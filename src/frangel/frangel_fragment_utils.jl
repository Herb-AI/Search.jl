"""
    mine_fragments(grammar::AbstractGrammar, program::RuleNode)::Set{RuleNode}

Finds all the fragments from the provided `program`. The result is a set of the distinct fragments, generated recursively by going over all children.

# Arguments
- `grammar`: The grammar rules of the program.
- `program`: The program to mine fragments for.

# Returns
All the found fragments in the provided program.

"""
function mine_fragments(grammar::AbstractGrammar, program::RuleNode)::Set{RuleNode}
    fragments = Set{RuleNode}()
    if isterminal(grammar, program)
        push!(fragments, program)
    else
        if iscomplete(grammar, program)
            push!(fragments, program)
        end
        for child in program.children
            fragments = union(fragments, mine_fragments(grammar, child))
        end
    end
    fragments
end

"""
    mine_fragments(grammar::AbstractGrammar, programs::Set{RuleNode})::Set{RuleNode}

Finds all the fragments from the provided `programs` list. The result is a set of the distinct fragments found within all programs.

# Arguments
- `grammar`: The grammar rules of the program.
- `programs`: A set of programs to mine fragments for.

# Returns
All the found fragments in the provided programs.

"""
function mine_fragments(grammar::AbstractGrammar, programs::Set{RuleNode})::Set{RuleNode}
    fragments = reduce(union, mine_fragments(grammar, p) for p in programs)
    for program in programs
        delete!(fragments, program)
    end
    fragments
end

function mine_fragments(grammar::AbstractGrammar, programs::Set{Tuple{RuleNode,Int,Int}})::Set{RuleNode}
    fragments = reduce(union, mine_fragments(grammar, p) for (p, _, _) in programs)
    for program in programs
        delete!(fragments, program)
    end
    fragments
end

"""
    remember_programs!(old_remembered::Dict{BitVector, Tuple{RuleNode, Int, Int}}, passing_tests::BitVector, new_program::RuleNode, 
        fragments::Set{RuleNode}, grammar::AbstractGrammar)::Set{RuleNode}

Updates the remembered programs by including `new_program` if it is simpler than all remembered programs that pass the same subset of tests, 
    and there is no simpler program passing a superset of the tests. It also removes any "worse" programs from the dictionary.

# Arguments
- `old_remembered`: The previously remembered programs, represented as a dictionary mapping `passed_tests` to (program's tree, the tree's `node_count`, `program_length`).
- `passing_tests`: A BitVector representing the passing test set for the new program.
- `new_program`: The new program to be considered for addition to the `old_remembered` dictionary.
- `fragments`: A set the fragments mined from the `old_remembered` dictionary.
- `grammar`: The grammar rules of the program.

# Returns
The newly mined fragments from the updated remembered programs.

"""
function remember_programs!(
    old_remembered::Dict{BitVector,Tuple{RuleNode,Int,Int}},
    passing_tests::BitVector,
    new_program::RuleNode,
    fragments::Set{RuleNode},
    grammar::AbstractGrammar
)::Set{RuleNode}
    node_count = count_nodes(grammar, new_program)
    program_length = length(string(rulenode2expr(new_program, grammar)))
    # Check the new program's testset over each remembered program
    for (key_tests, (_, p_node_count, p_program_length)) in old_remembered
        isSimpler = node_count < p_node_count || (node_count == p_node_count && program_length < p_program_length)
        # if the new program's passing testset is a subset of the old program's, discard new program if worse
        if all(passing_tests .== (passing_tests .& key_tests))
            if !isSimpler
                return fragments
            end
            # else if it is a superset -> discard old program if worse (either more nodes, or same #nodes but less tests)
        elseif all(key_tests .== (key_tests .& passing_tests))
            if isSimpler || (passing_tests != key_tests && node_count == p_node_count)
                delete!(old_remembered, key_tests)
            end
        end
    end
    old_remembered[passing_tests] = (new_program, node_count, program_length)
    mine_fragments(grammar, Set(values(old_remembered)))
end