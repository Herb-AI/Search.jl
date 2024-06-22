
@testset verbose=true "Search procedure" begin
    g₁ = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    grammar = @csgrammar begin
        Start = ntInt
        ntInt = ntBool ? ntInt : ntInt
        ntInt = 0
        ntInt = 1
        ntInput = _arg_1 
        ntInput = _arg_2
        ntInt = ntInput
        ntInt = ntInt + ntInt
        ntBool = ntInt <= ntInt
        ntBool = ntBool && ntBool  
        ntBool = !ntBool
    end

    problem_max = Problem([
            IOExample(Dict{Symbol, Any}(:_arg_1 => 1, :_arg_2 => 2), 2),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 2, :_arg_2 => 0), 2),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 1, :_arg_2 => -1), 1),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 3, :_arg_2 => 1), 3),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 0, :_arg_2 => 0), 0),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 3, :_arg_2 => 4), 4)])
    
    @testset "Search" begin
        pg = all_problem_grammar_pairs(PBE_SLIA_Track_2019)
        problems = Set(["problem_38664547","problem_most_frequently_occurring_text", "problem_25239569","problem_35016216", "problem_40498040","problem_count_specific_characters_in_a_cell", "problem_37534494", "problem_23435880", "problem_cell_contains_number", "problem_40498040"])
        for name in problems
            println(name)
            problem = pg[name][1]
            g = pg[name][2]
            grammar = deepcopy(g)
            
            #check if grammar contains if-else rule
            sym_start = :Start
            sym_bool = :ntBool
            return_type = grammar.rules[grammar.bytype[sym_start][1]]    
            idx = findfirst(r -> r == :($sym_bool ? $return_type : $return_type), grammar.rules)
            # add condition rule for easy access when outputing
            if isnothing(idx)
                add_rule!(grammar, :($sym_start = $sym_bool ? $return_type : $return_type))
                idx = length(grammar.rules)
            end
            
            
            term_iter = BFSIterator(grammar, :Start)
            pred_iter = BFSIterator(grammar, :ntBool)
            iterator = SubsetIterator(grammar, :Start, problem.spec, term_iter, pred_iter)
        
            solution, flag = synth(problem, iterator, allow_evaluation_errors=true)
            println(flag)
            @test flag == HerbSearch.optimal_program
        end
    end

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
        @test subset_programs[1][1].ind == 5
        @test subset_programs[2][1].ind == 6
        @test subset_programs[3][1].ind == 3
        @test subset_programs[4][1].ind == 4
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

    @testset "greedy_set_incomplete_cover" begin
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
        @test res == HerbSearch.incomplete_cover

    end
end
