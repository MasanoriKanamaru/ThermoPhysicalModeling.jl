

# ****************************************************************
#         Types of solvers for heat conduction equations
# ****************************************************************

abstract type HeatConductionSolver end

"""
Singleton type of the forward Euler method
"""
struct ForwardEulerSolver <: HeatConductionSolver end
const ForwardEuler = ForwardEulerSolver()

"""
Singleton type of the backward Euler method
"""
struct BackwardEulerSolver <: HeatConductionSolver end
const BackwardEuler = BackwardEulerSolver()

"""
Singleton type of the Crank-Nicolson method
"""
struct CrankNicolsonSolver <: HeatConductionSolver end
const CrankNicolson = CrankNicolsonSolver()


# ****************************************************************
#                      1D heat conduction
# ****************************************************************

"""
    forward_temperature(stpm::SingleTPM, nₜ::Integer)

Calculate the temperature for the next time step (`nₜ + 1`) based on 1D heat conductivity equation.

TO DO: Allow selection of boundary conditions and solvers

# Arguments
- `stpm` : Thermophysical model for a single asteroid
- `nₜ`   : Index of the current time step
"""
function update_temperature!(stpm::SingleTPM, nₜ::Integer)
    λ = stpm.thermo_params.λ
    Tⱼ   = @views stpm.temperature[:, :, nₜ  ]
    Tⱼ₊₁ = @views stpm.temperature[:, :, nₜ+1]

    ## Forward Euler method
    @. Tⱼ₊₁[begin+1:end-1, :] = @views (1-2λ')*Tⱼ[begin+1:end-1, :] + λ'*(Tⱼ[begin+2:end, :] + Tⱼ[begin:end-2, :])

    ## Boundary conditions
    update_surface_temperature!(stpm, nₜ+1, Radiation)  # Upper boundary condition of radiation
    update_bottom_temperature!(stpm, nₜ+1, Insulation)  # Lower boundary condition of insulation
end


"""
    forward_temperature(btpm::BinaryTPM, nₜ::Integer)

Calculate the temperature for the next time step (`nₜ + 1`) based on 1D heat conductivity equation.

# Arguments
- `btpm` : Thermophysical model for a binary asteroid
- `nₜ`   : Index of the current time step
"""
function update_temperature!(btpm::BinaryTPM, nₜ::Integer)
    update_temperature!(btpm.pri, nₜ)
    update_temperature!(btpm.sec, nₜ)
end


# ****************************************************************
#                 Types of boundary conditions
# ****************************************************************

abstract type BoundaryCondition end

"""
Singleton type of radiation boundary condition
"""
struct RadiationBoundaryCondition <: BoundaryCondition end
const Radiation = RadiationBoundaryCondition()

"""
Singleton type of insulation boundary condition
"""
struct InsulationBoundaryCondition <: BoundaryCondition end
const Insulation = InsulationBoundaryCondition()

"""
Singleton type of isothermal boundary condition
"""
struct IsothermalBoundaryCondition <: BoundaryCondition end
const Isothermal = IsothermalBoundaryCondition()


# ****************************************************************
#                    Upper boundary condition
# ****************************************************************

"""
    update_surface_temperature!(stpm::SingleTPM, nₜ::Integer, ::RadiationBoundaryCondition)

Update surface temperature under radiation boundary condition using Newton's method

# Arguments
- `stpm`      : Thermophysical model for a single asteroid
- `nₜ`        : Index of the current time step
- `Radiation` : Singleton of `RadiationBoundaryCondition` to select boundary condition
"""
function update_surface_temperature!(stpm::SingleTPM, nₜ::Integer, ::RadiationBoundaryCondition)
    for nₛ in eachindex(stpm.shape.faces)
        P    = stpm.thermo_params.P
        l    = (stpm.thermo_params.l    isa Real ? stpm.thermo_params.l    : stpm.thermo_params.l[nₛ]   )
        Γ    = (stpm.thermo_params.Γ    isa Real ? stpm.thermo_params.Γ    : stpm.thermo_params.Γ[nₛ]   )
        A_B  = (stpm.thermo_params.A_B  isa Real ? stpm.thermo_params.A_B  : stpm.thermo_params.A_B[nₛ] )
        A_TH = (stpm.thermo_params.A_TH isa Real ? stpm.thermo_params.A_TH : stpm.thermo_params.A_TH[nₛ])
        ε    = (stpm.thermo_params.ε    isa Real ? stpm.thermo_params.ε    : stpm.thermo_params.ε[nₛ]   )
        Δz   = stpm.thermo_params.Δz

        F_sun, F_scat, F_rad = stpm.flux[nₛ, :]
        F_total = flux_total(A_B, A_TH, F_sun, F_scat, F_rad)
        update_surface_temperature!((@views stpm.temperature[:, nₛ, nₜ]), F_total, P, l, Γ, ε, Δz)
    end
end


"""
    update_surface_temperature!(T::AbstractVector, F_total::Real, k::Real, l::Real, Δz::Real, ε::Real)

Newton's method to update the surface temperature under radiation boundary condition.

# Arguments
- `T`       : 1-D array of temperatures
- `F_total` : Total energy absorbed by the facet
- `Γ`       : Thermal inertia [tiu]
- `P`       : Period of thermal cycle [sec]
- `Δz̄`      : Non-dimensional step in depth, normalized by thermal skin depth `l`
- `ε`       : Emissivity
"""
function update_surface_temperature!(T::AbstractVector, F_total::Float64, P::Float64, l::Float64, Γ::Float64, ε::Float64, Δz::Float64)
    Δz̄ = Δz / l    # Dimensionless length of depth step
    εσ = ε * σ_SB

    for _ in 1:20
        T_pri = T[begin]

        f = F_total + Γ / √(4π * P) * (T[begin+1] - T[begin]) / Δz̄ - εσ*T[begin]^4
        df = - Γ / √(4π * P) / Δz̄ - 4*εσ*T[begin]^3             
        T[begin] -= f / df

        err = abs(1 - T_pri / T[begin])
        err < 1e-10 && return
    end
end


"""
    update_surface_temperature!(stpm::SingleTPM, nₜ::Integer, ::InsulationBoundaryCondition)

Update surface temperature based on insulation boundary condition

# Arguments
- `stpm`       : Thermophysical model for a single asteroid
- `nₜ`         : Index of the current time step
- `Insulation` : Singleton of `InsulationBoundaryCondition` to select boundary condition
"""
function update_surface_temperature!(stpm::SingleTPM, nₜ::Integer, ::InsulationBoundaryCondition)
    for nₛ in eachindex(stpm.shape.faces)
        stpm.temperature[begin, nₛ, nₜ] = stpm.temperature[begin+1, nₛ, nₜ]
    end
end


"""
    update_surface_temperature!(stpm::SingleTPM, nₜ::Integer, ::IsothermalBoundaryCondition)

Update bottom temperature based on isothermal boundary condition

# Arguments
- `stpm`       : Thermophysical model for a single asteroid
- `nₜ`         : Index of the current time step
- `Isothermal` : Singleton of `IsothermalBoundaryCondition` to select boundary condition
"""
function update_surface_temperature!(stpm::SingleTPM, nₜ::Integer, ::IsothermalBoundaryCondition)
    # for nₛ in eachindex(stpm.shape.faces)
    #     stpm.temperature[begin, nₛ, nₜ] = T_upper
    # end
end


# ****************************************************************
#                    Lower boundary condition
# ****************************************************************

"""
    update_bottom_temperature!(shape::ShapeModel, nₜ::Integer, ::InsulationBoundaryCondition)

Update bottom temperature based on insulation boundary condition

# Arguments
- `stpm`       : Thermophysical model for a single asteroid
- `nₜ`         : Index of the current time step
- `Insulation` : Singleton of `InsulationBoundaryCondition` to select boundary condition
"""
function update_bottom_temperature!(stpm::SingleTPM, nₜ::Integer, ::InsulationBoundaryCondition)
    for nₛ in eachindex(stpm.shape.faces)
        stpm.temperature[end, nₛ, nₜ] = stpm.temperature[end-1, nₛ, nₜ]
    end
end


"""
    update_bottom_temperature!(shape::ShapeModel, nₜ::Integer, ::IsothermalBoundaryCondition)

Update bottom temperature based on isothermal boundary condition

# Arguments
- `stpm`       : Thermophysical model for a single asteroid
- `nₜ`         : Index of the current time step
- `Isothermal` : Singleton of `IsothermalBoundaryCondition` to select boundary condition
"""
function update_bottom_temperature!(stpm::SingleTPM, nₜ::Integer, ::IsothermalBoundaryCondition)
    # for nₛ in eachindex(stpm.shape.faces)
    #     stpm.temperature[end, nₛ, nₜ] = T_lower
    # end
end
