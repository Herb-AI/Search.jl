prob_gram_pairs = all_problem_grammar_pairs(PBE_BV_Track_2018)
prob_gram_pairs = all_problem_grammar_pairs(PBE_SLIA_Track_2019)

filtered_prob_gram_pairs = []
for pg in prob_gram_pairs
    if length(pg[2][1].spec) < 1000
        push!(filtered_prob_gram_pairs, pg)
    end
end

max_enumerations=[100, 500, 1000, 10000, 20000, 40000, 100000]

# all_solved_by_ES = Dict{Any, Any}(5 => 7, 20 => 5, 81 => 8, 58 => 7, 75 => 5, 37 => 3, 23 => 7, 41 => 4, 67 => 4, 69 => 4, 36 => 4, 43 => 5, 98 => 8, 82 => 7, 80 => 8, 96 => 7, 39 => 4, 51 => 5, 77 => 3, 7 => 6, 25 => 4, 95 => 8, 90 => 5, 71 => 7, 66 => 5, 34 => 4, 70 => 4, 65 => 3, 97 => 6, 38 => 7)
all_solved_by_DT = Dict{Any, Any}(79 => 22, 35 => 63, 58 => 14, 52 => 34, 30 => 34, 53 => 38, 6 => 29, 44 => 35, 98 => 18, 73 => 61, 82 => 8, 3 => 22, 96 => 20, 64 => 33, 95 => 13, 71 => 22, 50 => 20, 15 => 23, 27 => 20, 38 => 8)

all_solved_by_DT = Dict()
all_solved_by_ES = Dict()

solved_ES = Dict()
solved_DT = Dict()
# solved_problems = Set([177,141,160,146,80,244,202])
solved_problems = Set([58,98,82,96,95,71,38,79])
for me in max_enumerations
    solved_DT[me] = []
    solved_ES[me] = []
    for (j, pg) in enumerate(filtered_prob_gram_pairs)
        if !(j in solved_problems)
            continue
        end
        problem_name = pg[1]
        problem = pg[2][1]
        grammar = pg[2][2]
        println(j, " name: ", pg[1]) 
        println(j, " ", problem_name, ", max enums: ",me)

        iterations_subset = me * 4/5
        iterations_dt = me * 1/5

        iterator = BFSIterator(grammar, :Start)
        solDT, resDT = smallest_subset(problem, iterator, max_enumerations=me, allow_evaluation_errors=true)

        if resDT == HerbSearch.full_cover && length(solDT) == 1
            push!(solved_DT[me], j)
            push!(solved_ES[me], j)
            println(solDT[1][1])
            all_solved_by_ES[j] = length(solDT[1][1])
            continue
        end

        
        ret = learn_DT(problem, grammar, :Start, :ntBool, solDT, iterations_dt)
        # ret = learn_DT(problem, grammar, :Start, nothing, solDT, iterations_dt)
        if isnothing(ret)
            continue
        end

        rulenode, g = ret
        satisfies = satisfies_examples(problem, rulenode2expr(rulenode, g), SymbolTable(g, Main), allow_evaluation_errors=true)

        if length(satisfies) / length(problem.spec) == 1
            
            println("LENGTH of programs ", length(solDT))
            if !haskey(all_solved_by_DT, j)
                all_solved_by_DT[j] = length(rulenode)
            end
            if length(rulenode) < all_solved_by_DT[j] 
                all_solved_by_DT[j] = length(rulenode)
            end
            push!(solved_DT[me], j)
        end
        println()
    end

    for k in keys(solved_DT)
        println(k, ": length DT == ", length(solved_DT[k]), ", ", solved_DT[k])
        println(k, ": length ES == ", length(solved_ES[k]), ", ", solved_ES[k])
    end
    println("1:1")
    println("all_solved_by_ES: ", all_solved_by_ES)
    println("all solved by DT: ",all_solved_by_DT)
    println()
end

println("all_solved_by_ES: ", all_solved_by_ES)
println("all_solved_by_DT: ", all_solved_by_DT)
for k in keys(all_solved_by_ES)
    if haskey(all_solved_by_DT, k)
        println("prob: ", k,"-> ", all_solved_by_ES[k]," ", all_solved_by_DT[k])
    end
end
