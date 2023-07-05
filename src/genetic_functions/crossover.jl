function crossover_2_children(parent1::RuleNode, parent2::RuleNode)
    copyparent1 = deepcopy(parent1)
    copyparent2 = deepcopy(parent2)
    
    node_location1::NodeLoc = sample(NodeLoc, copyparent1)
    node_location2::NodeLoc = sample(NodeLoc, copyparent2)
    subprogram1 = get(copyparent1, node_location1)
    subprogram2 = get(copyparent2, node_location2)
    
    if node_location1.i != 0
        insert!(copyparent1, node_location1, subprogram2)
    else
        copyparent1 = subprogram2
    end
    if node_location2.i != 0
        insert!(copyparent2, node_location2, subprogram1)
    else 
        copyparent2 = subprogram1
    end
    return (copyparent1,copyparent2)
end


function crossover_1_child(parent1::RuleNode, parent2::RuleNode)
    copyparent1 = deepcopy(parent1)
    copyparent2 = deepcopy(parent2)
    
    node_location1::NodeLoc = sample(NodeLoc, copyparent1)
    node_location2::NodeLoc = sample(NodeLoc, copyparent2)
    subprogram1 = get(copyparent1, node_location1)                                  
    subprogram2 = get(copyparent2, node_location2)

    if rand() <= 0.5
        if node_location1.i != 0
            insert!(copyparent1, node_location1, subprogram2)
        else
            copyparent1 = subprogram2
        end
        return copyparent1
    end
    if node_location2.i != 0
        insert!(copyparent2, node_location2, subprogram1)
    else 
        copyparent2 = subprogram1
    end

    return copyparent2
end