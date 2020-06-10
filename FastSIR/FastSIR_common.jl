module FastSIRCommon
using LightGraphs
using Plots

function makeGraph(nb_nodes, edges_per_vertex)
    random_regular_digraph(nb_nodes, edges_per_vertex)
end

function myPlot(times, S, I, R)
   plot(times, S, label=:S)
   plot!(times, I, label=:I)
   plot!(times, R, label=:R)
end

end
