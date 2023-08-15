module MOACOTOP
    using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, StatsBase
    import AlgebraOfGraphics: set_aog_theme!, firasans


    the_resolution = (500, 380)

    include("top.jl")
    include("top_probs.jl")
    include("mo_utils.jl")
    include("heuristics.jl")
    include("ants.jl")
    include("viz.jl")
    export TOP, Robot, verify, hop_to!, get_ω, get_r, # top.jl
           π_robot_survives, 𝔼_nb_robots_survive, π_robot_visits_node_j, 𝔼_reward, # top_probs.jl
           Objs, Soln, same_trail_set, unique_solns, get_pareto_solns, nondominated, area_indicator, # mo_utils.jl
           η_s, η_r, # heuristics.jl
           Ant, Ants, Pheremone, lay!, evaporate!, # ants.jl
           viz_setup, viz_Pareto_front, viz_soln, viz_pheremone
end
