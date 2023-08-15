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
        100.0 * ones(nb_nodes, nb_nodes),
        100.0 * ones(nb_nodes, nb_nodes)
    )
end

"""
    evaporate!(pheremone, ρ)

evaporate the pheremone. 1-ρ is the evaporation rate.
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
