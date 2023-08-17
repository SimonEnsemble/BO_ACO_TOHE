# note: combined heuristic could be reward per survival probability?
ϵ = 0.05 # small number to add, to avoid it being zero...
"""
    η_r(u, v, top)
    η_r(u, v, top, previous_robots)

heuristic score for a hop u -> v, concerning objective 𝔼[reward].

## method 1: doesn't consider previous robots' paths
score = 𝔼[reward of node v] / (max reward among all nodes)
normalized so ∈ [0, 1], for comparison with η_s

## method 2: considers previous robots' paths.
a sequential perspective.
score = 𝔼[reward of node v | previous robots already deployed] / (max reward among all nodes)
this robot can only get the reward if none of the previous robots successfully visit this node.
"""
function η_r(u::Int, v::Int, top::TOP)
    return ϵ + get_ω(top, u, v) * get_r(top, v)
end

function η_r(u::Int, v::Int, top::TOP, previous_robots::Vector{Robot})
    # only get expected one-hop reward if none of the previous robots visisted.
    # special case if v = 1. then we don't use this rule, since it would never be selected.
    if v == 1
        return η_r(u, v, top)
    else
        return ϵ + η_r(u, v, top) * (1.0 - π_some_robot_visits_node_j(previous_robots, v, top))
    end
end

"""
    η_s(u, v, top)

heuristic score for a hop u -> v, concerning objective 𝔼[# robots survive].
score = prob. of surviving that edge.

note: if 1 -> 1 hop, survival prob is 1.0
"""
function η_s(u::Int, v::Int, top::TOP)
    ϵ = 0.01 # to avoid it being zero...
	if u == v == 1 # gonna survive fo sho if we stay at base
		return 1.0 + ϵ
	end
    return ϵ + get_ω(top, u, v)
end
