module MOACOTOP
    using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, StatsBase

    include("top.jl")
    include("top_probs.jl")
    include("mo_utils.jl")
    export TOP, Robot, verify, viz_setup, hop_to!, get_ω, get_r, # top.jl
           π_robot_survives, 𝔼_nb_robots_survive, π_robot_visits_node_j, 𝔼_reward, # top_probs.jl
           Objs, Soln, same_trail_set, sort_by_r!, unique_solns # mo_utils.jl
end
