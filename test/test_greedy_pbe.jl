using HerbBenchmarks.PBE_SLIA_Track_2019
using Base.Threads

@testset "Testing the greedy PBE iterator" verbose = true begin
    g = @cfgrammar begin
        Number = |(0:1)
        Number = x
        Number = Number + Number
        Number = Number * Number
        nBool = (nBool || nBool) | (nBool && nBool) | (!nBool) | (Number < Number) | (Number > Number) | (Number == Number)
    end

    @testset "Producing initial programs" begin
        examples = [IOExample(Dict(:x => x), x * x + 1) for x ∈ 1:5]

        term_iter = BFSIterator(g, :Number)
        pred_iter = BFSIterator(g, :nBool)
        pbe_iterator = GreedyPBEIterator(g, :Number, examples, term_iter, pred_iter)

        for (i, prog) ∈ enumerate(pbe_iterator)
            println(prog)
            break
        end
        println("---------------------")
    end

    @testset "Synthesize max function" begin

        examples = [IOExample(Dict(:x => x), max(x, 0) + 1) for x ∈ -5:5]

        term_iter = BFSIterator(g, :Number)
        pred_iter = BFSIterator(g, :nBool)
        pbe_iterator = GreedyPBEIterator(g, :Number, examples, term_iter, pred_iter)

        for (i, prog) ∈ enumerate(pbe_iterator)
            println(prog)
            break
        end
        println("---------------------")
    end

    @testset "Synthesize max with 2 variables" begin
        add_rule!(g, :(Number = y))
        examples = [IOExample(Dict(:x => x, :y => y), max(x, y)) for (x, y) ∈ [(2, 10), (-5, -1), (1, 0), (-2, -2), (0, 1), (5, 10), (16, 13)]]

        term_iter = BFSIterator(g, :Number)
        pred_iter = BFSIterator(g, :nBool)
        pbe_iterator = GreedyPBEIterator(g, :Number, examples, term_iter, pred_iter)

        for (i, prog) ∈ enumerate(pbe_iterator)
            println(prog)
            break
        end
        println("---------------------")
    end
end

@testset "SyGuS benchmarks" begin
    function get_problems_and_grammars(mod::Module)
        all_symbols = names(mod)
        # Filter symbols starting with "problem"
        problem_symbols = filter(s -> occursin(r"^problem_\d+$", string(s)), all_symbols)
        # Get the corresponding values (functions) for the problem symbols
        problems = Vector{Tuple{Any,Any}}()
        for problem_sym ∈ problem_symbols
            prob = getfield(mod, problem_sym)
            grammar_sym = Symbol(replace(string(problem_sym), "problem" => "grammar"))
            grammar = getfield(mod, grammar_sym)
            push!(problems, (prob, grammar))
        end

        return problems
    end


    function solve(iterator, timeout_seconds=10)
        # Create a task to execute the iteration
        task = @task begin
            Base.iterate(iterator)
        end
        Threads.@spawn task

        println("sleeping")
        sleep(10)
        println("woke up")
        if istaskdone(task)
            println("isdone")
            return 1
        else
            Base.throwto(task, InterruptException())
            return nothing
        end
    end
    # @testset "String examples" begin
    #     # The id has to be matching
    #     grammar = PBE_SLIA_Track_2019.grammar_12948338
    #     problem = PBE_SLIA_Track_2019.problem_12948338

    #     term_iter = BFSIterator(grammar, :Start)
    #     pred_iter = BFSIterator(grammar, :ntBool)
    #     pbe_iterator = GreedyPBEIterator(grammar, :Start, problem.spec, term_iter, pred_iter)

    #     for (i, prog) ∈ enumerate(pbe_iterator)
    #         println(prog)
    #         break
    #     end
    #     println("---------------------")
    # end

    # @testset "View SyGuS problems" begin
    #     problemsets = get_problems_and_grammars(PBE_SLIA_Track_2019)[2]

    #     for (prob, g) ∈ problemsets
    #         term_iter = BFSIterator(g, :Start)
    #         pred_iter = BFSIterator(g, :ntBool)
    #         pbe_iterator = GreedyPBEIterator(g, :Start, prob.spec, term_iter, pred_iter)


    #         solution, state = Base.iterate(pbe_iterator)
    #         println("----------------")
    #         println(solution)
    #         println("----------------")
    #     end
    # end
end