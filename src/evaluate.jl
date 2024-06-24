struct EvaluationError <: Exception
    expr::Expr
    input::Dict{Symbol, Any}
    error::Exception
end

Base.showerror(io::IO, e::EvaluationError) = print(io, "An exception was thrown while evaluating the expression $(e.expr) on input $(e.input): $(e.error)")

"""
    evaluate(problem::Problem{Vector{IOExample}}, expr::Any, tab::SymbolTable; allow_evaluation_errors::Bool=false)

Evaluate the expression on the examples.

Optional parameters:

    - `shortcircuit` - Whether to stop evaluating after finding single example fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
    - `allow_evaluation_errors` - Whether the search should continue if an exception is thrown in the evaluation or throw the error

Returns a score in the interval [0, 1]
"""
function evaluate(problem::Problem{Vector{IOExample}}, expr::Any, symboltable::SymbolTable; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false)::Number
    number_of_satisfied_examples = 0

    crashed = false
    for example ∈ problem.spec
        try
            output = execute_on_input(symboltable, expr, example.in)
            if (output == example.out)
                number_of_satisfied_examples += 1
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

    return number_of_satisfied_examples/length(problem.spec);
end

"""
    function evaluate_and_collect(problem::Problem{Vector{IOExample}}, expr::Any, symboltable::SymbolTable; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false)::Tuple{Number, Set{Int}}    

Evaluate the expression on the examples.

Optional parameters:

    - `shortcircuit` - Whether to stop evaluating after finding single example fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
    - `allow_evaluation_errors` - Whether the search should continue if an exception is thrown in the evaluation or throw the error

Returns a score in the interval [0, 1] as well as a set of all examples solved
"""
function evaluate_and_collect(problem::Problem{Vector{IOExample}}, expr::Any, symboltable::SymbolTable; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false)::Tuple{Number, Set{Int}}    
    number_of_satisfied_examples = 0

    crashed = false
    examples_solved = Set{Int}()
    for (index, example) ∈ enumerate(problem.spec)
        try
            output = execute_on_input(symboltable, expr, example.in)
            if (output == example.out)
                number_of_satisfied_examples += 1
                push!(examples_solved, index)
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

    return (number_of_satisfied_examples/length(problem.spec), examples_solved);
end
