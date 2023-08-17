"""
    TOP(nb_nodes, g, nb_robots)

team-orienteering problem instance

simple, undirected graph `g`
  nodes = locations
  edges = path between two locations
    node label = :r, the reward for visiting that node.
    edge label = :ω, the survival probability of a robot
                      when traversing that edge.
  node 1 = base node.
"""
struct TOP
    # number of nodes in the graph
	nb_nodes::Int
    # the graph abstraction of the environment
	g::MetaDiGraph
    # number of robots comprising the team
	nb_robots::Int
end

"""
    get_ω(top, i, j)
    get_ω(g, i, j)

compute survival probability of traveling node i -> j.
"""
function get_ω(g::MetaDiGraph, i::Int, j::Int)
    if (i == 1) && (j == 1)
        return 1.0 # survives staying at base for sure
    else
        return get_prop(g, i, j, :ω)
    end
end
get_ω(top::TOP, i::Int, j::Int) = get_ω(top.g, i, j)

"""
    get_r(top, v)
    get_r(g, v)

get reward from visting node v.
"""
get_r(g::MetaDiGraph, v::Int) = get_prop(g, v, :r)
get_r(top::TOP, v::Int) = get_r(top.g, v)

"""
    Robot(trail, edge_visit, done)
    Robot(top)   # start at node 1, no steps
    Robot(trail, top) # give it a trail

a robot traversing the graph.
    we'll now treat the graph as directed, when it comes to the 
    trail the robot takes.
    robot starts/ends at base node 1.
"""
mutable struct Robot
    # list of vertices the robot takes
    trail::Vector{Int}       
    # keeps track of edge visitation status (directed)
    edge_visit::Matrix{Bool} 
    # finished with trail?
    done::Bool               
end

# initialize robot
Robot(top::TOP) = Robot(
        [1],    # starts at base
        [false for i = 1:top.nb_nodes, j = 1:top.nb_nodes], # no edges visited
        false  # trail not complete
)

"""
    hop_to!(robot, v)

have robot hop to node v next.
"""
function hop_to!(robot::Robot, v::Int, top::TOP)
    u = robot.trail[end]  # current node
    # if start, end at base node, we done!
    if ((u == 1) && (v == 1)) 
        robot.done = true
        # (no self-loops in graph so can't assert edge there.)
    else
        @assert has_edge(top.g, u, v)
    end
    @assert ! robot.edge_visit[u, v]
    push!(robot.trail, v) # extend trail
    robot.edge_visit[u, v] = true # update edge visitation status
    return nothing
end

function Robot(trail::Vector{Int}, top::TOP)
    robot = Robot(top)
    @assert trail[1] == 1
    for i = 2:length(trail)
        hop_to!(robot, trail[i], top)
    end
    robot.done = (trail[end] == 1) && length(trail) != 1
    return robot
end

"""
    verify(robot, top)

checks that robot path makes sense.
"""
function verify(robot::Robot, top::TOP)
    # how many edges are visited in the trail?
	nb_edges = length(robot.trail)-1

	# trail must follow edges that exist in the graph
	for n = 1:nb_edges # loop over edges u -> v
		u = robot.trail[n]
		v = robot.trail[n+1]
        # no self-loops in g but we allow 1->1 as special case
        #   "stay at base"
		if ! (u == v == 1) 
			@assert has_edge(top.g, u, v)
		end
		# edge visit status consistent with trail
		@assert robot.edge_visit[u, v]
	end
	# no other edges visisted that included in trail...
	@assert sum(robot.edge_visit) == nb_edges
    # starts at base node
    @assert robot.trail[1] == 1
    # ends at base node
    if robot.done
        @assert robot.trail[end-1:end] == [1, 1]
    end
    if robot.trail[end-1:end] == [1, 1]
        @assert robot.done
    end
end
