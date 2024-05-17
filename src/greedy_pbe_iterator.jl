Base.@doc """
    GreedyPBEIterator <: ProgramIterator

Defines an [`ProgramIterator`](@ref), that greedly generates a program for each IOExample, given an iterator. 

Consists of:
- `examples::Vector{<:IOExample}`: a collection of examples defining the specification 
- `subiterator::ProgramIterator`: a user-provided iterator instance that can find programs which satisfy individual examples
end
""" GreedyPBEIterator
@programiterator GreedyPBEIterator(
    spec::Vector{<:IOExample},
    term_iter::ProgramIterator,
    pred_iter::ProgramIterator
)


"""
The state of the iterator is made up of the terms and preds that have been generated
"""
mutable struct PBEIteratorState
    terms::Vector{RuleNode}
    cover::Vector{Set{Int64}}
    preds::Vector{RuleNode}
    preds_gen::Function
end


function __stateful_iterator(iter::ProgramIterator)
    state = nothing
    return function ()
        p, state = isnothing(state) ? iterate(iter) : iterate(iter, state)
        return p
    end
end


"""
    Base.iterate(
    iterator::GreedyPBEIterator;
)
Starts the iteration for the GreedyPBEIterator. This method will use the subiterator to produce and store n programs that satisfy at least 1 example from the specification.
"""
function Base.iterate(
    iter::GreedyPBEIterator;
)

    subiterator = iter.term_iter
    grammar = get_grammar(iter.solver)
    init_state = copy(subiterator.solver.state)
    subproblems = map(ex -> Problem([ex]), iter.spec)

    programs::Vector{RuleNode} = Vector()
    for pb ∈ subproblems
        res = synth(pb, subiterator)
        subiterator.solver.state = copy(init_state)
        if res[2] == optimal_program
            push!(programs, res[1])
        end
    end

    cover = Vector{Set{Int64}}()
    for p ∈ programs
        satisfies = Set{Int64}()
        expr = rulenode2expr(p, grammar)
        for (i, example) ∈ enumerate(subproblems)
            sym_table = SymbolTable(grammar)
            if evaluate(example, expr, sym_table) == 1
                push!(satisfies, i)
            end
        end
        push!(cover, satisfies)
    end

    state = PBEIteratorState(programs, cover, Vector{RuleNode}(), __stateful_iterator(iter.pred_iter))
    return learn_tree!(iter, state)
end


function Base.iterate(iter::GreedyPBEIterator, state::PBEIteratorState)
    return learn_tree!(iter, state)
end


function learn_tree!(iter::GreedyPBEIterator, state::PBEIteratorState)
    DT = nothing
    while isnothing(DT)
        __next_pred!(state)
        println(rulenode2expr(state.preds[end], get_grammar(iter.solver)))
        #build decision tree
        xx = make_features(iter, state)
        DT = build_tree(xx, state.cover)
    end

    return dt2expr(DT, state.terms, state.preds, get_grammar(iter.solver)), state
end

function make_features(iter::GreedyPBEIterator, state::PBEIteratorState)::Vector{Vector{Float64}}
    spec = iter.spec
    grammar = get_grammar(iter.solver)
    preds = state.preds

    xx = Vector{Vector{Float64}}()
    for ex ∈ spec
        x = Float64.([execute_on_input(grammar, pred, ex.in) for pred in preds])
        push!(xx, x)
    end

    return xx
end


function __next_pred!(state::PBEIteratorState)::RuleNode
    pred = freeze_state(state.preds_gen())
    push!(state.preds, pred)
    return pred
end

function dt2expr(tree::DecisionTreeInternal, terms::Vector{RuleNode}, preds::Vector{RuleNode}, grammar::AbstractGrammar)::Expr
    cond = rulenode2expr(preds[tree.pred_index], grammar)
    t_branch = dt2expr(tree.true_branch, terms, preds, grammar)
    f_branch = dt2expr(tree.false_branch, terms, preds, grammar)

    prog = """if $(cond)
            $(t_branch)
        else
            $(f_branch)
        end"""
    return Meta.parse(prog)
end

function dt2expr(tree::DecisionTreeLeaf, terms::Vector{RuleNode}, preds::Vector{RuleNode}, grammar::AbstractGrammar)
    term = rulenode2expr(terms[tree.term_index], grammar)
    return term
end