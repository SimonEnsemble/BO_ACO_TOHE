"""
    Ant(λ)

the param λ ∈ [0, 1] dictates balance of this ant's prioritization of the objectives.
"""
struct Ant
	λ::Float64
end

"""
    Ants(nb_ants)

generate a heterogeneous colony of ants (equally spaced λ's).
"""
Ants(nb_ants::Int) = [Ant((k - 1) / (nb_ants - 1)) for k = 1:nb_ants]

"""
    Pheremone(τ_r, τ_s)
    Pheremone(top) # initialize to large value (100.0)

store the pheremone trails associated with the:
* 𝔼[reward] objective
* 𝔼[# robots survive] objective

each is an n×n matrix, with n = # nodes.
these matrices are not symmetric.
"""
struct Pheremone
    τ_r::Matrix{Float64} # reward obj
    τ_s::Matrix{Float64} # survival obj
end

# initialize
function Pheremone(top::TOP)
    nb_nodes = nv(top.g)
    return Pheremone(
        1.0 * ones(nb_nodes, nb_nodes),
        1.0 * ones(nb_nodes, nb_nodes)
    )
end

"""
    evaporate!(pheremone, ρ)

evaporate the pheremone. ρ is the trail persistence. 
1-ρ is the evaporation rate.
e.g. ρ=0.98 is a good value.
"""
function evaporate!(pheremone::Pheremone, ρ::Float64)
	pheremone.τ_s .*= ρ
	pheremone.τ_r .*= ρ
	return nothing
end

"""
    lay!(pheremone, pareto_solns)

lay pheremone on the trails associated with the Pareto solutions passed.

each Pareto soln lays pheremone on both trails.
the amount layed on trail i (pertaining to objective i) is equal to
the value of that objective for that solution divided by the number of solutions.
"""
function lay!(pheremone::Pheremone, pareto_solns::Vector{Soln})
    # number of Parto solns
	ℓ = length(pareto_solns)
	# each non-dominated solution contributes pheremone.
	for pareto_soln in pareto_solns
		# loop over robots
		for robot in pareto_soln.robots
			# loop over robot trail
			for i = 1:length(robot.trail)-1
				# step u -> v
				u = robot.trail[i]
				v = robot.trail[i+1]
				# lay it!
				# TODO: doesn't scaling here matter?
				pheremone.τ_r[u, v] += pareto_soln.objs.r / ℓ
				pheremone.τ_s[u, v] += pareto_soln.objs.s / ℓ
			end
		end
	end
	return nothing
end

#"""
#    min_max!(pheremone, global_pareto_solns, ρ)
#
#see Min/Max AS paper by Stutzle and Hoos.
#"""
#function min_max!(
#	pheremone::Pheremone,
#	global_pareto_solns::Vector{Soln},
#	ρ::Float64,
#    avg_nb_choices_soln_components::Float64;
#	p_best::Float64=0.05, # prob select best soln at convergence as defined
#    verbose::Bool=false
#)
#	# which solution gives the maximum of each objective?
#	id_r_max = argmax(soln.objs.r for soln in global_pareto_solns)
#	id_s_max = argmax(soln.objs.s for soln in global_pareto_solns)
#
#	# max objective values
#	r_max = global_pareto_solns[id_r_max].objs.r
#	s_max = global_pareto_solns[id_s_max].objs.s
#	
#    # estimate τ_max for each objective
#    τ_max_r = r_max / (1 - ρ) # eqn. 7 (we deposit r_max not 1 / r_max)
#    τ_max_s = s_max / (1 - ρ)
#    
#    #=
#    this leads to too-small ϕ's...
#	# number of solution components in opt trails for the two objs
#	n_r = sum(
#		[length(robot.trail) for robot in global_pareto_solns[id_r_max].robots]
#	)
#	n_s = sum(
#		[length(robot.trail) for robot in global_pareto_solns[id_s_max].robots]
#	)
#    
#    # formula for fraction of τ_max that should be τ_min.
#    ϕ_r = (1 - p_best ^ (1 / n_r)) / ((avg_nb_choices_soln_components - 1) * p_best ^ (1 / n_r))
#    ϕ_s = (1 - p_best ^ (1 / n_s)) / ((avg_nb_choices_soln_components - 1) * p_best ^ (1 / n_s))
#	
#    @assert ϕ_s < 0.2
#	@assert ϕ_r < 0.2
#    =#
#
#	# compute τ_min
#	#   warning: I manually set this because it is too large otherwise.
#	ϕ_r = 0.05 
#	ϕ_s = 0.05 
#	τ_min_r = τ_max_r * ϕ_r
#	τ_min_s = τ_max_s * ϕ_s
#    if verbose
#        @show τ_min_r, τ_max_r
#        @show τ_min_s, τ_max_s
#    end
#
#	# impose limits by clipping
#	nb_nodes = size(pheremone.τ_s)[1]
#	for i = 1:nb_nodes
#		for j = 1:nb_nodes
#			pheremone.τ_s[i, j] = clamp(pheremone.τ_s[i, j], τ_min_s, τ_max_s)
#			pheremone.τ_r[i, j] = clamp(pheremone.τ_r[i, j], τ_min_r, τ_max_r)
#		end
#	end
#	return nothing
#end
