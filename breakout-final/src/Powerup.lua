Powerup = Class{}

function Powerup:init(x, y, type)
    self.x = x
    self.y = y

    self.width = 16
    self.height = 16

    -- two balls is 1
    -- key is 4
    self.type = type
end

function Powerup:collides(target)
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

function Powerup:update(dt)
    self.y = self.y + POWERUP_SPEED * dt
end

function Powerup:render()
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type],
        self.x, self.y)
end