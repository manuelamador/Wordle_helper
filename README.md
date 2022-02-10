# Wordle_helper

Simple program to solve [Wordle](https://www.powerlanguage.co.uk/wordle/) puzzles. Written in Julia 1.7. 

The algorithm finds the next guess that minimizes the expected number of words that remain after the guess has been tried. 

See jupyter notebook, `examples.ipynb`, for details and examples. 

To run the script, navigate to this folder with the prompt and type:

    > julia -t auto solve_a_game.jl 

To run it in hard mode, do 

    > julia -t auto solve_a_game.jl hard_mode 


