### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# ╔═╡ 29f1ee6a-19aa-11ee-3bd2-7f4f2d5568ea
begin
	import Pkg; Pkg.activate()
	using JuMP, UnicodePlots
	import DataFrames, HiGHS
end

# ╔═╡ 73bf1c39-a6bc-4994-b166-8e2fa0db02cf
md"## foods available in our kitchen"

# ╔═╡ 742324f0-01e6-4fc6-8a70-4da0c388cde7
foods = DataFrames.DataFrame(
    [
        "hamburger" 2.49 410 24 26 730
        "chicken" 2.89 420 32 10 1190
        "hot dog" 1.50 560 20 32 1800
        "fries" 1.89 380 4 19 270
        "macaroni" 2.09 320 12 10 930
        "pizza" 1.99 320 15 12 820
        "salad" 2.49 320 31 12 1230
        "milk" 0.89 100 8 2.5 125
        "ice cream" 1.59 330 8 10 180
    ],
    ["name", "cost", "calories", "protein", "fat", "sodium"],
)

# ╔═╡ 065f0d91-08c2-4dd1-8cdb-fcdf0db59109
md"## our nutrient needs/avoidances"

# ╔═╡ febb9ef4-f7a5-4998-9b2c-90caaba88e1b
limits = DataFrames.DataFrame(
    [
        "calories" 1800 2200
        "protein" 91 Inf
        "fat" 0 65
        "sodium" 0 1779
    ],
    ["nutrient", "min", "max"],
)

# ╔═╡ 0f56a3a5-7927-40b1-bcaa-895fb004d998
md"## the optimization problem
*  $\mathcal{F}$: set of foods
*  $\mathcal{N}$: set of nutrients
*  $c_f$: cost of food $f \in \mathcal{F}$ per mass
*  $a_{nf}$: mass of nutrient $n$ in food $f$ per mass of food
*  we need at least $l_n$ mass of nutrient $n$
*  we need less than $u_n$ mass of nutrient $n$

_decision variables_ are $x_f$ for $f\in\mathcal{F}$: the mass of food $f$ to eat.

```math
\begin{align}
	\min_{f\in\mathcal{F}} c_f x_f & \\
	\text{s.t. } & x_f \geq 0 \text{ for } f \in \mathcal{F}\\
	& l_n \leq \sum_{f\in\mathcal{F}} a_{nf} x_f \leq u_n \text{ for } n \in \mathcal{N}
\end{align}
```

* minimize the cost of the food
*  $|\mathcal{F}| + 2|\mathcal{N}|$ constraints:
  * food consumed greater than equal to zero (duh)
  * we get the nutrients we need
  * we don't consume too much of nutrients bad for us
"

# ╔═╡ 322399ea-3279-4d6d-8753-6626a20e8058
begin
	# create JuMP model with certain optimizer for linear program (LP)
	model = Model(HiGHS.Optimizer)
	set_silent(model)
end

# ╔═╡ 7d510b3f-5cdb-44ac-b969-7e32815d3cb1
md"create decision variables"

# ╔═╡ db80cadc-de8b-4de8-a827-25892d7811fb
@variable(model, x[foods.name] >= 0)

# ╔═╡ 3d008f66-6dc1-4d58-a67d-fbbf38df99f8
x

# ╔═╡ b7bd58d7-da78-4ed0-940c-c209c04248a2
foods.x = Array(x) # attach to data frame to easily loop over

# ╔═╡ 03b5ecbc-a12c-4dd0-b867-4b582c9ce388
md"define objective"

# ╔═╡ 3f88e513-a862-4258-acda-b143e6156e80
@objective(model, Min, sum(foods.cost .* x));

# ╔═╡ 879502e2-be21-4e9d-a1c6-f8f1236df62d
md"define constraints (one for each nutrient)"

# ╔═╡ 3d89f118-7a8f-42f1-8b5f-1eeedd7facf6
for row in eachrow(limits)
	@constraint(model, row.min <= sum(foods[:, row.nutrient] .* x) <= row.max)
end

# ╔═╡ 8989b3eb-dce3-4c29-8134-c87eb7e448d6
md"print model"

# ╔═╡ f9dd7fb3-cdc2-4516-b5ef-90a10c448202
print(model)

# ╔═╡ b28d156c-e969-4fc9-9a77-932827c56e4d
md"optimization time!"

# ╔═╡ b7690aeb-4ee5-464b-87cf-268ec94c0def
begin
	optimize!(model)
	solution_summary(model)
end

# ╔═╡ 1d098a26-9882-42e2-9e11-c4c77bb2ed15
md"view solution"

# ╔═╡ a717aaa1-efcc-4e91-adf4-7e8719210a8c
for row in eachrow(foods)
    println(row.name, " = ", value(row.x))
end

# ╔═╡ 2c237183-48f3-4e3b-91de-91220156eb7b
md"put in a data frame"

# ╔═╡ eef60af5-3e8e-4a40-a7fb-f1d9826ed08b
solution = DataFrames.DataFrame(
	Containers.rowtable(value, x; header = [:food, :quantity])
)

# ╔═╡ beaef221-ff1e-4ca3-8ef2-8caaef82a363
filter!(row -> row.quantity > 0.0, solution)

# ╔═╡ 4df278c4-6196-4a8e-b87e-3fd5e5245867
barplot(solution.food, solution.quantity, title="optimum diet")

# ╔═╡ Cell order:
# ╠═29f1ee6a-19aa-11ee-3bd2-7f4f2d5568ea
# ╟─73bf1c39-a6bc-4994-b166-8e2fa0db02cf
# ╠═742324f0-01e6-4fc6-8a70-4da0c388cde7
# ╟─065f0d91-08c2-4dd1-8cdb-fcdf0db59109
# ╟─febb9ef4-f7a5-4998-9b2c-90caaba88e1b
# ╟─0f56a3a5-7927-40b1-bcaa-895fb004d998
# ╠═322399ea-3279-4d6d-8753-6626a20e8058
# ╟─7d510b3f-5cdb-44ac-b969-7e32815d3cb1
# ╠═db80cadc-de8b-4de8-a827-25892d7811fb
# ╠═3d008f66-6dc1-4d58-a67d-fbbf38df99f8
# ╠═b7bd58d7-da78-4ed0-940c-c209c04248a2
# ╟─03b5ecbc-a12c-4dd0-b867-4b582c9ce388
# ╠═3f88e513-a862-4258-acda-b143e6156e80
# ╟─879502e2-be21-4e9d-a1c6-f8f1236df62d
# ╠═3d89f118-7a8f-42f1-8b5f-1eeedd7facf6
# ╟─8989b3eb-dce3-4c29-8134-c87eb7e448d6
# ╠═f9dd7fb3-cdc2-4516-b5ef-90a10c448202
# ╟─b28d156c-e969-4fc9-9a77-932827c56e4d
# ╠═b7690aeb-4ee5-464b-87cf-268ec94c0def
# ╟─1d098a26-9882-42e2-9e11-c4c77bb2ed15
# ╠═a717aaa1-efcc-4e91-adf4-7e8719210a8c
# ╟─2c237183-48f3-4e3b-91de-91220156eb7b
# ╠═eef60af5-3e8e-4a40-a7fb-f1d9826ed08b
# ╠═beaef221-ff1e-4ca3-8ef2-8caaef82a363
# ╠═4df278c4-6196-4a8e-b87e-3fd5e5245867
