using HerbCore 
using HerbGrammar
using HerbData
using HerbSearch
using Logging
disable_logging(LogLevel(1))

using Base.Threads
include("combinators.jl")


arithmetic_grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

# CREATE A PROBLEM
function create_problem(f, range=5)
    examples = [HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return HerbData.Problem(examples,"problem"), examples
end

problem, examples = create_problem(x -> x ^ 4 + x * x + 2 * x + 5)

meta_grammar = @csgrammar begin
    S = generic_run(COMBINATOR...;)
    MS = A
    MS = COMBINATOR
    MAX_DEPTH = 8
    sa_inital_temperature = |(1:5)
    # range from splits the range from [0.9,1] and generates 10 numbers with equal distance to each other
    sa_temperature_decreasing_factor = |(range(0.9,1,10))
    vlsn_enumeration_depth = |(2:3)
    GIVEN_GRAMMAR = arithmetic_grammar
    GIVEN_PROBLEM = problem
    ALGORITHM = mh() | sa(sa_inital_temperature,sa_temperature_decreasing_factor) | vlsn(vlsn_enumeration_depth)
    A = (ALGORITHM,STOPFUNCTION,MAX_DEPTH,GIVEN_PROBLEM,GIVEN_GRAMMAR)
    # A = ga,STOP
    # A = dfs,STOP
    # A = bfs,STOP
    # A = astar,STOP
    # MHCONFIGURATION = MAXDEPTH
    # MAXDEPTH = 3
    COMBINATOR = (Sequence,ALIST,MAX_DEPTH,GIVEN_GRAMMAR)
    COMBINATOR = (Parallel,ALIST,MAX_DEPTH,GIVEN_GRAMMAR)
    ALIST = [MS;MS]
    ALIST = [MS;ALIST]
    # COMBINATOR = sequence(MSLIST)
    # COMBINATOR = parallel([MSLIST],SELECT)
    # MSLIST = MS,MS
    # MSLIST = MS,MSLIST
    # SELECT = best | crossover | mutate
    STOPFUNCTION = (time, iteration, cost) -> STOPCONDITION
    STOPCONDITION = STOPTERM
    STOPCONDITION = STOPTERM && STOPCONDITION
    # STOPTERM = OPERAND == VALUE
    STOPTERM = ITERATION_STOP
    ITERATION_STOP = iteration > VALUE
    # STOPTERM = OPERAND < VALUE
    # OPERAND = time | iteration | cost
    OPERAND = iteration
    VALUE = |(100:110)
    VALUE = 10 * VALUE
end


mh() = get_mh_enumerator(examples, HerbSearch.mean_squared_error)
sa(inital_temperature,temperature_decreasing_factor) = get_sa_enumerator(examples, HerbSearch.mean_squared_error, inital_temperature, temperature_decreasing_factor)
vlsn(enumeration_depth) = get_vlsn_enumerator(examples, HerbSearch.mean_squared_error, enumeration_depth)

# GENERATE META SEARCH PROCEDURE AND RUN IT
function run_grammar_multiple_times()
    for _ in 1:10
        meta_program = rand(RuleNode, meta_grammar, :S, 10)
        meta_expr = rulenode2expr(meta_program, meta_grammar)
        println(meta_expr)
        @time expr,_,_ = eval(meta_expr)
    end
end

function fitness_function(program, _)
    start_time = time()
    expression = rulenode2expr(program, meta_grammar)
    println("Expr",expression)    
    expr, prog, cost = eval(expression)
    duration = time() - start_time
    return 1 / (cost * 100 + duration) 
end
meta_program = rand(RuleNode, meta_grammar, :S, 10)

genetic_algorithm = get_genetic_enumerator(Vector{Example}([]),fitness_function = fitness_function)
mh_alg = get_mh_enumerator(Vector{Example}([]),fitness_function = fitness_function)
outcome = supervised_search(meta_grammar,problem,:S,(time, iteration, cost) -> time > 5, meta_program, enumerator 



= genetic_algorithm)
println(outcome)