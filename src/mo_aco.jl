struct MO_ACO_run
	global_pareto_solns::Vector{Soln}
	areas::Vector{Float64}
	pheremone::Pheremone
	nb_iters::Int
end

function mo_aco(
	top::TOP; 
	nb_ants::Int=100, 
	nb_iters::Int=100, 
	verbose::Bool=false,
	run_checks::Bool=true,
	ρ::Float64=0.98, # trail persistence rate = 1 - evaporation rate
	min_max::Bool=true,
	my_seed::Int=1337
)
	Random.seed!(my_seed)

	# initialize ants and pheremone
	ants = Ants(nb_ants)
	pheremone = Pheremone(top)

	# for computing τ_min, τ_max
	avg_nb_choices_soln_components = mean(degree(top.g)) / 2

	# shared pool of non-dominated solutions
	global_pareto_solns = Soln[]

	# track growth of area indicator
	areas = zeros(nb_iters)
	for i = 1:nb_iters # iterations
		#=
		🐜s construct solutions
		=#
        solns = [construct_soln(ant, pheremone, top) for ant in ants]

		if run_checks
			for soln in solns
				for robot in soln.robots
					verify(robot, top)
				end
			end
		end

		#=
		compute non-dominated solutions.
        keep redundant solutions b/c these trails still deserve pheremone.
		=#
		iter_pareto_solns = get_pareto_solns(solns, true) # keep redundant ones

		#=
		update global pool of non-dominated solutions
        based on those found this iteration...
        remove those with redundant trail-sets.
		=#
		global_pareto_solns = get_pareto_solns(
			vcat(global_pareto_solns, iter_pareto_solns), true
		)
        if verbose
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
		evaporate!(pheremone, ρ)
		if rand() < 0.2
			lay!(pheremone, global_pareto_solns)
		else
			lay!(pheremone, iter_pareto_solns)
		end
		if min_max
			min_max!(pheremone, global_pareto_solns, ρ, avg_nb_choices_soln_components)
		end

		if verbose
			println("iter $i:")
			println("\t$(length(iter_pareto_solns)) nd-solns")
			println("\tglobally $(length(global_pareto_solns)) nd-solns")
			println("max τs = ", maximum(pheremone.τ_s))
			println("min τs = ", minimum(pheremone.τ_s))
			println("max τr = ", maximum(pheremone.τ_r))
			println("min τr = ", minimum(pheremone.τ_r))
		end

		#=
		track quality of Pareto set
		=#
		areas[i] = area_indicator(global_pareto_solns)
	end
	@info "found $(length(global_pareto_solns)) Pareto-optimal solns"
	# sort by obj
	sort!(global_pareto_solns, by=s -> s.objs.r)
	return MO_ACO_run(global_pareto_solns, areas, pheremone, nb_iters)
end
