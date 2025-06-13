local gameStarted = false
local score = 0
local scoreTimer = 0
local highscore = 0

local flashlightEnabled = false
local flashlightFlickerTimer = 0
local flashlightFlickerCount = 3
local flashlightFlickerMax = 6

local rgb1, rgb2, rgb3 = 1, 1, 1

local rgb1 = math.random(1, 255) / 255
local rgb2 = math.random(1, 255) / 255
local rgb3 = math.random(1, 255) / 255

local roadImage
local roadbgImage
local roadScrollY = 0
local roadScrollSpeed = 200

local barrierWidth = 70

local enemyCars = {}
local enemySpawnTimer = 0
local enemySpawnInterval = 0.5

local enemyCarWidth = 30
local enemyCarHeight = 60
local baseEnemyCarSpeed = 250

local moonshine = require("libraries.moonshine")

local menuTimer = 0

local enemyImage

-- Skin system variables
local skins = {}
local currentSkin = nil
local skinSelectionMode = false
local skinButtons = {}
local skinButtonSize = 100
local skinButtonPadding = 15
local skinVerticalPadding = 50  -- Increased vertical padding
local skinScrollY = 0
local maxSkinScroll = 0

-- Touch control variables
local touchId = nil
local touchStartX = nil

-- Skin unlocking system
local unlockedSkins = {}
local lastUnlockScore = 0
local unlockNotification = ""
local unlockNotificationTimer = 0
local unlockNotificationDuration = 3  -- seconds

-- Camera movement variables
local cameraOffsetX = 0
local cameraOffsetY = 0
local cameraShakeTimer = 0
local cameraShakeIntensity = 0

-- Music variables
local bgMusic = nil
local musicVolume = 0.5

local shadow = love.graphics.newImage("resources/Sprites/shadow.png")

function love.load()
    love.window.setMode(405, 720, {resizable = false})

    -- Initialize audio
    love.audio.setVolume(musicVolume)
    bgMusic = love.audio.newSource("resources/music/bgmain.wav", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()

    effect = moonshine(moonshine.effects.filmgrain)
        .chain(moonshine.effects.vignette)
        .chain(moonshine.effects.scanlines)
        .chain(moonshine.effects.chromasep)

    effect.vignette.opacity = 0.55
    effect.filmgrain.size = 3
    effect.scanlines.opacity = 0.2

    titleFont = love.graphics.newFont("resources/Fonts/Jersey10.ttf", 64)
    scoreFont = love.graphics.newFont("resources/Fonts/Jersey10.ttf", 48)
    promptFont = love.graphics.newFont("resources/Fonts/Jersey10.ttf", 28)
    hsFont = love.graphics.newFont("resources/Fonts/Jersey10.ttf", 24)
    skinFont = love.graphics.newFont("resources/Fonts/Jersey10.ttf", 18)
    buttonFont = love.graphics.newFont("resources/Fonts/Jersey10.ttf", 30)
    notificationFont = love.graphics.newFont("resources/Fonts/Jersey10.ttf", 24)  -- Now using Jersey10 for notifications
    lockFont = love.graphics.newFont(30)  -- Default font for lock emoji

    roadImage = love.graphics.newImage("resources/Sprites/road.png")
    roadbgImage = love.graphics.newImage("resources/Sprites/roadbg.png")
    enemyImage = love.graphics.newImage("resources/Sprites/enemy.png")

    car = {
        x = 405 / 2,
        y = 600,
        width = 30,
        height = 60,
        speed = 400,
        angle = 0,
        maxTilt = math.rad(15)
    }

    targetX = car.x

    if love.filesystem.getInfo("highscore.txt") then
        local contents = love.filesystem.read("highscore.txt")
        highscore = tonumber(contents) or 0
    end
    
    -- Load skins and set default
    loadSkins()
    setDefaultSkin()
end

function loadSkins()
    skins = {}
    
    -- Load unlocked skins from save file
    if love.filesystem.getInfo("unlocked_skins.txt") then
        local contents = love.filesystem.read("unlocked_skins.txt")
        unlockedSkins = {}
        for skinName in contents:gmatch("[^\n]+") do
            unlockedSkins[skinName] = true
        end
    end
    
    -- Load skins from directory
    if love.filesystem.getInfo("resources/Skins") then
        local files = love.filesystem.getDirectoryItems("resources/Skins")
        for _, file in ipairs(files) do
            if file:match("%.png$") then
                local skinName = file:gsub("%.png$", "")
                local isDefault = skinName == "Gray Double Window"
                table.insert(skins, {
                    name = skinName,
                    image = love.graphics.newImage("resources/Skins/"..file),
                    unlocked = isDefault or (unlockedSkins[skinName] or false)
                })
            end
        end
    end
    
    -- Create skin buttons with proper spacing (only for unlocked skins)
    createSkinButtons()
end

function saveUnlockedSkins()
    local skinNames = {}
    for _, skin in ipairs(skins) do
        if skin.unlocked then
            table.insert(skinNames, skin.name)
        end
    end
    love.filesystem.write("unlocked_skins.txt", table.concat(skinNames, "\n"))
end

function unlockRandomSkin()
    local lockedSkins = {}
    for _, skin in ipairs(skins) do
        if not skin.unlocked then
            table.insert(lockedSkins, skin)
        end
    end
    
    if #lockedSkins > 0 then
        local randomSkin = lockedSkins[math.random(1, #lockedSkins)]
        randomSkin.unlocked = true
        unlockedSkins[randomSkin.name] = true
        saveUnlockedSkins()
        
        -- Recreate buttons to reflect changes
        createSkinButtons()
        
        return randomSkin
    end
    return nil
end

function setDefaultSkin()
    -- First try to find Gray Double Window
    for _, skin in ipairs(skins) do
        if skin.name == "Gray Double Window" and skin.unlocked then
            currentSkin = skin
            return
        end
    end
    
    -- Fallback to first available unlocked skin
    for _, skin in ipairs(skins) do
        if skin.unlocked then
            currentSkin = skin
            return
        end
    end
    
    -- No unlocked skins found, create default
    currentSkin = {
        name = "Default",
        image = nil,
        unlocked = true
    }
end

function createSkinButtons()
    skinButtons = {}
    local startX = (405 - (skinButtonSize * 3 + skinButtonPadding * 2)) / 2
    local startY = 150
    
    -- Only create buttons for unlocked skins
    for i, skin in ipairs(skins) do
        if skin.unlocked then
            local row = math.floor((#skinButtons) / 3)
            local col = (#skinButtons) % 3
            
            -- Calculate text space needed
            local lines = 1
            if #skin.name > 12 then lines = 2 end
            
            table.insert(skinButtons, {
                x = startX + col * (skinButtonSize + skinButtonPadding),
                y = startY + row * (skinButtonSize + skinVerticalPadding),
                width = skinButtonSize,
                height = skinButtonSize,
                skin = skin,
                textY = startY + row * (skinButtonSize + skinVerticalPadding) + skinButtonSize + 5,
                lines = lines
            })
        end
    end
    
    -- Calculate max scroll
    local totalRows = math.ceil(#skinButtons / 3)
    maxSkinScroll = math.max(0, (totalRows * (skinButtonSize + skinVerticalPadding)) - (720 - startY - 150))
end

function checkCollision(a, b)
    return a.x - a.width/2 < b.x + b.width/2 and
           a.x + a.width/2 > b.x - b.width/2 and
           a.y - a.height/2 < b.y + b.height/2 and
           a.y + a.height/2 > b.y - b.height/2
end

function love.update(dt)
    -- Update camera shake
    if cameraShakeTimer > 0 then
        cameraShakeTimer = cameraShakeTimer - dt
        cameraOffsetX = (math.random() - 0.5) * cameraShakeIntensity * cameraShakeTimer
        cameraOffsetY = (math.random() - 0.5) * cameraShakeIntensity * cameraShakeTimer
    else
        cameraOffsetX = 0
        cameraOffsetY = 0
    end

    if skinSelectionMode then return end

    if not gameStarted then
        menuTimer = menuTimer + dt
        return
    end

    -- Update unlock notification timer
    if unlockNotificationTimer > 0 then
        unlockNotificationTimer = unlockNotificationTimer - dt
        if unlockNotificationTimer <= 0 then
            unlockNotification = ""
        end
    end

    -- Check for score milestones (every 25 points)
    if score >= lastUnlockScore + 25 then
        lastUnlockScore = math.floor(score / 25) * 25
        local unlockedSkin = unlockRandomSkin()
        if unlockedSkin then
            unlockNotification = unlockedSkin.name .. " Skin Unlocked!"
            unlockNotificationTimer = unlockNotificationDuration
            -- Add camera shake when unlocking a skin
            cameraShakeTimer = 0.5
            cameraShakeIntensity = 5
        end
    end

    local time = love.timer.getTime()
    rgb1 = 0.5 + 0.5 * math.sin(time * 0.5) 
    rgb2 = 0.5 + 0.5 * math.sin(time * 1.0) 
    rgb3 = 0.5 + 0.5 * math.sin(time * 1.5)

    -- Road scrolling
    roadScrollY = (roadScrollY - roadScrollSpeed * dt) % roadImage:getHeight()

    -- Movement controls
    if touchId or love.mouse.isDown(1) then
        targetX = touchId and love.touch.getPosition(touchId) or love.mouse.getX()
    end

    -- Car movement
    local dx = targetX - car.x
    car.x = car.x + dx * dt * 6
    car.angle = math.max(-car.maxTilt, math.min(dx * 0.005, car.maxTilt))
    car.x = math.max(barrierWidth + car.width/2, math.min(405 - barrierWidth - car.width/2, car.x))

    -- Enemy spawning
    local difficultyFactor = math.min(score / 50, 1)
    enemySpawnInterval = 1.5 - difficultyFactor * 1.1
    local enemySpeed = baseEnemyCarSpeed + difficultyFactor * 300
    local enemiesPerSpawn = 1 + math.floor(difficultyFactor * 2)

    enemySpawnTimer = enemySpawnTimer + dt
    while enemySpawnTimer >= enemySpawnInterval do
        enemySpawnTimer = enemySpawnTimer - enemySpawnInterval
        for i = 1, enemiesPerSpawn do
            table.insert(enemyCars, {
                x = math.random(barrierWidth + enemyCarWidth/2, 405 - barrierWidth - enemyCarWidth/2),
                y = -enemyCarHeight / 2,
                width = enemyCarWidth,
                height = enemyCarHeight,
                speed = enemySpeed,
                color = {love.math.random(), love.math.random(), love.math.random()}
            })
        end
    end

    -- Update enemies
    for i = #enemyCars, 1, -1 do
        local enemy = enemyCars[i]
        if enemy then
            enemy.y = enemy.y + enemy.speed * dt
        end
        if enemy then
            if enemy.y - enemy.height/2 > 720 then
                table.remove(enemyCars, i)
            elseif checkCollision(car, enemy) then
                gameStarted = false
                enemyCars = {}
                -- Add camera shake on collision
                cameraShakeTimer = 1.0
                cameraShakeIntensity = 10
            end
        end
    end

    -- Score handling
    scoreTimer = scoreTimer + dt
    if scoreTimer >= 1 then
        score = score + 1
        scoreTimer = scoreTimer - 1
        if score > highscore then
            highscore = score
            love.filesystem.write("highscore.txt", tostring(highscore))
        end
    end

    -- Flashlight effect
    if not flashlightEnabled and flashlightFlickerTimer >= 0.2 then
        flashlightFlickerTimer = 0
        flashlightFlickerCount = flashlightFlickerCount + 1
        flashlightEnabled = flashlightFlickerCount % 2 == 1
        if flashlightFlickerCount >= flashlightFlickerMax then
            flashlightEnabled = true
        end
    end
    flashlightFlickerTimer = flashlightFlickerTimer + dt
end

function love.draw()
    effect(function()
        love.graphics.clear(0.1, 0.1, 0.1)

        if skinSelectionMode then
            drawSkinSelection()
            return
        end

        -- Apply camera offset
        love.graphics.push()
        love.graphics.translate(cameraOffsetX, cameraOffsetY)

        -- Draw background
        love.graphics.setColor(1,1,1)
        love.graphics.draw(roadbgImage, 0, 0, 0, 405/roadbgImage:getWidth(), 720/roadbgImage:getHeight())
        local roadX = (405 - roadImage:getWidth()) / 2
        love.graphics.draw(roadImage, roadX, -roadScrollY)
        love.graphics.draw(roadImage, roadX, -roadScrollY + roadImage:getHeight())

        -- Draw enemies
        for _, enemy in ipairs(enemyCars) do
            love.graphics.setColor(enemy.color)
            love.graphics.draw(enemyImage,
                enemy.x - enemy.width/2,
                enemy.y - enemy.height/2,
                0,
                enemy.width/enemyImage:getWidth(),
                enemy.height/enemyImage:getHeight())
        end

        -- Draw player car
        love.graphics.push()
        love.graphics.translate(car.x, car.y)
        love.graphics.rotate(car.angle)
        if currentSkin.image then
            if currentSkin and currentSkin.name == "RGB Gamer" then
                love.graphics.setColor(rgb1, rgb2, rgb3)
                love.graphics.draw(currentSkin.image, 
                    -car.width/2, -car.height/2,
                    0,
                    car.width/currentSkin.image:getWidth(),
                    car.height/currentSkin.image:getHeight())
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(currentSkin.image, 
                    -car.width/2, -car.height/2,
                    0,
                    car.width/currentSkin.image:getWidth(),
                    car.height/currentSkin.image:getHeight())
            end
        else
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", -car.width/2, -car.height/2, car.width, car.height)
        end
        love.graphics.pop()

        -- Draw UI
        if not gameStarted then
            drawMainMenu()
        else
            drawGameUI()
        end
        
        love.graphics.pop() -- Pop camera offset
    end)

    love.graphics.setFont(scoreFont)
    love.graphics.setColor(1, 1, 1)
    local scoreText = tostring(score)
    love.graphics.print(scoreText, (405 - scoreFont:getWidth(scoreText))/2, 20)
end

function drawMainMenu()
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1)
    local title = "Midnight Rush"
    local titleWidth = titleFont:getWidth(title)
    local titleY = 100 + math.sin(menuTimer * 1.2) * 8
    love.graphics.print(title, (405 - titleWidth)/2, titleY)

    love.graphics.setFont(promptFont)
    local prompt = "Touch to start"
    local promptWidth = promptFont:getWidth(prompt)
    local promptY = 550 + math.sin(menuTimer * 3) * 5
    love.graphics.print(prompt, (405 - promptWidth)/2, promptY)

    -- Skins button
    love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
    love.graphics.rectangle("fill", 20, 650, 100, 50, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Skins", 35, 655)

    love.graphics.setFont(hsFont)
    local hsText = "Highscore: "..tostring(highscore)
    love.graphics.print(hsText, (405 - hsFont:getWidth(hsText))/2, 180)
end

function drawGameUI()
    love.graphics.setFont(scoreFont)
    love.graphics.setColor(1, 1, 1)

    love.graphics.draw(shadow, 0, 0)

    -- Draw unlock notification if active
    if unlockNotificationTimer > 0 then
        love.graphics.setFont(notificationFont)
        local alpha = math.min(1, unlockNotificationTimer * 2)  -- Fade out effect
        love.graphics.setColor(0, 1, 0, alpha)
        
        -- Calculate text width and wrap if necessary
        local text = unlockNotification
        local maxWidth = 380  -- Leave some margin
        local textWidth = notificationFont:getWidth(text)
        
        if textWidth > maxWidth then
            -- Find space to split
            local spacePos = text:find(" ", #text/2)
            if spacePos then
                local line1 = text:sub(1, spacePos-1)
                local line2 = text:sub(spacePos+1)
                local line1Width = notificationFont:getWidth(line1)
                local line2Width = notificationFont:getWidth(line2)
                
                love.graphics.print(line1, (405 - line1Width)/2, 80)
                love.graphics.print(line2, (405 - line2Width)/2, 110)
            else
                -- Just center the single line if we can't split it
                love.graphics.print(text, (405 - textWidth)/2, 100)
            end
        else
            love.graphics.print(text, (405 - textWidth)/2, 100)
        end
    end

    if flashlightEnabled then
        love.graphics.push()
        love.graphics.translate(car.x, car.y)
        love.graphics.rotate(car.angle)
        love.graphics.rotate(-math.pi/2)
        love.graphics.setColor(1, 1, 0.7, 0.15)
        love.graphics.arc("fill", 0, 0, 170, math.rad(-15), math.rad(15))
        love.graphics.pop()
    end
end

function drawSkinSelection()
    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 405, 720)
    
    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1)
    local title = "Warderobe"
    love.graphics.print(title, (405 - titleFont:getWidth(title))/2, 50)
    
    -- Back button
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", 20, 20, 100, 50, 10)
    love.graphics.setFont(promptFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Back", 35, 25)
    
    love.graphics.push()
    love.graphics.translate(0, -skinScrollY)
    
    for _, button in ipairs(skinButtons) do
        -- Button background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 10, 10)
        
        -- Selected highlight
        if button.skin.name == currentSkin.name then
            love.graphics.setColor(0, 1, 0, 0.3)
            love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 10, 10)
            love.graphics.setLineWidth(3)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 10, 10)
            love.graphics.setLineWidth(1)
        end
        
        -- Skin preview
        if button.skin.image then
            love.graphics.push()
            love.graphics.translate(button.x + button.width/2, button.y + button.height/2)
            love.graphics.rotate(math.rad(15))
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(button.skin.image, 
                -car.width/2, -car.height/2,
                0,
                car.width/button.skin.image:getWidth(),
                car.height/button.skin.image:getHeight())
            love.graphics.pop()
        else
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
        end
        
        -- Skin name with wrapping
        love.graphics.setFont(skinFont)
        love.graphics.setColor(1, 1, 1)
        
        if button.lines > 1 then
            local spacePos = button.skin.name:find(" ", #button.skin.name/2)
            if spacePos then
                local line1 = button.skin.name:sub(1, spacePos-1)
                local line2 = button.skin.name:sub(spacePos+1)
                love.graphics.print(line1, button.x + (button.width - skinFont:getWidth(line1))/2, button.textY)
                love.graphics.print(line2, button.x + (button.width - skinFont:getWidth(line2))/2, button.textY + 20)
            else
                local nameWidth = skinFont:getWidth(button.skin.name)
                love.graphics.print(button.skin.name, button.x + (button.width - nameWidth)/2, button.textY)
            end
        else
            local nameWidth = skinFont:getWidth(button.skin.name)
            love.graphics.print(button.skin.name, button.x + (button.width - nameWidth)/2, button.textY)
        end
    end
    
    love.graphics.pop()
    
    -- Scroll indicator
    if maxSkinScroll > 0 then
        local scrollBarHeight = 200
        local scrollBarPos = (skinScrollY/maxSkinScroll) * (720 - 150 - scrollBarHeight)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("fill", 390, 150 + scrollBarPos, 10, scrollBarHeight, 5)
    end
end

-- Input handling functions
function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    if skinSelectionMode then
        handleSkinSelectionInput(x, y + skinScrollY)
    elseif not gameStarted then
        if x >= 20 and x <= 120 and y >= 650 and y <= 700 then
            skinSelectionMode = true
        else
            startGame()
        end
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    if not touchId then
        touchId = id
        if skinSelectionMode then
            handleSkinSelectionInput(x, y + skinScrollY)
        elseif not gameStarted then
            if x >= 20 and x <= 120 and y >= 650 and y <= 700 then
                skinSelectionMode = true
            else
                startGame()
            end
        end
    end
end

function handleSkinSelectionInput(x, y)
    -- Back button
    if x >= 20 and x <= 120 and y >= 20 and y <= 70 then
        skinSelectionMode = false
        return
    end
    
    -- Skin buttons
    for _, button in ipairs(skinButtons) do
        if x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height then
            currentSkin = button.skin
            break
        end
    end
end

function startGame()
    gameStarted = true
    score = 0
    scoreTimer = 0
    lastUnlockScore = 0
    car.x = 405 / 2
    targetX = car.x
    car.angle = 0
    flashlightEnabled = false
    flashlightFlickerTimer = 0
    flashlightFlickerCount = 0
    enemyCars = {}
    enemySpawnTimer = 0
    enemySpawnInterval = 1.5
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if id == touchId and gameStarted then
        targetX = x
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    if id == touchId then
        touchId = nil
    end
end

function love.wheelmoved(x, y)
    if skinSelectionMode then
        skinScrollY = math.max(0, math.min(skinScrollY - y * 20, maxSkinScroll))
    end
end

function love.keypressed(key)
    if key == "escape" then
        if skinSelectionMode then
            skinSelectionMode = false
        elseif gameStarted then
            gameStarted = false
        end
    elseif key == "s" and not gameStarted and not skinSelectionMode then
        skinSelectionMode = true
    end
end