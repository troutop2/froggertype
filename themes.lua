local Themes = {}

local function hex(hexStr, alpha)
    hexStr = hexStr:gsub("#", "")
    local r = tonumber(hexStr:sub(1, 2), 16) / 255
    local g = tonumber(hexStr:sub(3, 4), 16) / 255
    local b = tonumber(hexStr:sub(5, 6), 16) / 255
    return {r, g, b, alpha or 1}
end

Themes.list = {
    {
        id = "frogger",
        name = "Frogger",
        bg = hex("#16231a"),
        panel = hex("#1f3325"),
        panel_hover = hex("#294231"),
        sub = hex("#4f7158"),
        text = hex("#d2fbd8"),
        main = hex("#4fe383"),
        caret = hex("#5cff95"),
        error = hex("#ff5c57"),
        error_extra = hex("#b23b3b"),
        accent = hex("#4fe383"),
        graph_raw = hex("#3b5943"),
        frog = hex("#5cff95")
    },
    {
        id = "serika_dark",
        name = "Serika Dark",
        bg = hex("#323437"),
        panel = hex("#2c2e31"),
        panel_hover = hex("#3a3c40"),
        sub = hex("#646669"),
        text = hex("#d1d0c5"),
        main = hex("#e2b714"),
        caret = hex("#e2b714"),
        error = hex("#ca4754"),
        error_extra = hex("#7e2a33"),
        accent = hex("#e2b714"),
        graph_raw = hex("#535558"),
        frog = hex("#e2b714")
    },
    {
        id = "matrix",
        name = "Matrix",
        bg = hex("#0d1117"),
        panel = hex("#141b22"),
        panel_hover = hex("#1d2630"),
        sub = hex("#265935"),
        text = hex("#75ff98"),
        main = hex("#00ff41"),
        caret = hex("#00ff41"),
        error = hex("#ff3860"),
        error_extra = hex("#9e1c36"),
        accent = hex("#00ff41"),
        graph_raw = hex("#1d3d27"),
        frog = hex("#00ff41")
    },
    {
        id = "dracula",
        name = "Dracula",
        bg = hex("#282a36"),
        panel = hex("#343746"),
        panel_hover = hex("#44475a"),
        sub = hex("#6272a4"),
        text = hex("#f8f8f2"),
        main = hex("#bd93f9"),
        caret = hex("#ff79c6"),
        error = hex("#ff5555"),
        error_extra = hex("#b23b3b"),
        accent = hex("#50fa7b"),
        graph_raw = hex("#44475a"),
        frog = hex("#50fa7b")
    },
    {
        id = "carbon",
        name = "Carbon",
        bg = hex("#2b2b2b"),
        panel = hex("#232323"),
        panel_hover = hex("#363636"),
        sub = hex("#616161"),
        text = hex("#f5e6c8"),
        main = hex("#f66e0d"),
        caret = hex("#f66e0d"),
        error = hex("#e45c5c"),
        error_extra = hex("#993333"),
        accent = hex("#f66e0d"),
        graph_raw = hex("#474747"),
        frog = hex("#f66e0d")
    },
    {
        id = "nord",
        name = "Nord",
        bg = hex("#2e3440"),
        panel = hex("#3b4252"),
        panel_hover = hex("#434c5e"),
        sub = hex("#616e88"),
        text = hex("#eceff4"),
        main = hex("#88c0d0"),
        caret = hex("#81a1c1"),
        error = hex("#bf616a"),
        error_extra = hex("#833d45"),
        accent = hex("#a3be8c"),
        graph_raw = hex("#4c566a"),
        frog = hex("#a3be8c")
    }
}

Themes.currentIndex = 1

function Themes.current()
    return Themes.list[Themes.currentIndex]
end

function Themes.next()
    Themes.currentIndex = Themes.currentIndex + 1
    if Themes.currentIndex > #Themes.list then
        Themes.currentIndex = 1
    end
    return Themes.current()
end

function Themes.set(index)
    if index >= 1 and index <= #Themes.list then
        Themes.currentIndex = index
    end
    return Themes.current()
end

return Themes

