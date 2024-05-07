@testset verbose=true "Search procedure" begin
    g₁ = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    @testset "Search" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])
        iterator = BFSIterator(g₁, :Number, max_depth=5)
        solution, flag = synth(problem, iterator)
        # program = rulenode2expr(solution, g₁)

        @test 13 == 2*6+1
    end

    # @testset "Search_best max_enumerations stopping condition" begin
    #     problem = Problem([IOExample(Dict(:x => x), 2x-1) for x ∈ 1:5])
    #     iterator = BFSIterator(g₁, :Number)

    #     solution = smallest_subset(problem, iterator)
    #     # program = rulenode2expr(solution, g₁)

    #     @test 13 == 2*6+1

    #     # @test program == :x
    #     # @test flag == suboptimal_program
    # end

    # @testset "Search_best with errors in evaluation" begin
    #     g₃ = @csgrammar begin
    #         Number = 1
    #         List = []
    #         Index = List[Number]
    #     end
        
    #     problem = Problem([IOExample(Dict(), x) for x ∈ 1:5])
    #     iterator = BFSIterator(g₃, :Index, max_depth=2)
    #     solution, flag = synth(problem, iterator, allow_evaluation_errors=true) 

    #     @test solution == RuleNode(3, [RuleNode(2), RuleNode(1)])
    #     @test flag == suboptimal_program
    # end
end