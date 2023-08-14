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
    sort_by_r!(solns)

sort list of solutions by the objective 𝔼[team reward].
needed to sort according to solutions on the Pareto front.
"""
function sort_by_r!(solns::Vector{Soln})
	# get list of first objective values
	rs = [soln.objs.r for soln in solns]
	# find out how to sort them
	ids = sortperm(rs)
	# do the sorting. the dot is important for modifying it !
	solns .= solns[ids]
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
