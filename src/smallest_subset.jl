"""
satisfies_examples(problem::Problem{Vector{IOExample}}, expr::Any, tab::SymbolTable; allow_evaluation_errors::Bool=false)

Evaluate the expression on the examples.

Optional parameters:

    - `shortcircuit` - Whether to stop evaluating after finding single example fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
    - `allow_evaluation_errors` - Whether the search should continue if an exception is thrown in the evaluation or throw the error

Returns set of IOexamples indexes it satisfies.
"""
function satisfies_examples(problem::Problem{Vector{IOExample}}, expr::Any, symboltable::SymbolTable; shortcircuit::Bool=false, allow_evaluation_errors::Bool=true)::Set{Number}
    satisfied = Set{Number}()
    for (i, example) ∈ enumerate(problem.spec)
        try
            output = execute_on_input(symboltable, expr, example.in)
            if (output == example.out)
                push!(satisfied, i)
            elseif (shortcircuit)
                break;
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

@enum SubsetSearchResult full_cover=1 incomplete_cover=2


"""
find_smallest_subset(U::Set{Number}, expr::Any, programs::Vector{Tuple{RuleNode, Set{Number}}})

Finds smallest subset that satisfies the examples in U.

Parameters:
    - `U` - Set of examples needed to be satisified
    - `programs` - Collection of programs and its corresponding set of examples it satisfies

Returns the minimal set of programs and result if the algorithm managed to find coverage for all programs.
"""
function find_smallest_subset(
    U::Set{Number},
    programs::Vector{Tuple{RuleNode, Set{Number}}}
)::Tuple{Vector{Tuple{RuleNode, Set{Number}}}, SubsetSearchResult}
    sort!(programs, by=x -> length(x[2]), rev=true)
    indexes, result = greedy_set_cover(U, map(t -> t[2], programs))

    subset_programs = Vector{Tuple{RuleNode, Set{Number}}}()
    for idx in indexes
        push!(subset_programs, programs[idx])
    end
    return (subset_programs, result)
end

"""
smallest_subset(problem::Problem, iterator::ProgramIterator; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false, max_time = typemax(Int), max_enumerations = typemax(Int), mod::Module=Main)::Tuple{Vector{RuleNode}, SubsetSearchResult}

Synthesize a smallest subset of program that satisfies the maximum number of examples in the problem.
        - problem                 - The problem definition with IO examples
        - iterator                - The iterator that will be used
        - shortcircuit            - Whether to stop evaluating after finding a single example that fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
        - allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
        - max_time                - Maximum time that the iterator will run 
        - max_enumerations        - Maximum number of iterations that the iterator will run 
        - mod                     - A module containing definitions for the functions in the grammar that do not exist in Main

Returns a tuple of vector of the rulenodes representing the smallest subset of programs and a synthresult that indicates if that program is optimal. `smallest_subset` uses `synth` which iterates over all possible programs until max_enumerations or max_time is reached and then finds smallest subset from the programs that satisfy maximum number of examples.
"""
function smallest_subset(
    problem::Problem,
    iterator::ProgramIterator;
    shortcircuit::Bool=false, 
    allow_evaluation_errors::Bool=true,
    max_time = typemax(Int),
    max_enumerations = typemax(Int),
    mod::Module=Main
)::Tuple{Vector{Tuple{RuleNode, Set{Number}}}, SubsetSearchResult}
    start_time = time()
    grammar = get_grammar(iterator.solver)
    
    symboltable :: SymbolTable = SymbolTable(grammar, mod)

    programs = Vector{Tuple{RuleNode, Set{Number}}}()

    for (i, candidate_program) ∈ enumerate(iterator)

        expr = rulenode2expr(candidate_program, grammar)
        correct_examples = satisfies_examples(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
        
        if length(correct_examples) == length(problem.spec)
            candidate_program = freeze_state(candidate_program)
            println("satisfies all: ", correct_examples)
            return (([(candidate_program, correct_examples)]), full_cover)
        elseif length(correct_examples) > 0
            candidate_program = freeze_state(candidate_program)
            push!(programs, (candidate_program, correct_examples))
        end

        if i > max_enumerations || time() - start_time > max_time
            println("stoping: ")
            break;
        end
    end
    return find_smallest_subset(Set{Number}(1:length(problem.spec)), programs)
end


"""
greedy_set_cover(U::Set{Number}, S::Vector{Set{Number}})::Tuple{Vector{Number}, SubsetSearchResult}

Uses greedy polynomial time approximation algorithm to find a set covering for U using S. This function is used by find_smallest_subset function.
        - U - represents the universe of elements to be covered.
        - S - represents the collection of sets
Returns the set C containing indexes of sets which is the approximate solution to the set cover problem.
"""
function greedy_set_cover(U::Set{Number}, S::Vector{Set{Number}})::Tuple{Vector{Number}, SubsetSearchResult}
    U_covered = Set{Number}()
    C = Vector{Number}() 
    
    while U_covered != U
        max_set = Set{Number}()
        idx = -1
        for (i, s) in enumerate(S)
            if length(setdiff(s, U_covered)) > length(max_set)
                max_set = s
                idx = i
            end
        end

        if idx == -1
            return (C, incomplete_cover)
        end
        push!(C, idx) 
        union!(U_covered, max_set)
    end
    
    return (C, full_cover)
end

