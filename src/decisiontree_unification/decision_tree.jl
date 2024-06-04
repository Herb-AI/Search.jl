abstract type DivideConquerIterator <: ProgramIterator end

abstract type AbstractDecisionTreeNode end

struct DecisionTreeError <: Exception
    message::String
end
Base.showerror(io::IO, e::DecisionTreeError) = println(io, e.message)

struct DecisionTreeInternal <: AbstractDecisionTreeNode
    pred_index::UInt32
    true_branch::AbstractDecisionTreeNode
    false_branch::AbstractDecisionTreeNode
end

struct DecisionTreeLeaf <: AbstractDecisionTreeNode
    term_index::UInt32
end

mutable struct DecisionTreeAST
    tree::Union{Nothing,AbstractDecisionTreeNode}
    iter::DivideConquerIterator
    terms::Vector{RuleNode}
    preds::Vector{RuleNode}
    pred_gen::Iterators.Stateful
    cover::Vector{Set{Int64}}
    features::Vector{Vector{Float64}}
    pred_batch_size::Int64

    DecisionTreeAST(iter::DivideConquerIterator; pred_batch_size::Int64=64) = begin
        grammar = get_grammar(iter.solver)
        examples = get_spec(iter)
        terms = initial_programs(iter, examples)
        if isnothing(terms)
            if iter.max_enumerations == 0
                throw(DecisionTreeError("Ran out of enumerations for terms"))
            end
            throw(DecisionTreeError("terms couldn't be generated or timedout"))
        end
        cover = __make_cover(terms, examples, grammar)

        pred_gen = Iterators.take(get_pred_iter(iter), iter.max_enumerations)
        pred_gen = Iterators.filter(pred_gen) do pred
            input_symbols = collect(keys(examples[1].in))
            pred_expr = rulenode2expr(pred, grammar)
            typeof(pred_expr) == Expr || return false
            any(sym -> sym ∈ input_symbols, __flatten_symbols(pred_expr))
        end
        pred_gen = Iterators.map(pred -> freeze_state(pred), pred_gen) # to iterate over RuleNodes and not StateHoles
        pred_gen = Iterators.Stateful(pred_gen)

        new(
            nothing,
            iter,
            terms,
            Vector{RuleNode}(),
            pred_gen,
            cover,
            Vector{Vector{Float64}}(undef, length(iter.spec)),
            pred_batch_size
        )
    end
end


function Base.iterate(iter::DivideConquerIterator)
    try
        AST = DecisionTreeAST(iter)
        learn_tree!(AST)
        return dt2expr(AST), AST
    catch ex
        println(ex.message)
        return nothing
    end
end

function Base.iterate(iter::DivideConquerIterator, AST::DecisionTreeAST)
    return dt2expr(AST), AST
end

function initial_programs(iter::DivideConquerIterator, spec::Vector{IOExample})::Union{Nothing,Vector{RuleNode}}
    throw(DecisionTreeError("You must implement the initial_programs method for your iterator type"))
end

function get_pred_iter(iter::DivideConquerIterator)::ProgramIterator
    throw(DecisionTreeError("You must implement the get_pred_iter method for your iterator type"))
end

function get_spec(iter::DivideConquerIterator)::Vector{IOExample}
    throw(DecisionTreeError("You must implement the get_spec method for your iterator type"))
end


function dt2expr(AST::DecisionTreeAST)::Expr
    if isnothing(AST.tree)
        throw(DecisionTreeError("There is no tree to convert"))
    end
    return __dt2expr(AST.tree, AST.terms, AST.preds, get_grammar(AST.iter.solver))
end


function learn_tree!(state::DecisionTreeAST)::DecisionTreeAST
    while isnothing(state.tree)
        for i in 1:state.pred_batch_size
            new_pred = iterate(state.pred_gen)
            if isnothing(new_pred)
                println("exhausted the predicate enumeration")
                state.tree = build_tree(state.features, state.cover)
                return state
            end
            push!(state.preds, new_pred[1])
            __update_features!(state, new_pred[1])
        end
        state.tree = build_tree(state.features, state.cover)
    end

    return state
end


function __update_features!(state::DecisionTreeAST, new_pred::RuleNode)
    spec = get_spec(state.iter)
    grammar = get_grammar(state.iter.solver)
    xx = state.features

    for (i, ex) ∈ enumerate(spec)
        if !isassigned(xx, i)
            xx[i] = Vector{Float64}()
        end
        try
            push!(xx[i], execute_on_input(grammar, new_pred, ex.in))
        catch exept
            push!(xx[i], 0)
        end
    end
end


function build_tree(X::Vector{Vector{Float64}}, covers::Vector{Set{Int64}})::Union{AbstractDecisionTreeNode,Nothing}
    dt = __build_tree(Set(1:length(X)), X, covers, Set(1:length(X[1])))
    if isnothing(dt)
        return nothing
    end
    return dt
end


function __make_cover(terms::Vector{RuleNode}, examples::Vector{IOExample}, grammar::AbstractGrammar)::Vector{Set{Int64}}
    cover = Vector{Set{Int64}}()
    subproblems = map(ex -> Problem([ex]), examples)
    for term ∈ terms
        satisfies = Set{Int64}()
        expr = rulenode2expr(term, grammar)
        for (i, example) ∈ enumerate(subproblems)
            sym_table = SymbolTable(grammar)
            if evaluate(example, expr, sym_table, allow_evaluation_errors=true) == 1
                push!(satisfies, i)
            end
        end
        push!(cover, satisfies)
    end
    return cover
end


function __dt2expr(tree::DecisionTreeInternal, terms::Vector{RuleNode}, preds::Vector{RuleNode}, grammar::AbstractGrammar)::Expr
    cond = rulenode2expr(preds[tree.pred_index], grammar)
    t_branch = __dt2expr(tree.true_branch, terms, preds, grammar)
    f_branch = __dt2expr(tree.false_branch, terms, preds, grammar)

    prog = """if $(cond)
            $(t_branch)
        else
            $(f_branch)
        end"""
    return Base.remove_linenums!(Meta.parse(prog))
end

function __dt2expr(tree::DecisionTreeLeaf, terms::Vector{RuleNode}, preds::Vector{RuleNode}, grammar::AbstractGrammar)
    term = rulenode2expr(terms[tree.term_index], grammar)
    return term
end


function __build_tree(pts::Set{Int64}, X::Vector{Vector{Float64}}, covers::Vector{Set{Int64}}, preds::Set{Int64})::Union{AbstractDecisionTreeNode,Nothing}
    #check if a term covers all the indices
    for (i, cover) ∈ enumerate(covers)
        if issubset(pts, cover) # term t is a leaf
            return DecisionTreeLeaf(i)
        end
    end

    if isempty(preds)
        return nothing
    end

    best_pred = nothing
    lowest_entropy = floatmax(Float64)
    for pred_index ∈ preds
        entropy = conditional_entropy(pts, pred_index, X, covers)
        if entropy < lowest_entropy
            lowest_entropy = entropy
            best_pred = pred_index
        end
    end

    if lowest_entropy == floatmax(Float64)
        return nothing
    end

    #split the remaining pts after best_pred
    ptsy, ptsn = split_by_predicate(pts, best_pred, X)
    delete!(preds, best_pred)
    yes_branch = __build_tree(ptsy, X, covers, preds)
    no_branch = __build_tree(ptsn, X, covers, preds)
    push!(preds, best_pred)

    if isnothing(yes_branch) || isnothing(no_branch)
        return nothing
    else
        return DecisionTreeInternal(best_pred, yes_branch, no_branch)
    end
end


function conditional_entropy(pts::Set{Int64}, pred_index::Int64, X::Vector{Vector{Float64}}, covers::Vector{Set{Int64}})::Float64
    yes_points, no_points = split_by_predicate(pts, pred_index, X)

    return (length(yes_points) / length(pts) * entropy(yes_points, covers) +
            length(no_points) / length(pts) * entropy(no_points, covers))
end


function split_by_predicate(pts::Set{Int64}, pred_index::Int64, X::Vector{Vector{Float64}})::Tuple{Set{Int64},Set{Int64}}
    yes_points = Set{Int64}()
    no_points = Set{Int64}()
    for pt ∈ pts
        if X[pt][pred_index] == 1
            push!(yes_points, pt)
        else
            push!(no_points, pt)
        end
    end
    return yes_points, no_points
end


function entropy(pts::Set{Int64}, covers::Vector{Set{Int64}})::Float64
    ent = 0
    for i ∈ 1:length(covers)
        p = unconditional_prob(pts, i, covers)
        if p != 0
            ent += -p * log2(p)
        end
    end
    return ent
end


function unconditional_prob(pts::Set{Int64}, t::Int64, covers::Vector{Set{Int64}})::Float64
    p = 0
    for pt ∈ pts
        p += conditional_prob(pt, pts, t, covers)
    end

    return p / length(pts)
end


function conditional_prob(pt::Int64, pts::Set{Int64}, t::Int64, covers::Vector{Set{Int64}})::Float64
    if pt ∉ covers[t]
        return 0
    end

    num = length(intersect(covers[t], pts))
    den = 0
    for cover ∈ covers
        if pt ∈ cover
            den += length(intersect(cover, pts))
        end
    end

    return num / den
end

__flatten_symbols!(list) = ex -> begin
    ex isa Symbol && push!(list, ex)
    ex isa Expr && ex.head == :call && map(__flatten_symbols!(list), ex.args[2:end])
    list
end

__flatten_symbols(ex) = ex |> __flatten_symbols!([])