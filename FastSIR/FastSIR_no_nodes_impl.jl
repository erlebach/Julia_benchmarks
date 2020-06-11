module FastSIRNoNodes

using LightGraphs
import Random: seed!
using Distributions
using DataStructures

# ERROR related to conversion of somekind: Float64 to :Symbol

#***********************************

# Implementation without nodes to decrease the total number of
# allocations. Code becomes less readable.
# Events are lighter now: they only contain the node index, an action and a time.

# Consumes too much memory. No longer needed
#=
mutable struct Node
    index::Int  # :S, :I, :R
    status::Symbol  # :S, :I, :R
    pred_inf_time::Float64
    rec_time::Float64
    #Node(index::Int, status::Symbol, pred_inf_time::Float64, rec_time::Float64) =
        #new(index, status, pred_inf_time, rec_time)
end
=#

# Make sure Basic is in the path. Consider LOAD_PATH
#import Basic: copy
#function Base.copy(node::Node)
    #Node(node.index, node.status, node.pred_inf_time, node.rec_time)
#end

# I cannot set fields if immutable
mutable struct Event
    index::Int  # graph node index
	time::Float64
    action::Symbol # :recover, :transmit
end
mutable struct Event1
    index::Int  # graph node index
	time::Float64
    action::Symbol # :recover, :transmit
    action2::Symbol # :recover, :transmit
end

mutable struct Event4
	index::Int
end

function fastSIR(G, params, initial_infecteds::Vector{Int})
	τ = params.τ
	γ = params.γ
	expo_γ = Exponential(γ) # type Distribution::Exp
	expo_τ = Exponential(τ)
	t_max = params.t_max  # mandatory
	infinite_time = 1.e8

    nb_nodes = nv(G)

	# Node data
	status = fill(:S, nb_nodes)
	pred_inf_time = fill(infinite_time, nb_nodes)
	rec_time = zeros(nb_nodes)
    times = [0.]

    # length(G) is Int128
    S = [nb_nodes]
    I = [0]
    R = [0]

	# empty queue
    Q = PriorityQueue(Base.Order.Forward);

	# prestore one F.Node for each graph vertex
    #nodes = Array{Node,1}(undef, nb_nodes)

    #for u in 1:nb_nodes  # extremely fast
        #nodes[u] = Node(u, :S, pred_inf_time, rec_time)
    #end

	# REMOVE
	#println(">>> about to test")
	#testTimings(G, nodes[4])  # EXPERIMENTAL. JUST FOR TESTING REMOVE WHEN DONE
	#println("END TEST TIMINGS")
	# REMOVE

    for u in initial_infecteds
       #println("nodes[u]= ", nodes[u])
       #event = Event(nodes[u], 0., :transmit)
       event = Event(u, 0., :transmit)
       # How to do this with immutable structure
       pred_inf_time[u] = 0.0  # should this new time be reflectd in the event? Here, it is.
       #nodes[u].pred_inf_time = 0.0  # should this new time be reflectd in the event? Here, it is.
       Q[event] = event.time
    end

    while !isempty(Q)
        event = dequeue!(Q)
        if event.action == :transmit
            if status[event.index] == :S
            #if event.node.status == :S
                # 12 allocations, 224 bytes
                #@time processTransSIR(G, event.node, event.time, τ, γ, times,
                processTransSIR(G, event.index, rec_time, status, pred_inf_time, event.time, τ, γ, times,
					S, I, R, Q, t_max, expo_τ, expo_γ)
				#println("completed processTransSIR\n")
            end
		else
             # 1 alloc: 16 bytes, 0.000001 to 0.000002 seconds
             processRecSIR(status, event.index, event.time, times, S, I, R)
			 #println("completed processRecSIR\n")
             #processRecSIR(event.node, event.time, times, S, I, R)
        end
    end
	println("Inside Implemention with no Nodes")
	println("times, times[end]: $(length(times)), $(times[end])")
    times, S, I, R
end;

function testTimings(G, node_u)
	println("\nEnter testTimings")
	a = Array{Int,1}()
	# 115 alloc
	for ν in neighbors(G, node_u.index)
		push!(a, ν)
		#@time findTransSIR(Q, t, τ, node_u, nodes[ν], t_max, nodes, expo_τ)
	end
	println("after testTimings loop\n")
end

#function processTransSIR(G, node_u, t::Float64, τ::Float64, γ::Float64,
function processTransSIR(G, u, rec_time, status, pred_inf_time, t::Float64, τ::Float64, γ::Float64,
        times::Vector{Float64}, S::Vector{Int}, I::Vector{Int}, R::Vector{Int},
		Q, t_max::Float64, expo_τ, expo_γ)
		#Q, t_max::Float64, nodes::Vector{Node}, expo_τ, expo_γ)
    if (S[end] <= 0)
		println("S=$(S[end]), (ERROR!!! S cannot be zero at this point")
	end
	#node_u.status = :I
	status[u] = :I
    push!(times, t)
    push!(S, S[end]-1)
    push!(I, I[end]+1)
    push!(R, R[end])
	#node_u.rec_time = t + rand(Exponential(γ))
	#node_u.rec_time = t + rand(expo_γ)
	rec_time[u] = t + rand(expo_γ)

	if rec_time[u] < t_max
		#@time new_event = Event(node_u, node_u.rec_time, :recover)
		new_event = Event(u, rec_time[u], :recover)
		#println("after Event\n")
		Q[new_event] = new_event.time
		#println("after Q\n")
	end

	#println("\nbefore  2nd neighbor loop, testTimings")
	#testTimings(G, nodes[4])  # EXPERIMENTAL. JUST FOR TESTING REMOVE WHEN DONE

	for ν in neighbors(G, u)
		findTransSIR(Q, t, τ, rec_time, pred_inf_time, status, u, ν, t_max, expo_τ)
		#println("after findTransSIR (within neighbor loop)\n")
	end
	#println("after neighbors\n")

	#testTimings(G, nodes[4])  # EXPERIMENTAL. JUST FOR TESTING REMOVE WHEN DONE
	#println("after  2nd neighbor loop, testTimings\n")
end


function findTransSIR(Q, t, τ, rec_time, pred_inf_time, status, sid, tid, t_max, expo_τ)
	if status[tid] == :S
		#inf_time = t + rand(Exponential(τ))
		inf_time = t + rand(expo_τ)
		#print("inf_time")
		# Allocate memory for this list
		if inf_time < minimum([rec_time[sid], pred_inf_time[tid], t_max])
		#if inf_time < minimum([source.rec_time, target.pred_inf_time, t_max])
			new_event = Event(tid, inf_time, :transmit)
			Q[new_event] = new_event.time
			pred_inf_time[tid] = inf_time
		end
	end
end

function processRecSIR(status, u, t, times, S, I, R)
	push!(times, t)
	push!(S, S[end])
	push!(I, I[end]-1)
	push!(R, R[end]+1)
	status[u] = :R
end

function simulate(G, params, infected)
	#global γ, τ
	times, S, I, R = fastSIR(G, params, infected)
	return times, S, I, R
end

end
