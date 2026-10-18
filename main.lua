local Themes = require("themes")
local Sound = require("sound")
local Words = require("words")
local Frog = require("frog")
local Arcade = require("arcade")

local App = {
    -- Top Level Mode: "arcade" or "classic"
    gameMode = "arcade",

    -- Classic Test settings
    mode = "time", -- "time" or "words"
    timeOptions = {15, 30, 60},
    timeSelected = 30,
    wordsOptions = {10, 25, 50, 100},
    wordsSelected = 25,
    punctuation = false,
    numbers = false,

    -- State: "idle", "typing", "results"
    state = "idle",
    
    -- Word list data
    words = {},
    currentWordIndex = 1,
    currentCharIndex = 1,
    
    -- Timer & Stats
    startTime = 0,
    elapsedTime = 0,
    timeLimit = 30,
    totalTypedChars = 0,
    correctChars = 0,
    incorrectChars = 0,
    extraChars = 0,
    missedChars = 0,
    totalKeystrokes = 0,
    
    -- Timeline history for results graph: { {sec = 1, wpm = 65, raw = 70, errors = 0}, ... }
    history = {},
    lastRecordedSecond = 0,
    currentSecondErrors = 0,
    
    -- Caret animation
    caretX = 0,
    caretY = 0,
    targetCaretX = 0,
    targetCaretY = 0,
    caretBlink = 0,
    
    -- Smooth line scrolling
    scrollY = 0,
    targetScrollY = 0,
    lineHeight = 44,
    
    -- Frogger animation
    frogHopTimer = 0,
    globalTime = 0,
    
    -- Visual layout cache
    lines = {},
    contentWidth = 860,
    
    -- Fonts
    fonts = {},
    
    -- UI Interactive buttons
    buttons = {}
}

function love.load()
    love.keyboard.setKeyRepeat(true)
    Sound.init()
    
    -- Setup clean fonts
    App.fonts.title = love.graphics.newFont(26)
    App.fonts.subtitle = love.graphics.newFont(14)
    App.fonts.typing = love.graphics.newFont(28)
    App.fonts.statsBig = love.graphics.newFont(48)
    App.fonts.statsMed = love.graphics.newFont(24)
    App.fonts.statsSmall = love.graphics.newFont(16)
    App.fonts.ui = love.graphics.newFont(15)
    App.fonts.uiBold = love.graphics.newFont(15)

    -- Cursors
    App.cursors = {
        arrow = love.mouse.getSystemCursor("arrow"),
        hand = love.mouse.getSystemCursor("hand"),
        ibeam = love.mouse.getSystemCursor("ibeam")
    }

    Arcade.init()
    App.resetTest()
end

function App.resetTest(keepSameWords)
    App.state = "idle"
    App.startTime = 0
    App.elapsedTime = 0
    App.totalTypedChars = 0
    App.correctChars = 0
    App.incorrectChars = 0
    App.extraChars = 0
    App.missedChars = 0
    App.totalKeystrokes = 0
    App.history = {}
    App.lastRecordedSecond = 0
    App.currentSecondErrors = 0
    App.currentWordIndex = 1
    App.currentCharIndex = 1
    App.scrollY = 0
    App.targetScrollY = 0

    if App.mode == "time" then
        App.timeLimit = App.timeSelected
        -- Generate plenty of words for time mode
        if not keepSameWords then
            local count = math.max(80, math.floor(App.timeLimit * 4))
            App.rawWords = Words.getRandom(count, App.punctuation, App.numbers)
        end
    else
        if not keepSameWords then
            App.rawWords = Words.getRandom(App.wordsSelected, App.punctuation, App.numbers)
        end
    end

    -- Build structured word objects
    App.words = {}
    for i, w in ipairs(App.rawWords) do
        local chars = {}
        for c = 1, #w do
            table.insert(chars, {
                char = w:sub(c, c),
                status = "untyped" -- "correct", "incorrect", "untyped"
            })
        end
        table.insert(App.words, {
            target = w,
            typed = "",
            chars = chars,
            extras = {}, -- array of extra letters typed
            isComplete = false,
            hasError = false,
            x = 0,
            y = 0,
            width = 0
        })
    end

    App.recalculateLayout()
    App.updateCaretTarget(true)
end

function App.recalculateLayout()
    local font = App.fonts.typing
    local spaceWidth = font:getWidth(" ")
    local winW, winH = love.graphics.getDimensions()
    
    App.contentWidth = math.min(940, winW - 120)
    local startX = (winW - App.contentWidth) / 2
    local startY = 220
    
    local curX = startX
    local curY = startY
    local lineIndex = 1

    App.lines = {{ words = {}, y = curY }}

    for i, wObj in ipairs(App.words) do
        -- Calculate word display width (target + extra)
        local displayStr = wObj.target
        if #wObj.extras > 0 then
            displayStr = displayStr .. table.concat(wObj.extras, "")
        end
        local wordW = font:getWidth(displayStr)
        wObj.width = wordW

        -- Check line wrap
        if curX + wordW > startX + App.contentWidth and curX > startX then
            lineIndex = lineIndex + 1
            curX = startX
            curY = curY + App.lineHeight
            table.insert(App.lines, { words = {}, y = curY })
        end

        wObj.x = curX
        wObj.y = curY
        wObj.line = lineIndex
        table.insert(App.lines[lineIndex].words, wObj)

        curX = curX + wordW + spaceWidth
    end
end

function App.updateCaretTarget(immediate)
    local font = App.fonts.typing
    local currentWord = App.words[App.currentWordIndex]
    
    if currentWord then
        local baseWordX = currentWord.x
        local typedLen = #currentWord.typed
        local subStr = ""

        if typedLen <= #currentWord.target then
            subStr = currentWord.target:sub(1, typedLen)
        else
            subStr = currentWord.target .. table.concat(currentWord.extras, "")
        end

        local offset = font:getWidth(subStr)
        App.targetCaretX = baseWordX + offset
        App.targetCaretY = currentWord.y

        -- Scroll smoothly if line > 2
        local targetLine = currentWord.line or 1
        if targetLine >= 2 then
            App.targetScrollY = (targetLine - 2) * App.lineHeight
        else
            App.targetScrollY = 0
        end
    end

    if immediate then
        App.caretX = App.targetCaretX
        App.caretY = App.targetCaretY
        App.scrollY = App.targetScrollY
    end
end

function App.finishTest()
    App.state = "results"
    App.elapsedTime = math.max(0.1, App.elapsedTime)
    Sound.playFinish()

    -- Ensure final second is recorded in history
    local finalWpm = App.getWpm()
    local finalRaw = App.getRawWpm()
    table.insert(App.history, {
        sec = math.floor(App.elapsedTime * 10) / 10,
        wpm = finalWpm,
        raw = finalRaw,
        errors = App.currentSecondErrors
    })
end

function App.getWpm()
    if App.elapsedTime <= 0 then return 0 end
    local minutes = App.elapsedTime / 60
    local wordsTyped = (App.correctChars) / 5
    return math.max(0, math.floor(wordsTyped / minutes + 0.5))
end

function App.getRawWpm()
    if App.elapsedTime <= 0 then return 0 end
    local minutes = App.elapsedTime / 60
    local totalChars = (App.totalTypedChars) / 5
    return math.max(0, math.floor(totalChars / minutes + 0.5))
end

function App.getAccuracy()
    if App.totalKeystrokes <= 0 then return 100 end
    local acc = (App.correctChars / App.totalKeystrokes) * 100
    return math.max(0, math.min(100, math.floor(acc * 10) / 10))
end

function App.getConsistency()
    if #App.history < 2 then return 100 end
    local sum = 0
    for _, pt in ipairs(App.history) do
        sum = sum + pt.raw
    end
    local mean = sum / #App.history
    if mean <= 0 then return 100 end
    local varSum = 0
    for _, pt in ipairs(App.history) do
        varSum = varSum + (pt.raw - mean) ^ 2
    end
    local stdDev = math.sqrt(varSum / #App.history)
    local cv = stdDev / mean
    local consistency = math.max(0, math.min(100, (1 - cv) * 100))
    return math.floor(consistency)
end

function App.getProgress()
    if App.mode == "time" then
        return math.min(1, App.elapsedTime / App.timeLimit)
    else
        return math.min(1, (App.currentWordIndex - 1) / #App.words)
    end
end

function love.update(dt)
    App.globalTime = App.globalTime + dt

    -- Update cursor on button hover
    local mx, my = love.mouse.getPosition()
    local isHovered = false
    for _, btn in ipairs(App.buttons) do
        if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
            isHovered = true
            break
        end
    end
    if App.cursors and App.cursors.hand then
        love.mouse.setCursor(isHovered and App.cursors.hand or App.cursors.arrow)
    end

    if App.gameMode == "arcade" then
        Arcade.update(dt)
        return
    end

    App.caretBlink = App.caretBlink + dt

    if App.frogHopTimer > 0 then
        App.frogHopTimer = App.frogHopTimer - dt
    end

    -- Smooth caret interpolation
    local lerpRate = math.min(1, dt * 28)
    App.caretX = App.caretX + (App.targetCaretX - App.caretX) * lerpRate
    App.caretY = App.caretY + (App.targetCaretY - App.caretY) * lerpRate

    -- Smooth scroll interpolation
    local scrollRate = math.min(1, dt * 14)
    App.scrollY = App.scrollY + (App.targetScrollY - App.scrollY) * scrollRate

    -- Test timing
    if App.state == "typing" then
        App.elapsedTime = love.timer.getTime() - App.startTime

        -- Check time limit
        if App.mode == "time" and App.elapsedTime >= App.timeLimit then
            App.elapsedTime = App.timeLimit
            App.finishTest()
            return
        end

        -- Record 1-second interval stats for chart
        local currentSec = math.floor(App.elapsedTime)
        if currentSec > App.lastRecordedSecond and currentSec >= 1 then
            App.lastRecordedSecond = currentSec
            table.insert(App.history, {
                sec = currentSec,
                wpm = App.getWpm(),
                raw = App.getRawWpm(),
                errors = App.currentSecondErrors
            })
            App.currentSecondErrors = 0
        end
    end
end

function love.textinput(text)
    if App.gameMode == "arcade" then
        Arcade.textinput(text)
        return
    end

    if App.state == "results" then return end
    if text == " " then return end -- Space handled in keypressed

    if App.state == "idle" then
        App.state = "typing"
        App.startTime = love.timer.getTime()
    end

    local currentWord = App.words[App.currentWordIndex]
    if not currentWord then return end

    App.totalKeystrokes = App.totalKeystrokes + 1
    App.totalTypedChars = App.totalTypedChars + 1

    currentWord.typed = currentWord.typed .. text
    local charIdx = #currentWord.typed

    if charIdx <= #currentWord.target then
        local expectedChar = currentWord.target:sub(charIdx, charIdx)
        if text == expectedChar then
            currentWord.chars[charIdx].status = "correct"
            App.correctChars = App.correctChars + 1
            Sound.playKey()
        else
            currentWord.chars[charIdx].status = "incorrect"
            currentWord.hasError = true
            App.incorrectChars = App.incorrectChars + 1
            App.currentSecondErrors = App.currentSecondErrors + 1
            Sound.playKey()
        end
    else
        -- Extra characters beyond target length
        table.insert(currentWord.extras, text)
        currentWord.hasError = true
        App.extraChars = App.extraChars + 1
        App.currentSecondErrors = App.currentSecondErrors + 1
        Sound.playKey()
        App.recalculateLayout()
    end

    App.updateCaretTarget(false)

    -- Auto-finish test if completed the last word in words mode
    if App.mode == "words" and App.currentWordIndex == #App.words then
        if #currentWord.typed == #currentWord.target then
            currentWord.isComplete = true
            App.finishTest()
            return
        end
    end
end

function love.keypressed(key)
    -- Global Mode Switch
    if key == "f1" then
        App.gameMode = (App.gameMode == "arcade" and "classic" or "arcade")
        if App.gameMode == "arcade" then
            Arcade.resize(love.graphics.getDimensions())
        end
        return
    end

    -- Global Shortcuts
    if key == "f2" then
        Themes.next()
        return
    end

    if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) and key == "m" then
        Sound.toggle()
        return
    end

    if App.gameMode == "arcade" then
        Arcade.keypressed(key)
        return
    end

    if key == "tab" then
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            App.resetTest(true) -- Repeat same test
        else
            App.resetTest(false) -- New test
        end
        return
    end

    if key == "escape" then
        App.resetTest(false)
        return
    end

    if App.state == "results" then
        if key == "return" or key == "space" then
            App.resetTest(false)
        end
        return
    end

    -- Backspace handling
    if key == "backspace" then
        local currentWord = App.words[App.currentWordIndex]
        if not currentWord then return end

        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            -- Delete entire current word input
            if #currentWord.typed > 0 then
                -- Revert stats
                for _, ch in ipairs(currentWord.chars) do
                    if ch.status == "correct" then App.correctChars = math.max(0, App.correctChars - 1) end
                    if ch.status == "incorrect" then App.incorrectChars = math.max(0, App.incorrectChars - 1) end
                    ch.status = "untyped"
                end
                App.extraChars = math.max(0, App.extraChars - #currentWord.extras)
                App.totalTypedChars = math.max(0, App.totalTypedChars - #currentWord.typed)
                currentWord.typed = ""
                currentWord.extras = {}
                currentWord.hasError = false
                Sound.playBackspace()
                App.recalculateLayout()
                App.updateCaretTarget(false)
            end
            return
        end

        if #currentWord.typed > 0 then
            Sound.playBackspace()
            local charIdx = #currentWord.typed

            if charIdx > #currentWord.target then
                table.remove(currentWord.extras)
                App.extraChars = math.max(0, App.extraChars - 1)
                App.recalculateLayout()
            else
                local status = currentWord.chars[charIdx].status
                if status == "correct" then
                    App.correctChars = math.max(0, App.correctChars - 1)
                elseif status == "incorrect" then
                    App.incorrectChars = math.max(0, App.incorrectChars - 1)
                end
                currentWord.chars[charIdx].status = "untyped"
            end

            currentWord.typed = currentWord.typed:sub(1, -2)
            App.totalTypedChars = math.max(0, App.totalTypedChars - 1)
            App.updateCaretTarget(false)
        else
            -- If at start of word and previous word had errors, jump back!
            if App.currentWordIndex > 1 then
                local prevWord = App.words[App.currentWordIndex - 1]
                if prevWord and prevWord.hasError then
                    App.currentWordIndex = App.currentWordIndex - 1
                    Sound.playBackspace()
                    App.updateCaretTarget(false)
                end
            end
        end
        return
    end

    -- Spacebar handling: advance word
    if key == "space" then
        local currentWord = App.words[App.currentWordIndex]
        if not currentWord then return end

        if #currentWord.typed == 0 then
            return -- Don't skip empty words
        end

        Sound.playSpace()
        App.frogHopTimer = 0.25 -- Frog hop animation trigger!

        -- Mark missed characters if word wasn't fully typed
        if #currentWord.typed < #currentWord.target then
            currentWord.hasError = true
            for c = #currentWord.typed + 1, #currentWord.target do
                App.missedChars = App.missedChars + 1
            end
        end

        currentWord.isComplete = true

        -- Advance to next word
        if App.currentWordIndex < #App.words then
            App.currentWordIndex = App.currentWordIndex + 1
            App.updateCaretTarget(false)
        else
            -- Completed all words in words mode!
            App.finishTest()
            return
        end

        -- In words mode, check if target count reached
        if App.mode == "words" and App.currentWordIndex > App.wordsSelected then
            App.finishTest()
        end
    end
end

function love.resize(w, h)
    Arcade.resize(w, h)
    App.recalculateLayout()
    App.updateCaretTarget(true)
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end

    for _, btn in ipairs(App.buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            if btn.onClick then
                btn.onClick()
            end
            return
        end
    end
end

-- =========================================================================
-- DRAWING LOGIC
-- =========================================================================

function love.draw()
    local theme = Themes.current()
    local winW, winH = love.graphics.getDimensions()
    App.buttons = {} -- Clear button bounds for click detection

    -- Background
    love.graphics.clear(theme.bg)

    -- Top Navigation & Header
    drawHeader(theme, winW, winH)

    if App.gameMode == "arcade" then
        Arcade.draw(theme, winW, winH, App.fonts)
    else
        if App.state == "results" then
            drawResultsScreen(theme, winW, winH)
        else
            drawTypingScreen(theme, winW, winH)
        end
    end

    -- Footer info / key hints
    drawFooter(theme, winW, winH)
end

function drawHeader(theme, winW, winH)
    -- Logo and mascot
    local logoX = 60
    local logoY = 40
    
    -- Draw little animated frog next to title
    local isHopping = (App.frogHopTimer > 0)
    Frog.drawMascot(logoX + 16, logoY + 12, 0.9, App.globalTime, isHopping, theme)

    love.graphics.setFont(App.fonts.title)
    love.graphics.setColor(theme.text)
    love.graphics.print("froggertype", logoX + 44, logoY - 4)

    love.graphics.setFont(App.fonts.subtitle)
    love.graphics.setColor(theme.sub)
    local subTitle = (App.gameMode == "arcade") and "arcade frogger crossing" or "minimalist typing speed test"
    love.graphics.print(subTitle, logoX + 46, logoY + 28)

    -- Top Navigation Pill Bar (Monkeytype style)
    local navH = 38
    local navY = logoY + 2
    local panelW = (App.gameMode == "arcade") and 490 or 600
    local panelX = (winW - panelW) / 2

    -- Pill Background
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", panelX, navY, panelW, navH, 8, 8)

    local mx, my = love.mouse.getPosition()
    local curX = panelX + 12

    -- Helper for clickable pill items
    local function drawNavPill(text, isActive, onClick)
        love.graphics.setFont(App.fonts.ui)
        local tw = App.fonts.ui:getWidth(text)
        local btnW = tw + 14
        local btnH = navH - 8
        local btnY = navY + 4

        local hovered = (mx >= curX and mx <= curX + btnW and my >= btnY and my <= btnY + btnH)
        
        if isActive then
            love.graphics.setColor(theme.main)
        elseif hovered then
            love.graphics.setColor(theme.text)
        else
            love.graphics.setColor(theme.sub)
        end

        love.graphics.print(text, curX + 7, btnY + 5)

        table.insert(App.buttons, {
            x = curX, y = btnY, w = btnW, h = btnH,
            onClick = onClick
        })

        curX = curX + btnW + 2
    end

    -- Top Mode Switch: Arcade vs Classic
    drawNavPill("🕹️ arcade", App.gameMode == "arcade", function()
        App.gameMode = "arcade"
        Arcade.resize(love.graphics.getDimensions())
    end)

    drawNavPill("⌨️ classic", App.gameMode == "classic", function()
        App.gameMode = "classic"
    end)

    -- Divider
    love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.3)
    love.graphics.line(curX + 6, navY + 8, curX + 6, navY + navH - 8)
    curX = curX + 16

    if App.gameMode == "arcade" then
        love.graphics.setFont(App.fonts.ui)
        love.graphics.setColor(theme.sub)
        love.graphics.print("Type words to hop! (F1: toggle)", curX + 6, navY + 10)
    else
        -- Modifier: Punctuation
        drawNavPill("@ punct", App.punctuation, function()
            App.punctuation = not App.punctuation
            App.resetTest(false)
        end)

        -- Modifier: Numbers
        drawNavPill("# num", App.numbers, function()
            App.numbers = not App.numbers
            App.resetTest(false)
        end)

        -- Divider
        love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.3)
        love.graphics.line(curX + 6, navY + 8, curX + 6, navY + navH - 8)
        curX = curX + 16

        -- Mode: Time
        drawNavPill("time", App.mode == "time", function()
            App.mode = "time"
            App.resetTest(false)
        end)

        -- Mode: Words
        drawNavPill("words", App.mode == "words", function()
            App.mode = "words"
            App.resetTest(false)
        end)

        -- Divider
        love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.3)
        love.graphics.line(curX + 6, navY + 8, curX + 6, navY + navH - 8)
        curX = curX + 16

        -- Sub-options depending on mode
        if App.mode == "time" then
            for _, t in ipairs(App.timeOptions) do
                drawNavPill(tostring(t), App.timeSelected == t, function()
                    App.timeSelected = t
                    App.resetTest(false)
                end)
            end
        else
            for _, w in ipairs(App.wordsOptions) do
                drawNavPill(tostring(w), App.wordsSelected == w, function()
                    App.wordsSelected = w
                    App.resetTest(false)
                end)
            end
        end
    end

    -- Right-side controls (Theme button & Sound toggle)
    local rightX = winW - 220
    
    -- Sound toggle pill
    local soundText = Sound.enabled and "🔊 sound" or "🔇 mute"
    love.graphics.setFont(App.fonts.ui)
    local soundW = App.fonts.ui:getWidth(soundText) + 16
    local soundH = navH
    local soundHover = (mx >= rightX and mx <= rightX + soundW and my >= navY and my <= navY + soundH)
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", rightX, navY, soundW, soundH, 8, 8)
    love.graphics.setColor(soundHover and theme.main or theme.sub)
    love.graphics.print(soundText, rightX + 8, navY + 10)
    table.insert(App.buttons, {
        x = rightX, y = navY, w = soundW, h = soundH,
        onClick = function() Sound.toggle() end
    })

    -- Theme button
    local themeText = "🎨 " .. theme.name
    local themeX = rightX + soundW + 10
    local themeW = App.fonts.ui:getWidth(themeText) + 16
    local themeHover = (mx >= themeX and mx <= themeX + themeW and my >= navY and my <= navY + soundH)
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", themeX, navY, themeW, soundH, 8, 8)
    love.graphics.setColor(themeHover and theme.main or theme.sub)
    love.graphics.print(themeText, themeX + 8, navY + 10)
    table.insert(App.buttons, {
        x = themeX, y = navY, w = themeW, h = soundH,
        onClick = function() Themes.next() end
    })
end

function drawTypingScreen(theme, winW, winH)
    -- Live Counter (Timer or Word Count)
    love.graphics.setFont(App.fonts.statsMed)
    love.graphics.setColor(theme.main)

    local counterText = ""
    if App.mode == "time" then
        if App.state == "idle" then
            counterText = tostring(App.timeLimit)
        else
            local remaining = math.max(0, math.ceil(App.timeLimit - App.elapsedTime))
            counterText = tostring(remaining)
        end
    else
        counterText = string.format("%d / %d", math.min(App.wordsSelected, App.currentWordIndex - 1), App.wordsSelected)
    end
    
    local counterX = (winW - App.contentWidth) / 2
    love.graphics.print(counterText, counterX, 150)

    -- Live WPM indicator when typing
    if App.state == "typing" then
        love.graphics.setFont(App.fonts.ui)
        love.graphics.setColor(theme.sub)
        local liveWpm = App.getWpm()
        love.graphics.print(string.format("%d wpm", liveWpm), counterX + 80, 156)
    end

    -- ==========================================
    -- Frogger Lily Pad Leap Progress Track
    -- ==========================================
    local trackY = 195
    local trackW = App.contentWidth
    local trackX = counterX

    -- Track water line
    love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.line(trackX, trackY, trackX + trackW, trackY)

    -- Lily pads along the track
    local progress = App.getProgress()
    local pads = 10
    for p = 0, pads do
        local px = trackX + (p / pads) * trackW
        local isReached = (progress >= (p / pads))
        
        if isReached then
            love.graphics.setColor(theme.main[1], theme.main[2], theme.main[3], 0.7)
        else
            love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.35)
        end
        love.graphics.ellipse("fill", px, trackY, 7, 3.5)
    end

    -- The leaping frog icon on the progress track!
    local frogTrackX = trackX + progress * trackW
    local frogHop = (App.frogHopTimer > 0) and -8 or 0
    Frog.drawMascot(frogTrackX, trackY - 14 + frogHop, 0.45, App.globalTime, App.frogHopTimer > 0, theme)

    -- ==========================================
    -- Words Display (3-Line View with Scissor)
    -- ==========================================
    local font = App.fonts.typing
    love.graphics.setFont(font)

    local viewY = 220
    local viewH = App.lineHeight * 3.3
    
    -- Scissor clips outside lines so scrolling is buttery smooth
    love.graphics.setScissor(counterX - 20, viewY - 10, App.contentWidth + 40, viewH)

    love.graphics.push()
    love.graphics.translate(0, -App.scrollY)

    -- Render all visible words
    for _, word in ipairs(App.words) do
        local wx = word.x
        local wy = word.y

        -- Only render if near the view
        if wy - App.scrollY > viewY - 60 and wy - App.scrollY < viewY + viewH + 60 then
            local targetLen = #word.target
            local charX = wx

            -- Draw target characters
            for cIdx, chObj in ipairs(word.chars) do
                local charStr = chObj.char
                local charW = font:getWidth(charStr)

                if chObj.status == "correct" then
                    love.graphics.setColor(theme.text)
                elseif chObj.status == "incorrect" then
                    love.graphics.setColor(theme.error)
                else
                    love.graphics.setColor(theme.sub)
                end

                love.graphics.print(charStr, charX, wy)
                charX = charX + charW
            end

            -- Draw extra characters (if user typed beyond target length)
            for _, exChar in ipairs(word.extras) do
                local exW = font:getWidth(exChar)
                -- Red underline / warning highlight for extra characters
                love.graphics.setColor(theme.error_extra)
                love.graphics.print(exChar, charX, wy)
                love.graphics.setLineWidth(2)
                love.graphics.line(charX, wy + font:getHeight() - 2, charX + exW, wy + font:getHeight() - 2)
                charX = charX + exW
            end
        end
    end

    -- ==========================================
    -- Smooth Animated Caret
    -- ==========================================
    local caretAlpha = 1
    if App.state == "idle" then
        caretAlpha = 0.4 + 0.6 * math.abs(math.sin(App.caretBlink * 4))
    end

    love.graphics.setColor(theme.caret[1], theme.caret[2], theme.caret[3], caretAlpha)
    local caretHeight = font:getHeight() - 4
    love.graphics.rectangle("fill", App.caretX, App.caretY + 2, 2.5, caretHeight, 1.5, 1.5)

    love.graphics.pop()
    love.graphics.setScissor()

    -- Reset test button icon below typing area
    drawRestartPrompt(theme, winW, 400)
end

function drawRestartPrompt(theme, winW, y)
    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(App.fonts.ui)
    
    local text = "tab - restart test"
    local tw = App.fonts.ui:getWidth(text)
    local btnW = tw + 28
    local btnH = 34
    local btnX = (winW - btnW) / 2
    local btnY = y

    local hovered = (mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH)

    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)

    love.graphics.setColor(hovered and theme.main or theme.sub)
    love.graphics.print("⟳  " .. text, btnX + 14, btnY + 8)

    table.insert(App.buttons, {
        x = btnX, y = btnY, w = btnW, h = btnH,
        onClick = function() App.resetTest(false) end
    })
end

function drawResultsActions(theme, winW, y)
    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(App.fonts.ui)

    local btnW = 160
    local btnH = 36
    local gap = 16
    local totalW = btnW * 2 + gap
    local startX = (winW - totalW) / 2

    -- Next Test Button
    local h1 = (mx >= startX and mx <= startX + btnW and my >= y and my <= y + btnH)
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", startX, y, btnW, btnH, 8, 8)
    love.graphics.setColor(h1 and theme.main or theme.text)
    love.graphics.print("⟳  next test (tab)", startX + 16, y + 9)
    table.insert(App.buttons, {
        x = startX, y = y, w = btnW, h = btnH,
        onClick = function() App.resetTest(false) end
    })

    -- Repeat Same Words Button
    local x2 = startX + btnW + gap
    local h2 = (mx >= x2 and mx <= x2 + btnW and my >= y and my <= y + btnH)
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", x2, y, btnW, btnH, 8, 8)
    love.graphics.setColor(h2 and theme.main or theme.text)
    love.graphics.print("🔁 repeat (shift+tab)", x2 + 12, y + 9)
    table.insert(App.buttons, {
        x = x2, y = y, w = btnW, h = btnH,
        onClick = function() App.resetTest(true) end
    })
end

function drawResultsScreen(theme, winW, winH)
    local wpm = App.getWpm()
    local acc = App.getAccuracy()
    local rawWpm = App.getRawWpm()
    local consistency = App.getConsistency()
    local totalTime = math.floor(App.elapsedTime * 10) / 10

    local panelX = (winW - 900) / 2
    local panelY = 120

    -- Left big stats
    love.graphics.setFont(App.fonts.subtitle)
    love.graphics.setColor(theme.sub)
    love.graphics.print("wpm", panelX, panelY)

    love.graphics.setFont(App.fonts.statsBig)
    love.graphics.setColor(theme.main)
    love.graphics.print(tostring(wpm), panelX, panelY + 18)

    love.graphics.setFont(App.fonts.subtitle)
    love.graphics.setColor(theme.sub)
    love.graphics.print("acc", panelX, panelY + 86)

    love.graphics.setFont(App.fonts.statsBig)
    love.graphics.setColor(theme.text)
    love.graphics.print(string.format("%d%%", math.floor(acc)), panelX, panelY + 104)

    -- Secondary detail stats
    local statX = panelX
    local statY = panelY + 176
    local function drawSubStat(label, val)
        love.graphics.setFont(App.fonts.subtitle)
        love.graphics.setColor(theme.sub)
        love.graphics.print(label, statX, statY)
        love.graphics.setFont(App.fonts.statsMed)
        love.graphics.setColor(theme.text)
        love.graphics.print(val, statX, statY + 16)
        statY = statY + 46
    end

    local testTypeStr = App.mode == "time" and string.format("time %ds", App.timeLimit) or string.format("words %d", App.wordsSelected)
    drawSubStat("test type", testTypeStr)
    drawSubStat("raw", tostring(rawWpm))
    drawSubStat("characters", string.format("%d/%d/%d/%d", App.correctChars, App.incorrectChars, App.extraChars, App.missedChars))
    drawSubStat("consistency", string.format("%d%%", consistency))
    drawSubStat("time", string.format("%.1fs", totalTime))

    -- ==========================================
    -- Monkeytype Signature Chart / Graph
    -- ==========================================
    local chartX = panelX + 220
    local chartY = panelY + 15
    local chartW = 680
    local chartH = 280

    drawChart(theme, chartX, chartY, chartW, chartH)

    -- Restart buttons below
    local btnY = panelY + 340
    drawResultsActions(theme, winW, btnY)
end

function drawChart(theme, cx, cy, cw, ch)
    -- Chart background panel
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 8, 8)

    if #App.history < 2 then
        love.graphics.setFont(App.fonts.ui)
        love.graphics.setColor(theme.sub)
        love.graphics.printf("Test finished quickly — take a longer test to view timeline curve!", cx + 20, cy + ch / 2 - 10, cw - 40, "center")
        return
    end

    -- Determine chart scales
    local maxWpm = 40
    local maxSec = App.history[#App.history].sec
    if maxSec <= 0 then maxSec = 1 end

    for _, pt in ipairs(App.history) do
        if pt.wpm > maxWpm then maxWpm = pt.wpm end
        if pt.raw > maxWpm then maxWpm = pt.raw end
    end
    maxWpm = math.ceil((maxWpm + 10) / 20) * 20 -- round up to neat multiple of 20

    -- Horizontal gridlines & Y labels
    love.graphics.setFont(App.fonts.subtitle)
    local gridLines = 4
    for i = 0, gridLines do
        local val = math.floor((maxWpm / gridLines) * i)
        local gy = cy + ch - 30 - (val / maxWpm) * (ch - 50)
        
        love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.15)
        love.graphics.setLineWidth(1)
        love.graphics.line(cx + 40, gy, cx + cw - 20, gy)

        love.graphics.setColor(theme.sub)
        love.graphics.print(tostring(val), cx + 10, gy - 8)
    end

    -- Plot points helper
    local function getPointCoords(pt)
        local px = cx + 45 + (pt.sec / maxSec) * (cw - 75)
        local py = cy + ch - 30 - (pt.wpm / maxWpm) * (ch - 50)
        local rawPy = cy + ch - 30 - (pt.raw / maxWpm) * (ch - 50)
        return px, py, rawPy
    end

    -- Draw Raw WPM Line (dashed / subtle)
    love.graphics.setColor(theme.graph_raw or theme.sub)
    love.graphics.setLineWidth(2)
    for i = 1, #App.history - 1 do
        local x1, _, ry1 = getPointCoords(App.history[i])
        local x2, _, ry2 = getPointCoords(App.history[i + 1])
        love.graphics.line(x1, ry1, x2, ry2)
    end

    -- Draw WPM Area Fill & Line
    local polygonPoints = {}
    local firstX, _, _ = getPointCoords(App.history[1])
    local lastX, _, _ = getPointCoords(App.history[#App.history])
    local baseY = cy + ch - 30

    table.insert(polygonPoints, firstX)
    table.insert(polygonPoints, baseY)

    for _, pt in ipairs(App.history) do
        local px, py = getPointCoords(pt)
        table.insert(polygonPoints, px)
        table.insert(polygonPoints, py)
    end

    table.insert(polygonPoints, lastX)
    table.insert(polygonPoints, baseY)

    -- Area fill
    if #polygonPoints >= 6 then
        love.graphics.setColor(theme.main[1], theme.main[2], theme.main[3], 0.12)
        love.graphics.polygon("fill", polygonPoints)
    end

    -- Main WPM glowing line
    love.graphics.setColor(theme.main)
    love.graphics.setLineWidth(3)
    for i = 1, #App.history - 1 do
        local x1, y1 = getPointCoords(App.history[i])
        local x2, y2 = getPointCoords(App.history[i + 1])
        love.graphics.line(x1, y1, x2, y2)
    end

    -- Dots for each point & error markers
    for _, pt in ipairs(App.history) do
        local px, py = getPointCoords(pt)
        -- WPM point
        love.graphics.setColor(theme.main)
        love.graphics.circle("fill", px, py, 3.5)

        -- If error occurred in this second, draw red marker
        if pt.errors and pt.errors > 0 then
            love.graphics.setColor(theme.error)
            love.graphics.circle("fill", px, baseY + 6, 4)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(px - 2, baseY + 4, px + 2, baseY + 8)
            love.graphics.line(px + 2, baseY + 4, px - 2, baseY + 8)
        end
    end

    -- Chart Legend
    local legendY = cy + 12
    love.graphics.setFont(App.fonts.subtitle)

    -- WPM Legend
    love.graphics.setColor(theme.main)
    love.graphics.circle("fill", cx + cw - 180, legendY + 6, 4)
    love.graphics.print("wpm", cx + cw - 170, legendY)

    -- Raw Legend
    love.graphics.setColor(theme.graph_raw or theme.sub)
    love.graphics.circle("fill", cx + cw - 110, legendY + 6, 4)
    love.graphics.print("raw", cx + cw - 100, legendY)

    -- Errors Legend
    love.graphics.setColor(theme.error)
    love.graphics.circle("fill", cx + cw - 50, legendY + 6, 4)
    love.graphics.print("err", cx + cw - 40, legendY)
end

function drawFooter(theme, winW, winH)
    local footerY = winH - 36
    love.graphics.setFont(App.fonts.subtitle)
    love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.7)

    -- Left hints
    if App.gameMode == "arcade" then
        love.graphics.print("f1 : classic mode   •   type floating words to leap   •   esc : restart   •   f2 : theme", 50, footerY)
    else
        love.graphics.print("f1 : arcade mode   •   tab / esc : restart   •   ctrl+backspace : delete word   •   f2 : theme", 50, footerY)
    end

    -- Right theme & version
    local infoStr = string.format("theme: %s   •   froggertype v2.0", theme.name)
    local infoW = App.fonts.subtitle:getWidth(infoStr)
    love.graphics.print(infoStr, winW - infoW - 50, footerY)
end
