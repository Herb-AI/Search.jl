using DataStructures

struct Edge
    symbol::Symbol
    dependencies::Set{Symbol}
    rules::Vector{Expr}
end

struct Node
    edges::Vector{Edge}
end    

struct Graph
    nodes::Dict{Symbol,Node}
    edges::Vector{Edge}
end

struct State
    current::Set{Symbol}
    escaped::Set{Symbol}
    used::Set{Edge}
end

function split_grammar(grammar::ContextSensitiveGrammar, start::Symbol)::Vector{ContextSensitiveGrammar}
    # Build a graph representing the dependencies between the rules
    graph = build_graph(grammar)

    # For each rule, find the smallest sub-grammar that contains it
    paths = []
    for edge in graph.edges
        edges = Set{Edge}([edge])
        union!(edges, find_path(graph, State(Set([start]), Set([:ε, edge.symbol]), Set()), edge.symbol))
        union!(edges, find_path(graph, State(edge.dependencies, Set([:ε]), Set([edge])), :ε))
        push!(paths, edges)
    end

    # Create a sub-grammar from each path
    subgrammars = []
    for i in 1:length(paths)
        # Check if the path is a subset of another path
        subset = false
        for j in i+1:length(paths)
            if issubset(paths[i], paths[j])
                subset = true
                break
            end
        end
        # Create a sub-grammar if the path is not a subset
        if !subset
            g = deepcopy(@csgrammar begin end)
            for edge in paths[i]
                for rule in edge.rules
                    add_rule!(g, rule)
                end
            end
            push!(subgrammars, g)
        end
    end

    return subgrammars
end

function find_path(graph::Graph, start::State, target::Symbol)::Set{Edge}
    # Breadth-first search
    queue = Queue{State}()
    enqueue!(queue, start)

    while !isempty(queue)
        state = dequeue!(queue)
        
        # Check if the target is in the current state
        if target in state.current && isempty(setdiff(state.current, state.escaped))
            return state.used
        end

        # Enqueue all possible next states
        for node in state.current
            if node in state.escaped
                continue
            end
            for edge in graph.nodes[node].edges
                if !(edge in state.used)
                    new_current = union(setdiff(state.current, Set([node])), edge.dependencies)
                    new_used = union(state.used, Set([edge]))
                    new_escaped = state.escaped
                    if !(node in edge.dependencies)
                        union!(new_escaped, Set([node]))
                    end
                    new_state = State(new_current, new_escaped, new_used)
                    enqueue!(queue, new_state)
                end
            end
        end
    end

    # Return an empty set if no path was found
    return Set{Edge}()
end

function build_graph(grammar::ContextSensitiveGrammar)::Graph
    # Collect all symbols
    symbols = Set{Symbol}()
    for type in grammar.types
        push!(symbols, type)
    end

    # Create a node for each symbol
    nodes = Dict{Symbol, Node}()
    for symbol in symbols
        nodes[symbol] = Node([])
    end

    # Place every rule on an edge with the correct dependencies
    edges = []
    for i in 1:length(grammar.rules)
        rule = :($(grammar.types[i]) = $(grammar.rules[i]))
        dependencies = Set{Symbol}(grammar.childtypes[i])
        if grammar.childtypes[i] == []
            push!(dependencies, :ε)
        end

        # Check if an edge with the same dependencies already exists
        matched = false
        for edge in nodes[grammar.types[i]].edges
            if edge.dependencies == dependencies
                matched = true
                push!(edge.rules, rule)
                break
            end
        end

        # Create a new edge if no match was found
        if !matched
            edge = Edge(grammar.types[i], dependencies, [rule])
            push!(edges, edge)
            push!(nodes[grammar.types[i]].edges, edge)        
        end
    end

    return Graph(nodes, edges)
end
