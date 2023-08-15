#=
visualization of the Pareto set
=#
function _viz_objectives!(ax, solns::Vector{Soln})
	scatter!(ax,
		[soln.objs.r for soln in solns],
		[soln.objs.s for soln in solns]
	)
end

function _viz_area_indicator!(ax, _pareto_solns::Vector{Soln})
    pareto_solns = sort(_pareto_solns, by=s -> s.objs.r)
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

"""
    viz_Pareto_front(solns)
"""
function viz_Pareto_front(solns::Vector{Soln})
	fig = Figure(resolution=the_resolution)
	ax = Axis(
		fig[1, 1],
		xlabel="𝔼(rewards)",
		ylabel="𝔼(# robots survive)"
	)
	xlims!(0, nothing)
	ylims!(0, nothing)
	_viz_objectives!(ax, solns)
	pareto_solns = get_pareto_solns(solns, false)
	_viz_area_indicator!(ax, pareto_solns)
	_viz_objectives!(ax, pareto_solns)
	fig
end

function _g_layout(top::TOP)
	_layout = Spring(iterations=250)
	return _layout(top.g)
end

#=
viz of the TOP setup and soln
=#
robot_colors = ColorSchemes.Accent_4

"""
    viz_setup(TOP; nlabels=true, robots=nothing, show_robots=true)

viz setup of the TOP.
"""
function viz_setup(
	top::TOP;
	nlabels::Bool=true,
	robots::Union{Nothing, Vector{Robot}}=nothing,
	show_robots::Bool=true
)   
    g = top.g

	# assign node color based on rewards
	reward_color_scheme = ColorSchemes.acton
    rewards = [get_r(top, v) for v in vertices(g)]
	crangescale = (0.0, round(maximum(rewards), digits=1))
	node_color = [get(reward_color_scheme, r, crangescale) for r in rewards]

	# assign edge color based on probability of survival
	survival_color_scheme = reverse(ColorSchemes.solar)
	edge_surivival_probs = [get_ω(top, ed.src, ed.dst) for ed in edges(g)]
	edge_color = [get(survival_color_scheme, p) for p in edge_surivival_probs]
    
    # graph layout
    layout = _g_layout(top)

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

"""
    viz_soln(soln, top; nlabels=false)

viz a proposed solution.
"""
function viz_soln(
	soln::Soln,
	top::TOP; 
	nlabels::Bool=false
)
	g = top.g
	robot_colors = ColorSchemes.Accent_4

	# graph layout
    layout = _g_layout(top)
	
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
    @assert top.nb_robots == length(soln.robots)
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
			# only add self-loop if it's just staying.
			if (robot.trail[n] == robot.trail[n+1] == 1) & (length(robot.trail) > 2)
				continue
			end
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
			marker='✈',markersize=20, color=robot_colors[r])
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

function viz_pheremone(
    pheremone::Pheremone,
    top::TOP;
	nlabels::Bool=false
)
	g_d = _covert_top_graph_to_digraph(top.g)

	# layout
	layout = _g_layout(top)

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
			edge_color=edge_color[i],
			nlabels=nlabels ? ["$v" for v in vertices(g_d)] : nothing,
			nlabels_align=(:center, :center)
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

"""
    viz_progress(aco_res)

view area indicator vs iteration.
"""
function viz_progress(res::MO_ACO_run)
	fig = Figure(resolution=the_resolution)
	ax  = Axis(fig[1, 1], xlabel="iteration", ylabel="area indicator")
	lines!(1:res.nb_iters, res.areas)
	fig
end
