local Enemy = {}
Enemy.__index = Enemy

Enemy.new = function(enemyData)
    local self = setmetatable({}, Enemy)
    self.name = enemyData.name
    self.defensetext = enemyData.defensetext
    self.misstext = enemyData.misstext
    self.exp = enemyData.exp
    self.gold = enemyData.gold
    self.maxhp = enemyData.maxhp
    self.hp = enemyData.hp
    self.maxdamage = enemyData.maxdamage
    self.killable = enemyData.killable
    self.canspare = enemyData.canspare
    self.dead = enemyData.dead
    self.actions = enemyData.actions
    self.acttexts = enemyData.acttexts or {}
    self.position = enemyData.position
    self.showhpbar = enemyData.showhpbar ~= false
    return self
end

return Enemy
