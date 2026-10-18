local Sound = {}

Sound.enabled = true
Sound.sources = {
    key = {},
    space = {},
    backspace = {},
    finish = nil,
    jump = {},
    splash = nil,
    squish = nil,
    fly = nil,
    levelClear = nil
}

local function generateKeySound(freq, duration, decayRate, noiseMix)
    local sampleRate = 44100
    local sampleCount = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local env = math.exp(-decayRate * t)
        local wave = math.sin(2 * math.pi * freq * t)
        local noise = (math.random() * 2 - 1) * math.exp(-decayRate * 3 * t)
        local sample = (wave * (1 - noiseMix) + noise * noiseMix) * env * 0.4
        soundData:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(soundData, "static")
end

local function generateJumpSound()
    local sampleRate = 44100
    local duration = 0.15
    local sampleCount = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local env = math.sin(math.pi * (t / duration))
        local freq = 220 + 350 * (t / duration)
        local sample = math.sin(2 * math.pi * freq * t) * env * 0.35
        soundData:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(soundData, "static")
end

local function generateSplashSound()
    local sampleRate = 44100
    local duration = 0.35
    local sampleCount = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local env = math.exp(-12 * t)
        local noise = (math.random() * 2 - 1)
        local lowWave = math.sin(2 * math.pi * 140 * t)
        local sample = (noise * 0.7 + lowWave * 0.3) * env * 0.45
        soundData:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(soundData, "static")
end

local function generateSquishSound()
    local sampleRate = 44100
    local duration = 0.28
    local sampleCount = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local env = math.exp(-14 * t)
        local freq = math.max(60, 260 - 500 * t)
        local sample = (math.sin(2 * math.pi * freq * t) + (math.random() * 2 - 1) * 0.4) * env * 0.4
        soundData:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(soundData, "static")
end

local function generateFlySound()
    local sampleRate = 44100
    local duration = 0.22
    local sampleCount = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local env = math.exp(-15 * t)
        local sample = (math.sin(2 * math.pi * 987.77 * t) + math.sin(2 * math.pi * 1318.5 * t)) * 0.25 * env
        soundData:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(soundData, "static")
end

local function generateLevelClearSound()
    local sampleRate = 44100
    local duration = 0.7
    local sampleCount = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    -- C5, E5, G5, C6 arpeggio
    local notes = {523.25, 659.25, 783.99, 1046.50}
    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local noteIdx = math.min(4, math.floor(t / 0.12) + 1)
        local noteT = t - (noteIdx - 1) * 0.12
        local env = math.exp(-8 * noteT)
        local freq = notes[noteIdx]
        local sample = math.sin(2 * math.pi * freq * t) * 0.3 * env
        soundData:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(soundData, "static")
end

local function generateChimeSound()
    local sampleRate = 44100
    local duration = 0.5
    local sampleCount = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, 16, 1)

    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local env = math.exp(-6 * t)
        local s1 = math.sin(2 * math.pi * 523.25 * t)
        local s2 = math.sin(2 * math.pi * 659.25 * t)
        local s3 = math.sin(2 * math.pi * 783.99 * t)
        local sample = (s1 + s2 + s3) * 0.2 * env
        soundData:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(soundData, "static")
end

function Sound.init()
    if not love.sound or not love.audio then
        Sound.enabled = false
        return
    end

    for i = 1, 6 do
        table.insert(Sound.sources.key, generateKeySound(750, 0.045, 90, 0.35))
        table.insert(Sound.sources.space, generateKeySound(380, 0.065, 60, 0.45))
        table.insert(Sound.sources.backspace, generateKeySound(560, 0.04, 110, 0.3))
        table.insert(Sound.sources.jump, generateJumpSound())
    end
    Sound.sources.finish = generateChimeSound()
    Sound.sources.splash = generateSplashSound()
    Sound.sources.squish = generateSquishSound()
    Sound.sources.fly = generateFlySound()
    Sound.sources.levelClear = generateLevelClearSound()
end

local function playFromPool(pool, basePitch)
    if not Sound.enabled or #pool == 0 then return end
    for _, src in ipairs(pool) do
        if not src:isPlaying() then
            src:setPitch((basePitch or 1.0) + (math.random() * 0.12 - 0.06))
            src:setVolume(0.4)
            src:play()
            return
        end
    end
    local src = pool[1]
    src:stop()
    src:setPitch((basePitch or 1.0) + (math.random() * 0.12 - 0.06))
    src:setVolume(0.4)
    src:play()
end

function Sound.playKey()
    playFromPool(Sound.sources.key, 1.0)
end

function Sound.playSpace()
    playFromPool(Sound.sources.space, 0.9)
end

function Sound.playBackspace()
    playFromPool(Sound.sources.backspace, 1.1)
end

function Sound.playJump()
    playFromPool(Sound.sources.jump, 1.0)
end

function Sound.playSplash()
    if Sound.enabled and Sound.sources.splash then
        Sound.sources.splash:stop()
        Sound.sources.splash:setVolume(0.55)
        Sound.sources.splash:play()
    end
end

function Sound.playSquish()
    if Sound.enabled and Sound.sources.squish then
        Sound.sources.squish:stop()
        Sound.sources.squish:setVolume(0.6)
        Sound.sources.squish:play()
    end
end

function Sound.playFly()
    if Sound.enabled and Sound.sources.fly then
        Sound.sources.fly:stop()
        Sound.sources.fly:setVolume(0.5)
        Sound.sources.fly:play()
    end
end

function Sound.playLevelClear()
    if Sound.enabled and Sound.sources.levelClear then
        Sound.sources.levelClear:stop()
        Sound.sources.levelClear:setVolume(0.55)
        Sound.sources.levelClear:play()
    end
end

function Sound.playFinish()
    if Sound.enabled and Sound.sources.finish then
        Sound.sources.finish:stop()
        Sound.sources.finish:setVolume(0.5)
        Sound.sources.finish:play()
    end
end

function Sound.toggle()
    Sound.enabled = not Sound.enabled
    return Sound.enabled
end

return Sound
