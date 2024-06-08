include("minerl.jl")
include("minecraft_grammar_definition.jl")
include("experiment_helpers.jl")
include("utils.jl")

using HerbSearch
using Logging
disable_logging(LogLevel(1))

# Set up FrAngel to use the test_tuple function for output equality
HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_reward_output_tuple(exec_output, out)

# Set here to work as a global variable - used in other files
RENDER = true 

# Set up the Minecraft environment
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=958129, inf_health=true, inf_food=true, disable_mobs=true)
    @debug("Environment initialized")
end

# Main body -> run frangel experiments
minerl_grammar_config::MinecraftGrammarConfiguration = get_minecraft_grammar()
@time run_frangel_experiments(
    grammar_config=minerl_grammar_config,
    experiment_configuration=ExperimentConfiguration(
        directory_path="src/minecraft/frangel/",
        experiment_description="Dummy experiment",
        number_of_runs=3,
        max_run_time=300,
        render_moves=RENDER # Toggle if Minecraft should be rendered
    ),
    world_seeds=[958129], # [958129, 1234, 4123, 4231, 9999] Seed for MineRL world environment
    frangel_seeds=[1235], # Seed for FrAngel
    specification_config=SpecificationConfiguration(),
    frangel_config=FrAngelConfig(max_time=30, verbose_level=0, generation=FrAngelConfigGeneration(use_fragments_chance=0.8, use_angelic_conditions_chance=0, max_size=40)),
)