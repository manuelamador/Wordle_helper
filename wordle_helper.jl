using Downloads
using ProgressMeter 
using DelimitedFiles
using FLoops

function get_word_lists()
    # list of valid wordle words
    url = "https://gist.githubusercontent.com/cfreshman/a03ef2cba789d8cf00c08f767e0fad7b/raw/a9e55d7e0c08100ce62133a1fa0d9c4f0f542f2c/wordle-answers-alphabetical.txt"
    result1 = String(take!(Downloads.download(url,IOBuffer())))

    
    url2 = "https://gist.githubusercontent.com/cfreshman/cdcdf777450c5b5301e439061d29694c/raw/de1df631b45492e0974f7affe266ec36fed736eb/wordle-allowed-guesses.txt"
    result2 = String(take!(Downloads.download(url2,IOBuffer())))
    
    words = map(String, split(result1))
    allowed_guesses = unique(vcat(words, map(String, split(result2)))) 

    return (; words, allowed_guesses)
end 


function save_word_lists()
    lsts = get_word_lists()
    open("words.txt", "w") do io
        writedlm(io, lsts[1])
    end 
    open("guesses.txt", "w") do io
        writedlm(io, lsts[2])
    end 
    return lsts
end


function load_word_lists()
    if isfile("words.txt") && isfile("guesses.txt") 
        # if possible, read from files
        lsts = readdlm("words.txt", String), readdlm("guesses.txt", String) 
    else 
        # otherwise, download and save to files
        lsts = save_word_lists()
    end 
    return (words = lsts[1][:], allowed_guesses = lsts[2][:])
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
    for (i, true_letter) in pairs(word)
        (true_letter == guess[i]) && (tmp[i] = 2; continue)
        for j in eachindex(tmp)
            if (tmp[j] == 0) && (true_letter == guess[j])
                tmp[j] = 1
                break
            end
        end 
    end 
    return tmp
end    


count_wrong_matches_given_outcome(words, guess, outcome; tmp = zeros(Int, 5)) = count( 
        x -> (is_a_match(x, guess, outcome; tmp) && (x != guess)), # wrong matches
        words)


function count_wrong_matches(word, guess, words; tmp1 = zeros(Int, 5), tmp2 = zeros(Int, 5))
    outcome = get_outcome(word, guess; tmp = tmp1)
    return count_wrong_matches_given_outcome(words, guess, outcome; tmp = tmp2)
end  


# Finds the best guess by minimizing the expected number of wrong matched words. 
function find_best_guess(;
    words, 
    allowed_guesses,
    verbose = true, 
    use_entropy = false
)    
    isempty(allowed_guesses) && error("empty guess list")
    p = Progress(length(allowed_guesses))
    @floop for (i, guess) in pairs(allowed_guesses)
        @init tmp1 = zeros(Int, 5)
        @init tmp2 = zeros(Int, 5)
        score = use_entropy ?
            sum(word -> log2(1 + count_wrong_matches(word, guess, words; tmp1, tmp2)), words) :
            Float64(sum(word -> count_wrong_matches(word, guess, words; tmp1, tmp2), words))
        @reduce() do (best_index = firstindex(allowed_guesses); i), (best_score = typemax(score); score)
            # find lowest score -- best guess
            if score < best_score 
                best_score = score
                best_index = i
            end 
        end 
        verbose && next!(p)
    end 
    return allowed_guesses[best_index::Int]
end


function new_guess_and_update!(remaining_words, guess, outcome, allowed_guesses; hard_mode = false, use_entropy = false)
    filter!(x -> is_a_match(x, guess, outcome), remaining_words)
    hard_mode && filter!(x -> is_a_match(x, guess, outcome), allowed_guesses)
    return find_best_guess(; words = remaining_words, allowed_guesses, verbose = false, use_entropy)
end 


# Given the correct word `true_word` and an initial `guess`, solve the game 
# given that `words` contains the list of potential words and `guess_pool`
# contains the list allowed words to be used as guesses. 
function solve(
    true_word, starting_guess; 
    words, allowed_guesses, 
    hard_mode = false, 
    use_entropy = false
) 
    (true_word in allowed_guesses) || (println("$true_word not in the list of guesses!"); return String[])
    guess = starting_guess
    sol = [guess]

    outcome = get_outcome(true_word, guess)
    remaining_words = filter(x -> is_a_match(x, guess, outcome), words)
    guesses = hard_mode ? allowed_guesses[:] : allowed_guesses

    while !(length(remaining_words) == 1 && remaining_words[1] == guess) 
        hard_mode &&  filter!(x -> is_a_match(x, guess, outcome), guesses)
        guess = find_best_guess(; allowed_guesses = guesses, words = remaining_words, verbose = false, use_entropy)
        push!(sol, guess)
        outcome = get_outcome(true_word, guess)
        filter!(x -> is_a_match(x, guess, outcome), remaining_words)
    end 
    return sol 
end


function solve_a_game(; hard_mode = false, use_entropy = false)
    (; words, allowed_guesses) = load_word_lists()

    println("""Solves a Worldle game in $(hard_mode ? "HARD" : "NORMAL") mode.   
    
        Outcome is a 5 digit number, where for each digit:
        
        0: represents a wrong letter, 
        1: represents a right letter in the wrong position, and 
        2: represents the right letter in the right position.

        For example, if the guess is 

            raise 

        and the outcome is
         
            10002

        then 'r' is in the wrong position, 'e' is the right position, and 
        'a', 'i' and 's' are not in the word.

    Control-C exits.
    """)

    i = 1 
    while true
        local guess, outcome

        while true
            print("Enter your guess $i: ")
            guess = lowercase(readline())
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

        next = new_guess_and_update!(words, guess, outcome, allowed_guesses; hard_mode, use_entropy)

        ending = i == 1 ? "" : "es"
        if  length(words) == 1 
            (guess != words[1]) && (i += 1)
            println("\nWord is $(words[1]). Required $i guess$ending.")
            break 
        elseif length(words) == 0 
            println("Inconsistent values. Something went wrong.")
            break
        end
        println("Number of remaining words: $(length(words))")
        (length(words) <= 10) && (print("Remaining words:"); println(words))

        println("Next best guess: $next")
        println()
        i += 1
    end 
end 