@testset "Testing the greedy PBE iterator" verbose = true begin
    @testset "Producing initial programs" begin
        g = @cfgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end

        examples = [IOExample(Dict(:x => x), x * x + 1) for x ∈ 1:5]

        subiterator = BFSIterator(g, :Number, max_size=5)
        pbe_iterator = GreedyPBEIterator(g, :Number, examples, subiterator)

        for ps ∈ pbe_iterator
            exprs = map(p -> rulenode2expr(p, g), ps)
            println(exprs)
            break
        end

    end
end