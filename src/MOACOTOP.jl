module MOACOTOP
    using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, StatsBase, ProgressLogging
    import AlgebraOfGraphics: set_aog_theme!, firasans


    the_resolution = (500, 380)

    include("top.jl")
    include("top_probs.jl")
    include("mo_utils.jl")
    include("heuristics.jl")
    include("ants.jl")
    include("build_soln.jl")
    include("mo_aco.jl")
    include("simulated_annealing.jl")
    include("viz.jl")
    include("examples.jl")
    export TOP, Robot, verify, hop_to!, get_ω, get_r, proper_trail, # top.jl
           π_robot_survives, 𝔼_nb_robots_survive, π_robot_visits_node_j, 𝔼_reward, π_some_robot_visits_node_j, # top_probs.jl
           Objs, Soln, same_trail_set, unique_solns, get_pareto_solns, nondominated, area_indicator, # mo_utils.jl
           η_s, η_r, # heuristics.jl
           Ant, Ants, Pheremone, lay!, evaporate!, min_max!, # ants.jl
           next_node_candidates, extend_trail!, construct_soln, # build_soln.jl
           mo_aco, MO_ACO_run, # mo_aco.jl
           viz_setup, viz_Pareto_front, viz_soln, viz_pheremone, viz_progress, viz_robot_trail, viz_pheromone_correlation, # viz.jl
           darpa_urban_environment, art_museum, generate_random_top, generate_manual_top, toy_problem, 
           toy_starish_top, art_museum_layout, block_model, complete_graph_top, power_plant_layout, # examples.jl
           perturb_trail, so_simulated_annealing, mo_simulated_annealing, viz_agg_objectives, MO_SA_Run, CoolingSchedule # simulated_annealing.jl
end
