"""
return the probability that a robot survives its trail.
"""
function π_robot_survives(trail::Vector{Int}, top::TOP)
    # if robot stays at base, certainly survives.
	if trail == [1, 1]
		return 1.0
	end
	# trail length, in terms of # edges
	ℓ = length(trail) - 1
	# product of survival probabilities along the trail (gotta survive all)
	return prod(
		get_prop(top.g, trail[n], trail[n+1], :ω)
			for n = 1:ℓ # n := edge along the trail.
	)
end

"""
return the expected number of robots that survive the TOP
"""
function 𝔼_nb_robots_survive(robots::Vector{Robot}, top::TOP)
	return sum(π_robot_survives(robot.trail, top) for robot in robots)
end

"""
return the probability that a given robot visits node j
(it must survive its journey to visit it)
"""
function π_robot_visits_node_j(robot::Robot, j::Int, top::TOP)
	# if the first node in the trail is j, survival probability is one.
	#  b/c survives at the base for sure.
	if robot.trail[1] == j
		return 1.0
	end
	# which node in the trail is node j? (possibly not there)
	id_trail_giving_node_j = findfirst(robot.trail .== j)
	if isnothing(id_trail_giving_node_j)
		# case: node j not in trail
		return 0.0
	else
		# case: node j in trail
		#    then we gotta survive the trail up till and including node j.
		# @assert trail[id_trail_giving_node_j] == j
		return π_robot_survives(robot.trail[1:id_trail_giving_node_j], top)
	end
end

"""
return the expected reward from node j, given robot trails.

or the expected reward from the whole graph.
"""
function 𝔼_reward(robots::Vector{Robot}, j::Int, top::TOP)
	# how many robots are traveling?
	nb_robots = length(robots)
	
	# wut reward does this node offer?
	r = get_prop(top.g, j, :r)

	# get probability that each robot visits this node
	π_visits = [π_robot_visits_node_j(robot, j, top) for robot in robots]
	
	# construct Poisson binomial distribution
	#   success prob's given in π_visits. 
	pb = PoissonBinomial(π_visits)
	
	# return expected reward
	#   = prob. node j visisted once or more * r
	#  note: either (i) 0 robots visit or (i) one or more robots visit.
	#   = (1 - prob(0 robots visit the node)) * r
	return (1 - pdf(pb, 0)) * r
end

function 𝔼_reward(robots::Vector{Robot}, top::TOP)
	return sum(
		𝔼_reward(robots, v, top) for v in vertices(top.g)
	)
end
