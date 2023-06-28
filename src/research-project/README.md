# research_project
https://projectforum.tudelft.nl/course_editions/60/generic_projects/2545


## define the experiments
define the following main parameters in experiment_step.jl

- search_alg_name = "astar"
    - options: bfs, vlns, mh
- dataset_ids = [1499, 1510, 1504, 1478]
    - ids of the dataset you want to evaluate
- n_runs = 10
    - the number of times the experiment should run
- max_pipelines = 100
    - the max number of pipelines that should be evaluated
- train_on_n_samples = 300   
    - the number of samples the pipelines should be trained on
- values = [3]
    - the maximum depth of pipelines that should be evaluated
    - You can try multiple depths and it will run the experiment for each different depth

## run the experiment
run experiment_step.jl, results will be in the db_output folder