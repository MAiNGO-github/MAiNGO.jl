# ============================ /test/MOI_wrapper.jl ============================
module TestMAINGO

#Set path to shared library with C-API.
#ENV["MAINGO_LIB"]="XXX/maingo/build/libmaingo-c-api.so"  #replace with path tho c-api lib file.
#include the wrapper

using ..MAiNGO
using MathOptInterface
using Test

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const OPTIMIZER = MOI.instantiate(MOI.OptimizerWithAttributes(MAiNGO.Optimizer,
                                                              MOI.Silent() => true))

const BRIDGED = MOI.instantiate(MOI.OptimizerWithAttributes(MAiNGO.Optimizer,
                                                            MOI.Silent() => true),
                                with_bridge_type = Float64)

const caching_optimizer = MOIU.CachingOptimizer(MOIU.UniversalFallback(MOIU.Model{Float64}()),
                                                MAiNGO.Optimizer(epsilonA = 0.5e-8,
                                                                 epsilonR = 0.5e-8,
                                                                 relNodeTol = 1e-11))
caching_optimizer.optimizer.inner.silent = true

# See the docstring of MOI.Test.Config for other arguments.
const CONFIG = MOI.Test.Config(
                               # Modify tolerances as necessary.
                               atol = 5e-4,
                               rtol = 5e-4,
                               # Use MOI.LOCALLY_SOLVED for local solvers.
                               optimal_status = MOI.OPTIMAL,
                               # Pass attributes or MOI functions to `exclude` to skip tests that
                               # rely on this functionality.
                               #exclude = Any[],
                               exclude = Any[MOI.delete,
                                             MOI.ConstraintBasisStatus,
                                             MOI.DualObjectiveValue,
                                             #MOI.ObjectiveBound,
                                             #MOI.VariableName, 
                                             MOI.DualStatus,
                                             MOI.ConstraintDual])

"""
    runtests()

This function runs all functions in the this Module starting with `test_`.
"""
function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

"""
    test_runtests()

This function runs all the tests in MathOptInterface.Test.

Pass arguments to `exclude` to skip tests for functionality that is not
implemented or that your solver doesn't support.
"""
function test_runtests()
    MOI.Test.runtests(
                      #   BRIDGED,
                      caching_optimizer,
                      CONFIG,
                      exclude = ["test_attribute_SolverVersion",
                                 #"test_objective_ObjectiveFunction_blank",
                                 # returns NaN in expression and solver has to responde with:
                                 # MOI.get(model, MOI.TerminationStatus()) == MOI.INVALID_MODEL
                                 # this code will error when NaN is found (better than waiting to know about bad stuff)

                                 "test_nonlinear_invalid",
                                 "test_nonlinear_hs071_NLPBlockDual", # MathOptInterface.NLPBlockDual(1)
                                 "test_linear_DUAL_INFEASIBLE",
                                 "test_linear_DUAL_INFEASIBLE_2",
                                 "test_solve_TerminationStatus_DUAL_INFEASIBLE", #MAiNGO always adds bounds
                                 "test_unbounded_MIN_SENSE_offset",
                                 "test_unbounded_MIN_SENSE",
                                 "test_unbounded_MAX_SENSE_offset",
                                 "test_unbounded_MAX_SENSE"]
                      # This argument is useful to prevent tests from failing on future
                      # releases of MOI that add new tests. Don't let this number get too far
                      # behind the current MOI release though! You should periodically check
                      # for new tests in order to fix bugs and implement new features.
                      #exclude_tests_after = v"0.10.5",
                      )
    return
end

"""
    test_SolverName()

You can also write new tests for solver-specific functionality. Write each new
test as a function with a name beginning with `test_`.
"""
function test_SolverName()
    @test MOI.get(MAiNGO.Optimizer(), MOI.SolverName()) == "MAiNGO"
    return
end

using JuMP

function test_GapSettings()
    model = Model(MAiNGO.Optimizer)
    value = MOI.get(model, MOI.AbsoluteGapTolerance())
    MOI.set(model, MOI.AbsoluteGapTolerance(), 1e-2)
    @test MOI.get(model, MOI.AbsoluteGapTolerance()) == 1e-2
    MOI.set(model, MOI.AbsoluteGapTolerance(), 100.0)
    @test MOI.get(model, MOI.AbsoluteGapTolerance()) == 100.0
    MOI.set(model, MOI.AbsoluteGapTolerance(), value)
    @test value == MOI.get(model, MOI.AbsoluteGapTolerance())

    value = MOI.get(model, MOI.RelativeGapTolerance())
    MOI.set(model, MOI.RelativeGapTolerance(), 1e-2)
    @test MOI.get(model, MOI.RelativeGapTolerance()) == 1e-2
    MOI.set(model, MOI.RelativeGapTolerance(), 5e-5)
    @test MOI.get(model, MOI.RelativeGapTolerance()) == 5e-5
    MOI.set(model, MOI.RelativeGapTolerance(), value)
    @test value == MOI.get(model, MOI.RelativeGapTolerance())
end

end # module TestMAINGO

# This line at tne end of the file runs all the tests!
TestMAINGO.runtests()
