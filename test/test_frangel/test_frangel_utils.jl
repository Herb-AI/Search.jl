using Logging
using LegibleLambdas
disable_logging(LogLevel(1))


@testset "Utility size functions" verbose = true begin
    grammar::ContextSensitiveGrammar = @cfgrammar begin
        Num = |(0:9)
        Num = (Num + Num) | (Num - Num)
        Num = max(Num, Num)
        Expression = Num | Variable
        Variable = x
        InnerStatement = (global Variable = Expression) | (InnerStatement; InnerStatement)
        Statement = (global Variable = Expression)
        Statement = (
            i = 0;
            while i < Num
                InnerStatement
                global i = i + 1
            end)
        Statement = (Statement; Statement)
        Return = return Expression
        Program = Return | (Statement; Return)
    end

    @testset "minsize_map" begin
        @testset "returns the correct minimum size for each rule" begin
            @test [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 2, 2, 1, 4, 9, 4, 6, 9, 3, 4, 8] == rules_minsize(grammar)
        end
    end

    @testset "symbols_minsize" begin
        @testset "returns the correct minimum size for each symbol, based on the rules minsizes" begin
            rules_minsizes = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 2, 2, 1, 4, 9, 4, 6, 9, 3, 4, 8]
            execpted_symbol_minsizes = Dict(:Expression => 2, :Num => 1, :Statement => 4, :Variable => 1, :InnerStatement => 4, :Return => 3, :Program => 4)

            @test execpted_symbol_minsizes == symbols_minsize(grammar, rules_minsizes)
        end
    end
end


@testset "Algorithm functions" verbose = true begin
    grammar::ContextSensitiveGrammar = @cfgrammar begin
        Num = |(0:9)
        Num = (Expression + Expression) | (Expression - Expression)
        Num = max(Num, Num)
        Expression = Num | Variable
        Variable = x
        InnerStatement = (global Variable = Expression) | (InnerStatement; InnerStatement)
        Statement = (global Variable = Expression)
        Statement = (
            i = 0;
            while i < Num
                InnerStatement
                global i = i + 1
            end)
        Statement = (Statement; Statement)
        Return = return Expression
        Program = Return | (Statement; Return)
    end

    @testset "mine_fragments" begin
        @testset "Finds the correct fragments" begin
            # program = begin
            #     global x = 8
            #     return 7
            # end
            program = RuleNode(24, [
                RuleNode(19, [
                    RuleNode(16),
                    RuleNode(14, [
                        RuleNode(9)
                    ])
                ]),
                RuleNode(22, [
                    RuleNode(14, [
                        RuleNode(8)
                    ])
                ])
            ])
            fragments = mine_fragments(grammar, program)
            fragments = delete!(fragments, program)
            expected_fragments = Set{RuleNode}([
                RuleNode(19, [
                    RuleNode(16),
                    RuleNode(14, [
                        RuleNode(9)
                    ])
                ]),
                RuleNode(16),
                RuleNode(14, [
                    RuleNode(9)
                ]),
                RuleNode(9),
                RuleNode(22, [
                    RuleNode(14, [
                        RuleNode(8)
                    ])
                ]),
                RuleNode(14, [
                    RuleNode(8)
                ]),
                RuleNode(8)
            ])

            @test expected_fragments == fragments
        end

        @testset "Returns a disjoint set" begin
            # Not proper/compilable programs, but sufficient for testing the functionality
            # program1 = return 7 + x
            # program2 = return 8 + x
            program1 = RuleNode(22, [
                RuleNode(14, [
                    RuleNode(11, [
                        RuleNode(14, [
                            RuleNode(8)
                        ]),
                        RuleNode(15, [
                            RuleNode(16)
                        ])
                    ])
                ])
            ])
            program2 = RuleNode(22, [
                RuleNode(14, [
                    RuleNode(11, [
                        RuleNode(14, [
                            RuleNode(9)
                        ]),
                        RuleNode(15, [
                            RuleNode(16)
                        ])
                    ])
                ])
            ])
            fragments = mine_fragments(grammar, Set{RuleNode}([program1, program2]))
            expected_fragments = Set{RuleNode}([
                RuleNode(14, [
                    RuleNode(11, [
                        RuleNode(14, [
                            RuleNode(8)
                        ]),
                        RuleNode(15, [
                            RuleNode(16)
                        ])
                    ])
                ]),
                RuleNode(14, [
                    RuleNode(11, [
                        RuleNode(14, [
                            RuleNode(9)
                        ]),
                        RuleNode(15, [
                            RuleNode(16)
                        ])
                    ])
                ]),
                RuleNode(11, [
                    RuleNode(14, [
                        RuleNode(8)
                    ]),
                    RuleNode(15, [
                        RuleNode(16)
                    ])
                ]),
                RuleNode(11, [
                    RuleNode(14, [
                        RuleNode(9)
                    ]),
                    RuleNode(15, [
                        RuleNode(16)
                    ])
                ]),
                RuleNode(14, [
                    RuleNode(8)
                ]),
                RuleNode(14, [
                    RuleNode(9)
                ]),
                RuleNode(15, [
                    RuleNode(16)
                ]),
                RuleNode(8),
                RuleNode(9),
                RuleNode(16)
            ])

            @test expected_fragments == fragments
        end
    end

    @testset "remember_programs" begin
        g = @cfgrammar begin
            Num = |(0:10)
            Num = x | (Num + Num) | (Num - Num) | (Num * Num)
        end

        # Add first remembered program
        first_program = RuleNode(13, [RuleNode(2), RuleNode(3)])
        first_program_tests = BitVector([1, 0, 1])
        first_program_value = (first_program, count_nodes(g, first_program), length(string(rulenode2expr(first_program, g))))
        old_remembered = Dict{BitVector,Tuple{RuleNode,Int,Int}}()
        remember_programs!(old_remembered, first_program_tests, first_program, Set{RuleNode}(), g)
        println(old_remembered)

        # Second program to consider
        longer_program = RuleNode(13, [RuleNode(13, [RuleNode(1), RuleNode(2)]), RuleNode(1)])
        longer_program_value = (longer_program, count_nodes(g, longer_program), length(string(rulenode2expr(longer_program, g))))

        same_length_program = RuleNode(13, [RuleNode(1), RuleNode(2)])
        same_length_program_value = (same_length_program, count_nodes(g, same_length_program), length(string(rulenode2expr(same_length_program, g))))

        shorter_program = RuleNode(1)
        shorter_program_value = (shorter_program, count_nodes(g, shorter_program), length(string(rulenode2expr(shorter_program, g))))

        function one_test_case(new_program::RuleNode, passing_tests::BitVector, expected_result::Dict{BitVector,Tuple{RuleNode,Int,Int}})
            new_remembered = deepcopy(old_remembered)
            remember_programs!(new_remembered, passing_tests, new_program, Set{RuleNode}(), g)
            @test expected_result == new_remembered
        end

        @testset "New programs pass a superset of tests" begin
            superset_tests = BitVector([1, 1, 1])
            # Longer program
            one_test_case(longer_program, superset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value, # Old program kept
                superset_tests => longer_program_value # New program added
            ))
            # Same-length program
            one_test_case(same_length_program, superset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                superset_tests => same_length_program_value # Old program replaced
            ))
            # Shorter program
            one_test_case(shorter_program, superset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                superset_tests => shorter_program_value # Old program replaced
            ))
        end

        @testset "New programs pass same set of tests" begin
            # Longer program
            one_test_case(longer_program, first_program_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value # Old program kept
            ))
            # Same-length program
            one_test_case(same_length_program, first_program_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value # Old program kept
            ))
            # Shorter program
            one_test_case(shorter_program, first_program_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => shorter_program_value # Old program replaced
            ))
        end

        @testset "New programs pass a subset of tests" begin
            subset_tests = BitVector([1, 0, 0])
            # Longer program
            one_test_case(longer_program, subset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value # Old program kept
            ))
            # Same-length program
            one_test_case(same_length_program, subset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value # Old program kept
            ))
            # Shorter program
            one_test_case(shorter_program, subset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value, # Old program kept
                subset_tests => shorter_program_value # New program added
            ))
        end

        @testset "New programs pass a disjoint set of tests" begin
            disjoint_tests = BitVector([0, 1, 1])
            # Longer program
            one_test_case(longer_program, disjoint_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value, # Old program kept
                disjoint_tests => longer_program_value # New program added
            ))
            # Same-length program
            one_test_case(same_length_program, disjoint_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value, # Old program kept
                disjoint_tests => same_length_program_value # New program added
            ))
            # Shorter program
            one_test_case(shorter_program, disjoint_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
                first_program_tests => first_program_value, # Old program replaced
                disjoint_tests => shorter_program_value # New program added
            ))
        end
    end

    @testset "simplifyQuick" begin
        @testset "removes unnecesarry neighbour nodes" begin
            println(grammar)

            # program = begin
            #     global x = 8
            #     return 7
            # end
            program = RuleNode(24, [
                RuleNode(19, [
                    RuleNode(16),
                    RuleNode(14, [
                        RuleNode(9)
                    ])
                ])
                RuleNode(22, [
                    RuleNode(14, [
                        RuleNode(8)
                    ])
                ])
            ])

            tests = [IOExample(Dict(), 7)]
            passed_tests = BitVector([true])

            # @test RuleNode(8) == simplify_quick(program, grammar, tests, passed_tests)
        end
    end
end
