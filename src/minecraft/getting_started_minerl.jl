include("minerl.jl")
include("logo_print.jl")
include("minecraft_grammar_definition.jl")
include("experiment_helpers.jl")

using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using Logging
using JSON

# Set up FrAngel to use the test_tuple function for output equality
HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_reward_output_tuple(exec_output, out)

# Set up the Minecraft environment
SEED = 958129
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=SEED, inf_health=true, inf_food=true, disable_mobs=true)
    @debug("Environment initialized")
end

RENDER = true

function create_spec(max_reward::Float64, percentages::Vector{Float64}, require_done::Bool, starting_position::Tuple{Float64, Float64, Float64})::Vector{IOExample}
    spec = Vector{IOExample}()
    for perc in percentages
        spec = push!(spec, IOExample(Dict{Symbol, Any}(:start_pos => starting_position), (perc * max_reward, false)))
    end

    if require_done
        spec = push!(spec, IOExample(Dict{Symbol, Any}(), (max_reward, true)))
    end

    spec
end

RANDOM_SEED = 1235

using Random

@kwdef struct SpecificationConfiguration
    max_reward::Float64 = 74.0
    reward_percentages::Vector{Float64} = [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
    require_done::Bool = false
end

Base.@kwdef struct ExperimentConfiguration
    directory_path::String           # path to the folder where the experiment will be stored 
    experiment_description::String   # name of the experiment
    number_of_runs::Int              # number of runs to run the experiment
    max_run_time::Int                # maximum runtime of one run of an experiment
    render_moves::Bool               #  boolean to render the moves while running
end


""" 
    runfrangel_experiment(grammar_config::MinecraftGrammarConfiguration, frangel_config::FrAngelConfig, specification_config::SpecificationConfiguration, max_synthesis_runtime::Int)

Runs frangel on minerl with the given configurations and returns the runtime, reward over time and if the task was solved
"""
function runfrangel(;
    grammar_config::MinecraftGrammarConfiguration,
    frangel_config::FrAngelConfig,
    specification_config::SpecificationConfiguration,
    max_synthesis_runtime::Int,
)

    grammar, angelic_conditions = grammar_config.minecraft_grammar, grammar_config.angelic_conditions
    current_max_possible_reward = specification_config.max_reward


    start_time = time()
    has_solved_task = false
    reward_over_time = Vector{Tuple{Float64,Float64}}()
    starting_position = environment.start_pos
    start_reward = 0.0

    if environment.env.done
        reset_env(environment)
    else 
        soft_reset_env(environment, environment.start_pos)
    end

    while time() - start_time < max_synthesis_runtime

        rules_min = rules_minsize(grammar)
        symbol_min = symbols_minsize(grammar, rules_min)
        
        problem_specification = create_spec(current_max_possible_reward, specification_config.reward_percentages, specification_config.require_done, starting_position)
        iterator = FrAngelRandomIterator(deepcopy(grammar), :Program, rules_min, symbol_min, max_depth=frangel_config.generation.max_size)
        try
            solution = frangel(problem_specification, frangel_config, angelic_conditions, iterator, rules_min, symbol_min, reward_over_time, start_time, start_reward)    
            if !isnothing(solution)
                state = execute_on_input(grammar, solution, Dict{Symbol, Any}(:start_pos => starting_position)) 
                starting_position = state.current_position
    
                current_max_possible_reward -= state.total_reward # update the reward left
                start_reward += state.total_reward
            end
        catch e
            if isa(e, PyCall.PyError) && environment.env.done
                has_solved_task = true
                break
            else
                rethrow() # TODO: maybe here just print the error such that the experiment can continue
            end
        end       
    end

    # experiment is done, gather data 
    try_data = Dict(
        "runtime" => time() - start_time,
        "reward_over_time" => reward_over_time,
        "solved" => has_solved_task,
        "frangel_config" => frangel_config,
        "specification_config" => specification_config,
    )
    return try_data
end

function runfrangel_experiment(; 
    grammar_config::MinecraftGrammarConfiguration,
    experiment_configuration::ExperimentConfiguration,
    seeds::Vector{Int},
    frangel_config::FrAngelConfig = FrAngelConfig(max_time=20, generation=FrAngelConfigGeneration(use_fragments_chance=0.8, use_angelic_conditions_chance=0, max_size=40)),
    specification_config::SpecificationConfiguration,
)
    # for each world seed run the experiment
    for world_seed in seeds
        experiment_output_path = create_experiment_file(directory_path = experiment_configuration.directory_path, experiment_name = "Seed_$world_seed")
        
        # reset environment to the new seed
        environment.settings[:seed] = world_seed
        reset_env(environment)

        Random.seed!(RANDOM_SEED) # seed the random seed the same for each world 
        
        # for each experiment try run the experiment
        tries_data = []
        for experiment_try_index in 1:experiment_configuration.number_of_runs
            # TODO: here change frangel configuration for each world
            try 
                try_output = runfrangel(
                    grammar_config = grammar_config,
                    frangel_config = frangel_config,
                    specification_config = specification_config,
                    max_synthesis_runtime = experiment_configuration.max_run_time,
                )
                if try_output["solved"]
                    printstyled("[Seed]: $world_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:green)
                else
                    printstyled("[Seed]: $world_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:black)
                end
                try_output["try_index"] = experiment_try_index
                push!(tries_data, try_output)
            catch e
                @error e
                println("Error in running the experiment with world_seed=$world_seed try_index=$try_index but we continue")
            end
        end
        experiment_data = Dict(
            "world_seed" => world_seed,
            "experiment_description" => experiment_configuration.experiment_description,
            "grammar" => repr(grammar_config.minecraft_grammar),
            "tries_data" => tries_data
        )
        # write json to the experiment path
        open(experiment_output_path, "w") do f
            write(f, json(experiment_data, 4))
        end
    end
end
minerl_grammar_config::MinecraftGrammarConfiguration = get_minecraft_grammar()
@time runfrangel_experiment(
    grammar_config = minerl_grammar_config, 
    experiment_configuration=ExperimentConfiguration(
        directory_path="src/minecraft/experiments/experiment_frangel/",
        experiment_description="Dummy experiment",
        number_of_runs=2,
        max_run_time=3,
        render_moves=RENDER
    ),
    seeds = [958129, 1234, 4123, 4231, 9999],
    specification_config=SpecificationConfiguration(),
    frangel_config = FrAngelConfig(max_time=20,verbose_level=-1, generation=FrAngelConfigGeneration(use_fragments_chance=0.8, use_angelic_conditions_chance=0, max_size=40)),
)




