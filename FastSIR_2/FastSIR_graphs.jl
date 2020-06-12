
# Exports come before indlude statements
#export watch

include("FastSIR_with_nodes_impl.jl"); # module WithNodes
include("FastSIR_with_weighted_nodes_impl.jl"); # module NoNodes
#include("FastSIR_no_nodes_impl.jl"); # module NoNodes
include("FastSIR_common.jl")
