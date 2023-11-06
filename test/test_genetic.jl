using Logging
using LegibleLambdas
disable_logging(LogLevel(1))


function create_problem(f, range=20)
    examples = [IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return Problem(examples), examples
end

@testset "Genetic search algorithms" verbose=true begin 
    @testset "mutate_random" begin
        grammar::ContextSensitiveGrammar = @csgrammar begin
            X = |(1:5)
            X = X * X
            X = X + X
            X = X - X
            X = x
        end
        @testset "gives a different program (new mem address) after mutation" begin
            for i in 1:10
                ruleNode = RuleNode(6,[RuleNode(1),RuleNode(2)])
                before = deepcopy(ruleNode)
                HerbSearch.mutate_random!(ruleNode,grammar)
                @test ruleNode !== before
            end
        end
        @testset "gives a different program (new mem address) after mutating the root node" begin
            root = RuleNode(4)
            HerbSearch.mutate_random!(root,grammar,1)
            @test root !== RuleNode(4)
        end
        grammar_two_types = @csgrammar begin
            A = B | C | D
            B = G | H
        end
        @testset "random_mutate works with more grammar variables" begin 
            for i in 1:10
                root = RuleNode(1,[RuleNode(4)]) # B->G
                # the only way to mutate is to get the same program 
                HerbSearch.mutate_random!(root, grammar_two_types, 2)
                # either C,D (2,3)
                # either G,H (1->4) and (1->5)
                @test root in [RuleNode(2),RuleNode(3), RuleNode(1,[RuleNode(4)]),RuleNode(1,[RuleNode(5)])]
            end
        end
    end

    @testset "Cross over" begin
        @testset "outcome has 2 children" begin
            @testset "only rule nodes" begin
                @testset "two different roots get swapped" begin
                    root1 = RuleNode(1)
                    root2 = RuleNode(2)
                    # they should be swapped
                    @test HerbSearch.crossover_swap_children_2(root1,root2) == (root2, root1)
                    # no modification
                    @test root1 == RuleNode(1)
                    @test root2 == RuleNode(2)
                end

                @testset "crossing over the same rulenode gives the same rulenode two times" begin 
                    @test HerbSearch.crossover_swap_children_2(RuleNode(1),RuleNode(1)) == (RuleNode(1),RuleNode(1))
                end
            end

            @testset "crossing over two parents returns two different children" begin

                rulenode1 = RuleNode(1,[RuleNode(2)])
                rulenode2 = RuleNode(3,[RuleNode(4,[RuleNode(5)])])
                child1,child2 = crossover_swap_children_2(rulenode1,rulenode2)
                @test child1 !== child2
                @test rulenode1 == RuleNode(1,[RuleNode(2)])
                @test rulenode2 == RuleNode(3,[RuleNode(4,[RuleNode(5)])])
            end

        end
        @testset "outcome has one child" begin
            @testset "only root node" begin
                @testset "crossing over the same rulenode gives the same rulenode" begin 
                    @test HerbSearch.crossover_swap_children_1(RuleNode(1),RuleNode(1)) == RuleNode(1)
                end

                @testset "crossing over the two roots gives one of them" begin 
                    root1 = RuleNode(1)
                    root2 = RuleNode(2)
                    child = HerbSearch.crossover_swap_children_1(root1, root2)
                    @test (child == root1 || child == root2)
                    @test root1 == RuleNode(1) && root2 == RuleNode(2)
                end
            end
            @testset "not root" begin
                root1 = RuleNode(1,[RuleNode(2)])
                root2 = RuleNode(3,[RuleNode(4)])
                child = HerbSearch.crossover_swap_children_1(root1, root2)
            end

        end
    end

    @testset "Syntesize simple arithmetic expressions" verbose = true begin
        grammar = @csgrammar begin
            X = |(1:5)
            X = X * X
            X = X + X
            X = X - X
            X = x
        end

        functions = [
            @λ(x -> 1),
            @λ(x -> 10),
            @λ(x -> 625),
            @λ(x -> 3 * x),
            @λ(x -> 3 * x + 10),
            @λ(x -> 3 * x * x + (x + 2)),
        ]
        function pretty_print_lambda(lambda)
            return repr(lambda)[2:end - 1]
        end

        @testset "syntesizing expr $(pretty_print_lambda(f))" for f in functions
            problem, examples = create_problem(f)
            enumerator = get_genetic_enumerator(examples, 
                initial_population_size =10,
                mutation_probability = 0.8,
                maximum_initial_population_depth = 3,
                )
            program, cost = search_best(grammar, problem, :X, enumerator=enumerator, error_function=mse_error_function, max_depth=nothing, max_time=20)
            @test cost == 0
        end
    end
    @testset "Validation logic" begin 
        grammar = @csgrammar begin
            X = |(1:5)
        end
        function get_genetic_algorithm(examples; kwargs...)
            outcome =  get_genetic_enumerator(examples; kwargs...)
            return outcome(grammar, 10, 10, :X)
        end

        problem, examples = create_problem(x -> x)
        @testset "Bad fitness function throws" begin
            bad_fitness = (program) -> 1
            enumerator = get_genetic_algorithm(examples, 
                fitness_function = bad_fitness, 
            )
            @test_throws HerbSearch.AlgorithmStateIsInvalid HerbSearch.validate_iterator(enumerator)
        end
        @testset "Bad population size throws" begin
            enumerator = get_genetic_algorithm(examples, 
                initial_population_size = -1,
            )
            @test_throws HerbSearch.AlgorithmStateIsInvalid HerbSearch.validate_iterator(enumerator)

            enumerator = get_genetic_algorithm(examples, 
                initial_population_size = 0,
            )
            @test_throws HerbSearch.AlgorithmStateIsInvalid HerbSearch.validate_iterator(enumerator)
        end

        @testset "Bad cross_over function throws" begin
            enumerator = get_genetic_algorithm(examples, 
                cross_over = (program1::Int,program2::Int) -> 1 # invalid crossover
            )
            @test_throws HerbSearch.AlgorithmStateIsInvalid HerbSearch.validate_iterator(enumerator)
        end

        @testset "Good algorithm params works" begin
            enumerator = get_genetic_algorithm(examples)
            # this works
            @test HerbSearch.validate_iterator(enumerator)
        end
    end
end