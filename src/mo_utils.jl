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
"""
function same_trail_set(robotsᵢ::Vector{Robot}, robotsⱼ::Vector{Robot})
	trails_i = Set([robot.trail for robot in robotsᵢ])
	trails_j = Set([robot.trail for robot in robotsⱼ])
	return trails_i == trails_j
end
