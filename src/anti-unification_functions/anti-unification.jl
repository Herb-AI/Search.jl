include("syntax_tree.jl")

"""
    function function placeholder(node::AST)

Creates a placeholder node for an AST
"""
function placeholder(node::AST)
    nodeType = typeof(node)
    subtrees = Vector{nodeType}()
    for i in node.subtrees
        push!(subtrees, nodeType(node.index,nothing,0,Vector{nodeType}()))
    end
    return nodeType(node.index,node.value,length(subtrees),subtrees)
end

"""
    function antiUnification(tree1::AST, tree2::AST, checker::Set{Tuple{Int, Int}})

Creates the longest common pattern between two ASTs. It utilizes the root nodes as the starting point for anti-unification
"""
function antiUnification(tree1::AST, tree2::AST, checker::Set{Tuple{Int, Int}})
    @assert tree1.value == tree2.value
    push!(checker, (tree1.index,tree2.index))
    queue = []
    substit = 0
    outputTree = placeholder(tree1)
    args = outputTree.size

    for i in range(1,outputTree.size)
        push!(queue, (outputTree, i, tree1.subtrees[i], tree2.subtrees[i]))
    end

    while( !isempty(queue) )
        parent_node, des, subtree1, subtree2 = popfirst!(queue)
        if subtree1.value == subtree2.value && subtree1.size == subtree2.size
            
            push!(checker, (subtree1.index, subtree2.index))
            newSubtree = placeholder(subtree1)
            
            args += newSubtree.size - 1
            substit += 1

            parent_node.subtrees[des] = newSubtree
            
            for i in range(1,newSubtree.size)
                push!(queue, (newSubtree, i, subtree1.subtrees[i], subtree2.subtrees[i]))
            end
        end
    end
    return (outputTree, substit, args)
end

"""
    function subtreeCheck(tree::AST, compareTree::AST, checker::Set{Tuple{Int, Int}})

Recursively calculates all common patterns between `CompareTree` and every node in `tree`
"""
function subtreeCheck(tree::AST, compareTree::AST, checker::Set{Tuple{Int, Int}})
    substitutions = []
    if tree.value == compareTree.value && tree.size == compareTree.size && (tree.index, compareTree.index) ∉ checker
        push!(substitutions, antiUnification(tree, compareTree, checker))
    end
    for subtree in tree.subtrees
        append!(substitutions, subtreeCheck(subtree, compareTree, checker))
    end
    return substitutions
end

"""
    function take_best(substitutions, max_args::Int, min_subs::Int)

Removes every common pattern from 'substitutions' based on `max_args` and `min_subs` constraints
"""
function take_best(substitutions, max_args::Int, min_subs::Int)
    best = nothing
    for subst in substitutions
        
        if !(subst[3] <= max_args && subst[2] >= min_subs)
            continue
        end
        if best === nothing
            best = subst
        elseif best[2] < subst[2]
            best = subst
        end
    end
    if best === nothing
        return []
    else
        return [best]
    end
end

"""
    function dfsCompare(tree1::AST , tree2::AST, checker::Set{Tuple{Int, Int}} , max_args::Int, min_subs::Int)

Recursively calculates all valid common patterns between two ASTs using every combination of nodes in the trees as starting point
"""
function dfsCompare(tree1::AST , tree2::AST, checker::Set{Tuple{Int, Int}} , max_args::Int, min_subs::Int)
    substitutions = take_best(subtreeCheck(tree2, tree1, checker), max_args, min_subs)
    for subtree in tree1.subtrees
        append!(substitutions, dfsCompare(subtree, tree2, checker, max_args, min_subs))
    end
    return substitutions
end

"""
    function calculate_dublicates(tree1::AST, tree2::AST, max_args::Int, min_subs::Int)

This function serves as the main entry point for calculating all valid common patterns between two ASTs using every combination of nodes in the trees as starting point
"""
function calculate_dublicates(tree1::AST, tree2::AST, max_args::Int, min_subs::Int)
    checker = Set{Tuple{Int, Int}}()
    return dfsCompare(tree1,tree2,checker, max_args, min_subs) 
end

"""
    function calculate_dublicates_rule_nodes(rule_nodes::Vector{RuleNode}, max_args::Int, min_subs::Int)

Calculates all valid common patterns between multiple ASTs
"""
function calculate_dublicates_rule_nodes(rule_nodes::Vector{RuleNode}, max_args::Int, min_subs::Int)
    active_trees = [(buildTreeRuleNode(rule_nodes[1]), 0 ,0)]
    for index in range(2,length(rule_nodes))
        new_trees = []
        for active_tree in active_trees
            results = calculate_dublicates(active_tree[1], buildTreeRuleNode(rule_nodes[index]), max_args, min_subs)
            append!(new_trees,results)
        end
        active_trees = new_trees
    end
    return active_trees
end

