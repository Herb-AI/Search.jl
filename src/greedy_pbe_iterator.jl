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
)


"""
The state of the iterator is made up of the terms and preds that have been generated
"""
mutable struct PBEIteratorState
    terms::Vector{RuleNode}
    cover::Vector{Set{Int64}}
    preds::Vector{RuleNode}
    preds_gen::Function
    features::Vector{Vector{Float64}}
    start_time::Float64
end


"""
    Base.iterate(
    iterator::GreedyPBEIterator;
)
Starts the iteration for the GreedyPBEIterator. This method will use the subiterator to produce and store n programs that satisfy at least 1 example from the specification.
"""
function Base.iterate(
    iter::GreedyPBEIterator;
)

    subiterator = iter.term_iter
    grammar = get_grammar(iter.solver)
    init_state = copy(subiterator.solver.state)
    subproblems = map(ex -> Problem([ex]), iter.spec)

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

    cover = __make_cover(programs, subproblems, grammar)

    state = PBEIteratorState(
        programs,
        cover,
        Vector{RuleNode}(),
        __stateful_iterator(iter.pred_iter),
        Vector{Vector{Float64}}(undef, length(iter.spec)),
        start_time
    )

    dt = learn_tree!(iter, state)
    return (time() - start_time > iter.max_time) ? nothing : dt
end


function Base.iterate(iter::GreedyPBEIterator, state::PBEIteratorState)
    dt = learn_tree!(iter, state)
    return (time() - state.start_time > iter.max_time) ? nothing : dt
end


function learn_tree!(iter::GreedyPBEIterator, state::PBEIteratorState)
    grammar = get_grammar(iter.solver)

    DT = nothing
    while isnothing(DT)
        new_pred = __next_pred_with_filter!(state, pred -> begin
            input_symbols = collect(keys(iter.spec[1].in))
            pred_expr = rulenode2expr(pred, grammar)
            if typeof(pred_expr) != Expr
                return false
            end
            for sym ∈ pred_expr.args
                if sym ∈ input_symbols
                    return true
                end
            end

            return false
        end)

        #build decision tree
        __update_features!(iter, state, new_pred)
        DT = build_tree(state.terms, state.preds, state.features, state.cover)
    end

    return dt2expr(DT, grammar), state
end

function __make_cover(terms::Vector{RuleNode}, subproblems::Vector{Problem{Vector{IOExample}}}, grammar::AbstractGrammar)::Vector{Set{Int64}}
    cover = Vector{Set{Int64}}()
    for term ∈ terms
        satisfies = Set{Int64}()
        expr = rulenode2expr(term, grammar)
        for (i, example) ∈ enumerate(subproblems)
            sym_table = SymbolTable(grammar)
            if evaluate(example, expr, sym_table, allow_evaluation_errors=true) == 1
                push!(satisfies, i)
            end
        end
        push!(cover, satisfies)
    end
    return cover
end


function __update_features!(iter::GreedyPBEIterator, state::PBEIteratorState, new_pred::RuleNode)
    spec = iter.spec
    grammar = get_grammar(iter.solver)
    xx = state.features

    for (i, ex) ∈ enumerate(spec)
        if !isassigned(xx, i)
            xx[i] = Vector{Float64}()
        end
        try
            push!(xx[i], execute_on_input(grammar, new_pred, ex.in))
        catch exept
            push!(xx[i], 0)
        end
    end
end


function __next_pred!(state::PBEIteratorState)::RuleNode
    pred::RuleNode = freeze_state(state.preds_gen())
    push!(state.preds, pred)
    return pred
end


function __next_pred_with_filter!(state::PBEIteratorState, f)::RuleNode
    pred::RuleNode = freeze_state(state.preds_gen())
    while f(pred) == false
        pred = freeze_state(state.preds_gen())
    end
    push!(state.preds, pred)
    return pred
end


function __stateful_iterator(iter::ProgramIterator)
    state = nothing
    return function ()
        p, state = isnothing(state) ? iterate(iter) : iterate(iter, state)
        return p
    end
end