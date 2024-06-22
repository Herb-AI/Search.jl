prob_gram_pairs = all_problem_grammar_pairs(PBE_SLIA_Track_2019)

good = [3, 5, 44, 58, 79, 96, 98]

incomplete = []
no_solution = []
skip = true

max_enumerations=[100, 500, 1000, 10000, 20000, 40000, 100000]
problems_solved = []
full_cover_and_satisfies_all = []
full_cover_cant_satisfy = []


for me in max_enumerations
    for (j, pg) in enumerate(prob_gram_pairs)
        if j in full_cover_and_satisfies_all
            continue
        end
        problem_name = pg[1]
        problem = pg[2][1]
        grammar = pg[2][2]

        println(j, " ", problem_name)
        iterator = BFSIterator(grammar, :Start)
        solution, result = synth(problem, iterator, max_enumerations=me, allow_evaluation_errors=true)

        if result == optimal_program
            push!(full_cover_and_satisfies_all, j)
        end
    end
    push!(problems_solved, length(full_cover_and_satisfies_all))
    println("max_enumerations: ",max_enumerations, " enumerations now: ", me)
    println("problems solved: ",problems_solved)
end