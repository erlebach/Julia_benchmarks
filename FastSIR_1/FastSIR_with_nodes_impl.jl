module FastSIRWithNodes

using LightGraphs
import Random: seed!
using Distributions
using DataStructures

# Consumes too much memory
mutable struct Node
    index::Int32   # Int  # :S, :I, :R
    status::Int8   #Symbol  # :S, :I, :R
    pred_inf_time::Float32  #Float64
    rec_time::Float32  #Float64
    #Node(index::Int, status::Symbol, pred_inf_time::Float64, rec_time::Float64) =
        #new(index, status, pred_inf_time, rec_time)
end

# Make sure Basic is in the path. Consider LOAD_PATH
#import Basic: copy
#function Base.copy(node::Node)
    #Node(node.index, node.status, node.pred_inf_time, node.rec_time)
#end

# I cannot set fields if immutable
mutable struct Event
    node::Node   # is a reference
    time::Float32   #Float64
    action::Int8   #Symbol # :Rec, :Inf
end

## Symbols: :S ==> SS, :I ==> II, :R ==> RR
# These are accessible from within the function without using functino arguments
const SS = Int8(1)
const II = Int8(2)
const RR = Int8(3)
const TRANSMIT = Int8(1)
const RECOVER =  Int8(2)

function fastSIR(G, params, initial_infecteds::Vector{Int32})
	τ = params.τ
	γ = params.γ
	expo_γ = Exponential(γ) # type Distribution::Exp
	expo_τ = Exponential(τ)
	t_max = params.t_max  # mandatory

    nb_nodes = nv(G)
	times = Float32[0.]
    # length(G) is Int128
    S = Int32[nb_nodes]
    I = Int32[0]
    R = Int32[0]
    pred_inf_time = 100000000.0
    rec_time = 0.

	# empty queue
    Q = PriorityQueue(Base.Order.Forward);

	# prestore one F.Node for each graph vertex
    nodes = Array{Node,1}(undef, nb_nodes)


    for u in 1:nb_nodes  # extremely fast
        nodes[u] = Node(u, SS, pred_inf_time, rec_time)
    end

	# REMOVE
	#println(">>> about to test")
	#testTimings(G, nodes[4])  # EXPERIMENTAL. JUST FOR TESTING REMOVE WHEN DONE
	#println("END TEST TIMINGS")
	# REMOVE

    for u in initial_infecteds
       #println("nodes[u]= ", nodes[u])
       event = Event(nodes[u], 0., TRANSMIT)
       # How to do this with immutable structure
       nodes[u].pred_inf_time = 0.0  # should this new time be reflectd in the event? Here, it is.
       Q[event] = event.time
    end

    while !isempty(Q)
        event = dequeue!(Q)
        if event.action == TRANSMIT
            if event.node.status == SS
                # 12 allocations, 224 bytes
                processTransSIR(G, event.node, event.time, τ, γ, times,
					S, I, R, Q, t_max, nodes, expo_τ, expo_γ)
                #println("processTransSIR\n")
            end
		else
             # 1 alloc: 16 bytes, 0.000001 to 0.000002 seconds
             processRecSIR(event.node, event.time, times, S, I, R)
             #println("processRecSIR\n")
        end
    end
	println("times, times[end]: $(length(times)), $(times[end])")
    times, S, I, R
end;

function testTimings(G, node_u)
	println("\nEnter testTimings")
	a = []
	# 115 alloc
	for ν in neighbors(G, node_u.index)
		push!(a, ν)
		#@time findTransSIR(Q, t, τ, node_u, nodes[ν], t_max, nodes, expo_τ)
	end
	#println("after testTimings loop\n")
end

function processTransSIR(G, node_u, t::Float32, τ::Float32, γ::Float32,
        times::Vector{Float32}, S::Vector{Int32}, I::Vector{Int32}, R::Vector{Int32},
		Q, t_max::Float32, nodes::Vector{Node}, expo_τ, expo_γ)
    if (S[end] <= 0)
		println("S=$(S[end]), (ERROR!!! S cannot be zero at this point")
	end
	node_u.status = II
    push!(times, t)
    push!(S, S[end]-1)
    push!(I, I[end]+1)
    push!(R, R[end])
	#node_u.rec_time = t + rand(Exponential(γ))
	node_u.rec_time = t + rand(expo_γ)

	if node_u.rec_time < t_max
		new_event = Event(node_u, node_u.rec_time, RECOVER)
		#println("after Event\n")
		Q[new_event] = new_event.time
		#println("after Q\n")
	end

	#println("\nbefore  2nd neighbor loop, testTimings")
	#testTimings(G, nodes[4])  # EXPERIMENTAL. JUST FOR TESTING REMOVE WHEN DONE

	for ν in neighbors(G, node_u.index)
		findTransSIR(Q, t, τ, node_u, nodes[ν], t_max, nodes, expo_τ)
		#println("after findTransSIR (within neighbor loop)\n")
	end
	#println("after neighbors\n")

	#testTimings(G, nodes[4])  # EXPERIMENTAL. JUST FOR TESTING REMOVE WHEN DONE
	#println("after  2nd neighbor loop, testTimings\n")
end


function findTransSIR(Q, t, τ, source, target, t_max, nodes, expo_τ)
	if target.status == SS
		#inf_time = t + rand(Exponential(τ))
		inf_time = t + rand(expo_τ)
		#print("inf_time")
		# Allocate memory for this list
		if inf_time < minimum([source.rec_time, target.pred_inf_time, t_max])
			new_event = Event(target, inf_time, TRANSMIT)
			Q[new_event] = new_event.time
			target.pred_inf_time = inf_time
		end
	end
end

function processRecSIR(node_u, t, times, S, I, R)
	push!(times, t)
	push!(S, S[end])
	push!(I, I[end]-1)
	push!(R, R[end]+1)
	node_u.status = RR
end

function simulate(G, params, infected)
	#global γ, τ
	println("simulate, infected: $(typeof(infected))")
	times, S, I, R = fastSIR(G, params, infected)
	return times, S, I, R
end

end
