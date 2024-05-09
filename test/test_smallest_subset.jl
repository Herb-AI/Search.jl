
@testset verbose=true "Search procedure" begin
    g₁ = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    # @testset "Search" begin
    #     problem = Problem([IOExample(Dict(:x => x), 2x+4) for x ∈ 1:5])
    #     iterator = BFSIterator(g₁, :Number, max_depth=5)
    #     solution = smallest_subset(problem, iterator, max_enumerations=65)
    #     for (s, n) in solution
    #         println(rulenode2expr(s, g₁))
    #         # println(s)
    #     end
    #     println(solution)
    #     # program = rulenode2expr(solution, g₁)
    #     # hello("world")
    #     @test 13 == 2*6+1
    # end

    @testset "smallest_subset" begin
        rule = RuleNode(1, Vector())

        data::Vector{Tuple{RuleNode, Set{Number}}}= [
            (RuleNode(1, Vector()), Set{Number}([1, 2, 3])),
            (RuleNode(2, Vector()), Set{Number}([4, 5])),
            (RuleNode(3, Vector()), Set{Number}([6, 7, 8, 9])),
            (RuleNode(4, Vector()), Set{Number}([10])),
            (RuleNode(5, Vector()), Set{Number}([11, 12, 13, 14, 15])),
            (RuleNode(6, Vector()), Set{Number}([1, 2, 3, 4, 5])),
            (RuleNode(7, Vector()), Set{Number}([0]))
        ]     
        subset_programs, result = find_smallest_subset(Set{Number}(1:15), data)

        @test result == HerbSearch.full_cover
        @test length(subset_programs) == 4
        @test subset_programs[1].ind == 5
        @test subset_programs[2].ind == 6
        @test subset_programs[3].ind == 3
        @test subset_programs[4].ind == 4
    end

    @testset "greedy_set_cover" begin
        U = Set{Number}(1:9)
        S = [
            Set{Number}([1, 2, 3]),
            Set{Number}([2, 4, 6]),
            Set{Number}([3, 6, 7]),
            Set{Number}([4, 5]),
            Set{Number}([5, 6, 7, 8, 9]),
        ]

        cover, res = greedy_set_cover(U, S)

        @test 5 in cover
        @test 2 in cover
        @test 1 in cover
        @test res == HerbSearch.full_cover
    end

    @testset "greedy_set_suboptimal_cover" begin
        U = Set{Number}(1:10)
        S = [
            Set{Number}([1, 2, 3]),
            Set{Number}([2, 4, 6]),
            Set{Number}([3, 6, 7]),
            Set{Number}([4, 5]),
            Set{Number}([5, 6, 7, 8, 9]),
        ]

        cover, res = greedy_set_cover(U, S)

        @test 5 in cover
        @test 2 in cover
        @test 1 in cover
        @test res == HerbSearch.suboptimal_cover

    end
end
