# functions that attempt to find MAiNGO
# findMAiNGO is the top level and the only one that users should call
# findMAiNGO_* try to find a specific MAiNGO (either the precompiled binaries from maingo_jll, or the C-API shared library or standalone version)
# the findMAiNGO_* subroutines should only be called from findMAiNGO

export findMAiNGO # export to make callable as findMAiNGO() instead of MAiNGO.findMAiNGO()
# import MAiNGO.set_maingo_exec, MAiNGO.set_maingo_lib, MAiNGO.set_environment_status

function findMAiNGO_jll(io)
    if MAiNGO_jll.is_available()
        MAiNGO.maingo_lib[] = MAiNGO_jll.libmaingo_c_api
        env_status = MAINGO_JLL
        println(io, "Found MAiNGO_jll!")
    else
        println("MAiNGO_jll not available for this platform.")
    end
    return env_status
end

function findMAiNGO_capi(io, path)
    MAiNGO.maingo_lib[] = path
    env_status = MAINGO_NOT_FOUND
    try
        lib = Libdl.dlopen(MAiNGO.maingo_lib[]) # Open the library explicitly.
        sym = Libdl.dlsym(lib, :solve_problem_from_ale_string_with_maingo)   # Get a symbol for the function to call.
        Libdl.dlclose(lib)
        env_status = C_API
        println(io, "Found C-API!")
    catch e
        @warn("Unable to find needed C interface in supplied MAINGO library file at " *
              path *
              ". Check the given path and if support for string based C API has been compiled.")
    end
    return env_status
end

function findMAiNGO_standalone(io, path)
    MAiNGO.maingo_exec[] = path
    env_status = STANDALONE
    println(io, "Will try to use standalone at " * path)
    return env_status
end

function findMAiNGO(; verbose::Bool = false,
                    preferred::Union{EnvironmentStatus,Nothing} = nothing,
                    standalone::Union{String,Nothing} = nothing,
                    c_api::Union{String,Nothing} = nothing)
    MAiNGO.environment_status[] = MAINGO_NOT_FOUND
    MAiNGO.maingo_exec[] = ""
    MAiNGO.maingo_lib[] = ""
    io = stdout
    if !verbose
        io = IOBuffer()
    end
    println(io, "Searching for MAiNGO...")

    if preferred == MAINGO_JLL || preferred === nothing
        println(io, "Attempting to use MAiNGO_jll...")
        MAiNGO.environment_status[] = findMAiNGO_jll(io)
        if MAiNGO.environment_status[] != MAINGO_JLL
            @warn("Did not find the preferred option MAiNGO_jll. Check that the package is properly installed. Proceeding to check for alternatives.")
            if haskey(ENV, "MAINGO_LIB") || c_api !== nothing
                println(io, "Attempting to use C-API...")
                lib_path = c_api === nothing ? ENV["MAINGO_LIB"] : c_api
                MAiNGO.environment_status[] = findMAiNGO_capi(io, lib_path)
            end
            if MAinGO.environment_status[] == MAINGO_NOT_FOUND &&
               (haskey(ENV, "MAINGO_EXEC") || standalone !== nothing)
                println(io, "Attempting to use standalone version...")
                standalone_path = standalone === nothing ? ENV["MAINGO_EXEC"] : standalone
                MAiNGO.environment_status[] = findMAiNGO_standalone(io,
                                                                    standalone_path)
            end
        end
    else
        println(io, "Attempting to use C-API...")
        if haskey(ENV, "MAINGO_LIB")
            lib_path = c_api === nothing ? ENV["MAINGO_LIB"] : c_api
        else
            lib_path = c_api === nothing ? "" : c_api
        end
        MAiNGO.environment_status[] = findMAiNGO_capi(io, lib_path)
        if MAiNGO.environment_status[] != C_API
            @warn("Unable to use the preferred option C-API. Make sure the solver has been separately downloaded, and that you properly set the MAINGO_LIB environment variable to the shared_parser library file. Proceeding to check for alternatives.")
            if haskey(ENV, "MAINGO_EXEC") || standalone !== nothing
                println(io, "Attempting to use standalone version...")
                standalone_path = standalone === nothing ? ENV["MAINGO_EXEC"] : standalone
                MAiNGO.environment_status[] = findMAiNGO_standalone(io,
                                                                    standalone_path)
            end
            if MAiNGO.environment_status[] == MAINGO_NOT_FOUND
                println(io, "Attempting to use MAiNGO_jll...")
                MAiNGO.environment_status[] = findMAiNGO_jll(io)
            end
        end
    end

    if MAiNGO.environment_status[] == MAINGO_NOT_FOUND
        @warn("No version of MAiNGO found. Please check that you have either installed the MAiNGO_jll package, or downloaded the solver seperately and properly set the MAINGO_EXEC or MAINGO_LIB environment variable.")
    elseif MAiNGO.environment_status[] == STANDALONE
        @warn("Using the standalone version of MAiNGO. This requires reading and writing files to memory, which may increase runtimes.")
    end
end
