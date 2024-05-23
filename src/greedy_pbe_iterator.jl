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


# """
# The state of the iterator is made up of the terms and preds that have been generated
# """
# mutable struct PBEIteratorState
#     terms::Vector{RuleNode}
#     cover::Vector{Set{Int64}}
#     preds::Vector{RuleNode}
#     preds_gen::Function
#     features::Vector{Vector{Float64}}
#     start_time::Float64
# end


# """
#     Base.iterate(
#     iterator::GreedyPBEIterator;
# )
# Starts the iteration for the GreedyPBEIterator. This method will use the subiterator to produce and store n programs that satisfy at least 1 example from the specification.
# """
# function Base.iterate(
#     iter::GreedyPBEIterator;
# )

#     subiterator = iter.term_iter
#     grammar = get_grammar(iter.solver)
#     init_state = copy(subiterator.solver.state)
#     subproblems = map(ex -> Problem([ex]), iter.spec)

#     start_time = time()
#     programs::Vector{RuleNode} = Vector()
#     for pb ∈ subproblems
#         program, synth_res = synth(pb, subiterator, allow_evaluation_errors=true, max_time=iter.max_time)
#         subiterator.solver.state = copy(init_state)

#         if (time() - start_time > iter.max_time || synth_res == suboptimal_program)
#             return nothing
#         end
#         if synth_res == optimal_program
#             push!(programs, program)
#         end
#     end

#     return (time() - start_time > iter.max_time) ? nothing : dt
# end


# function Base.iterate(iter::GreedyPBEIterator, state::PBEIteratorState)
#     dt = learn_tree!(iter, state)
#     return (time() - state.start_time > iter.max_time) ? nothing : dt
# end

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