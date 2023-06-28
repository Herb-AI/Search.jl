using Random
abstract type ExpressionIterator end


# TreeNode definition.
mutable struct TreeNode
    state
    visits::Int
    wins::Float64
    depth::Int
    children::Array{TreeNode, 1}
    parent::Union{TreeNode, Nothing}
end

# Create a new TreeNode.
function TreeNode(state, depth, parent)
    return TreeNode(state, 0, 0.0, depth, TreeNode[], parent)
end

# Select the child node with the highest UCT score.
function select_child(node::TreeNode, c)
    total_visits = sum(n.visits for n in node.children)
    best_score = -Inf
    best_child = nothing

    for child in node.children
        if child.visits == 0
            score = Inf  # Set a high score for unvisited nodes
        else
            exploration_term = c * sqrt(log(total_visits) / child.visits)
            score = child.wins / child.visits + exploration_term
        end

        if score > best_score
            best_score = score
            best_child = child
        end
    end

    return best_child
end

# Expands a chosen node by adding all configurations as child nodes an picking one at random.
function expand_node(node, grammar, mem)
    # Checks in memory if the rules have already been enumerated once to save time.
    if mem[node.depth+1] == nothing
        enumerator = Herb.HerbSearch.ContextFreeEnumerator(grammar, node.depth+1, :START)
        rules = []
        for rule in enumerator
            push!(rules, rule)
        end
        mem[node.depth+1] = rules
        push!(mem, nothing)
    else
        rules = mem[node.depth+1]
    end
    
    # Checks what the configuration of the current node is and filters out all configurations that do not match.
    temp = [string(node.state.children[i])[1:end-1] for i in eachindex(node.state.children)]
    filtered_rules = filter(x -> all(contains(string(x), s) for s in temp), rules)[2:end]
    
    # Create an array of child nodes and assign them to the current node.
    child_nodes = TreeNode[]
    for child in filtered_rules
        push!(child_nodes , TreeNode(child, node.depth+1, node))
    end
    node.children = child_nodes
    
    return rand(node.children)
end

# The simulation step tries to evaluate a pipeline and returns its accuracy.
function simulate(state, data)
    accuracy = 0
    try
        #pipeline = eval(Herb.HerbSearch.rulenode2expr(state, grammar))
        pipeline = eval(Meta.parse(insert_name_indexes(string(Herb.HerbSearch.rulenode2expr(state, grammar)))))
        accuracy = evaluate_pipeline(pipeline, data[1], data[2], data[3], data[4])
        #println("Accuracy: ", accuracy)
    catch
        accuracy = 0
    end
    return accuracy
end

# The backpropagation step updates the visits and wins fields of the given node and its parent node.
function backpropagate(node::TreeNode, result)
    while node != nothing
        node.visits += 1
        node.wins += result
        node = node.parent
    end
end

# Perform Monte Carlo Tree Search
function mcts(grammar, data, max_iterations, c)
    # Initialize the memory array for the memoization of certain configuration.
    mem = []
    push!(mem, nothing)
    # Generate the root node.
    root_node = select_initial_state(grammar, 2, :START, mem)
    best_pipeline_score = 0 
    best_pipeline_conf = nothing
    for _ in 1:max_iterations
        node = root_node
        # Selection 
        while !isempty(node.children) 
            node = select_child(node, c)
        end
        # Expansion
        if node.visits > 0
            node = expand_node(node, grammar, mem)
        end

        # Simulation
        reward = simulate(node.state, data)
        if reward > best_pipeline_score
            best_pipeline_score = reward
            best_pipeline_conf = node.state
        end

        # Backpropagation
        backpropagate(node, reward)
    end

    best_cost = 1 - best_pipeline_score
    return best_pipeline_conf, best_cost
end

# Creates an inital state to use as a starting point for the algorithm. 
function select_initial_state(grammar, max_depth, start_symbol, mem)
    initial_state = TreeNode(:EMPTY, 1, nothing)  # Create a root node with an empty symbol
    # Expand the root node by adding the first layer of options
    
    child_nodes = TreeNode[]
    enumerator = Herb.HerbSearch.ContextFreeEnumerator(grammar, max_depth, start_symbol)
    rules = []
    for expression in enumerator
        child = TreeNode(expression, 2, initial_state)
        push!(rules, expression)
        push!(child_nodes, child)
    end

    push!(mem, rules)
    push!(mem, nothing)

    initial_state.children = child_nodes
    
    return initial_state
end