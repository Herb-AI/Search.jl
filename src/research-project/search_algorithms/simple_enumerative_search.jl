"""Simple Enumerative Search (BFS)"""
function simple_enumerative_search(grammar, data, enumeration_depth)

    # initialize values
    best_program = nothing
    best_cost = 1.1
    t_start = now()
        
    # enumerate pipelines in bfs manner
    enumerator = Herb.HerbSearch.ContextFreeEnumerator(grammar, enumeration_depth, :START)
    for rule in enumerator
        if pipelines_evaluated > max_pipelines
            break
        end

        # evaluate the pipeline
        pipeline = eval(Meta.parse(insert_name_indexes(string(Herb.HerbSearch.rulenode2expr(rule, grammar)))))
        cost = pipeline_cost_function(pipeline, data[1], data[2], data[3], data[4])

        # update best cost
        if cost < best_cost
            best_cost = cost
            best_program = rule
        end
    end
    
    return best_program, best_cost
end
