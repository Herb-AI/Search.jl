Base.@doc """
    @programiterator AntiunificationIterator

Defines an [`ProgramIterator`](@ref) that iteratively enhances the grammar of another iterator using anti-unification. 

Consists of:
- `max_args::Int`: the maximum number of variable nodes inside a common pattern
- `min_subs::Int`: the minimum number of rulenodes inside a common pattern 
- `min_subs_increase::Int`: the increse in min_subs with each iteraton
- `max_programs_collected::Int`: the maximum number of collected programs
- `subset_size::Int`: the size of the subsets of problems considered for anti-unification
- 'no_repeat_subset_solved::Bool': whether it is allowed to add patterns that solve the same subset of examples between iterations

- `problem::Problem`: the problem definition with IO examples
- `iterator_lambda::Function`: a labda function that creates a instance of the iterator that is going to be used
- `shortcircuit::Bool`:  whether to stop evaluating after finding a single example that fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
- `allow_evaluation_errors::Bool`: whether the search should crash if an exception is thrown in the evaluation
- `max_time::Int`: maximum time that the iterator will run 
- `max_enumerations::Int`: maximum number of iterations that the iterator will run 
- `mod::Module`: a module containing definitions for the functions in the grammar that do not exist in Main

""" AntiunificationIterator
@programiterator AntiunificationIterator(
    max_args::Int = typemax(Int),
    min_subs::Int = 5,
    min_subs_increase::Int = 0,
    max_programs_collected::Int = typemax(Int),
    subset_size::Int = 0,
    no_repeat_subset_solved::Bool = true,

    problem::Problem,
    iterator_lambda::Function,
    shortcircuit::Bool=true, 
    allow_evaluation_errors::Bool=false,
    max_time::Int = typemax(Int),
    max_enumerations::Int = typemax(Int),
    mod::Module=Main
)


"""
    mutable struct IterStateAnti 

Struct used in Base.iterate of AntiunificationIterator. 

Cosists of:
`terminate::Bool`: whether to stop the iteration process
`step::Int`: number of iterations currently
`repreat_subsets::Set{Set{Int}}`: set of all of the subsets of examples based on which rules have been added to the grammar
`enumerations::Int`: current number of enumerations
"""
mutable struct IterStateAnti
    terminate::Bool
    step::Int
    repreat_subsets::Set{Set{Int}}
    enumerations::Int
end

"""
    function _generate_subsets(subsets::Vector{Vector{Int}}, current_subset::Vector{Int}, index::Int , programs_size::Int, subset_size::Int)

Backtracking method used to generate all possible subsets of a certain size.
"""
function _generate_subsets(subsets::Vector{Vector{Int}}, current_subset::Vector{Int}, index::Int , programs_size::Int, subset_size::Int)
    if index <= programs_size
        new_subset = deepcopy(current_subset)
        push!(new_subset, index)
        if length(new_subset) == subset_size
            push!(subsets, new_subset)
        else
            _generate_subsets(subsets, new_subset, index+1, programs_size, subset_size)
        end
        _generate_subsets(subsets, current_subset, index+1, programs_size, subset_size)
    end
end

"""
    function generate_subsets(programs_size:::Int, subset_size::Int)::Vector{Vector{Int}}

Method that generates all subsets of a certain size
"""
function generate_subsets(programs_size::Int, subset_size::Int)::Vector{Vector{Int}}
    current_subset = Vector{Int}()
    subsets = Vector{Vector{Int}}()
    _generate_subsets(subsets, current_subset, 1, programs_size, subset_size)
    return subsets
end


"""
    Base.iterate(iter::AntiunificationIterator)

Describes the iteration for a given [`AntiunificationIterator`](@ref) over the grammar. The iteration constructs a [`ProgramIterator`](@ref) and uses it to generate programs for the process of anti-unification.
"""
function Base.iterate(metaIter::AntiunificationIterator)
    @assert metaIter.subset_size != 1 && metaIter.subset_size >=0 && metaIter.subset_size <= metaIter.max_programs_collected
    grammar = get_grammar(metaIter.solver)
    newIterator = metaIter.iterator_lambda(grammar)
    repreat_subsets = Set{Set{Int}}()

    result = _program_collector(metaIter.subset_size, repreat_subsets, metaIter.max_programs_collected, metaIter.problem, newIterator, metaIter.max_args, metaIter.min_subs, metaIter.shortcircuit, 0, metaIter.allow_evaluation_errors, metaIter.max_time, metaIter.max_enumerations, metaIter.mod)
    state = IterStateAnti(result[2], 1, repreat_subsets, result[3])
    return (result[1], state)
end

"""
    Base.iterate(iter::AntiunificationIterator, state::IterStateAnti)

Describes the iteration for a given [`AntiunificationIterator`](@ref) and `IterStateAnti` over the grammar. The iteration constructs a [`ProgramIterator`](@ref) and uses it to generate programs for the process of anti-unification.
"""
function Base.iterate(metaIter::AntiunificationIterator, state::IterStateAnti)
    if(state.terminate)
        return nothing
    else
        grammar = get_grammar(metaIter.solver)
        newIterator = metaIter.iterator_lambda(grammar)
        if !metaIter.no_repeat_subset_solved
            state.repreat_subsets = Set{Set{int}}()
        end
        result = _program_collector(metaIter.subset_size, state.repreat_subsets, metaIter.max_programs_collected, metaIter.problem, newIterator, metaIter.max_args, metaIter.min_subs + metaIter.min_subs_increase * state.step, metaIter.shortcircuit, state.enumerations, metaIter.allow_evaluation_errors, metaIter.max_time, metaIter.max_enumerations, metaIter.mod)
        state.step+=1
        state.terminate = result[2]
        state.enumerations += result[3]
        return (result[1], state)
    end
end

"""
    function check_rule(newRule::Expr, grammar::AbstractGrammar) :: Bool

Method that generates all subsets of a certain size
"""
function check_rule(newRule::Expr, grammar::AbstractGrammar) :: Bool
    for (index, ruleBody) in enumerate(grammar.rules)
        ruleType = grammar.types[index]
        if ruleBody == newRule.args[2] && ruleType == newRule.args[1]
            return true
        end
    end
    return false
end





"""
    function _program_collector(subset_size::Int, repreat_subsets::Set{Set{Int}}, max_programs_collected::Int, problem::Problem, iterator::ProgramIterator, max_args::Int, min_subs::Int, shortcircuit::Bool, enumerations_total::Int, allow_evaluation_errors::Bool, max_time, max_enumerations, mod::Module)

Function used to generate and evaluate programs. Whenever  max_programs_collected programs have been found the grammar that the iterator uses is enhanced with new rules derived from common patterns.
Consists of:
- `subset_size::Int`: the size of the subsets of problems considered for anti-unification
- 'repreat_subsets::Set{Set{Int}}': set of all of the subsets of examples based on which rules have been added to the grammar
- `max_programs_collected::Int`: the maximum number of collected programs
- `problem::Problem`: the problem definition with IO examples
- `iterator::ProgramIterator`: the iterator that will be used
- `max_args::Int`: the maximum number of variable nodes inside a common pattern
- `min_subs::Int`: the minimum number of rulenodes inside a common pattern
- `shortcircuit::Bool`:  whether to stop evaluating after finding a single example that fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
- `enumerations_total::Int`: current number of enumeration done between all iterations
- `allow_evaluation_errors::Bool`: whether the search should crash if an exception is thrown in the evaluation
- `max_time::Int`: maximum time that the iterator will run 
- `max_enumerations::Int`: maximum number of iterations that the iterator will run 
- `mod::Module`: a module containing definitions for the functions in the grammar that do not exist in Main
"""
function _program_collector(
    subset_size::Int,
    repreat_subsets::Set{Set{Int}},
    max_programs_collected::Int,
    problem::Problem,
    iterator::ProgramIterator,
    max_args::Int = typemax(Int),
    min_subs::Int = 5,
    shortcircuit::Bool=true, 
    enumerations_total::Int=0,
    allow_evaluation_errors::Bool=false,
    max_time = typemax(Int),
    max_enumerations = typemax(Int),
    mod::Module=Main
    
)::Tuple{AbstractRuleNode, Bool, Int}
    start_time = time()
    grammar = get_grammar(iterator.solver)
    symboltable :: SymbolTable = SymbolTable(grammar, mod)
    best_score = 0
    best_program = nothing

    current_enumerations = 0
    examples_solved_total = Set{Int}()
    program_example_solved = Vector{Set{Int}}()
    programs_collected = Vector{RuleNode}()

    for (i, candidate_program) ∈ enumerate(iterator)
        current_enumerations = i
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(candidate_program, grammar)


        if best_program === nothing
            best_program = freeze_state(candidate_program)
        end
        
        # Evaluate the expression
        score, examples_solved = evaluate_and_collect(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
        if score == 1
            #if a solution is found return it
            candidate_program = freeze_state(candidate_program)
            return (candidate_program, true, current_enumerations)
        elseif score != 0
            #save the program that solves at least one example
            examples_solved_total = union(examples_solved_total, examples_solved)
            push!(program_example_solved, examples_solved)
            candidate_program = freeze_state(candidate_program)

            #retain the best program found
            if(best_score < score)
                best_score = score
                best_program = candidate_program
            end

            push!(programs_collected, candidate_program)
            
            #check if enought programs have been collected
            if length(problem.spec) == length(examples_solved_total) || length(programs_collected) == max_programs_collected
               
                if subset_size == 0
                    subset_size = max_programs_collected
                end


                #generate all subsets of posiible programs
                subsets = generate_subsets(length(programs_collected), subset_size)
                new_rules = 0


                for subset ∈ subsets
                    programs_subset = Vector{RuleNode}()
                    examples_solved_subset = Set{Int}()
                    
                    #calculate the union of solved examples and the subset of solved problems
                    for index ∈ subset
                        push!(programs_subset, programs_collected[index])
                        examples_solved_subset = union(examples_solved_subset, program_example_solved[index])
                    end
                    
                    #check if the subset of examples has been solved
                    if examples_solved_subset ∈ repreat_subsets
                        continue
                    end
                    
                    #generate dublicate patterns
                    dublicates = calculate_dublicates_rule_nodes(programs_subset, max_args, min_subs)

                    for pattern in dublicates
                        #generate new rule
                        tree = pattern[1]
                        ruleNode = createRuleNodeFromTree(tree)
                        newRule = transform_to_grammr_rule(ruleNode, grammar)
                        
                        #check if rule is already in the grammar
                        if check_rule(newRule, grammar) 
                            continue
                        end
                        
                        #add rule and constraint
                        add_rule!(grammar, newRule)
                        addconstraint!(grammar, create_constraint(ruleNode))
                        new_rules += 1
                        push!(repreat_subsets, examples_solved_subset)
                    end
                end

                #Check if new rules were added to the grammar
                if new_rules != 0
                    return (best_program, false, current_enumerations)
                else
                    programs_collected = Vector{RuleNode}()
                    examples_solved_total = Set{Int}()
                end
            end
        end
        

        # Check stopping criteria
        if enumerations_total + i > max_enumerations || time() - start_time > max_time
            break;
        end
    end

    # The enumeration exhausted, but an optimal problem was not found
    return (best_program, true, current_enumerations)
end

