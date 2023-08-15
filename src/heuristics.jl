# note: combined heuristic could be reward per survival probability?

"""
    η_r(u, v, top)

heuristic score for a hop u -> v, concerning objective 𝔼[reward].
score = reward of node v / (max reward among all nodes)
normalized so ∈ [0, 1], for comparison with η_s
"""
function η_r(u::Int, v::Int, top::TOP)
    ϵ = 0.02 # to avoid it being zero...
    return ϵ + get_r(top, v) / top.max_reward_among_nodes
end

"""
    η_s(u, v, top)

heuristic score for a hop u -> v, concerning objective 𝔼[# robots survive].
score = prob. of surviving that edge.

note: if 1 -> 1 hop, survival prob is 1.0
"""
function η_s(u::Int, v::Int, top::TOP)
	if u == v == 1 # gonna survive fo sho if we stay at base
		return 1.0
	end
    ϵ = 0.02 # to avoid it being zero...
    return ϵ + get_ω(top, u, v)
end
