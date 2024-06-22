


function satisfies_examples(spec::Vector{IOExample}, expr::Any, symboltable::SymbolTable, allow_evaluation_errors::Bool=true)::Set{Number}
    satisfied = Set{Number}()
    for (i, example) ∈ enumerate(spec)
        try
            output = execute_on_input(symboltable, expr, example.in)
            if (output == example.out)
                push!(satisfied, i)
            end
        catch e
            # Throw the error again if evaluation errors aren't allowed
            eval_error = EvaluationError(expr, example.in, e)
            allow_evaluation_errors || throw(eval_error)
            break
        end
    end
    return satisfied
end



Base.@doc """
    GreedyPBEIterator <: ProgramIterator

Defines an [`ProgramIterator`](@ref), that greedly generates a program for each IOExample, given an iterator. 

Consists of:
- `examples::Vector{<:IOExample}`: a collection of examples defining the specification 
- `subiterator::ProgramIterator`: a user-provided iterator instance that can find programs which satisfy individual examples
end
""" SubsetIterator
@programiterator mutable SubsetIterator(
    spec::Vector{<:IOExample},
    term_iter::ProgramIterator,
    pred_iter::ProgramIterator,
    max_enumerations::Int=10000,
    fraction::Int = 5,
    mod::Module=Main
) <: ProgramIterator

function Base.iterate(iter::SubsetIterator)
    program, term_state = iterate(iter.term_iter)
    state = Dict()
    state["term_state"] = term_state
    state["enums"] = 1

    state["programs"] = Dict{Set{Number}, RuleNode}()
    g = get_grammar(iter.solver)
    satisfied = satisfies_examples(iter.spec, rulenode2expr(program, g), SymbolTable(g, iter.mod))
    state["programs"][satisfied] = freeze_state(program)

    return (program, state)
end

function Base.iterate(iter::SubsetIterator, state)
    program, term_state = iterate(iter.term_iter, state["term_state"])
    state["term_state"] = term_state
    state["enums"] = state["enums"]+1
    
    g = get_grammar(iter.solver)
    satisfied = satisfies_examples(iter.spec, rulenode2expr(program, g), SymbolTable(g, iter.mod))
    
    if !haskey(state["programs"], satisfied)

        state["programs"][satisfied] = freeze_state(program)
        sym_start = get_starting_symbol(iter.term_iter.solver)
        sym_bool = get_starting_symbol(iter.pred_iter.solver)

        list_programs::Vector{Tuple{RuleNode, Set{Number}}} = [(v, k) for (k, v) in state["programs"]]
        smallest_subset, subset_result = find_smallest_subset(Set{Number}(1:length(iter.spec)), list_programs)
        candidate_program, new_grammar = decision_tree(iter.spec, g, sym_start, sym_bool, smallest_subset, state["enums"] / iter.fraction)
        iter.solver.grammar = new_grammar
        state["grammar"] = new_grammar
        return (candidate_program, state)
    end
    return (program, state)

end

struct DecisionTreeError <: Exception
    message::String
end
Base.showerror(io::IO, e::DecisionTreeError) = println(io, e.message)

using DecisionTree
function decision_tree(
    spec::Vector{IOExample},
    old_grammar::AbstractGrammar,
    sym_start::Symbol,
    sym_bool::Symbol,
    solutions::Vector{Tuple{RuleNode, Set{Number}}},
    n_predicates
)::Tuple{RuleNode, AbstractGrammar}
    grammar = old_grammar
    return_type = grammar.rules[grammar.bytype[sym_start][1]]

    idx = findfirst(r -> r == :($sym_bool ? $return_type : $return_type), grammar.rules)
    # add condition rule for easy access when outputing
    if isnothing(idx)
        throw(DecisionTreeError("Conditional if-else statement not found"))
    end


    labels = get_labels(solutions, spec)
    examples = get_examples(labels, spec )
    predicates = enumerate_predicates(grammar, sym_bool, n_predicates)

    if length(predicates) == 0
        return solutions[1][1], grammar
    end
    features = get_features(grammar, examples, predicates)
    features = float.(features)

    # init and fit model with features and labels
    model = DecisionTree.DecisionTreeClassifier()
    DecisionTree.fit!(model, features, labels)

    candidate_program = construct_final(model.root.node, idx, solutions, predicates)

    candidate_program = freeze_state(candidate_program)
    return candidate_program, grammar
end

function construct_final(
    node::Union{DecisionTree.Node, DecisionTree.Leaf},
    cond_rule_idx::Int64,
    solutions::Vector{Tuple{RuleNode, Set{Number}}},
    predicates::Vector{RuleNode},
    prune::Bool=true
)::RuleNode
    if DecisionTree.is_leaf(node)
        labels = split(node.majority, "-")
        idx = parse(Int, labels[1])
        return solutions[idx][1]
    end

    # check if two leafs can be combined
    if prune == true && DecisionTree.is_leaf(node.left) && DecisionTree.is_leaf(node.right)
        if occursin(node.left.majority, node.right.majority) == true
            labels = split(node.left.majority, "-")
            idx = parse(Int, labels[1])
            return solutions[idx][1]
        elseif occursin(node.right.majority, node.left.majority) == true
            labels = split(node.right.majority, "-")
            idx = parse(Int, labels[1])
            return solutions[idx][1]
        end
    end

    l = construct_final(node.left, cond_rule_idx, solutions, predicates)
    r = construct_final(node.right, cond_rule_idx, solutions, predicates)
    
    #has to be order r,l because DT compares features like this (Feature 5 < 0.5), essentially checks if the expr evaluates to false
    condition = RuleNode(cond_rule_idx, Vector{RuleNode}([predicates[node.featid], r, l]))
    return condition
end

function get_labels(
    solutions::Vector{Tuple{RuleNode, Set{Number}}},
    IO_examples::Vector{IOExample}
)::Vector{String}
    labels = fill("", length(IO_examples))
    for (program_idx, s) in enumerate(solutions)
        for i in s[2]
            labels[i] *= string(program_idx)*"-"
        end
    end
    return labels
end

function get_examples(
    labels::Vector{String},
    IO_examples::Vector{IOExample}
)::Vector{IOExample}
    examples = Vector{IOExample}()
    for (i, l) in enumerate(labels)
        if !isempty(l)
            push!(examples, IO_examples[i])
        end
    end
    filter!(l->!isempty(l), labels)

    return examples
end

function collect_rules_from_rulenode(rn::RuleNode, nodes::Set{Int64} = Set{Int64}())::Set{Int64}
    push!(nodes, rn.ind)
    for child in rn.children
        collect_rules_from_rulenode(child, nodes)  # Recursively collect nodes from children
    end
    return nodes
end

function enumerate_predicates(
    grammar::AbstractGrammar,
    sym_bool::Symbol,
    n_predicates::Number,
)::Vector{RuleNode}
    
    iterator = BFSIterator(grammar, sym_bool)
    predicates = Vector{RuleNode}()

    arg_rules = Vector{Int64}()
    for (i, rule) in enumerate(grammar.rules)
        if typeof(rule) == Symbol && occursin("_arg_", String(rule))
            push!(arg_rules, i)
        end            
    end
    for (i, candidate_program) ∈ enumerate(iterator)
        candidate_program = freeze_state(candidate_program)
        
        # add predicate only if contains rule with an argument
        # if the intersection of arg_rules and rules in candidate_program is >= 1
        if length(intersect(arg_rules, collect_rules_from_rulenode(candidate_program))) >= 1
            push!(predicates, candidate_program)
        end
        # if length(predicates) >= n_predicates
        if i >= n_predicates
            break
        end
    end
    return predicates
end

function get_features(
    grammar::AbstractGrammar,
    examples::Vector{IOExample}, 
    predicates::Vector{RuleNode},
    mod::Module=Main,
    allow_evaluation_errors::Bool=true
)::Matrix
    symboltable :: SymbolTable = SymbolTable(grammar, mod)
    features = trues(length(examples), length(predicates))
    
    for (i, e) in enumerate(examples)
        outputs = Vector()
        for p in predicates
            expr = rulenode2expr(p, grammar)
            try
                o = execute_on_input(symboltable, expr, e.in)
                push!(outputs, o)
            catch err
                # Throw the error again if evaluation errors aren't allowed
                eval_error = EvaluationError(expr, e.in, err)
                allow_evaluation_errors || throw(eval_error)
                push!(outputs, false)
                # break
            end
            
        end
        features[i, :] = outputs
    end
    return features
end