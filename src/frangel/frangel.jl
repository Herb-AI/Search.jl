"""
    struct FrAngelConfigGeneration

A configuration struct for FrAngel generation.

# Fields
- `max_size::Int`: The maximum size of the generated program.
- `use_fragments_chance::Float16`: The chance of using fragments during generation.
- `use_entire_fragment_chance::Float16`: The chance of using the entire fragment during replacement over modifying a program's children.
- `use_angelic_conditions_chance::Float16`: The chance of using angelic conditions during generation.
- `similar_new_extra_size::Int`: The extra size allowed for newly generated children during replacement.
- `gen_similar_prob_new::Float16`: The chance of generating a new child / replacing a node randomly. 

"""
@kwdef struct FrAngelConfigGeneration
    max_size::Int = 40
    use_fragments_chance::Float64 = 0.5
    use_entire_fragment_chance::Float16 = 0.5
    use_angelic_conditions_chance::Float16 = 0.5
    similar_new_extra_size::Int = 8
    gen_similar_prob_new::Float16 = 0.25
end

"""
    struct FrAngelConfigAngelic

A configuration struct for the angelic mode of FrAngel.

# Fields
- `max_time::Float16`: The maximum time allowed for resolving angelic conditions.
- `boolean_expr_max_size::Int`: The maximum size of boolean expressions when resolving angelic conditions.
- `max_execute_attempts::Int`: The maximal attempts of executing the program with angelic evaluation.
- `max_allowed_fails::Float16`: The maximum allowed fraction of failed tests during evaluation before short-circuit failure.

"""
@kwdef struct FrAngelConfigAngelic
    max_time::Float16 = 0.1
    boolean_expr_max_size::Int = 6
    max_execute_attempts::Int = 55
    max_allowed_fails::Float16 = 0.3
end

"""
    struct FrAngelConfig

The full configuration struct for FrAngel. Includes generation and angelic sub-configurations.

# Fields
- `max_time::Float16`: The maximum time allowed for execution of whole iterator.
- `generation::FrAngelConfigGeneration`: The generation configuration for FrAngel.
- `angelic::FrAngelConfigAngelic`: The configuration for angelic conditions of FrAngel.

"""
@kwdef struct FrAngelConfig
    max_time::Float16 = 5
    generation::FrAngelConfigGeneration = FrAngelConfigGeneration()
    angelic::FrAngelConfigAngelic = FrAngelConfigAngelic()
end

function frangel(
    spec::AbstractVector{<:IOExample}, 
    config::FrAngelConfig, 
    angelic_conditions::AbstractVector{Union{Nothing,Int}},
    iter::ProgramIterator
)
    remembered_programs = Dict{BitVector,Tuple{RuleNode,Int,Int}}()
    fragments = Vector{RuleNode}() # TODO: change it to vector everywhere
    grammar = iter.grammar

    rule_minsize = rules_minsize(grammar) 
    
    symbol_minsize = symbols_minsize(grammar, rule_minsize)
    add_fragments_prob!(grammar, config.generation.use_fragments_chance)
    fragments_offset = length(grammar.rules)
    state = nothing
    symboltable = SymbolTable(grammar)
    start_time = time()

    while time() - start_time < config.max_time
        # Generate random program
        program, state = (state === nothing) ? iterate(iter) : iterate(iter, state)

        # Generalize these two procedures at some point
        program = modify_and_replace_program_fragments!(program, fragments, fragments_offset, config.generation, grammar, rule_minsize, symbol_minsize)
        program = add_angelic_conditions!(program, grammar, angelic_conditions, config.generation)

        passed_tests = BitVector([false for _ in spec])
        # If it does not pass any tests, discard
        get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        if !any(passed_tests)
            continue
        end
        # If it contains angelic conditions, resolve them
        if contains_hole(program)
            resolve_angelic!(program, fragments, passed_tests, grammar, symboltable, spec, 1, angelic_conditions, config)
            # Still contains angelic conditions -> unresolved
            if contains_hole(program)
                continue
            end
            get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        end

        # Simplify and rerun over examples
        # TODO program = simplify_quick(program, grammar, spec, passed_tests)
        get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        
        # Early return -> if it passes all tests, then final round of simplification and return
        if all(passed_tests)
            # TODO program = simplify_slow(program, grammar, spec, angelic_conditions, (time() - start_time) / 10)
            return simplify_quick(program, grammar, spec, passed_tests)
        end

        # Update grammar with fragments
        fragments = remember_programs!(remembered_programs, passed_tests, program, fragments, grammar, config, fragments_offset)
    end
end

@programiterator Prob()

function Base.iterate(iter::Prob, state=nothing)
    rule_minsize = rules_minsize(iter.grammar) 
    
    symbol_minsize = symbols_minsize(iter.grammar, rule_minsize)

    return prob_sample(iter.grammar, iter.sym, rule_minsize, symbol_minsize), nothing
end

function prob_sample(grammar::AbstractGrammar, symbol::Symbol, rule_minsize::AbstractVector{Int}, symbol_minsize::Dict{Symbol,Int}, max_size=40)
    max_size = max(max_size, symbol_minsize[symbol])
    
    rules_for_symbol = grammar[symbol]
    log_probs = grammar.log_probabilities
    filtered_indices = filter(i -> return_type(grammar, rules_for_symbol[i]) == symbol && rule_minsize[rules_for_symbol[i]] ≤ max_size, eachindex(rules_for_symbol))
    
    possible_rules = [rules_for_symbol[i] for i in filtered_indices]
    weights = Weights(exp.(log_probs[filtered_indices]))
    
    rule_index = StatsBase.sample(possible_rules, weights)
    rule_node = RuleNode(rule_index)

    if !grammar.isterminal[rule_index]
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)

        for (index, child_type) in enumerate(child_types(grammar, rule_index))
            push!(rule_node.children, prob_sample(grammar, child_type, rule_minsize, symbol_minsize, sizes[index]))
        end
    end

    rule_node
end