# MAiNGO.jl

## What is MAiNGO?
MAiNGO (**M**cCormick-based **A**lgorithm for mixed-**i**nteger **N**onlinear **G**lobal **O**ptimization) is a deterministic global optimization solver for nonconvex mixed-integer nonlinear programs (MINLPs). For more information on MAiNGO, including installation, usage, and licensing, please see the [repository](https://git.rwth-aachen.de/avt-svt/public/maingo) and the [documentation](https://avt-svt.pages.rwth-aachen.de/public/maingo/).

MAiNGO.jl is a wrapper for using MAiNGO in Julia.
It requires a working installation of MAiNGO, either the standalone version with parser support (Mode A), or the shared parser library version (Mode B). When building MAiNGO from source this is configurable in the CMake configuration of MAiNGO. Per default, precompiled version of MAiNGO is used that operates in Mode B. 

## Using the precompiled version of MAiNGO from the Julia Package Manager
A Julia package containing a precompiled version of MAiNGO is available (MAiNGO_jll). This version is used by default on supported platforms (Linux/MacOs/Windows), but this can be changed ([see here](#switching-between-modes-finding-the-maingo-executable)). The precompiled version contains only open-source components. If you would like to use commercial subsolvers with MAiNGO (for example CPLEX or KNITRO), it might still make sense to compile MAiNGO yourself and use this version rather than the precompiled one.

### Quick start

```julia
using MAiNGO # if this fails, you need to add the package first manually
using JuMP
#Set options in constructor
model=Model(optimizer_with_attributes(MAiNGO.Optimizer, "epsilonA"=> 1e-8))
set_silent(model)

@variable(model, x, lower_bound=-20, upper_bound=20)
@variable(model, 0<=y<=2)
@variable(model, 0<=z<=2)
@variable(model, 0<=d<=2)
@variable(model, 0<=l<=6)
@variable(model, 0<=b<=6)

@NLobjective(model, Min, y*-1*x^2*(exp(-x^2+z+d+b)+l*b))
@NLconstraint(model,(x^2+y^2>=1))
JuMP.optimize!(model)
#query results
println(value(x)," ",value(y))
println(termination_status(model))
println(primal_status(model))
```


## Using a custom MAiNGO version

If you want to make use of a MAiNGO version that you build from source yourself, you have to give the path to the correct binary file. The correct path depends on the mode of operation.

### Modes of operation
The following library allows to call MAiNGO from Julia.
Currently two modes are supported:

#### Mode A)
 Using MAiNGO standalone exe with compiled parser support. This only allows to construct the problem in JuMP and call the MAiNGO executable with the filepath.
  Thus, results are obtained in form of an output text file.

If a JSON file is also written (by setting the corresponding MAiNGO option), then the contents of that file are parsed, allowing to query the model from JuMP. This requires the JSON module to be installed in Julia.
  
```julia
#Set path to MAiNGO standalone exe with compiled parser support.
ENV["MAINGO_EXEC"] = "W:\\maingo_build\\Debug\\MAiNGO.exe"  #replace "W:\\maingo_build\\Debug\\" with path to MAiNGO.exe
using MAiNGO # if this fails, you need to add the package first manually
#create model
using JuMP
model=Model(MAiNGO.Optimizer)
@variable(model, x, lower_bound=0, upper_bound=5)
@variable(model, y, lower_bound=0, upper_bound=2, start=0.5)

#The following also works:
#@variable(model,x in MOI.Interval(0,5)) 
#@variable(model, 0<=x<=5)
#For integer variables use 
#@variable(model, y in MOI.Integer(), start=0.5)

@constraint(model,y+x<=5)
@constraint(model,x+y>=4)
#Linear objective is also possible
#@objective(model, Max, (1 - x)*y)
@NLobjective(model, Max, (1 - x)^2 + 100 * (y - x^2)^2)
@NLconstraint(model,min(x^2+y^2,y)<=5+y^2)
MOI.set(model, MOI.RawOptimizerAttribute("writeJson"),1) # write JSON file to enable querying of results from JuMP
JuMP.optimize!(model)
println(objective_value(model))
```
#### Mode B)
Compiling an interface presenting a C-API to Julia. This must be configured when building MAiNGO, but allows several improvements.
  The problem definition is passed in memory. Settings can be set from within Julia/JuMP and the results are returned as Julia variables/ are queryable from JuMP.

For example:
```julia
#Set path to shared library with C-API.
ENV["MAINGO_LIB"]="W:\\maingo_build\\Debug\\shared_parser.dll"  #replace "W:\\maingo_build\\Debug\\" with path to shared_parser.dll
#include the wrapper
using MAiNGO # if this fails, you need to add the package first manually

#Set options in constructor
model=Model(optimizer_with_attributes(MAiNGO.Optimizer, "epsilonA"=> 1e-8,"res_name"=>"res_new.txt","prob_name"=>"problem.txt"))
#Alternate syntax
#model=Model(() -> MAiNGO.Optimizer(epsilonA=1e-8))#, "options" => options))

@variable(model, x, lower_bound=-20, upper_bound=20)
#@variable(model, y in MOI.Integer(),lower_bound=-10,upper_bound=10, start=0.5)
#Alterntaive forms
#@variable(model,x in MOI.Interval(0,5))
#@variable(model,y in MOI.Interval(0,2))
#@variable(model, 0<=x<=5)
@variable(model, 0<=y<=2)
@variable(model, 0<=z<=2)
@variable(model, 0<=d<=2)
@variable(model, 0<=l<=6)
@variable(model, 0<=b<=6)
#@constraint(model,y+x<=5)
#@constraint(model,x+y>=4)

@NLobjective(model, Min, y*-1*x^2*(exp(-x^2+z+d+b)+l*b))
@NLconstraint(model,(x^2+y^2>=1))
JuMP.optimize!(model)
#C-API allows us to query results
println(value(x)," ",value(y))
println(termination_status(model))
println(primal_status(model))
```

# Supported MAiNGO Options
Both modes of operation allow setting MAiNGO options through the MatOptInterface-API. An example of how to do so is given below. All numerical and boolean options [that are available in MAiNGO](https://avt-svt.pages.rwth-aachen.de/public/maingo/maingo_settings.html) can be set using the MOI.RawOptimizerAttribute() function. Additionally, the following options can also be set through specific other MOI functions:
- Solver time limit (in seconds): MOI.TimeLimitSec()
- Absolute gap: MOI.AbsoluteGapTolerance()
- Relative gap: MOI.RelativeGapTolerance()
- Silencing output: MOI.Silent() (this overwrites any other verbosity settings)

```julia
# assuming necessary paths and using-statements have already been set
model = Model(MAiNGO.Optimizer)
MOI.set(model, MOI.Silent(), true) # silence all MAiNGO output
MOI.set(model, MOI.AbsoluteGapTolerance(), 1e-8) # set the absolute gap tolerance
MOI.set(model, MOI.RawOptimizerAttribute("PRE_pureMultistart"), 1) # example of setting an option via the MOI.RawOptimizerAttribute() function
```

## Switching between modes, finding the MAiNGO executable
If you need to update the path to the MAiNGO executable during a session, this can be done as follows:
```julia

using MAiNGO
# by default, MAiNGO_jll will be used
# explicitly force use of standalone version (mode A)
ENV["MAINGO_EXEC"] = "W:\\maingo_build\\Debug\\MAiNGO.exe"
findMAiNGO(preferred=MAiNGO.C_API) # see note on "preferred"-argument below
# ...
# for example switch to release version of MAiNGO
ENV["MAINGO_EXEC"] = "W:\\maingo_build\\Release\\MAiNGO.exe"
findMAiNGO(preferred=MAiNGO.C_API)
# now switch to C-API (mode B)
ENV["MAINGO_LIB"]="W:\\maingo_build\\Debug\\shared_parser.dll"  #replace "W:\\maingo_build\\Debug\\" with path to shared_parser.dll
findMAiNGO(preferred=MAiNGO.C_API)
# switch back to MAiNGO_jll
findMAiNGO(preferred=MAiNGO.MAINGO_JLL)
```

The findMAiNGO() function takes several optional arguments, which can be passed as keyword-arguments:
* verbose: boolean, whether or not progress on finding MAiNGO is reported. (Default value: false)
* preferred: either MAiNGO.MAINGO_JLL or MAiNGO.C_API, determines whether jll binaries or custom installation of MAiNGO is preferred. Note that the C-API is always preferred to the standalone version. If a custom standalone version should be used, set this value to C-API and pass an empty string as the c_api argument (see next). (Default value: MAINGO_JLL)
* c_api: string, path to C-API file. If set, this overrides the environment variable MAINGO_LIB.
* standalone: string, path to standalone executable file. If set, this overrides the environment variable MAINGO_EXEC.

For example, to use the C-API at a new location, one could call:
```julia
using MAiNGO
findMAiNGO(preferred=MAiNGO.C_API, c_api="path\\to\\c\\api\\shared_parser.dll")
```

## Currently working:
* Integer and binary variables.
* Affine, Quadratic and nonlinear constraints and objectives.
* Operations: min,max,*,/,+,-,-(unary), exp,log,abs,sqrt,^
  - Other operations  are easy to add if supported by MathOptInterface,ALE and MAiNGO.
* Writing problem defined in JuMP syntax to an ALE problem.txt and calling MAiNGO.exe on a specified path.
* Alternatively using a C-API to call MAiNGO.



## Restrictions compared to using the Python or C++ interface
It is assumed that all variables are bounded. This interface assumes that integer variables are bounded between -1e6 and 1e6. For real variables these bounds are -1e8 and 1e8.

Other functionality such as special support for growing datasets or MPI parallelization is not currently supported via this wrapper.
 Additionally, constraint formulations are simply passed from their representation in JuMP/MathOptInterface to MAiNGO. As such, there is no way to make use of advanced techniques such as defining constraints that are only used for the relaxations, using special relaxations for functions used in thermodynamics and process engineering or formulating reduced space formulations.


## Tests
A subset of test cases for MathOptInterface solvers can be run by running the script ./test/runtests.jl. The current release was tested in the following combinations:
- Julia 1.8.5 and MathOptInterface v1.18.0
- Julia 1.9.4 and MathOptInterface v1.23.0.

