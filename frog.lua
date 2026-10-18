local Frog = {}

function Frog.drawMascot(x, y, scale, time, isHopping, theme)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)

    local bob = math.sin(time * 3) * 2
    local hopY = 0
    if isHopping then
        hopY = -math.abs(math.sin(time * 12)) * 14
    end

    local frogCol = theme.frog or theme.main
    local darkFrogCol = {frogCol[1] * 0.75, frogCol[2] * 0.75, frogCol[3] * 0.75, frogCol[4] or 1}
    local bellyCol = {math.min(1, frogCol[1] * 1.3), math.min(1, frogCol[2] * 1.3), math.min(1, frogCol[3] * 1.2), 1}

    -- Lilypad underneath
    love.graphics.setColor(0.12, 0.35, 0.2, 0.7)
    love.graphics.ellipse("fill", 0, 16, 26, 8)
    love.graphics.setColor(theme.bg)
    -- Slice in lilypad
    love.graphics.polygon("fill", 0, 16, 26, 12, 26, 20)

    -- Frog body
    love.graphics.push()
    love.graphics.translate(0, bob + hopY)

    -- Back feet
    love.graphics.setColor(darkFrogCol)
    love.graphics.ellipse("fill", -14, 12, 6, 3)
    love.graphics.ellipse("fill", 14, 12, 6, 3)

    -- Main body
    love.graphics.setColor(frogCol)
    love.graphics.ellipse("fill", 0, 4, 16, 13)

    -- Belly
    love.graphics.setColor(bellyCol)
    love.graphics.ellipse("fill", 0, 6, 10, 8)

    -- Eye sockets
    love.graphics.setColor(frogCol)
    love.graphics.circle("fill", -8, -6, 6)
    love.graphics.circle("fill", 8, -6, 6)

    -- Eye whites
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", -8, -6, 4)
    love.graphics.circle("fill", 8, -6, 4)

    -- Pupils (look toward center/user)
    love.graphics.setColor(0.08, 0.1, 0.08, 1)
    love.graphics.circle("fill", -7, -6, 2)
    love.graphics.circle("fill", 7, -6, 2)

    -- Eye sparkles
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", -8, -7, 1)
    love.graphics.circle("fill", 6, -7, 1)

    -- Smile
    love.graphics.setColor(darkFrogCol)
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", "open", 0, 2, 5, 0.2, math.pi - 0.2)

    -- Cheeks (rosy blush)
    love.graphics.setColor(1, 0.45, 0.55, 0.45)
    love.graphics.circle("fill", -11, 3, 2.5)
    love.graphics.circle("fill", 11, 3, 2.5)

    -- Front little arms
    love.graphics.setColor(darkFrogCol)
    love.graphics.ellipse("fill", -6, 12, 3, 2)
    love.graphics.ellipse("fill", 6, 12, 3, 2)

    love.graphics.pop()
    love.graphics.pop()
end

return Frog

