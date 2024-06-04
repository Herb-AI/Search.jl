using HerbBenchmarks, HerbBenchmarks.PBE_SLIA_Track_2019, HerbBenchmarks.PBE_BV_Track_2018

function timeout(f, args, seconds)
    # Start the worker task in a separate thread
    worker_thread = Threads.@spawn begin
        try
            f(args)
        catch
            return nothing
        end
    end

    sleep(seconds)

    sol = nothing
    # Cancel the worker task if it is still running
    if !istaskdone(worker_thread)
        println("Intrerupting task...")
        Base.throwto(worker_thread, InterruptException())
    else
        sol = fetch(worker_thread)
    end

    return sol
end

# @testset "Testing the greedy PBE iterator" verbose = true begin
#     g = @cfgrammar begin
#         Number = |(0:1)
#         Number = x
#         Number = Number + Number
#         Number = Number * Number
#         nBool = (nBool || nBool) | (nBool && nBool) | (!nBool) | (Number < Number) | (Number > Number) | (Number == Number)
#     end

#     @testset "Producing initial programs" begin
#         examples = [IOExample(Dict(:x => x), x * x + 1) for x ∈ 1:5]

#         term_iter = BFSIterator(g, :Number)
#         pred_iter = BFSIterator(g, :nBool)
#         pbe_iterator = GreedyPBEIterator(g, :Number, examples, term_iter, pred_iter)

#         for (i, prog) ∈ enumerate(pbe_iterator)
#             println(prog)
#             break
#         end
#         println("---------------------")
#     end

#     @testset "Synthesize max function" begin

#         examples = [IOExample(Dict(:x => x), max(x, 0) + 1) for x ∈ -5:5]

#         term_iter = BFSIterator(g, :Number)
#         pred_iter = BFSIterator(g, :nBool)
#         pbe_iterator = GreedyPBEIterator(g, :Number, examples, term_iter, pred_iter)

#         for (i, prog) ∈ enumerate(pbe_iterator)
#             println(prog)
#             break
#         end
#         println("---------------------")
#     end

#     @testset "Synthesize max with 2 variables" begin
#         add_rule!(g, :(Number = y))
#         examples = [IOExample(Dict(:x => x, :y => y), max(x, y)) for (x, y) ∈ [(2, 10), (-5, -1), (1, 0), (-2, -2), (0, 1), (5, 10), (16, 13)]]

#         term_iter = BFSIterator(g, :Number)
#         pred_iter = BFSIterator(g, :nBool)
#         pbe_iterator = GreedyPBEIterator(g, :Number, examples, term_iter, pred_iter)

#         for (i, prog) ∈ enumerate(pbe_iterator)
#             println(prog)
#             break
#         end
#         println("---------------------")
#     end
# end

@testset "SyGuS benchmarks" begin

    @testset "SyGuS Bit Vectors Greedy PBE" begin
        problemset = all_problem_grammar_pairs(PBE_BV_Track_2018)

        stats = Dict(
            :ids => Vector{String}(),
            :times => Vector{Float64}(),
            :iters => Vector{Int64}()
        )
        for (i, (id, (prob, g))) ∈ enumerate(problemset)
            if i > 100
                break
            end

            add_rule!(g, :(ntBool = (Start == UInt(0))))
            add_rule!(g, :(ntBool = (Start == UInt(1))))
            term_iter = BFSIterator(g, :Start)
            pred_iter = BFSIterator(g, :ntBool)
            pbe_iterator = GreedyPBEIterator(g, :Start, prob.spec, term_iter, pred_iter, max_enumerations=10000)

            start = time()
            iters_before = pbe_iterator.max_enumerations
            sol = Base.iterate(pbe_iterator)
            made_iters = iters_before - pbe_iterator.max_enumerations
            elapsed = time() - start

            if !isnothing(sol)
                push!(stats[:times], elapsed)
            else
                push!(stats[:times], -1)
            end
            push!(stats[:iters], made_iters)
            push!(stats[:ids], id)
            println("$i ~ $elapsed s " * (isnothing(sol) ? "failed" : "solved"))
            yield()
        end
        println("solved: $(count(x -> x != -1, stats[:times]))")
        println("total: $(length(stats[:ids]))")
    end

    # @testset "SyGuS Bit Vectors BFS" begin
    #     problemset = all_problem_grammar_pairs(PBE_BV_Track_2018)

    #     i = 0
    #     for (id, (prob, g)) ∈ problemset
    #         enumerator = BFSIterator(g, :Start)
    #         start = time()
    #         program, synth_res = synth(prob, enumerator, allow_evaluation_errors=true, max_time=10.0)
    #         elapsed = time() - start

    #         if synth_res == suboptimal_program
    #             time_it_took_bfs[id] = -1
    #         else
    #             time_it_took_bfs[id] = elapsed
    #         end
    #         println("$i ~ $elapsed s")
    #         i ++
    #         if i == 100
    #             break
    #         end
    #     end
    # end
end