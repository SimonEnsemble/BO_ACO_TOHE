### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ d04e8854-3557-11ee-3f0a-2f68a1123873
begin
	import Pkg; Pkg.activate()
	using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, PlutoUI, StatsBase

	import AlgebraOfGraphics: set_aog_theme!, firasans
	set_aog_theme!(fonts=[firasans("Light"), firasans("Light")])
	the_resolution = (500, 380)
	update_theme!(
		fontsize=20, 
		linewidth=2,
		markersize=14,
		titlefont=firasans("Light"),
		# resolution=the_resolution
	)
end

# ╔═╡ e136cdee-f7c1-4add-9024-70351646bf24
TableOfContents()

# ╔═╡ 613ad2a0-abb7-47f5-b477-82351f54894a
md"# MO-ACO of TSOP

MO-ACO = multi-objective ant colony optimization

TSOP = team survival orienteering problem

## generate problem instance
"

# ╔═╡ 6e7ce7a6-5c56-48a0-acdd-36ecece95933
function generate_graph(nb_nodes::Int; survival_model=:random)
	@assert survival_model in [:random, :binary]
	
	# generate structure of the graph
	g = erdos_renyi(nb_nodes, 0.3, is_directed=false)
	g = MetaGraph(g)
	
	# assign survival probabilities
	if survival_model == :random
		for ed in edges(g)
			set_prop!(g, ed, :ω, rand())
		end
	else
		for ed in edges(g)
			set_prop!(g, ed, :ω, rand([0.2, 0.8]))
		end
	end

	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, 0.1 + rand()) # reward too small, heuristic won't take it there.
	end
	
	# for base node
	# set_prop!(g, 1, :r, 0.001)
	return g
end

# ╔═╡ 184af2a6-d5ca-4cbc-8a1a-a172eaae472f
struct TOP
	nb_nodes::Int
	g::MetaGraph
	nb_robots::Int
end

# ╔═╡ 8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
top = TOP(
	20,
	generate_graph(20, survival_model=:random),
	2,         # number of robots
)

# ╔═╡ 47eeb310-04aa-40a6-8459-e3178facc83e
md"toy TOP problems (deterministic, for testing)"

# ╔═╡ fcf3cd41-beaa-42d5-a0d4-b77ad4334dd8
function generate_toy_top()
	Random.seed!(1337)
	nb_nodes = 10
	g = MetaGraph(star_graph(nb_nodes))
	
	# assign survival probabilities
	for ed in edges(g)
		set_prop!(g, ed, :ω, rand())
	end

	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, 0.1 + rand())
	end
	
	return TOP(nb_nodes, g, 1)
end

# ╔═╡ f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
md"## viz setup"

# ╔═╡ d0fd5e8b-7b3f-45ec-a132-5b33f599f2c9
md"## robot
takes a directed trail (circuit).
"

# ╔═╡ ddfcf601-a6cf-4c52-820d-fcf71bbf3d72
begin
	mutable struct Robot
		trail::Vector{Int}       # list of vertices
		edge_visit::Matrix{Bool} # keeps track of edge visitation status (directed)
		done::Bool               # finished with trail?
	end

	# initialize robot
	function Robot(top::TOP)
		return Robot(
			[1],    # starts at base
			[false for i = 1:top.nb_nodes, j = 1:top.nb_nodes], # no edges visited
			false  # trail not complete
		)
	end
end

# ╔═╡ b7f68115-14ea-4cd4-9e96-0fa63a353fcf
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
	rewards = [get_prop(g, v, :r) for v in vertices(g)]
	crangescale = (0.0, maximum(rewards))
	node_color = [get(reward_color_scheme, r, crangescale) for r in rewards]

	# assign edge color based on probability of survival
	survival_color_scheme = reverse(ColorSchemes.solar)
	edge_surivival_probs = [get_prop(g, ed.src, ed.dst, :ω) for ed in edges(g)]
	edge_color = [get(survival_color_scheme, p) for p in edge_surivival_probs]

	# layout
	_layout = Spring(; iterations=20)
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
		ticks=[0.0, round(crangescale[2], digits=1)]
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

# ╔═╡ 74ce2e45-8c6c-40b8-8b09-80d97f58af2f
viz_setup(top)

# ╔═╡ 926977f1-a337-4825-bfe4-ccc1a2e4cc93
function verify_robot(robot::Robot, top::TOP)
	nb_edges = length(robot.trail)-1
	# trail follows edges that exist in the graph
	for n = 1:nb_edges # loop over edges u -> v
		u = robot.trail[n]
		v = robot.trail[n+1]
		if ! (u == v == 1)
			@assert has_edge(top.g, u, v)
		end
		# edge visit status consistent with trail
		@assert robot.edge_visit[u, v]
	end
	# edges visisted unique
	@assert sum(robot.edge_visit) == nb_edges
	# edge visit status consistent with trail
	# TODO uniqueness of nodes visisted (depends on base situation)
end

# ╔═╡ e501d59e-336e-456d-8abb-bc663bd4899e
md"## computing survival probabilities"

# ╔═╡ cdb0e3ec-426a-48f2-800f-f70cfc20492a
function π_robot_survives(trail::Vector{Int}, top::TOP)
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

# ╔═╡ 2f78b5b8-e996-4b65-b8cc-7b27e45242ec
function 𝔼_nb_robots_survive(robots::Vector{Robot}, top::TOP)
	return sum(π_robot_survives(robot.trail, top) for robot in robots)
end

# ╔═╡ 732e023a-048f-4cf4-beba-c14d10fe643f
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

# ╔═╡ e7c955d6-ba17-4066-a737-e040c3016280
function random_trail(n::Int, top::TOP)
	robot = Robot(top)
	for i = 1:n
		u = robot.trail[i] # current node
		next_candidates = [v for v in neighbors(top.g, u) 
			if ! (robot.edge_visit[u, v])]
		if length(next_candidates) == 0
			break
		end
		v = sample(next_candidates)
		push!(robot.trail, v)
		robot.edge_visit[u, v] = true
	end
	verify_robot(robot, top)
	return robot
end

# ╔═╡ ad1c64f5-94b6-4c51-b66d-7cbe77495b2b
md"## computing expected reward"

# ╔═╡ ec757c86-2072-4cc2-a399-e4ef347c3c80
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

# ╔═╡ a1572e77-2126-443a-8da1-adcf4af01e87
function 𝔼_reward(robots::Vector{Robot}, top::TOP)
	return sum(
		𝔼_reward(robots, v, top) for v in vertices(top.g)
	)
end

# ╔═╡ 20f4eb18-3d36-43e0-8e97-ed2bccc13f55
robots = [random_trail(3, top), random_trail(4, top), random_trail(2, top)]

# ╔═╡ 241eea88-7610-4a54-af23-316b3fdf9780
π_robot_survives(robots[1].trail, top)

# ╔═╡ 67706b5c-ef3f-48df-b2e2-ace159f814e1
π_robot_visits_node_j(robots[1], 15, top)

# ╔═╡ 12c1ebd2-6b18-4c69-ac04-35639737b5ab
viz_setup(top, robots=robots)

# ╔═╡ 9e6d222b-c585-40b2-82c9-5d7b9f5b4e77
𝔼_reward(robots, top)

# ╔═╡ 1b5cfbae-7010-4e37-b8a8-f91df6577eeb
𝔼_nb_robots_survive(robots, top)

# ╔═╡ 0c5d0bbd-d278-4caa-ab1c-a886c2f4aaaa
π_robot_survives(robots[3].trail, top)

# ╔═╡ 9d44f37d-8c05-450a-a448-7be50387499c
md"## MO-ACO
### heuristics

combined could be reward per survival.
"

# ╔═╡ 2ac621ac-1a44-401e-bdb2-97cbb29d3508
# heuristic for hop u -> v
# score = reward of node v
function η_r(u::Int, v::Int, top::TOP)
	return get_prop(top.g, v, :r)
end

# ╔═╡ 974a1e40-50e0-4dc1-9bc9-6ea5ea687ae8
# heuristic for hop u -> v
# score = survival probability of that edge.
function η_s(u::Int, v::Int, top::TOP)
	if u == v == 1 # gonna survive fo sho if we stay at base
		return 1.0
	end
	return get_prop(top.g, u, v, :ω)
end

# ╔═╡ 84b0295b-6869-4040-8440-41d6a47a7ba4
md"### storing solutions"

# ╔═╡ f1c49f3b-eaeb-4950-8e78-b00849682756
# objectives
struct Objs
	r::Float64 # 𝔼(reward)
	s::Float64 # 𝔼(# robots survive)
end

# ╔═╡ 6d1a6ce7-3944-4fbd-ac22-e678d31d9a9b
begin
	struct Soln
		robots::Vector{Robot}
		objs::Objs
	end
	
	Soln(top::TOP) = Soln(
		[Robot(top) for k = 1:top.nb_robots], 
		Objs(NaN, NaN)
	)
end

# ╔═╡ 62751e4b-a109-4304-9fb1-26f8858603e9
function same_trails(solnᵢ::Soln, solnⱼ::Soln)
	nb_robots = length(solnᵢ.robots)
	trails_i = Set([robot.trail for robot in solnᵢ.robots])
	trails_j = Set([robot.trail for robot in solnⱼ.robots])
	return trails_i == trails_j
end

# ╔═╡ 2ba6b5ce-0404-4b35-997e-56730203d861
# sort solutions by first objective
function sort_by_r!(solns::Vector{Soln})
	# get list of first objective values
	rs = [soln.objs.r for soln in solns]
	# find out how to sort them
	ids = sortperm(rs)
	# do the sorting. the dot is important for modifying it !
	solns .= solns[ids]
end

# ╔═╡ 0cdb4beb-ba8a-4049-b723-1546aa010a8e
# in terms 
function unique(solns::Vector{Soln})
	ids_keep = [true for i = 1:length(solns)]
	for i = 1:length(solns)
		# turn off if there is one that is the same later.
		for j = i+1:length(solns)
			if same_trails(solns[i], solns[j])
				ids_keep[i] = false
			end
		end
	end
	return solns[ids_keep]
end

# ╔═╡ d8591f8d-5ef2-4363-9e81-c084c94dfc4e
md"### Pareto set"

# ╔═╡ d44b2e46-6709-47c6-942a-d9c0e5a7a8bf
function sol_strictly_dominates_sol(soln₁::Soln, soln₂::Soln)
	Δ_r = soln₁.objs.r - soln₂.objs.r
	Δ_s = soln₁.objs.s - soln₂.objs.s
	# if they give the same objective values...
	if (Δ_r == 0.0) && (Δ_s == 0.0)
		return false
	end
	# better or equal in terms of both objectives.
	return (Δ_r >= 0.0) && (Δ_s >= 0.0)
end

# ╔═╡ aabcc1a3-082b-468c-ad1e-648329f7f0c9
function get_pareto_solns(solns::Vector{Soln})
	ids_pareto = [true for i = 1:length(solns)]
	# look at each solution.
	for i = 1:length(solns)
		# if this solution is dominated by some other solution, we don't include it.
		for j = 1:length(solns)
			if i == j
				continue
			end
			if sol_strictly_dominates_sol(solns[j], solns[i])
				ids_pareto[i] = false
				break
			end
		end
	end
	return solns[ids_pareto]
end

# ╔═╡ f97e50dc-ce9b-484b-b3cb-1f38e9100d6f
function _viz_objectives!(ax, solns::Vector{Soln})
	scatter!(ax,
		[soln.objs.r for soln in solns],
		[soln.objs.s for soln in solns]
	)
end

# ╔═╡ f2ff035f-1a19-47cd-a79e-f634b7cf8447
function _viz_area_indicator!(ax, pareto_solns::Vector{Soln})
	linecolor = "gray"
	shadecolor = ("yellow", 0.2)
	for i = 1:length(pareto_solns)-1
		# vertical line
		lines!(ax, 
			[pareto_solns[i].objs.r, pareto_solns[i].objs.r],
			[pareto_solns[i].objs.s, pareto_solns[i+1].objs.s],
			color=linecolor
		)
		# horizontal line
		lines!(ax, 
			[pareto_solns[i].objs.r, pareto_solns[i+1].objs.r],
			[pareto_solns[i+1].objs.s, pareto_solns[i+1].objs.s],
			color=linecolor
		)
		# shade
		fill_between!(ax, 
			[pareto_solns[i].objs.r, pareto_solns[i+1].objs.r],
			zeros(2),
			[pareto_solns[i+1].objs.s, pareto_solns[i+1].objs.s],
			color=shadecolor
		)
	end
	# first horizontal line
	lines!(ax, 
		[0, pareto_solns[1].objs.r],
		[pareto_solns[1].objs.s, pareto_solns[1].objs.s],
		color=linecolor
	)
	# first shade
	fill_between!(ax, 
		[0, pareto_solns[1].objs.r],
		zeros(2),
		[pareto_solns[1].objs.s, pareto_solns[1].objs.s],
		color=shadecolor
	)
	# last vertical line
	lines!(ax, 
		[pareto_solns[end].objs.r, pareto_solns[end].objs.r],
		[pareto_solns[end].objs.s, 0.0],
		color=linecolor
	)
end

# ╔═╡ 3526e2f9-1e07-43dc-9067-5656d7c864eb
function viz_Pareto_front(solns::Vector{Soln})
	local fig = Figure(resolution=the_resolution)
	local ax = Axis(
		fig[1, 1],
		xlabel="𝔼(rewards)", 
		ylabel="𝔼(# robots survive)"
	)
	xlims!(0, nothing)
	ylims!(0, nothing)
	_viz_objectives!(ax, solns)
	pareto_solns = get_pareto_solns(solns)
	sort_by_r!(pareto_solns)
	_viz_area_indicator!(ax, pareto_solns)
	_viz_objectives!(ax, pareto_solns)
	fig
end

# ╔═╡ 2e6d6c29-0cc9-4c6b-9a68-23b93caff78d
# reference pt = origin.
# imagine r on the x-axis and s on the y-axis.
function area_indicator(pareto_solns::Vector{Soln})
	# make sure these are indeed Pareto-optimal
	@assert length(get_pareto_solns(pareto_solns)) == length(pareto_solns)
	
	# sort by first objective, 𝔼[reward].
	sort_by_r!(pareto_solns)
	
	# initialize area as area of first box
	area = pareto_solns[1].objs.s * pareto_solns[1].objs.r
	for i = 2:length(pareto_solns)-1
		Δr = pareto_solns[i+1].objs.r - pareto_solns[i].objs.r
		@assert Δr > 0
		@assert pareto_solns[i+1].objs.s < pareto_solns[i].objs.s
		area += pareto_solns[i+1].objs.s * Δr
	end
	return area
end

# ╔═╡ 4c60da94-d66f-461b-9e48-2a3c5343b80e
md"### ants"

# ╔═╡ 4ea8f171-8834-41d2-ac0e-d3101e63cdc0
struct Ant
	λ::Float64
end

# ╔═╡ e289eb93-1446-4506-abb5-f8b3d58ecca6
Ants(nb_ants::Int) = [Ant((k - 1) / (nb_ants - 1)) for k = 1:nb_ants]

# ╔═╡ fd90796f-4aa4-476c-b2b2-9a327133d43a
toy_ants = Ants(100)

# ╔═╡ 40266eb7-f001-411f-9227-d165487c8158
md"### pheremone"

# ╔═╡ 762e252d-dcb9-48d9-b981-fa142e272ea0
begin
	struct Pheremone
		τ_r::Matrix{Float64} # reward obj
		τ_s::Matrix{Float64} # survival obj
	end
	
	# initialize
	function Pheremone(top::TOP)
		nb_nodes = nv(top.g)
		return Pheremone(
			ones(nb_nodes, nb_nodes),
			ones(nb_nodes, nb_nodes)
		)
	end
end

# ╔═╡ bfd0ec10-4b7e-4a54-b08a-8ecde1f3a97d
toy_pheremone = Pheremone(top)

# ╔═╡ 0ed6899e-3343-4973-8b9a-fe7547eca346
function evaporate!(pheremone::Pheremone, ρ::Float64=0.02)
	pheremone.τ_s .*= (1 - ρ)
	pheremone.τ_r .*= (1 - ρ)
	return nothing
end

# ╔═╡ a52784a1-cd98-45a7-8931-b8488d71ead9
function lay!(pheremone::Pheremone, nd_solns::Vector{Soln})
	ℓ = length(nd_solns)
	# each non-dominated solution contributes pheremone.
	for nd_soln in nd_solns
		# loop over robots
		for robot in nd_soln.robots
			# loop over robot trail
			for i = 1:length(robot.trail)-1
				# step u -> v
				u = robot.trail[i]
				v = robot.trail[i+1]
				# lay it!
				# TODO: doesn't scaling here matter?
				pheremone.τ_r[u, v] += nd_soln.objs.r / ℓ
				pheremone.τ_s[u, v] += nd_soln.objs.s / ℓ
			end
		end
	end
	return nothing
end

# ╔═╡ 244a70b2-25aa-486f-8c9b-2f761c5766d5
function covert_top_graph_to_digraph(top::TOP)
	g_d = SimpleDiGraph(top.nb_nodes)
	for ed in edges(top.g)
		add_edge!(g_d, ed.src, ed.dst)
		add_edge!(g_d, ed.dst, ed.src)
	end
	return g_d
end

# ╔═╡ 96f20fc5-cc82-481f-8cb5-5b538190096e
ColorSchemes.Greens

# ╔═╡ 058baefa-23c4-4a10-831c-a045db7ea382
function viz(pheremone::Pheremone, top::TOP)
	g_d = covert_top_graph_to_digraph(top)

	# layout
	_layout = Spring(; iterations=20)
	layout = _layout(top.g)
	
	edge_color = [
		[get(
			ColorSchemes.Greens, 
			pheremone.τ_r[ed.src, ed.dst], 
			(minimum(pheremone.τ_r), maximum(pheremone.τ_r))
		)
			for ed in edges(g_d)],
		[get(
			ColorSchemes.Reds, 
			pheremone.τ_s[ed.src, ed.dst], 
			(minimum(pheremone.τ_s), maximum(pheremone.τ_s))
		)
			for ed in edges(g_d)],
	]
	
	fig = Figure()
	axs = [Axis(fig[1, i], aspect=DataAspect()) for i = 1:2]
	axs[1].title = "τᵣ"
	axs[2].title = "τₛ"
	

	for i = 1:2
		graphplot!(axs[i],
			g_d, 
			layout=layout,
			# node_size=35, 
			node_color="gray",
			edge_color=edge_color[i]
			# nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
			# nlabels_align=(:center, :center)
		)
	end
		
	hidespines!.(axs)
	hidedecorations!.(axs)
	
	return fig
end

# ╔═╡ 9b5a36a0-17a4-403a-9587-9fba3fa1c456
md"### building partial solution"

# ╔═╡ fb1a2c2f-2651-46b3-9f79-2e983a7baca6
# TODO should this depend on other robots?
function next_node_candidates(robot::Robot, top::TOP)
	# current vertex
	u = robot.trail[end]
	# return neighbors of u 
	#  exclude (directed) edges traversed already by THIS robot.
	#  (allows overlap with other robots)
	vs = [v for v in neighbors(top.g, u) if ! (robot.edge_visit[u, v])]
	# give option to never leave base
	if u == 1
		push!(vs, 1)
	end
	return vs
end

# ╔═╡ c34fac32-76b4-4051-ba76-9b5a758954f3
function extend_trail!(robot::Robot, ant::Ant, pheremone::Pheremone, top::TOP)
	# current vertex
	u = robot.trail[end]
	
	# get list of next-node condidates
	vs = next_node_candidates(robot, top)
	
	# build probabilities by combining heuristic and pheremone.
	#   each ant weighs obj's differently.
	transition_probs = [
		(pheremone.τ_s[u, v] * η_s(u, v, top)) ^ ant.λ * 
		(pheremone.τ_r[u, v] * η_r(u, v, top)  ) ^ (1 - ant.λ)
		for v in vs]
	
	# sample a new node
	v = sample(vs,
		ProbabilityWeights(
			transition_probs
		)
	)

	# if base node, robot is done
	if v == 1
		robot.done = true
	end
	
	# push to robot's trail and update edge visitation status
	push!(robot.trail, v)
	robot.edge_visit[u, v] = true
	return v
end

# ╔═╡ 92b98a6c-3535-4559-951c-210f0d8a8d63
function construct_soln(ant::Ant, pheremone::Pheremone, top::TOP)
	# initialize robots
	robots = [Robot(top) for k = 1:top.nb_robots]
	
	# ant builds a solution
	for robot in robots
		while ! robot.done
			extend_trail!(robot, ant, pheremone, top)
		end
	end
	
	# compute objective values of solution
	objs = Objs(
		𝔼_reward(robots, top),
		𝔼_nb_robots_survive(robots, top)
	)
	
	# voila, we hv solution
	return Soln(robots, objs)
end

# ╔═╡ 553626cc-7b2b-440d-b4e2-66a3c2fccba4
toy_solns = [construct_soln(ant, toy_pheremone, top) for ant in toy_ants];

# ╔═╡ a53ce432-02d7-45db-ba26-7f182bc26524
viz_setup(top, robots=toy_solns[2].robots)

# ╔═╡ 33452066-8a35-4bb0-ae58-8bcfb22e2102
viz_Pareto_front(toy_solns)

# ╔═╡ 74459833-f3e5-4b13-b838-380c007c86ed
md"### 🐜"

# ╔═╡ 4f7363b5-2aba-4a95-89da-da8c7f1d5ccd
struct MO_ACO_run
	global_pareto_solns::Vector{Soln}
	areas::Vector{Float64}
	pheremone::Pheremone
	nb_iters::Int
end

# ╔═╡ 2c1eb95b-30dd-4185-8fc4-5c8b6cab507a
function mo_aco(
	top::TOP; 
	nb_ants::Int=100, 
	nb_iters::Int=10, 
	verbose::Bool=false,
	run_checks::Bool=true
)
	# initialize ants and pheremone
	ants = Ants(nb_ants)
	pheremone = Pheremone(top)
	# shared pool of non-dominated solutions
	global_pareto_solns = Soln[]
	# track growth of area indicator
	areas = zeros(nb_iters)
	for i = 1:nb_iters # iterations
		#=
		🐜s construct solutions
		=#
		solns = Soln[] # ants' solutions this iter
		for (a, ant) in enumerate(ants)
			# each ant constructs a solution
			soln = construct_soln(ant, pheremone, top)
			push!(solns, soln)
		end

		if run_checks
			for soln in solns
				for robot in soln.robots
					verify_robot(robot, top)
				end
			end
		end

		#=
		compute non-dominated solutions
		=#
		iter_pareto_solns = get_pareto_solns(solns)

		#=
		update global pool of non-dominated solutions
		=#
		old_global_pareto_solns = deepcopy(global_pareto_solns) # TODO remove after debug
		global_pareto_solns = get_pareto_solns(
			vcat(global_pareto_solns, iter_pareto_solns)
		)
		global_pareto_solns = unique(global_pareto_solns)

		if verbose
			println("iter $i:")
			println("\t$(length(iter_pareto_solns)) nd-solns")
			println("\tglobally $(length(global_pareto_solns)) nd-solns")
		end
		
		#=
		🐜 lay pheremone
		=#
		evaporate!(pheremone)
		if rand() < 0.2
			lay!(pheremone, global_pareto_solns)
		else
			lay!(pheremone, iter_pareto_solns)
		end

		#=
		track quality of Pareto set
		=#
		areas[i] = area_indicator(global_pareto_solns)
	end
	@info "found $(length(global_pareto_solns)) Pareto-optimal solns"
	# sort by obj
	sort_by_r!(global_pareto_solns)
	return MO_ACO_run(global_pareto_solns, areas, pheremone, nb_iters)
end

# ╔═╡ a8e27a0e-89da-4206-a7e2-94f796cac8b4
res = mo_aco(top, verbose=false, nb_ants=100, nb_iters=500)

# ╔═╡ 270bfe3c-dd71-439c-a2b8-f6cd38c68803
function viz_progress(res::MO_ACO_run)
	fig = Figure(resolution=the_resolution)
	ax  = Axis(fig[1, 1], xlabel="iteration", ylabel="area indicator")
	lines!(1:res.nb_iters, res.areas)
	fig
end

# ╔═╡ 92d564b1-17f1-4fd1-9e76-8ea1b65c127a
viz_progress(res)

# ╔═╡ 4769582f-6498-4f14-a965-ed109b7f97d1
viz_Pareto_front(res.global_pareto_solns)

# ╔═╡ 877f63e6-891d-4988-a17d-a6bdb671eaf3
function viz_soln(
	soln::Soln,
	top::TOP; 
	nlabels::Bool=false, 
	robots::Union{Nothing, Vector{Robot}}=nothing,
	show_robots::Bool=true
)
	g = top.g
	robot_colors = ColorSchemes.Accent_4

	# layout
	_layout = Spring(; iterations=20)
	layout = _layout(g)
	
	fig = Figure(resolution=(300 * top.nb_robots, 400))
	axs = [
		Axis(
			fig[1, r], 
			aspect=DataAspect()
		) 
		for r = 1:top.nb_robots
	]
	for ax in axs
		hidespines!(ax)
		hidedecorations!(ax)
	end
	for r = 1:top.nb_robots
		robot = soln.robots[r]

		# wut is survival prob of this robot?
		π_survive = π_robot_survives(robot.trail, top)
		axs[r].title = "robot $r\nπ(survive)=$(round(π_survive, digits=5))"
		
		# plot graph with nodes and edges colored
		graphplot!(
			axs[r],
			g, 
			layout=layout,
			node_size=14, 
			node_color="gray", 
			edge_color="lightgray",
			nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
			nlabels_align=(:center, :center)
		)
		# represent trail as a graph
		g_trail = SimpleGraph(nv(g))
		for n = 1:length(robot.trail) - 1
			add_edge!(g_trail, robot.trail[n], robot.trail[n+1])
		end
		graphplot!(
			axs[r],
			g_trail,
			layout=layout,
			node_size=0,
			edge_color=(robot_colors[r], 0.5),
			edge_width=10
		)
		
		# start node = 1
		x = layout[1][1]
		y = layout[1][2]
		scatter!(axs[r], [x + 0.1], [y + 0.1], 
			marker='✈',markersize=20, color="black")
	end
	Label(
		fig[2, :], 
		"𝔼[reward]=$(round(soln.objs.r, digits=3))\n
		 𝔼[# robots survive]=$(round(soln.objs.s, digits=3))\n
		"
	)
	fig
end

# ╔═╡ b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
viz_soln(res.global_pareto_solns[1], top)

# ╔═╡ 027dd425-2d7d-4f91-9e10-d5ecd90af49c
viz_soln(res.global_pareto_solns[end], top)

# ╔═╡ 197ea13f-b460-4457-a2ad-ae8d63c5e5ea
viz(res.pheremone, top)

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╠═6e7ce7a6-5c56-48a0-acdd-36ecece95933
# ╠═184af2a6-d5ca-4cbc-8a1a-a172eaae472f
# ╠═8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
# ╟─47eeb310-04aa-40a6-8459-e3178facc83e
# ╠═fcf3cd41-beaa-42d5-a0d4-b77ad4334dd8
# ╟─f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
# ╠═b7f68115-14ea-4cd4-9e96-0fa63a353fcf
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╟─d0fd5e8b-7b3f-45ec-a132-5b33f599f2c9
# ╠═ddfcf601-a6cf-4c52-820d-fcf71bbf3d72
# ╠═926977f1-a337-4825-bfe4-ccc1a2e4cc93
# ╟─e501d59e-336e-456d-8abb-bc663bd4899e
# ╠═cdb0e3ec-426a-48f2-800f-f70cfc20492a
# ╠═2f78b5b8-e996-4b65-b8cc-7b27e45242ec
# ╠═732e023a-048f-4cf4-beba-c14d10fe643f
# ╠═e7c955d6-ba17-4066-a737-e040c3016280
# ╟─ad1c64f5-94b6-4c51-b66d-7cbe77495b2b
# ╠═ec757c86-2072-4cc2-a399-e4ef347c3c80
# ╠═a1572e77-2126-443a-8da1-adcf4af01e87
# ╠═20f4eb18-3d36-43e0-8e97-ed2bccc13f55
# ╠═241eea88-7610-4a54-af23-316b3fdf9780
# ╠═67706b5c-ef3f-48df-b2e2-ace159f814e1
# ╠═12c1ebd2-6b18-4c69-ac04-35639737b5ab
# ╠═9e6d222b-c585-40b2-82c9-5d7b9f5b4e77
# ╠═1b5cfbae-7010-4e37-b8a8-f91df6577eeb
# ╠═0c5d0bbd-d278-4caa-ab1c-a886c2f4aaaa
# ╟─9d44f37d-8c05-450a-a448-7be50387499c
# ╠═2ac621ac-1a44-401e-bdb2-97cbb29d3508
# ╠═974a1e40-50e0-4dc1-9bc9-6ea5ea687ae8
# ╟─84b0295b-6869-4040-8440-41d6a47a7ba4
# ╠═f1c49f3b-eaeb-4950-8e78-b00849682756
# ╠═6d1a6ce7-3944-4fbd-ac22-e678d31d9a9b
# ╠═62751e4b-a109-4304-9fb1-26f8858603e9
# ╠═2ba6b5ce-0404-4b35-997e-56730203d861
# ╠═0cdb4beb-ba8a-4049-b723-1546aa010a8e
# ╟─d8591f8d-5ef2-4363-9e81-c084c94dfc4e
# ╠═d44b2e46-6709-47c6-942a-d9c0e5a7a8bf
# ╠═aabcc1a3-082b-468c-ad1e-648329f7f0c9
# ╠═f97e50dc-ce9b-484b-b3cb-1f38e9100d6f
# ╠═f2ff035f-1a19-47cd-a79e-f634b7cf8447
# ╠═3526e2f9-1e07-43dc-9067-5656d7c864eb
# ╠═2e6d6c29-0cc9-4c6b-9a68-23b93caff78d
# ╟─4c60da94-d66f-461b-9e48-2a3c5343b80e
# ╠═4ea8f171-8834-41d2-ac0e-d3101e63cdc0
# ╠═e289eb93-1446-4506-abb5-f8b3d58ecca6
# ╠═fd90796f-4aa4-476c-b2b2-9a327133d43a
# ╟─40266eb7-f001-411f-9227-d165487c8158
# ╠═762e252d-dcb9-48d9-b981-fa142e272ea0
# ╠═bfd0ec10-4b7e-4a54-b08a-8ecde1f3a97d
# ╠═0ed6899e-3343-4973-8b9a-fe7547eca346
# ╠═a52784a1-cd98-45a7-8931-b8488d71ead9
# ╠═244a70b2-25aa-486f-8c9b-2f761c5766d5
# ╠═96f20fc5-cc82-481f-8cb5-5b538190096e
# ╠═058baefa-23c4-4a10-831c-a045db7ea382
# ╟─9b5a36a0-17a4-403a-9587-9fba3fa1c456
# ╠═fb1a2c2f-2651-46b3-9f79-2e983a7baca6
# ╠═c34fac32-76b4-4051-ba76-9b5a758954f3
# ╠═92b98a6c-3535-4559-951c-210f0d8a8d63
# ╠═553626cc-7b2b-440d-b4e2-66a3c2fccba4
# ╠═a53ce432-02d7-45db-ba26-7f182bc26524
# ╠═33452066-8a35-4bb0-ae58-8bcfb22e2102
# ╟─74459833-f3e5-4b13-b838-380c007c86ed
# ╠═4f7363b5-2aba-4a95-89da-da8c7f1d5ccd
# ╠═2c1eb95b-30dd-4185-8fc4-5c8b6cab507a
# ╠═a8e27a0e-89da-4206-a7e2-94f796cac8b4
# ╠═270bfe3c-dd71-439c-a2b8-f6cd38c68803
# ╠═92d564b1-17f1-4fd1-9e76-8ea1b65c127a
# ╠═4769582f-6498-4f14-a965-ed109b7f97d1
# ╠═877f63e6-891d-4988-a17d-a6bdb671eaf3
# ╠═b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
# ╠═027dd425-2d7d-4f91-9e10-d5ecd90af49c
# ╠═197ea13f-b460-4457-a2ad-ae8d63c5e5ea
