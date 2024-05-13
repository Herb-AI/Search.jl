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
    subiterator::ProgramIterator
)


"""
    Base.iterate(
    iterator::GreedyPBEIterator;
)
Starts the iteration for the GreedyPBEIterator. This method will use the subiterator to produce and store n programs that satisfy at least 1 example from the specification.
"""
function Base.iterate(
    iterator::GreedyPBEIterator;
)

    subiterator = iterator.subiterator
    init_state = copy(subiterator.solver.state)
    subproblems = map(ex -> Problem([ex]), iterator.spec)

    programs::Vector{RuleNode} = Vector()
    for pb ∈ subproblems
        res = synth(pb, subiterator)
        subiterator.solver.state = copy(init_state)
        if res[2] == optimal_program
            push!(programs, res[1])
        end
    end

    return programs, copy(programs)
end

function Base.iterate(iter::GreedyPBEIterator, terms::Vector{RuleNode})
    return (terms, terms)
end