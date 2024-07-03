@testset "Grammar splitting" begin
    g = @cfgrammar begin
        X = |(1:5)
        X = X * X
        X = X + X
        X = X - X
        X = x
    end

    grammars = split_grammar(g, :x)
end