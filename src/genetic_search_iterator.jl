using Random

Base.@kwdef mutable struct GeneticSearchIterator <: ExpressionIterator
    grammar::ContextFreeGrammar
    examples::Vector{IOExample}
    fitness::Function
    cross_over::Function
    mutation!::Function
    stopping_condition::Function
    
    start_symbol::Symbol
    max_depth::Int64 = 5  # maximum depth of the program that is generated
    population_size::Int64 = 10
    cross_over_probability::Float64
    mutation_probability::Float64
    
end

Base.@kwdef struct GeneticIteratorState
    population::Vector{RuleNode}
    best_programs::Vector{RuleNode}
    best_program_fitnesses::Vector{Float64}
    iteration_number::Int64 = 0
end

Base.IteratorSize(::GeneticSearchIterator) = Base.SizeUnknown()
Base.eltype(::GeneticSearchIterator) = RuleNode

function get_best_program_and_fitness(population, fitness)
    best_program = nothing
    best_fitness = 0
    
    for i in 1:length(population)
        chromosome = population[i]
        # Find the fitness for the current chromosome.
        fitness_value = fitness(chromosome)  
        if i == 1
            best_fitness = fitness_value
            best_program = chromosome
        else 
            # Update best program if a greater fitness has been found.  
            if fitness_value > best_fitness
                best_fitness = fitness_value
                best_program = chromosome
            end
        end
    end 
    return (best_program, best_fitness)
end
function Base.iterate(iter::GeneticSearchIterator)
    grammar, max_depth = iter.grammar, iter.max_depth
    
    # sample a random node using start symbol and grammar
    
    population = rand_nodes(grammar, iter.start_symbol, max_depth,iter.population_size)
    # println(iter.population_size) 
    best_program, best_fitness = get_best_program_and_fitness(population, iter.fitness)
    return iterate(iter, GeneticIteratorState(
        population=population,
        best_programs=[best_program],
        best_program_fitnesses=[best_fitness],
        iteration_number=0))
end


function Base.iterate(iter::GeneticSearchIterator, current_state::GeneticIteratorState)
    
    grammar, examples = iter.grammar, iter.examples
    
    # if the stopping condition is true then return
    best_fitness = current_state.best_program_fitnesses[length(current_state.best_program_fitnesses)]
    if (iter.stopping_condition(current_state.iteration_number, best_fitness))
        return current_state
    end
    
    population = current_state.population

    # Calculate fitness
    fitness_array = [iter.fitness(chromosome) for chromosome in population]
    sum_of_fitness = sum(fitness_array)
    fitness_array = [fitness_value/sum_of_fitness for fitness_value in fitness_array]
    
    # Select the chromosomes for the next generation based on the fitnesses.  
    chromosome_array = []
    while length(chromosome_array) != trunc(Int, iter.population_size/2)
        selected_chromosome = select_chromosome(fitness_array, population)
        push!(chromosome_array, selected_chromosome)
        for j in 1:length(population)
        
            if (population[j] == selected_chromosome)
                deleteat!(population, j)
                deleteat!(fitness_array, j)
                fitness_array = [fitness_value * sum_of_fitness for fitness_value in fitness_array]
                sum_of_fitness = sum(fitness_array)
                fitness_array = [fitness_value/sum_of_fitness for fitness_value in fitness_array]
                break
            end
        end
    end
    
    # Crossover with neighbours. 
    
    new_population = []
    for i in 1 : length(chromosome_array)
        j = i + 1
        if j > length(chromosome_array)
            j = 1
        end

        
        chromosome1, chromosome2 = iter.cross_over(chromosome_array[i], chromosome_array[j], iter.fitness)

        push!(new_population, chromosome1)
        push!(new_population, chromosome2)

    end
    

    # Introduce mutation if the probability allows it 
    
    for chromosome in new_population
        random_number = rand()
        if random_number < iter.mutation_probability
            iter.mutation!(chromosome, iter.grammar)
        end
    end

    best_program, best_fitness = get_best_program_and_fitness(new_population, iter.fitness)
    
    push!(current_state.best_programs, best_program)
    push!(current_state.best_program_fitnesses, best_fitness)

    return iterate(iter, GeneticIteratorState(
        population=new_population,
        best_programs=current_state.best_programs,
        best_program_fitnesses=current_state.best_program_fitnesses,
        iteration_number=current_state.iteration_number + 1))
end

function select_chromosome(fitness_array, population)
    random_number = rand()        
    current_fitness_sum = 0
    for (fitness_value,chromosome) in zip(fitness_array,population)
        # random number between 0 and 1
        current_fitness_sum += fitness_value
        if random_number < current_fitness_sum
            return chromosome
        end
    end 
end


"""
Returns the cost of the `program` using the examples and the `cost_function`. It first convert the program to an expression and
evaluates it on all the examples.
"""
function calculate_cost(program::RuleNode, cost_function::Function, examples::AbstractVector{Example}, grammar::Grammar)
    results = Tuple{Int64,Int64}[]
    expression = rulenode2expr(program, grammar)
    symbol_table = SymbolTable(grammar)
    for example ∈ filter(e -> e isa IOExample, examples)
        outcome = HerbEvaluation.test_with_input(symbol_table, expression, example.in)
        push!(results, (example.out, outcome))
    end
    return cost_function(results)
end

function calculate_cost(program::RuleNode, examples::AbstractVector{Example}, grammar::Grammar)
    results = Tuple{Int64,Int64}[]
    expression = rulenode2expr(program, grammar)
    symbol_table = SymbolTable(grammar)
    for example ∈ filter(e -> e isa IOExample, examples)
        outcome = HerbEvaluation.test_with_input(symbol_table, expression, example.in)
        push!(results, (example.out, outcome))
    end
    return results
end

# Construct the initial population at random
function rand_nodes(grammar, start_symbol, max_depth, population_size) 
    
    
    cfe = ContextFreeEnumerator(grammar, max_depth, start_symbol)
    size = count_expressions(grammar, max_depth, start_symbol)
    population = Vector{RuleNode}(undef, population_size)
    
    for i in 1:population_size
        
        population[i] = collect(cfe)[rand(0:size)]
        
    end
    return population
end
