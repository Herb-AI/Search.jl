include("minerl.jl")
include("logo_print.jl")
include("spec_utils.jl")

using Base.Filesystem
using HerbGrammar, HerbSpecification, HerbInterpret, HerbSearch
using Logging
using Random
using JSON

"""
    create_experiment_file(directory_path::String, experiment_name::String)

Creates a new experiment file in the given directory with the given name. If a file with the same name already exists, it will create a new file with an incremented index.
The experiment name should not contain the ".json" extension.
"""
function create_experiment_file(; directory_path::String, experiment_name::String)
    mkpath(directory_path)
    experiment_name = replace(experiment_name, ".json" => "")
    file_path = joinpath(directory_path, experiment_name * ".json")

    if isfile(file_path)
        printstyled("File $file_path already exists. Creating a new one with incremental index\n", color=:yellow)

        index = 1
        while isfile(file_path)
            index += 1
            file_name = "$experiment_name" * "_$index.json"
            file_path = joinpath(directory_path, file_name)
        end
        printstyled("Created experiment file at $file_path\n", color=:green)
    end
    open(file_path, "w") do f
        write(f, "")
    end
    return file_path
end


function append_to_json_file(filepath, new_data)
    open(filepath, "r") do file
        json_data = JSON.parse(read(file, String))
        json_data = [json_data; new_data]
        open(filepath, "w") do f
            write(f, json(json_data, 4))
        end
    end
end

Base.@kwdef struct ExperimentConfiguration
    directory_path::String           # path to the folder where the experiment will be stored 
    experiment_description::String   # name of the experiment
    number_of_runs::Int              # number of runs to run the experiment, for each world and FrAngel seed
    max_run_time::Int                # maximum runtime of one run of an experiment
    render_moves::Bool               #  boolean to render the moves while running
end

""" 
    run_frangel_once(grammar_config::MinecraftGrammarConfiguration, frangel_config::FrAngelConfig, specification_config::SpecificationConfiguration, max_synthesis_runtime::Int)

The function that performs a single experiment run. Runs FrAngel on MineRL with the given configurations and returns the runtime, reward over time and if the task was solved.
"""
function run_frangel_once(;
    grammar_config::MinecraftGrammarConfiguration,
    frangel_config::FrAngelConfig,
    specification_config::SpecificationConfiguration,
    max_synthesis_runtime::Int,
)
    # Init
    grammar, angelic_conditions = grammar_config.minecraft_grammar, grammar_config.angelic_conditions
    current_max_possible_reward = specification_config.max_reward

    start_time = time()
    has_solved_task = false
    reward_over_time = Vector{Tuple{Float64,Float64}}()
    starting_position = environment.start_pos
    start_reward = 0.0

    # Prepare environment for experiment
    if environment.env.done
        reset_env(environment)
    else
        soft_reset_env(environment, environment.start_pos)
    end

    # Main loop - run for as long as the experiment allows
    while time() - start_time < max_synthesis_runtime

        rules_min = rules_minsize(grammar)
        symbol_min = symbols_minsize(grammar, rules_min)
        # Create new test spec and iterator
        problem_specification = create_spec(current_max_possible_reward, specification_config.reward_percentages, specification_config.require_done, starting_position)
        iterator = FrAngelRandomIterator(deepcopy(grammar), :Program, rules_min, symbol_min, max_depth=frangel_config.generation.max_size)
        # Generate next FrAngel program, and update environment state
        try
            solution = frangel(problem_specification, frangel_config, angelic_conditions, iterator, rules_min, symbol_min, reward_over_time, start_time, start_reward)
            # If the solution passes at least one test
            if !isnothing(solution)
                state = execute_on_input(grammar, solution, Dict{Symbol,Any}(:start_pos => starting_position))
                starting_position = state.current_position
                # Update the reward left to reach goal
                current_max_possible_reward -= state.total_reward
                start_reward += state.total_reward
            end
        catch e
            # Task is solved
            if isa(e, PyCall.PyError) && environment.env.done
                has_solved_task = true
                break
            else
                rethrow() # TODO: maybe here just print the error such that the experiment can continue
            end
        end
    end
    # Experiment is done, gather data 
    try_data = Dict(
        "runtime" => time() - start_time,
        "reward_over_time" => reward_over_time,
        "solved" => has_solved_task,
        "frangel_config" => frangel_config,
        "specification_config" => specification_config,
    )
    return try_data
end

"""
    runfrangel_experiment(grammar_config::MinecraftGrammarConfiguration, experiment_configuration::ExperimentConfiguration, world_seeds::Vector{Int}, 
        frangel_config::FrAngelConfig, specification_config::SpecificationConfiguration)

Runs FrAngel for all provided `world_seeds` based on provided configurations. For each seed in the world_seeds vector, it runs the experiment `number_of_runs` times and saves the data in a JSON file.
"""
function run_frangel_experiments(;
    grammar_config::MinecraftGrammarConfiguration,
    experiment_configuration::ExperimentConfiguration,
    world_seeds::Vector{Int},
    frangel_seeds::Vector{Int},
    frangel_config::FrAngelConfig,
    specification_config::SpecificationConfiguration,
)
    # Have some joy in life :)
    # print_logo()

    # For each world seed run an experiment
    for world_seed in world_seeds
        experiment_output_path = create_experiment_file(directory_path=experiment_configuration.directory_path, experiment_name="Seed_$world_seed")

        # Reset environment to the new seed
        environment.settings[:seed] = world_seed
        reset_env(environment)

        tries_data = []
        for frangel_seed in frangel_seeds

            Random.seed!(frangel_seed)
            # Run the experiment `number_of_runs` times
            for experiment_try_index in 1:experiment_configuration.number_of_runs

                # Note: here change FrAngel configuration for each run

                try
                    # Run the experiment
                    try_output = run_frangel_once(
                        grammar_config=grammar_config,
                        frangel_config=frangel_config,
                        specification_config=specification_config,
                        max_synthesis_runtime=experiment_configuration.max_run_time,
                    )
                    if try_output["solved"]
                        printstyled("[Seed]: world=$world_seed frangel=$frangel_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:green)
                    else
                        printstyled("[Seed]: world=$world_seed frangel=$frangel_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:black)
                    end
                    try_output["try_index"] = experiment_try_index
                    try_output["frangel_seed"] = frangel_seed
                    push!(tries_data, try_output)
                catch e
                    @error e
                    println("Error in running the experiment with world_seed=$world_seed frangel_seed=$frangel_seed try_index=$experiment_try_index but we continue")
                end
            end
        end
        # Save the experiment data
        experiment_data = Dict(
            "world_seed" => world_seed,
            "experiment_description" => experiment_configuration.experiment_description,
            "grammar" => repr(grammar_config.minecraft_grammar),
            "tries_data" => tries_data
        )
        # Write the data into a JSON
        open(experiment_output_path, "w") do f
            write(f, json(experiment_data, 4))
        end
    end
end