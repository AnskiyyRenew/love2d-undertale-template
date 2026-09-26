local action = {
    sprite = nil,
    can_move = true,
    is_moving = false
}

-- Default vars.
local speed = 2
local enable_bigshot = true
local bigshot_cd = 60
local bigshot_timer = 0
local bs_begin = false
local bs_ready = false
local control_mode = 1
local fire_angle = 0
local hold_fire = 0
local cool_down = 5
local cd_timer = 5
local bullets = {}

-- Init: the contract lives in _temp.lua. Binding, tint and state reset belong
-- to the soul, so the engine never pokes these fields from outside.
---@param sprite table|nil The player sprite driven by this soul.
---@param can_move boolean|nil Mirrors Player.canMove; nil keeps the current value.
---@param args table|nil Extra arguments from Player.SetSoul / Player.NewSoul.
---@return table self This soul module.
function action.Init(sprite, can_move, args)
    action.sprite = sprite
    if (can_move ~= nil) then
        action.can_move = (can_move ~= false)
    end
    if (sprite) then
        sprite.color = {1, 1, 0}
        sprite.rotation = fire_angle + 180
    end
    control_mode = 1

    return action
end

function action.Bullet(spr, layer)
    local bul = Sprites.CreateSprite(spr, layer)
    bul.isBullet = true

    bul.HitCall = function (self) end

    bul.Destroy = function (self)
        self:UnSolid()
        Layers.remove(self)
        for i = #Sprites.images, 1, -1 do
            if (Sprites.images[i] == self) then
                table.remove(Sprites.images, i)
                break
            end
        end
        LuaEX.rmVarTable(bullets, self)
    end

    table.insert(bullets, bul)
    return bul
end

---Controls the player's movement and behaviour.
---@param dt number|nil
function action.Update(dt)
    if (not action.sprite) then return end

    local can_move = action.can_move
    local sprite = action.sprite
    local up, down, left, right = Controller.GetState("up"), Controller.GetState("down"), Controller.GetState("left"), Controller.GetState("right")
    local cancel = Controller.GetState("cancel")
    local fire = Controller.GetState("confirm")

    if (cancel > 0) then
        speed = 1
    else
        speed = 2
    end

    if (not can_move) then return end
    if (sprite) then
        if (Global.GetVariable("UseRealTime(dt)")) then
            -- Put your dt logic here.
            if (up > 0) then sprite.y = sprite.y - speed * 60 * dt end
            if (down > 0) then sprite.y = sprite.y + speed * 60 * dt end
            if (left > 0) then sprite.x = sprite.x - speed * 60 * dt end
            if (right > 0) then sprite.x = sprite.x + speed * 60 * dt end
        else
            -- Put your frames logic here.
            cd_timer = cd_timer - 1
            if (up > 0) then sprite.y = sprite.y - speed end
            if (down > 0) then sprite.y = sprite.y + speed end
            if (left > 0) then sprite.x = sprite.x - speed end
            if (right > 0) then sprite.x = sprite.x + speed end

            -- Fire.
            if (fire == 1 and cd_timer <= 0) then
                Audio.PlaySound("snd_shoot.wav")
                cd_timer = cool_down
                local bullet = Sprites.CreateSprite("Soul Library Sprites/spr_heartbullet_1.png", sprite.layer - 0.1)
                bullet:MoveTo(sprite:GetPosition())
                bullet.ypivot = 1
                bullet.rotation = sprite.rotation - 180
                bullet.color = {1, 1, 0}
                bullet.velocity = {
                    x = 8 * math.sin(math.rad(bullet.rotation)),
                    y = 8 * -math.cos(math.rad(bullet.rotation)),
                    r = 0
                }
                bullet.Step = function (self)
                    self.velocity.y = self.velocity.y - 0.05
                    self.yscale = self.yscale + 0.05
                    if (self.x < -20 or self.x > 660 or self.y < -20 or self.y > 500) then
                        self:Destroy()
                    else
                        for i = #bullets, 1, -1
                        do
                            local b = bullets[i]
                            local coll1 = Collisions.FollowShape(self)
                            local coll2 = Collisions.FollowShape(b)

                            if (Collisions.RectangleWithRectangle(coll1, coll2)) then
                                self:Destroy()
                                b:HitCall()
                            end
                        end
                    end
                end
            end

            if (enable_bigshot) then
                if (Controller.GetState("confirm") > 1) then
                    bigshot_timer = bigshot_timer + 1
                    -- Part
                    if (bigshot_timer >= bigshot_cd / 3 and not bs_begin) then
                        bs_begin = true

                        for i = 1, 4
                        do
                            local part = Sprites.CreateSprite("Shapes/circle.png", sprite.layer - 0.01)
                            part.color = {1, 1, 0}
                            part.alpha = 0
                            part._offset = i * 90
                            part._radius = 30
                            part:MoveTo(
                                sprite.x + part._radius * math.cos(math.rad(part._offset)),
                                sprite.y + part._radius * math.sin(math.rad(part._offset))
                            )
                            part:Scale(0.1, 0.1)
                            part.Step = function (self)
                                self.alpha = self.alpha + 0.02
                                self._offset = self._offset + 3
                                self._radius = math.max(0, self._radius - 1)
                                self:MoveTo(
                                    sprite.x + self._radius * math.cos(math.rad(self._offset)),
                                    sprite.y + self._radius * math.sin(math.rad(self._offset))
                                )
                                if (Controller.GetState("confirm") == -1) then
                                    self:Destroy()
                                end
                            end
                        end
                    end

                    if (bigshot_timer >= bigshot_cd and not bs_ready) then
                        bs_ready = true

                        -- Shadow
                        local heart = Sprites.CreateSprite(sprite.path, sprite.layer - 0.01)
                        heart.rotation = sprite.rotation
                        heart.color = {1, 1, 0}
                        heart.alpha = 0.5
                        heart:Scale(1.4, 1.4)
                        heart:MoveTo(sprite:GetPosition())
                        heart.Step = function (self)
                            if (Controller.GetState("confirm") == -1) then
                                self:Destroy()
                            end
                        end
                    end
                end
                if (Controller.GetState("confirm") == -1 and bs_ready) then
                    bigshot_timer = 0
                    bs_begin = false
                    bs_ready = false
                end
            end
        end
    end
end

return action