using Revise

include("../Herb.jl/src/Herb.jl")

# ×(a, b) = a * b

g = Herb.HerbGrammar.@cfgrammar begin
    Program = DAG -> EST # Directed Acyclic Graph to Estimator
    DAG = PASS | EST | DAG -> DAG # DAG can just pass data, can be an estimator or can be a transition from DAG to DAG 
    DAG = ( DAG & DAG ) -> CONCAT # two DAG can be concatinated together
    EST = 1
    CONCAT = 2
    PASS = 0
    

#     Real = |(0:3)
#     Real = a
#     Real = Real + Real
#     Real = Real × Real
end

# problem = Herb.HerbData.Problem([Herb.HerbData.IOExample(Dict(:x => x), 3x) for x ∈ 1:5], "example")

# Herb.HerbSearch.enumerative_search(g₁, problem, 3, Herb.HerbSearch.ContextFreeBFSEnumerator)

println(collect(enumerate(g.rules)))