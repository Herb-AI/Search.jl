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

function split_grammar(grammar::ContextSensitiveGrammar, start::Symbol)::Vector{ContextSensitiveGrammar}
    # Build a graph representing the dependencies between the rules
    graph = build_graph(grammar)

    # For each rule, find the smallest sub-grammar that contains it
    paths = []
    for edge in graph.edges
        edges = Set{Edge}([edge])
        union!(edges, find_path(graph, start, edge.symbol))
        for dependency in edge.dependencies
            union!(edges, find_path(graph, dependency, nothing))
        end
        push!(paths, edges)
    end

    # TODO: Remove subsets

    # Create a sub-grammar from each path
    subgrammars = []
    for path in paths
        g = deepcopy(@csgrammar begin end)
        for edge in path
            for rule in edge.rules
                add_rule!(g, rule)
            end
        end
        push!(subgrammars, g)
    end

    return subgrammars
end

function find_path(graph::Graph, start::Symbol, target::Union{Symbol,Nothing})::Set{Edge}
    
    # TODO: Find the shortest path from start to target

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
