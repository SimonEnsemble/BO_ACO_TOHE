"""
    next_node_candidates(robot, top)

build list of candiate nodes for the next hop, for a given robot, given its partial trail. finds all neighbors of current node (assumed to be last node in the current partial trail) that have not been traveled to _from this current node_ before. (ok for a robot to re-visit a node; may be necessary to get back...)

if at base, we have the option to never leave it => if at base, always = an option to stay. 

allows for overlap with other robots. in fact, does not even consider the trails of the other robots (possible improvement here?).
"""
function next_node_candidates(robot::Robot, top::TOP)
	# current vertex
	u = robot.trail[end]
	# return neighbors of u 
	#  exclude (directed) edges traversed already by THIS robot.
	#  (allows overlap with other robots)
	vs = [v for v in neighbors(top.g, u) if ! (robot.edge_visit[u, v])]
	# give option to never leave base
	if u == 1
		pushfirst!(vs, 1)
	end
	return vs
end

"""
    extend_trail!(robot, ant, pheremone, top)

given a robot with a partial trail and the pheremone, extend the trail of an ant.

uses multi-colony ant optimization rule.

returns node to visit next.
"""
function extend_trail!(
        robot::Robot, 
        ant::Ant, 
        pheremone::Pheremone, 
        previous_robots::Vector{Robot},
        top::TOP;
        use_heuristic::Bool=true,
        use_pheremone::Bool=true,
        consider_previous_robots::Bool=true
)
	@assert ! robot.done
	# current vertex
	u = robot.trail[end]

	# get list of next-node condidates
	vs = next_node_candidates(robot, top)

	# build probabilities by combining heuristic and pheremone.
	#   each ant weighs obj's differently.
    transition_probs = ones(length(vs))
    for (i, v) in enumerate(vs)
        if use_heuristic
            _η_r = consider_previous_robots ? η_r(u, v, top, previous_robots) : η_r(u, v, top)
            _η_s = η_s(u, v, top)

            transition_probs[i] *= _η_s ^ ant.λ * _η_r ^ (1 - ant.λ)
        end
        if use_pheremone
            transition_probs[i] *= pheremone.τ_s[u, v] ^ ant.λ * pheremone.τ_r[u, v] ^ (1 - ant.λ)
        end
    end
	# sample a new node
    v = sample(vs, ProbabilityWeights(transition_probs))

	# push to robot's trail and update edge visitation status
	hop_to!(robot, v, top)
	return v
end

"""
    construct_soln(ant, pheremone, top; use_heuristic=true, use_pheremone=true, consider_previous_robots=true)

based on current pheremone levels, use an ant to construct a solution to the TOP. compute the value of the objectives for this solution.

one robot at-a-time (they are independent anyway).
"""
function construct_soln(
        ant::Ant, 
        pheremone::Pheremone, 
        top::TOP;
        use_heuristic::Bool=true,
        use_pheremone::Bool=true,
        consider_previous_robots::Bool=true
)
	# initialize robots
	robots = [Robot(top) for k = 1:top.nb_robots]

	# ant builds a solution
    for (k, robot) in enumerate(robots)
		while ! robot.done
            extend_trail!(robot, ant, pheremone, robots[1:k], top, 
                          use_pheremone=use_pheremone, use_heuristic=use_heuristic, 
                          consider_previous_robots=consider_previous_robots)
		end
	end

	# compute objective values of solution
	objs = Objs(
		𝔼_reward(robots, top),
		𝔼_nb_robots_survive(robots, top)
	)

	return Soln(robots, objs)
end
