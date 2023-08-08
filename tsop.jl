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
	g = erdos_renyi(nb_nodes, 0.3)
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
	g::MetaGraph
	nb_robots::Int
end

# ╔═╡ 8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
top = TOP(
	generate_graph(20, survival_model=:binary),
	3,         # number of robots
)

# ╔═╡ ddfcf601-a6cf-4c52-820d-fcf71bbf3d72
begin
	mutable struct Robot
		path::Vector{Int}
		done::Bool
	end
	
	Robot() = Robot([1], false)
end

# ╔═╡ 43292bcd-8830-49f1-9db4-fb94e5847ed9
get_prop(top.g, 1, 1, :ω)

# ╔═╡ f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
md"## viz setup"

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
	# plot paths as highlighted edges
	if ! isnothing(robots)
		for (r, robot) in enumerate(robots)
			# represent path as a graph
			g_path = SimpleGraph(nv(g))
			for n = 1:length(robot.path) - 1
				add_edge!(g_path, robot.path[n], robot.path[n+1])
			end
			graphplot!(
				g_path,
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

# ╔═╡ e501d59e-336e-456d-8abb-bc663bd4899e
md"## computing survival probabilities"

# ╔═╡ 926977f1-a337-4825-bfe4-ccc1a2e4cc93
function verify_path(path::Vector{Int}, top::TOP)
	# can follow edges that exist in the graph
	for n = 1:length(path)-1
		@assert has_edge(top.g, path[n], path[n+1])
	end
	# TODO uniqueness of nodes visisted (depends on base situation)
end

# ╔═╡ cdb0e3ec-426a-48f2-800f-f70cfc20492a
function π_robot_survives(path::Vector{Int}, top::TOP)
	if path == [1, 1]
		return 1.0
	end
	# path length, in terms of # edges
	ℓ = length(path) - 1
	# product of survival probabilities along the path (gotta survive all)
	return prod(
		get_prop(top.g, path[n], path[n+1], :ω)
			for n = 1:ℓ # n := edge along the path.
	)
end

# ╔═╡ 2f78b5b8-e996-4b65-b8cc-7b27e45242ec
function 𝔼_nb_robots_survive(robots::Vector{Robot}, top::TOP)
	return sum(π_robot_survives(robot.path, top) for robot in robots)
end

# ╔═╡ 732e023a-048f-4cf4-beba-c14d10fe643f
function π_robot_visits_node_j(robot::Robot, j::Int, top::TOP)
	# if the first node in the path is j, survival probability is one.
	#  b/c survives at the base for sure.
	if robot.path[1] == j
		return 1.0
	end
	# which node in the path is node j? (possibly not there)
	id_path_giving_node_j = findfirst(robot.path .== j)
	if isnothing(id_path_giving_node_j)
		# case: node j not in path
		return 0.0
	else
		# case: node j in path
		#    then we gotta survive the path up till and including node j.
		# @assert path[id_path_giving_node_j] == j
		return π_robot_survives(robot.path[1:id_path_giving_node_j], top)
	end
end

# ╔═╡ e7c955d6-ba17-4066-a737-e040c3016280
function random_path(n::Int, top::TOP)
	path = zeros(Int, n+1)
	path[1] = 1
	for i = 1:n
		next_candidates = [u for u in neighbors(top.g, path[i]) if ! (u in path)]
		if length(next_candidates) == 0
			break
		end
		path[i+1] = sample(next_candidates)
	end
	return Robot(path, false)
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
robots = [random_path(3, top), random_path(4, top), random_path(2, top)]

# ╔═╡ 241eea88-7610-4a54-af23-316b3fdf9780
π_robot_survives(robots[1].path, top)

# ╔═╡ 67706b5c-ef3f-48df-b2e2-ace159f814e1
π_robot_visits_node_j(robots[1], 15, top)

# ╔═╡ 12c1ebd2-6b18-4c69-ac04-35639737b5ab
viz_setup(top, robots=robots)

# ╔═╡ 9e6d222b-c585-40b2-82c9-5d7b9f5b4e77
𝔼_reward(robots, top)

# ╔═╡ 1b5cfbae-7010-4e37-b8a8-f91df6577eeb
𝔼_nb_robots_survive(robots, top)

# ╔═╡ 0c5d0bbd-d278-4caa-ab1c-a886c2f4aaaa
π_robot_survives(robots[3].path, top)

# ╔═╡ 9d44f37d-8c05-450a-a448-7be50387499c
md"## MO-ACO
### heuristics

combined could be reward per survival.
"

# ╔═╡ 974a1e40-50e0-4dc1-9bc9-6ea5ea687ae8
# heuristic for hop u -> v
# score = survival probability of that edge.
function η_survival(u::Int, v::Int, top::TOP)
	if u == v == 1
		return 1.0
	end
	return get_prop(top.g, u, v, :ω)
end

# ╔═╡ 2ac621ac-1a44-401e-bdb2-97cbb29d3508
# heuristic for hop u -> v
# score = reward of node v
function η_reward(u::Int, v::Int, top::TOP)
	return get_prop(top.g, v, :r)
end

# ╔═╡ 84b0295b-6869-4040-8440-41d6a47a7ba4
md"### storing Pareto front"

# ╔═╡ f1c49f3b-eaeb-4950-8e78-b00849682756
# objectives
struct Objs
	𝔼_reward::Float64
	𝔼_nb_robots_survive::Float64
end

# ╔═╡ 6d1a6ce7-3944-4fbd-ac22-e678d31d9a9b
begin
	struct Soln
		robots::Vector{Robot}
		objs::Objs
	end
	Soln(top::TOP) = Soln(
		[Robot() for k = 1:top.nb_robots], 
		Objs(NaN, NaN)
	)
end

# ╔═╡ e138f48b-eb22-40b8-aab1-ce877fba4f8f
# pool of solutions
mutable struct ParetoFront
	solns::Vector{Soln}
end

# ╔═╡ d44b2e46-6709-47c6-942a-d9c0e5a7a8bf
function sol_dominates_sol(soln₁::Soln, soln₂::Soln)
	better_reward   = soln₁.objs.𝔼_reward            >= soln₂.objs.𝔼_reward
	better_survival = soln₁.objs.𝔼_nb_robots_survive >= soln₂.objs.𝔼_nb_robots_survive
	return better_reward && better_survival
end

# ╔═╡ aabcc1a3-082b-468c-ad1e-648329f7f0c9
function nondominated_solns(solns::Vector{Soln})
	ids_nondominated = [true for i = 1:length(solns)]
	# look at each solution.
	for i = 1:length(solns)
		# if ANY other solution dominates it, it's not a dominant solution 
		for j = 1:length(solns)
			if i == j
				continue
			end
			if sol_dominates_sol(solns[j], solns[i])
				ids_nondominated[i] = false
				break
			end
		end
	end
	return solns[ids_nondominated]
end

# ╔═╡ 3526e2f9-1e07-43dc-9067-5656d7c864eb
function viz_Pareto_front(solns::Vector{Soln})
	local fig = Figure()
	local ax = Axis(
		fig[1, 1],
		xlabel="𝔼(# robots survive)", 
		ylabel="𝔼(rewards)"
	)
	xlims!(0, nothing)
	ylims!(0, nothing)
	scatter!(
		[soln.objs.𝔼_nb_robots_survive for soln in solns],
		[soln.objs.𝔼_reward for soln in solns]
	)
	nd_solns = nondominated_solns(solns)
	scatter!(
		[soln.objs.𝔼_nb_robots_survive for soln in nd_solns],
		[soln.objs.𝔼_reward for soln in nd_solns], marker=:x
	)
	fig
end

# ╔═╡ 4c60da94-d66f-461b-9e48-2a3c5343b80e
md"### ants"

# ╔═╡ 4ea8f171-8834-41d2-ac0e-d3101e63cdc0
struct Ant
	λ::Float64
end

# ╔═╡ e289eb93-1446-4506-abb5-f8b3d58ecca6
Ants(nb_ants::Int) = [Ant((k - 1) / (nb_ants - 1)) for k = 1:nb_ants]

# ╔═╡ 40266eb7-f001-411f-9227-d165487c8158
md"### pheremone"

# ╔═╡ 762e252d-dcb9-48d9-b981-fa142e272ea0
begin
	struct Pheremone
		τ_survival::Matrix{Float64}
		τ_reward  ::Matrix{Float64}
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

# ╔═╡ 0ed6899e-3343-4973-8b9a-fe7547eca346
function evaporate!(pheremone::Pheremone, ρ::Float64=0.02)
	pheremone.τ_survival .*= (1 - ρ)
	pheremone.τ_reward   .*= (1 - ρ)
	return nothing
end

# ╔═╡ a52784a1-cd98-45a7-8931-b8488d71ead9
function lay!(pheremone::Pheremone, nd_solns::Vector{Soln})
	ℓ = length(nd_solns)
	# each non-dominated solution contributes pheremone.
	for nd_soln in nd_solns
		# loop over robots
		for robot in nd_soln.robots
			# loop over robot path
			for i = 1:length(robot.path)-1
				# step u -> v
				u = robot.path[i]
				v = robot.path[i+1]
				# lay it!
				# TODO: doesn't scaling here matter?
				pheremone.τ_reward[u, v] += nd_soln.objs.𝔼_reward / ℓ
				pheremone.τ_survival[u, v] += nd_soln.objs.𝔼_nb_robots_survive / ℓ
			end
		end
	end
	return nothing
end

# ╔═╡ e56941ec-927e-4e11-8542-3c134c8966f5
pheremone = Pheremone(top)

# ╔═╡ baefb187-b38c-494a-8d31-b2364fd75caf
ants = Ants(100)

# ╔═╡ 9b5a36a0-17a4-403a-9587-9fba3fa1c456
md"### building partial solution"

# ╔═╡ fb1a2c2f-2651-46b3-9f79-2e983a7baca6
# TODO should this depend on other robots?
function next_node_candidates(robot::Robot, top::TOP)
	# current vertex
	u = robot.path[end]
	# return neighbors of u 
	#  if we exclude nodes visisted already, then
	#    robot could get stuck.
	#    def gotta allow the base to be re-visisted...
	#  we always keep the base as an option
	vs = [v for v in neighbors(top.g, u)]# if ! (v in robot.path[2:end])]
	# give option to never leave base
	if u == 1
		push!(vs, 1)
	end
	return vs
end

# ╔═╡ c34fac32-76b4-4051-ba76-9b5a758954f3
function extend_path!(robot::Robot, ant::Ant, pheremone::Pheremone, top::TOP)
	# current vertex
	u = robot.path[end]
	
	# get list of next-node condidates
	vs = next_node_candidates(robot, top)
	
	# build probabilities by combining heuristic and pheremone.
	#   each ant weighs obj's differently.
	transition_probs = [
		(pheremone.τ_survival[u, v] * η_survival(u, v, top)) ^ ant.λ * 
		(pheremone.τ_reward[u, v]   * η_reward(u, v, top)  ) ^ (1 - ant.λ)
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
	
	# push to robot's path
	push!(robot.path, v)
	return v
end

# ╔═╡ 92b98a6c-3535-4559-951c-210f0d8a8d63
function construct_soln(ant::Ant, pheremone::Pheremone, top::TOP)
	# initialize robots
	robots = [Robot() for k = 1:top.nb_robots]
	
	# ant builds a solution
	for robot in robots
		while ! robot.done
			extend_path!(robot, ant, pheremone, top)
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

# ╔═╡ 1fbfb3e1-6211-4ef7-8602-465817ced205
construct_soln(ants[1], pheremone, top)

# ╔═╡ 553626cc-7b2b-440d-b4e2-66a3c2fccba4
bogus_solns = [construct_soln(ant, pheremone, top) for ant in ants];

# ╔═╡ a53ce432-02d7-45db-ba26-7f182bc26524
viz_setup(top, robots=bogus_solns[2].robots)

# ╔═╡ 33452066-8a35-4bb0-ae58-8bcfb22e2102
viz_Pareto_front(bogus_solns)

# ╔═╡ 74459833-f3e5-4b13-b838-380c007c86ed
md"### 🐜"

# ╔═╡ 2c1eb95b-30dd-4185-8fc4-5c8b6cab507a
function mo_aco(top::TOP; nb_ants::Int=100, nb_iters::Int=10, verbose::Bool=false)
	# initialize ants and pheremone
	ants = Ants(nb_ants)
	pheremone = Pheremone(top)
	# shared pool of non-dominated solutions
	global_nd_solns = Soln[]
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

		#=
		compute non-dominated solutions
		=#
		iter_nd_solns = nondominated_solns(solns)

		#=
		update global pool of non-dominated solutions
		=#
		global_nd_solns = nondominated_solns(
			vcat(global_nd_solns, iter_nd_solns)
		)

		if verbose
			println("iter $i:")
			println("\t$(length(iter_nd_solns)) nd-solns")
			println("\tglobally $(length(global_nd_solns)) nd-solns")
		end
		
		#=
		🐜 lay pheremone
		=#
		evaporate!(pheremone)
		if rand() < 0.2
			lay!(pheremone, global_nd_solns)
		else
			lay!(pheremone, iter_nd_solns)
		end
	end
	# sort by obj
	ids_sorted = sortperm([s.objs.𝔼_reward for s in global_nd_solns])
	return global_nd_solns[ids_sorted]
end

# ╔═╡ a8e27a0e-89da-4206-a7e2-94f796cac8b4
global_nd_solns = mo_aco(top, verbose=false, nb_ants=100, nb_iters=100)

# ╔═╡ 4769582f-6498-4f14-a965-ed109b7f97d1
viz_Pareto_front(global_nd_solns)

# ╔═╡ 1a92f1b9-0c76-4dfe-b499-9eb9cca61391
viz_setup(top, robots=global_nd_solns[1].robots)

# ╔═╡ 0988e5aa-09b0-4c10-b23c-86d613e1401c
viz_setup(top, robots=global_nd_solns[end].robots)

# ╔═╡ 877f63e6-891d-4988-a17d-a6bdb671eaf3
function viz_soln(
	soln::Soln,
	top::TOP; 
	nlabels::Bool=true, 
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
			aspect=DataAspect(), 
			title="robot $r"
		) 
		for r = 1:top.nb_robots
	]
	for ax in axs
		hidespines!(ax)
		hidedecorations!(ax)
	end
	for r = 1:top.nb_robots
		robot = soln.robots[r]
		
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
		# represent path as a graph
		g_path = SimpleGraph(nv(g))
		for n = 1:length(robot.path) - 1
			add_edge!(g_path, robot.path[n], robot.path[n+1])
		end
		graphplot!(
			axs[r],
			g_path,
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
		"𝔼[reward]=$(round(soln.objs.𝔼_reward, digits=3))\n
		 𝔼[# robots survive]=$(round(soln.objs.𝔼_nb_robots_survive, digits=3))\n
		"
	)
	fig
end

# ╔═╡ b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
viz_soln(global_nd_solns[1], top)

# ╔═╡ 027dd425-2d7d-4f91-9e10-d5ecd90af49c
viz_soln(global_nd_solns[end], top)

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╠═6e7ce7a6-5c56-48a0-acdd-36ecece95933
# ╠═184af2a6-d5ca-4cbc-8a1a-a172eaae472f
# ╠═8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
# ╠═ddfcf601-a6cf-4c52-820d-fcf71bbf3d72
# ╠═43292bcd-8830-49f1-9db4-fb94e5847ed9
# ╟─f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
# ╠═b7f68115-14ea-4cd4-9e96-0fa63a353fcf
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╟─e501d59e-336e-456d-8abb-bc663bd4899e
# ╠═926977f1-a337-4825-bfe4-ccc1a2e4cc93
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
# ╠═974a1e40-50e0-4dc1-9bc9-6ea5ea687ae8
# ╠═2ac621ac-1a44-401e-bdb2-97cbb29d3508
# ╟─84b0295b-6869-4040-8440-41d6a47a7ba4
# ╠═f1c49f3b-eaeb-4950-8e78-b00849682756
# ╠═6d1a6ce7-3944-4fbd-ac22-e678d31d9a9b
# ╠═e138f48b-eb22-40b8-aab1-ce877fba4f8f
# ╠═d44b2e46-6709-47c6-942a-d9c0e5a7a8bf
# ╠═aabcc1a3-082b-468c-ad1e-648329f7f0c9
# ╠═3526e2f9-1e07-43dc-9067-5656d7c864eb
# ╟─4c60da94-d66f-461b-9e48-2a3c5343b80e
# ╠═4ea8f171-8834-41d2-ac0e-d3101e63cdc0
# ╠═e289eb93-1446-4506-abb5-f8b3d58ecca6
# ╟─40266eb7-f001-411f-9227-d165487c8158
# ╠═762e252d-dcb9-48d9-b981-fa142e272ea0
# ╠═0ed6899e-3343-4973-8b9a-fe7547eca346
# ╠═a52784a1-cd98-45a7-8931-b8488d71ead9
# ╠═e56941ec-927e-4e11-8542-3c134c8966f5
# ╠═baefb187-b38c-494a-8d31-b2364fd75caf
# ╟─9b5a36a0-17a4-403a-9587-9fba3fa1c456
# ╠═fb1a2c2f-2651-46b3-9f79-2e983a7baca6
# ╠═c34fac32-76b4-4051-ba76-9b5a758954f3
# ╠═92b98a6c-3535-4559-951c-210f0d8a8d63
# ╠═1fbfb3e1-6211-4ef7-8602-465817ced205
# ╠═553626cc-7b2b-440d-b4e2-66a3c2fccba4
# ╠═a53ce432-02d7-45db-ba26-7f182bc26524
# ╠═33452066-8a35-4bb0-ae58-8bcfb22e2102
# ╟─74459833-f3e5-4b13-b838-380c007c86ed
# ╠═2c1eb95b-30dd-4185-8fc4-5c8b6cab507a
# ╠═a8e27a0e-89da-4206-a7e2-94f796cac8b4
# ╠═4769582f-6498-4f14-a965-ed109b7f97d1
# ╠═1a92f1b9-0c76-4dfe-b499-9eb9cca61391
# ╠═0988e5aa-09b0-4c10-b23c-86d613e1401c
# ╠═877f63e6-891d-4988-a17d-a6bdb671eaf3
# ╠═b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
# ╠═027dd425-2d7d-4f91-9e10-d5ecd90af49c
