### A Pluto.jl notebook ###
# v0.19.40

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

# ╔═╡ bda53ee3-555e-48cc-8e74-578032368650


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

# ╔═╡ b9a9808e-8631-45e1-9e31-516565c804a3
nb_iters = 100

# ╔═╡ 74459833-f3e5-4b13-b838-380c007c86ed
md"### 🐜"

# ╔═╡ a8e27a0e-89da-4206-a7e2-94f796cac8b4
@time res = mo_aco(
	top, 
	verbose=false, 
	nb_ants=100, 
	nb_iters=nb_iters,
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
	nb_iters=nb_iters,
	consider_previous_robots=true,
	use_heuristic=true,
	use_pheremone=false,
)

# ╔═╡ 3b94a9a8-93c8-4e46-ae23-63374d368b16
res_pheremone_only = mo_aco(
	top, 
	verbose=false, 
	nb_ants=100, 
	nb_iters=nb_iters,
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

# ╔═╡ a60a74bc-ce8f-4711-bffc-61b108b97cff
md"## toy problem for Fig. 1
"

# ╔═╡ 7ac39f58-729b-45ca-8b7f-9028d3f53810
toy_top = toy_problem()

# ╔═╡ b17cb22b-346c-4328-883e-b7bf3578f229
md"visualize the problem setup. manual layout to match what I drew in Adobe Illustrator."

# ╔═╡ 279f2d91-8da2-4cd0-9e0f-e9fcea96ba0e
begin
	scale_factor = 100.0
	toy_layout = Spring(iterations=250, C=2.0, 
		pin=Dict(
			1=>[111, -240]./scale_factor,
			2=>[320, -68]./scale_factor,
			3=>[320, -352]./scale_factor,
			4=>[569, -183]./scale_factor,
			5=>[810, -54]./scale_factor
		)
	)(toy_top.g)
end

# ╔═╡ c25acc19-8475-40fd-bef8-522e848a4ea6
viz_setup(toy_top, radius=0.3, layout=toy_layout)

# ╔═╡ 84f19f64-bc92-4d08-9d5a-14d5668c34cb
md"find Pareto-optimal solutions"

# ╔═╡ 466457f1-04a1-453b-aa16-1e8f53a3ce5b
toy_res = mo_aco(
	toy_top, 
	verbose=false, 
	nb_ants=100, 
	nb_iters=2000,
	consider_previous_robots=true,
	use_heuristic=true,
	use_pheremone=true,
)

# ╔═╡ 4907dfa8-c40a-41c1-873b-f241b7f6da99
viz_progress(toy_res)

# ╔═╡ 2df0e4be-c832-4aa8-ba82-036d9262a564
@bind toy_soln_id PlutoUI.Slider(1:length(toy_res.global_pareto_solns), show_value=true)

# ╔═╡ 157a43e6-3026-4173-9b4f-1b942d1eab0f
viz_soln(toy_res.global_pareto_solns[toy_soln_id], toy_top, show_𝔼=false)

# ╔═╡ 76ea8409-64ca-4e54-b0d8-653cd878929e
md"would like to see some Pareto-dominated solutions too."

# ╔═╡ ce7a63a0-bf48-472b-9396-0c510d8320dc
random_toy_solns = [
	construct_soln(
		Ant(rand()), 
		Pheremone(toy_top), 
		toy_top
	) for i = 1:250
]

# ╔═╡ d8925e73-3fe6-48c5-975e-4a9985c8306d
sort!(random_toy_solns, by=s -> s.objs.r)

# ╔═╡ 32fb4b0b-67be-44d2-9cc1-9aa9a97a858f
all_toy_solns = vcat(toy_res.global_pareto_solns, random_toy_solns)

# ╔═╡ 37b0fde6-3b0e-471e-90d2-b7cf2d533d1e
@bind id_toy_all PlutoUI.Slider(1:length(all_toy_solns), show_value=true)

# ╔═╡ fdc9990c-163d-4fca-bd1f-2b7eba3c741c
viz_Pareto_front(all_toy_solns, id_hl=id_toy_all)

# ╔═╡ 840bcd72-a885-41bc-9eb7-77ca77e37684
viz_soln(all_toy_solns[id_toy_all], toy_top, show_𝔼=false, show_robots=false)

# ╔═╡ 1cd2f793-f0ff-4ae1-a363-99f4f1e7b934
md"finally, hand-select some solutions to present for intuition"

# ╔═╡ 6f159833-58b7-4e04-b893-b8ca1b82c9cd
solns_to_present = [3, 7, 16, 42]

# ╔═╡ dab36455-6614-4f86-aac3-3472c9cade6e
function select_toy_solutions()
	# stay put
	robots = [
		Robot([1, 1], toy_top), 
		Robot([1, 1], toy_top)
	]
	solns = [Soln(robots, toy_top)]
	
	# Pareto-optimal soln #1
	robots = [
		Robot([1, 1], toy_top), 
		Robot([1, 3, 2, 4, 2, 3, 1], toy_top)
	]
	push!(solns, Soln(robots, toy_top))

	# Pareto-optimal soln #2
	robots = [
		Robot([1, 3, 2, 4, 5, 4, 2, 3, 1], toy_top),
		Robot([1, 3, 2, 4, 2, 3, 1], toy_top)
	]
	push!(solns, Soln(robots, toy_top))

	# non-optimal solution
	robots = [
		Robot([1, 2, 1], toy_top), 
		Robot([1, 2, 3, 4, 2, 1, 1], toy_top)
	]
	push!(solns, Soln(robots, toy_top))

	return solns
end

# ╔═╡ 8341da6a-0756-4b24-aa92-f6c4068cdd42
toy_solns_to_show = select_toy_solutions()

# ╔═╡ 7b6a097f-8cac-4370-a09d-38f156edfbda
viz_Pareto_front(toy_solns_to_show, resolution=(300, 300), upper_xlim=10, savename="toy_Pareto_front")

# ╔═╡ 61efbac2-2c41-4adb-8fb3-5e94efc2367d
md"visualize the robot trails."

# ╔═╡ 67518659-c654-4fea-9878-a9585c77474a
viz_robot_trail(toy_top, toy_solns_to_show[4].robots, 1, layout=toy_layout, underlying_graph=true)

# ╔═╡ 25322609-8f3a-4fd6-bd9e-4010718af529
viz_robot_trail(toy_top, [Robot(toy_top)], 1, layout=toy_layout, underlying_graph=true, savename=joinpath("toy_solns", "underlying_graph"))

# ╔═╡ 0bc62c67-9d8d-4952-94d7-ce95ccfeeaac
toy_top.g

# ╔═╡ de3274c8-b7f8-43b0-8a90-9e3ef654e95e
if ! isdir("toy_solns")
	mkdir("toy_solns")
end

# ╔═╡ a0faa901-f8ef-4b75-869b-2f3285d79076
for (i, s) in enumerate(toy_solns_to_show)
	for r = 1:2
		viz_robot_trail(toy_top, s.robots, r, layout=toy_layout, savename=joinpath("toy_solns", "soln_$(i)_robot_trail_$(r)"))
	end
end

# ╔═╡ 0a8dec0e-e107-4c10-a36e-c0a1c922c265
viz_robot_trail(toy_top, [Robot(toy_top), Robot(toy_top), Robot([1, 3, 4, 2, 3, 1], toy_top)], 3, layout=toy_layout, underlying_graph=true, savename=joinpath("toy_solns", "for_notation"))

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╠═bdb5d550-13f6-4d8d-9a74-14b889efe7a2
# ╟─47eeb310-04aa-40a6-8459-e3178facc83e
# ╠═fcf3cd41-beaa-42d5-a0d4-b77ad4334dd8
# ╠═bda53ee3-555e-48cc-8e74-578032368650
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
# ╠═b9a9808e-8631-45e1-9e31-516565c804a3
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
# ╟─a60a74bc-ce8f-4711-bffc-61b108b97cff
# ╠═7ac39f58-729b-45ca-8b7f-9028d3f53810
# ╟─b17cb22b-346c-4328-883e-b7bf3578f229
# ╠═279f2d91-8da2-4cd0-9e0f-e9fcea96ba0e
# ╠═c25acc19-8475-40fd-bef8-522e848a4ea6
# ╟─84f19f64-bc92-4d08-9d5a-14d5668c34cb
# ╠═466457f1-04a1-453b-aa16-1e8f53a3ce5b
# ╠═4907dfa8-c40a-41c1-873b-f241b7f6da99
# ╟─2df0e4be-c832-4aa8-ba82-036d9262a564
# ╠═157a43e6-3026-4173-9b4f-1b942d1eab0f
# ╟─76ea8409-64ca-4e54-b0d8-653cd878929e
# ╠═ce7a63a0-bf48-472b-9396-0c510d8320dc
# ╠═d8925e73-3fe6-48c5-975e-4a9985c8306d
# ╠═32fb4b0b-67be-44d2-9cc1-9aa9a97a858f
# ╠═37b0fde6-3b0e-471e-90d2-b7cf2d533d1e
# ╠═fdc9990c-163d-4fca-bd1f-2b7eba3c741c
# ╠═840bcd72-a885-41bc-9eb7-77ca77e37684
# ╟─1cd2f793-f0ff-4ae1-a363-99f4f1e7b934
# ╠═6f159833-58b7-4e04-b893-b8ca1b82c9cd
# ╠═dab36455-6614-4f86-aac3-3472c9cade6e
# ╠═8341da6a-0756-4b24-aa92-f6c4068cdd42
# ╠═7b6a097f-8cac-4370-a09d-38f156edfbda
# ╟─61efbac2-2c41-4adb-8fb3-5e94efc2367d
# ╠═67518659-c654-4fea-9878-a9585c77474a
# ╠═25322609-8f3a-4fd6-bd9e-4010718af529
# ╠═0bc62c67-9d8d-4952-94d7-ce95ccfeeaac
# ╠═de3274c8-b7f8-43b0-8a90-9e3ef654e95e
# ╠═a0faa901-f8ef-4b75-869b-2f3285d79076
# ╠═0a8dec0e-e107-4c10-a36e-c0a1c922c265
