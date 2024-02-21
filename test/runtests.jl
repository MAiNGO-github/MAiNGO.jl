#Needs to know MAiNGO location, for example, by setting : ENV["MAINGO_LIB"]="\\maingo_build\\Debug\\shared_parser.dll"
# MAiNGO defaults to using MAiNGO_jll, so a path is not required, unless you want to test your own MAiNGO installation.
ENV["MAINGO_LIB"] = "XYZ/maingo/build/libmaingo-c-api.so"
include("../src/MAiNGO.jl")
using Test

include("gear.jl")
include("minlp.jl")
include("nlp1.jl")
include("nlp2.jl")
include("pool1.jl")
include("bad_expressions.jl")

include("run_tests.jl")
