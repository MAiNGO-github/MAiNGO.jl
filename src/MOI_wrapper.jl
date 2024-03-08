#This file handels the main wrapping of the Optimizer and model to be used from the MathOptInterface.

using MathOptInterface: MathOptInterface
import MathOptInterface: Utilities

const MOI = MathOptInterface
const MOIU = MOI.Utilities

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# function aliases

const SAF = MOI.ScalarAffineFunction{Float64}
const SQF = MOI.ScalarQuadraticFunction{Float64}
const SNF = MOI.ScalarNonlinearFunction

# set aliases
const Bounds = Union{
    MOI.EqualTo{Float64},
    MOI.GreaterThan{Float64},
    MOI.LessThan{Float64},
    MOI.Interval{Float64},
}

#Define the optimizer.
mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::MAINGOModel #The model
    nlp_block_data::Union{Nothing,MOI.NLPBlockData} #Nonlinear equations are handled specially in current version of MathOptInterface
    ##	function Optimizer(; kwargs...) 
    ##        options = Dict{String, Any}(String(key) => val for (key,val) in kwargs)
    ##        return new(MAINGOModel(options), nothing)
    ##	end
end

Optimizer(; options...) = Optimizer(MAINGOModel(; options...), nothing)

#Define name
MOI.get(::Optimizer, ::MOI.SolverName) = "MAiNGO"

#Define functions and constraints usable in the model 
MOIU.@model(
    Model, # modelname
    (), # scalarsets
    (MOI.Interval, MOI.LessThan, MOI.GreaterThan, MOI.EqualTo), # typedscalarsets 
    (), # vectorsets
    (), # typedvectorsets
    (), # scalarfunctions
    (MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction), # typedscalarfunctions (that we can handle nonlinear functions is specified later)
    (), # vectorfunctions
    ()
)

#We allow setting and receiving parameters by string
#E.g. model=Model(optimizer_with_attributes(MAINGO.Optimizer, "epsilonA"=> 1e-8,"res_name"=>"res_new.txt","prob_name"=>"problem.txt"))
# or  model=Model(() -> MAINGO.Optimizer(epsilonA=1e-8))#, "options" => options)) 
# RawOptimizerAttribute
MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true

#How to set parameters
function MOI.set(model::Optimizer, p::MOI.RawOptimizerAttribute, value)
    model.inner.options[p.name] = value
    return
end

#How to get parameter
function MOI.get(model::Optimizer, p::MOI.RawOptimizerAttribute)
    if haskey(model.inner.options, p.name)
        return model.inner.options[p.name]
    end
    return error("RawOptimizerAttribute with name $(p.name) is not set.")
end

# TimeLimitSec
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, val::Real)
    model.inner.options["maxTime"] = Float64(val)
    return
end
# Tolerances supported
MOI.supports(::Optimizer, ::MOI.AbsoluteGapTolerance) = true
MOI.supports(::Optimizer, ::MOI.RelativeGapTolerance) = true

function MOI.get(model::Optimizer, ::MOI.AbsoluteGapTolerance)
    return get(model.inner.options, "epsilonA", 1e-2)
end

function MOI.set(model::Optimizer, ::MOI.AbsoluteGapTolerance, value::Real)
    MOI.set(model, MOI.RawOptimizerAttribute("epsilonA"), value)
    return
end

function MOI.get(model::Optimizer, ::MOI.RelativeGapTolerance)
    return get(model.inner.options, "epsilonR", 1e-2)
end

function MOI.set(model::Optimizer, ::MOI.RelativeGapTolerance, value::Real)
    MOI.set(model, MOI.RawOptimizerAttribute("epsilonR"), value)
    return
end

#MAINGO's default time limit is 24hrs
function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    return get(model.inner.options, "maxTime", 86400.0)
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
function MOI.get(model::Optimizer, ::MOI.Silent)
    return model.inner.silent
end

function MOI.set(model::Optimizer, ::MOI.Silent, flag::Bool)
    model.inner.silent = flag
    output_flag = flag ? 0 : 1
    MOI.set(model, MOI.RawOptimizerAttribute("LBP_verbosity"), output_flag)
    MOI.set(model, MOI.RawOptimizerAttribute("UBP_verbosity"), output_flag)
    MOI.set(model, MOI.RawOptimizerAttribute("BAB_verbosity"), output_flag)
    return
end

#How to check if  Optimizer is empty
function MOI.is_empty(model::Optimizer)
    return MAiNGO.is_empty(model.inner) && model.nlp_block_data === nothing
end

#How to reset Optimizer (keeps options) but resets model
function MOI.empty!(model::Optimizer)
    silent = model.inner.silent

    model.inner = MAINGOModel(;
        ((Symbol(key), val) for (key, val) in model.inner.options)...,
    )
    if silent
        MOI.set(model, MOI.Silent(), true)
    else
        MOI.set(model, MOI.Silent(), false)
    end
    model.nlp_block_data = nothing

    return
end

# copy

MOI.supports_incremental_interface(::Optimizer) = true
function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; kws...)
    return MOIU.default_copy_to(dest, src; kws...)
end

# This function is taken and adapted from https://discourse.julialang.org/t/how-to-read-from-external-command-and-also-get-exit-status/99880
# It captures the exit code of an external call (we use it to capture the exit code of the call to the MAiNGO standalone executable)
# This is required for setting the solver_status attribute in MAiNGOModel::solution_info
function runandcapture(cmd)
    cmd = Cmd(cmd; ignorestatus = true)
    res = run(pipeline(cmd))
    return res.exitcode
end

# Optimize by writing the problem in ALE syntax to a file and calling a standalone executable with that file.
# This is a fallback method and only allows to construct the problem and receive the results in form of a text file.
function optimizeWithFile!(model::Optimizer)
    write_settings_file(model.inner)
    write_ALE_file(model.inner)
    rm("statisticsAndSolution.json"; force = true) # remove possibly existing json file from older runs
    retcode = runandcapture(
        `$(MAiNGO.maingo_exec[]) $(model.inner.problem_file_name) $(model.inner.settings_file_name)`,
    )
    return read_results(model.inner, retcode)
end

#Struct for defining options matching the struct defined in the header of the called C-API
struct option_pair_c
    option_name::Cstring
    option_value::Cdouble
    function option_pair_c(name::String, value::Real)
        return new(
            Base.unsafe_convert(Cstring, Base.cconvert(Cstring, name)),
            Base.unsafe_convert(Cdouble, Base.cconvert(Cdouble, value)),
        )
    end
end

#Optimize the model with the given settings, if the C-API is found. 
#If it is not found, the fallback option described in optimizeWithFile! is used.
function MOI.optimize!(model::Optimizer)
    if environment_status[] == C_API || environment_status[] == MAINGO_JLL

        #Write the problem definition to memory
        buffer = write_ALE_problem(model.inner)
        problem = String(take!(buffer))

        #Preallocate memory that the C-API can write to
        solution = Vector{Cdouble}(zeros(length(model.inner.variable_info)))
        obj = Ref{Cdouble}(0.0)
        cpuTime = Ref{Cdouble}(0.0)
        wallTime = Ref{Cdouble}(0.0)
        obj_upper_bound = Ref{Cdouble}(0.0)
        obj_lower_bound = Ref{Cdouble}(0.0)

        #Set the file paths
        resultFileName = model.inner.options["res_name"]
        logFileName = model.inner.options["log_name"]
        settingsFileName = model.inner.options["settings_name"]

        #Set other options (all options recognized from MAINGO->set_option() can be used.)
        options = Array{option_pair_c,1}()
        for (key, value) in model.inner.options
            #MAINGO only has options with numeric value
            # prob_name and res_name and log_name are already set in constructor
            if (
                !(
                    key in
                    ["prob_name", "res_name", "log_name", "settings_name"]
                ) && isa(value, Real)
            )
                push!(options, option_pair_c(String(key), Float64(value)))
            end
        end
        status = NOT_SOLVED_YET
        #try
        #Call use the C Interface to call the MAINGO solver
        #Signature of called function:
        # (const char* aleString, double* objectiveValue, double* solutionPoint, unsigned solutionPointLength, double* cpuSolutionTime, double* wallSolutionTime, double* upper_bound, double* lower_bound, const char* resultFileName, const char* logFileName, const char* settingsFileName, const option_pair* options, unsigned numberOptions);
        # (function,location), return type, input types, inputs

        status = ccall(
            ("solve_problem_from_ale_string_with_maingo", maingo_lib[]),
            Cint,
            (
                Cstring,
                Ref{Cdouble},
                Ptr{Cdouble},
                Cuint,
                Ref{Cdouble},
                Ref{Cdouble},
                Ref{Cdouble},
                Ref{Cdouble},
                Cstring,
                Cstring,
                Cstring,
                Ptr{option_pair_c},
                Cuint,
            ),
            problem,
            obj,
            solution,
            length(solution),
            cpuTime,
            wallTime,
            obj_upper_bound,
            obj_lower_bound,
            resultFileName,
            logFileName,
            settingsFileName,
            options,
            length(options),
        )

        model.inner.solution_info = SolutionStatus()
        if (status == -1)
            model.inner.solution_info.solver_status = TERMINATED_BY_MAINGO
            model.inner.solution_info.model_status = NO_FEASIBLE_POINT_FOUND
        else
            maingo_status = MaingoModelStatus(status)
            if (
                maingo_status == GLOBALLY_OPTIMAL ||
                maingo_status == FEASIBLE_POINT
            )
                model.inner.solution_info.feasible_point = solution

                if model.inner.objective_info.sense == :Max
                    model.inner.solution_info.objective_value = -obj[]
                    model.inner.solution_info.upper_bound = -obj_lower_bound[]
                    model.inner.solution_info.lower_bound = -obj_upper_bound[]

                else
                    model.inner.solution_info.objective_value = obj[]
                    model.inner.solution_info.upper_bound = obj_upper_bound[]
                    model.inner.solution_info.lower_bound = obj_lower_bound[]
                end
                model.inner.solution_info.solver_status = NORMAL_COMPLETION
                model.inner.solution_info.model_status = maingo_status

            elseif (maingo_status == INFEASIBLE)
                model.inner.solution_info.solver_status = NORMAL_COMPLETION
                model.inner.solution_info.model_status = maingo_status
            else
                model.inner.solution_info.solver_status = UNKNOWN_ERROR
                model.inner.solution_info.model_status = NO_FEASIBLE_POINT_FOUND
            end
        end
        model.inner.solution_info.cpu_time = cpuTime[]
        model.inner.solution_info.wall_time = wallTime[]
    elseif environment_status[] == STANDALONE
        optimizeWithFile!(model)
    else
        @warn(
            "No version of MAiNGO has been set. Please call findMAiNGO() and try again."
        )
    end
end

include(joinpath("moi", "util.jl"))
include(joinpath("moi", "variables.jl"))
include(joinpath("moi", "constraints.jl"))
include(joinpath("moi", "objective.jl"))
include(joinpath("moi", "results.jl"))
