



#=============================================
Generate 𝐹 and ∇ₓ𝐹 from user input
=============================================#

"""
    F, ∇ₓF = state_function_and_Jacobian(Ts, Gs, nb)

Returns the state function `F` and its jacobian, `∇ₓF`.
"""
function state_function_and_Jacobian(Ts::Tuple, Gs::Tuple, nb)
    nt = length(Ts)
    tracers(x) = state_to_tracers(x, nb, nt)
    tracer(x,i) = state_to_tracer(x, nb, nt, i)
    T(p) = blockdiag([Tⱼ(p) for Tⱼ in Ts]...) # Big T (linear part)
    function G(x,p)
        xs = tracers(x)
        return reduce(vcat, [Gⱼ(xs..., p) for Gⱼ in Gs]) # nonlinear part
    end
    F(x,p) = G(x,p) - reduce(vcat, [Tⱼ(p) * tracer(x,j) for (j,Tⱼ) in enumerate(Ts)])
    ∇ₓG(x,p) = local_jacobian(Gs, x, p, nt, nb)     # Jacobian of nonlinear part
    ∇ₓF(x,p) = ∇ₓG(x,p) - T(p)       # full Jacobian ∇ₓ𝐹(𝑥) = -T + ∇ₓ𝐺(𝑥)
    return F, ∇ₓF
end
function state_function_and_Jacobian(T, G)
    F(x,p) = G(x,p) - T(p) * x                     # full 𝐹(𝑥) = -T 𝑥 + 𝐺(𝑥)
    ∇ₓG(x,p) = sparse(Diagonal(localderivative(G, x, p))) # Jacobian of nonlinear part
    ∇ₓF(x,p) = ∇ₓG(x,p) - T(p)       # full Jacobian ∇ₓ𝐹(𝑥) = -T + ∇ₓ𝐺(𝑥)
    return F, ∇ₓF
end

"""
    localderivative(G, x, p)
    localderivative(Gᵢ, xs, i, p)
    localderivative(Gᵢ, dx, xs, i, p)

Returns the "local" derivative of `G` (or `Gᵢ`), i.e., equivalent to the vector

```
dualpart.(G(x .+ ε, p))
```

but using ForwardDiff's Jacobian instead.
"""
function localderivative(G, x, p) # for single tracer
    return vec(ForwardDiff.jacobian(λ -> G(x .+ λ, p), [0.0]))
end
function localderivative(Gᵢ, xs, j, p) # for multiple tracers
    return vec(ForwardDiff.jacobian(λ -> Gᵢ(perturb_tracer(xs,j,λ)..., p), [0.0]))
end
function localderivative(Gᵢ!, dx, xs, j, p) # if Gᵢ are in-place
    return vec(ForwardDiff.jacobian((dx,λ) -> Gᵢ!(dx, perturb_tracer(xs,j,λ)..., p), dx, [0.0]))
end
perturb_tracer(xs, j, λ) = (xs[1:j-1]..., xs[j] .+ λ, xs[j+1:end]...)

function inplace_state_function_and_Jacobian(Ts::Tuple, Gs::Tuple, nb)
    nt = length(Ts)
    tracers(x) = state_to_tracers(x, nb, nt)
    tracer(x,i) = state_to_tracer(x, nb, nt, i)
    T(p) = blockdiag([Tⱼ(p) for Tⱼ in Ts]...) # Big T (linear part)
    #F(x,p) = G(x,p) - T(p) * x                     # full 𝐹(𝑥) = -T 𝑥 + 𝐺(𝑥)
    function F!(dx,x,p)
        xs = tracers(x)
        for (j, (Tⱼ, Gⱼ!)) in enumerate(zip(Ts, Gs))
            ij = tracer_indices(nb,nt,j)
            @views dx[ij] .= Gⱼ!(dx[ij], xs..., p)
            @views dx[ij] .-= Tⱼ(p) * x[ij]
        end
        return dx
    end
    ∇ₓG(x,p) = inplace_local_jacobian(Gs, x, p, nt, nb)     # Jacobian of nonlinear part
    ∇ₓF(x,p) = ∇ₓG(x,p) - T(p)       # full Jacobian ∇ₓ𝐹(𝑥) = -T + ∇ₓ𝐺(𝑥)
    return F!, ∇ₓF
end


export state_function_and_Jacobian, inplace_state_function_and_Jacobian

"""
    F, ∇ₓF = state_function_and_Jacobian(Ts, Gs, nb)

Returns the state function `F` and its jacobian, `∇ₓF`.
"""
function split_state_function_and_Jacobian(Ts::Tuple, Ls::Tuple, NLs::Tuple, nb)
    nt = length(Ts)
    tracers(x) = state_to_tracers(x, nb, nt)
    T(p) = blockdiag([Tⱼ(p) for Tⱼ in Ts]...) # Big T (linear part)
    NL(x,p) = reduce(vcat, [NLⱼ(tracers(x)..., p) for NLⱼ in NLs]) # nonlinear part
    L(x,p) = reduce(vcat, [Lⱼ(tracers(x)..., p) for Lⱼ in Ls]) # nonlinear part
    F(x,p) = NL(x,p) + L(x,p) - T(p) * x                     # full 𝐹(𝑥) = -T 𝑥 + 𝐺(𝑥)
    ∇ₓNL(x,p) = local_jacobian(NLs, x, p, nt, nb)     # Jacobian of nonlinear part
    ∇ₓL(p) = local_jacobian(Ls, zeros(nt*nb), p, nt, nb)     # Jacobian of nonlinear part
    ∇ₓF(x,p) = ∇ₓNL(x,p) + ∇ₓL(p) - T(p)       # full Jacobian ∇ₓ𝐹(𝑥) = -T + ∇ₓ𝐺(𝑥)
    return F, L, NL, ∇ₓF, ∇ₓL, ∇ₓNL, T
end
function split_state_function_and_Jacobian(T, L, NL, nb)
    F(x,p) = NL(x,p) + L(x,p) - T(p) * x                     # full 𝐹(𝑥)
    ∇ₓNL(x,p) = sparse(Diagonal(localderivative(NL, x, p))) # Jacobian of nonlinear part
    ∇ₓL(p) = sparse(Diagonal(localderivative(L, x, p)))     # Jacobian of nonlinear part
    ∇ₓF(x,p) = ∇ₓNL(x,p) + ∇ₓL(p) - T(p)       # full Jacobian ∇ₓ𝐹(𝑥) = -T + ∇ₓ𝐺(𝑥)
    return F, L, NL, ∇ₓF, ∇ₓL, ∇ₓNL, T
end
export split_state_function_and_Jacobian

function local_jacobian(Gs, x, p, nt, nb)
    return reduce(vcat, [local_jacobian_row(Gⱼ, x, p, nt, nb) for Gⱼ in Gs])
end
function inplace_local_jacobian(Gs, x, p, nt, nb)
    return reduce(vcat, [inplace_local_jacobian_row(Gⱼ!, x, p, nt, nb) for Gⱼ! in Gs])
end

function local_jacobian_row(Gᵢ, x, p, nt, nb)
    tracers(x) = state_to_tracers(x, nb, nt)
    return reduce(hcat, [sparse(Diagonal(localderivative(Gᵢ, tracers(x), j, p))) for j in 1:nt])
end
function inplace_local_jacobian_row(Gᵢ!, x, p, nt, nb)
    tracers(x) = state_to_tracers(x, nb, nt)
    dx = Vector{Float64}(undef,nb)
    return reduce(hcat, [sparse(Diagonal(localderivative(Gᵢ!, dx, tracers(x), j, p))) for j in 1:nt])
end

#=============================================
Generate 𝑓 and derivatives from user input
=============================================#

function generate_objective(ωs, μx, σ²x, v, ωp)
    nt, nb = length(ωs), length(v)
    tracers(x) = state_to_tracers(x, nb, nt)
    f(x, p) = ωp * mismatch(p) +
        sum([ωⱼ * mismatch(xⱼ, μⱼ, σⱼ², v) for (ωⱼ, xⱼ, μⱼ, σⱼ²) in zip(ωs, tracers(x), μx, σ²x)])
    return f
end


function generate_∇ₓobjective(ωs, μx, σ²x, v)
    nt, nb = length(ωs), length(v)
    tracers(x) = state_to_tracers(x, nb, nt)
    ∇ₓf(x, p) = reduce(hcat, [ωⱼ * ∇mismatch(xⱼ, μⱼ, σⱼ², v) for (ωⱼ, xⱼ, μⱼ, σⱼ²) in zip(ωs, tracers(x), μx, σ²x)])
    return ∇ₓf
end

function generate_∇ₚobjective(ωp)
    ∇ₚf(x, p) = ωp * ∇mismatch(p)
    return ∇ₚf
end

generate_objective_and_derivatives(ωs, μx, σ²x, v, ωp) =
    generate_objective(ωs, μx, σ²x, v, ωp),
    generate_∇ₓobjective(ωs, μx, σ²x, v),
    generate_∇ₚobjective(ωp)

export generate_objective, generate_∇ₓobjective, generate_∇ₚobjective
export generate_objective_and_derivatives


"""
    mismatch(x, xobs, σ²xobs, v)

Volume-weighted mismatch of modelled tracer `x` against observed mean, `xobs`, given observed variance, `σ²xobs`, and volumes `v`.
"""
function mismatch(x, xobs, σ²xobs, v)
    δx = x - xobs
    W = Diagonal(v ./ σ²xobs)
    return 0.5 * transpose(δx) * W * δx / (transpose(xobs) * W * xobs)
end
mismatch(x, ::Missing, args...) = 0

"""
    ∇mismatch(x, xobs, σ²xobs, v)

Adjoint of the gradient of `mismatch(x, xobs, σ²xobs, v)`.
"""
function ∇mismatch(x, xobs, σ²xobs, v)
    δx = x - xobs
    W = Diagonal(v ./ σ²xobs)
    return transpose(W * δx) / (transpose(xobs) * W * xobs)
end
∇mismatch(x, ::Missing, args...) = transpose(zeros(length(x)))


#=============================================
multi-tracer norm
=============================================#

function volumeweighted_norm(nt, v)
    w = repeat(v, nt)
    return nrm(x) = transpose(x) * Diagonal(w) * x
end




