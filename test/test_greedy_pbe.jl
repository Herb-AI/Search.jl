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