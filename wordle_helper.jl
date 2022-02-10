using Downloads 
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

is_a_match(word, guess, outcome; tmp = zeros(Int, 5)) = get_outcome(word, guess; tmp) == outcome


# If the correct word is `word`, returns the vector `outcome` for each letter in `guess`. 
# This deals with repeated letters. 
function get_outcome(word, guess; tmp = zeros(Int, 5)) 
    tmp .= 0
    for i in eachindex(word)
        true_letter = word[i]
        (true_letter == guess[i]) && (tmp[i] = 2; continue)
        for j in eachindex(tmp)
            (tmp[j] == 0) && (true_letter == guess[j]) && (tmp[j] = 1; break)
        end 
    end 
    return tmp
end
    

count_wrong_matches(words, guess, outcome; tmp = zeros(Int, 5)) = count( 
        x -> (is_a_match(x, guess, outcome; tmp) && (x != guess)), # wrong matches
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
        tmp = zeros(Int, 5)
        outcome = zeros(Int, 5)
        for (i, word) in enumerate(words) 
            get_outcome(word, guess; tmp = outcome)
            number_matches += count_wrong_matches(words, guess, outcome; tmp)
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



function solve_a_game(; hard_mode = false)
    all_words = get_word_lists()
    game_words = get_word_lists().words

    println("""Solves a Worldle game.
    
        For outcome, give a list of 5 digits, each representing a letter in that 
        position:
        
        0: represents a wrong letter, 
        1: represents a right letter in the wrong position, and 
        2: represents the right letter in the right position.

        If the guess is 

            raise 

        and the outcome is
         
            10002

        then 'r' is in the wrong position, 'e' is the right position, and 
        'a', 'i' and 's' are not in the word.

        Use lowercase for the guesses. 

    Control-C exits.
    """)

    i = 1 
    while true
        local guess, outcome

        while true
            print("Enter your guess $i: ")
            guess = readline()
            if (length(guess) == 5) 
                break 
            else 
                println("Word is not 5 letters long")
            end
        end 

        while true 
            print("Enter the outcome for guess $i: ")
            outcome = map(x -> parse(Int, x), collect(readline()))
            if (length(outcome) == 5) 
                break 
            else 
                println("Outcome is not 5 digits long")
            end 
        end 

        next = new_guess_and_update!(game_words, guess, outcome, all_words.words; hard_mode)

        ending = i == 1 ? "" : "es"
        if  length(game_words) == 1 
            (guess != game_words[1]) && (i += 1)
            println("\nWord is $(game_words[1]). Required $i guess$ending.")
            break 
        elseif length(game_words) == 0 
            println("Inconsistent values. Something went wrong.")
            break
        end
        println("Next best guess: $(next[1])")
        println()
        i += 1
    end 
end 