
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

    @testset "Search" begin
        problem = Problem([
            IOExample(Dict{Symbol, Any}(:_arg_1 => 1, :_arg_2 => 2), 2),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 2, :_arg_2 => 0), 2),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 1, :_arg_2 => -1), 1),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 3, :_arg_2 => 1), 3),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 0, :_arg_2 => 0), 0),
            IOExample(Dict{Symbol, Any}(:_arg_1 => 3, :_arg_2 => 4), 4)])

        # println(problem.spec)
        # println()
        # del(problem)
        # println(problem.spec)
        # grammar = PBE_SLIA_Track_2019.grammar_12948338
        # problem = PBE_SLIA_Track_2019.problem_12948338
       
        # println(problem.spec)
        term_iter = BFSIterator(grammar, :Start)
        pred_iter = BFSIterator(grammar, :ntBool)
        iterator = SubsetIterator(grammar, :Start, problem.spec, term_iter, pred_iter)
       
        max_enumerations = 50

        for (i, candidate_program) ∈ enumerate(iterator)
            # Create expression from rulenode representation of AST
            expr = rulenode2expr(candidate_program, grammar)
            # Evaluate the expression
            # score = evaluate(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
            # if score == 1
            #     candidate_program = freeze_state(candidate_program)
            #     return (candidate_program, optimal_program)
            # elseif score >= best_score
            #     best_score = score
            #     candidate_program = freeze_state(candidate_program)
            #     best_program = candidate_program
            # end
    
            # # Check stopping criteria
            if i > max_enumerations
                break;
            end
        end



    end

    max_enumerations=1000000
    max_time = 60
    # @testset "decision trees combining" begin
    #     pg = all_problem_grammar_pairs(PBE_SLIA_Track_2019)
       
    #     good = [3, 5, 44, 58, 79, 96, 98]
    #     full_cover_and_satisfies_all = []
    #     full_cover_cant_satisfy = [44, 73, 76]
    #     incomplete = []
    #     no_solution = []
    #     j = 1
    #     skip = true
    #     for i in pg
    #         # if skip || !(j in good)
    #         #     j+=1
    #         #     continue
    #         # end
    #         problem_name = i[1]
    #         problem = i[2][1]
    #         grammar = i[2][2]

    #         println(j, " ", problem_name)
    #         iterator = BFSIterator(grammar, :Start)
    #         solution, result = smallest_subset(problem, iterator, max_enumerations=max_enumerations, max_time=max_time, allow_evaluation_errors=true)
            
    #         println("solutions: ", length(solution), ", result: ", result)
    #         for (p, s) in solution
    #             expr = rulenode2expr(p, grammar)
    #             println(expr)
    #         end

    #         ret = learn_DT(problem, grammar, :Start, :ntBool, solution)
    #         if !isnothing(ret)
    #             rulenode, g = ret
    #             expr = rulenode2expr(rulenode, g)
    #             println("final_program expr: ", expr)
    #             symboltable :: SymbolTable = SymbolTable(g, Main)

    #             # println(problem.spec)
    #             satisfies = satisfies_examples(problem, expr, symboltable, allow_evaluation_errors=true)
    #             println(length(satisfies), " / ", length(problem.spec), " = ", length(satisfies) / length(problem.spec))
    #             if length(satisfies) / length(problem.spec) == 1
    #                 if result==HerbSearch.full_cover
    #                     push!(full_cover_and_satisfies_all, j)
    #                 end
    #             elseif result==HerbSearch.full_cover
    #                 push!(full_cover_cant_satisfy, j)
    #             else
    #                 push!(incomplete, j)
    #             end
    #             println()
    #         else 
    #             push!(no_solution, j)
    #         end
    #         println()
    #         j+=1
    #     end
    #     println("max_enumerations: ", max_enumerations, " or max_time: ", max_time, "sec")
    #     println("result decision trees: ", length(full_cover_and_satisfies_all), "/", length(pg), " = ", length(full_cover_and_satisfies_all)/length(pg))
    #     println("full_cover_and_satisfies_all: ",full_cover_and_satisfies_all)
    #     println("full_cover_cant_satisfy: ", full_cover_cant_satisfy)
    #     println("incomplete: ",incomplete)
    # end


    #  @testset "predicates generation" begin
    #     pg = all_problem_grammar_pairs(PBE_SLIA_Track_2019)
       
    #     grammar = pg["problem_cell_contains_all_of_many_things"][2]
    #     # predicates = generate_rand_predicates(grammar, :ntBool, 1024)
    #     enums = 16

    #     start_time = time()
    #     predicates = enumerate_predicates(grammar, :ntBool, enums)
    #     println("time: ", time()-start_time, length(predicates))
    # end


    # @testset "test on basic enumeration" begin
    #     pg = all_problem_grammar_pairs(PBE_SLIA_Track_2019)
       
    #     sat_all = []
    #     for enumerations in [100, 1000, 2000, 4000, 8000, 10000]
    #         o = 0
    #         for i in pg

    #             problem_name = i[1]
    #             problem = i[2][1]
    #             grammar = i[2][2]

    #             # println(j, " ", problem_name)
    #             iterator = BFSIterator(grammar, :Start)
    #             solution, result = synth(problem, iterator, max_enumerations=enumerations, allow_evaluation_errors=true)

    #             if result == optimal_program
    #                 o += 1
    #             end
    #         end
    #         println(enumerations, ", BFS enumeration result: ", o, "/", length(pg), " = ", o/length(pg))
    #     end
    # end


    # function del(problem)
    #     p = problem
    #     deleteat!(p.spec, [1,2,3,4,5,6])
    #     println("done")
    # end




    # @testset "Search" begin
    #     problem = Problem([
    #         IOExample(Dict{Symbol, Any}(:_arg_1 => 1, :_arg_2 => 2), 2),
    #         IOExample(Dict{Symbol, Any}(:_arg_1 => 2, :_arg_2 => 0), 2),
    #         IOExample(Dict{Symbol, Any}(:_arg_1 => 1, :_arg_2 => 0), 1),
    #         IOExample(Dict{Symbol, Any}(:_arg_1 => 3, :_arg_2 => 1), 3),
    #         IOExample(Dict{Symbol, Any}(:_arg_1 => 3, :_arg_2 => 4), 4),
    #         IOExample(Dict{Symbol, Any}(:_arg_1 => 0, :_arg_2 => 0), 0),
    #         IOExample(Dict{Symbol, Any}(:_arg_1 => 0, :_arg_2 => 1), 1)])

    #     iterator = BFSIterator(g3, :Start, max_depth=6)
       
    #     solution, result = smallest_subset(problem, iterator, max_enumerations=10)

    #     rulenodes = learn_DT(problem, g3, :Start, :ntBool, solution)
    #     println("final_program expr: ", rulenode2expr(rulenodes, g3))
    #     println()
    # end

    # @testset "smallest_subset" begin
    #     rule = RuleNode(1, Vector())

    #     data::Vector{Tuple{RuleNode, Set{Number}}}= [
    #         (RuleNode(1, Vector()), Set{Number}([1, 2, 3])),
    #         (RuleNode(2, Vector()), Set{Number}([4, 5])),
    #         (RuleNode(3, Vector()), Set{Number}([6, 7, 8, 9])),
    #         (RuleNode(4, Vector()), Set{Number}([10])),
    #         (RuleNode(5, Vector()), Set{Number}([11, 12, 13, 14, 15])),
    #         (RuleNode(6, Vector()), Set{Number}([1, 2, 3, 4, 5])),
    #         (RuleNode(7, Vector()), Set{Number}([0]))
    #     ]     
    #     subset_programs, result = find_smallest_subset(Set{Number}(1:15), data)

    #     @test result == HerbSearch.full_cover
    #     @test length(subset_programs) == 4
    #     @test subset_programs[1][1].ind == 5
    #     @test subset_programs[2][1].ind == 6
    #     @test subset_programs[3][1].ind == 3
    #     @test subset_programs[4][1].ind == 4
    # end

    # @testset "greedy_set_cover" begin
    #     U = Set{Number}(1:9)
    #     S = [
    #         Set{Number}([1, 2, 3]),
    #         Set{Number}([2, 4, 6]),
    #         Set{Number}([3, 6, 7]),
    #         Set{Number}([4, 5]),
    #         Set{Number}([5, 6, 7, 8, 9]),
    #     ]

    #     cover, res = greedy_set_cover(U, S)

    #     @test 5 in cover
    #     @test 2 in cover
    #     @test 1 in cover
    #     @test res == HerbSearch.full_cover
    # end

    # @testset "greedy_set_incomplete_cover" begin
    #     U = Set{Number}(1:10)
    #     S = [
    #         Set{Number}([1, 2, 3]),
    #         Set{Number}([2, 4, 6]),
    #         Set{Number}([3, 6, 7]),
    #         Set{Number}([4, 5]),
    #         Set{Number}([5, 6, 7, 8, 9]),
    #     ]

    #     cover, res = greedy_set_cover(U, S)

    #     @test 5 in cover
    #     @test 2 in cover
    #     @test 1 in cover
    #     @test res == HerbSearch.incomplete_cover

    # end
end
