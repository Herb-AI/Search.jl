module HerbSearch

using DataStructures

using HerbCore
using HerbGrammar
using HerbConstraints
using HerbInterpret
using HerbSpecification
using MLStyle

include("sampling_grammar.jl")

include("program_iterator.jl")
include("uniform_iterator.jl")

include("heuristics.jl")

include("fixed_shaped_iterator.jl")
include("top_down_iterator.jl")

include("evaluate.jl")

include("search_procedure.jl")

include("stochastic_iterator.jl")
include("stochastic_functions/cost_functions.jl")
include("stochastic_functions/neighbourhood.jl")
include("stochastic_functions/propose.jl")
include("stochastic_functions/accept.jl")
include("stochastic_functions/temperature.jl")

include("genetic_functions/fitness.jl")
include("genetic_functions/mutation.jl")
include("genetic_functions/crossover.jl")
include("genetic_functions/select_parents.jl")
include("genetic_search_iterator.jl")

include("random_iterator.jl")

include("frangel/frangel.jl")
include("frangel/frangel_utils.jl")
include("frangel/frangel_generation.jl")
include("frangel/frangel_random_iterator.jl")
include("frangel/long_hash_map.jl")

include("fragments/fragment_grammar_utils.jl")
include("fragments/mining_fragments.jl")

include("angelic_conditions/frangel_angelic_utils.jl")
include("angelic_conditions/bit_trie.jl")

export 
  ProgramIterator,
  @programiterator,
  
  ContextSensitivePriorityEnumerator,
  
  heuristic_leftmost,
  heuristic_rightmost,
  heuristic_random,
  heuristic_smallest_domain,

  derivation_heuristic,

  synth,
  SynthResult,
  optimal_program,
  suboptimal_program,

  FixedShapedIterator,
  UniformIterator,
  next_solution!,

  TopDownIterator,
  RandomIterator,
  BFSIterator,
  DFSIterator,
  MLFSIterator,

  MHSearchIterator,
  VLSNSearchIterator,
  SASearchIterator,
  
  mean_squared_error,
  misclassification,

  GeneticSearchIterator,
  misclassification,
  validate_iterator,
  sample,
  rand,

  frangel,
  FrAngelConfig,
  FrAngelConfigGeneration,
  FrAngelConfigAngelic,

  replace_first_angelic!,
  execute_angelic_on_input,
  get_code_paths!,

  mine_fragments,
  remember_programs!,
  
  generate_random_program,
  modify_and_replace_program_fragments!,
  add_angelic_conditions!,

  add_fragments_prob!,
  setup_grammar_with_fragments!,
  add_fragment_base_rules!,
  add_fragment_rules!,

  FrAngelRandomIterator,
  FrAngelRandomIteratorState,

  count_nodes,
  simplify_quick,
  _simplify_quick_once,
  symbols_minsize,
  rules_minsize,

  LongHashMap,
  init_long_hash_map,
  lhm_put!,
  lhm_contains,

  BitTrie,
  BitTrieNode,
  trie_add!,
  trie_contains
  
end # module HerbSearch
