"""
    get_genetic_enumerator(spec; fitness_function = HerbSearch.default_fitness, initial_population_size = 10, maximum_initial_population_depth = 3, mutation_probability = 0.1, cross_over = HerbSearch.crossover_swap_children_2, select_parents = HerbSearch.select_fitness_proportional_parents, evaluation_function::Function=HerbInterpret.execute_on_input) 

Returns a [`GeneticSearchIterator`](@ref) given a grammar. The iterator is fitted against the examples provided evaluated using the fitness function. All other arguments are hyperparameters for the genetic search procedure.
"""
function get_genetic_enumerator(spec; 
    fitness_function = HerbSearch.default_fitness, 
    initial_population_size = 10,
    maximum_initial_population_depth = 3,
    mutation_probability = 0.1,
    cross_over = HerbSearch.crossover_swap_children_2,
    select_parents = HerbSearch.select_fitness_proportional_parents, 
    evaluation_function::Function=execute_on_input)
    return (grammar, max_depth, max_size, start_symbol) -> begin
        return GeneticSearchIterator(
            grammar = grammar,
            spec = spec,
            fitness = fitness_function,
            cross_over = cross_over,
            mutation! = mutate_random!,
            select_parents = select_parents,
            start_symbol = start_symbol,
            population_size = initial_population_size,
            maximum_initial_population_depth = maximum_initial_population_depth,
            mutation_probability = mutation_probability,
            evaluation_function = evaluation_function
        )
    end

end

