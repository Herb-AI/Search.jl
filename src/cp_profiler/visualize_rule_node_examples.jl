using Revise, HerbCore, HerbGrammar

include("visualize_rule_node.jl")

g = @cfgrammar begin
    Number = |(1:2)
    Number = x
    Number = Number + Number
    Number = Number * Number
end

r = RuleNode(5, [
    RuleNode(1),
    RuleNode(5, [
        RuleNode(1),
        Hole(get_domain(g, :Number))
    ])
])

visualize(g, r, "ExampleTree")
