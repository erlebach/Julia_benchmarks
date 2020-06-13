# Julia_benchmarks
Collection of benchmarks for discussion in Julia Discourse

FastSIR_0/: Based implementation of FastSIR, using struct Nodes, struct Event, 
a priorityQueue, and LigthGraphs.jl. The model follows the book Mathematical epidemic modeling on Networks. 

FastSIR_2/: Changed struct Node and Events to use shorter variable types (Int32, Float32, 
   and Int8 instead of Symbol.). This saves 2x memory. I did not squash the graph to reduce
   data further. 

FastSIR_3/: implementation of weighted graphs,  which adds about 25% compute time. 
