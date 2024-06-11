# Setup the Documenter environment
using Pkg
Pkg.activate(@__DIR__)
Pkg.Registry.update()
Pkg.develop([
    PackageSpec(path=joinpath(@__DIR__, "..")),
    PackageSpec(path=joinpath(@__DIR__, "..", "test", "Example.jl"))
])
Pkg.instantiate()

# Load Code
using Documenter
using Documenter.Remotes: GitHub
using DocumenterInterLinks
using PkgJogger
using CUDA
using Example
@jog Example

DocMeta.setdocmeta!(PkgJogger, :DocTestSetup, :(using PkgJogger); recursive=true)

# Generate index.md from README.md
index_md = joinpath(@__DIR__, "src", "index.md")
readme_md = joinpath(@__DIR__, "..", "README.md")
open(index_md, "w") do io
    write(
        io,
        """
```@meta
EditURL = "$readme_md"
```
"""
    )
    write(io, read(readme_md, String))
end

# Interproject Links
links = InterLinks(
    "Julia" => "https://docs.julialang.org/en/v1/",
    "CUDA" => "https://cuda.juliagpu.org/stable/",
)

makedocs(;
    modules=[
        PkgJogger,
        JogExample,
        Base.get_extension(PkgJogger, :PkgJoggerCUDAExt),
    ],
    authors="Alexius Wadell <awadell@gmail.com> and contributors",
    repo=GitHub("awadell1", "PkgJogger.jl"),
    sitename="PkgJogger.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://awadell1.github.io/PkgJogger.jl",
        assets=String[],
        analytics="G-V9E0Q8BDHR",
    ),
    pages=[
        "Home" => "index.md",
        "Jogger" => "jogger.md",
        "Saving Results" => "io.md",
        "Continuous Benchmarking" => "ci.md",
        "Profiling" => "profiling.md",
        "Reference" => "reference.md",
    ],
    plugins=[links],
    checkdocs=:all,
)

deploydocs(;
    repo="github.com/awadell1/PkgJogger.jl",
    devbranch="main",
)

# Remove index.md
rm(joinpath(@__DIR__, "src", "index.md"))
