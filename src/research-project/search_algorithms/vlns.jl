"""constructs neighborhood given the pipeline and returns the best neighbor in its neighborhood"""
function find_best_neighbour_in_neighbourhood(current_program, grammar, data, enumeration_depth, max_pipeline_depth, neighbours_per_iteration, print_statements=false)
    # 1. Construct neighbourhood
    neighbourhood_node_loc, dict = Herb.HerbSearch.constructNeighbourhoodRuleSubset(current_program, grammar)
    replacement_expressions = Herb.HerbSearch.enumerate_neighbours_propose(enumeration_depth)(current_program, 
                                                                                                neighbourhood_node_loc, 
                                                                                                grammar,
                                                                                                max_pipeline_depth, # = max depth of pipeline, depth of subprogram is bound by this
                                                                                                dict)

    # 2. Find best neighbour
    best_program = deepcopy(current_program)
    pipeline = eval(Meta.parse(insert_name_indexes(string(Herb.HerbSearch.rulenode2expr(best_program, grammar)))))
    best_program_cost = pipeline_cost_function(pipeline, data[1], data[2], data[3], data[4])
    possible_program = current_program
    neighbours_tried = 0
    for replacement_expression in replacement_expressions
        if (neighbours_tried % 5) == 0
            if print_statements
                println("Tried ", neighbours_tried, " neighbours")
            end
        end
        if neighbours_tried == neighbours_per_iteration
            break
        end
        if pipelines_evaluated == max_pipelines
            if print_statements
                println("max pipelines reached [find_best_neighbour_in_neighbourhood]")
            end
            break
        end
        # change current_program to one of its neighbours 
        if neighbourhood_node_loc.i == 0
            possible_program = replacement_expression
        else
            neighbourhood_node_loc.parent.children[neighbourhood_node_loc.i] = replacement_expression
        end
        pipeline = eval(Meta.parse(insert_name_indexes(string(Herb.HerbSearch.rulenode2expr(possible_program, grammar)))))
        possible_program_cost = pipeline_cost_function(pipeline, data[1], data[2], data[3], data[4])
        if possible_program_cost <= best_program_cost
            best_program = deepcopy(current_program)
            best_program_cost = possible_program_cost        
        end
        neighbours_tried += 1
    end
    return best_program, best_program_cost
end


"""Very Large Neighborhood Search"""
function vlns(grammar, data, enumeration_depth, max_pipeline_depth, neighbours_per_iteration=15, print_statements=false)
    current_program = get_random_pipeline(grammar, max_pipeline_depth, :START)
    println("start pipeline: ", current_program)
    current_cost = 1.1
    i = 0
    while true
        if pipelines_evaluated == max_pipelines
            if print_statements
                println("max pipelines reached [vlns]")
            end
            break
        end
        if print_statements
            println("Iteration: ", i)
        end
        previous_cost = current_cost
        current_program, current_cost = find_best_neighbour_in_neighbourhood(current_program, grammar, data, enumeration_depth, max_pipeline_depth, neighbours_per_iteration, print_statements)

        if current_cost == 0.0
            if print_statements
                println("Stopping because cost is 0.0")
            end
            break
        end
        i += 1
    end
    if print_statements
        println("Final program: ", current_program)
        println("Final cost: ", current_cost)
    end
    return current_program, current_cost
end