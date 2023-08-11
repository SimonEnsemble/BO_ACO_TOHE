### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ d493a41c-3879-11ee-32aa-052ae56d5240
begin
	import Pkg; Pkg.activate()
	push!(LOAD_PATH, joinpath("..", "src"))

	using Revise
	using MOACOTOP, Graphs, MetaGraphs, Random, Test
end

# ╔═╡ 2d6e9814-74e5-4e07-9980-b3f6c06863e9
md"# testing

test with a manually-constructed TOP.

edges are either low- or high-risk.

nodes are either high- or low-reward.
"

# ╔═╡ 305a8d3c-98c8-4ca2-baa8-24cbd1f74178
begin
	# risks
	ω =  Dict("lo" => 0.8, "hi" => 0.2)
	
	# rewards
	r = Dict("hi" => 15.0, "lo" => 10.0)
end

# ╔═╡ 10219d1e-6927-4618-8f02-bb08721587e0
function generate_manual_top(ω, r)
	g = MetaGraph(SimpleGraph(11))
	# add edges
	edge_list = [
		# branch
		(1, 9, ω["lo"]),
		# branch
		(1, 10, ω["hi"]),
		(10, 11, ω["hi"]),
		# cycle
		(1, 8, ω["lo"]),
		(8, 7, ω["lo"]),
		(7, 6, ω["hi"]),
		(6, 4, ω["hi"]),
		(4, 3, ω["hi"]),
		(3, 2, ω["lo"]),
		(2, 1, ω["lo"]),
		# bridge off cycle
		(4, 5, 1.0),
		# shortcut in cycle
		(7, 3, ω["lo"]),
	]
	for (i, j, ω) in edge_list
		add_edge!(g, i, j, :ω, ω)
	end
	# assign nodes rewards
	rewards = Dict(
		1  => r["lo"], 
		10 => r["hi"], 
		11 => r["hi"], 
		9  => r["lo"], 
		2  => r["hi"], 
		3  => r["lo"], 
		7  => r["lo"], 
		8  => r["lo"], 
		6  => r["lo"], 
		4  => r["hi"], 
		5  => r["hi"]
	)

	for v = 1:nv(g)
		set_prop!(g, v, :r, rewards[v])
	end
	
	return TOP(nv(g), g, 2)
end

# ╔═╡ d1349d2b-4956-4d42-a93f-7f666f2444d2
top = generate_manual_top(ω, r)

# ╔═╡ 118d65bb-ea24-42a5-ab0a-f2bb6a32d098
begin
	robot = Robot(top)
	hop_to!(robot, 2, top)
	hop_to!(robot, 3, top)
	hop_to!(robot, 7, top)
	hop_to!(robot, 6, top)
	alt_robot = Robot([1, 2, 3, 7, 6], top)
	@test robot.trail == alt_robot.trail
	verify(alt_robot, top)
	verify(robot, top)
end

# ╔═╡ 69d091d8-c8fa-48cd-9d1d-1750e604ec55
viz_setup(top, robots=[robot])

# ╔═╡ cae311a4-0c0d-42ef-a599-63c84943c6b3
md"## test probability model"

# ╔═╡ e4212d0f-fb28-40a2-83c3-43db5c2cd94b
# traverses 3 lo-risk, 1 hi-risk
@test π_robot_survives(robot.trail, top) ≈ ω["lo"] ^ 3 * ω["hi"]

# ╔═╡ 31731f25-e2d3-47b5-bcf0-e284de56e36e
@test 𝔼_nb_robots_survive([robot], top) ≈ π_robot_survives(robot.trail, top)

# ╔═╡ ddab2b7f-ffdf-478a-8d03-31c38ba1eb39
@test π_robot_visits_node_j(robot, 2, top) ≈ ω["lo"] 

# ╔═╡ 584e4cb3-fe1f-4d69-aa7e-fff6fa29a906
@test π_robot_visits_node_j(robot, 3, top) ≈ ω["lo"] ^ 2

# ╔═╡ 8fd64509-25a7-4126-b97d-63aeeb47a971
@test π_robot_visits_node_j(robot, 7, top) ≈ ω["lo"] ^ 3

# ╔═╡ c5ffab03-7c6f-4da7-b47e-0a8cd1c64fd3
@test π_robot_visits_node_j(robot, 6, top) ≈ π_robot_survives(robot.trail, top)

# ╔═╡ c08a26c8-a11d-4165-b73c-b1916f37e894
@test 𝔼_reward([robot], top) ≈ 
	# dies hopping to 2 (collects only node 1 reward)
	(1 - ω["lo"]) * r["lo"]  + 
	# dies hopping to 3 (surives hop to 2 first). collect reward at 1 and 2
	ω["lo"] * (1 - ω["lo"]) * (r["lo"] + r["hi"]) + 
	# dies hopping to 7.
	ω["lo"] ^ 2 * (1 - ω["lo"]) * (2 * r["lo"] + r["hi"]) + 
	# dies hopping to 6
	ω["lo"] ^ 3 * (1 - ω["hi"]) * (3 * r["lo"] + r["hi"]) + 
	# survives all
	π_robot_survives(robot.trail, top) * (4 * r["lo"] + r["hi"])

# ╔═╡ a46e2c9a-0d18-4501-89f1-f48cbca6112c
begin
	nodes_not_visisted = [10, 11, 9, 8, 4, 5]
	for j in nodes_not_visisted
		@test π_robot_visits_node_j(robot, j, top) == 0.0
	end
end

# ╔═╡ 697915c7-ccfb-4d47-ab7f-5e5046ede84a
md"## test utils"

# ╔═╡ 774f4cba-73d6-4568-ac14-6829439a0a37
begin
	robots = [
		Robot([1, 2, 3, 7, 6], top),
		Robot([1, 2], top)
	]
	other_robots = [
		Robot([1, 2, 3, 7, 6], top),
		Robot([1], top)
	]
	@test same_trail_set(robots, reverse(robots))
	@test ! same_trail_set(robots, other_robots)
end

# ╔═╡ f528d140-9115-4a27-b1f8-30ddcb86f2d8


# ╔═╡ Cell order:
# ╠═d493a41c-3879-11ee-32aa-052ae56d5240
# ╟─2d6e9814-74e5-4e07-9980-b3f6c06863e9
# ╠═305a8d3c-98c8-4ca2-baa8-24cbd1f74178
# ╠═10219d1e-6927-4618-8f02-bb08721587e0
# ╠═d1349d2b-4956-4d42-a93f-7f666f2444d2
# ╠═118d65bb-ea24-42a5-ab0a-f2bb6a32d098
# ╠═69d091d8-c8fa-48cd-9d1d-1750e604ec55
# ╟─cae311a4-0c0d-42ef-a599-63c84943c6b3
# ╠═e4212d0f-fb28-40a2-83c3-43db5c2cd94b
# ╠═31731f25-e2d3-47b5-bcf0-e284de56e36e
# ╠═ddab2b7f-ffdf-478a-8d03-31c38ba1eb39
# ╠═584e4cb3-fe1f-4d69-aa7e-fff6fa29a906
# ╠═8fd64509-25a7-4126-b97d-63aeeb47a971
# ╠═c5ffab03-7c6f-4da7-b47e-0a8cd1c64fd3
# ╠═c08a26c8-a11d-4165-b73c-b1916f37e894
# ╠═a46e2c9a-0d18-4501-89f1-f48cbca6112c
# ╟─697915c7-ccfb-4d47-ab7f-5e5046ede84a
# ╠═774f4cba-73d6-4568-ac14-6829439a0a37
# ╠═f528d140-9115-4a27-b1f8-30ddcb86f2d8
