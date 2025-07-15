"""
    Objs(r, s)

store the two objectives: 𝔼(reward),  𝔼(# robots survive)
"""
struct Objs
	r::Float64 # 𝔼(reward)
	s::Float64 # 𝔼(# robots survive)
end

"""
    Soln(robots, objs)
    Soln(top) # initialize

store the solution to the TOP: the robots and the value of the two objectives.
"""
struct Soln
    robots::Vector{Robot}
    objs::Objs
end

# initialize
Soln(top::TOP) = Soln(
    [Robot(top) for k = 1:top.nb_robots], 
    Objs(NaN, NaN)
)

# compute objective associated with robot trail set
function Soln(robots::Vector{Robot}, top::TOP)
	objs = Objs(
		𝔼_reward(robots, top),
		𝔼_nb_robots_survive(robots, top)
	)

    return Soln(robots, objs)
end

"""
    same_trail_set(robots_i, robots_j)

do the robots have the same sets of trails? true or false.
this is a set comparison. comparing sets of trails.
used for making sure we keep track of only *unique* solutions.
"""
function same_trail_set(robotsᵢ::Vector{Robot}, robotsⱼ::Vector{Robot})
	trails_i = Set([robot.trail for robot in robotsᵢ])
	trails_j = Set([robot.trail for robot in robotsⱼ])
	return trails_i == trails_j
end

"""
    unique(solns, :objs)
    unique(solns, :robot_trails)

get unique list of solutions, in terms of (i) their objectives or (ii) the robot trail sets.
"""
function unique_solns(solns::Vector{Soln}, by::Symbol)
	@assert by in [:robot_trails, :objs]
	# start with assumption we gonna keep all of em
	ids_keep = [true for i = 1:length(solns)]
	for i = 1:length(solns)
		# throw out if there is one that is the same later.
		for j = i+1:length(solns)
			if by == :robot_trails
				if same_trail_set(solns[i].robots, solns[j].robots)
					ids_keep[i] = false
				end
			elseif by == :objs
				if solns[i].objs == solns[j].objs
					ids_keep[i] = false
				end
			end
		end
	end
	return solns[ids_keep]
end

"""
    get_pareto_solns(solns, keep_duplicates)

get the nondominated solutions from a list of solutions.
uses algo from here:
https://en.wikipedia.org/wiki/Maxima_of_a_point_set
"""
function get_pareto_solns(solns::Vector{Soln}, keep_duplicates::Bool)
    # sort by r, from hi to low.
    #  for ties in r, important to sort by s too, next.
    sorted_solns = sort(solns, by=s -> (s.objs.r, s.objs.s), rev=true)
	largest_s_seen = -Inf
	ids_pareto = Int[]
	for i = 1:length(sorted_solns)
        if keep_duplicates
            # is this a duplicate?
            if (i > 1) && (sorted_solns[i].objs == sorted_solns[ids_pareto[end]].objs)
                push!(ids_pareto, i)
                continue
            end
        end
		if sorted_solns[i].objs.s > largest_s_seen
			largest_s_seen = sorted_solns[i].objs.s
			push!(ids_pareto, i)
		end
	end
	return sorted_solns[ids_pareto]
end

"""
	nondominated(soln, solns) # true or false

a point p in a finite set of points S is said to be non-dominated if there is no other point q in S whose coordinates are all greater than or equal to the corresponding coordinates of p. 

BUT we modify so that we consider that solutions with equal objectives cannot dominate each other.
"""
function nondominated(soln::Soln, solns::Vector{Soln})
    for other_soln in solns
		# if they are the same, don't compare.
		if other_soln.objs == soln.objs
			continue
		end
        Δr = other_soln.objs.r - soln.objs.r
        Δs = other_soln.objs.s - soln.objs.s
        if (Δr ≥ 0.0) && (Δs ≥ 0.0)
            return false
        end
    end
    return true
end

"""
    area_indicator(pareto_solns, reward_sum, nb_robots)

compute area indicator, with reference point = the origin, characterizing the quality of a pareto set of solutions.
"""
function area_indicator(pareto_solns::Vector{Soln}, reward_sum::Float64, nb_robots::Int)
    @assert all([nondominated(p, pareto_solns) for p in pareto_solns])

	# important to only have the unique ones to avoid inflating the area.
    pareto_solns = unique_solns(pareto_solns, :objs)
	# sort by first objective, 𝔼[reward].
    sort!(pareto_solns, by=s -> s.objs.r)

	# imagine r on the x-axis and s on the y-axis.
    # initialize area as area of first box
    area = pareto_solns[1].objs.s * pareto_solns[1].objs.r / (reward_sum * nb_robots)
    # i = index of the box.
    for i = 2:length(pareto_solns) # i = the box
        Δr = (pareto_solns[i].objs.r - pareto_solns[i-1].objs.r) / reward_sum
        area += pareto_solns[i].objs.s * Δr / nb_robots
        @assert Δr > 0
        @assert pareto_solns[i].objs.s < pareto_solns[i-1].objs.s
    end
    return area
end
