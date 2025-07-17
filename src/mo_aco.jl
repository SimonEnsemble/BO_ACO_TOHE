struct MO_ACO_run
    global_pareto_solns::Vector{Soln}
    areas::Vector{Float64}
    pheremone::Union{Pheremone, Vector{Pheremone}}
    nb_iters::Int
end

function mo_aco(
    top::TOP; 
    nb_ants::Int=100, 
    nb_iters::Int=100, 
    verbose::Bool=false,
    run_checks::Bool=true,
    ρ::Float64=0.96, # trail persistence rate = 1 - evaporation rate
    #min_max::Bool=true,
    use_heuristic::Bool=true,
    use_pheremone::Bool=true,
    my_seed::Int=1337,
    one_pheromone_trail_per_robot::Bool=false
)
    Random.seed!(my_seed)

    # initialize ants and pheremone
    ants = Ants(nb_ants)
    if one_pheromone_trail_per_robot
        pheremone = [Pheremone(top) for r = 1:top.nb_robots]
    else
        pheremone = Pheremone(top)
    end

    # for computing τ_min, τ_max
    avg_nb_choices_soln_components = mean(degree(top.g)) / 2

    # shared pool of non-dominated solutions
    global_pareto_solns = Soln[]

    # track growth of area indicator
    reward_sum = sum([get_r(top.g, v) for v = 1:nv(top.g)]) # for scaling
    areas = zeros(nb_iters)
    @progress for i = 1:nb_iters # iterations
        #=
        🐜s construct solutions
        =#
        solns = [construct_soln(ant, pheremone, top, 
                                use_heuristic=use_heuristic, use_pheremone=use_pheremone)
                 for ant in ants]

        if run_checks
            for soln in solns
                for robot in soln.robots
                    verify(robot, top)
                end
            end
        end

        #=
        compute non-dominated solutions.
        keep redundant solutions b/c these trails still deserve pheremone if unique trails
        =#
        iter_pareto_solns = get_pareto_solns(solns, true) # keep redundant ones
        iter_pareto_solns = unique_solns(iter_pareto_solns, :robot_trails)

        #=
        update global pool of non-dominated solutions
        based on those found this iteration...
        remove those with redundant trail-sets.
        =#
        global_pareto_solns = get_pareto_solns(
            vcat(global_pareto_solns, iter_pareto_solns), true
        )
        if verbose
            println("\t# iter-best solutions: ", length(iter_pareto_solns))
            println("\t# global sol'ns b4 unique!: ", length(global_pareto_solns))
        end
        global_pareto_solns = unique_solns(global_pareto_solns, :robot_trails)
        if verbose
            println("\t# global sol'ns after unique!: ", length(global_pareto_solns))
        end

        #=
        🐜 evaporate, lay, clip pheremone
        alt. between using global- and iteration-best Pareto set.
        =#
        if use_pheremone
            evaporate!(pheremone, ρ)
            lay!(pheremone, global_pareto_solns) # elite ant
            lay!(pheremone, iter_pareto_solns) 
         end
#        if min_max
#            min_max!(pheremone, global_pareto_solns, ρ, avg_nb_choices_soln_components)
#        end

        if verbose
            println("iter $i:")
            println("\t$(length(iter_pareto_solns)) nd-solns")
            println("\tglobally $(length(global_pareto_solns)) nd-solns")
            if ! one_pheromone_trail_per_robot
                println("max τs = ", maximum(pheremone.τ_s))
                println("min τs = ", minimum(pheremone.τ_s))
                println("max τr = ", maximum(pheremone.τ_r))
                println("min τr = ", minimum(pheremone.τ_r))
            end
        end

        #=
        track quality of Pareto set
        =#
        areas[i] = area_indicator(global_pareto_solns, reward_sum, top.nb_robots)
    end
    @info "found $(length(global_pareto_solns)) Pareto-optimal solns"
    # sort by obj
    sort!(global_pareto_solns, by=s -> s.objs.r)
    return MO_ACO_run(global_pareto_solns, areas, pheremone, nb_iters)
end
