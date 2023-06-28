include("../lib/HerbSearch.jl/src/HerbSearch.jl")
function genetic_algorithm(grammar, data, population_size, max_depth, cross_over_prob, mutation_prob)
    function mutation(chromosome, grammar)
        # find all children 
        
        children = get_children(chromosome)
        # select random node
        (gen, loc) = children[rand(1:length(children))]
        
        loc = split(loc, ", ")[1:(length(split(loc, ", "))-1)]
        # find type 
        type = find_type(gen, grammar)
        # select random of same type
        new_gen = get_random_other_rule(gen, type, grammar)
        # exchange 
        exchange(chromosome, new_gen, loc)
        return chromosome
    end
    
    function get_children(chromosome)
        if (length(chromosome.children) == 0)
            return [(chromosome, "")]
        else
            children = []
            for child in chromosome.children
                for grand_child in get_children(child)
                    # Keep track of the path to the grand child
                    push!(children, (grand_child[1], "$(child.ind), $(grand_child[2])")) 
                end
            end
            return children 
        end 
    end
    
    function fitness_function(chromosome) 
        # convert rulenode to pipeline 
        pipeline = eval(Meta.parse(insert_name_indexes(string(Herb.HerbSearch.rulenode2expr(chromosome, grammar)))))
        fitness = 0
        
        try    
            cost = pipeline_cost_function(pipeline, data[1], data[2], data[3], data[4])
            fitness = 1 - cost
        catch ex
            println(ex) 
            fitness = 0
        end    
              
        return fitness
    end
    
    function find_type(gen, grammar)
        type = nothing
        for i in 1:length(grammar.types)
            if(Herb.HerbGrammar.rulenode2expr(gen, grammar) == grammar.rules[i])
                type = grammar.types[i]
            end
        end
        return type
    end
    
    function get_random_other_rule(gen, type, grammar)
        others = []
        
        for i in 1:length(grammar.types)
            if(grammar.types[i] == type && Herb.HerbGrammar.rulenode2expr(gen, grammar) != grammar.rules[i])
                new_gen = Herb.HerbGrammar.RuleNode(i)
                push!(others, new_gen)
            end
        end
        
        return others[rand(1:length(others))]
    end
    
    function exchange(chromosome, new_gen, loc)
        if (length(loc) == 1)
            for i in 1:length(chromosome.children)
                if ("$(chromosome.children[i].ind)" == loc[1])
                    chromosome.children[i] = new_gen
                    return 
                end
            end
        else 
            for i in 1:length(chromosome.children)
                if ("$(chromosome.children[i].ind)" == loc[1])
                    exchange(chromosome.children[i], new_gen, loc[2:length(loc)])
                end
            end
        end
    
    end
    
    
    function stopping_condition(iteration, fitness)
        return iteration > 10 || fitness >= 9.9
    end
    
    function cross_over(chromosome1, chromosome2, fitness_function)
        
        copy1 = Base.deepcopy(chromosome1)
        copy2 = Base.deepcopy(chromosome2)
        # find crossing point 
        rules1 = get_cross_point(copy1)
        rules2 = get_cross_point(copy2)
        
        rule1 = rules1[rand(1:length(rules1)-1)]
        rule2 = rules2[rand(1:length(rules2)-1)]
        
        while length(get_cross_point(rule1)) != length(get_cross_point(rule2))
            rules1 = get_cross_point(copy1)
            rules2 = get_cross_point(copy2)
        
            rule1 = rules1[rand(1:length(rules1)-1)]
            rule2 = rules2[rand(1:length(rules2)-1)]
        end
    
        # cross over 
        exchange_rules(copy1, rule2, rule1)
        exchange_rules(copy2, rule1, rule2)    
        if fitness_function(copy1) == 0 || fitness_function(copy2) == 0
            return (chromosome1, chromosome2)  
        end
        return (copy1, copy2) 
    end
    
    function get_cross_point(chromosome)
        rules = []
        for child in chromosome.children
            push!(rules, child)
            for grand_child in get_cross_point(child)
                push!(rules, grand_child)
            end 
        end
        return rules
    end
    
    function exchange_rules(chromosome, rule1, rule2)
        for i in (1:length(chromosome.children))
            
            if (chromosome.children[i] == rule2)
                chromosome.children[i] = rule1
                return
            end
            exchange_rules(chromosome.children[i], rule1, rule2) 
        end
        return
    end

    
    it = Herb.HerbSearch.GeneticSearchIterator(
        grammar, 
        Vector{Herb.HerbData.IOExample}([]), 
        fitness_function,
        cross_over,
        mutation, 
        stopping_condition, 
        :START, 
        max_depth, 
        population_size,
        cross_over_prob, 
        mutation_prob
)
   results = Base.iterate(it)
   return (results.best_programs[length(results.best_programs)], results.best_program_fitnesses[length(results.best_program_fitnesses)])
end