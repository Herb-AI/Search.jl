abstract type AbstractDecisionTreeNode end

struct DecisionTreeError <: Exception
    message::String
end
Base.showerror(io::IO, e::DecisionTreeError) = print(io, e.message)

struct DecisionTreeInternal <: AbstractDecisionTreeNode
    pred_index::UInt32
    true_branch::AbstractDecisionTreeNode
    false_branch::AbstractDecisionTreeNode
end

struct DecisionTreeLeaf <: AbstractDecisionTreeNode
    term_index::UInt32
end

struct DecisionTreeAST
    tree::AbstractDecisionTreeNode
    terms::Vector{RuleNode}
    preds::Vector{RuleNode}
end


function dt2expr(AST::DecisionTreeAST, grammar::AbstractGrammar)::Expr
    return __dt2expr(AST.tree, AST.terms, AST.preds, grammar)
end


function build_tree(terms::Vector{RuleNode}, preds::Vector{RuleNode}, X::Vector{Vector{Float64}}, covers::Vector{Set{Int64}})::Union{DecisionTreeAST,Nothing}
    dt = __build_tree(Set(1:length(X)), X, covers, Set(1:length(X[1])))
    if isnothing(dt)
        return nothing
    end
    return DecisionTreeAST(dt, terms, preds)
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