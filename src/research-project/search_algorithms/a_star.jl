using DataStructures
using CSV, DataFrames

function a_star(grammar, data, enumeration_depth, dataset_id, max_pipeline, index)
    # println("A*")
    # println(enumeration_depth)
    results = a_star_search(grammar, enumeration_depth, max_pipeline, data)

    filename = "a_star_results/$(dataset_id)_$(enumeration_depth)_$(max_pipeline)_($index).csv"
    CSV.write(filename, results)

    best_pipeline = results[findmin(results.cost)[2], 2]
    best_accuracy = results[findmin(results.cost)[2], 3]

    return best_pipeline, 1 - best_accuracy

end


function a_star_search(grammar, max_depth, max_pipeline, data)
    enumerator = Herb.HerbSearch.ContextFreeEnumerator(grammar, max_depth, :START)
    rules = [rule for rule in enumerator]

    d = Dict()
    pq = PriorityQueue()
    df = DataFrame(pipeline = [], rule_node = [], accuracy = Float64[], time = Float64[], cost = Float64[], node = Bool[])
    visited = Set()

    n_pipeline = 1

    for i in 1:4

        accuracy, time, cost_value = a_star_cost(grammar, rules[i], data)
        n_pipeline += 1

        d[rules[i]] = [accuracy, time, cost_value]
        push!(visited, rules[i])
        enqueue!(pq, rules[i], cost_value)

    end

    while n_pipeline <= max_pipeline && !isempty(pq)

        node = dequeue!(pq)
        neighbours = find_neighbours(node, rules)
  

        for neighbour in neighbours

            if n_pipeline > max_pipeline break end

            if neighbour ∉ visited 
                accuracy, time, cost_value = a_star_cost(grammar, neighbour, data)
                n_pipeline += 1

                d[neighbour] = [accuracy, time, cost_value]
                enqueue!(pq, neighbour, cost_value) 
                push!(visited, neighbour)
            end
        end

        push!(df, [Herb.HerbSearch.rulenode2expr(node, grammar), node, d[node][1], d[node][2], d[node][3], true])
    end


     while !isempty(pq)
        node = dequeue!(pq)
        push!(df, [Herb.HerbSearch.rulenode2expr(node, grammar), node, d[node][1], d[node][2], d[node][3], false])
     end

    return df

end

function a_star_cost(grammar, rule, data)
    try

        time = @elapsed begin
            pipeline = eval(Herb.HerbSearch.rulenode2expr(rule, grammar))

            accuracy = evaluate_pipeline(pipeline, data[1], data[2], data[3], data[4])
        end
        
        cost_value  = (1 - accuracy) + 0.001 * (1 + log10(time * 1000))

        return accuracy, time  * 1000, cost_value
    catch err
        # print(err)
        return 0, 0, 2
    end
end

function find_neighbours(rule, rules)
    neighbours = []
    for r in rules
        if Herb.HerbGrammar.depth(r) == (Herb.HerbGrammar.depth(rule) + 2) break end

        if Herb.HerbGrammar.depth(r) == (Herb.HerbGrammar.depth(rule) + 1) && last(r.children) == last(rule.children)
            push!(neighbours, r)
        end
    end
    return neighbours
end