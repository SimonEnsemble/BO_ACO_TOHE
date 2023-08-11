"""
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
	g::MetaGraph
    # number of robots comprising the team
	nb_robots::Int
end

"""
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
    @assert robot.trail[end] == 1
end
