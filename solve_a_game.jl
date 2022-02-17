import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

include("wordle_helper.jl")

hard_mode = ("hard_mode" in ARGS) ? true : false 
use_entropy = ("use_entropy" in ARGS) ? true : false 

solve_a_game(; hard_mode, use_entropy)
