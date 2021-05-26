module Astroshaper

using LinearAlgebra
using StaticArrays
using StructArrays

using GLMakie  # 3D visulaization

include("constants.jl")
export AU, G, GM☉, SOLAR_CONST, c₀, σ_SB

include("obj.jl")
export loadobj

include("coordinates.jl")
export rotateX, rotateY, rotateZ
export rotateX!, rotateY!, rotateZ!

include("kepler.jl")
export OrbitalElements
export ref_to_orb!, ref_to_orb
export orb_to_ref!, orb_to_ref

include("spin.jl")
export Spin, setSpinParams

include("smesh.jl")
export SMesh

include("shape.jl")
export Shape, setShapeModel, findVisibleFaces!, showshape

include("YORP.jl")
export getNetTorque, getNetTorque_shadowing, torque2rate, getTimeScale

include("thermophysics.jl")

include("nbody.jl")
export Particle

include("hermite4.jl")
export run_sim

end # module Astroshaper
