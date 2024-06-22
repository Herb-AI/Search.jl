prob_gram_pairs = all_problem_grammar_pairs(PBE_SLIA_Track_2019)
prob_gram_pairs = all_problem_grammar_pairs(PBE_BV_Track_2018)

# filter problems with >= 1000 IO examples
filtered_prob_gram_pairs = []
for pg in prob_gram_pairs
    if length(pg[2][1].spec) < 1000
        push!(filtered_prob_gram_pairs, pg)
    end
end

max_enumerations=[100, 500, 1000, 10000, 20000, 40000, 100000]
num_predicates = [100, 500, 1000, 8000, 24000]

experiments = Dict()

DT_solved = Set()
satisfied_by_one = Set()

#function to print experiments in a readable format
function print_exp(exp)
    table = []
    for i in max_enumerations
        push!(table, zeros(length(num_predicates)))
    end
    for (i, k) in enumerate(max_enumerations)
        if !haskey(exp, k)
            continue
        end
        one_prog_sat = exp[k][1]
        full_cov = exp[k][2]
        solved_by_n = exp[k][3]
        solved_DT = exp[k][4]
        println("enums: ",k)
        println("one prog satisfies: ",length(one_prog_sat), " ",one_prog_sat)
        println("full_cov: ",length(full_cov), " ",full_cov)
        println("doesnt satisfy with full cover: ",  setdiff(full_cov, solved_DT))
        for (j, np) in enumerate(num_predicates)
            if !haskey(solved_by_n, np)
                continue
            end
            println("np: ", np, " solves: ", solved_by_n[np])
            table[i][j] = length(solved_by_n[np])
        end
    end
    for (i, r) in enumerate(table)
        println(max_enumerations[i], ": ",r)
    end
end

# solved problems from SLIA track
solved_problems = union(Set([5, 7, 20, 23, 25, 34, 36, 37, 38, 39, 41, 43, 51, 58, 65, 66, 67, 69, 70, 71, 75, 77, 80, 81, 82, 90, 95, 96, 97, 98]), Set([3, 6, 15, 27, 30, 35, 44, 50, 52, 53, 64, 73, 79]))
solved_problems = Set([177,141,160,146,80,244,202])

expressions = Dict()
println(length(filtered_prob_gram_pairs))
for me in max_enumerations
    problems_solved_by_n_predicates = Dict()
    for np in num_predicates
        problems_solved_by_n_predicates[np] = []
    end
    full_cover_many_programs = Set()
    one_prog_satisfies_all = Set()
    solved_by_DT = Set()
    
    for (j, pg) in enumerate(filtered_prob_gram_pairs)
        if !(j in solved_problems)
            continue
        end
        # if j in satisfied_by_one 
        #     continue
        # end

        problem_name = pg[1]
        problem = pg[2][1]
        grammar = pg[2][2]

        # if problem_name != "problem_25239569"
        #     continue
        # end

        println(j, " ", problem_name)
        iterator = BFSIterator(grammar, :Start)
        solution, result = smallest_subset(problem, iterator, max_enumerations=me, allow_evaluation_errors=true)

        println("length solutions: ", length(solution), " ", result)
        println(solution)
        for (rn, set_sat) in solution
            expr = rulenode2expr(rn, grammar)
            println(expr)
        end
        if result == HerbSearch.incomplete_cover
            continue
        elseif result==HerbSearch.full_cover && length(solution) == 1
            push!(one_prog_satisfies_all, j)
            push!(satisfied_by_one, j)
            continue
        elseif result==HerbSearch.full_cover && length(solution) != 1
            push!(full_cover_many_programs, j)
        end

        for n_predicates in num_predicates
            # ret = learn_DT(problem, grammar, :Start, :ntBool, solution, n_predicates)
            ret = learn_DT(problem, grammar, :Start, nothing, solution, n_predicates)
            
            if isnothing(ret)
                continue
            end

            rulenode, g = ret
            expr = rulenode2expr(rulenode, g)
            symboltable :: SymbolTable = SymbolTable(g, Main)

            satisfies = satisfies_examples(problem, expr, symboltable, allow_evaluation_errors=true)

            println("n_predicates: ", n_predicates)
            println(length(satisfies), " / ", length(problem.spec), " = ", length(satisfies) / length(problem.spec))


            if length(satisfies) / length(problem.spec) == 1
                println("satisfies all with DT: \n", expr)
                # if haskey(expressions, problem_name)
                #     println("duplicate solution")
                #     println(expressions[problem_name])
                # end
                expressions[problem_name] = expr
                push!(problems_solved_by_n_predicates[n_predicates], j)
                push!(solved_by_DT, j)
                break
            end
        end
        println()
    end


    experiments[me] = [one_prog_satisfies_all, full_cover_many_programs, problems_solved_by_n_predicates, solved_by_DT]



    println("num_predicates: ", num_predicates)
    println("max_enumerations: ", max_enumerations)
    println("experiments")
    print_exp(experiments)
    println()
    println(experiments)
    println()
    println()

end