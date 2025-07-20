# note: [1, 1]
# and [1, x, 1, 1] are annoying cases for insert.


# try trail modification (u, w) -> (u, v, u, w)
function _attempt_node_grab!(robot::Robot, top::TOP; verbose::Bool=false)
    # after wut node to insert?
    if robot.trail == [1, 1]
        i = 1
    else
        # 1, x₁, ..., xₙ, 1, 1 length = n + 3
        i = rand(1:(length(robot.trail)-2)) # first, last, second-to-last are depot
    end
    
    u = robot.trail[i]
    w = robot.trail[i+1]
    
    candidate_vs = Int[]
    for v = 2:top.nb_nodes
        if has_edge(top.g, u, v) && has_edge(top.g, v, u) && (! robot.edge_visit[u, v]) && (! robot.edge_visit[v, u])
            push!(candidate_vs, v)
        end
    end
    
    if length(candidate_vs) == 0
        return false
    end

    # pick a node to insert
    v = rand(candidate_vs)

    if verbose
        println("\tnode grab: ($u, $w) -> ($u, $v, $u, $w)")
    end

    # rewire!
    insert!(robot.trail, i+1, v)
    insert!(robot.trail, i+2, u)
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, u] = true

    return true
end

# try trail modification (u, w) -> (u, v, w)
function _attempt_node_insertion!(robot::Robot, top::TOP; verbose::Bool=false)
    # after wut node to insert?
    if robot.trail == [1, 1]
        i = 1
    else
        # 1, x₁, ..., xₙ, 1, 1 length = n + 3
        i = rand(1:(length(robot.trail)-2)) # first, last, second-to-last are depot
    end
    
    # proposal: (u, w) -> (u, v, w)
    u = robot.trail[i]
    w = robot.trail[i+1]

    candidate_vs = Int[]
    for v = 2:top.nb_nodes
        if has_edge(top.g, u, v) && has_edge(top.g, v, w) && (! robot.edge_visit[u, v]) && (! robot.edge_visit[v, w])
            push!(candidate_vs, v)
        end
    end
    
    # no nodes left to insert?
    if length(candidate_vs) == 0
        return false
    end

    # pick a node to insert
    v = rand(candidate_vs)
    
    if verbose
        println("\tinsertion: ($u, $w) -> ($u, $v, $w)")
    end

    # rewire!
    insert!(robot.trail, i+1, v)
    robot.edge_visit[u, w] = false # turn off old edge
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, w] = true

    if length(robot.trail) == 3
        push!(robot.trail, 1) # gotta be (1, 1) -> (1, v, 1, 1)
        @assert u == w == 1
        robot.edge_visit[1, 1] = true
    end

    return true
end

# try trail modification (u, v, w) -> (u, w) i.e. delete v
function _attempt_node_deletion!(robot::Robot, top::TOP; verbose::Bool=false)
    # too short for a deletion?
    if length(robot.trail) == 2
        return false
    end

    # wut node to delete?
    i = rand(2:(length(robot.trail)-2)) # first, last, second-to-last are depot
    v = robot.trail[i]

    # proposal: (u, v, w) -> (u, w)
    u = robot.trail[i-1]
    w = robot.trail[i+1]

    if u == w
        # def can delete v.
        robot.edge_visit[u, v] = false # turn off old edge
        robot.edge_visit[v, w] = false # turn off old edge
        
        deleteat!(robot.trail, i)
        deleteat!(robot.trail, i) # (u, v, u) -> (u)
        return true
    end

    if (! has_edge(top.g, u, w)) || robot.edge_visit[u, w]
        return false
    end

    if verbose
        println("\tdeletion: ($u, $v, $w) -> ($u, $w)")
    end

    # rewire!
    deleteat!(robot.trail, i)
    robot.edge_visit[u, v] = false # turn off old edge
    robot.edge_visit[v, w] = false # turn off old edge
    robot.edge_visit[u, w] = true

    return true
end

# try trail modification (u, v, w) -> (u, x, w)
function _attempt_node_substitution!(robot::Robot, top::TOP; verbose::Bool=false)
    # too short for a substitution?
    if length(robot.trail) ≤ 3
        return false
    end

    # wut node to subs for another?
    i = rand(2:(length(robot.trail)-2)) # first, last, second-to-last are depot
    v = robot.trail[i]

    u = robot.trail[i-1]
    w = robot.trail[i+1]
    
    candidate_xs = Int[]
    for x = 2:top.nb_nodes
        if has_edge(top.g, u, x) && has_edge(top.g, x, w) && (! robot.edge_visit[u, x]) && (! robot.edge_visit[x, w])
            push!(candidate_xs, x)
        end
    end

    if length(candidate_xs) == 0
        return false
    end

    x = rand(candidate_xs)

    if verbose
        println("\tnode subs ($u, $v, $w) -> ($u, $x, $w)")
    end
    
    robot.trail[i] = x
    
    # rewire
    robot.edge_visit[u, v] = false # turn off old edge
    robot.edge_visit[v, w] = false # turn off old edge
    robot.edge_visit[u, x] = true
    robot.edge_visit[x, w] = true

    return true
end

# try trail modification (u, v, w) and (x, y, z) -> (u, y, w) and (x, v, z)
function _attempt_node_swap!(robot::Robot, top::TOP; verbose::Bool=false)
    # too short for a swap?
    if length(robot.trail) ≤ 5
        return false
    end

    # sample two non-depot nodes to swap
    i, j = sample(2:(length(robot.trail)-2), 2, replace=false) # positions
    v = robot.trail[i]
    y = robot.trail[j]

    u = robot.trail[i-1]
    w = robot.trail[i+1]
    
    x = robot.trail[j-1]
    z = robot.trail[j+1]

    # is the swap possible?
    for (s, d) in [(u, y), (y, w), (x, v), (v, z)]
        # deal-breaker: no edge in graph or it has been used
        if (! has_edge(top.g, s, d)) || robot.edge_visit[s, d]
            return false
        end
    end
    
    if verbose
        println("\tnode swap ($u, $v, $w) and ($x, $y, $z) -> ($u, $y, $w) and ($x, $v, $z)")
    end

    # swap possible if got here
    robot.trail[i] = y
    robot.trail[j] = v
    
    # rewire (turn off old edges and add new
    robot.edge_visit[u, v] = false
    robot.edge_visit[v, w] = false
    robot.edge_visit[x, y] = false
    robot.edge_visit[y, z] = false
    
    robot.edge_visit[u, y] = true
    robot.edge_visit[y, w] = true
    robot.edge_visit[x, v] = true
    robot.edge_visit[v, z] = true

    return true
end

function perturb_trail(
    robot::Robot, top::TOP; verbose::Bool=false
)
    # create copy of trail (will not necessarily accept perturbation)
    @assert robot.done
    new_robot = deepcopy(robot)
    
    # current number of non-depot-node visits
    n = length(robot.trail) - 3 # 3 are 1's cuz complete trail
        
    trail_perturbations = [:swap, :insert, :delete, :substitute, :grab]

    perturbation = sample(trail_perturbations)
    
    if perturbation == :insert
        success = _attempt_node_insertion!(new_robot, top, verbose=verbose)
    elseif perturbation == :grab
        success = _attempt_node_grab!(new_robot, top, verbose=verbose)
    elseif perturbation == :swap
        success = _attempt_node_swap!(new_robot, top, verbose=verbose)
    elseif perturbation == :delete
        success = _attempt_node_deletion!(new_robot, top, verbose=verbose)
    elseif perturbation == :substitute
        success = _attempt_node_substitution!(new_robot, top, verbose=verbose)
    end

    if ! success
        return perturb_trail(robot, top, verbose=verbose)
    end
   
    if verbose
        println("\tnew trail: ", new_robot.trail)
    end
    verify(new_robot, top)

    return new_robot, perturbation
end
