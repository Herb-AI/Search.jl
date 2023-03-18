function get_mh_enumerator(grammar, examples, max_depth, start_symbol, cost_function)
    return StochasticSearchEnumerator(
        grammar = grammar,
        examples = examples,
        max_depth = max_depth,
        neighbourhood = constructNeighbourhood,
        propose = random_fill_propose,
        temperature = const_temperature,
        accept = probabilistic_accept,
        cost_function = cost_function,
        start_symbol = start_symbol,
    )
end

function get_vlsn_enumerator(grammar, examples, max_depth, start_symbol, cost_function)
    return StochasticSearchEnumerator(
        grammar = grammar,
        examples = examples,
        max_depth = max_depth,
        neighbourhood = constructNeighbourhoodRuleSubset,
        propose = enumerate_neighbours_propose,
        temperature = const_temperature,
        accept = best_accept,
        cost_function = cost_function,
        start_symbol = start_symbol,
    )
end