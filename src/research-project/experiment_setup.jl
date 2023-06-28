# # uncomment the following if not all packages are added.

# import Pkg
# using Pkg
# Pkg.add("HTTP")
# Pkg.add("JSON")
# Pkg.add("DataFrames")
# Pkg.add("OpenML")
# Pkg.add("DataFrames") 
# Pkg.add("CSV") 
# Pkg.add("Suppressor")
# Pkg.add("StatsBase")
# Pkg.add("ScikitLearn")
# Pkg.add("OpenSSL_jll")

using ScikitLearn
using ScikitLearn.Pipelines: Pipeline, FeatureUnion
using ScikitLearn.CrossValidation: cross_val_score
using XGBoost
using Revise
using Random
using Statistics: mean
using Suppressor
using Random
using Dates

include("./Herb.jl/src/Herb.jl")
include("./Herb.jl/HerbGrammar.jl/src/HerbGrammar.jl")
include("./Herb.jl/HerbData.jl/src/HerbData.jl")
include("./Herb.jl/HerbEvaluation.jl/src/HerbEvaluation.jl")
include("./Herb.jl/HerbConstraints.jl/src/HerbConstraints.jl")
include("./Herb.jl/HerbSearch.jl/src/HerbSearch.jl")
include("helper.jl")

#declaration of global variables, max_pipeline is set at the bottom of the file
global pipelines_evaluated = 0
global max_pipelines = 0

# import the search algorithms
include("./search_algorithms/simple_enumerative_search.jl")
include("./search_algorithms/metropolis_hastings.jl")
include("./search_algorithms/genetic_algorithm.jl")
include("./search_algorithms/vlns.jl")
include("./search_algorithms/mcts.jl")
include("./search_algorithms/a_star.jl")


# import the sk-learn functions
@sk_import decomposition: (PCA)
@sk_import preprocessing: (StandardScaler, RobustScaler, MinMaxScaler, MaxAbsScaler, Binarizer, PolynomialFeatures)
@sk_import feature_selection: (VarianceThreshold, SelectKBest, SelectPercentile, SelectFwe, RFE)
@sk_import tree: (DecisionTreeClassifier)
@sk_import ensemble: (RandomForestClassifier, GradientBoostingClassifier)
@sk_import linear_model: (LogisticRegression)
@sk_import neighbors: (NearestNeighbors, KNeighborsClassifier)
@sk_import svm: (LinearSVC)

Random.seed!(1234)


"""
Splits the dataset in the train set, validation set and test set. 
Also splits the features and labels.
"""
function split_dataset(dataset)
    
    # load and shuffle dataset
    dataset_shuffled = dataset[shuffle(1:end), :]
    
    # split into train and test sets 
    train_ind = floor(Int, size(dataset_shuffled, 1) * 0.70)
    val_ind = train_ind + floor(Int, size(dataset_shuffled, 1) * 0.15)
    train_df = dataset_shuffled[1:train_ind, :]
    val_df = dataset_shuffled[(train_ind+1):val_ind, :]
    test_df = dataset_shuffled[(val_ind+1):end, :]

    # split into features and labels
    train_X = train_df[:, 1:end-1]
    train_Y = train_df[:, end]
    test_X = test_df[:, 1:end-1]
    test_Y = test_df[:, end]
    val_X = val_df[:, 1:end-1]
    val_Y = val_df[:, end]

    return train_X, train_Y, val_X, val_Y, test_X, test_Y
end


# define the grammar
grammar = Herb.HerbGrammar.@cfgrammar begin
    
    # multiple classifiers possible
    START   = Pipeline([CLASSIF]) | Pipeline([PRE, CLASSIF])
    PRE     = PREPROC | FSELECT | ("seq", Pipeline([PRE, PRE]))  | ("par", FeatureUnion([PRE, PRE])) 
    # BRANCH  = PRE | CLASSIF | ("seq", Pipeline([PRE, CLASSIF]))

    # preprocessing functions
    PREPROC =   
        ("StandardScaler", StandardScaler()) |
        ("RobustScaler", RobustScaler()) |
        ("MinMaxScaler", MinMaxScaler()) |
        ("MaxAbsScaler", MaxAbsScaler()) |
        ("PCA", PCA()) |
        ("Binarizer", Binarizer()) |
        ("PolynomialFeatures", PolynomialFeatures())

    # feature selection functions
    FSELECT =  
        ("VarianceThreshold", VarianceThreshold()) |
        ("SelectKBest",  SelectKBest(k=4)) |
        ("SelectPercentile",  SelectPercentile()) |
        ("SelectFwe",  SelectFwe()) |
        ("Recursive Feature Elimination",  RFE(LinearSVC())) 

    # classifiers
    CLASSIF =
        ("DecisionTree", DecisionTreeClassifier()) |
        ("RandomForest", RandomForestClassifier()) |
        ("Gradient Boosting Classifier", GradientBoostingClassifier()) |
        ("LogisticRegression", LogisticRegression()) 
        ("KNearestNeighbors", KNeighborsClassifier())
end

"""
this method appends a number to each of the pipeline step names 
e.g. Pipeline(("op", op()), ("op", op()), ...) -> Pipeline(("op1", op()), ("op2", op()), ...)
this way all of the step names are unique
the input is the pipeline as a string, the output is also a string
"""
function insert_name_indexes(p)
    p_start = ""
    i = 1
    while i <= 100
        try
            p = replace(p, """",""" => string(i)*"""",""", count=1)
            p_split = split(p, string(i) * """", """)
            p_start *= p_split[1] * string(i) * """", """
            p = p_split[2]
            i += 1
        catch
            break
        end
    end
    return split(p_start, string(i))[1]
end

"""chooses a random pipeline from the grammar"""
function get_random_pipeline(grammar, max_depth, start_symbol)
    # all pipelines that can be assembled in max_depth steps
    cfe = Herb.HerbSearch.ContextFreeEnumerator(grammar, max_depth, start_symbol)
    cfe_size = deepcopy(cfe)
    
    # find size
    size = 0
    for pipeline in cfe_size
        size += 1
    end

    # Find start program
    ret_pipeline = nothing
    c = 0
    i = abs(rand(Int) % size)
    for pipeline in cfe
        if c == i
            ret_pipeline = pipeline
            break
        end
        c = c + 1
    end
    return ret_pipeline
end

"""chooses a random element from array"""
function rand_choose(a::Array)
    n = length(a)
    idx = mod(rand(Int64),n)+1
    return a[idx]
end



"""
Fits the pipeline to the training set and measures the accuracy on test set.
input:  pipeline, train_X, train_Y, test_X, test_Y
output: accuracy of pipeline
"""
function evaluate_pipeline(pipeline, train_X, train_Y, test_X, test_Y)
    global pipelines_evaluated += 1
    println(pipelines_evaluated)    

    if pipelines_evaluated > max_pipelines
        return 0.0
    end

    # # this gives the following warning often, so it is suppressed for now.
    # # ConvergenceWarning: lbfgs failed to converge
    @suppress_err begin
        try
            # fit the pipeline
            model = ScikitLearn.fit!(pipeline, Matrix(train_X), Array(train_Y))
            # make predictions
            predictions = ScikitLearn.predict(model, Matrix(test_X))
            # measure the accuracy
            accuracy = mean(predictions .== test_Y)
            return accuracy
        catch e
            println("Caught error [in evaluate_pipeline()]: ", e)
            return 0.0
        end
    end
end

"""Trains the pipeline and returns 1-accuracy"""
function pipeline_cost_function(pipeline, train_X, train_Y, test_X, test_Y)
    return 1.0 - evaluate_pipeline(pipeline, train_X, train_Y, test_X, test_Y)
end

"""returns a string with information about the parameters"""
function parameters_info_string(search_alg_name, dataset_ids, n_runs, grammar, enumeration_depth, max_pipeline_depth, neighbours_per_iteration)
    result  = 
        "Search algorithm: " * uppercase(search_alg_name) * "\n" *
        "Datasets: " * string(dataset_ids) * "\n" *
        "Number of runs: " * string(n_runs) * "\n" *
        "train_on_n_samples: " * string(train_on_n_samples) * "\n" *
        "Start time: " * string(Dates.format(now(), "yyyy-mm-dd HH:MM:SS")) * "\n" * 

        "Parameters: " * "\n" * 
        "enumeration_depth: " * string(enumeration_depth) * "\n" * 
        "max_pipeline_depth: " * string(max_pipeline_depth) * "\n" * 
        "neighbours_per_iteration (only vlns): " * string(neighbours_per_iteration) * "\n\n\n" *
        "Results: \n\n"

    return result
end

"""returns a string with information about te run"""
function run_info_string(dataset_id, grammar, search_alg_name, start_time, end_time, best_pipeline, best_cost, accuracy)
    duration = (end_time-start_time).value

    result  = 
        "Dataset: " * string(dataset_id) * "\n" *
        "Search algorithm: " * uppercase(search_alg_name) * "\n" *
        "Duration: " * string(round(duration/60000, digits=2)) * " minutes" *
        " (= " * string(round(duration/1000, digits=2)) * " seconds)" * "\n" * 
        "Best pipeline: " * string(best_pipeline) * "\n" * 
        "             : " * string(Herb.HerbSearch.rulenode2expr(best_pipeline, grammar)) * "\n" *
        "Cost: " * string(best_cost)* "\n"  *
        "Test Accuracy: " * string(accuracy) * "\n\n"
        
    return result
end

"""ruturns a string representation of a dictionary"""
function pretty_print_dict(d::Dict, pre=1)
    res = ""
    for (k,v) in d
        if typeof(v) <: Dict
            s = "$(repr(k)) => "
            res *= (join(fill(" ", pre)) * s) * "\n"
            res *= pretty_print_dict(v, pre+1+length(s)) * "\n"
        else
            res *= (join(fill(" ", pre)) * "$(repr(k)) => $(repr(v))") * "\n"
        end
    end
    return res
end

"""
Loads the datasets and runs the search algorithm n_runs amount of times.
It saves the results in a dictionary and returns this. 
"""
function run_search(
        search_alg_name, 
        dataset_ids,
        n_runs,
        grammar, 
        enumeration_depth,
        max_pipeline_depth,
        neighbours_per_iteration,
        train_on_n_samples,
        mcts_iterations)


    # information about the runs
    result_string = parameters_info_string(search_alg_name, dataset_ids, n_runs, grammar, enumeration_depth, max_pipeline_depth, neighbours_per_iteration)
    results = Dict{Int, Any}()

    for dataset_id in dataset_ids
        # add new field to the results dict
        merge!(results, Dict(
            dataset_id => Dict(
                "accuracy" => [],
                "avg_accuracy" => 1.11,
                "sample_variance_accuracy" => 1.11
        )))
        ##load dataset HERE
        dataset = get_dataset(dataset_id)
        # run the search algorithm n_runs times
        for i in range(1, n_runs)
            
            # get train-test splits
            # Shuffle and split the dataset
            train_X, train_Y, val_X, val_Y, test_X, test_Y = split_dataset(dataset)
            data = [first(train_X, train_on_n_samples), first(train_Y, train_on_n_samples), first(val_X, train_on_n_samples), first(val_Y, train_on_n_samples)]
            global pipelines_evaluated = 0

            println(string(dataset_id) * " - " * string(i))
            best_program = nothing
            best_program_cost = nothing

            start_time = now()
            if search_alg_name == "mh"
                best_program, best_program_cost = mh(  grammar, data, enumeration_depth, max_pipeline_depth)
            elseif search_alg_name == "vlns"
                best_program, best_program_cost = vlns(grammar, data, enumeration_depth, max_pipeline_depth, neighbours_per_iteration)
            elseif search_alg_name == "bfs"
                best_program, best_program_cost = simple_enumerative_search(grammar, data, enumeration_depth)
            elseif search_alg_name == "mcts"
                best_program, best_program_cost = mcts(grammar, data, mcts_iterations, 1.42)
            elseif search_alg_name == "astar"
                best_program, best_program_cost = a_star(grammar, data, enumeration_depth, dataset_id, max_pipelines, i)
            elseif search_alg_name == "ga"
                best_program, best_program_cost = genetic_algorithm(grammar, data, enumeration_depth, max_pipeline_depth, 0.1, 0.1)
            end
            end_time = now()

            pipeline = eval(Meta.parse(insert_name_indexes(string(Herb.HerbSearch.rulenode2expr(best_program, grammar)))))
            global pipelines_evaluated = 0
            accuracy = evaluate_pipeline(pipeline, train_X, train_Y, test_X, test_Y)
            # add to result string
            result_string *= run_info_string(dataset_id, grammar, search_alg_name, start_time, end_time, best_program, best_program_cost, accuracy)

            # add to result dictionary
            push!(results[dataset_id]["accuracy"], accuracy)
        end

        
        test_accuracies = results[dataset_id]["accuracy"]
        avg_accuracy = sum(test_accuracies)/n_runs
        results[dataset_id]["avg_accuracy"] = avg_accuracy
        results[dataset_id]["sample_variance_accuracy"] = sum((test_accuracies.-avg_accuracy).^2)/(n_runs-1)
    end

    result_string = pretty_print_dict(results) * "\n\n\n" * result_string
    return result_string, results
end

"""runs the search algorithm and saves the results to a file"""
function run_and_save(filename)
    #run algorithm - don't touch this!! (change at the top instead)
    result_string, results = run_search(search_alg_name, dataset_ids, n_runs, grammar, enumeration_depth, max_pipeline_depth, neighbours_per_iteration, train_on_n_samples, mcts_iterations)
    println(result_string)
    
    #write result to file
    open("db_output/"*string(filename)*".txt", "w") do file
        write(file, result_string)
    end

    return results
end

# clear output directory
foreach(rm, readdir("db_output",join=true))

### set the right parameters here

search_alg_name = "astar"             # options: bfs, vlns, mh

# dataset_ids = [61]
# dataset_ids = [37, 44]                          # parameter selection: [diabetes:37, spambase:44]
dataset_ids = [1499, 1510, 1504, 1478]          # evaluation: [seeds:1499, wdbc:1510, steel-plates-fault:1504, har:1478]

n_runs = 10
max_pipelines = 100

train_on_n_samples = 300    # to speed up evaluation, train only on n samples. To train on full dataset, set to 10000000

mcts_iterations = 600

# parameters to be optimized:
enumeration_depth = 3
max_pipeline_depth = 5
neighbours_per_iteration = 15



# create dict for saving results
final_results = Dict()
for id in dataset_ids
    final_results[id] = Dict("avg_accuracy" => [], "avg_sample_variance_accuracy" => [])
end



values = [3]  # set the values of the parameter you want to try out

# run the seach algorithms with the different values of the parameter
for value in values
    global enumeration_depth = value    # change the parameter name here
    res = run_and_save("enumeration_depth=" * string(value))

    # calculate the avg costs for each value
    for (id, val) in res
            push!(final_results[id]["avg_accuracy"], val["avg_accuracy"])
            push!(final_results[id]["avg_sample_variance_accuracy"], val["sample_variance_accuracy"])
    end
end

# write avg costs to file 
open("db_output/avg_accuracies.txt", "w") do file
    write(file, pretty_print_dict(final_results))
end