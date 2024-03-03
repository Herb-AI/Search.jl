include("combinators.jl")

# input is grammar and problem
meta_grammar = @csgrammar begin
	S = (problemExamples,grammar) -> generic_run(COMBINATOR...;)
	MS = A
	MS = COMBINATOR
	MAX_DEPTH = 10

	# SA configuration
	sa_inital_temperature = |(1:5)
	sa_temperature_decreasing_factor = |(range(0.9, 1, 10))

	# VLSN configuration
	vlsn_enumeration_depth = 1|2

	ALGORITHM = get_mh_enumerator(problemExamples, HerbSearch.mean_squared_error) | 
				get_sa_enumerator(problemExamples, HerbSearch.mean_squared_error, sa_inital_temperature, sa_temperature_decreasing_factor) |
				get_vlsn_enumerator(problemExamples, HerbSearch.mean_squared_error, vlsn_enumeration_depth)
	A = (ALGORITHM, STOPFUNCTION, MAX_DEPTH, problemExamples, grammar)
	# A = ga,STOP
	# A = dfs,STOP
	# A = bfs,STOP
	# A = astar,STOP
	COMBINATOR = (Sequence, ALIST, MAX_DEPTH, grammar)
	COMBINATOR = (Parallel, ALIST, MAX_DEPTH, grammar)
	ALIST = [MS; MS]
	ALIST = [MS; ALIST]
	# SELECT = best | crossover | mutate
	STOPFUNCTION = (time, iteration, cost) -> time > BIGGEST_TIME
	ITERATION_STOP = iteration > VALUE
	# STOPTERM = OPERAND < VALUE
	# OPERAND = time | iteration | cost
	BIGGEST_TIME = 10 | 20 | 30
	VALUE = 1000 | 2000 | 3000 | 4000 | 5000
	# VALUE = 10 * VALUE
end

function evaluate_meta_program(meta_expression,problem, grammar)
	# get the function (problem,examples) -> run program
	program = eval(meta_expression)   
	# provide the problem and the grammar for that problem 
	return Base.@invokelatest program(problem.spec, grammar)
end