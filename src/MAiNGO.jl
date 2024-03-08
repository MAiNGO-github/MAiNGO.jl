# The following wrapper files where enable to create input for  MAiNGO  for global optimization.
# To do this, the objective and constraints are converted into strings compatibel with the ALE syntax.

# Large parts of these files where adapted from from the wrapper Baron.jl (commit 5e2a6f5adb4d9d54633d3d1cffc661ad01e58b39)

# MIT License Copyright (c) 2015 Joey Huchette for Baron.jl

module MAiNGO

@enum EnvironmentStatus begin
    MAINGO_NOT_FOUND = 1
    C_API = 2
    MAINGO_JLL = 3
    STANDALONE = 4
end
maingo_lib = Ref("")
maingo_exec = Ref("")

environment_status = Ref(MAINGO_NOT_FOUND)

using Libdl: Libdl
using MAiNGO_jll

include("find.jl") # contains all requried subroutines for finding MAiNGO

const maingo_variable_default_bound = 10e8

#Define struct for variables
mutable struct VariableInfo
    lower_bound::Union{Float64,Nothing}
    upper_bound::Union{Float64,Nothing}
    category::Symbol
    start::Union{Float64,Nothing}
    name::Union{String,Nothing}
end

#Constructor for variables
VariableInfo() = VariableInfo(nothing, nothing, :Cont, nothing, nothing)

#Define struct for constraints
mutable struct ConstraintInfo
    expression::Expr
    name::Union{String,Nothing}
end

#Constructor for constraints
function ConstraintInfo()
    return ConstraintInfo(:(), nothing)
end

mutable struct ObjectiveInfo
    expression::Union{Expr,Number}
    sense::Symbol
end
ObjectiveInfo() = ObjectiveInfo(0, :Feasibility)

#Mostly unused at the moment, because MAINGO does not return reasons for premature termination
@enum MaingoSolverStatus begin
    NORMAL_COMPLETION = 1
    INSUFFICIENT_MEMORY_FOR_NODES = 2
    ITERATION_LIMIT = 3
    TIME_LIMIT = 4
    NUMERICAL_SENSITIVITY = 5
    USER_INTERRUPTION = 6
    INSUFFICIENT_MEMORY_FOR_SETUP = 7
    RESERVED = 8
    TERMINATED_BY_MAINGO = 9
    SYNTAX_ERROR = 10
    LICENSING_ERROR = 11
    USER_HEURISTIC_TERMINATION = 12
    UNKNOWN_ERROR = 13
end

#Return codes returned from the MAINGO solver after termination
@enum MaingoModelStatus begin
    GLOBALLY_OPTIMAL = 0
    INFEASIBLE = 1
    FEASIBLE_POINT = 2
    NO_FEASIBLE_POINT_FOUND = 3
    BOUND_TARGETS = 4
    NOT_SOLVED_YET = 5
    JUST_A_WORKER_DONT_ASK_ME = 6
end

#Information availible after solution
mutable struct SolutionStatus
    feasible_point::Union{Nothing,Vector{Float64}}
    objective_value::Float64
    upper_bound::Float64
    lower_bound::Float64
    wall_time::Float64
    cpu_time::Float64
    solver_status::MaingoSolverStatus
    model_status::MaingoModelStatus

    SolutionStatus() = new(nothing)
end

#Struct collecting information and settings for a given problem.
#The optimizer can solve several models after each other.
#In theory the interface in MathOptInterface allows incremental construction of models, but this is not implemented here.
mutable struct MAINGOModel
    options::Dict{String,Any}

    variable_info::Vector{VariableInfo}
    constraint_info::Vector{ConstraintInfo}
    objective_info::ObjectiveInfo

    temp_dir_name::String
    problem_file_name::String
    summary_file_name::String
    log_file_name::String
    result_file_name::String
    settings_file_name::String

    solution_info::Union{Nothing,SolutionStatus}
    silent::Bool

    function MAINGOModel(; kwargs...)
        options = Dict{String,Any}(String(key) => val for (key, val) in kwargs)
        return MAINGOModel(options)
    end
    function MAINGOModel(options::Dict{String,Any})
        model = new()
        model.options = options
        # valid options are MAINGO options e.g. (epsilonA,1.0e-9) and prob_name and res_name and log_name for problem and results file names
        model.variable_info = VariableInfo[]
        model.constraint_info = ConstraintInfo[]
        model.objective_info = ObjectiveInfo()
        model.silent = false
        temp_dir = mktempdir()
        model.temp_dir_name = temp_dir
        model.problem_file_name =
            get!(options, "prob_name", joinpath(temp_dir, "maingoProblem.txt"))
        model.result_file_name =
            get!(options, "res_name", joinpath(temp_dir, "result.txt"))
        model.log_file_name =
            get!(options, "log_name", joinpath(temp_dir, "bab.log"))
        model.settings_file_name = get!(
            options,
            "settings_name",
            joinpath(pwd(), "MAiNGOSettings.txt"),
        )
        model.solution_info = nothing
        return model
    end
end

function __init__()
    return findMAiNGO(; verbose = true)
end

include("util.jl")
include("MOI_wrapper.jl")
end
