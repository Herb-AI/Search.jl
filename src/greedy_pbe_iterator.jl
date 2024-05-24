Base.@doc """
    GreedyPBEIterator <: ProgramIterator

Defines an [`ProgramIterator`](@ref), that greedly generates a program for each IOExample, given an iterator. 

Consists of:
- `examples::Vector{<:IOExample}`: a collection of examples defining the specification 
- `subiterator::ProgramIterator`: a user-provided iterator instance that can find programs which satisfy individual examples
end
""" GreedyPBEIterator
@programiterator GreedyPBEIterator(
    spec::Vector{<:IOExample},
    term_iter::ProgramIterator,
    pred_iter::ProgramIterator,
    max_time::Float64 = 60.0
) <: DivideConquerIterator

function Base.iterate(iter::GreedyPBEIterator)
    try
        start_time = time()
        AST = DecisionTreeAST(iter)
        learn_tree!(AST)
        if time() - start_time > iter.max_time
            return nothing
        end
        return dt2expr(AST), AST
    catch
        return nothing
    end
end

function Base.iterate(::GreedyPBEIterator, state::DecisionTreeAST)
    try
        start_time = time()
        learn_tree!(AST)
        if time() - start_time > iter.max_time
            return nothing
        end
        return dt2expr(AST), AST
    catch
        return nothing
    end
end


function get_spec(iter::GreedyPBEIterator)::Vector{IOExample}
    return iter.spec
end

function get_pred_iter(iter::GreedyPBEIterator)::ProgramIterator
    return iter.pred_iter
end

function initial_programs(iter::GreedyPBEIterator, examples::Vector{IOExample})::Union{Nothing,Vector{RuleNode}}
    subiterator = iter.term_iter
    init_state = copy(subiterator.solver.state)
    subproblems = map(ex -> Problem([ex]), examples)

    start_time = time()
    programs::Vector{RuleNode} = Vector()
    for pb ∈ subproblems
        program, synth_res = synth(pb, subiterator, allow_evaluation_errors=true, max_time=iter.max_time)
        subiterator.solver.state = copy(init_state)

        if (time() - start_time > iter.max_time || synth_res == suboptimal_program)
            return nothing
        end
        if synth_res == optimal_program
            push!(programs, program)
        end
    end

    return programs
end