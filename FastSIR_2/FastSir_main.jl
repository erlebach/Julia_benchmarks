
include("FastSIR_graphs.jl")
FW = FastSIRWithNodes
FWG = FastSIRWithWeightedNodes
#FN = FastSIRNoNodes
F  = FastSIRCommon
using LightGraphs
using SimpleWeightedGraphs

# const G = F.erdos_renyi(200000, 0.0002)
# Erdos-renyi(200000, 0.0002) generates a graph with 200,000 edges and 4M edges.
# The cost of fastSIR in Jlia is 8.8 sec, 400,000 iterations, and 740M memory allocs
# So create a smaller graph and debug

# const G = F.erdos_renyi(50000, 0.0002)
# each call to processTransSIR: 0.000007 sec, 11 alloc, 210 bytes. WHY?

# t_max is mandatory parameter. There are actually 2x edges reported (both directions)
const G = F.erdos_renyi(100000, 0.006)
const GW = SimpleWeightedGraph(G)
# Compute the maximum degree
@time max_degree = Δ(G)  # no allocations
@time neigh_list = zeros(Int, max_degree)
@time adj = adjacency_matrix(G)
println(adj[2])


println("Graph G: $(nv(G)) nodes, $(ne(G)) edges")
println("Graph GW: $(nv(G)) nodes, $(ne(G)) edges")

# ρ: fraction initially infected
const params = (τ=.3, γ=1.0, t_max=5., ρ=0.05)

const infected = rand(1:nv(G), Int(floor(nv(G)*params.ρ)))
println("Initial number of infected: $(length(infected)),  percentage infected: $(params.ρ)")

# Higher τ means higher infection rate, so infection should grow faster. It does not.
# Higher τ means smaller time increments (smaller increment to infection, so infections should rise faster)

# 5 sec with no_node
# 5.7 sec with fast_SIR
# 16 to 25 percent decrease in time

for i in 1:1
	global times, S, I, Rkjjj
	global timesn, Sn, In, Rn
	global timesw, Sw, Iw, Rw
	# with Node struct

	# 6.942529 seconds (16.88 M allocations: 934.965 MiB, 8.75% gc time)
	# 6.421051 seconds (16.85 M allocations: 934.356 MiB, 7.72% gc time)
	# 6.197951 seconds (15.46 M allocations: 848.826 MiB, 8.24% gc time)
	#@time times, S, I, R = FW.simulate(G, params, infected)

	@time timesw, Sw, Iw, Rw = FWG.simulate(GW, params, infected)
	# without Node struct
	#@time timesn, Sn, In, Rn = FN.simulate(G, params, infected)
end
F.myPlot(times, S, I, R)
F.myPlot(timesn, Sn, In, Rn)
n = 39
tn = times[end-n:end];
Sn = S[end-n:end];
In = I[end-n:end];
Rn = R[end-n:end];
F.myPlot(tn, Sn, In, Rn);
F.myPlot(times, S, I, R);
#----------------------------------------------------------------------



# only 32 bytes allocated
@time for i in nv(G)
	neighbors(G, nodes[i].index)
end

#@time for n in nodes
count = [3]
count1 = [4]
# No memory allocation
@time for i in 1:nv(G) #(i,node) in enumerate(nodes)
	count[1] = count1[1] - count[1]
	count[1] = count1[1] + count[1]
	#neighbors(G, getIndex(n)) #getIndex(node))
	#print("gg")
end
print(count)
