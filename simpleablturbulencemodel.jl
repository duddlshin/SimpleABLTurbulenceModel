### A Pluto.jl notebook ###
# v0.19.46

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ f6fffe10-ab2a-46f1-beef-bd5fa7de02f6
using Plots, LaTeXStrings, PlutoUI, Measures

# ╔═╡ 6dd312f0-a859-11ef-15a3-27ed336cc0af
md"""

# Turbulence Modeling for the Atmospheric Boundary Layer
### By Ethan YoungIn Shin 
###### Last edit: 12/31/2024
"""


# ╔═╡ 063985b5-21e8-4f0b-b65a-e75c136b6b7d
md"""
### Lesson objectives
"""

# ╔═╡ b6eac708-a136-4cb8-90a0-1511fb62a829
md"""
In this notebook, we will learn what turbulence is and how to write our first turbulence model for atmospheric flow!
Turbulence models are an essential tool for accurately modeling flow in tons of applications! Any situation where we have fluid flow, we can model using computational fluid dynamics simulations! In this notebook, we will look at turbulence modeling in the context of atmospheric models.

By the end of this notebook, you will have made a simplified version of a turbulence model that is used in a real weather forecasting model!

"""

# ╔═╡ 16213d95-eda1-4f56-bf8e-105fb56b9cde
html"""<img src="https://www.weathercompany.com/wp-content/uploads/2024/02/hero-sky-dramatic-lightning-weather-shutterstock_2200924189.jpg" height=350> <figcaption style="font-size: 14px; color: gray;">Source: The Weather Company</figcaption>"""


# ╔═╡ f92529b4-3d28-43bd-917c-674e49a4405a
md"""
### 0. Pre-lessons on numerical methods
First, we will learn some basic numerical methods needed to solve equations in discretized form.
"""

# ╔═╡ 81bdc7ea-22c1-4e69-8a10-e9db43dc434a
md"""
#### 0.1 Finite difference
"""

# ╔═╡ 28492fc9-96e4-4b31-939e-11f328a689e9
md"""

2nd order central difference for the first derivative:

$\frac{f(z + \Delta z) - f(z - \Delta z)}{2 \Delta z} - f'(z) = \mathcal{O}(\Delta z^2)$

"""

# ╔═╡ d270a745-e0c9-43ec-a4d6-47cb17d2c77d
function ∂_∂𝑧(𝑧::Array{FT, 1}, 𝑓::Array{FT, 1}) where {FT <: AbstractFloat}
    n = length(𝑧)
    ∂𝑓_∂𝑧 = zeros(n)
    𝑧 = 𝑧[:]
    𝑓 = 𝑓[:]
    # 1st order forward and backward difference
    ∂𝑓_∂𝑧[1] = (𝑓[2] - 𝑓[1]) / (𝑧[2] - 𝑧[1])
    ∂𝑓_∂𝑧[2:n-1] = (𝑓[3:end] .- 𝑓[1:end-2]) ./ (𝑧[3:end] .- 𝑧[1:end-2])
    # 2nd order central difference
    ∂𝑓_∂𝑧[n] = (𝑓[n] - 𝑓[n-1]) / (𝑧[end] - 𝑧[end-1])

    return ∂𝑓_∂𝑧
end

# ╔═╡ 9258ae4d-038d-47e6-8dfa-926a14922009
md"""

2nd order central difference for the second derivative:

$\frac{f(z + \Delta z) - 2f(z) + f(z - \Delta z)}{\Delta z^2} - f''(z) = \mathcal{O}(\Delta z^2)$


"""

# ╔═╡ 2097169b-b9fb-4252-8d18-5975414c9922
function ∂²_∂𝑧²(𝑧::Array{FT, 1}, 𝑓::Array{FT, 1}) where {FT <: AbstractFloat}
    n = length(𝑧)
    ∂²𝑓_∂𝑧² = zeros(n)
    𝑧 = 𝑧[:]
    𝑓 = 𝑓[:]
    ∂²𝑓_∂𝑧²[1] = (𝑓[3] - 2*𝑓[2] + 𝑓[1]) / (𝑧[2] - 𝑧[1])^2
    ∂²𝑓_∂𝑧²[2:n-1] = (𝑓[3:end] .- 2*𝑓[2:end-1] .+ 𝑓[1:end-2]) ./ (𝑧[2:end-1] .- 𝑧[1:end-2]).^2
    ∂²𝑓_∂𝑧²[n] = (𝑓[n-2] - 2*𝑓[n-1] + 𝑓[n]) / (𝑧[n] - 𝑧[n-1])^2
    return ∂²𝑓_∂𝑧²
end

# ╔═╡ 2d1b7653-fb6d-4d09-8f8e-dd45c3c407eb
md"""
#### 0.2 Time integration
"""

# ╔═╡ 6eea1a75-d791-4c16-be20-319ea03679b7
md"""
Let an initial value problem be specified as follows:

$\frac{dy}{dt} = f(t,y),~ y(t_0)=y_0$

The function $f$ and initial conditions $t_0$, $y_0$ are provided.

How do we do numerical integration of this ordinary differential equations?
"""

# ╔═╡ 74a4d18b-0465-427d-ac2a-ba88e87544f9
md"""

We'l look at the 4th order Runge-Kutta method:

$y_{n+1} = y_n + \frac{1}{6} (k_1 + 2k_2 + 2k_3 + k_4) h$

$t_{n+1} = t_n + h$

for $n = 1, 2, 3, ...,$ using:

$k_1 = f(t_n, y_n)$
$k_2 = f(t_n + \frac{h}{2}, y_n + h\frac{k_1}{2})$
$k_3 = f(t_n + \frac{h}{2}, y_n + h\frac{k_2}{2})$
$k_4 = f(t_n + h, y_n + hk_3)$

"""

# ╔═╡ 59ae82f1-a469-4b6e-9fa9-65a06cf52fb0
md"""
Finite differencing and time integration are key to building atmospheric models. Of course, there are existing packages that have implementations of these. However, it is important to fully understand how the numerics in a model work, and a lot of times, especially in older codes for atmospheric models, you have manual numeric method implementations. Therefore, for the educational purpose of the notebook, we will proceed to use our just-written implementations!
"""

# ╔═╡ 594c390a-8ef4-475f-8f1f-d4d06f4f2162
md"""
### 1. What is the atmospheric boundary layer (ABL)? What is turbulence?
"""

# ╔═╡ 899fc27a-866e-4d3e-9952-0631c976dfba
html"""<img src="https://www.iop.org/sites/default/files/styles/original_optimised/public/2020-01/boundary-layer.jpg?itok=Ef-O_TuO" height=450> <figcaption style="font-size: 14px; color: gray;">Source: Institute of Physics</figcaption>"""


# ╔═╡ 18c4d6fb-8e48-4287-bf30-9f1221d70cc1
md"""
The atmospheric boundary layer (ABL) is the portion of the atmosphere that is influence by the presence of Earth’s surface [1]. It is where we humans live and do most of our interactions. So, why do we need models for the ABL? To name just a few examples, air pollution mixing, wildfire spreads, weather forecasting, wind energy. etc. ABL models give us tools to study our atmosphere as it pertains to our applications of interest.

"""

# ╔═╡ d2371ab3-036e-4587-857b-20eb6dea0757
md"""
##### One key aspect about the ABL that we will focus on today is turbulence.

You may recognize turbulence from your last plane ride. But it is much much more than a few instances of shaking motion in the air. Turbulence is what fundamentally dictates the flow characteristics of the ABL!

Here are some interesting facts about turbulence.

- **Turbulence is**
  - One of the unsolved problems of classical physics
  - Governing equations are known but there is no analytical solution to turbulent flow
  - Chaotic system, highly sensitive to initial conditions

- **Characteristics of turbulence:**
  - Unsteady and three dimensional
  - Random-like but with coherent structures
  - Enhanced mixing
  - Broadband in its energy spectrum

"""

# ╔═╡ 41cb1005-778c-4c90-a2ff-d1ecd7963271
html"""<img src="https://eepower.com/uploads/articles/Turbulence_can_negatively_impact_the_performance_of_wind_turbines.jpg" height=450> <figcaption style="font-size: 14px; color: gray;">Source: National Oceanic and Atmospheric Administration (NOAA)</figcaption>"""

# ╔═╡ feece485-f3ff-41cb-8ed7-ddb8cf2962de
md"""
This offshore wind farm shows a beautiful visual of turbulent wakes behind the wind turbines. How would understanding turbulence be of practical value in this scenario?
"""

# ╔═╡ 9ba7bdb2-7b71-4628-aa33-b789ebfa2576
md"""
### 2. Governing equations of the ABL
"""

# ╔═╡ 05daf599-352a-40f8-935a-c8db73dd20e2
md"""
In a model for the atmospheric boundary layer (ABL), we are solving simplified (time-averaged) equations for momentum and heat.

$\frac{\partial \overline{u}}{\partial t} = f(\bar{v} - v_G) - \textcolor{red}{\frac{\partial \overline{u'w'}}{\partial z}}$

$\frac{\partial \overline{v}}{\partial t} = f(u_G - \bar{u}) - \textcolor{red}{\frac{\partial \overline{v'w'}}{\partial z}}$

$\frac{\partial \overline{\theta}}{\partial t} = - \textcolor{red}{\frac{\partial \overline{w'\theta'}}{\partial z}}$

where $\overline{u}$, $\overline{v}$ are velocity components and $\overline{\theta}$ is a pressure-based (potential) temperature. I will explain $u_G$ and $v_G$ a few boxes down, but for now, they are constant velocity values high up in the air!

The red terms $\textcolor{red}{\frac{\partial \overline{u'w'}}{\partial z}}$, $\textcolor{red}{\frac{\partial \overline{v'w'}}{\partial z}}$, and $\textcolor{red}{\frac{\partial \overline{w'\theta'}}{\partial z}}$ are what we call 'unclosed' terms because they can't be solved analytically.

The goal of turbulence modeling is to provide a closure for these unclosed turbulent fluctuation terms $\overline{u'w'}$, $\overline{v'w'}$, and $\overline{w'\theta'}$.

"""

# ╔═╡ 4407e589-3689-4812-be78-cee0a0eb01d6
md"""
We model these turbulent fluxes using some strong assumptions that say that momentum and heat transfer in a turbulent flow can be modeled similar to viscous diffusion and are related to gradients of the mean statistics.

$\overline{u'w'} = - \nu_t \frac{\partial \overline{u}}{\partial z}$
$\overline{v'w'} = - \nu_t \frac{\partial \overline{v}}{\partial z}$ 
$\overline{w'\theta'} = - \alpha_t \frac{\partial \overline{\theta}}{\partial z}$ 

In these turbulence models, the main goal is to model these viscosity-like variables $\nu_t$ and $\alpha_t$.
"""

# ╔═╡ c6bc4cd1-f43c-4db7-971a-3515362793dc
md"""
So first, we express these governing equations in Julia. These are the equations we will integrate (march forward in time).
"""


# ╔═╡ 89016778-670d-4324-b982-1838b8de0122
md"""
#### 2.1 Initial conditions
"""

# ╔═╡ 42fb5324-9fb2-40ba-aef2-4e266d99ea8a
md"""
We also need to define the initial conditions for the problem.
But before we define them, I will explain what $u_G$ and $v_G$ are.
The variables $u_G$ and $v_G$ are theoretical wind components, called geostrophic winds, that result from a balance between the earth spinning and pressure gradients high up in the air. 


"""




# ╔═╡ e8ea1f8f-c40d-45c3-8825-39091ee88c26
html"""<img src="https://geography.name/wp-content/uploads/2015/09/FIG06_013-640x327.webp" height=300> <figcaption style="font-size: 14px; color: gray;">Source: https://geography.name/geostrophic-winds/.</figcaption>"""


# ╔═╡ 6c227761-505d-4034-a641-4c5593fe15e5
md"""
We shall see how the surface of the earth affects the wind flow, but for now, these theoretical velocities are what we set to be our initial conditions for our velocity components.

$u(z) = u_G$
$v(z) = v_G$

We will additionally define an artificial timestep:

$Δt=(0.1Δz^2)/max(\nu_t)$
"""

# ╔═╡ 1143350b-fc92-464f-a5df-42756d9534b8
md"""
#### 2.2 Boundary conditions
You cannot solve differential equations without boundary conditions. These are the boundary conditions that we introduce for the top and bottom of our 1D grid.
"""

# ╔═╡ 8f2ab920-c1d4-44a8-9517-6088fd15770e
md"""

Right at the surface, the wind has to come to a stop, right? 

So the lower boundary conditions are:

$u_{bottom} = 0$
$v_{bottom} = 0$

As I mentioned above, up in the sky, the wind is dictated by balance between the earth spinning and the pressure gradients. 

Therefore, the upper boundary conditions are: 

$u_{top} = u_G$
$v_{top} = v_G$ 

Let's assume the temperature $\theta$ is uniform throughout (this is a highly idealized situation!).

"""

# ╔═╡ e0611b52-5e7f-463b-9296-a699b3fec0d6
md"""
#### 2.3 Setting things up
"""

# ╔═╡ 352a053e-ad85-49e1-8379-d3e9d96bb90c
md"""
We will define some variables and technical settings that I've hidden away below. Feel free to check these out!

"""

# ╔═╡ 80689c95-175e-41e3-b68f-22daa2982983
begin
	# Variables
	u_G = 8               # Geostrophic wind speed (x-component) (m/s)
	v_G = 0               # Geostrophic wind speed (y-component) (m/s)
	Ω = 7.29e-5           # Angular speed of the Earth
	ϕ = 57.05             # Latitude
	𝑓 = 2 * Ω * sind(ϕ)   # A rotational effect on the Earth at the specific latitude
	Prₜ = 0.85            # Turbulent Prandtl number
	θ_ref = 289.5         # Reference potential temperature

	# How many artificial timesteps will we run forward our governing equations?
	nstep = 10000;

	# Vertical domain settings.
	Lz = 3000                                     # Top of the domain (m)
	nz = 129                                      # Number of grid points
	z = collect(range(0, stop=Lz, length=nz))     # The grid initialized
	Δz = z[2] - z[1];                             # Grid-cell size 

	println("Settings and variables")
end

# ╔═╡ a78da882-f05b-43bb-9c09-b9944827c69f
function f(u::Array{FT, 1},v::Array{FT, 1},θ::Array{FT, 1},νₜ::Array{FT, 1},αₜ::Array{FT, 1}) where {FT <: AbstractFloat} 

	# We'll use the chain rule here to compute the consecutive gradients 
	∂uw_∂z = - ∂_∂𝑧(z,νₜ) .* ∂_∂𝑧(z,u) .- νₜ .* ∂²_∂𝑧²(z,u)
	∂vw_∂z = - ∂_∂𝑧(z,νₜ) .* ∂_∂𝑧(z,v) .- νₜ .* ∂²_∂𝑧²(z,v)
	∂wθ_∂z = - ∂_∂𝑧(z,αₜ) .* ∂_∂𝑧(z,θ) .- αₜ .* ∂²_∂𝑧²(z,θ)
	
	# governing equations
	∂u_∂t = 𝑓 .* (v .- v_G) - ∂uw_∂z;
	∂v_∂t = 𝑓 .* (u_G .- u) - ∂vw_∂z;
	∂θ_∂t = - ∂wθ_∂z
	
	return ∂u_∂t, ∂v_∂t, ∂θ_∂t
end


# ╔═╡ cb6c51b9-b5fe-4161-ad12-aad1eef1af74
# RK4
function rk4(u::Array{FT, 1}, v::Array{FT, 1}, θ::Array{FT, 1}, Δt::FT, νₜ::Array{FT, 1}, αₜ::Array{FT, 1}) where {FT <: AbstractFloat}
    # Find rk4 coefficients
    k1_u, k1_v, k1_θ = f(u, v, θ, νₜ, αₜ);
    k2_u, k2_v, k2_θ = f(u.+k1_u.*Δt/2, v.+k1_v.*Δt/2, θ.+k1_θ.*Δt/2, νₜ, αₜ);
    k3_u, k3_v, k3_θ = f(u.+k2_u.*Δt/2, v.+k2_v.*Δt/2, θ.+k2_θ.*Δt/2, νₜ, αₜ);
    k4_u, k4_v, k4_θ = f(u.+k3_u.*Δt, v.+k3_v.*Δt, θ.+k3_θ.*Δt, νₜ, αₜ);
	
    # Update u, v, T
    u .+= (1/6) * (k1_u .+ 2*k2_u .+ 2*k3_u .+ k4_u) * Δt;
    v .+= (1/6) * (k1_v .+ 2*k2_v .+ 2*k3_v .+ k4_v) * Δt;
	θ .+= (1/6) * (k1_θ .+ 2*k2_θ .+ 2*k3_θ .+ k4_θ) * Δt;
  
    return u, v, θ
end

# ╔═╡ 2bbb432e-f038-4edf-abc0-70eabcb34073
# Initial conditions
function initial_conditions(u_G, v_G, θ_ref, Δz, νₜ)
	u = u_G*ones(length(z))
	v = v_G*ones(length(z))
	θ = θ_ref*ones(length(z)) 
	Δt = (0.1*Δz^2) / maximum(νₜ)
		
	return u, v, θ, Δt
end

# ╔═╡ ba5e58c5-0754-47d3-b27b-5162fb1b0e71
# Boundary conditions
function boundary_conditions(u::Array{FT,1}, v::Array{FT,1}, θ::Array{FT,1}) where {FT <: AbstractFloat}
	# Lower boundary conditions
	u[1] = 0
	v[1] = 0
	θ[1] = θ_ref

	# Upper boundary conditions
	u[end] = u_G
	v[end] = v_G
	θ[end] = θ_ref
		
	return u, v, θ
end

# ╔═╡ a2e596cb-7404-48d3-a558-6f6979c4b0c0
md"""
### 3. Turbulence modeling
Here, we start to model our turbulent 'eddy' viscosity variable νₜ, which dictates how the turbulent fluctuations behave in our 1D domain. 

We'll look at three different models:
"""

# ╔═╡ 54f254b3-0b59-4aea-9e72-0c6631f93df2
md"""
#### 3.1 A constant eddy viscosity model
"""

# ╔═╡ f2423a94-f782-4814-84b9-9413143a111d
md"""
Our first model is the simplest model possible. We assume that the eddy viscosity is constant value, which we define $val1$, over the 1D domain. 
We will see how this affects predictions of our atmospheric quantities of interest (QOIs).

"""

# ╔═╡ f4f3cc04-626d-4366-838c-729c6a2f9fac
function constant_eddyviscosity(z,val1)
	n = length(z)
	νₜ = val1*ones(n)            # eddy viscosity formulation
	
	return νₜ;
end

# ╔═╡ 91822f0b-a411-43d2-b131-43c1273e01b7
md"""
#### 3.2 A mixing length model
"""

# ╔═╡ 5617fbba-1c50-49d8-8946-a55c367c332d
md"""
Our second model is a very old model [2]. 

Imagine you are stirring milk in your coffee with a spoon. The fluid mixes, and swirls form, helping to distribute the milk. The "mixing length" is like the average size of those swirls or turbulent eddies that cause mixing. It's a measure of how far fluid parcels can "travel" or "mix" before losing their identity. One can understand the mixing length to grow with the distance from the surface as the size of the swirls that transfer momentum in the air are not constrained by the proximity to the surface!

The formulation of the eddy viscosity is given as 

$\nu_t = \kappa l_m u_*$

where $\kappa$ is the von Karman constant and $u_*$ is a measure of how fast turbulence is near the surface. 

"""

# ╔═╡ b4a1963d-b941-4f7a-8511-aff317c246a3
function mixinglength_eddyviscosity(z,λ)
	ustar = 0.5                      # friction velocity (arbitrary value)
	κ = 0.4                          # von Karman constant
	𝑙ₘ = (κ*z) ./ (1 .+ κ*z/λ)       # mixing length 
	νₜ = κ*𝑙ₘ*ustar;                 # eddy viscosity formulation
	
	return νₜ;   
end

# ╔═╡ afbf4908-f785-4012-af2e-314a74f20612
md"""
#### 3.3 Yonsei University (YSU) model 
(ACTUALLY USED IN A WEATHER MODEL)
"""

# ╔═╡ 0d4642c4-6ce5-41c0-b4b5-cd299ffdd4e9
md"""
The YSU model is a turbulence model (called a planetary boundary layer scheme) used in operational weather models [3] such as the Weather Research and Forecasting (WRF) model. 

It's designed to simulate various atmospheric conditions, including the following:

1. Daytime convective mixing driven by solar heating at the surface.

2. Nighttime stable conditions where turbulence is weaker, and mixing is limited.

3. Entrainment at the top of the boundary layer, where it interacts with the free atmosphere above.

This is the formulation:

$\nu_t = k w_s z (1 - \frac{z}{h})^p$

Many of these variables are very deep in the weeds of atmospheric science jargon, so I'll only highlight that we can see that the eddy viscosity is a function of the height but also a $p$ power term. 

Here, with some simplifications of fixed values, we can see how it is implemented in code!

"""

# ╔═╡ 5ed68b97-0f31-47ee-ac8d-1d850a9d9d7d
begin 
	function ysu_eddyviscosity(z,height)
		ustar = 0.36                            # friction velocity (arbitrary value)
		κ = 0.4                                 # von Karman constant
		temp_vals = (1 .- z/height)               
		temp_vals[z .> height] .= 0.0
		νₜ = κ * ustar * z .* temp_vals.^2      # eddy viscosity formulation
		νₜ[z .> height] .= 0.00001                # νₜ falls above boundary-layer height
		
		return νₜ
	end
end

# ╔═╡ 0eb53843-51a9-4cc5-b4d0-4b00a3a2555c
# Choose which model to use given model name
function eddy_viscosity(model::String, z, val1, λ, ablh)
	if model == "constant"
		νₜ = constant_eddyviscosity(z,val1)
	elseif model == "mixinglength"
		νₜ = mixinglength_eddyviscosity(z,λ)
	elseif model == "ysu"
		νₜ = ysu_eddyviscosity(z,ablh)
	end

	αₜ = νₜ/Prₜ

	return νₜ, αₜ
end


# ╔═╡ 7f4dac99-bd38-4130-942d-23ec8a339dac
md"""
### Running the code.

Now, let's actually run the model and see some results.
"""

# ╔═╡ e184b85e-0ece-471e-adc5-930cd6451259
md"""
### 4. Plotting quantities of interest
"""

# ╔═╡ 5caccd71-9d4a-4ff9-bcbc-301f4177c7cd
md"""
Now, let's look at some plots on the quantities of interest (QOIs) from our model.
We are interested in the wind speed $U$, wind direction $\phi$, the eddy viscosity $\nu_t$, and what a turbulence model aims to model - the vertical momentum stress $\tau/ρ$.

First, choose your turbulence model:
"""

# ╔═╡ b7766664-aa81-48d2-8066-16a4a0160287
begin 
	# Decide the model (1. constant, 2. mixinglength, 3. ysu)
	model = "ysu"

	println("Model chosen: ", model)
end

# ╔═╡ 0062cc6c-c306-4619-a70d-c6b96116c082
md"""
In the case of the "constant" eddy viscosity model, test different values of "val1". 

In the case of the "mixinglength" model, test different values of "λ".

Finally, in the case of the "ysu" model, try different "height" values.

See how these parameters change predictions of our QOIs.
"""

# ╔═╡ 9f0a9b20-2253-4027-8efc-3b2184322062
@bindname val1 Slider(0.01:0.01:2, show_value=true, default=0.1)

# ╔═╡ 6c69b7f0-913c-4c74-8d8a-cc4f0470b999
@bindname λ Slider(10:10:200, show_value=true, default=40)

# ╔═╡ 697bf44c-6800-4788-a6e8-2dce3b9b50d0
@bindname height Slider(800:10:1000, show_value=true, default=900)

# ╔═╡ 57458bf3-2370-40bb-9cb7-17d8eee1e02a
begin 
	νₜ, αₜ = eddy_viscosity(model, z, val1, λ, height);
	u,v,θ,Δt = initial_conditions(u_G, v_G, θ_ref, Δz, νₜ);
end

# ╔═╡ c9f90500-8245-444c-91db-8aa22dc1bc34
# Now let's run our governing equations for u,v forward in artificial time using RK4
begin
	# Main loop
	for i = 1:nstep
		
		# Apply boundary conditions
		u,v,θ = boundary_conditions(u,v,θ)
	
		# RK4
		u,v,θ = rk4(u, v, θ, Δt, νₜ, αₜ)
		
		# Check convergence
		if i==nstep
			@warn "Run finished. Check plots for convergence."
			break;
		end
	end
end

# ╔═╡ 2c5b5bb2-e746-4081-a63a-a1be4fbee2d8
let
	gr(size=(900,700))
	
	speed = sqrt.(u.^2 + v.^2)
	
	p1 = plot(speed, z, label=L"\mathrm{u}",
		linewidth=2,
		linecolor=:red,
		legend=:false,
		legendfontsize=16,
		xlabel=L"U~(m/s)",
		ylabel=L"z~(m)",
		labelfontsize=20, 
		tickfontsize=10,
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		xlims=(-1,20),
		ylims=(0,1500),
		)
	title!("Wind speed")

	dir = atand.(v,u)
		
	p2 = plot(dir[2:end], z[2:end], label=L"\mathrm{v}",
	    linewidth=2,
		linecolor=:blue,
		legend=:false,
		legendfontsize=16,
		xlabel=L"\phi~(\deg)", 
		ylabel=L"z~(m)", 
		labelfontsize=20, 
		tickfontsize=10,
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		ylims=(0,1500),
	)
	title!("Wind direction")

	p3 = plot(νₜ, z, label=L"\mathrm{v}",
		linewidth=2,
		linecolor=:green,
		legend=:false,
		legendfontsize=16,
		xlabel=L"\nu_t~(m^2/s)", 
		ylabel=L"z~(m)", 
		labelfontsize=20, 
		tickfontsize=10,
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		# xlim = (0,40),
		ylims=(0,1500),
		)
	title!("Eddy viscosity")

	uw = - νₜ .* ∂_∂𝑧(z,u)
	vw = - νₜ .* ∂_∂𝑧(z,v)
	vmf = sqrt.(uw.^2 .+ vw.^2)

	p4 = plot(-vmf, z, label=L"\mathrm{v}",
		linewidth=2,
		linecolor=:orange,
		legend=:false,
		legendfontsize=16,
		xlabel=L"-\tau/\rho~(m^2/s^2)", 
		ylabel=L"z~(m)", 
		labelfontsize=20, 
		tickfontsize=10,
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		# xlim = (-1, 0.01),
		ylims=(0,1500),
		)
	title!("Vertical momentum stress")

	plot(p1, p2, p3, p4, layout = (2, 2))
end

# ╔═╡ 038f931e-be85-4f83-a073-ace3364550fd
md"""
Now, if these single columns of the modeled atmosphere are concatenated horizontally on a single axis, we get a 2D representation of the QOIs over a flat terrain. 
"""

# ╔═╡ 02efe866-9223-4725-aa14-44ace8003844
let
	gr(size=(900,700))
	
	speed = sqrt.(u.^2 + v.^2)
	speed_2d = hcat([speed for _ in 1:60]...)
	dir = atand.(v,u)
	dir_2d = hcat([dir for _ in 1:60]...)
	νₜ_2d = hcat([νₜ for _ in 1:60]...)
	uw = - νₜ .* ∂_∂𝑧(z,u)
	vw = - νₜ .* ∂_∂𝑧(z,v)
	vmf = sqrt.(uw.^2 .+ vw.^2)
	vmf_2d = hcat([vmf for _ in 1:60]...)

	# Arbitrary x-axis
	x = range(0, stop=100, length=60) 
	
	# Plot 2d wind speed
	p1 = heatmap(x, z, speed_2d, 
		interpolation=:bicubic, 
		color=:viridis,
		xlabel=L"x~(m)",
		ylabel=L"z~(m)",
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		colorbar=true,
    	colorbar_title=L"\overline{U}~(m/s)",
		labelfontsize=20, 
		tickfontsize=10,
		colorbar_titlefontsize=20,
		)
	title!("Wind speed")

		# Plot 2d wind direction
	p2 = heatmap(x, z, dir_2d, 
		interpolation=:bicubic, 
		color=:viridis,
		xlabel=L"x~(m)",
		ylabel=L"z~(m)",
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		colorbar=true,
    	colorbar_title=L"\overline{\phi}~(\deg)",
		labelfontsize=20, 
		tickfontsize=10,
		colorbar_titlefontsize=20,
		)
	title!("Wind direction")

		# Plot 2d wind speed
	p3 = heatmap(x, z, νₜ_2d, 
		interpolation=:bicubic, 
		color=:viridis,
		xlabel=L"x~(m)",
		ylabel=L"z~(m)",
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		colorbar=true,
    	colorbar_title=L"\overline{\nu_t}~(m^2/s)",
		labelfontsize=20, 
		tickfontsize=10,
		colorbar_titlefontsize=20,
		)
	title!("Eddy viscosity")

		# Plot 2d wind speed
	p4 = heatmap(x, z, -vmf_2d, 
		interpolation=:bicubic, 
		color=:viridis,
		xlabel=L"x~(m)",
		ylabel=L"z~(m)",
		left_margin=5mm,
		right_margin=2mm,
		bottom_margin=5mm,
		colorbar=true,
    	colorbar_title=L"\overline{\tau/\rho}~(m^2/s^2)",
		labelfontsize=20, 
		tickfontsize=10,
		colorbar_titlefontsize=20,
		)
	title!("Vertical momentum stress")



	plot(p1, p2, p3, p4, layout = (2, 2))
end

# ╔═╡ aa958bd9-bf43-48c9-a55d-0a525b961223
md"""
###### There are more details involved, of course, but this is essentially how turbulence modeling in atmospheric models enables useful weather predictions! 

"""

# ╔═╡ 8b37b9f6-dcd4-44a5-9813-c069be3023ef
md"""
(Further questions or comments may be addressed to: youngin@mit.edu.)
"""

# ╔═╡ b218ef00-7835-4846-bdac-a324ff58aaab


# ╔═╡ d8c877e9-0fc9-434c-8cb1-7dfb6ab81554
md"""
### Acknowledgement:
- Professor Michael Howland, for his class "Atmospheric Boundary Layer Flows and Wind Energy" and problem set on turbulence modeling, which provided the foundational material and inspiration for this notebook.
- Dr. Baris Kale, for providing the opportunity for me to use the notebook to validate YSU results.

"""

# ╔═╡ 54aa46f1-1fb5-45b3-a874-b3d1fb9130a6
md"""
### References

[1] Stull, R. B. (2012). An introduction to boundary layer meteorology (Vol. 13). Springer Science & Business Media.

[2] Prandtl, L. (1925). 7. Bericht über Untersuchungen zur ausgebildeten Turbulenz. ZAMM‐Journal of Applied Mathematics and Mechanics/Zeitschrift für Angewandte Mathematik und Mechanik, 5(2), 136-139.

[3] Hong, S. Y., Noh, Y., & Dudhia, J. (2006). A new vertical diffusion package with an explicit treatment of entrainment processes. Monthly weather review, 134(9), 2318-2341.

"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
Measures = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
LaTeXStrings = "~1.4.0"
Measures = "~0.3.2"
Plots = "~1.40.8"
PlutoUI = "~0.7.60"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.5"
manifest_format = "2.0"
project_hash = "ef208a4f24212c8c6909012aaef5fb095c12e609"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "8873e196c2eb87962a2048b3b8e08946535864a1"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+2"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "009060c9a6168704143100f36ab08f06c2af4642"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.2+1"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "bce6804e5e6044c6daab27bb533d1295e4a2e759"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.6"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "13951eb68769ad1cd460cdb2e64e5e95f1bf123d"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.27.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "ea32b83ca4fefa1768dc84e504cc0a94fb1ab8d1"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.2"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Dbus_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fc173b380865f70627d7dd1190dc2fce6cc105af"
uuid = "ee1fde0b-3d02-5ea6-8484-8dfef6360eab"
version = "1.14.10+0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a4be429317c42cfae6a7fc03c31bad1970c310d"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+1"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e51db81749b0777b2147fbe7b783ee79045b8e99"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.6.4+1"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "53ebe7511fa11d33bec688a9178fac4e49eeee00"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.2"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "466d45dc38e15794ec7d5d63ec03d776a9aff36e"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.4+1"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "db16beca600632c95fc8aca29890d83788dd8b23"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.96+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "786e968a8d2fb167f2e4880baba62e0e26bd8e4e"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.3+1"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1ed150b39aebcc805c26b93a8d0122c940f64ce2"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.14+0"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "532f9126ad901533af1d4f5c198867227a7bb077"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.4.0+1"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Qt6Wayland_jll", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "52adc6828958ea8a0cf923d53aa10773dbca7d5f"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.9"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4e9e2966af45b06f24fd952285841428f1d6e858"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.9+0"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "48b5d4c75b2c9078ead62e345966fa51a25c05ad"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.82.2+1"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "01979f9b37367603e2848ea225918a3b3861b606"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+1"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "ae350b8225575cc3ea385d4131c81594f86dfe4f"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.12"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "401e4f3f30f43af2c8478fc008da50096ea5240f"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.3.1+0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.JLFzf]]
deps = ["Pipe", "REPL", "Random", "fzf_jll"]
git-tree-sha1 = "71b48d857e86bf7a1838c4736545699974ce79a2"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.9"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "be3dc50a92e5a386872a493a10050136d4703f9b"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.6.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "25ee0be4d43d0269027024d75a24c24d6c6e590c"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.0.4+0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "170b660facf5df5de098d866564877e119141cbd"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.2+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "36bdbc52f13a7d1dcb0f3cd694e01677a515655b"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.0.0+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "78211fb6cbc872f77cad3fc0b6cf647d923f4929"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.7+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "854a9c268c43b77b0a27f22d7fab8d33cdb3a731"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.2+1"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.Latexify]]
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "ce5f5621cac23a86011836badfedf664a612cee4"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.5"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll"]
git-tree-sha1 = "8be878062e0ffa2c3f67bb58a595375eda5de80b"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.11.0+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "ff3b4b9d35de638936a525ecd36e86a8bb919d11"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c6ce1e19f3aec9b59186bdf06cdf3c4fc5f5f3e6"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.50.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "61dfdba58e585066d8bce214c5a51eaa0539f269"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.17.0+1"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "84eef7acd508ee5b3e956a2ae51b05024181dee0"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.40.2+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "b404131d06f7886402758c9ce2214b636eb4d54a"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "edbf5309f9ddf1cab25afc344b1e8150b7c832f9"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.40.2+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "a2d09619db4e765091ee5c6ffe8872849de0feea"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.28"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f02b56007b064fbfddb4c9cd60161b6dd0f40df3"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.1.0"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7493f61f55a6cce7325f197443aa80d32554ba10"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.15+1"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6703a85cb3781bd5909d48730a67205f3f31a575"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.3+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "12f1439c4f986bb868acda6ea33ebc78e19b95ad"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.7.0"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e127b609fb9ecba6f201ba7ab753d5a605d53801"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.54.1+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pipe]]
git-tree-sha1 = "6842804e7867b115ca9de748a0cf6b364523c16d"
uuid = "b98c9c47-44ae-5843-9183-064241ee97a0"
version = "1.3.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "35621f10a7531bc8fa58f74610b1bfb70a3cfc6b"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.43.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "41031ef3a1be6f5bbbf3e8073f210556daeae5ca"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.3.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "3ca9a356cd2e113c420f2c13bea19f8d3fb1cb18"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.3"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "TOML", "UUIDs", "UnicodeFun", "UnitfulLatexify", "Unzip"]
git-tree-sha1 = "45470145863035bb124ca51b320ed35d071cc6c2"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.40.8"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "eba4810d5e6a01f612b948c9fa94f905b49087b0"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.60"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "492601870742dcd38f233b23c3ec629628c1d724"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.7.1+1"

[[deps.Qt6Declarative_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6ShaderTools_jll"]
git-tree-sha1 = "e5dd466bf2569fe08c91a2cc29c1003f4797ac3b"
uuid = "629bc702-f1f5-5709-abd5-49b8460ea067"
version = "6.7.1+2"

[[deps.Qt6ShaderTools_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "1a180aeced866700d4bebc3120ea1451201f16bc"
uuid = "ce943373-25bb-56aa-8eca-768745ed7b5a"
version = "6.7.1+1"

[[deps.Qt6Wayland_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6Declarative_jll"]
git-tree-sha1 = "729927532d48cf79f49070341e1d918a65aba6b0"
uuid = "e99dba38-086e-5de3-a5b1-6e4c66e897c3"
version = "6.7.1+1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "83e6cce8324d49dfaf9ef059227f91ed4441a8e5"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.2"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "5cf7606d6cef84b543b483848d4ae08ad9832b21"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.3"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "7822b97e99a1672bfb1b49b668a6d46d58d8cbcb"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.9"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "01915bfcd62be15329c9a07235447a89d588327c"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.21.1"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.UnitfulLatexify]]
deps = ["LaTeXStrings", "Latexify", "Unitful"]
git-tree-sha1 = "975c354fcd5f7e1ddcc1f1a23e6e091d99e99bc8"
uuid = "45397f5d-5981-4c77-b2b3-fc36d6e9b728"
version = "1.6.4"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.Vulkan_Loader_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Wayland_jll", "Xorg_libX11_jll", "Xorg_libXrandr_jll", "xkbcommon_jll"]
git-tree-sha1 = "2f0486047a07670caad3a81a075d2e518acc5c59"
uuid = "a44049a8-05dd-5a78-86c9-5fde0876e88c"
version = "1.3.243+0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "7558e29847e99bc3f04d6569e82d0f5c54460703"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+1"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "93f43ab61b16ddfb2fd3bb13b3ce241cafb0e6c9"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.31.0+0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "a2fccc6559132927d4c5dc183e3e01048c6dcbd6"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.5+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "7d1671acbe47ac88e981868a078bd6b4e27c5191"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.42+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "15e637a697345f6743674f1322beefbc5dcd5cfc"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.6.3+0"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "326b4fea307b0b39892b3e85fa451692eda8d46c"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.1+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "3796722887072218eabafb494a13c963209754ce"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.4+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "9dafcee1d24c4f024e7edc92603cedba72118283"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+1"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "2b0e27d52ec9d8d483e2ca0b72b3cb1a8df5c27a"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.11+1"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "02054ee01980c90297412e4c809c8694d7323af3"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.4+1"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "d7155fea91a4123ef59f42c4afb5ab3b4ca95058"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.6+1"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "47e45cd78224c53109495b3e324df0c37bb61fbe"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.11+0"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fee57a273563e273f0f53275101cd41a8153517a"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.1+1"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "1a74296303b6524a0472a8cb12d3d87a78eb3612"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.0+1"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "730eeca102434283c50ccf7d1ecdadf521a765a4"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.2+0"

[[deps.Xorg_xcb_util_cursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_jll", "Xorg_xcb_util_renderutil_jll"]
git-tree-sha1 = "04341cb870f29dcd5e39055f895c39d016e18ccd"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.4+0"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "330f955bc41bb8f5270a369c473fc4a5a4e4d3cb"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.6+0"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "691634e5453ad362044e2ad653e79f3ee3bb98c3"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.39.0+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b9ead2d2bdb27330545eb14234a2e300da61232e"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.0+1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "555d1076590a6cc2fdee2ef1469451f872d8b41b"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.6+1"

[[deps.eudev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "gperf_jll"]
git-tree-sha1 = "431b678a28ebb559d224c0b6b6d01afce87c51ba"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.9+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6e50f145003024df4f5cb96c7fce79466741d601"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.56.3+0"

[[deps.gperf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0ba42241cb6809f1a278d0bcb976e0483c3f1f2d"
uuid = "1a1c6b14-54f6-533d-8383-74cd7377aa70"
version = "3.1.1+1"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1827acba325fdcdf1d2647fc8d5301dd9ba43a9d"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.9.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e17c115d55c5fbb7e52ebedb427a0dca79d4484e"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.2+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "141fe65dc3efabb0b1d5ba74e91f6ad26f84cc22"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a22cf860a7d27e4f3498a0fe0811a7957badb38"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.3+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "ad50e5b90f222cfe78aa3d5183a20a12de1322ce"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.18.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "b70c870239dc3d7bc094eb2d6be9b73d27bef280"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.44+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "490376214c4721cdaca654041f635213c6165cb3"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+2"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "814e154bdb7be91d78b6802843f76b6ece642f11"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.6+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9c304562909ab2bab0262639bd4f444d7bc2be37"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+1"
"""

# ╔═╡ Cell order:
# ╟─6dd312f0-a859-11ef-15a3-27ed336cc0af
# ╟─063985b5-21e8-4f0b-b65a-e75c136b6b7d
# ╟─b6eac708-a136-4cb8-90a0-1511fb62a829
# ╟─16213d95-eda1-4f56-bf8e-105fb56b9cde
# ╠═f6fffe10-ab2a-46f1-beef-bd5fa7de02f6
# ╟─f92529b4-3d28-43bd-917c-674e49a4405a
# ╟─81bdc7ea-22c1-4e69-8a10-e9db43dc434a
# ╟─28492fc9-96e4-4b31-939e-11f328a689e9
# ╠═d270a745-e0c9-43ec-a4d6-47cb17d2c77d
# ╟─9258ae4d-038d-47e6-8dfa-926a14922009
# ╠═2097169b-b9fb-4252-8d18-5975414c9922
# ╟─2d1b7653-fb6d-4d09-8f8e-dd45c3c407eb
# ╟─6eea1a75-d791-4c16-be20-319ea03679b7
# ╟─74a4d18b-0465-427d-ac2a-ba88e87544f9
# ╠═cb6c51b9-b5fe-4161-ad12-aad1eef1af74
# ╟─59ae82f1-a469-4b6e-9fa9-65a06cf52fb0
# ╟─594c390a-8ef4-475f-8f1f-d4d06f4f2162
# ╟─899fc27a-866e-4d3e-9952-0631c976dfba
# ╟─18c4d6fb-8e48-4287-bf30-9f1221d70cc1
# ╟─d2371ab3-036e-4587-857b-20eb6dea0757
# ╟─41cb1005-778c-4c90-a2ff-d1ecd7963271
# ╟─feece485-f3ff-41cb-8ed7-ddb8cf2962de
# ╟─9ba7bdb2-7b71-4628-aa33-b789ebfa2576
# ╟─05daf599-352a-40f8-935a-c8db73dd20e2
# ╟─4407e589-3689-4812-be78-cee0a0eb01d6
# ╟─c6bc4cd1-f43c-4db7-971a-3515362793dc
# ╠═a78da882-f05b-43bb-9c09-b9944827c69f
# ╟─89016778-670d-4324-b982-1838b8de0122
# ╟─42fb5324-9fb2-40ba-aef2-4e266d99ea8a
# ╟─e8ea1f8f-c40d-45c3-8825-39091ee88c26
# ╟─6c227761-505d-4034-a641-4c5593fe15e5
# ╠═2bbb432e-f038-4edf-abc0-70eabcb34073
# ╟─1143350b-fc92-464f-a5df-42756d9534b8
# ╟─8f2ab920-c1d4-44a8-9517-6088fd15770e
# ╠═ba5e58c5-0754-47d3-b27b-5162fb1b0e71
# ╟─e0611b52-5e7f-463b-9296-a699b3fec0d6
# ╟─352a053e-ad85-49e1-8379-d3e9d96bb90c
# ╟─80689c95-175e-41e3-b68f-22daa2982983
# ╟─a2e596cb-7404-48d3-a558-6f6979c4b0c0
# ╠═0eb53843-51a9-4cc5-b4d0-4b00a3a2555c
# ╟─54f254b3-0b59-4aea-9e72-0c6631f93df2
# ╟─f2423a94-f782-4814-84b9-9413143a111d
# ╠═f4f3cc04-626d-4366-838c-729c6a2f9fac
# ╟─91822f0b-a411-43d2-b131-43c1273e01b7
# ╟─5617fbba-1c50-49d8-8946-a55c367c332d
# ╠═b4a1963d-b941-4f7a-8511-aff317c246a3
# ╟─afbf4908-f785-4012-af2e-314a74f20612
# ╟─0d4642c4-6ce5-41c0-b4b5-cd299ffdd4e9
# ╠═5ed68b97-0f31-47ee-ac8d-1d850a9d9d7d
# ╟─7f4dac99-bd38-4130-942d-23ec8a339dac
# ╠═57458bf3-2370-40bb-9cb7-17d8eee1e02a
# ╠═c9f90500-8245-444c-91db-8aa22dc1bc34
# ╟─e184b85e-0ece-471e-adc5-930cd6451259
# ╟─5caccd71-9d4a-4ff9-bcbc-301f4177c7cd
# ╠═b7766664-aa81-48d2-8066-16a4a0160287
# ╟─0062cc6c-c306-4619-a70d-c6b96116c082
# ╟─9f0a9b20-2253-4027-8efc-3b2184322062
# ╟─6c69b7f0-913c-4c74-8d8a-cc4f0470b999
# ╟─697bf44c-6800-4788-a6e8-2dce3b9b50d0
# ╟─2c5b5bb2-e746-4081-a63a-a1be4fbee2d8
# ╟─038f931e-be85-4f83-a073-ace3364550fd
# ╟─02efe866-9223-4725-aa14-44ace8003844
# ╟─aa958bd9-bf43-48c9-a55d-0a525b961223
# ╟─8b37b9f6-dcd4-44a5-9813-c069be3023ef
# ╟─b218ef00-7835-4846-bdac-a324ff58aaab
# ╟─d8c877e9-0fc9-434c-8cb1-7dfb6ab81554
# ╟─54aa46f1-1fb5-45b3-a874-b3d1fb9130a6
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
