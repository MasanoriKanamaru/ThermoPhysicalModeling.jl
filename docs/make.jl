using ThermoPhysicalModeling
using Documenter

DocMeta.setdocmeta!(ThermoPhysicalModeling, :DocTestSetup, :(using ThermoPhysicalModeling); recursive=true)

makedocs(;
    modules=[ThermoPhysicalModeling],
    repo="https://github.com/MasanoriKanamaru/ThermoPhysicalModeling.jl/blob/{commit}{path}#{line}",
    sitename="ThermoPhysicalModeling.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://MasanoriKanamaru.github.io/ThermoPhysicalModeling.jl",
        assets=["assets/favicon.ico"],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/MasanoriKanamaru/ThermoPhysicalModeling.jl",
)
