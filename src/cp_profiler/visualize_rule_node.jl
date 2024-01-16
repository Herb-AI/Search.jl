using Revise, Sockets, HerbCore

include("connector.jl");

mutable struct RefInt
    value::Int;
end

mutable struct VisualizerConfig
    max::Int
    request_counter::Int
    sent_counter::Int
end

visualizer_config = VisualizerConfig(10, 0, 0);

function visualize(g::Grammar, r::AbstractRuleNode, name::String="MyTree")
    global visualizer_config;
    visualizer_config.request_counter += 1;
    if (visualizer_config.sent_counter >= visualizer_config.max)
        return;
    end
    visualizer_config.sent_counter += 1;
    name *= string(visualizer_config.request_counter)
    println("Sending a request to visualize '$(name)'")

    conn = Connector()
    start(conn, name)
    conn.msg.nodeId = -1
    visualize(g, r, conn, RefInt(0), 0, 0)
    close(conn)
end

function visualize(g::Grammar, r::Hole, conn::Connector, uniqueID::RefInt, pid::Int, alt::Int)
    uniqueID.value += 1;
    id = uniqueID.value;
    node(conn, id, pid, alt, 1, SOLVED, "Hole ($(count(r.domain)) options)", "info");
end

function visualize(g::Grammar, r::RuleNode, conn::Connector, uniqueID::RefInt, pid::Int, alt::Int)
    uniqueID.value += 1;
    id = uniqueID.value;
    node(conn, id, pid, alt, 1, BRANCH, string(g.rules[r.ind]), "info");
    for (alt, child) ∈ enumerate(r.children)
        visualize(g, child, conn, uniqueID, id, alt-1);
    end
end
