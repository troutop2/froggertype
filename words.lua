local Words = {}

Words.dictionary = {
    "the", "be", "of", "and", "a", "to", "in", "he", "have", "it",
    "that", "for", "they", "i", "with", "as", "not", "on", "she", "at",
    "by", "this", "we", "you", "do", "but", "from", "or", "which", "one",
    "would", "all", "will", "there", "say", "who", "make", "when", "can", "more",
    "if", "no", "man", "out", "other", "so", "what", "time", "up", "go",
    "about", "than", "into", "could", "state", "only", "new", "year", "some", "take",
    "come", "these", "know", "see", "use", "get", "like", "then", "first", "any",
    "work", "now", "may", "such", "give", "over", "think", "most", "even", "find",
    "day", "also", "after", "way", "many", "must", "look", "before", "great", "back",
    "through", "long", "where", "much", "should", "well", "people", "down", "own", "just",
    "because", "good", "each", "those", "feel", "seem", "how", "high", "too", "place",
    "little", "world", "very", "still", "nation", "hand", "old", "life", "tell", "write",
    "become", "here", "show", "house", "both", "between", "need", "mean", "call", "develop",
    "under", "last", "right", "move", "thing", "general", "school", "never", "same", "another",
    "begin", "while", "number", "part", "turn", "real", "leave", "might", "want", "point",
    "form", "child", "few", "small", "since", "against", "ask", "late", "home", "interest",
    "large", "person", "end", "open", "public", "follow", "during", "present", "without", "again",
    "hold", "govern", "around", "possible", "head", "consider", "word", "program", "problem", "however",
    "lead", "system", "set", "order", "eye", "plan", "run", "keep", "face", "fact",
    "group", "play", "stand", "increase", "early", "course", "change", "help", "line", "frog",
    "pond", "jump", "leap", "green", "water", "lily", "pad", "hop", "swim", "tongue",
    "fly", "lake", "stone", "ripple", "croak", "quick", "brown", "fox", "lazy", "dog",
    "code", "type", "fast", "speed", "test", "keys", "finger", "click", "space", "board",
    "light", "dark", "sound", "peace", "focus", "flow", "rhythm", "skill", "power", "habit",
    "quiet", "stream", "nature", "breeze", "forest", "moss", "shade", "branch", "leaf", "splash"
}

function Words.getRandom(count, withPunctuation, withNumbers)
    local list = {}
    local punct = {",", ".", "!", "?", ";", ":"}
    
    for i = 1, count do
        local w = Words.dictionary[math.random(1, #Words.dictionary)]
        
        if withNumbers and math.random() < 0.12 then
            w = tostring(math.random(1, 999))
        else
            if withPunctuation then
                if i == 1 or math.random() < 0.18 then
                    w = w:sub(1, 1):upper() .. w:sub(2)
                end
                if math.random() < 0.22 then
                    w = w .. punct[math.random(1, #punct)]
                end
            end
        end
        
        table.insert(list, w)
    end
    
    return list
end

return Words

