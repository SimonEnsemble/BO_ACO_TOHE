module MOACOTOP
    using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, StatsBase

    include("top.jl")
    include("top_probs.jl")
    export TOP, Robot, verify, # top.jl
           π_robot_survives, 𝔼_nb_robots_survive, π_robot_visits_node_j, 𝔼_reward # top_probs.jl
end
