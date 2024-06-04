Base.@doc """
    GreedyPBEIterator <: ProgramIterator

Defines an [`ProgramIterator`](@ref), that greedly generates a program for each IOExample, given an iterator. 

Consists of:
- `examples::Vector{<:IOExample}`: a collection of examples defining the specification 
- `subiterator::ProgramIterator`: a user-provided iterator instance that can find programs which satisfy individual examples
end
""" GreedyPBEIterator
@programiterator mutable GreedyPBEIterator(
    spec::Vector{<:IOExample},
    term_iter::ProgramIterator,
    pred_iter::ProgramIterator,
    max_enumerations::Int=10000,
    max_time::Float64=60.0,
    mod::Module=Main
) <: DivideConquerIterator

function Base.iterate(iter::GreedyPBEIterator)
    try
        AST = DecisionTreeAST(iter, pred_batch_size=2000)
        learn_tree!(AST)
        return dt2expr(AST), AST
    catch ex
        if ex isa DecisionTreeError
            showerror(stdout, ex)
        else
            rethrow(ex)
        end
        return nothing
    end
end

function Base.iterate(::GreedyPBEIterator, state::DecisionTreeAST)
    try
        learn_tree!(AST)
        return dt2expr(AST), AST
    catch ex
        if ex isa DecisionTreeError
            showerror(stdout, ex)
        else
            throw(ex)
        end
        return nothing
    end
end


function get_spec(iter::GreedyPBEIterator)::Vector{IOExample}
    return iter.spec
end

function get_pred_iter(iter::GreedyPBEIterator)::ProgramIterator
    return iter.pred_iter
end

function initial_programs!(iter::GreedyPBEIterator, examples::Vector{IOExample})::Union{Nothing,Vector{RuleNode}}
    g = get_grammar(iter.solver)
    sym_table = SymbolTable(g, iter.mod)
    subiterator = iter.term_iter
    subproblems = map(ex -> Problem([ex]), examples)

    start_time = time()
    programs::Vector{RuleNode} = Vector()
    unsolved = Set{Int64}(1:length(subproblems))
    for prog ∈ subiterator
        #check which examples it solves
        expr = rulenode2expr(prog, g)
        cover = Set{Int64}()
        for (prob_idx, pb) ∈ enumerate(subproblems)
            how_many = evaluate(pb, expr, sym_table, allow_evaluation_errors=true)
            if how_many == 1
                push!(cover, prob_idx)
            end
        end

        #check if it solves anything new
        what_it_solves = intersect(cover, unsolved)
        if length(what_it_solves) > 0
            push!(programs, freeze_state(prog))
            setdiff!(unsolved, what_it_solves)
        end

        #stopping criteria
        if iter.max_enumerations == 0 || time() - start_time > iter.max_time
            return nothing
        elseif length(unsolved) == 0
            return programs
        end
        iter.max_enumerations -= 1
    end

    return programs
end



# Proof of concept: Limited iterators
# This type can convert any program iterator into an iterator with a fixed number of enumerations
# It is essentially a decorator
struct LimitedIterator <: ProgramIterator
    iter::ProgramIterator
    max_enumerations::Int64
end

function Base.iterate(iterator::LimitedIterator)
    if iterator.max_enumerations == 0
        return nothing
    end
    next, state = Base.iterate(iterator.iter)
    return next, (1, state)
end

function Base.iterate(iterator::LimitedIterator, state::Tuple{Int64, Any})
    if iterator.max_enumerations <= state[1]
        return nothing
    end
    next, new_state = Base.iterate(iterator.iter, state[2])
    return next, (1 + state[1], new_state)
end