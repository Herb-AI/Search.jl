g = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = (Num == Num)
    Num = (if Bool ; Num else Num end)
end

@testset "basic_example" begin
    spec = [IOExample(Dict(:x => x), 3x) for x ∈ 1:5]
    problem = Problem(spec)
    config = FrAngelConfig(generation = FrAngelConfigGeneration(use_fragments_chance = 0.5, use_angelic_conditions_chance = 0))
    angelic_conditions = AbstractVector{Union{Nothing, Int64}}([nothing for rule in g.rules])
    rules_min = rules_minsize(g)
    symbol_min = symbols_minsize(g, rules_min)

    @time begin     
    # @time @profview begin     
        iterator = FrAngelRandomIterator(g, :Num, rules_min, symbol_min, max_depth = 10)
        solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min) 
    end
    program = rulenode2expr(solution, g) # should yield 2*6 +1 
    println(program)

    @time begin 
        iterator = BFSIterator(g, :Num, max_depth=10)
        solution, flag = synth(problem, iterator)
    end
    program = rulenode2expr(solution, g) # should yield 2*6 +1 
    println(program)
end