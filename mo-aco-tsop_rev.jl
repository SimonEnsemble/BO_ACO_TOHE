### A Pluto.jl notebook ###
# v0.20.5

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ d04e8854-3557-11ee-3f0a-2f68a1123873
begin
	import Pkg; Pkg.activate("aco")
	using Revise, Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, PlutoUI, StatsBase

	import AlgebraOfGraphics: set_aog_theme!, firasans, wongcolors
	set_aog_theme!(fonts=[firasans("Light"), firasans("Light")])
	the_size = (600, 500)
	update_theme!(
		fontsize=20, 
		linewidth=2,
		markersize=14,
		titlefont=firasans("Light"),
		size=the_size
	)

	push!(LOAD_PATH, "src")
	using MOACOTOP
end

# ╔═╡ e136cdee-f7c1-4add-9024-70351646bf24
TableOfContents()

# ╔═╡ 613ad2a0-abb7-47f5-b477-82351f54894a
md"# BO-ACO of RTOHE problem
BO = bi-objective

ACO = ant colony optimization

RTOHE = robot team orienteering in a hazardous environment

## generate problem instance
"

# ╔═╡ 7e4e838c-0e42-4925-9ddf-4c3601466b64
@bind problem_instance Select(
	["power_plant", "art_museum", "random", "block model", "complete"], default="art_museum"
)

# ╔═╡ 37508da4-9175-47d0-a6a9-3c104d566d90
function complete_graph_top(
    nb_nodes::Int, nb_robots::Int, r_distn::Distribution, w_distn::Distribution
)
    r_distn = Truncated(r_distn, 0.0, Inf)
    w_distn = Truncated(w_distn, 0.0, 1.0)

    g = MetaDiGraph(complete_graph(nb_nodes))
    for v = 1:nv(g)
        set_prop!(g, v, :r, rand(r_distn))
    end
    for ed in edges(g)
        set_prop!(g, ed.src, ed.dst, :ω, rand(w_distn))
        set_prop!(g, ed.dst, ed.src, :ω, rand(w_distn))
    end
    return TOP(nv(g), g, nb_robots)
end

# ╔═╡ bdb5d550-13f6-4d8d-9a74-14b889efe7a2
if problem_instance == "power_plant"
	top = darpa_urban_environment(2)
elseif problem_instance == "art_museum"
	top = art_museum(3)
elseif problem_instance == "random"
	top = generate_random_top(30, 5)
elseif problem_instance == "block model"
	Random.seed!(5)
	local p_interconnect = 0.05
	# complicated graph with few robots
	# to showcase when multiple robot trails better.
	top = block_model(
		# number of nodes
		[10, 8, 12, 6], 

		# number of robots
		2,
		
		# connection probabilities
		[
			0.5 p_interconnect p_interconnect p_interconnect; 
			p_interconnect 0.5 p_interconnect p_interconnect;
			p_interconnect p_interconnect 0.4 p_interconnect;
			p_interconnect p_interconnect p_interconnect 0.8;
		],
		
		# reward dist'n
		[Normal(1.0, 0.5), Normal(5.0, 2.0), Normal(6.0, 1.0), Normal(6.0, 3.0)],
		
		# survival prob dist'n
		[
			Normal(0.9, 0.3) for i = 1:4, j = 1:4
		],
	)
elseif problem_instance == "complete"
	top = complete_graph_top(
		25, 2, Normal(1.0, 1.0), Normal(0.75, 0.2)
	)	
end

# ╔═╡ 76ecc4c1-39b7-4b3c-b98c-cdb1cdcf7eba
@assert get_ω(top.g, 1, 1) == 1.0

# ╔═╡ 0d37a5b6-042f-4951-9dfe-7b7082561c46
function get_unvisited_nodes(trail::Vector{Int}, nb_nodes::Int)
	return [v for v = 1:nb_nodes if ! (v in trail)]
end

# ╔═╡ 8b729e7e-9871-4ed9-83e4-5c85c8ac7ef7
typeof(top)

# ╔═╡ f9d57f37-60ef-482e-9266-afbcb567be08
get_ω(top.g, 1, 1)

# ╔═╡ 21ef0739-9c36-4825-b965-b99cd984b9d2
nv(top.g)

# ╔═╡ efeeb427-9061-4c77-b1c0-50b26abdb6a6
top.nb_robots

# ╔═╡ f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
md"## viz setup"

# ╔═╡ e3946d78-b7d4-4484-9e00-dc20d0457293
if problem_instance == "art_museum"
	art_museum_scale = 8.0
	layout = art_museum_layout(art_museum_scale)
	robot_radius = 0.45
else
	layout = Spring(iterations=350, C=1.4, initialtemp=1.0)(top.g)
	robot_radius = 0.25
end

# ╔═╡ 74ce2e45-8c6c-40b8-8b09-80d97f58af2f
viz_setup(
	top, nlabels=false, layout=layout, robot_radius=robot_radius, savename=problem_instance, depict_r=false, depict_ω=false, show_robots=false, node_size=23
)

# ╔═╡ 79dd4f91-8a4a-4be1-8013-c9b6dfa56a75
begin	
	fig = viz_setup(
		top, nlabels=false, robot_radius=robot_radius,
		savename=problem_instance * "_full_setup", depict_r=true,
		depict_ω=true, show_robots=true, layout=layout, node_size=23
	)
	if problem_instance == "art_museum"
		ax = current_axis()
		for (i, pos) in zip(1:2, [(2.75, 3.6), (3.75, -1.75)])
			text!(ax, pos, text="floor #$i", 
				align=(:center, :center), font=firasans("Light")
			)
		end
	end
	if problem_instance == "power_plant"
		resize!(fig.scene, (the_size[1] * 1.4, the_size[1] * 1.4))
	end
	resize_to_layout!(fig)
	save("paper/" * problem_instance * "_full_setup.pdf", fig)
	fig
end

# ╔═╡ 9d44f37d-8c05-450a-a448-7be50387499c
md"## MO-ACO 🐜
"

# ╔═╡ b9a9808e-8631-45e1-9e31-516565c804a3
md"

\# of iterations: $(@bind nb_iters Select([2, 10, 250, 500, 1000, 5000, 10000], default=2))

\# of runs: $(@bind n_runs Select([1, 2, 5, 10], default=1))

run checks? $(@bind run_checks CheckBox(default=true))
"

# ╔═╡ cdfdf924-d0f5-452f-9c94-eef7592c374d
ρ = 0.9 # evaporation rate

# ╔═╡ 8a6c6d9a-e15a-4f22-9d86-00e591b15693
md"set seeds same to give each the same initial condition for fair comparison."

# ╔═╡ 17117efa-c63e-4193-a99b-c7423367fc06
my_seeds = [rand(1:typemax(Int)) for r = 1:n_runs]

# ╔═╡ 70f8f70f-83ad-4d2b-a40f-7e616462a9c1
test_run = mo_aco(
	top, 
	verbose=true, 
	nb_ants=100, 
	nb_iters=25,
	use_heuristic=true,
	use_pheremone=true,
	run_checks=run_checks,
	my_seed=my_seeds[1], 
	one_pheromone_trail_per_robot=true
)

# ╔═╡ a8e27a0e-89da-4206-a7e2-94f796cac8b4
@time ress = [
	mo_aco(
		top, 
		verbose=false, 
		nb_ants=100, 
		nb_iters=nb_iters,
		use_heuristic=true,
		use_pheremone=true,
		run_checks=run_checks,
		ρ=ρ,
		my_seed=my_seeds[r]
	)
	for r = 1:n_runs
]

# ╔═╡ 0f66c200-8478-4d8c-a2e2-69425b04e5f2
begin	
	function perturb_trail(
		robot::Robot, top::TOP
	)
		# create copy of trail (will not necessarily accept perturbation)
		new_trail = deepcopy(robot.trail)
		@assert new_trail[1] == new_trail[end] == new_trail[end-1] == 1
		
		# current number of non-depot-node visits
		n = length(robot.trail) - 3

		@show robot.trail

		# candidate perturbations
		if n == 0 # stay at depot node
			trail_perturbations = [:insert]
		elseif n == nv(top.g) - 1 # all nodes visisted
			trail_perturbations = [:swap, :delete, :rev_subseq]
		elseif n == 1
			trail_perturbations = [:insert, :delete, :substitute]
		else
			trail_perturbations = [:swap, :insert, :delete, :substitute, :rev_subseq]
		end
		
		perturbation = sample(trail_perturbations)
		@show perturbation
		
		if perturbation == :insert
			# where to insert?
			i = 1 + rand(1:(n+1)) # 1 b/c first node stays depot

			# list of candidate nodes to insert
			unvisited_nodes = get_unvisited_nodes(new_trail, nv(top.g))

			# pick a node to insert
			new_v =  rand(unvisited_nodes)

			# do it!
			insert!(new_trail, i, new_v)
		elseif perturbation == :swap
			# sample two non-depot nodes to swap
			i, j = sample(2:(n+1), 2, replace=false) # positions
			u, v = new_trail[i], new_trail[j]    # actual node IDs
	
			# swap
			new_trail[i] = v
			new_trail[j] = u
		elseif perturbation == :delete
			i = rand(2:(n+1))
			deleteat!(new_trail, i)
		elseif perturbation == :substitute
			# choose node to substitute
			unvisited_nodes = get_unvisited_nodes(new_trail, nv(top.g))
			v = rand(unvisited_nodes)
			
			# node index to eliminate
			i = rand(2:(n+1))

			# substitute
			new_trail[i] = v
		elseif perturbation == :rev_subseq
			i, j = sample(2:(n+1), 2, replace=false) # positions
			ids = (j > i) ? (i:j) : (j:i)
			@show ids
			new_trail[ids] = reverse(new_trail[ids])
		end
			
		# end
		@show new_trail
		@assert new_trail != robot.trail
		@assert new_trail[1] == new_trail[end] == new_trail[end-1] == 1
		
		return new_trail
	end
	

	eg_robot = ress[1].global_pareto_solns[5].robots[2]
	perturb_trail(eg_robot, top)
end

# ╔═╡ 9adc9690-6436-4ba6-a813-8883aa0f3aca
reverse(eg_robot.trail)

# ╔═╡ 3a1caac3-dd55-42fb-91b2-2f9c3001c22c
md"area indicator at end of search:"

# ╔═╡ 793286fa-ff36-44bb-baaf-e7fd819c5aa4
[res.areas[end] for res in ress]

# ╔═╡ 92d564b1-17f1-4fd1-9e76-8ea1b65c127a
viz_progress(ress, savename="progress")

# ╔═╡ 3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
md"
run browser: $(@bind run_id PlutoUI.Slider(1:n_runs))

solution browser: $(@bind soln_id PlutoUI.Slider(1:length(ress[1].global_pareto_solns)))
"

# ╔═╡ f89383c4-e46c-4cc2-967a-11bd451ec486
ress[run_id].global_pareto_solns[soln_id].robots[2].trail

# ╔═╡ 9d49add3-8b03-402d-aa67-a173a74a2995
run_id

# ╔═╡ f2f8de8e-629c-45eb-81f2-9898777678ff
soln_id

# ╔═╡ b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
viz_soln(
	ress[run_id].global_pareto_solns[soln_id], top, show_𝔼=true, layout=layout, robot_radius=robot_radius, elabels=true, only_first_elabel=true
)

# ╔═╡ aca53592-e8d5-4640-951a-7acca6241ea3
ids_hl = [13, 20]#, 133, 178]

# ╔═╡ 4769582f-6498-4f14-a965-ed109b7f97d1
viz_Pareto_front(
	ress[run_id].global_pareto_solns, size=(300, 300), ids_hl=ids_hl, savename="pareto_front", incl_legend=false
)

# ╔═╡ 60917dfc-8342-4bae-abec-d64eab350c15
for soln_id in ids_hl
	viz_soln(ress[run_id].global_pareto_solns[soln_id], top, show_𝔼=false, savename="a_soln_$soln_id", layout=layout, robot_radius=robot_radius, elabels=true, only_first_elabel=true)
end

# ╔═╡ 751c4203-88b1-40dd-9a96-926cd614aef8
viz_soln(
	ress[run_id].global_pareto_solns[soln_id], top, show_𝔼=false, savename="a_soln", layout=layout, robot_radius=robot_radius
)

# ╔═╡ 282b9a15-f2d3-4dd8-8944-758b5d0d3bb7
length(ress[run_id].global_pareto_solns[1].robots)

# ╔═╡ 197ea13f-b460-4457-a2ad-ae8d63c5e5ea
viz_pheremone(ress[run_id].pheremone, top, savename="paper/pheremone", layout=layout)

# ╔═╡ 3d7c6d35-f730-4dc8-a3be-b415e3276013
sort(rand(23), rev=true)

# ╔═╡ 17c48342-f684-4149-b1ea-b626896a4691
viz_soln(
	ress[run_id].global_pareto_solns[soln_id], top, savename="example", robot_radius=robot_radius, layout=layout
)

# ╔═╡ 514851fe-da59-4885-9dc8-0c9fb0c02223
md"### baselines"

# ╔═╡ 2442f18e-9a4c-4a0f-bdf7-6fe1d1517a6b
ress_multiple_trails = [
	mo_aco(
		top, 
		verbose=false, 
		nb_ants=100, 
		nb_iters=nb_iters,
		use_heuristic=true,
		use_pheremone=true,
		run_checks=run_checks,
		my_seed=my_seeds[r],
		one_pheromone_trail_per_robot=true,
		ρ=ρ
	)
	for r = 1:n_runs
]

# ╔═╡ 42590ba8-bca3-4309-a9cf-dad307124463
begin
	local k = 4 # robot ID
	viz_pheremone(
		ress_multiple_trails[run_id].pheremone[k], top, 
		savename="paper/pheremone_$k", layout=layout
	)
end

# ╔═╡ 72ae4f16-173d-4e22-b338-c6781143fa5f
ress_multiple_trails[run_id].pheremone[1]

# ╔═╡ 67c9334e-1155-4ef3-8d75-030dcfc1e570
ress_heuristic_only = [
	mo_aco(
		top, 
		verbose=false, 
		nb_ants=100, 
		nb_iters=nb_iters,
		use_heuristic=true,
		use_pheremone=false,
		run_checks=run_checks,
		my_seed=my_seeds[r]
	)
	for r = 1:n_runs
]

# ╔═╡ 3b94a9a8-93c8-4e46-ae23-63374d368b16
ress_pheremone_only = [
	mo_aco(
		top, 
		verbose=false, 
		nb_ants=100, 
		nb_iters=nb_iters,
		use_heuristic=false,
		use_pheremone=true,
		run_checks=run_checks,
		ρ=ρ,
		my_seed=my_seeds[r]
	)
	for r=1:n_runs
]

# ╔═╡ 2400b72e-2d1a-4c2e-91c7-14c8ac92cc11
ress_random = [
	mo_aco(
		top, 
		verbose=false, 
		nb_ants=100, 
		nb_iters=nb_iters,
		use_heuristic=false,
		use_pheremone=false,
		run_checks=run_checks,
		my_seed=my_seeds[r]
	)
	for r=1:n_runs
]

# ╔═╡ 0808a99f-1f55-4b0a-81e9-3f511c9f55d5
begin
	local fig = Figure(size=(700, 400))
	local ax = Axis(
		fig[1, 1], 
		xlabel="# iterations", 
		ylabel="Pareto-set quality",
		xscale=log10
	)
	for r = 1:n_runs
		lines!(
			1:ress[r].nb_iters, ress[r].areas, 
			label="ACO", linewidth=3, color=(wongcolors()[1], 0.5)
		)
		lines!(
			1:ress_multiple_trails[r].nb_iters, ress_multiple_trails[r].areas, 
			label="ACO (one trail / robot)", 
			linewidth=3, color=(wongcolors()[5], 0.5)
		)
		lines!(
			1:ress_pheremone_only[r].nb_iters, ress_pheremone_only[r].areas, 
			label="heuristic ablation", linewidth=3, color=(wongcolors()[2], 0.5)
		)
		lines!(
			1:ress_heuristic_only[r].nb_iters, ress_heuristic_only[r].areas, 
			label="pheromone ablation", linewidth=3, color=(wongcolors()[3], 0.5)
		)
		lines!(
			1:ress_random[r].nb_iters, ress_random[r].areas, 
			label="random", linewidth=3, color=(wongcolors()[4], 0.5)
		)
	end
	fig[1, 2] = Legend(
		fig, ax, "search algorithm", framevisible = false, unique=true
	)
	save("paper/ACO_comparison.pdf", fig)
	fig
end

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╟─7e4e838c-0e42-4925-9ddf-4c3601466b64
# ╠═bdb5d550-13f6-4d8d-9a74-14b889efe7a2
# ╠═76ecc4c1-39b7-4b3c-b98c-cdb1cdcf7eba
# ╠═37508da4-9175-47d0-a6a9-3c104d566d90
# ╠═0d37a5b6-042f-4951-9dfe-7b7082561c46
# ╠═8b729e7e-9871-4ed9-83e4-5c85c8ac7ef7
# ╠═0f66c200-8478-4d8c-a2e2-69425b04e5f2
# ╠═9adc9690-6436-4ba6-a813-8883aa0f3aca
# ╠═f9d57f37-60ef-482e-9266-afbcb567be08
# ╠═21ef0739-9c36-4825-b965-b99cd984b9d2
# ╠═efeeb427-9061-4c77-b1c0-50b26abdb6a6
# ╟─f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
# ╠═e3946d78-b7d4-4484-9e00-dc20d0457293
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╠═79dd4f91-8a4a-4be1-8013-c9b6dfa56a75
# ╟─9d44f37d-8c05-450a-a448-7be50387499c
# ╟─b9a9808e-8631-45e1-9e31-516565c804a3
# ╠═cdfdf924-d0f5-452f-9c94-eef7592c374d
# ╠═70f8f70f-83ad-4d2b-a40f-7e616462a9c1
# ╟─8a6c6d9a-e15a-4f22-9d86-00e591b15693
# ╠═17117efa-c63e-4193-a99b-c7423367fc06
# ╠═a8e27a0e-89da-4206-a7e2-94f796cac8b4
# ╟─3a1caac3-dd55-42fb-91b2-2f9c3001c22c
# ╠═793286fa-ff36-44bb-baaf-e7fd819c5aa4
# ╠═92d564b1-17f1-4fd1-9e76-8ea1b65c127a
# ╟─3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
# ╠═f89383c4-e46c-4cc2-967a-11bd451ec486
# ╠═9d49add3-8b03-402d-aa67-a173a74a2995
# ╠═f2f8de8e-629c-45eb-81f2-9898777678ff
# ╠═b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
# ╠═aca53592-e8d5-4640-951a-7acca6241ea3
# ╠═4769582f-6498-4f14-a965-ed109b7f97d1
# ╠═60917dfc-8342-4bae-abec-d64eab350c15
# ╠═751c4203-88b1-40dd-9a96-926cd614aef8
# ╠═282b9a15-f2d3-4dd8-8944-758b5d0d3bb7
# ╠═197ea13f-b460-4457-a2ad-ae8d63c5e5ea
# ╠═3d7c6d35-f730-4dc8-a3be-b415e3276013
# ╠═17c48342-f684-4149-b1ea-b626896a4691
# ╟─514851fe-da59-4885-9dc8-0c9fb0c02223
# ╠═2442f18e-9a4c-4a0f-bdf7-6fe1d1517a6b
# ╠═42590ba8-bca3-4309-a9cf-dad307124463
# ╠═72ae4f16-173d-4e22-b338-c6781143fa5f
# ╠═67c9334e-1155-4ef3-8d75-030dcfc1e570
# ╠═3b94a9a8-93c8-4e46-ae23-63374d368b16
# ╠═2400b72e-2d1a-4c2e-91c7-14c8ac92cc11
# ╠═0808a99f-1f55-4b0a-81e9-3f511c9f55d5
