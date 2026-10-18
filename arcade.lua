local Words = require("words")
local Sound = require("sound")
local Frog = require("frog")

local Arcade = {
    -- State: "playing", "dead_anim", "game_over", "level_win"
    state = "playing",
    
    -- Progression
    level = 1,
    score = 0,
    highScore = 0,
    lives = 3,
    maxLives = 3,
    goalsFilled = {false, false, false, false, false},
    
    -- Typing stats for current run
    runKeystrokes = 0,
    runCorrect = 0,
    runStartTime = 0,
    runElapsedTime = 0,
    
    -- Frog position & movement
    frog = {
        lane = 0, -- 0 (start bank) to 9 (goals)
        x = 0,
        y = 0,
        targetX = 0,
        targetY = 0,
        startX = 0,
        startY = 0,
        isJumping = false,
        jumpProgress = 0,
        jumpDuration = 0.18,
        facing = "up",
        currentPlatform = nil -- attached log/pad reference if on river
    },
    
    -- Lane definitions (0 to 9)
    lanes = {},
    
    -- Moving entities: cars on roads, logs & pads on river
    cars = {},
    platforms = {},
    bonusFlies = {},
    
    -- Current typed input buffer
    typedInput = "",
    targetedEntity = nil,
    
    -- Particles / Floating text
    particles = {},
    popups = {},
    
    -- Timers
    stateTimer = 0,
    globalTime = 0,
    
    -- Playfield bounds
    board = {
        x = 60,
        y = 90,
        w = 980,
        h = 580,
        laneH = 58
    }
}

-- Curated word pools by length for exciting game pacing
local SHORT_WORDS = {
    "hop", "pad", "log", "bug", "run", "fly", "mud", "wet", "dip", "sun",
    "leap", "pond", "swim", "fast", "rush", "safe", "jump", "bank", "moss", "tree",
    "flow", "wave", "croak", "water", "river", "shore", "green", "swift"
}

local MEDIUM_WORDS = {
    "lilypad", "current", "splashing", "swimming", "jumping", "floating", "ripples",
    "stream", "tadpole", "highway", "traffic", "crossing", "boulder", "shelter",
    "journey", "spring", "splash", "feather", "sunlight", "swampy", "insects"
}

local function getRandomWord(level)
    if level == 1 or math.random() < 0.65 then
        return SHORT_WORDS[math.random(1, #SHORT_WORDS)]
    else
        return MEDIUM_WORDS[math.random(1, #MEDIUM_WORDS)]
    end
end

function Arcade.resize(winW, winH)
    winW = winW or love.graphics.getWidth()
    winH = winH or love.graphics.getHeight()
    local b = Arcade.board
    b.w = math.min(1000, winW - 80)
    b.x = (winW - b.w) / 2
    b.y = 80
    b.h = math.min(580, winH - 120)
    b.laneH = b.h / 10

    for i = 0, 9 do
        if Arcade.lanes and Arcade.lanes[i] then
            Arcade.lanes[i].y = b.y + b.h - (i + 1) * b.laneH
            Arcade.lanes[i].h = b.laneH
        end
    end
end

function Arcade.init()
    Arcade.resize(love.graphics.getDimensions())
    Arcade.score = 0
    Arcade.level = 1
    Arcade.lives = 3
    Arcade.goalsFilled = {false, false, false, false, false}
    Arcade.runKeystrokes = 0
    Arcade.runCorrect = 0
    Arcade.runStartTime = love.timer.getTime()
    Arcade.runElapsedTime = 0
    Arcade.particles = {}
    Arcade.popups = {}
    Arcade.bonusFlies = {}
    
    Arcade.setupLevel()
    Arcade.resetFrogToStart()
    Arcade.state = "playing"
end

function Arcade.setupLevel()
    local b = Arcade.board
    local speedMult = 1.0 + (Arcade.level - 1) * 0.22

    -- Lanes configuration:
    -- Lane 0: Bottom safe bank
    -- Lane 1, 2, 3: Road
    -- Lane 4: Middle safe bank
    -- Lane 5, 6, 7, 8: River
    -- Lane 9: Top goal bank
    Arcade.lanes = {}
    for i = 0, 9 do
        local ly = b.y + b.h - (i + 1) * b.laneH
        local ltype = "safe"
        if i >= 1 and i <= 3 then
            ltype = "road"
        elseif i == 4 then
            ltype = "safe"
        elseif i >= 5 and i <= 8 then
            ltype = "river"
        elseif i == 9 then
            ltype = "goals"
        end

        Arcade.lanes[i] = {
            index = i,
            y = ly,
            h = b.laneH,
            type = ltype
        }
    end

    -- Generate Cars for Road Lanes (1, 2, 3)
    Arcade.cars = {}
    -- Lane 1: Slow cars ->
    Arcade.spawnCarLane(1, 1, 90 * speedMult, {
        {model = "sedan", color = {0.85, 0.25, 0.25}},
        {model = "taxi", color = {0.95, 0.75, 0.15}}
    }, 3)

    -- Lane 2: Fast racecars <-
    Arcade.spawnCarLane(2, -1, 150 * speedMult, {
        {model = "racer", color = {0.2, 0.6, 0.95}},
        {model = "truck", color = {0.7, 0.3, 0.8}}
    }, 2)

    -- Lane 3: Heavy trucks ->
    Arcade.spawnCarLane(3, 1, 110 * speedMult, {
        {model = "truck", color = {0.85, 0.5, 0.2}},
        {model = "bus", color = {0.25, 0.75, 0.4}}
    }, 2)

    -- Generate River Platforms for Lanes (5, 6, 7, 8)
    Arcade.platforms = {}
    -- Lane 5: Medium logs <-
    Arcade.spawnPlatformLane(5, -1, 75 * speedMult, "log", 130, 3)
    -- Lane 6: Lily pads & Turtles ->
    Arcade.spawnPlatformLane(6, 1, 105 * speedMult, "turtle", 100, 4)
    -- Lane 7: Long logs <-
    Arcade.spawnPlatformLane(7, -1, 85 * speedMult, "log", 180, 2)
    -- Lane 8: Swift lily pads ->
    Arcade.spawnPlatformLane(8, 1, 120 * speedMult, "pad", 95, 3)

    -- Assign target words to all platforms and safe zones ahead
    Arcade.refreshPlatformWords()
end

function Arcade.spawnCarLane(laneIdx, dir, speed, models, count)
    local b = Arcade.board
    local laneY = Arcade.lanes[laneIdx].y
    local spacing = b.w / count

    for i = 1, count do
        local modelInfo = models[((i - 1) % #models) + 1]
        local carW = (modelInfo.model == "truck" or modelInfo.model == "bus") and 110 or 75
        local startX = b.x + (i - 1) * spacing + math.random(-20, 20)
        table.insert(Arcade.cars, {
            lane = laneIdx,
            x = startX,
            y = laneY + (b.laneH - 34) / 2,
            w = carW,
            h = 32,
            dir = dir,
            speed = speed,
            model = modelInfo.model,
            color = modelInfo.color
        })
    end
end

function Arcade.spawnPlatformLane(laneIdx, dir, speed, ptype, width, count)
    local b = Arcade.board
    local laneY = Arcade.lanes[laneIdx].y
    local spacing = b.w / count

    for i = 1, count do
        local startX = b.x + (i - 1) * spacing + math.random(-30, 30)
        table.insert(Arcade.platforms, {
            lane = laneIdx,
            x = startX,
            y = laneY + (b.laneH - 36) / 2,
            w = width,
            h = 36,
            dir = dir,
            speed = speed,
            type = ptype, -- "log", "pad", "turtle"
            word = getRandomWord(Arcade.level),
            submerged = false
        })
    end
end

function Arcade.refreshPlatformWords()
    local used = {}
    for _, p in ipairs(Arcade.platforms) do
        local w = getRandomWord(Arcade.level)
        while used[w] do
            w = getRandomWord(Arcade.level)
        end
        used[w] = true
        p.word = w
    end
end

function Arcade.resetFrogToStart()
    local b = Arcade.board
    local startLane = Arcade.lanes[0]
    Arcade.frog.lane = 0
    Arcade.frog.x = b.x + b.w / 2
    Arcade.frog.y = startLane.y + (b.laneH - 28) / 2
    Arcade.frog.targetX = Arcade.frog.x
    Arcade.frog.targetY = Arcade.frog.y
    Arcade.frog.startX = Arcade.frog.x
    Arcade.frog.startY = Arcade.frog.y
    Arcade.frog.isJumping = false
    Arcade.frog.jumpProgress = 0
    Arcade.frog.facing = "up"
    Arcade.frog.currentPlatform = nil
    Arcade.typedInput = ""
    Arcade.targetedEntity = nil
end

function Arcade.getWpm()
    if Arcade.runElapsedTime <= 0 then return 0 end
    local minutes = Arcade.runElapsedTime / 60
    local wordsTyped = (Arcade.runCorrect) / 5
    return math.max(0, math.floor(wordsTyped / minutes + 0.5))
end

function Arcade.addPopup(text, x, y, color)
    table.insert(Arcade.popups, {
        text = text,
        x = x,
        y = y,
        color = color or {1, 1, 0.3, 1},
        life = 1.0,
        maxLife = 1.0
    })
end

function Arcade.addParticles(x, y, count, color)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local spd = math.random(40, 160)
        table.insert(Arcade.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            life = math.random(0.3, 0.7),
            maxLife = 0.7,
            color = color or {0.4, 0.9, 0.5, 1},
            size = math.random(2, 4)
        })
    end
end

-- =========================================================================
-- UPDATE LOGIC
-- =========================================================================

function Arcade.update(dt)
    Arcade.globalTime = Arcade.globalTime + dt
    local b = Arcade.board

    -- Update particles & popups
    for i = #Arcade.particles, 1, -1 do
        local p = Arcade.particles[i]
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        if p.life <= 0 then
            table.remove(Arcade.particles, i)
        end
    end

    for i = #Arcade.popups, 1, -1 do
        local pop = Arcade.popups[i]
        pop.life = pop.life - dt
        pop.y = pop.y - 30 * dt
        if pop.life <= 0 then
            table.remove(Arcade.popups, i)
        end
    end

    if Arcade.state == "dead_anim" then
        Arcade.stateTimer = Arcade.stateTimer - dt
        if Arcade.stateTimer <= 0 then
            if Arcade.lives > 0 then
                Arcade.state = "playing"
                Arcade.resetFrogToStart()
            else
                Arcade.state = "game_over"
                if Arcade.score > Arcade.highScore then
                    Arcade.highScore = Arcade.score
                end
            end
        end
        return
    end

    if Arcade.state == "level_win" then
        Arcade.stateTimer = Arcade.stateTimer - dt
        if Arcade.stateTimer <= 0 then
            Arcade.level = Arcade.level + 1
            Arcade.goalsFilled = {false, false, false, false, false}
            Arcade.setupLevel()
            Arcade.resetFrogToStart()
            Arcade.state = "playing"
        end
        return
    end

    if Arcade.state ~= "playing" then return end

    Arcade.runElapsedTime = love.timer.getTime() - Arcade.runStartTime

    -- Move cars
    for _, car in ipairs(Arcade.cars) do
        car.x = car.x + car.dir * car.speed * dt
        if car.dir == 1 and car.x > b.x + b.w + 40 then
            car.x = b.x - car.w - 40
        elseif car.dir == -1 and car.x < b.x - car.w - 40 then
            car.x = b.x + b.w + 40
        end
    end

    -- Move platforms (logs/pads)
    for _, plat in ipairs(Arcade.platforms) do
        plat.x = plat.x + plat.dir * plat.speed * dt
        if plat.dir == 1 and plat.x > b.x + b.w + 60 then
            plat.x = b.x - plat.w - 60
            plat.word = getRandomWord(Arcade.level)
        elseif plat.dir == -1 and plat.x < b.x - plat.w - 60 then
            plat.x = b.x + b.w + 60
            plat.word = getRandomWord(Arcade.level)
        end
    end

    -- Update Frog Leap Animation
    if Arcade.frog.isJumping then
        Arcade.frog.jumpProgress = Arcade.frog.jumpProgress + dt / Arcade.frog.jumpDuration
        if Arcade.frog.jumpProgress >= 1.0 then
            Arcade.frog.jumpProgress = 1.0
            Arcade.frog.isJumping = false
            Arcade.frog.x = Arcade.frog.targetX
            Arcade.frog.y = Arcade.frog.targetY
            Arcade.onJumpLand()
        else
            local t = Arcade.frog.jumpProgress
            Arcade.frog.x = Arcade.frog.startX + (Arcade.frog.targetX - Arcade.frog.startX) * t
            Arcade.frog.y = Arcade.frog.startY + (Arcade.frog.targetY - Arcade.frog.startY) * t
        end
    else
        -- If resting on a platform on the river, drift with it!
        if Arcade.frog.currentPlatform then
            local plat = Arcade.frog.currentPlatform
            Arcade.frog.x = Arcade.frog.x + plat.dir * plat.speed * dt

            -- Check if drifted off the screen edge
            if Arcade.frog.x < b.x - 20 or Arcade.frog.x > b.x + b.w + 20 then
                Arcade.killFrog("splash")
                return
            end
        end

        -- Check hazard collisions when not jumping
        Arcade.checkCollisions()
    end

    -- Randomly spawn bonus flies on middle bank or lilypads
    if #Arcade.bonusFlies == 0 and math.random() < 0.003 then
        local fx = b.x + math.random(100, b.w - 100)
        local fy = Arcade.lanes[4].y + 15
        table.insert(Arcade.bonusFlies, {
            x = fx,
            y = fy,
            word = "fly",
            timer = 8.0
        })
    end

    -- Update bonus flies timer
    for i = #Arcade.bonusFlies, 1, -1 do
        local fly = Arcade.bonusFlies[i]
        fly.timer = fly.timer - dt
        if fly.timer <= 0 then
            table.remove(Arcade.bonusFlies, i)
        end
    end
end

function Arcade.checkCollisions()
    local f = Arcade.frog
    local laneInfo = Arcade.lanes[f.lane]
    if not laneInfo then return end

    -- Road collision: Hit by a car?
    if laneInfo.type == "road" then
        local frogR = 12
        for _, car in ipairs(Arcade.cars) do
            if car.lane == f.lane then
                if f.x + frogR > car.x and f.x - frogR < car.x + car.w and
                   f.y + frogR > car.y and f.y - frogR < car.y + car.h then
                    Arcade.killFrog("squish")
                    return
                end
            end
        end
    end

    -- River collision: Not on a platform?
    if laneInfo.type == "river" and not f.currentPlatform then
        Arcade.killFrog("splash")
        return
    end
end

function Arcade.onJumpLand()
    local f = Arcade.frog
    local laneInfo = Arcade.lanes[f.lane]
    if not laneInfo then return end

    -- Check if landed in River
    if laneInfo.type == "river" then
        -- Find if on any platform
        local onPlat = nil
        for _, plat in ipairs(Arcade.platforms) do
            if plat.lane == f.lane then
                if f.x >= plat.x - 10 and f.x <= plat.x + plat.w + 10 then
                    onPlat = plat
                    break
                end
            end
        end

        if onPlat then
            f.currentPlatform = onPlat
            Sound.playJump()
            Arcade.addParticles(f.x, f.y + 10, 8, {0.3, 0.8, 0.4, 0.8})
        else
            -- Landed in water!
            Arcade.killFrog("splash")
            return
        end
    else
        f.currentPlatform = nil
        Sound.playJump()
        Arcade.addParticles(f.x, f.y + 10, 6, {0.5, 0.9, 0.5, 0.7})
    end

    -- Reached Lane 9 (Goals!)
    if f.lane == 9 then
        Arcade.checkGoalHaven()
    end
end

function Arcade.checkGoalHaven()
    local b = Arcade.board
    local f = Arcade.frog
    local goalSpacing = b.w / 5

    -- Find which goal bay (1 to 5)
    local bayIndex = math.floor((f.x - b.x) / goalSpacing) + 1
    bayIndex = math.max(1, math.min(5, bayIndex))

    if not Arcade.goalsFilled[bayIndex] then
        -- Safe haven reached!
        Arcade.goalsFilled[bayIndex] = true
        Arcade.score = Arcade.score + 500
        Sound.playLevelClear()
        Arcade.addPopup("+500 RESCUED!", f.x, f.y - 20, {0.2, 1, 0.5, 1})
        Arcade.addParticles(f.x, f.y, 25, {1, 0.85, 0.2, 1})

        -- Check if all 5 havens filled!
        local allFilled = true
        for _, filled in ipairs(Arcade.goalsFilled) do
            if not filled then allFilled = false; break end
        end

        if allFilled then
            Arcade.score = Arcade.score + 2000
            Arcade.state = "level_win"
            Arcade.stateTimer = 2.2
            Sound.playFinish()
            Arcade.addPopup("LEVEL COMPLETE! +2000", b.x + b.w / 2, b.y + b.h / 2, {1, 0.9, 0.2, 1})
        else
            Arcade.resetFrogToStart()
        end
    else
        -- Already occupied bay! Splashes into bay boundary
        Arcade.killFrog("splash")
    end
end

function Arcade.killFrog(reason)
    Arcade.lives = Arcade.lives - 1
    Arcade.state = "dead_anim"
    Arcade.stateTimer = 1.0

    if reason == "squish" then
        Sound.playSquish()
        Arcade.addPopup("SQUISH!", Arcade.frog.x, Arcade.frog.y - 15, {1, 0.3, 0.3, 1})
        Arcade.addParticles(Arcade.frog.x, Arcade.frog.y, 16, {0.9, 0.3, 0.3, 1})
    else
        Sound.playSplash()
        Arcade.addPopup("SPLASH!", Arcade.frog.x, Arcade.frog.y - 15, {0.3, 0.7, 1, 1})
        Arcade.addParticles(Arcade.frog.x, Arcade.frog.y, 20, {0.4, 0.8, 1, 1})
    end

    Arcade.typedInput = ""
    Arcade.targetedEntity = nil
end

-- =========================================================================
-- TYPING INPUT HANDLING
-- =========================================================================

function Arcade.textinput(text)
    if Arcade.state ~= "playing" then return end
    if Arcade.frog.isJumping then return end

    Arcade.runKeystrokes = Arcade.runKeystrokes + 1
    local testInput = Arcade.typedInput .. text

    -- First, check bonus flies
    for i, fly in ipairs(Arcade.bonusFlies) do
        if fly.word == testInput then
            Arcade.typedInput = ""
            Arcade.score = Arcade.score + 300
            Sound.playFly()
            Arcade.addPopup("+300 SLURP! 🪰", fly.x, fly.y - 20, {1, 0.85, 0.2, 1})
            Arcade.addParticles(fly.x, fly.y, 14, {1, 0.9, 0.3, 1})
            table.remove(Arcade.bonusFlies, i)
            return
        end
    end

    -- Find target entities in the NEXT lane (or on current lane to reposition)
    local nextLaneIdx = Arcade.frog.lane + 1
    if nextLaneIdx > 9 then return end

    local candidates = {}
    local nextLaneInfo = Arcade.lanes[nextLaneIdx]

    if nextLaneInfo.type == "river" then
        -- Next lane is river: target platforms in that lane
        for _, plat in ipairs(Arcade.platforms) do
            if plat.lane == nextLaneIdx then
                table.insert(candidates, {
                    entity = plat,
                    word = plat.word,
                    targetX = plat.x + plat.w / 2,
                    targetY = plat.y + plat.h / 2,
                    lane = nextLaneIdx
                })
            end
        end
    elseif nextLaneInfo.type == "goals" then
        -- Next lane is goals (Lane 9): target open goal bays!
        local b = Arcade.board
        local goalSpacing = b.w / 5
        local goalWords = {"lily", "haven", "home", "nest", "pond"}
        for g = 1, 5 do
            if not Arcade.goalsFilled[g] then
                local gx = b.x + (g - 0.5) * goalSpacing
                local gy = nextLaneInfo.y + nextLaneInfo.h / 2
                table.insert(candidates, {
                    entity = {isGoal = true, index = g},
                    word = goalWords[g] or "safe",
                    targetX = gx,
                    targetY = gy,
                    lane = 9
                })
            end
        end
    else
        -- Next lane is road or safe bank:
        -- Generate 3 directional hops: Left, Center, Right ahead!
        local b = Arcade.board
        local f = Arcade.frog
        local curX = f.x
        local offsets = {-140, 0, 140}
        local dirWords = {
            {-140, {"left", "west", "dash", "side"}},
            {0, {"up", "leap", "step", "move", "cross"}},
            {140, {"right", "east", "skip", "hop"}}
        }

        for _, set in ipairs(dirWords) do
            local dx = set[1]
            local targetX = math.max(b.x + 40, math.min(b.x + b.w - 40, curX + dx))
            local wordList = set[2]
            local w = wordList[(Arcade.frog.lane % #wordList) + 1]
            table.insert(candidates, {
                entity = {isCrosswalk = true},
                word = w,
                targetX = targetX,
                targetY = nextLaneInfo.y + nextLaneInfo.h / 2,
                lane = nextLaneIdx
            })
        end
    end

    -- Match testInput against candidates
    local matchedTarget = nil
    local prefixMatch = false

    for _, cand in ipairs(candidates) do
        if cand.word == testInput then
            matchedTarget = cand
            break
        elseif cand.word:sub(1, #testInput) == testInput then
            prefixMatch = true
        end
    end

    if matchedTarget then
        -- Target completed! Execute Leap!
        Arcade.runCorrect = Arcade.runCorrect + #matchedTarget.word
        Arcade.score = Arcade.score + 10 * Arcade.level + #matchedTarget.word * 5
        Sound.playKey()

        -- Trigger frog leap
        local f = Arcade.frog
        f.startX = f.x
        f.startY = f.y
        f.targetX = matchedTarget.targetX
        f.targetY = matchedTarget.targetY
        f.lane = matchedTarget.lane
        f.isJumping = true
        f.jumpProgress = 0
        f.currentPlatform = nil
        Sound.playJump()

        -- Reset input buffer
        Arcade.typedInput = ""
        Arcade.targetedEntity = nil
    elseif prefixMatch then
        Arcade.runCorrect = Arcade.runCorrect + 1
        Arcade.typedInput = testInput
        Sound.playKey()
    else
        -- Typo
        Sound.playKey()
        Arcade.typedInput = testInput -- Keep for error display until backspaced
    end
end

function Arcade.keypressed(key)
    if Arcade.state == "game_over" then
        if key == "return" or key == "space" or key == "tab" then
            Arcade.init()
        end
        return
    end

    if key == "backspace" then
        if #Arcade.typedInput > 0 then
            Arcade.typedInput = Arcade.typedInput:sub(1, -2)
            Sound.playBackspace()
        end
        return
    end

    if key == "escape" then
        Arcade.init()
        return
    end
end

-- =========================================================================
-- DRAWING LOGIC
-- =========================================================================

function Arcade.draw(theme, winW, winH, fonts)
    local b = Arcade.board
    local mx, my = love.mouse.getPosition()

    -- 1. Draw Board Background (Water, Road, Grass)
    Arcade.drawBoardBackground(theme)

    -- 2. Draw Moving Platforms (Logs & Lilypads)
    Arcade.drawPlatforms(theme, fonts)

    -- 3. Draw Moving Cars
    Arcade.drawCars(theme)

    -- 4. Draw Goal Bays (Lane 9)
    Arcade.drawGoalBays(theme, fonts)

    -- 5. Draw Bonus Flies
    Arcade.drawBonusFlies(fonts)

    -- 6. Draw The Frog
    Arcade.drawFrog(theme)

    -- 7. Draw Target Words hovering over available paths
    Arcade.drawTargetWords(theme, fonts)

    -- 8. Draw Floating Popups & Particles
    Arcade.drawEffects(fonts)

    -- 9. Draw Arcade HUD (Score, Lives, Level, WPM, Active Input)
    Arcade.drawHUD(theme, winW, fonts)

    -- 10. Draw Game Over / Level Win overlays
    if Arcade.state == "game_over" then
        Arcade.drawGameOverOverlay(theme, winW, winH, fonts)
    elseif Arcade.state == "level_win" then
        Arcade.drawLevelWinOverlay(theme, winW, winH, fonts)
    end
end

function Arcade.drawBoardBackground(theme)
    local b = Arcade.board

    -- Board Outer Frame
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle("fill", b.x - 8, b.y - 8, b.w + 16, b.h + 16, 12, 12)

    -- Draw Lanes
    for i = 0, 9 do
        local lane = Arcade.lanes[i]
        if lane.type == "safe" then
            -- Grass bank
            love.graphics.setColor(0.14, 0.32, 0.20, 1.0)
            love.graphics.rectangle("fill", b.x, lane.y, b.w, lane.h)
            -- Grass blade accents
            love.graphics.setColor(0.19, 0.42, 0.26, 0.6)
            for gx = b.x + 10, b.x + b.w - 10, 35 do
                love.graphics.line(gx, lane.y + lane.h, gx + 4, lane.y + lane.h - 10)
                love.graphics.line(gx + 6, lane.y + lane.h, gx + 10, lane.y + lane.h - 14)
            end
        elseif lane.type == "road" then
            -- Asphalt
            love.graphics.setColor(0.18, 0.19, 0.22, 1.0)
            love.graphics.rectangle("fill", b.x, lane.y, b.w, lane.h)
            -- Dashed lane divider lines
            love.graphics.setColor(0.9, 0.85, 0.3, 0.4)
            love.graphics.setLineWidth(2)
            for lx = b.x + 10, b.x + b.w - 10, 40 do
                love.graphics.line(lx, lane.y + lane.h, lx + 20, lane.y + lane.h)
            end
        elseif lane.type == "river" then
            -- Flowing River
            love.graphics.setColor(0.10, 0.24, 0.42, 1.0)
            love.graphics.rectangle("fill", b.x, lane.y, b.w, lane.h)
            -- Animated river ripples
            love.graphics.setColor(0.16, 0.38, 0.58, 0.5)
            love.graphics.setLineWidth(1.5)
            local waveOffset = (Arcade.globalTime * 40 * (i % 2 == 0 and 1 or -1)) % 60
            for rx = b.x - 60 + waveOffset, b.x + b.w + 60, 60 do
                love.graphics.arc("line", "open", rx, lane.y + lane.h * 0.5, 14, 0.2, math.pi - 0.2)
            end
        elseif lane.type == "goals" then
            -- Top haven bank
            love.graphics.setColor(0.12, 0.28, 0.18, 1.0)
            love.graphics.rectangle("fill", b.x, lane.y, b.w, lane.h)
        end
    end
end

function Arcade.drawPlatforms(theme, fonts)
    for _, plat in ipairs(Arcade.platforms) do
        if plat.type == "log" then
            -- Wooden Log with rings
            love.graphics.setColor(0.48, 0.28, 0.14, 1.0)
            love.graphics.rectangle("fill", plat.x, plat.y, plat.w, plat.h, 12, 12)
            -- Bark stripes
            love.graphics.setColor(0.36, 0.20, 0.09, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.line(plat.x + 15, plat.y + 6, plat.x + plat.w - 15, plat.y + 6)
            love.graphics.line(plat.x + 20, plat.y + plat.h - 8, plat.x + plat.w - 20, plat.y + plat.h - 8)
            -- End caps
            love.graphics.setColor(0.62, 0.40, 0.22, 1.0)
            love.graphics.circle("fill", plat.x + 10, plat.y + plat.h / 2, 7)
            love.graphics.circle("fill", plat.x + plat.w - 10, plat.y + plat.h / 2, 7)
        elseif plat.type == "pad" then
            -- Giant Lilypad
            love.graphics.setColor(0.20, 0.55, 0.30, 1.0)
            love.graphics.ellipse("fill", plat.x + plat.w / 2, plat.y + plat.h / 2, plat.w / 2, plat.h / 2)
            -- V-notch
            love.graphics.setColor(0.10, 0.24, 0.42, 1.0)
            local cx = plat.x + plat.w / 2
            local cy = plat.y + plat.h / 2
            love.graphics.polygon("fill", cx, cy, cx + plat.w / 2, cy - 8, cx + plat.w / 2, cy + 8)
        elseif plat.type == "turtle" then
            -- Swimming Turtles trio
            local count = 3
            local subW = plat.w / count
            for t = 1, count do
                local tx = plat.x + (t - 0.5) * subW
                local ty = plat.y + plat.h / 2
                -- Turtle Shell
                love.graphics.setColor(0.18, 0.48, 0.28, 1.0)
                love.graphics.ellipse("fill", tx, ty, 13, 11)
                -- Flippers
                love.graphics.setColor(0.14, 0.38, 0.22, 0.9)
                love.graphics.ellipse("fill", tx - 10, ty - 8, 4, 2)
                love.graphics.ellipse("fill", tx + 10, ty - 8, 4, 2)
                love.graphics.ellipse("fill", tx - 10, ty + 8, 4, 2)
                love.graphics.ellipse("fill", tx + 10, ty + 8, 4, 2)
            end
        end
    end
end

function Arcade.drawCars(theme)
    for _, car in ipairs(Arcade.cars) do
        -- Shadow
        love.graphics.setColor(0.08, 0.08, 0.1, 0.4)
        love.graphics.rectangle("fill", car.x + 2, car.y + 4, car.w, car.h, 6, 6)

        -- Car Body
        love.graphics.setColor(car.color)
        love.graphics.rectangle("fill", car.x, car.y, car.w, car.h, 6, 6)

        -- Windshield & Roof
        love.graphics.setColor(0.12, 0.14, 0.18, 0.85)
        local roofInset = (car.model == "truck" or car.model == "bus") and 10 or 18
        love.graphics.rectangle("fill", car.x + roofInset, car.y + 4, car.w - roofInset * 2, car.h - 8, 4, 4)

        -- Headlights
        local headX = car.dir == 1 and (car.x + car.w - 3) or (car.x + 1)
        love.graphics.setColor(1.0, 0.95, 0.5, 0.9)
        love.graphics.circle("fill", headX, car.y + 5, 2.5)
        love.graphics.circle("fill", headX, car.y + car.h - 5, 2.5)

        -- Headlight beam
        love.graphics.setColor(1.0, 0.95, 0.5, 0.12)
        local beamDir = car.dir
        love.graphics.polygon("fill", headX, car.y + 5, headX + beamDir * 40, car.y - 10, headX + beamDir * 40, car.y + car.h + 10, headX, car.y + car.h - 5)
    end
end

function Arcade.drawGoalBays(theme, fonts)
    local b = Arcade.board
    local lane = Arcade.lanes[9]
    local goalSpacing = b.w / 5

    for g = 1, 5 do
        local gx = b.x + (g - 0.5) * goalSpacing
        local gy = lane.y + lane.h / 2

        -- Water inlet
        love.graphics.setColor(0.10, 0.24, 0.42, 1.0)
        love.graphics.rectangle("fill", gx - 32, lane.y + 6, 64, lane.h - 12, 8, 8)

        -- Big Lilypad in bay
        love.graphics.setColor(0.20, 0.55, 0.30, 0.9)
        love.graphics.ellipse("fill", gx, gy, 26, 18)

        -- If filled, draw happy rescued frog!
        if Arcade.goalsFilled[g] then
            Frog.drawMascot(gx, gy - 2, 0.75, Arcade.globalTime + g, false, theme)
            love.graphics.setFont(fonts.subtitle)
            love.graphics.setColor(theme.main)
            love.graphics.printf("SAVED", gx - 30, gy + 10, 60, "center")
        end
    end
end

function Arcade.drawBonusFlies(fonts)
    for _, fly in ipairs(Arcade.bonusFlies) do
        local bob = math.sin(Arcade.globalTime * 8) * 3
        -- Golden glowing aura
        love.graphics.setColor(1, 0.85, 0.2, 0.35)
        love.graphics.circle("fill", fly.x, fly.y + bob, 14)

        -- Firefly body
        love.graphics.setColor(1, 0.9, 0.2, 1)
        love.graphics.circle("fill", fly.x, fly.y + bob, 4)

        -- Wings
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.ellipse("fill", fly.x - 3, fly.y + bob - 4, 3, 2)
        love.graphics.ellipse("fill", fly.x + 3, fly.y + bob - 4, 3, 2)

        -- Prompt word
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(1, 0.9, 0.3, 1)
        love.graphics.printf("🪰 " .. fly.word, fly.x - 40, fly.y + bob - 22, 80, "center")
    end
end

function Arcade.drawFrog(theme)
    local f = Arcade.frog
    local jumpY = 0
    if f.isJumping then
        -- Parabolic hop arc
        local t = f.jumpProgress
        jumpY = -math.sin(t * math.pi) * 28
    end

    Frog.drawMascot(f.x, f.y + jumpY, 0.9, Arcade.globalTime, f.isJumping, theme)
end

function Arcade.drawTargetWords(theme, fonts)
    if Arcade.state ~= "playing" or Arcade.frog.isJumping then return end

    local nextLaneIdx = Arcade.frog.lane + 1
    if nextLaneIdx > 9 then return end
    local nextLaneInfo = Arcade.lanes[nextLaneIdx]

    love.graphics.setFont(fonts.uiBold)

    local function drawPillWord(word, wx, wy)
        local tw = fonts.uiBold:getWidth(word)
        local pw = tw + 18
        local ph = 24
        local px = wx - pw / 2
        local py = wy - ph / 2

        -- Check match with typedInput
        local isPrefix = (#Arcade.typedInput > 0 and word:sub(1, #Arcade.typedInput) == Arcade.typedInput)
        local isMismatch = (#Arcade.typedInput > 0 and not isPrefix)

        -- Pill background
        if isPrefix then
            love.graphics.setColor(theme.main[1], theme.main[2], theme.main[3], 0.95)
        else
            love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.88)
        end
        love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)

        -- Border
        love.graphics.setColor(theme.main[1], theme.main[2], theme.main[3], isPrefix and 1.0 or 0.4)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", px, py, pw, ph, 6, 6)

        -- Text rendering with character coloring
        local charX = px + 9
        for c = 1, #word do
            local ch = word:sub(c, c)
            local cw = fonts.uiBold:getWidth(ch)

            if c <= #Arcade.typedInput then
                local userCh = Arcade.typedInput:sub(c, c)
                if userCh == ch then
                    love.graphics.setColor(isPrefix and theme.bg or theme.main)
                else
                    love.graphics.setColor(theme.error)
                end
            else
                love.graphics.setColor(isPrefix and theme.bg or theme.text)
            end

            love.graphics.print(ch, charX, py + 4)
            charX = charX + cw
        end
    end

    if nextLaneInfo.type == "river" then
        -- Draw word over each platform in the next lane
        for _, plat in ipairs(Arcade.platforms) do
            if plat.lane == nextLaneIdx then
                drawPillWord(plat.word, plat.x + plat.w / 2, plat.y + plat.h / 2)
            end
        end
    elseif nextLaneInfo.type == "goals" then
        local b = Arcade.board
        local goalSpacing = b.w / 5
        local goalWords = {"lily", "haven", "home", "nest", "pond"}
        for g = 1, 5 do
            if not Arcade.goalsFilled[g] then
                local gx = b.x + (g - 0.5) * goalSpacing
                local gy = nextLaneInfo.y + nextLaneInfo.h / 2
                drawPillWord(goalWords[g] or "safe", gx, gy)
            end
        end
    else
        -- Road or safe bank
        local b = Arcade.board
        local f = Arcade.frog
        local curX = f.x
        local dirWords = {
            {-140, {"left", "west", "dash", "side"}},
            {0, {"up", "leap", "step", "move", "cross"}},
            {140, {"right", "east", "skip", "hop"}}
        }

        for _, set in ipairs(dirWords) do
            local dx = set[1]
            local targetX = math.max(b.x + 40, math.min(b.x + b.w - 40, curX + dx))
            local wordList = set[2]
            local w = wordList[(Arcade.frog.lane % #wordList) + 1]
            drawPillWord(w, targetX, nextLaneInfo.y + nextLaneInfo.h / 2)
        end
    end
end

function Arcade.drawEffects(fonts)
    -- Particles
    for _, p in ipairs(Arcade.particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    end

    -- Popups
    love.graphics.setFont(fonts.subtitle)
    for _, pop in ipairs(Arcade.popups) do
        local alpha = pop.life / pop.maxLife
        love.graphics.setColor(pop.color[1], pop.color[2], pop.color[3], alpha)
        love.graphics.printf(pop.text, pop.x - 100, pop.y, 200, "center")
    end
end

function Arcade.drawHUD(theme, winW, fonts)
    local b = Arcade.board
    local hudY = 46

    -- Left: Score & High Score
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(theme.sub)
    love.graphics.print("SCORE", b.x, hudY)
    love.graphics.setFont(fonts.statsMed)
    love.graphics.setColor(theme.main)
    love.graphics.print(string.format("%06d", Arcade.score), b.x + 65, hudY - 5)

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(theme.sub)
    love.graphics.print("HI-SCORE", b.x + 190, hudY)
    love.graphics.setFont(fonts.statsMed)
    love.graphics.setColor(theme.text)
    love.graphics.print(string.format("%06d", math.max(Arcade.score, Arcade.highScore)), b.x + 275, hudY - 5)

    -- Center: Level & Lives
    local cx = b.x + b.w / 2
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(theme.sub)
    love.graphics.print("LEVEL", cx - 70, hudY)
    love.graphics.setFont(fonts.statsMed)
    love.graphics.setColor(theme.main)
    love.graphics.print(tostring(Arcade.level), cx - 15, hudY - 5)

    -- Frog Lives icons
    local lifeX = cx + 45
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(theme.sub)
    love.graphics.print("LIVES", lifeX, hudY)
    for l = 1, Arcade.maxLives do
        local lx = lifeX + 50 + (l - 1) * 24
        if l <= Arcade.lives then
            Frog.drawMascot(lx, hudY + 8, 0.45, Arcade.globalTime, false, theme)
        else
            love.graphics.setColor(theme.sub[1], theme.sub[2], theme.sub[3], 0.3)
            love.graphics.circle("fill", lx, hudY + 8, 5)
        end
    end

    -- Right: Live WPM & Active Typed Input
    local rx = b.x + b.w - 220
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(theme.sub)
    love.graphics.print("WPM", rx, hudY)
    love.graphics.setFont(fonts.statsMed)
    love.graphics.setColor(theme.main)
    love.graphics.print(tostring(Arcade.getWpm()), rx + 45, hudY - 5)

    -- Input Buffer Pill (shows what user is currently typing)
    if #Arcade.typedInput > 0 then
        local inpText = Arcade.typedInput
        love.graphics.setFont(fonts.uiBold)
        local iw = fonts.uiBold:getWidth(inpText) + 24
        local ix = b.x + b.w - iw
        love.graphics.setColor(theme.panel)
        love.graphics.rectangle("fill", ix, hudY - 4, iw, 26, 6, 6)
        love.graphics.setColor(theme.main)
        love.graphics.print(inpText .. "_", ix + 12, hudY)
    end
end

function Arcade.drawGameOverOverlay(theme, winW, winH, fonts)
    -- Semi-transparent dark overlay
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, winW, winH)

    local cx = winW / 2
    local cy = winH / 2 - 40

    love.graphics.setFont(fonts.statsBig)
    love.graphics.setColor(theme.error)
    love.graphics.printf("GAME OVER", cx - 250, cy - 80, 500, "center")

    love.graphics.setFont(fonts.statsMed)
    love.graphics.setColor(theme.text)
    love.graphics.printf(string.format("FINAL SCORE: %d", Arcade.score), cx - 250, cy, 500, "center")

    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(theme.sub)
    love.graphics.printf(string.format("LEVEL REACHED: %d   •   AVG WPM: %d", Arcade.level, Arcade.getWpm()), cx - 250, cy + 45, 500, "center")

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(theme.main)
    love.graphics.printf("PRESS SPACE / TAB / ENTER TO PLAY AGAIN", cx - 250, cy + 105, 500, "center")
end

function Arcade.drawLevelWinOverlay(theme, winW, winH, fonts)
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, winW, winH)

    local cx = winW / 2
    local cy = winH / 2 - 40

    love.graphics.setFont(fonts.statsBig)
    love.graphics.setColor(theme.main)
    love.graphics.printf("LEVEL COMPLETE! 🐸🎉", cx - 300, cy - 60, 600, "center")

    love.graphics.setFont(fonts.statsMed)
    love.graphics.setColor(theme.text)
    love.graphics.printf(string.format("ALL 5 FROGS RESCUED! +2000 BONUS"), cx - 300, cy + 10, 600, "center")

    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(theme.sub)
    love.graphics.printf("PREPARING NEXT LEVEL...", cx - 300, cy + 60, 600, "center")
end

return Arcade
