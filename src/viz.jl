the_size = (500, 400)

"""
    trail_to_digraph(robot, top)

convert robot trail to a directed graph with same nodes as TOP.
"""
function trail_to_digraph(robot::Robot, top::TOP)
    g_trail = MetaDiGraph(nv(top.g))
    for n = 1:length(robot.trail) - 1
        # only add self-loop if it's just staying.
        if (robot.trail[n] == robot.trail[n+1] == 1) & (length(robot.trail) > 2)
            continue
        end
        add_edge!(g_trail, robot.trail[n], robot.trail[n+1])
        set_prop!(g_trail, robot.trail[n], robot.trail[n+1], :step, n)
    end
    return g_trail
end

#=
visualization of the Pareto set
=#
function _viz_objectives!(ax, solns::Vector{Soln}; label=nothing, markersize=14)
    scatter!(ax,
        [soln.objs.r for soln in solns],
        [soln.objs.s for soln in solns],
        label=label,
        markersize=markersize,
        strokewidth=1,
        strokecolor="black",
        color=Cycled(2)
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
    viz_Pareto_front(solns, id_hl=nothing, savename=nothing)
"""
function viz_Pareto_front(
        solns::Vector{Soln}; 
        ids_hl::Vector{Int}=Int[],
        savename::Union{Nothing, String}=nothing,
        size=the_size,
        upper_xlim=nothing,
        incl_legend::Bool=true
    )
    fig = Figure(size=size, backgroundcolor=:transparent)
    ax = Axis(
        fig[1, 1],
        xlabel="𝔼[team rewards]",
        ylabel="𝔼[# robots survive]"
    )
    xlims!(0, upper_xlim)
    ylims!(0, nothing)
    pareto_solns = get_pareto_solns(solns, false)
    _viz_area_indicator!(ax, pareto_solns)
    _viz_objectives!(ax, solns, markersize=5, label="dominated")
    _viz_objectives!(ax, pareto_solns, label="Pareto-optimal")
    if incl_legend
        axislegend(labelsize=12, framevisible=true, framecolor="lightgray")
    end
    if length(ids_hl) > 0
        scatter!(
            ax, [s.objs.r for s in solns[ids_hl]], [s.objs.s for s in solns[ids_hl]],
            color=Cycled(5), strokewidth=2
        )
    end
    if ! isnothing(savename)
        save(savename * ".pdf", fig)
    end
    fig
end

function _g_layout(top::TOP; C::Float64=2.0)
    _layout = Spring(iterations=250, C=C)
    return _layout(top.g)
end

#=
viz of the TOP setup and soln
=#
robot_colors = ColorSchemes.Accent_8

"""
    viz_setup(TOP; nlabels=true, robots=nothing, show_robots=true, robot_radius=1.0, C=2.0)

viz setup of the TOP.
"""
function viz_setup(
    top::TOP;
    nlabels::Bool=true,
    elabels::Bool=false,
    robots::Union{Nothing, Vector{Robot}}=nothing,
    show_robots::Bool=true,
    C::Float64=2.0,
    robot_radius::Float64=1.0,
    savename::Union{Nothing, String}=nothing,
    depict_ω::Bool=true,
    depict_r::Bool=true,
    layout::Union{Nothing, Vector{Point2{Float64}}}=nothing,
    pad::Float64=0.0,
    node_size::Int=25,
    show_colorbars::Bool=true
)   
    g = deepcopy(top.g)

    # assign node color based on rewards
    reward_color_scheme = ColorSchemes.nuuk
    rewards = [get_r(top, v) for v in vertices(g)]
    crangescale_r = (0.0, round(maximum(rewards), digits=1))
    if depict_r
        node_color = [get(reward_color_scheme, r, crangescale_r) for r in rewards]
    else
        node_color = ["white" for r in rewards]
    end

    # assign edge color based on probability of survival
    survival_color_scheme = reverse(ColorSchemes.amp)
    edge_surivival_probs = [get_ω(top, ed.src, ed.dst) for ed in edges(g)]
    crangescale_s = (floor(minimum(edge_surivival_probs), digits=1), 1.0)
    if depict_ω
        edge_color = [get(survival_color_scheme, p, crangescale_s) for p in edge_surivival_probs]
    else
        edge_color = ["gray" for p in edge_surivival_probs]
    end
    
    # graph layout
    if isnothing(layout)
        layout = _g_layout(top, C=C)
    end
    
    fig = Figure(backgroundcolor=:transparent)
    ax = Axis(fig[1, 1], aspect=DataAspect(), title=top.name)
    hidespines!(ax)
    hidedecorations!(ax)
    # plot trails as highlighted edges
    if ! isnothing(robots)
        for (r, robot) in enumerate(robots)
            g_trail = trail_to_digraph(robot, top)
            graphplot!(
                g_trail,
                layout=layout,
                elabels=elabels ? ["$(get_prop(r_trail, e, :step))" for e in edges(g_trail)] : nothing,
                elabels_fontsize=10,
                node_strokewidth=1,
                node_size=0,
                nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
                nlabels_color=node_color,
                nlabels_fontsize=9,
                nlabels_align=(:center, :center),
                color="black",
                edge_color=(robot_colors[r], 0.5),
                edge_width=8,
                curve_distance_usage=true,
                arrow_shift=:end
            )
        end
    end
    # plot graph with nodes and edges colored
    graphplot!(
        g,
        layout=layout,
        node_size=node_size,
        node_color=node_color,
        node_strokewidth=1,
        color="white",
        edge_color=edge_color,
        nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
        nlabels_color=:black,
        nlabels_fontsize=12,
        nlabels_align=(:center, :center),
        arrow_shift=:end
    )
    if show_robots
        # start node = 1
        for r = 1:top.nb_robots
            id_node_robots = 1
            if ! isnothing(robots) && length(robots) == top.nb_robots
                id_node_robots = robots[r].trail[end]
            end
            x = layout[id_node_robots][1]
            y = layout[id_node_robots][2]
            θ_shift = top.name in ["nuclear power plant", "synthetic (2 communities)"] ? π/2 : 0.0
            θ_multiple = top.name in ["nuclear power plant", "synthetic (2 communities)"] ? π : π/2
            θ = - θ_multiple * (r - 1) + θ_shift
            scatter!([x + robot_radius*cos(θ)], [y + robot_radius*sin(θ)],
                marker='✈',markersize=25, color=robot_colors[r])
        end
    end
    if depict_r && show_colorbars
        Colorbar(
            fig[1, 2],
            colormap=reward_color_scheme,
            vertical=true,
            label="reward",
            limits=crangescale_r,
            ticks=[0.0, crangescale_r[2]],
            height=Relative(3/5)
           )
    end
    if depict_ω && show_colorbars
        Colorbar(
            fig[1, depict_r ? 3 : 2],
            colormap=survival_color_scheme,
            vertical=true,
            label="survival probability",
            limits=crangescale_s,
            ticks=[crangescale_s[1], crangescale_s[2]],
            tellheight=true,
            height=Relative(3/5)
        )
    end
    
    pad!(ax, layout, pad=pad)

    if ! isnothing(savename)
        save(savename * ".pdf", fig)
    end
    fig
end

function pad!(ax, layout; pad=0.00)
    # add a margin
    if pad > 0.0
        for (i, lims!) in zip(1:2, [xlims!, ylims!])
            v0, v1 = minimum(map(x->x[i], layout)), maximum(map(x->x[i], layout)) # values
            r = v1 - v0 # range
            lims!(ax, v0 - pad * r, v1 + pad * r)
        end
    end
end

"""
    viz_robot_trail(top, robot)
"""
function viz_robot_trail(
    top::TOP,
    robots::Vector{Robot},
    robot_id::Int;
    layout::Union{Nothing, Vector{Point2{Float64}}}=nothing,
    size::Tuple{Int, Int}=the_size,
    pad::Float64=0.1,
    elabels::Bool=true,
    savename::Union{Nothing, String}=nothing,
    underlying_graph::Bool=true
)
    r_trail = trail_to_digraph(robots[robot_id], top)
    
    # graph layout
    if isnothing(layout)
        layout = _g_layout(top, C=2.0)
    end

    fig = Figure(size=size, backgroundcolor=:transparent)
    ax = Axis(fig[1, 1], aspect=DataAspect())
    hidespines!(ax)
    hidedecorations!(ax)
    if underlying_graph
        graphplot!(
                   top.g,
                   layout=layout,
                   node_size=40,
                   edge_color="black",
                   edge_width=3,
                   arrow_size=20,
                   curve_distance_usage=true,
        )
    end
	graphplot!(
                r_trail,
                layout=layout,
                elabels=elabels ? ["$(get_prop(r_trail, e, :step))" for e in edges(r_trail)] : nothing,
                elabels_fontsize=14,
                elabels_distance=12.0,
                arrow_size=20,
                node_strokewidth=3,
                nlabels_color="black",
                node_size=40,
                nlabels=["$v" for v in vertices(r_trail)],
                node_color="white", 
                nlabels_fontsize=20,
                nlabels_align=(:center, :center),
                color="black",
                edge_color=robot_colors[robot_id],
                edge_width=4,
                curve_distance_usage=true,
            )
    pad!(ax, layout, pad=pad)
    if ! isnothing(savename)
        save(savename * ".pdf", fig)
    end
    fig
end

"""
    viz_soln(soln, top; nlabels=false, savename=nothing, show_𝔼=true)

viz a proposed solution.
"""
function viz_soln(
    soln::Soln,
    top::TOP; 
    nlabels::Bool=false,
    elabels::Bool=false,
    only_first_elabel::Bool=false,
    savename::Union{Nothing, String}=nothing,
    robot_radius::Float64=0.2,
    show_𝔼::Bool=true,
    show_robots::Bool=true,
    layout=nothing
)
    g = top.g

    # graph layout
    if isnothing(layout)
        layout = _g_layout(top)
    end
    
    fig = Figure(size=(300 * top.nb_robots, 400), backgroundcolor=:transparent)
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
    for k = 1:top.nb_robots-1
        colgap!(fig.layout, k, Relative(-0.01))
    end
    @assert top.nb_robots == length(soln.robots)
    # sort robots by survivability
    ids_sp = sortperm([π_robot_survives(robot.trail, top) for robot in soln.robots])
    for r = 1:top.nb_robots
        robot = soln.robots[ids_sp[r]]
        # represent trail as a graph
        r_trail = trail_to_digraph(robot, top)

        # wut is survival prob of this robot?
        π_survive = π_robot_survives(robot.trail, top)
        axs[r].title = "π(robot $r survives)=$(round(π_survive, digits=2))"
        
        # plot graph with nodes and edges colored
        graphplot!(
            axs[r],
            g, 
            layout=layout,
            node_size=14, 
            node_color="black", 
            edge_color="lightgray",
            nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
            nlabels_color=:white,
            edge_width=1,
            nlabels_fontsize=9,
            arrow_shift=:end,
            nlabels_align=(:center, :center)
        )
        # plot trail of robot. unless self-loop.
        if robot.trail != [1, 1]
            if elabels
                the_elabels = ["$(get_prop(r_trail, e, :step))" for e in edges(r_trail)]
                if only_first_elabel
                    for (i, ed) in enumerate(edges(r_trail))
                        if ! ((ed.src == robot.trail[1]) && (ed.dst == robot.trail[2]))
                            the_elabels[i] = ""
                        end
                    end
                end
            else
                the_elabels = nothing
            end
            graphplot!(
                axs[r],
                r_trail, 
                layout=layout,
                elabels=the_elabels,
                elabels_fontsize=10,
                node_size=14, 
                node_color="black", 
                edge_color=robot_colors[r],
                edge_width=3,
                nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
                curve_distance_usage=true,
                nlabels_color=:white,
                nlabels_fontsize=9,
                arrow_shift=:end,
                nlabels_align=(:center, :center)
            )
        end

        if show_robots
            # start node = 1
            x = layout[1][1]
            y = layout[1][2]
            scatter!(axs[r], [x], [y - robot_radius], 
                marker='✈',markersize=20, color=robot_colors[r])
        end
    end
    if show_𝔼
        Label(
            fig[2, :], 
            "𝔼[R]=$(round(soln.objs.r, digits=2)); 𝔼[S]=$(round(soln.objs.s, digits=2))",
            font=firasans("Light")
        )
        rowgap!(fig.layout, 1, Relative(-0.3))
    end
    if ! isnothing(savename)
        save(savename * ".pdf", fig)
    end
    fig
end

function viz_pheremone(
    pheremone::Pheremone,
    top::TOP;
    nlabels::Bool=false,
    layout=nothing,
    savename::Union{Nothing, String}=nothing
)
    g = top.g

    # layout
    if isnothing(layout)
        layout = _g_layout(top)
    end

    τ_rs = [pheremone.τ_r[ed.src, ed.dst] for ed in edges(g)]
    τ_ss = [pheremone.τ_s[ed.src, ed.dst] for ed in edges(g)]

    edge_color = [
        [get(
            ColorSchemes.algae,
            pheremone.τ_r[ed.src, ed.dst],
            (minimum(τ_rs), maximum(τ_rs))
        )
            for ed in edges(g)],
        [get(
            ColorSchemes.amp,
            pheremone.τ_s[ed.src, ed.dst],
            (minimum(τ_ss), maximum(τ_ss))
        )
            for ed in edges(g)],
    ]

    fig = Figure(backgroundcolor=:transparent)
    axs = [Axis(fig[1, i], aspect=DataAspect()) for i = 1:2]
    rowsize!(fig.layout, 1, Relative(0.75))
    colgap!(fig.layout, 1, Relative(0.02))
    axs[1].title = rich("τ", subscript("R"))
    axs[2].title = rich("τ", subscript("S"))

    for i = 1:2
        graphplot!(axs[i],
            g,
            layout=layout,
            # node_size=35,
            node_color="gray",
            edge_color=edge_color[i],
            nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
            nlabels_align=(:center, :center)
        )
    end

    hidespines!.(axs)
    hidedecorations!.(axs)

    # histograms too
    axs_hist = [
        Axis(
            fig[2, i],
            ylabel="# arcs",
            xticks=LinearTicks(4)
        )
        for i = 1:2
    ]
    τ_s = [pheremone.τ_s[ed.src, ed.dst] for ed in edges(g)]
    τ_r = [pheremone.τ_r[ed.src, ed.dst] for ed in edges(g)]
    hist!(axs_hist[1], τ_r, color="green")
    hist!(axs_hist[2], τ_s, color="red")
    axs_hist[1].xlabel = rich("τ", subscript("R"))
    axs_hist[2].xlabel = rich("τ", subscript("S"))
    for ax_hist in axs_hist
        xlims!(ax_hist, 0.0, nothing)
        ylims!(ax_hist, 0.0, nothing)
    end
    rowgap!(fig.layout, 1, Relative(-0.2))
    if ! isnothing(savename)
        save(savename * ".pdf", fig)
    end
    return fig
end

"""
    viz_progress(aco_res)

view area indicator vs iteration.
"""
function viz_progress(res::MO_ACO_run; savename::String="", the_size::Tuple{Int, Int}=(500, 500))
    viz_progress([res], savename=savename, the_size=the_size)
end

function viz_progress(ress::Vector{MO_ACO_run}; savename::String="", the_size::Tuple{Int, Int}=(500, 500))
    fig = Figure(size=the_size)
    ax  = Axis(fig[1, 1], xlabel="iteration", ylabel="area indicator")
    for res in ress
            lines!(1:res.nb_iters, res.areas, linewidth=3)
    end
    xlims!(0, 1.02 * ress[1].nb_iters)
    if savename != ""
        save(savename * ".pdf", fig)
    end
    fig
end

"""
for simualted annealing
"""
function viz_agg_objectives(run::MO_SA_Run; savename::String="")
	colormap = ColorSchemes.:buda

	fig = Figure()

	# temp
	nb_iters_per_wᵣ = length(run.agg_objectives[1])
	ax_temp = Axis(fig[0, 1], ylabel="temperature")
	hidexdecorations!(ax_temp)
	iters = 1:nb_iters_per_wᵣ
	lines!(
        ax_temp, iters, [run.cooling_schedule.T₀ * run.cooling_schedule.α ^ (i-1) for i in iters],
		color=:black
	)

	# agg objs
	ax = Axis(
		fig[1, 1],
		xlabel="iteration",
		ylabel="normalized\naggregated\nobjective"
	)
	linkxaxes!(ax_temp, ax)
	for (i, (wᵣ, agg_obj)) in enumerate(zip(run.wᵣs, run.agg_objectives))
		lines!(agg_obj, color=get(colormap, wᵣ))
	end
	Colorbar(fig[1, 2], colormap=colormap, label="wᵣ")

    ylims!(ax, 0, 1)

	rowsize!(fig.layout, 0, Relative(0.3))

    if ! (savename == "")
        save(savename, fig)
    end

	fig
end

function viz_pheromone_graph_correlation(
	top::TOP, res::MO_ACO_run; savename::String=""
)
    τᵣs = [res.pheremone.τ_r[ed.src, ed.dst] for ed in edges(top.g)]
    τₛs = [res.pheremone.τ_s[ed.src, ed.dst] for ed in edges(top.g)]
	# reward of node edge is heading to
	rs = [get_r(top, ed.dst) for ed in edges(top.g)]
	# ω
	ωs = [get_ω(top, ed.src, ed.dst) for ed in edges(top.g)]

    fig = Figure(size=(700, 300))
    ax = Axis(
		fig[1, 1], xlabel="r(v′)", ylabel="τᵣ(v, v′)"
	)
    println("correlation: ", cor(rs, τᵣs))
    scatter!(ax, rs, τᵣs)

	ax2 = Axis(
		fig[1, 2], xlabel="ω(v, v′)", ylabel="τₛ(v, v′)"
	)
    scatter!(ax2, ωs, τₛs)
    println("correlation: ", cor(ωs, τₛs))

    if ! (savename == "")
        save(savename, fig)
    end
    fig
end

function viz_pheromone_correlation(top::TOP, res::MO_ACO_run; savename::String="")
	τᵣs = [res.pheremone.τ_r[ed.src, ed.dst] for ed in edges(top.g)]
	τₛs = [res.pheremone.τ_s[ed.src, ed.dst] for ed in edges(top.g)]

	τᵣ_range = range(0.0, maximum(τᵣs) * 1.05)

    println("correlation: ", cor(τᵣs, τₛs))

	# fit line
	coefficients = [ones(length(τᵣs)) τᵣs] \ τₛs

	fig = Figure()
	ax = Axis(fig[1, 1], xlabel="τᵣ", ylabel="τₛ")
	lines!(
		τᵣ_range, τᵣ_range * coefficients[2] .+ coefficients[1],
		color="gray", linestyle=:dash, label="linear fit"
	)
	scatter!(τᵣs, τₛs)
	axislegend(position=:rb)
    if ! (savename == "")
        save(savename, fig)
    end
	fig
end
