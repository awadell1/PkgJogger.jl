using PkgJogger
using Documenter

DocMeta.setdocmeta!(PkgJogger, :DocTestSetup, :(using PkgJogger); recursive=true)

makedocs(;
    modules=[PkgJogger],
    authors="Alexius Wadell <awadell@gmail.com> and contributors",
    repo="https://github.com/awadell1/PkgJogger.jl/blob/{commit}{path}#{line}",
    sitename="PkgJogger.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://awadell1.github.io/PkgJogger.jl",
        assets=String[],
        analytics = "G-V9E0Q8BDHR",
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/awadell1/PkgJogger.jl",
    devbranch="main",
)
