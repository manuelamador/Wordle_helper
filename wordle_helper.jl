using Downloads 
using StaticArrays
using ThreadsX
using ProgressMeter 


function get_word_lists(; use_all_allowed_guesses = true)
    # list of valid wordle words
    url = "https://gist.githubusercontent.com/cfreshman/a03ef2cba789d8cf00c08f767e0fad7b/raw/a9e55d7e0c08100ce62133a1fa0d9c4f0f542f2c/wordle-answers-alphabetical.txt"
    result1 = String(take!(Downloads.download(url,IOBuffer())))

    
    url2 = "https://gist.githubusercontent.com/cfreshman/cdcdf777450c5b5301e439061d29694c/raw/de1df631b45492e0974f7affe266ec36fed736eb/wordle-allowed-guesses.txt"
    result2 = String(take!(Downloads.download(url2,IOBuffer())))
    
    words = map(String, split(result1))
    allowed_guesses = use_all_allowed_guesses ? vcat(words, map(String, split(result2))) : words

    return (; words, allowed_guesses)
end 



# This function checks whether `word` is consistent with `outcome` and the associated
# `guess`. 
# The `outcome` is a vector of 5 integers, representing the match of each letter
# in `guess`. A value of 0 means wrong letter, 1 means right letter wrong position, and 2 means 
# right letter right position. 
function is_a_match(word, guess, outcome)
    for (i, s) in enumerate(outcome)
        if s == 2 # right position
            (word[i] != guess[i]) && return false 
        elseif s == 1 # right letter wrong position
            ((word[i] == guess[i]) || !occursin(guess[i], word)) && return false 
        else # wrong letter
            occursin(guess[i], word) && return false
        end 
    end 
    return true
end 


# If the correct word is `word`, returns the outcome of guessing `letter` in position `pos`. 
function get_pos_outcome(word, letter, pos)
    (letter == word[pos]) && (return 2) # right letter right position
    (occursin(letter, word)) && (return 1) # right letter wrong position
    return 0 # wrong letter
end 


# If the correct word is `word`, returns the vector `outcome` for each letter in `guess`. 
get_outcome(word, guess) = @SVector [get_pos_outcome(word, guess[i], i) for i in 1:5]


count_wrong_matches(words, guess, outcome) = count(
        x -> (is_a_match(x, guess, outcome) && (x != guess)), # wrong matches
        words)


# Finds the best guess by minimizing the expected number of wrong matched words. 
function find_best_guess(;
        allowed_guesses,
        words, 
        verbose = true
)
    verbose && (p = Progress(length(allowed_guesses)))
    op = (x, y) -> y[2] < x[2] ? y : x
    best = ThreadsX.mapreduce(op, 1:length(allowed_guesses), init = ("", typemax(Int))) do i  
        guess = allowed_guesses[i]
        number_matches = 0
        for (i, word) in enumerate(words) 
            outcome = get_outcome(word, guess)
            number_matches += count_wrong_matches(words, guess, outcome)
        end 
        verbose && next!(p)
        return (guess, number_matches)
    end 
    return best
end


function new_guess_and_update!(remaining_words, guess, outcome, allowed_guesses; hard_mode = false)
    filter!(x -> is_a_match(x, guess, outcome), remaining_words)
    guesses = hard_mode ? remaining_words : allowed_guesses
    return find_best_guess(; allowed_guesses = guesses, words = remaining_words, verbose = false)
end 


# Given the correct word `true_word` and an initial `guess`, solve the game 
# given that `words` contains the list of potential words and `guess_pool`
# contains the list allowed words to be used as guesses. 
function solve(true_word, starting_guess; words, allowed_guesses, hard_mode = false) 
    guess = starting_guess
    sol = [guess]
    remaining_words = filter(x -> is_a_match(x, guess, get_outcome(true_word, guess)), words)
    while !(length(remaining_words) == 1 && remaining_words[1] == guess) 
        guesses = hard_mode ? remaining_words : allowed_guesses
        guess = find_best_guess(;allowed_guesses = guesses, words = remaining_words, verbose = false)[1]
        push!(sol, guess)
        filter!(x -> is_a_match(x, guess, get_outcome(true_word, guess)), remaining_words)
    end 
    return sol 
end
