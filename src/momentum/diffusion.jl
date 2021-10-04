"""
    diffusion!(d, Jac, V, t, setup, getJacobian)

Evaluate diffusive terms and optionally Jacobian. Fill result in `d`. Return `Jac`.
"""
function diffusion!(d, ∇d, V, t, setup, getJacobian)
    @unpack visc = setup.case
    @unpack Nu, Nv, indu, indv = setup.grid
    @unpack N1, N2, N3, N4 = setup.grid
    @unpack Dux, Duy, Dvx, Dvy = setup.discretization
    @unpack Diffu, Diffv, yDiffu, yDiffv = setup.discretization
    @unpack Su_ux, Su_uy, Su_vx, Sv_vx, Sv_vy, Sv_uy = setup.discretization
    @unpack Aν_ux, Aν_uy, Aν_vx, Aν_vy = setup.discretization

    uₕ = @view V[indu]
    vₕ = @view V[indv]
    du = @view d[indu]
    dv = @view d[indv]

    if visc == "laminar"
        # D2u = Diffu * uₕ + yDiffu
        mul!(du, Diffu, uₕ)
        du .+= yDiffu

        # D2v = Diffv * vₕ + yDiffv
        mul!(dv, Diffv, vₕ)
        dv .+= yDiffv

        getJacobian && (∇d .= blockdiag(Diffu, Diffv))
    elseif visc ∈ ["qr", "LES", "ML"]
        # Get components of strain tensor and its magnitude;
        # The magnitude S_abs is evaluated at pressure points
        S11, S12, S21, S22, S_abs, S_abs_u, S_abs_v =
            strain_tensor(V, t, setup, getJacobian)

        # Turbulent viscosity at all pressure points
        ν_t = turbulent_viscosity(S_abs, setup)

        # To compute the diffusion, we need ν_t at ux, uy, vx and vy locations
        # This means we have to reverse the process of strain_tensor.m: go
        # From pressure points back to the ux, uy, vx, vy locations
        ν_t_ux, ν_t_uy, ν_t_vx, ν_t_vy = interpolate_ν(ν_t, setup)

        # Now the total diffusive terms (laminar + turbulent) is as follows
        # Note that the factor 2 is because
        # Tau = 2*(ν+ν_t)*S(u), with S(u) = 0.5*(∇u + (∇u)^T)

        ν = 1 / setup.fluid.Re # Molecular viscosity

        du .= Dux * (2 .* (ν .+ ν_t_ux) .* S11[:]) .+ Duy * (2 .* (ν .+ ν_t_uy) .* S12[:])
        dv .= Dvx * (2 .* (ν .+ ν_t_vx) .* S21[:]) .+ Dvy * (2 .* (ν .+ ν_t_vy) .* S22[:])

        if getJacobian
            # Freeze ν_t, i.e. we skip the derivative of ν_t wrt V in
            # The Jacobian
            Jacu1 =
                Dux * 2 * spdiagm(ν .+ ν_t_ux) * Su_ux +
                Duy * 2 * spdiagm(ν .+ ν_t_uy) * 1 / 2 * Su_uy
            Jacu2 = Duy * 2 * spdiagm(ν .+ ν_t_uy) * 1 / 2 * Sv_uy
            Jacv1 = Dvx * 2 * spdiagm(ν .+ ν_t_vx) * 1 / 2 * Su_vx
            Jacv2 =
                Dvx * 2 * spdiagm(ν .+ ν_t_vx) * 1 / 2 * Sv_vx +
                Dvy * 2 * spdiagm(ν .+ ν_t_vy) * Sv_vy
            Jacu = [Jacu1 Jacu2]
            Jacv = [Jacv1 Jacv2]

            if visc == "LES"
                # Smagorinsky
                C_S = setup.visc.Cs
                filter_length = deltax
                K = C_S^2 * filter_length^2
            elseif visc == "qr"
                C_d = deltax^2 / 8
                K = C_d * 0.5 * (1 - α / C_d)^2
            elseif visc == "ML" # Mixing-length
                lm = setup.visc.lm # Mixing length
                K = (lm^2)
            else
                error("wrong value for visc parameter")
            end
            tmpu1 =
                2 * Dux * spdiagm(S11) * Aν_ux * S_abs_u +
                2 * Duy * spdiagm(S12) * Aν_uy * S_abs_u
            tmpu2 = 2 * Duy * spdiagm(S12) * Aν_uy * S_abs_v
            tmpv1 = 2 * Dvx * spdiagm(S21) * Aν_vx * S_abs_u
            tmpv2 =
                2 * Dvx * spdiagm(S21) * Aν_vx * S_abs_v +
                2 * Dvy * spdiagm(S22) * Aν_vy * S_abs_v
            Jacu += K * [tmpu1 tmpu2]
            Jacv += K * [tmpv1 tmpv2]

            ∇d .= [Jacu; Jacv]
        end
    elseif visc == "keps"
        error("k-e implementation in diffusion.m not finished")
    else
        error("wrong specification of viscosity model")
    end

    d, ∇d
end