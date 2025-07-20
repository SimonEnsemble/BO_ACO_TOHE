# try trail modification (u, w) -> (u, v, u, w)
function _attempt_node_grab!(robot::Robot, top::TOP)
    # after wut node to insert?
    i = rand(1:(length(robot.trail)-2)) # first, last, second-to-last are depot
    
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

    # rewire!
    insert!(robot.trail, i+1, v)
    insert!(robot.trail, i+2, u)
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, u] = true

    return true
end

# try trail modification (u, w) -> (u, v, w)
function _attempt_node_insertion!(robot::Robot, top::TOP)
    # after wut node to insert?
    i = rand(1:(length(robot.trail)-2)) # first, last, second-to-last are depot
    
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

    # rewire!
    insert!(robot.trail, i+1, v)
    robot.edge_visit[u, w] = false # turn off old edge
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, w] = true

    return true
end

# try trail modification (u, v, w) -> (u, w) i.e. delete v
function _attempt_node_deletion!(robot::Robot, top::TOP)
    # too short for a deletion?
    if length(robot.trail) ≤ 3
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
        deleteat!(robot.trail, i)
        deleteat!(robot.trail, i) # (u, v, u) -> (u)
        robot.edge_visit[u, v] = false # turn off old edge
        robot.edge_visit[v, w] = false # turn off old edge
    end

    if (! has_edge(top.g, u, w)) || robot.edge_visit[u, w]
        return false
    end

    # rewire!
    deleteat!(robot.trail, i)
    robot.edge_visit[u, v] = false # turn off old edge
    robot.edge_visit[v, w] = false # turn off old edge
    robot.edge_visit[u, w] = true

    return true
end

# try trail modification (u, v, w) -> (u, x, w)
function _attempt_node_substitution!(robot::Robot, top::TOP)
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
    
    robot.trail[i] = x
    
    # rewire
    robot.edge_visit[u, v] = false # turn off old edge
    robot.edge_visit[v, w] = false # turn off old edge
    robot.edge_visit[u, x] = true
    robot.edge_visit[x, w] = true

    return true
end

# try trail modification (u, v, w) and (x, y, z) -> (u, y, w) and (x, v, z)
function _attempt_node_swap!(robot::Robot, top::TOP)
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

function perturb_trail!(
    robot::Robot, top::TOP
)
    # create copy of trail (will not necessarily accept perturbation)
    @assert robot.done
    new_robot = deepcopy(robot)
    
    # current number of non-depot-node visits
    n = length(robot.trail) - 3 # 3 are 1's cuz complete trail
        
    trail_perturbations = [:swap, :insert, :delete, :substitute, :grab]

    perturbation = sample(trail_perturbations)
    
    if perturbation == :insert
        success = _attempt_node_insertion!(robot, top)
    elseif perturbation == :grab
        success = _attempt_node_grab!(robot, top)
    elseif perturbation == :swap
        success = _attempt_node_swap!(robot, top)
    elseif perturbation == :delete
        success = _attempt_node_deletion!(robot, top)
    elseif perturbation == :substitute
        success = _attempt_node_substitution!(robot, top)
    end

    if ! success
        return perturb_trail!(robot, top)
    end
    return perturbation
end
