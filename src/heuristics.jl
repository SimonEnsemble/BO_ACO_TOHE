# note: combined heuristic could be reward per survival probability?
"""
    η_r(u, v, top)
    η_r(u, v, top, robots)

heuristic score for a hop u -> v, concerning objective 𝔼[reward].
score = 𝔼[reward of node v] / (max reward among all nodes)
normalized so ∈ [0, 1], for comparison with η_s
"""
function η_r(u::Int, v::Int, top::TOP)
    ϵ = 0.02 # to avoid it being zero...
    return ϵ + get_ω(top, u, v) * get_r(top, v) / top.max_one_hop_𝔼_reward
    #return ϵ + get_r(top, v) / top.max_one_hop_𝔼_reward
end

"""
    η_s(u, v, top)

heuristic score for a hop u -> v, concerning objective 𝔼[# robots survive].
score = prob. of surviving that edge.

note: if 1 -> 1 hop, survival prob is 1.0
"""
function η_s(u::Int, v::Int, top::TOP)
    ϵ = 0.02 # to avoid it being zero...
	if u == v == 1 # gonna survive fo sho if we stay at base
		return 1.0 + ϵ
	end
    return ϵ + get_ω(top, u, v)
end
