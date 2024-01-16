mutable struct SearchStatistics
    grammar::Grammar
    number_of_search_nodes::Int
    number_of_solutions::Int
    number_of_fails::Int
    start_time::Number
    connector::Union{Connector, Nothing}
end

function SearchStatistics(grammar)
    # connector = Connector()
    # start(connector, "SearchTree")
    # SearchStatistics(grammar, 0, 0, 0, time(), connector)
    SearchStatistics(grammar, 0, 0, 0, time(), nothing)
end

#todo: (tree, id, pid, alt, numberOfChildren) should be packed in a PriorityQueueItem (or, "SearchNode")
function on_complete_tree(stats::SearchStatistics, tree::AbstractRuleNode, id::Int, pid::Int, alt::Int, numberOfChildren::Int)
    stats.number_of_fails += 1; #todo: this could also be a solution
    #println("$(pid) -> $(id) COMPLETE")
    # if (stats.number_of_fails == 1710)
    #     visualize(stats.grammar, tree)
    # end
    #node(stats.connector, id, pid, alt, numberOfChildren, FAILED, string(tree), string(rulenode2expr(tree, stats.grammar)));
end

#todo: (tree, id, pid, alt, numberOfChildren) should be packed in a PriorityQueueItem (or, "SearchNode")
function on_partial_tree(stats::SearchStatistics, tree::AbstractRuleNode, id::Int, pid::Int, alt::Int, numberOfChildren::Int)
    stats.number_of_search_nodes += 1;
    #println("$(pid) -> $(id) PARTIAL")
    #visualize(stats.grammar, tree)
    #node(stats.connector, id, pid, alt, numberOfChildren, BRANCH, string(tree), string(tree));
end


function Base.show(io::IO, stats::SearchStatistics)
    println(io, "SearchStatistics {")
    println(io, "    time elapsed =    " * string(round(time() - stats.start_time, digits=3)) * " sec,")
    println(io, "    #partial trees =  " * string(stats.number_of_search_nodes) * ",")
    println(io, "    #complete trees = " * string(stats.number_of_fails) * ",")
    # println(io, "    #internalnodes = " * string(stats.number_of_search_nodes) * ",")
    # println(io, "    #solutions =     " * string(stats.number_of_solutions) * ",")
    # println(io, "    #fails =         " * string(stats.number_of_fails) * ",")
    println(io, "}")
end
