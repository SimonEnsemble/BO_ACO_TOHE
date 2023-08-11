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
	g::MetaGraph
    # number of robots comprising the team
	nb_robots::Int
end

"""
    get_ω(top, i, j)

compute survival probability of traveling node i -> j.
"""
get_ω(top::TOP, i::Int, j::Int) = get_prop(top.g, i, j, :ω)

"""
    get_r(top, v)

get reward from visting node v.
"""
get_r(top::TOP, v::Int) = get_prop(top.g, v, :r)

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
    @assert ! robot.edge_visit[u, v]
    @assert has_edge(top.g, u, v)
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
        @assert robot.trail[end] == 1
    end
end

"""
viz setup of the TOP.
"""
function viz_setup(
	top::TOP;
	nlabels::Bool=true,
	robots::Union{Nothing, Vector{Robot}}=nothing,
	show_robots::Bool=true
)
	g = top.g
	robot_colors = ColorSchemes.Accent_4

	# assign node color based on rewards
	reward_color_scheme = ColorSchemes.acton
    rewards = [get_r(top, v) for v in vertices(g)]
	crangescale = (0.0, round(maximum(rewards), digits=1))
	node_color = [get(reward_color_scheme, r, crangescale) for r in rewards]

	# assign edge color based on probability of survival
	survival_color_scheme = reverse(ColorSchemes.solar)
	edge_surivival_probs = [get_ω(top, ed.src, ed.dst) for ed in edges(g)]
	edge_color = [get(survival_color_scheme, p) for p in edge_surivival_probs]

	# layout
	_layout = Spring(
        iterations=150,
        pin=haskey(props(top.g), :pin) ? get_prop(top.g, :pin) : []
    )
	layout = _layout(g)

	fig = Figure()
	ax = Axis(fig[1, 1], aspect=DataAspect())
	hidespines!(ax)
	hidedecorations!(ax)
	# plot trails as highlighted edges
	if ! isnothing(robots)
		for (r, robot) in enumerate(robots)
			# represent trail as a graph
			g_trail = SimpleGraph(nv(g))
			for n = 1:length(robot.trail) - 1
				add_edge!(g_trail, robot.trail[n], robot.trail[n+1])
			end
			graphplot!(
				g_trail,
				layout=layout,
				node_size=0,
				edge_color=(robot_colors[r], 0.5),
				edge_width=10
			)
		end
	end
	# plot graph with nodes and edges colored
	graphplot!(
		g,
		layout=layout,
		node_size=35,
		node_color=node_color,
		edge_color=edge_color,
		nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
		nlabels_align=(:center, :center)
	)
	if show_robots
		# start node = 1
		x = layout[1][1]
		y = layout[1][2]
		r = 0.15
		for i = 1:top.nb_robots
			θ = π/2 * (i - 1)
			scatter!([x + r*cos(θ)], [y + r*sin(θ)],
				marker='✈',markersize=20, color=robot_colors[i])
		end
	end
	Colorbar(
		fig[0, 1],
		colormap=reward_color_scheme,
		vertical=false,
		label="reward",
		limits=crangescale,
		ticks=[0.0, crangescale[2]]
	)
	Colorbar(
		fig[-1, 1],
		colormap=survival_color_scheme,
		vertical=false,
		label="survival probability",
		ticks=[0.0, 1.0]
	)

	fig
end
