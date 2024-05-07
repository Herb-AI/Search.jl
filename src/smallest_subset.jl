struct EvaluationError <: Exception
    expr::Expr
    input::Dict{Symbol, Any}
    error::Exception
end

Base.showerror(io::IO, e::EvaluationError) = print(io, "An exception was thrown while evaluating the expression $(e.expr) on input $(e.input): $(e.error)")

"""
satisfies_examples(problem::Problem{Vector{IOExample}}, expr::Any, tab::SymbolTable; allow_evaluation_errors::Bool=false)

Evaluate the expression on the examples.

Optional parameters:

    - `shortcircuit` - Whether to stop evaluating after finding single example fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
    - `allow_evaluation_errors` - Whether the search should continue if an exception is thrown in the evaluation or throw the error

Returns indexes of IOexamples it satisfies.
"""
function satisfies_examples(problem::Problem{Vector{IOExample}}, expr::Any, symboltable::SymbolTable; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false)::Vector{Number}
    crashed = false
    satisfied = Vector{Number}()
    for (i, example) ∈ enumerate(problem.spec)
        try
            output = execute_on_input(symboltable, expr, example.in)
            if (output == example.out)
                push!(satisfied, i)
            elseif (shortcircuit)
                break;
            end
        catch e
            # You could also decide to handle less severe errors (such as index out of range) differently,
            # for example by just increasing the error value and keeping the program as a candidate.
            crashed = true
            # Throw the error again if evaluation errors aren't allowed
            eval_error = EvaluationError(expr, example.in, e)
            allow_evaluation_errors || throw(eval_error)
            break
        end
    end
    return satisfied
end


@enum SynthResult optimal_program=1 suboptimal_program=2

function smallest_subset(
    problem::Problem,
    iterator::ProgramIterator;
    shortcircuit::Bool=true, 
    allow_evaluation_errors::Bool=false,
    max_time = typemax(Int),
    max_enumerations = typemax(Int),
    mod::Module=Main
)::Vector{Tuple{RuleNode, Vector{Number}}}
    start_time = time()
    symboltable :: SymbolTable = SymbolTable(iterator.grammar, mod)

    programs = Vector{Tuple{RuleNode, Vector{Number}}}()

    for (i, candidate_program) ∈ enumerate(iterator)
        println("i: ",i)
        expr = rulenode2expr(candidate_program, iterator.grammar)
        correct_examples = satisfies_examples(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
        # println("length(correct_examples): ", length(correct_examples))
        if length(correct_examples) == length(problem.spec)
            println("return - all correct")
            return Vector{RuleNode}([(candidate_program, correct_examples)])
        elseif length(correct_examples) > 0
            println("push to programs")
            push!(programs, (candidate_program, correct_examples))
        end
        if i > max_enumerations || time() - start_time > max_time
            println("time limit or max enums")
            break;
        end
        # println("end")
    end
    # println("endloop")
    # for p in programs
    #     println(rulenode2expr(p, iterator.grammar))
    # end
    # println("programs")
    # println(programs)
    return programs
end