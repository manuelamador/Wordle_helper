import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

include("wordle_helper.jl")

if length(ARGS) == 0 || ARGS[1] == "normal_mode"
    println("Normal mode")
    solve_a_game(; hard_mode = false)
elseif ARGS[1] == "hard_mode"
    println("Hard mode") 
    solve_a_game(; hard_mode = true)
else 
    println("Wrong arguments")
end 