-- UpgradeScreen: 3-card upgrade selection modal
local C = require("consts")

local UpgradeScreen = {}
UpgradeScreen.__index = UpgradeScreen

function UpgradeScreen.new(gameLoop)
    local self = setmetatable({}, UpgradeScreen)
    self.gameLoop = gameLoop
    self.group = display.newGroup()
    self.group.isVisible = false

    -- Dimmed background
    self.overlay = display.newRect(self.group, C.CENTER_X, C.CENTER_Y, C.WIDTH, C.HEIGHT)
    self.overlay:setFillColor(unpack(C.COLOR.OVERLAY))
    self.overlay:addEventListener("tap", function() end)
    self.overlay.isHitTestable = true

    -- Title
    self.titleText = display.newText({
        parent = self.group,
        text = "WAVE COMPLETE",
        x = C.CENTER_X,
        y = 180,
        font = native.systemFontBold,
        fontSize = 32,
        align = "center",
    })
    self.titleText:setFillColor(1, 1, 1)

    -- Subtitle
    self.subText = display.newText({
        parent = self.group,
        text = "Choose your upgrade",
        x = C.CENTER_X,
        y = 225,
        font = native.systemFont,
        fontSize = 20,
        align = "center",
    })
    self.subText:setFillColor(0.7, 0.7, 0.7)

    -- Upgrade cards
    self.cards = {}
    self.cardWidth = 280
    self.cardHeight = 360
    self.cardSpacing = 20

    local cardCount = 3
    local totalWidth = cardCount * self.cardWidth + (cardCount - 1) * self.cardSpacing
    local startX = C.CENTER_X - totalWidth / 2 + self.cardWidth / 2

    for i = 1, cardCount do
        local card = self:createCard(startX + (i - 1) * (self.cardWidth + self.cardSpacing), C.CENTER_Y + 50, i)
        table.insert(self.cards, card)
    end

    return self
end

function UpgradeScreen:createCard(x, y, index)
    local card = {}

    local function makeGroup()
        local g = display.newGroup()
        g.x = x
        g.y = y
        self.group:insert(g)
        return g
    end

    card.group = makeGroup()

    -- Card background
    card.bg = display.newRoundedRect(card.group, 0, 0, self.cardWidth, self.cardHeight, 16)
    card.bg:setFillColor(0.15, 0.15, 0.22)
    card.bg:setStrokeColor(0.3, 0.3, 0.45)
    card.bg.strokeWidth = 2

    -- Icon placeholder (shape based on category)
    card.iconBg = display.newCircle(card.group, 0, -110, 40)
    card.iconBg:setFillColor(unpack(C.COLOR.ACCENT))
    card.iconBg.alpha = 0.3
    card.icon = display.newCircle(card.group, 0, -110, 30)
    card.icon:setFillColor(unpack(C.COLOR.ACCENT))

    -- Name text
    card.nameText = display.newText({
        parent = card.group,
        text = "???",
        x = 0,
        y = -30,
        font = native.systemFontBold,
        fontSize = 20,
        align = "center",
        width = self.cardWidth - 20,
    })
    card.nameText:setFillColor(1, 1, 1)

    -- Desc text
    card.descText = display.newText({
        parent = card.group,
        text = "???",
        x = 0,
        y = 10,
        font = native.systemFont,
        fontSize = 16,
        align = "center",
        width = self.cardWidth - 20,
    })
    card.descText:setFillColor(0.7, 0.7, 0.7)

    -- Tap area
    card.tapArea = display.newRect(card.group, 0, 0, self.cardWidth, self.cardHeight)
    card.tapArea:setFillColor(0, 0, 0, 0.01)
    card.tapArea.isHitTestable = true

    card.index = index
    card.data = nil
    card.upgradeId = nil

    return card
end

function UpgradeScreen:show(choices)
    self.group.isVisible = true

    for i, card in ipairs(self.cards) do
        local data = choices[i]
        if data then
            card.data = data
            card.upgradeId = data.id
            card.nameText.text = data.name
            card.descText.text = data.desc

            -- Color by category
            local color
            if data.temp then
                if data.category == "damage" then color = { 1, 0.3, 0.3 }
                elseif data.category == "fire_rate" then color = { 1, 0.6, 0.1 }
                elseif data.category == "range" then color = { 0.3, 0.8, 1 }
                elseif data.category == "gold" then color = C.COLOR.GOLD
                elseif data.category == "defense" then color = C.COLOR.HP_BAR
                elseif data.category == "utility" then color = { 0.5, 0.5, 1 }
                else color = C.COLOR.ACCENT end
            else
                color = { 0.8, 0.6, 1 }  -- purple tint for permanent
            end

            card.iconBg:setFillColor(unpack(color))
            card.iconBg.alpha = 0.4
            card.icon:setFillColor(unpack(color))

            -- Update tap listener
            card.tapArea:removeEventListener("tap", card._tapHandler)
            card._tapHandler = function()
                self.gameLoop:onUpgradeSelected(card.upgradeId)
            end
            card.tapArea:addEventListener("tap", card._tapHandler)

            card.bg:setStrokeColor(unpack(color))
            card.bg.alpha = 1
        else
            card.bg.alpha = 0
            card.tapArea.isHitTestable = false
        end
    end
end

function UpgradeScreen:hide()
    self.group.isVisible = false
end

function UpgradeScreen:destroy()
    self.group:removeSelf()
end

return UpgradeScreen