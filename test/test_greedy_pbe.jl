@testset "Testing the greedy PBE iterator" verbose = true begin
    g = @cfgrammar begin
        Number = |(0:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
        nBool = (nBool || nBool) | (nBool && nBool) | (!nBool) | (Number < Number) | (Number > Number)
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
    end

    @testset "Synthesize max function" begin

        examples = [IOExample(Dict(:x => x), max(x, 0)) for x ∈ -5:5]

        term_iter = BFSIterator(g, :Number)
        pred_iter = BFSIterator(g, :nBool)
        pbe_iterator = GreedyPBEIterator(g, :Number, examples, term_iter, pred_iter)

        for (i, prog) ∈ enumerate(pbe_iterator)
            println(prog)
            break
        end
    end

end