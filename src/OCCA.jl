"""
This `OCCA` module is used to load the OCCA matrix and grid for use in AIBECS.

!!! tip
    To load the OCCA matrix and grid, do
    ```
    julia> grd, T = OCCA.load()
    ```
    See *Forget* (2010) for more details

!!! note
    The files, that are downloaded from a public and persistant URL in FigShare,
    were created with the code available at https://github.com/briochemc/OceanCirculations.
"""
module OCCA

using SparseArrays          # For sparse matrix
using DataDeps              # For storage location of data
using Downloads
using JLD2                  # For saving circulation as JLD2 format
using CodecZlib             # for JLD2 compression JLD2
using Unitful               # for units
using Reexport
@reexport using OceanGrids            # To store the grid

function fallback_download(remotepath, localdir)
    @assert(isdir(localdir))
    filename = basename(remotepath)  # only works for URLs with filename as last part of name
    localpath = joinpath(localdir, filename)
    Downloads.download(remotepath, localpath)
    return localpath
end

# OCCA URLs
function url(; version="")
    url_start = "https://files.figshare.com/"
    version == ""             ? "$(url_start)28336173/OCCA.jld2" :
    OCCAversionerror(version)
end

OCCAversionerror(version) = error("""`$version` is not a valid OCCA circulation name.

                                  Only valid version is the default (`version=""`).

                                  See *Forget* (2010) for more details on OCCA.""")

# OCCA Hashes
function sha(; version="")
    version == "" ? "8949a90564b0e7c68e7da0fbdb63ac4b49a84afc982f5bf6def72649a482f412" :
    OCCAversionerror(version)
end

# Create registry entry for OCCA in JLD2 format
function register_OCCA(; version="")
    register(
        DataDep(
            "AIBECS-OCCA",
            """
            References:
            - $(citation())
            """,
            url(version=version),
            sha(version=version),
            fetch_method = fallback_download
        )
    )
    return nothing
end

"""
    load

Returns the grid and the transport matrix.

!!! tip
    To load the OCCA matrix and grid, do
    ```
    julia> grd, T = OCCA.load()
    ```
    See *Forget* (2010) for more details
"""
function load(; version="")
    register_OCCA(version=version)
    jld2_file = @datadep_str string("AIBECS-OCCA/", "OCCA.jld2")
    @info """You are about to use the OCCA model.
          If you use it for research, please cite:

          - $(citation())

          You can find the corresponding BibTeX entries in the CITATION.bib file
          at the root of the AIBECS.jl package repository.
          (Look for the "Forget_2010" key.)
          """
    jldopen(jld2_file) do file
        file["grid"], ustrip.(file["T"])
    end
end

citation() = "Forget, G., 2010: Mapping Ocean Observations in a Dynamical Framework: A 2004–06 Ocean Atlas. J. Phys. Oceanogr., 40, 1201–1221, https://doi.org/10.1175/2009JPO4043.1"

versions() = [""]

end # end module

export OCCA

