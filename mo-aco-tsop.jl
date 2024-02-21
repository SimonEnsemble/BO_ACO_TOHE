### A Pluto.jl notebook ###
# v0.19.38

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
function generate_random_top(
	nb_nodes::Int, 
	nb_robots::Int; 
	survival_model=:random, 
	p=0.3
)
	@assert survival_model in [:random, :binary]
	
	# generate structure of the graph
	g_er = erdos_renyi(nb_nodes, p, is_directed=false)
	g = MetaDiGraph(nb_nodes)
	
	for ed in edges(g_er)
		add_edge!(g, ed.src, ed.dst)
		add_edge!(g, ed.dst, ed.src)
		if survival_model == :random
			ω = rand()
		elseif survival_model == :binary
			ω = rand([0.4, 0.8])
		end
		set_prop!(g, ed.src, ed.dst, :ω, ω)
		set_prop!(g, ed.dst, ed.src, :ω, ω)
	end
	
	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, 0.1 + rand()) # reward too small, heuristic won't take it there.
	end

	# compute max one-hop 𝔼[reward]
    one_hop_𝔼_r = zeros(nv(g))
    for v = 1:nv(g)
        us = neighbors(g_er, v)
        one_hop_𝔼_r[v] = maximum(get_prop(g, u, v, :ω) * get_prop(g, v, :r) for u in us)
    end
	
	# for base node
	# set_prop!(g, 1, :r, 0.001)
	return TOP(
		nb_nodes,
		g,
		nb_robots,
		maximum(one_hop_𝔼_r)
	)
end

# ╔═╡ 8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
# ╠═╡ disabled = true
#=╠═╡
top = generate_random_top(50, 4)
  ╠═╡ =#

# ╔═╡ bdb5d550-13f6-4d8d-9a74-14b889efe7a2
top = art_museum(3)

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
	
	return TOP(nv(g), g, 2, maximum([get_prop(g, v, :r) for v = 1:nv(g)]))
end

# ╔═╡ c3633991-6015-4cde-8aea-62c6ff9a1fdd
# ╠═╡ disabled = true
#=╠═╡
top = generate_manual_top()
  ╠═╡ =#

# ╔═╡ f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
md"## viz setup"

# ╔═╡ 54ddc953-ad25-4d77-905e-732a7664e9aa
robot_example = Robot([1, 2, 4, 5, 3, 2, 1], top)

# ╔═╡ ab9bf29e-8d06-42a0-ac38-8564af098025
robots_example = [
		robot_example,
		Robot([1, 2, 21, 22, 27, 26, 27, 23, 21, 2, 1], top),
		Robot([1, 2, 3, 6, 8, 10, 9, 2, 1], top)
	]

# ╔═╡ d2a377a0-4e0b-489d-b4d2-55c85cfaa07e
robots_failure_example = [
		Robot(robots_example[1].trail[1:5], top),
		Robot(robots_example[2].trail[1:5], top),
		Robot(robots_example[3].trail[1:3], top),
	]

# ╔═╡ 74ce2e45-8c6c-40b8-8b09-80d97f58af2f
viz_setup(top, nlabels=true, C=2.0, radius=0.5, savename="art_gallery", depict_r=false, depict_ω=false, show_robots=true)

# ╔═╡ e8598540-a37b-4f52-a6ca-819c50411d13
viz_setup(top, nlabels=true, C=2.0, radius=0.5, savename="art_gallery_trail", depict_r=false, depict_ω=false, robots=[robot_example])

# ╔═╡ 2e468a5c-4400-4da8-b2f5-c978065cf440
viz_setup(top, nlabels=true, C=2.0, radius=0.5, savename="art_gallery_trails", depict_r=false, depict_ω=false, 
	robots=robots_example
)

# ╔═╡ 65cba45f-0151-4692-8280-7c67cc4372ec
viz_setup(top, nlabels=true, C=2.0, radius=0.5, savename="art_gallery_omegas", depict_r=false, depict_ω=true, show_robots=true)

# ╔═╡ 787972cc-f1de-4f6d-9760-c92cbcb2bc4c
viz_setup(top, nlabels=true, C=2.0, radius=0.5, savename="art_gallery_prob_survive_robot", depict_r=false, depict_ω=true, show_robots=true, robots=[robot_example])

# ╔═╡ 7cfd6d84-aa4f-4dd2-9dff-7da94ff3b82e
viz_setup(top, nlabels=true, C=2.0, radius=0.5, savename="art_gallery_prob_survive_team", depict_r=false, depict_ω=true, show_robots=true, robots=robots_example)

# ╔═╡ 79dd4f91-8a4a-4be1-8013-c9b6dfa56a75
viz_setup(top, nlabels=true, C=2.0, radius=0.6, savename="art_gallery_full_setup", depict_r=true, depict_ω=true, show_robots=true)

# ╔═╡ fd7d8294-3e2b-4954-96f8-b4773ba11cef
viz_setup(top, nlabels=true, C=2.0, radius=0.5, savename="art_gallery_failure", depict_r=false, depict_ω=false, show_robots=true,
	robots=robots_failure_example)

# ╔═╡ f9ad4452-5927-43cc-b14d-5cd87bf8cf54
viz_setup(top, nlabels=true, C=2.0, radius=0.6, savename="art_gallery_plans_b4_failure", depict_r=true, depict_ω=true, 
	robots=robots_example)

# ╔═╡ a8a194e0-28fe-4016-81ba-d1375ad1852e
viz_setup(top, nlabels=true, C=2.0, radius=0.6, savename="art_gallery_plans_all", depict_r=true, depict_ω=false, 
	robots=robots_example)

# ╔═╡ 9d44f37d-8c05-450a-a448-7be50387499c
md"## MO-ACO
"

# ╔═╡ 74459833-f3e5-4b13-b838-380c007c86ed
md"### 🐜"

# ╔═╡ a8e27a0e-89da-4206-a7e2-94f796cac8b4
@time res = mo_aco(
	top, 
	verbose=false, 
	nb_ants=100, 
	nb_iters=3000,
	consider_previous_robots=true,
	use_heuristic=true,
	use_pheremone=true,
)

# ╔═╡ 793286fa-ff36-44bb-baaf-e7fd819c5aa4
res.areas[end]

# ╔═╡ 92d564b1-17f1-4fd1-9e76-8ea1b65c127a
viz_progress(res, savename="progress")

# ╔═╡ 3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
@bind soln_id PlutoUI.Slider(1:length(res.global_pareto_solns))

# ╔═╡ b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
viz_soln(res.global_pareto_solns[soln_id], top, show_𝔼=true, savename="a_soln")

# ╔═╡ 4769582f-6498-4f14-a965-ed109b7f97d1
viz_Pareto_front(res.global_pareto_solns, id_hl=soln_id, savename="pareto_front")#)

# ╔═╡ 197ea13f-b460-4457-a2ad-ae8d63c5e5ea
viz_pheremone(res.pheremone, top, savename="pheremone")

# ╔═╡ 17c48342-f684-4149-b1ea-b626896a4691
viz_soln(res.global_pareto_solns[soln_id], top, savename="example", radius=0.5)

# ╔═╡ 67c9334e-1155-4ef3-8d75-030dcfc1e570
res_heuristic_only = mo_aco(
	top, 
	verbose=false, 
	nb_ants=100, 
	nb_iters=3000,
	consider_previous_robots=true,
	use_heuristic=true,
	use_pheremone=false,
)

# ╔═╡ 3b94a9a8-93c8-4e46-ae23-63374d368b16
res_pheremone_only = mo_aco(
	top, 
	verbose=false, 
	nb_ants=100, 
	nb_iters=3000,
	consider_previous_robots=true,
	use_heuristic=false,
	use_pheremone=true,
)

# ╔═╡ 0808a99f-1f55-4b0a-81e9-3f511c9f55d5
begin
	local fig = Figure(resolution=MOACOTOP.the_resolution)
	local ax = Axis(fig[1, 1], xlabel="# iterations", ylabel="area indicator")
	lines!(1:res.nb_iters, res.areas, label="ACO")
	lines!(1:res_pheremone_only.nb_iters, res_pheremone_only.areas, label="ACO (no heuristic)")
	lines!(1:res_heuristic_only.nb_iters, res_heuristic_only.areas, label="ACO (no pheromone)")
	axislegend(position=:rb)
	save("ACO_comparison.pdf", fig)
	fig
end

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╠═6e7ce7a6-5c56-48a0-acdd-36ecece95933
# ╠═8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
# ╠═bdb5d550-13f6-4d8d-9a74-14b889efe7a2
# ╟─47eeb310-04aa-40a6-8459-e3178facc83e
# ╠═fcf3cd41-beaa-42d5-a0d4-b77ad4334dd8
# ╠═f309baac-a2c3-4e89-93bd-9a99fb3157cd
# ╠═c3633991-6015-4cde-8aea-62c6ff9a1fdd
# ╟─f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
# ╠═54ddc953-ad25-4d77-905e-732a7664e9aa
# ╠═ab9bf29e-8d06-42a0-ac38-8564af098025
# ╠═d2a377a0-4e0b-489d-b4d2-55c85cfaa07e
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╠═e8598540-a37b-4f52-a6ca-819c50411d13
# ╠═2e468a5c-4400-4da8-b2f5-c978065cf440
# ╠═65cba45f-0151-4692-8280-7c67cc4372ec
# ╠═787972cc-f1de-4f6d-9760-c92cbcb2bc4c
# ╠═7cfd6d84-aa4f-4dd2-9dff-7da94ff3b82e
# ╠═79dd4f91-8a4a-4be1-8013-c9b6dfa56a75
# ╠═fd7d8294-3e2b-4954-96f8-b4773ba11cef
# ╠═f9ad4452-5927-43cc-b14d-5cd87bf8cf54
# ╠═a8a194e0-28fe-4016-81ba-d1375ad1852e
# ╟─9d44f37d-8c05-450a-a448-7be50387499c
# ╟─74459833-f3e5-4b13-b838-380c007c86ed
# ╠═a8e27a0e-89da-4206-a7e2-94f796cac8b4
# ╠═793286fa-ff36-44bb-baaf-e7fd819c5aa4
# ╠═92d564b1-17f1-4fd1-9e76-8ea1b65c127a
# ╟─3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
# ╠═b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
# ╠═4769582f-6498-4f14-a965-ed109b7f97d1
# ╠═197ea13f-b460-4457-a2ad-ae8d63c5e5ea
# ╠═17c48342-f684-4149-b1ea-b626896a4691
# ╠═67c9334e-1155-4ef3-8d75-030dcfc1e570
# ╠═3b94a9a8-93c8-4e46-ae23-63374d368b16
# ╠═0808a99f-1f55-4b0a-81e9-3f511c9f55d5
