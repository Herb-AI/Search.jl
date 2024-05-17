abstract type AbstractDecisionTreeNode end

struct DecisionTreeError <: Exception
    message::String
end
Base.showerror(io::IO, e::DecisionTreeError) = print(io, e.message)

struct DecisionTreeInternal <: AbstractDecisionTreeNode
    pred_index::Int64
    true_branch::AbstractDecisionTreeNode
    false_branch::AbstractDecisionTreeNode
end

struct DecisionTreeLeaf <: AbstractDecisionTreeNode
    term_index::Int64
end


function build_tree(X::Vector{Vector{Float64}}, covers::Vector{Set{Int64}})::Union{AbstractDecisionTreeNode,Nothing}
    return build_tree(Set(1:length(X)), X, covers, Set(1:length(X[1])))
end


function build_tree(pts::Set{Int64}, X::Vector{Vector{Float64}}, covers::Vector{Set{Int64}}, preds::Set{Int64})::Union{AbstractDecisionTreeNode,Nothing}
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
    best_gain = -1
    for pred_index ∈ preds
        ig = information_gain(pts, pred_index, X, covers)
        if ig > best_gain
            best_gain = ig
            best_pred = pred_index
        end
    end

    if best_gain == -1
        return nothing
    end

    #split the remaining pts after best_pred
    ptsy, ptsn = split_by_predicate(pts, best_pred, X)
    delete!(preds, best_pred)
    yes_branch = build_tree(ptsy, X, covers, preds)
    no_branch = build_tree(ptsn, X, covers, preds)
    push!(preds, best_pred)

    if isnothing(yes_branch) || isnothing(no_branch)
        return nothing
    else
        return DecisionTreeInternal(best_pred, yes_branch, no_branch)
    end
end


function information_gain(pts::Set{Int64}, pred_index::Int64, X::Vector{Vector{Float64}}, covers::Vector{Set{Int64}})::Float64
    yes_points, no_points = split_by_predicate(pts, pred_index, X)

    return length(yes_points) / length(pts) * entropy(yes_points, covers) +
           length(no_points) / length(pts) * entropy(no_points, covers)
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
        ent += -p * log2(p)
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
        den += length(intersect(cover, pts))
    end

    return num / den
end