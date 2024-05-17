struct Edge
    dependencies::Set{Symbol}
    rules::Vector{Expr}
end

struct Node
    edges::Vector{Edge}
end    

struct Graph
    nodes::Dict{Symbol,Node}
end

function split_grammar(grammar::ContextSensitiveGrammar, start::Symbol)::Vector{ContextSensitiveGrammar}
    # Build a graph representing the dependencies between the rules
    graph = build_graph(grammar)

    # TODO: Implement the splitting algorithm

    return []
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
            push!(nodes[grammar.types[i]].edges, Edge(dependencies, [rule]))        
        end
    end
    
    return Graph(nodes)
end
