![Logo](docs/src/assets/logo_text_dots.png)

# IncompressibleNavierStokes

| Documentation | Workflows | Code coverage | Quality assurance |
| :-----------: | :-------: | :-----------: | :---------------: |
| [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://agdestein.github.io/IncompressibleNavierStokes.jl/stable) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://agdestein.github.io/IncompressibleNavierStokes.jl/dev) | [![Build Status](https://github.com/agdestein/IncompressibleNavierStokes.jl/workflows/CI/badge.svg)](https://github.com/agdestein/IncompressibleNavierStokes.jl/actions) | [![Coverage](https://codecov.io/gh/agdestein/IncompressibleNavierStokes.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/agdestein/IncompressibleNavierStokes.jl) | [![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl) |

This package implements energy-conserving solvers for the incompressible Navier-Stokes
equations on a staggered Cartesian grid. It is based on the Matlab package
[INS2D](https://github.com/bsanderse/INS2D)/[INS3D](https://github.com/bsanderse/INS3D). The simulations can be run on the single/multithreaded CPUs or Nvidia GPUs.

This package also provides experimental support for neural closure models for
large eddy simulation.

## Installation

To install IncompressibleNavierStokes, open up a Julia-REPL, type `]` to get
into Pkg-mode, and type:

```
add IncompressibleNavierStokes
```

which will install the package and all dependencies to your local environment.
Note that IncompressibleNavierStokes requires Julia version `1.7` or above.

See the
[Documentation](https://agdestein.github.io/IncompressibleNavierStokes.jl/dev/generated/LidDrivenCavity2D/)
for examples of some typical workflows. More examples can be found in the
[`examples`](examples) directory.

## Gallery

The velocity and pressure fields may be visualized in a live session using
[Makie](https://github.com/JuliaPlots/Makie.jl). Alternatively,
[ParaView](https://www.paraview.org/) may be used, after exporting individual
snapshot files using the `save_vtk` function, or the full time series using the
`VTKWriter` processor.

| ![](assets/examples/Actuator2D.png) | ![](assets/examples/BackwardFacingStep2D.png) | ![](assets/examples/DecayingTurbulence2D.png) | ![](assets/examples/TaylorGreenVortex2D.png) |
|:-:|:-:|:-:|:-:|
| [Actuator (2D)](examples/Actuator2D.jl) | [Backward Facing Step (2D)](examples/BackwardFacingStep2D.jl) | [Decaying Turbulence (2D)](examples/DecayingTurbulence2D.jl) | [Taylor-Green Vortex (2D)](examples/TaylorGreenVortex2D.jl) |
| ![](assets/examples/Actuator3D.png) | ![](assets/examples/BackwardFacingStep3D.png) | ![](assets/examples/DecayingTurbulence3D.png) | ![](assets/examples/TaylorGreenVortex3D.png) |
| [Actuator (3D)](examples/Actuator3D.jl) | [Backward Facing Step (3D)](examples/BackwardFacingStep3D.jl) | [Decaying Turbulence (3D)](examples/DecayingTurbulence3D.jl) | [Taylor-Green Vortex (3D)](examples/TaylorGreenVortex3D.jl) |


## Demo

The following example code  using a negative body force on a small rectangle
with an unsteady inflow. It simulates a wind turbine (actuator) under varying
wind conditions.

```julia
using GLMakie
using IncompressibleNavierStokes

# A 2D grid is a Cartesian product of two vectors
n = 40
x = LinRange(0.0, 10.0, 5n + 1)
y = LinRange(-2.0, 2.0, 2n + 1)

# Boundary conditions: Unsteady BC requires time derivatives
boundary_conditions = (
    # Inlet, outlet
    (
        # Unsteady BC requires time derivatives
        DirichletBC(
            (dim, x, y, t) -> sin(π / 6 * sin(π / 6 * t) + π / 2 * (dim() == 1)),
            (dim, x, y, t) ->
                (π / 6)^2 *
                cos(π / 6 * t) *
                cos(π / 6 * sin(π / 6 * t) + π / 2 * (dim() == 1)),
        ),
        PressureBC(),
    ),

    # Sides
    (PressureBC(), PressureBC()),
)

# Actuator body force: A thrust coefficient `Cₜ` distributed over a thin rectangle
xc, yc = 2.0, 0.0 # Disk center
D = 1.0           # Disk diameter
δ = 0.11          # Disk thickness
Cₜ = 0.2          # Thrust coefficient
cₜ = Cₜ / (D * δ)
inside(x, y) = abs(x - xc) ≤ δ / 2 && abs(y - yc) ≤ D / 2
bodyforce(dim, x, y, t) = dim() == 1 ? -cₜ * inside(x, y) : 0.0

# Build setup and assemble operators
setup = Setup(x, y; Re = 100.0, boundary_conditions, bodyforce);

# Initial conditions (extend inflow)
u₀, p₀ = create_initial_conditions(setup, (dim, x, y) -> dim() == 1 ? 1.0 : 0.0);

# Solve unsteady Navier-Stokes equations
u, p, outputs = solve_unsteady(
    setup, u₀, p₀, (0.0, 12.0);
    Δt = 0.05,
    processors = (
        animator(setup, "vorticity.mp4"; nupdate = 4),
        timelogger(),
    ),
)
```

The resulting animation is shown below.

https://github.com/agdestein/IncompressibleNavierStokes.jl/assets/40632532/6ee09a03-1674-46e0-843c-000f0b9b9527

## Similar projects

- [WaterLily.jl](https://github.com/weymouth/WaterLily.jl/)
  Incompressible solver with immersed boundaries
- [Oceananigans.jl](https://github.com/CliMA/Oceananigans.jl):
  Ocean simulations
- [ClimaCore.jl](https://github.com/CliMA/ClimaCore.jl):
  Atmospheric simulations
- [Trixi.jl](https://github.com/trixi-framework/Trixi.jl):
  High order solvers for various hyperbolic equations
- [Ferrite.jl](https://github.com/Ferrite-FEM/Ferrite.jl):
  Finite element discretizations
- [Gridap.jl](https://github.com/gridap/Gridap.jl):
  Finite element discretizations
- [FourierFlows.jl](https://github.com/FourierFlows/FourierFlows.jl):
  Pseudo-spectral discretizations
