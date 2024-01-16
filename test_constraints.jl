using Revise, HerbSearch, Debugger, HerbGrammar, HerbData, HerbInterpret, HerbConstraints, Test

@testset verbose=true "Test Constraints" begin
    @testset "Enumerate RequireOnLeft" begin
		grammar = @csgrammar begin
			A = |(1:3)
			S = A + A + A
		end
		constraint = RequireOnLeft([1, 2, 3])
		addconstraint!(grammar, constraint)
		
		#4{1, 1, 3} is an invalid program, as it does not respect the order [1, 2, 3]
		#therefore, it should not be enumerated
		programs = collect(get_bfs_enumerator(grammar, 2, 4, :S))
		invalid_program = RuleNode(4, [RuleNode(1), RuleNode(1), RuleNode(3)])
		@test !(invalid_program ∈ programs)
    end

	@testset "Enumerate OneOf" begin
		grammar = @csgrammar begin
			A = |(1:2)
			S = A + A
		end
		constraint = OneOf(Forbidden(MatchNode(1)), Forbidden(MatchNode(2)))
		addconstraint!(grammar, constraint)
		
		#3{1, 2} and 3{2, 1} are an invalid programs, as they contain both of the forbidden subtrees
		#one of should only allow 1 of the forbidden subtrees, but not both
		programs = collect(get_bfs_enumerator(grammar, 2, 3, :S))
		invalid_program1 = RuleNode(3, [RuleNode(1), RuleNode(2)])
		invalid_program2 = RuleNode(3, [RuleNode(2), RuleNode(1)])
		@test !(invalid_program1 ∈ programs)
		@test !(invalid_program2 ∈ programs)
	end

    @testset "Propagating LocalOrdered (hole points to a MatchVar)" begin
		grammar = @csgrammar begin
			Real = |(1:9)
			Real = Real + Real
			Real = Real * Real
		end
		
		constraint = LocalOrdered(
			[],
			MatchNode(10, [
				MatchVar(:x), 
				MatchNode(10, [
					MatchNode(8), 
					MatchVar(:y)
				])
			]),
			[:x, :y]
		)
		
		expr = RuleNode(10, [
			Hole(get_domain(grammar, :Real))
			RuleNode(10, [
				RuleNode(8)
				RuleNode(4)
			])
		]
		)
		context = GrammarContext(expr, [1], Set{Int}())
		domain, _ = propagate(constraint, grammar, context, collect(1:9), nothing)
		
		@test domain == [1, 2, 3, 4]
    end

	@testset "Propagating LocalOrdered (hole points to a MatchNode)" begin
		grammar = @csgrammar begin
			Real = |(1:9)
			Real = Real + Real
			Real = Real * Real
		end
		
		constraint = LocalOrdered(
			[],
			MatchNode(10, [
				MatchNode(8), 
				MatchNode(10, [
					MatchVar(:x), 
					MatchVar(:y)
				])
			]),
			[:x, :y]
		)
		
		expr = RuleNode(10, [
			Hole(get_domain(grammar, :Real))
			RuleNode(10, [
				RuleNode(8)
				RuleNode(4)
			])
		]
		)
		context = GrammarContext(expr, [1], Set{Int}())
		domain, _ = propagate(constraint, grammar, context, collect(1:9), nothing)
		
		@test domain == [1, 2, 3, 4, 5, 6, 7, 9] #8 needs to get pruned, as it would complete the pattern
    end

end
