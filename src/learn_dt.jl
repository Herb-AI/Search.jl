function get_labels_examples(
    solutions::Vector{Tuple{RuleNode, Set{Number}}},
    IO_examples::Vector{IOExample}
)::Tuple{Vector{String}, Vector{IOExample}}
    labels = fill("", length(IO_examples))
    for (program_idx, s) in enumerate(solutions)
        for i in s[2]
            labels[i] *= string(program_idx)
        end
    end

    examples = Vector{IOExample}()
    for (i, l) in enumerate(labels)
        if !isempty(l)
            push!(examples, IO_examples[i])
        end
    end
    filter!(l->!isempty(l), labels)

    return (labels, examples)
end

using DecisionTree
function learn_DT(
    problem::Problem{Vector{IOExample}},
    grammar::AbstractGrammar,
    sym_start::Symbol,
    sym_bool::Symbol,
    solutions::Vector{Tuple{RuleNode, Set{Number}}},
    max_predicates::Int64=1024
)::Union{Tuple{RuleNode, AbstractGrammar}, Nothing}
    
    # no solutions to combine with the decision tree -> return nothing
    if isempty(solutions)
        return nothing
    end
    
    # check if the condition rule is contained in the grammar
    return_type = grammar.rules[grammar.bytype[sym_start][1]]    
    idx = findfirst(r -> r == :($sym_bool ? $return_type : $return_type), grammar.rules)
    # add condition rule for easy access when outputing
    if isnothing(idx)
        add_rule!(grammar, :($return_type = $sym_bool ? $return_type : $return_type))
        idx = length(grammar.rules)
    end

    symboltable :: SymbolTable = SymbolTable(grammar, Main)

    labels, examples = get_labels_examples(solutions, problem.spec)
    
    n_predicates = 16
    candidate_program = nothing
    while n_predicates <= max_predicates
        println("pred: ", n_predicates)
        (features, predicates) = get_features_predicates(grammar, sym_bool, examples, n_predicates)
        features = float.(features)

        # init and fit model with features and labels
        model = DecisionTree.DecisionTreeClassifier()
        DecisionTree.fit!(model, features, labels)

        candidate_program = construct_final(model.root.node, idx, solutions, predicates, false)
        expr = rulenode2expr(candidate_program, grammar)
        println("final_program expr: ", expr)

        score = evaluate(Problem(examples), expr, symboltable, allow_evaluation_errors=true)
        if score == 1
            candidate_program = freeze_state(candidate_program)
            return (candidate_program, grammar)
        else 
            n_predicates *= 4
        end
    end

    candidate_program = freeze_state(candidate_program)
    return (candidate_program, grammar)
end

function construct_final(
    node::Union{DecisionTree.Node, DecisionTree.Leaf},
    cond_rule_idx::Int64,
    solutions::Vector{Tuple{RuleNode, Set{Number}}},
    predicates::Vector{RuleNode},
    prune::Bool=true
)::RuleNode
    if DecisionTree.is_leaf(node)
        idx = Int(node.majority[1])-48
        return solutions[idx][1]
    end

    # check if two leafs can be combined
    if prune == true && DecisionTree.is_leaf(node.left) && DecisionTree.is_leaf(node.right)
        if occursin(node.left.majority, node.right.majority) == true
            idx = Int(node.left.majority[1])-48
            return solutions[idx][1]
        elseif occursin(node.right.majority, node.left.majority) == true
            idx = Int(node.right.majority[1])-48
            return solutions[idx][1]
        end
    end

    l = construct_final(node.left, cond_rule_idx, solutions, predicates)
    r = construct_final(node.right, cond_rule_idx, solutions, predicates)
    
    #has to be order r,l because DT compares features like this (Feature 5 < 0.5), essentially checks if the expr evaluates to false
    condition = RuleNode(cond_rule_idx, Vector{RuleNode}([predicates[node.featid], r, l]))
    return condition
end

function get_features_predicates(
    grammar::AbstractGrammar,
    sym_bool::Symbol,
    examples::Vector{IOExample}, 
    n_predicates::Int64,
    mod::Module=Main,
    allow_evaluation_errors::Bool=true
)::Tuple{Matrix, Vector{RuleNode}}
    symboltable :: SymbolTable = SymbolTable(grammar, mod)
    features = trues(length(examples), n_predicates)
    
    # generate random predicates
    predicates = Vector{RuleNode}()
    while length(predicates) < n_predicates
        rand_rn = rand(RuleNode, grammar, sym_bool, 4)
        # if a predicate contains some argument
        if occursin("_arg_", repr(rulenode2expr(rand_rn, grammar)))
            push!(predicates, rand_rn)
        end
    end

    # println("predicates: ")
    # for (i, p) in enumerate(predicates)
    #     println(i, " ", rulenode2expr(p, grammar))
    # end
    
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
    return (features, predicates)
end