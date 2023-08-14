### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ d04e8854-3557-11ee-3f0a-2f68a1123873
begin
	import Pkg; Pkg.activate()
	using Revise, Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, PlutoUI, StatsBase

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

	push!(LOAD_PATH, "src")
	using MOACOTOP
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

# ╔═╡ 8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
# ╠═╡ disabled = true
#=╠═╡
top = TOP(
	20,
	generate_graph(20, survival_model=:random),
	2,         # number of robots
)
  ╠═╡ =#

# ╔═╡ 47eeb310-04aa-40a6-8459-e3178facc83e
md"toy TOP problems (deterministic, for testing)"

# ╔═╡ fcf3cd41-beaa-42d5-a0d4-b77ad4334dd8
function generate_toy_star_top(nb_nodes::Int)
	Random.seed!(1337)
	g = MetaGraph(star_graph(nb_nodes))

	# add another layer
	@assert degree(g)[1] == nb_nodes-1 # first node is center
	for v = 2:nb_nodes
		add_vertex!(g)
		add_edge!(g, nb_nodes + v - 1, v)
		add_edge!(g, v, nb_nodes + v - 1)
	end
	
	# assign survival probabilities
	for ed in edges(g)
		set_prop!(g, ed, :ω, rand())
	end

	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, 0.1 + rand())
	end
	
	return TOP(nv(g), g, 1)
end

# ╔═╡ a6eacde8-6a89-457c-a3eb-6284e8dd8773
# ╠═╡ disabled = true
#=╠═╡
top = generate_toy_star_top(4)
  ╠═╡ =#

# ╔═╡ f309baac-a2c3-4e89-93bd-9a99fb3157cd
function generate_manual_top()
	Random.seed!(1337)
	g = MetaGraph(SimpleGraph(11))
	lo_risk = 0.95
	hi_risk = 0.70
	edge_list = [
		# branch
		(1, 9, lo_risk),
		# branch
		(1, 10, hi_risk),
		(10, 11, hi_risk),
		# cycle
		(1, 8, lo_risk),
		(8, 7, lo_risk),
		(7, 6, hi_risk),
		(6, 4, hi_risk),
		(4, 3, hi_risk),
		(3, 2, lo_risk),
		(2, 1, lo_risk),
		# bridge off cycle
		(4, 5, 1.0),
		# shortcut in cycle
		(7, 3, lo_risk),
	]
	reward_dict = Dict(
		1=>1, 10=>5, 11=>25, 9=>3, 2=>40, 3=>10, 7=>4, 8=>4, 6=>10, 4=>35, 5=>34
	)
	for (i, j, p_s) in edge_list
		add_edge!(g, i, j, :ω, p_s)
	end
	for v = 1:nv(g)
		set_prop!(g, v, :r, 1.0*reward_dict[v])
	end
	
	return TOP(nv(g), g, 2)
end

# ╔═╡ 47b497ad-3236-47f9-bbf5-f8ddc64b617a
top = generate_manual_top()

# ╔═╡ f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
md"## viz setup"

# ╔═╡ 74ce2e45-8c6c-40b8-8b09-80d97f58af2f
viz_setup(top)

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

# ╔═╡ d8591f8d-5ef2-4363-9e81-c084c94dfc4e
md"### Pareto set"

# ╔═╡ 2e6d6c29-0cc9-4c6b-9a68-23b93caff78d
# reference pt = origin.
# imagine r on the x-axis and s on the y-axis.
function area_indicator(pareto_solns::Vector{Soln})
	# make sure these are indeed Pareto-optimal
	@assert length(get_pareto_solns(pareto_solns)) == length(pareto_solns)
	
	# sort by first objective, 𝔼[reward].
	uo_pareto_solns = unique_solns(pareto_solns, :objs)
	sort_by_r!(uo_pareto_solns)
	
	# initialize area as area of first box
	area = uo_pareto_solns[1].objs.s * uo_pareto_solns[1].objs.r
	for i = 2:length(uo_pareto_solns)-1 # i = the box
		Δs = uo_pareto_solns[i+1].objs.s - uo_pareto_solns[i].objs.s
		Δr = uo_pareto_solns[i+1].objs.r - uo_pareto_solns[i].objs.r
		# @assert Δr >= 0
		# @assert uo_pareto_solns[i+1].objs.s <= uo_pareto_solns[i].objs.s
		area += uo_pareto_solns[i+1].objs.s * Δr
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
			100.0 * ones(nb_nodes, nb_nodes),
			100.0 * ones(nb_nodes, nb_nodes)
		)
	end
end

# ╔═╡ bfd0ec10-4b7e-4a54-b08a-8ecde1f3a97d
toy_pheremone = Pheremone(top)

# ╔═╡ 0ed6899e-3343-4973-8b9a-fe7547eca346
function evaporate!(pheremone::Pheremone, ρ::Float64)
	pheremone.τ_s .*= ρ
	pheremone.τ_r .*= ρ
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

# ╔═╡ b8f68b76-6d1d-49de-acc3-e79e3d414893
@warn "hack in ϕ_s, ϕ_r ..."

# ╔═╡ 2e3694f5-f5c5-419e-97cf-4e726ba90335
# see Min/Max AS paper
function enforce_min_max!(
	pheremone::Pheremone, 
	global_pareto_solns::Vector{Soln},
	ρ::Float64,
	avg_nb_choices_soln_components::Float64;
	p_best::Float64=0.05 # prob select best soln at convergence as defined
)
	# get best of each objective
	id_r_max = argmax(soln.objs.r for soln in global_pareto_solns)
	id_s_max = argmax(soln.objs.s for soln in global_pareto_solns)

	# best objective values
	r_max = global_pareto_solns[id_r_max].objs.r
	s_max = global_pareto_solns[id_s_max].objs.s

	# number of solution components in opt trails for the two objs
	n_r = sum(
		[length(robot.trail) for robot in global_pareto_solns[id_r_max].robots]
	)
	n_s = sum(
		[length(robot.trail) for robot in global_pareto_solns[id_s_max].robots]
	)

	# estimate τ_max
	τ_max_r = r_max / ρ
	τ_max_s = s_max / ρ

	# compute τ_min
	#   warning: I manually set this because it is too large otherwise.
	ϕ_r = 0.05 # (1 - p_best ^ (1 / n_r)) / ((avg_nb_choices_soln_components - 1) * p_best ^ (1 / n_r))
	τ_min_r = τ_max_r * ϕ_r
	ϕ_s = 0.05 # (1 - p_best ^ (1 / n_s)) / ((avg_nb_choices_soln_components - 1) * p_best ^ (1 / n_s))
	τ_min_s = τ_max_s * ϕ_s
	@assert ϕ_s < 0.4
	@assert ϕ_r < 0.4

	# impose limits by clipping
	nb_nodes = size(pheremone.τ_s)[1]
	for i = 1:nb_nodes
		for j = 1:nb_nodes
			pheremone.τ_s[i, j] = clamp(pheremone.τ_s[i, j], τ_min_s, τ_max_s)
			pheremone.τ_r[i, j] = clamp(pheremone.τ_r[i, j], τ_min_r, τ_max_r)
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

# ╔═╡ 058baefa-23c4-4a10-831c-a045db7ea382
function viz(pheremone::Pheremone, top::TOP)
	g_d = covert_top_graph_to_digraph(top)

	# layout
	_layout = Spring(; iterations=50)
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

	# histograms too
	axs_hist = [
		Axis(
			fig[2, i], 
			ylabel="# edges"
		) 
		for i = 1:2
	]
	τ_s = [pheremone.τ_s[ed.src, ed.dst] for ed in edges(g_d)]
	τ_r = [pheremone.τ_r[ed.src, ed.dst] for ed in edges(g_d)]
	hist!(axs_hist[1], τ_r, color="green")
	hist!(axs_hist[2], τ_s, color="red")
	axs_hist[1].xlabel = "τᵣ"
	axs_hist[2].xlabel = "τₛ"
	xlims!(axs_hist[1], 0.0, nothing)
	xlims!(axs_hist[2], 0.0, nothing)
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
	@assert ! robot.done
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

	# if base node, robot is done TODO: figure out how to get rid of this.
	# if (v == 1)
	# 	robot.done = true
	# end
	
	# push to robot's trail and update edge visitation status
	hop_to!(robot, v, top)
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
	run_checks::Bool=true,
	ρ::Float64=0.98, # 1 - evaporation rate
	min_max::Bool=true
)
	# initialize ants and pheremone
	ants = Ants(nb_ants)
	pheremone = Pheremone(top)
	#    for computing τ_min, τ_max
	avg_nb_choices_soln_components = mean(degree(top.g)) / 2
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
					verify(robot, top)
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
		global_pareto_solns = unique_solns(global_pareto_solns, :robot_trails)
		
		#=
		🐜 evaporate, lay, clip pheremone
		=#
		evaporate!(pheremone, ρ)
		if rand() < 0.2
			lay!(pheremone, global_pareto_solns)
		else
			lay!(pheremone, iter_pareto_solns)
		end
		if min_max
			enforce_min_max!(pheremone, global_pareto_solns, ρ, avg_nb_choices_soln_components)
		end

		if verbose
			println("iter $i:")
			println("\t$(length(iter_pareto_solns)) nd-solns")
			println("\tglobally $(length(global_pareto_solns)) nd-solns")
			println("max τs = ", maximum(pheremone.τ_s))
			println("min τs = ", minimum(pheremone.τ_s))
			println("max τr = ", maximum(pheremone.τ_r))
			println("min τr = ", minimum(pheremone.τ_r))
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
res = mo_aco(top, verbose=false, nb_ants=100, nb_iters=200, min_max=false)

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
		",
		font=firasans("Light")
	)
	fig
end

# ╔═╡ 3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
@bind soln_id PlutoUI.Slider(1:length(res.global_pareto_solns))

# ╔═╡ b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
viz_soln(res.global_pareto_solns[soln_id], top)

# ╔═╡ 197ea13f-b460-4457-a2ad-ae8d63c5e5ea
viz(res.pheremone, top)

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╠═6e7ce7a6-5c56-48a0-acdd-36ecece95933
# ╠═8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
# ╟─47eeb310-04aa-40a6-8459-e3178facc83e
# ╠═fcf3cd41-beaa-42d5-a0d4-b77ad4334dd8
# ╠═a6eacde8-6a89-457c-a3eb-6284e8dd8773
# ╠═f309baac-a2c3-4e89-93bd-9a99fb3157cd
# ╠═47b497ad-3236-47f9-bbf5-f8ddc64b617a
# ╟─f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╟─9d44f37d-8c05-450a-a448-7be50387499c
# ╠═2ac621ac-1a44-401e-bdb2-97cbb29d3508
# ╠═974a1e40-50e0-4dc1-9bc9-6ea5ea687ae8
# ╟─d8591f8d-5ef2-4363-9e81-c084c94dfc4e
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
# ╠═b8f68b76-6d1d-49de-acc3-e79e3d414893
# ╠═2e3694f5-f5c5-419e-97cf-4e726ba90335
# ╠═244a70b2-25aa-486f-8c9b-2f761c5766d5
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
# ╠═3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
# ╠═b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
# ╠═197ea13f-b460-4457-a2ad-ae8d63c5e5ea
