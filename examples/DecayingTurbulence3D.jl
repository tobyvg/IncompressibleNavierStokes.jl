# Little LSP hack to get function signatures, go    #src
# to definition etc.                                #src
if isdefined(@__MODULE__, :LanguageServer)          #src
    include("../src/IncompressibleNavierStokes.jl") #src
    using .IncompressibleNavierStokes               #src
end                                                 #src

# # Decaying Homogeneous Isotropic Turbulence - 3D
#
# In this example we consider decaying homogeneous isotropic turbulence,
# similar to the cases considered in [Kochkov2021](@cite) and
# [Kurz2022](@cite). The initial velocity field is created randomly, but with a
# specific energy spectrum. Due to viscous dissipation, the turbulent features
# eventually group to form larger visible eddies.

# We start by loading packages.
# A [Makie](https://github.com/JuliaPlots/Makie.jl) plotting backend is needed for plotting. `GLMakie` creates an interactive window (useful for real-time
# plotting), but does not work when building this example on GitHub.
# `CairoMakie` makes high-quality static vector-graphics plots.

using FFTW
#md using CairoMakie
using GLMakie #!md
using IncompressibleNavierStokes

# Case name for saving results
name = "DecayingTurbulence3D"

# Floating point precision
T = Float64

# Array type
ArrayType = Array
## using CUDA; ArrayType = CuArray
## using AMDGPU; ArrayType = ROCArray
## using oneAPI; ArrayType = oneArray
## using Metal; ArrayType = MtlArray

# Reynolds number
Re = T(10_000)

# A 3D grid is a Cartesian product of three vectors
n = 32
lims = T(0), T(1)
x = LinRange(lims..., n + 1)
y = LinRange(lims..., n + 1)
z = LinRange(lims..., n + 1)
plot_grid(x, y, z)

# Build setup and assemble operators
setup = Setup(x, y, z; Re, ArrayType);

# Since the grid is uniform and identical for x, y, and z, we may use a
# specialized spectral pressure solver
pressure_solver = SpectralPressureSolver(setup);

# Initial conditions
u₀, p₀ = random_field(setup; pressure_solver)

# Solve unsteady problem
u, p, outputs = solve_unsteady(
    setup,
    u₀,
    p₀,
    (T(0), T(1));
    Δt = T(0.001),
    pressure_solver,
    processors = (
        rtp = realtimeplotter(;
            setup,
            plot = fieldplot,
            ## plot = energy_history_plot,
            ## plot = energy_spectrum_plot,
            nupdate = 1,
        ),
        ## anim = animator(; setup, path = "vorticity.mkv", nupdate = 20),
        ## vtk = vtk_writer(; setup, nupdate = 10, dir = "output/$name", filename = "solution"),
        ## field = fieldsaver(; setup, nupdate = 10),
        log = timelogger(; nupdate = 1),
    ),
);

# Field plot
outputs[1]

# Energy history
outputs[2]

# Energy spectrum
outputs[3]

# ## Post-process
#
# We may visualize or export the computed fields `(u, p)`

# Export to VTK
save_vtk(setup, u, p, "output/solution")

# Plot pressure
plot_pressure(setup, p)

# Plot velocity
plot_velocity(setup, u)

# Plot vorticity
plot_vorticity(setup, u)
