--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = {}
    table.insert(self.balls, params.ball)
    self.level = params.level

    self.recoverPoints = params.recoverPoints or 5000

    -- give ball random starting velocity
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)

    self.powerupSpawned = false -- true if a powerup has spawned
    self.brickHits = 0 -- number of times the ball has hit a brick

    if PlayState:getLockedBrick(self.bricks) then
        self.lockedBrick = self.bricks[PlayState:getLockedBrick(self.bricks)]
    end
    self.keyGrabbed = false
    self.keyTimer = 0
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    self.paddle:update(dt)

    for k, ball in pairs(self.balls) do
        ball:update(dt)
    end

    if self.powerup then
        self.powerup:update(dt)
    end

    if self.key then
        self.key:update(dt)
    end

    if self.lockedBrick then -- the timer isn't used if there is no locked brick
        self.keyTimer = self.keyTimer + dt
    end

    -- check if any ball hits the paddle
    for k, ball in pairs(self.balls) do
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    end

    -- detect collision across all bricks with the balls
    for k, brick in pairs(self.bricks) do
        for j, ball in pairs(self.balls) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                if not brick.isLocked then
                    -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()

                    -- a powerup appears after 10 hits (only once)
                    if not self.powerupSpawned then
                        self.brickHits = self.brickHits + 1
                        if self.brickHits >= 10 then
                            self.powerupSpawned = true
                            self.powerup = Powerup(brick.x + brick.width / 2 - 8, brick.y + brick.height, 1)
                        end
                    end

                    -- if we have enough points, recover a point of health and increase size
                    if self.score > self.recoverPoints then
                        -- can't go above 3 health
                        self.health = math.min(3, self.health + 1)

                        self.paddle.size = math.min(4, self.paddle.size + 1)
                        self.paddle.width = 32 * self.paddle.size

                        -- multiply recover points by 2
                        self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                        -- play recover sound effect
                        gSounds['recover']:play()
                    end

                    -- go to our victory screen if there are no more bricks left
                    if self:checkVictory() then
                        gSounds['victory']:play()

                        gStateMachine:change('victory', {
                            level = self.level,
                            paddle = self.paddle,
                            health = self.health,
                            score = self.score,
                            highScores = self.highScores,
                            ball = self.balls[1],
                            recoverPoints = self.recoverPoints
                        })
                    end
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if a ball goes below bounds, it has to be removed
    -- but if there's still at least one ball, the player doesn't loose a life
    for k, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            ball.remove = true
            gSounds['hurt']:play()
        end
    end

    -- remove a ball if necessary and check if it's game over
    for k, ball in pairs(self.balls) do
        if ball.remove then
            table.remove(self.balls, k)

            if #self.balls == 0 then -- there's no balls left
                self.health = self.health - 1
                gSounds['hurt']:play()

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    self.paddle.size = math.max(1, self.paddle.size - 1)
                    self.paddle.width = 32 * self.paddle.size
                    
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            end
        end
    end

    -- check if player grabs the powerup
    if self.powerup and self.powerup:collides(self.paddle) then
        gSounds['powerup']:play()

        for i = 0, 1 do
            local b = Ball(self.balls[1].skin)
            b.x = self.paddle.x + self.paddle.width / 2 - b.width / 2
            b.y = self.paddle.y - b.height
            b.dx = -self.balls[i + 1].dx
            b.dy = -math.abs(self.balls[1].dy)
            table.insert(self.balls, b)
        end

        self.powerup = nil
    end

    -- check if powerup goes below bounds
    if self.powerup and self.powerup.y >= VIRTUAL_HEIGHT then
        self.powerup = nil
    end

    -- spawn a key every 20 seconds
    if not self.key and not self.keyGrabbed and self.keyTimer >= 20 then
        self.key = Powerup(self.lockedBrick.x + self.lockedBrick.width / 2 - 8, 
        self.lockedBrick.y + self.lockedBrick.height, 4)
    end

    -- check if player grabs the key 
    if self.key and self.key:collides(self.paddle) then
        -- change the status of the locked brick
        self.lockedBrick.isLocked = false

        self.keyGrabbed = true
        self.key = nil
    end

    -- check if key goes below bounds; the key should reappear
    if self.key and self.key.y >= VIRTUAL_HEIGHT then
        self.keyTimer = 0
        self.key = nil
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for k, ball in pairs(self.balls) do
        ball:render()
    end

    if self.powerup then
        self.powerup:render()
    end

    if self.key then
        self.key:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

-- used to get the locked brick if there is one
function PlayState:getLockedBrick(bricks)
    for k, brick in pairs(bricks) do
        if brick.isLocked then
            return k
        end
    end

    return nil
end