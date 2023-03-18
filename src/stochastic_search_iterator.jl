using Random


"""
MetropolisHastingsEnumerator(grammar::Grammar, max_depth::Int, sym::Symbol, examples::AbstractVector{Example}, neighbourhood::Function)
neighbourhood should be a function which takes two parameters: current program and grammar, and should return nodeLoc ...
An iterator over all possible expressions of a grammar up to max_depth with start symbol sym.
"""
Base.@kwdef mutable struct StochasticSearchEnumerator <: ExpressionIterator
    grammar::ContextFreeGrammar
    max_depth::Int64 = 5  # maximum depth of the program that is generated
    examples::Vector{Example}
    neighbourhood::Function
    propose::Function
    accept::Function
    temperature::Function
    cost_function::Function
    start_symbol::Symbol
end

Base.@kwdef struct IteratorState
    current_program::RuleNode
    current_temperature::Float32
    best_program::RuleNode
    best_program_cost::Float32
end

Base.IteratorSize(::StochasticSearchEnumerator) = Base.SizeUnknown()
Base.eltype(::StochasticSearchEnumerator) = RuleNode

function Base.iterate(iter::StochasticSearchEnumerator)
    grammar, max_depth = iter.grammar, iter.max_depth
    node = rand(RuleNode, grammar, iter.start_symbol, max_depth)

    current_cost = calculate_cost(node, iter.cost_function, iter.examples, iter.grammar)

    # TODO change current best cost
    return (node, IteratorState(current_program = node, current_temperature = 1, best_program = node,best_program_cost=current_cost))
end



function Base.iterate(iter::StochasticSearchEnumerator, current_state::IteratorState)
    grammar, examples = iter.grammar, iter.examples
    neighbourhood_node_location, dict = iter.neighbourhood(current_state.current_program, grammar)

    new_temperature = iter.temperature(current_state.current_temperature)

    current_program = current_state.current_program
    subprogram = get(current_program, neighbourhood_node_location)
    # save copy because propose might change program
    current_cost = calculate_cost(current_program, iter.cost_function, examples, grammar)
    new_program = deepcopy(current_program)

    @info "Start: $(rulenode2expr(current_program, grammar)), subexpr: $(rulenode2expr(subprogram, grammar)), cost: $current_cost"

    # propose new programs to consider
    possible_replacements = iter.propose(current_program, neighbourhood_node_location, grammar, iter.max_depth, dict)
    possible_program = current_program
    best_replacement = nothing
    for possible_replacement in possible_replacements
        # @info "Replacement: $(rulenode2expr(possible_replacement, grammar))"
        # replace node at node_location with new_random 
        if neighbourhood_node_location.i == 0
            possible_program = possible_replacement
            # @info "Replacing the root entirely"
        else 
            # update current_program with the subprogram generated
            neighbourhood_node_location.parent.children[neighbourhood_node_location.i] = possible_replacement
        end
        program_cost = calculate_cost(possible_program, iter.cost_function, examples, grammar)
        # @info "Possible program: $(rulenode2expr(possible_program, grammar)), $(program_cost)"
        if iter.accept(current_cost, program_cost)
            new_program = deepcopy(possible_program)
            current_cost = program_cost
            best_replacement = deepcopy(possible_replacement)
        end
    end
    if best_replacement !== nothing
        @info "Best replace: $(rulenode2expr(best_replacement, grammar)) => Cost : $current_cost"
    else 
        @info "Can't find better"
    end
    @info "================"
    if current_cost < current_state.best_program_cost
        next_state = IteratorState(
            current_program=new_program, 
            current_temperature=new_temperature,
            best_program=new_program, 
            best_program_cost=current_cost)
    else
        next_state = IteratorState(
            current_program=new_program, 
            current_temperature=new_temperature,
            best_program=current_state.best_program, 
            best_program_cost=current_state.best_program_cost)
    end

    return (new_program, next_state)
end

function calculate_cost(program::RuleNode, cost_function::Function, examples::AbstractVector{Example}, grammar::Grammar)
    results = Tuple{Int64, Int64}[]
    expression = rulenode2expr(program,grammar)
    symbol_table = SymbolTable(grammar)
    for example ∈ filter(e -> e isa IOExample, examples)
        outcome = HerbEvaluation.test_with_input(symbol_table, expression, example.in)
        push!(results, (example.out, outcome))
    end
    return cost_function(results)
end