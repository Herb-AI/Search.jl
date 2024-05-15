function split_grammar(grammar::ContextSensitiveGrammar, sym::Symbol, max_depth::Integer)::Vector{ContextSensitiveGrammar}
    # TODO: check if this grammar is valid

    if max_depth == 0
        return [grammar]
    end
    
    rules = find_rules(grammar, sym)
    subgrammars = generate_subgrammars(grammar, rules)

    if max_depth == 1
        result = []
        for (subgrammar, _) in subgrammars
            cleanup_removed_rules!(subgrammar)
            push!(result, subgrammar)
        end
        return result
    end

    result = []
    for (subgrammar, current) in subgrammars
        for type in subgrammar.childtypes[current]
            subgrammar_split = split_grammar(subgrammar, type, max_depth - 1)
            for subsubgrammar in subgrammar_split
                cleanup_removed_rules!(subsubgrammar)
                push!(result, subsubgrammar)
            end
        end
    end
    return result
end

function find_rules(grammar::ContextSensitiveGrammar, sym::Symbol)::Vector{Int}
    return [i for (i, type) in enumerate(grammar.types) if type == sym && !grammar.isterminal[i]]
end

function generate_subgrammars(grammar::ContextSensitiveGrammar, rules::Vector{Int})::Vector{Tuple{ContextSensitiveGrammar, Int}}
    subgrammars = []
    for current in rules
        subgrammar = deepcopy(grammar)
        remove_rules(subgrammar, rules, current)
        push!(subgrammars, (subgrammar, current))
    end
    return subgrammars
end

function remove_rules(grammar::ContextSensitiveGrammar, rules::Vector{Int}, current::Int)
    for remove in rules
        if remove != current
            remove_rule!(grammar, remove)
        end
    end
end
