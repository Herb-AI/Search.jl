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

function add_bool_rules(grammar::AbstractGrammar, sym_start::Symbol)::Symbol
    
    sym_bool = :(ntBool)
    add_rule!(grammar, :($sym_bool = $sym_start == 1))
    add_rule!(grammar, :($sym_bool = $sym_start == 0))
    add_rule!(grammar, :($sym_start = $sym_bool ? $sym_start : $sym_start))
    return sym_bool
end

using DecisionTree
function learn_DT(
    problem::Problem{Vector{IOExample}},
    old_grammar::AbstractGrammar,
    sym_start::Symbol,
    sym_bool::Union{Symbol, Nothing},
    solutions::Vector{Tuple{RuleNode, Set{Number}}},
    max_predicates = typemax(10000)
)::Union{Tuple{RuleNode, AbstractGrammar}, Nothing}
    start_time = time()
    
    # no solutions to combine with the decision tree -> return nothing
    if isempty(solutions)
        return nothing
    end

    # check if the condition rule is contained in the grammar
    grammar = deepcopy(old_grammar)
    if isnothing(sym_bool)
        sym_bool = add_bool_rules(grammar, sym_start)
    end
    return_type = grammar.rules[grammar.bytype[sym_start][1]]    
    idx = findfirst(r -> r == :($sym_bool ? $return_type : $return_type), grammar.rules)
    # add condition rule for easy access when outputing
    if isnothing(idx)
        add_rule!(grammar, :($sym_start = $sym_bool ? $sym_start : $sym_start))
        # add_rule!(grammar, :($return_type = $sym_bool ? $return_type : $return_type))
        idx = length(grammar.rules)
    end


    labels = get_labels(solutions, problem.spec)
    examples = get_examples(labels, problem.spec )
    
    n_predicates = max_predicates
    candidate_program = nothing
    
    symboltable :: SymbolTable = SymbolTable(grammar, Main)
    while n_predicates <= max_predicates
        println("pred: ", n_predicates)
        # predicates = generate_rand_predicates(grammar, sym_bool, n_predicates)
        t = time()
        predicates = enumerate_predicates(grammar, sym_bool, n_predicates)
        features = get_features(grammar, examples, predicates)
        println("time to enum predicates and get features: ", time()-t)
        features = float.(features)

        # init and fit model with features and labels
        model = DecisionTree.DecisionTreeClassifier()
        DecisionTree.fit!(model, features, labels)

        candidate_program = construct_final(model.root.node, idx, solutions, predicates)
        expr = rulenode2expr(candidate_program, grammar)
        # println("final_program expr: ", expr)

        score = evaluate(Problem(examples), expr, symboltable, allow_evaluation_errors=true)
        if score == 1
            candidate_program = freeze_state(candidate_program)
            println("FinishedDT time: ", time() - start_time)
            return (candidate_program, grammar)
        else 
            n_predicates *= 4
        end
    end

    candidate_program = freeze_state(candidate_program)
    println("FinishedDT time: ", time() - start_time)
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

function generate_rand_predicates(
    grammar::AbstractGrammar,
    sym_bool::Symbol,
    n_predicates::Int64
)::Vector{RuleNode}
    # generate random predicates
    predicates = Vector{RuleNode}()
    while length(predicates) < n_predicates
        rand_rn = rand(RuleNode, grammar, sym_bool, 4)
        # if a predicate contains some argument
        if occursin("_arg_", repr(rulenode2expr(rand_rn, grammar)))
            push!(predicates, rand_rn)
        end
    end
    return predicates
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
            println("num:",length(predicates))
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