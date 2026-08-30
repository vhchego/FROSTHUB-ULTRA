--[[
    ❄️ FROSTHUB ULTRA (XENO - SEM DRAWING) ❄️
    - Verifica disponibilidade do Drawing
    - Desativa FOV/Radar se necessário
    - Interface sempre funcional
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera

-- Verifica se a biblioteca Drawing existe
local hasDrawing = pcall(function() return Drawing.new end)

-- ====================== CONFIGURAÇÕES ======================
local Config = {
    TeamCheck = true,
    Aimbot = {
        Enabled = false,
        AimKey = Enum.UserInputType.MouseButton2,
        AimlockMode = "Hold",
        FOV = 200,
        Smoothness = 0,
        AimPart = "Head",
        ShowFOV = hasDrawing,       -- só mostra se Drawing existir
        FOVColor = Color3.fromRGB(0, 255, 0),
        VisibleCheck = false
    },
    Hitbox = { Enabled = false, ExpandFactor = 1.5 },
    ESP = {
        Enabled = false,
        ShowName = true,
        ShowDistance = true,
        ShowHealth = true,
        ShowWeapon = false,
        TextColor = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        HighlightEnabled = true,
        HighlightColor = Color3.fromRGB(255, 0, 0),
        HighlightTransparency = 0.5
    },
    AutoFarm = {
        Enabled = false, Radius = 50,
        Whitelist = {"Coin", "Gem", "Potion", "HealthPack"},
        Blacklist = {"Trash"}
    },
    Speed = {
        WalkEnabled = false, WalkSpeed = 16,
        JumpEnabled = false, JumpForce = 150,
        WalkToggleKey = Enum.KeyCode.F5, JumpToggleKey = Enum.KeyCode.F6
    },
    Fly = {
        FlyEnabled = false, FlySpeed = 50,
        FlyMinSpeed = 10, FlyMaxSpeed = 500,
        FlyToggleKey = Enum.KeyCode.F7, NoClipEnabled = false,
        NoClipToggleKey = Enum.KeyCode.F8
    },
    Visual = { FullBrightEnabled = false, FullBrightKey = Enum.KeyCode.F9 },
    FreeCam = {
        Enabled = false, ToggleKey = Enum.KeyCode.F4,
        Speed = 50, SpeedStep = 10, MinSpeed = 10, MaxSpeed = 500,
        Sensitivity = 0.5
    },
    Radar = {
        Enabled = false,
        MaxDistance = 250,
        FrostFilter = false,
        MinZoom = 80,
        MaxZoom = 600,
        ZoomStep = 25,
        ToggleKey = Enum.KeyCode.F10
    },
    UI = {
        KeyToggleMenu = Enum.KeyCode.F1,
        KeyToggleAimbot = Enum.KeyCode.F2,
        KeyToggleESP = Enum.KeyCode.F3,
        KeyToggleRadar = Enum.KeyCode.F10,
        MenuEnabled = true,
        AccentColor = Color3.fromRGB(0, 180, 255),
        AccentLight = Color3.fromRGB(100, 220, 255),
        BackgroundColor = Color3.fromRGB(8, 12, 20),
        SectionColor = Color3.fromRGB(14, 20, 32),
        BorderColor = Color3.fromRGB(0, 140, 210),
        TextColor = Color3.fromRGB(220, 240, 255),
        SubTextColor = Color3.fromRGB(140, 180, 210),
        WindowWidth = 380,
        WindowHeight = 520,
        MinWidth = 300,
        MinHeight = 440
    }
}

local KeyBinds = {
    Menu = { Config.UI, "KeyToggleMenu" },
    AimbotToggle = { Config.UI, "KeyToggleAimbot" },
    ESPToggle = { Config.UI, "KeyToggleESP" },
    RadarToggle = { Config.UI, "KeyToggleRadar" },
    FreeCam = { Config.FreeCam, "ToggleKey" },
    WalkSpeed = { Config.Speed, "WalkToggleKey" },
    Jump = { Config.Speed, "JumpToggleKey" },
    Fly = { Config.Fly, "FlyToggleKey" },
    NoClip = { Config.Fly, "NoClipToggleKey" },
    FullBright = { Config.Visual, "FullBrightKey" },
}

-- ====================== ESTADOS ======================
local holdingAimKey = false
local aimbotConnection = nil
local espContainer = nil
local espLoopConn = nil
local espData = {}
local autoFarmConnection = nil
local hitboxConnection = nil
local menuScreenGui = nil
local mainFrame = nil
local fovCircleAimbot = nil
local fovUpdateConn = nil

local freeCamRenderConn = nil
local freeCamInputChanged = nil
local cameraCFrame = nil
local rotationX, rotationY = 0, 0
local freezedRootPart = nil

local walkLoop = nil
local spaceHeld = false

local flyLoop = nil
local bodyGyro = nil
local bodyVelocity = nil
local noclipLoop = nil

local originalLighting = {}
local fullBrightLoop = nil

local resizing = false
local resizeStartPos = nil
local resizeStartSize = nil

local expandedParts = {}
local ToggleUpdates = {}

local rebindingKey = nil
local rebindButton = nil

-- ====================== FUNÇÕES BÁSICAS ======================
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if Config.TeamCheck and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
        return false
    end
    return true
end

-- ====================== VERIFICAÇÃO DE PAREDE ======================
local function IsTargetVisible(targetPart)
    if not targetPart then return false end
    local cam = Camera
    if not cam then return false end
    local startPos = cam.CFrame.Position
    local targetPos = targetPart.Position
    local direction = (targetPos - startPos).Unit
    local distance = (targetPos - startPos).Magnitude

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true

    local result = Workspace:Raycast(startPos, direction * distance, params)
    if not result then return true end
    local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
    if hitChar == targetPart.Parent then return true end
    return false
end

-- ====================== HITBOX EXPANDER ======================
local function ApplyHitboxExpander(player)
    if not Config.Hitbox.Enabled then return end
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if not expandedParts[part] then expandedParts[part] = part.Size end
            part.Size = expandedParts[part] * Config.Hitbox.ExpandFactor
        end
    end
end
local function RestoreHitbox(player)
    for part, origSize in pairs(expandedParts) do
        if part and part.Parent then part.Size = origSize end
    end
    table.clear(expandedParts)
end

-- ====================== AIMBOT (XFROST) ======================
local function GetBestAimbotTarget()
    local cam = Camera
    if not cam then return nil end
    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local fovRadius = Config.Aimbot.FOV
    local bestPart = nil
    local bestDist = math.huge

    for _, p in pairs(Players:GetPlayers()) do
        if not IsEnemy(p) then continue end
        local char = p.Character
        if not char then continue end
        local part = char:FindFirstChild(Config.Aimbot.AimPart)
        if not part then continue end

        if Config.Aimbot.VisibleCheck and not IsTargetVisible(part) then continue end

        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if distToCenter <= fovRadius and distToCenter < bestDist then
            bestDist = distToCenter
            bestPart = part
        end
    end
    return bestPart
end

-- ====================== MOVIMENTAÇÃO DO MOUSE ======================
local function moveMouseToTarget(targetPart)
    local cam = Camera
    if not cam then return end
    local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return end

    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local delta = Vector2.new(screenPos.X, screenPos.Y) - center
    local smoothFactor = Config.Aimbot.Smoothness or 0

    local dist = delta.Magnitude
    if dist < 2 then return end

    local acceleration = 1 + (dist / 300)
    local adjustedSmooth = smoothFactor * acceleration
    if adjustedSmooth > 1 then adjustedSmooth = 1 end

    if smoothFactor == 0 or adjustedSmooth < 0.01 then
        if mousemoverel then
            mousemoverel(delta.X, delta.Y)
        elseif syn and syn.input then
            syn.input.mousemove(delta.X, delta.Y)
        end
        return
    end

    local moveX = delta.X * adjustedSmooth
    local moveY = delta.Y * adjustedSmooth
    if mousemoverel then
        mousemoverel(moveX, moveY)
    elseif syn and syn.input then
        syn.input.mousemove(moveX, moveY)
    end
end

local function AimbotLoop()
    if Config.FreeCam.Enabled then return end
    if not Config.Aimbot.Enabled then return end
    if not holdingAimKey then return end
    local targetPart = GetBestAimbotTarget()
    if targetPart then moveMouseToTarget(targetPart) end
end

-- ====================== FOV CIRCLES (PROTEGIDO) ======================
local function UpdateFOVCircles()
    if not hasDrawing then return end
    if Config.Aimbot.Enabled and Config.Aimbot.ShowFOV and not Config.FreeCam.Enabled then
        if not fovCircleAimbot then
            pcall(function()
                fovCircleAimbot = Drawing.new("Circle")
            end)
        end
        if fovCircleAimbot then
            fovCircleAimbot.Color = Config.Aimbot.FOVColor
            fovCircleAimbot.Thickness = 2
            fovCircleAimbot.Radius = Config.Aimbot.FOV
            fovCircleAimbot.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            fovCircleAimbot.Visible = true
        end
    else
        if fovCircleAimbot then fovCircleAimbot.Visible = false end
    end
end

-- ====================== ESP OTIMIZADO ======================
local function CreateESPContainer()
    if espContainer then espContainer:Destroy() end
    espContainer = Instance.new("ScreenGui")
    espContainer.Name = "FrostHub_ESP"
    espContainer.ResetOnSpawn = false
    espContainer.Parent = CoreGui
end

local function cleanupPlayerESP(player)
    local data = espData[player]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    espData[player] = nil
end

local function espUpdateLoop()
    pcall(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer or not IsEnemy(player) then
                if espData[player] then cleanupPlayerESP(player) end
                continue
            end
            local char = player.Character
            if not char then
                if espData[player] then
                    if espData[player].highlight then espData[player].highlight.Enabled = false end
                    if espData[player].billboard then espData[player].billboard.Enabled = false end
                end
                continue
            end
            local head = char:FindFirstChild("Head")
            if not head then
                if espData[player] then
                    if espData[player].highlight then espData[player].highlight.Enabled = false end
                    if espData[player].billboard then espData[player].billboard.Enabled = false end
                end
                continue
            end
            if not espData[player] then espData[player] = {} end
            local data = espData[player]

            if Config.ESP.HighlightEnabled then
                if not data.highlight or not data.highlight.Parent then
                    local hl = Instance.new("Highlight")
                    hl.FillColor = Config.ESP.HighlightColor
                    hl.FillTransparency = Config.ESP.HighlightTransparency
                    hl.OutlineColor = Color3.new(1,1,1)
                    hl.Parent = char
                    data.highlight = hl
                else
                    data.highlight.FillColor = Config.ESP.HighlightColor
                    data.highlight.FillTransparency = Config.ESP.HighlightTransparency
                    data.highlight.Enabled = true
                    if data.highlight.Parent ~= char then data.highlight.Parent = char end
                end
            else
                if data.highlight then data.highlight:Destroy(); data.highlight = nil end
            end

            if not data.billboard or not data.billboard.Parent then
                local bill = Instance.new("BillboardGui")
                bill.Size = UDim2.new(0, 200, 0, 50)
                bill.AlwaysOnTop = true
                bill.Parent = head
                bill.Adornee = head
                local text = Instance.new("TextLabel")
                text.Size = UDim2.new(1,0,1,0)
                text.BackgroundTransparency = 1
                text.TextColor3 = Config.ESP.TextColor
                text.TextStrokeTransparency = 0
                text.TextScaled = true
                text.Font = Config.ESP.Font
                text.Parent = bill
                data.billboard = bill
                data.billboardText = text
            else
                if data.billboard.Adornee ~= head then data.billboard.Adornee = head end
                data.billboard.Enabled = true
            end

            if data.billboardText then
                local hum = char:FindFirstChild("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local display = ""
                if Config.ESP.ShowName then display = player.Name end
                if Config.ESP.ShowHealth and hum then
                    local hp = math.floor((hum.Health / hum.MaxHealth) * 100)
                    display = display .. (display ~= "" and " | " or "") .. hp .. "%"
                end
                if Config.ESP.ShowDistance and root and myRoot then
                    local dist = (myRoot.Position - root.Position).Magnitude
                    display = display .. (display ~= "" and " | " or "") .. math.floor(dist) .. "m"
                end
                data.billboardText.Text = display
            end
        end

        for player, _ in pairs(espData) do
            if not Players:FindFirstChild(player.Name) then cleanupPlayerESP(player) end
        end
    end)
end

local function enableESP()
    CreateESPContainer()
    if espLoopConn then espLoopConn:Disconnect() end
    espLoopConn = RunService.RenderStepped:Connect(espUpdateLoop)
    Config.ESP.Enabled = true
end

local function disableESP()
    if espLoopConn then espLoopConn:Disconnect(); espLoopConn = nil end
    for _, data in pairs(espData) do
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
    end
    espData = {}
    if espContainer then espContainer:Destroy(); espContainer = nil end
    Config.ESP.Enabled = false
end

-- ====================== AUTO FARM ======================
local function IsItemValid(item)
    for _, kw in ipairs(Config.AutoFarm.Whitelist) do
        if string.find(item.Name, kw) or string.find(item.ClassName, kw) then
            for _, bk in ipairs(Config.AutoFarm.Blacklist) do
                if string.find(item.Name, bk) or string.find(item.ClassName, bk) then return false end
            end
            return true
        end
    end
    return false
end

local function AutoFarmLoop()
    if not Config.AutoFarm.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and IsItemValid(obj) and (obj.Position - root.Position).Magnitude <= Config.AutoFarm.Radius then
            local pp = obj:FindFirstChildOfClass("ProximityPrompt")
            if pp then fireproximityprompt(pp) end
            task.wait(0.02)
        end
    end
end

-- ====================== FULL BRIGHT ======================
local function SaveOriginalLighting()
    originalLighting = {Brightness = Lighting.Brightness, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, ClockTime = Lighting.ClockTime, OutdoorAmbient = Lighting.OutdoorAmbient}
end
local function ApplyFullBright()
    Lighting.Brightness = 2; Lighting.FogEnd = 1e7; Lighting.FogStart = 1e7
    Lighting.ClockTime = 14; Lighting.OutdoorAmbient = Color3.new(1,1,1)
    for _, v in ipairs(Lighting:GetChildren()) do if v:IsA("Atmosphere") then v:Destroy() end end
end
local function RestoreLighting()
    if originalLighting.Brightness then
        Lighting.Brightness = originalLighting.Brightness; Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart; Lighting.ClockTime = originalLighting.ClockTime
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    end
end
function SetFullBrightEnabled(state)
    Config.Visual.FullBrightEnabled = state
    if state then SaveOriginalLighting(); ApplyFullBright()
        if not fullBrightLoop then fullBrightLoop = RunService.Heartbeat:Connect(function() if Config.Visual.FullBrightEnabled then ApplyFullBright() end end) end
    else if fullBrightLoop then fullBrightLoop:Disconnect(); fullBrightLoop = nil end; RestoreLighting() end
    if ToggleUpdates["FullBright"] then ToggleUpdates["FullBright"]() end
end

-- ====================== CÂMERA LIVRE ======================
local function EnableFreeCam()
    if Config.FreeCam.Enabled then return end
    Config.FreeCam.Enabled = true
    local cam = workspace.CurrentCamera
    if not cam then return end
    cameraCFrame = cam.CFrame
    local lookVec = cam.CFrame.LookVector
    rotationY = math.deg(math.asin(lookVec.Y))
    rotationX = math.deg(math.atan2(-lookVec.X, -lookVec.Z))
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    if LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.Anchored = true; freezedRootPart = root end
    end
    freeCamRenderConn = RunService.RenderStepped:Connect(function(deltaTime)
        if not Config.FreeCam.Enabled then return end
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cameraCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cameraCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cameraCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cameraCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0,1,0) end
        if moveDir.Magnitude > 0 then moveDir = moveDir.Unit; cameraCFrame += moveDir * Config.FreeCam.Speed * deltaTime end
        local rotCFrame = CFrame.fromEulerAnglesYXZ(math.rad(rotationY), math.rad(rotationX), 0)
        cameraCFrame = CFrame.new(cameraCFrame.Position) * rotCFrame
        cam.CFrame = cameraCFrame
    end)
    freeCamInputChanged = UserInputService.InputChanged:Connect(function(input)
        if not Config.FreeCam.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Delta * Config.FreeCam.Sensitivity
            rotationX = rotationX - delta.X; rotationY = math.clamp(rotationY - delta.Y, -89, 89)
        elseif input.UserInputType == Enum.UserInputType.MouseWheel then
            Config.FreeCam.Speed = math.clamp(Config.FreeCam.Speed + (input.Position.Z > 0 and Config.FreeCam.SpeedStep or -Config.FreeCam.SpeedStep), Config.FreeCam.MinSpeed, Config.FreeCam.MaxSpeed)
        end
    end)
    if aimbotConnection and Config.Aimbot.Enabled then StopAimbot(); Config.Aimbot.Enabled = true end
end
local function DisableFreeCam()
    if not Config.FreeCam.Enabled then return end
    Config.FreeCam.Enabled = false
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    if freeCamRenderConn then freeCamRenderConn:Disconnect(); freeCamRenderConn = nil end
    if freeCamInputChanged then freeCamInputChanged:Disconnect(); freeCamInputChanged = nil end
    if freezedRootPart then freezedRootPart.Anchored = false; freezedRootPart = nil end
    if Config.Aimbot.Enabled and not aimbotConnection then StartAimbot() end
end
local function ToggleFreeCam()
    if Config.FreeCam.Enabled then DisableFreeCam() else EnableFreeCam() end
end

-- ====================== SPEED HACK ======================
local function ApplyWalk(hum)
    if Config.Speed.WalkEnabled then hum.WalkSpeed = Config.Speed.WalkSpeed else hum.WalkSpeed = 16 end
end
function SetWalkEnabled(state)
    Config.Speed.WalkEnabled = state
    if state then
        if not walkLoop then walkLoop = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then local hum = char:FindFirstChild("Humanoid"); if hum and hum.Health > 0 then ApplyWalk(hum) end end
        end) end
    else
        if walkLoop then walkLoop:Disconnect(); walkLoop = nil end
        local char = LocalPlayer.Character
        if char then local hum = char:FindFirstChild("Humanoid"); if hum then hum.WalkSpeed = 16 end end
    end
    if ToggleUpdates["WalkEnabled"] then ToggleUpdates["WalkEnabled"]() end
end
function SetJumpEnabled(state)
    Config.Speed.JumpEnabled = state
    if ToggleUpdates["JumpEnabled"] then ToggleUpdates["JumpEnabled"]() end
end

-- ====================== FLY + NOCLIP (ORIGINAL) ======================
function StartFly()
    if flyLoop then return end
    local char = LocalPlayer.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    bodyGyro = Instance.new("BodyGyro"); bodyGyro.MaxTorque = Vector3.new(400000,400000,400000); bodyGyro.CFrame = root.CFrame; bodyGyro.P = 10000; bodyGyro.D = 100; bodyGyro.Parent = root
    bodyVelocity = Instance.new("BodyVelocity"); bodyVelocity.MaxForce = Vector3.new(400000,400000,400000); bodyVelocity.Velocity = Vector3.zero; bodyVelocity.P = 10000; bodyVelocity.Parent = root
    flyLoop = RunService.Heartbeat:Connect(function()
        if not Config.Fly.FlyEnabled then return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        local cam = workspace.CurrentCamera
        if cam and bodyGyro then bodyGyro.CFrame = cam.CFrame end
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0,1,0) end
        if moveDir.Magnitude > 0 then moveDir = moveDir.Unit * Config.Fly.FlySpeed end
        if bodyVelocity then bodyVelocity.Velocity = moveDir end
    end)
end
function StopFly()
    if flyLoop then flyLoop:Disconnect(); flyLoop = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
end
function StartNoClip()
    if noclipLoop then return end
    noclipLoop = RunService.Heartbeat:Connect(function()
        if not Config.Fly.NoClipEnabled then return end
        local char = LocalPlayer.Character; if not char then return end
        for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end
    end)
end
function StopNoClip()
    if noclipLoop then noclipLoop:Disconnect(); noclipLoop = nil end
    local char = LocalPlayer.Character
    if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end
end

-- ====================== GERENCIAMENTO DE LOOP ======================
local function StartAimbot()
    if aimbotConnection then aimbotConnection:Disconnect() end
    aimbotConnection = RunService.RenderStepped:Connect(AimbotLoop)
end
local function StopAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
end
local function StartESP() Config.ESP.Enabled = true; enableESP() end
local function StopESP() Config.ESP.Enabled = false; disableESP() end
local function StartAutoFarm()
    if autoFarmConnection then autoFarmConnection:Disconnect() end
    autoFarmConnection = RunService.Heartbeat:Connect(AutoFarmLoop)
end
local function StopAutoFarm()
    if autoFarmConnection then autoFarmConnection:Disconnect(); autoFarmConnection = nil end
end
local function StartHitbox()
    if hitboxConnection then hitboxConnection:Disconnect() end
    hitboxConnection = RunService.Heartbeat:Connect(function()
        if not Config.Hitbox.Enabled then return end
        for _, player in ipairs(Players:GetPlayers()) do if IsEnemy(player) then ApplyHitboxExpander(player) end end
    end)
end
local function StopHitbox()
    if hitboxConnection then hitboxConnection:Disconnect(); hitboxConnection = nil end
    for _, player in ipairs(Players:GetPlayers()) do RestoreHitbox(player) end
end

-- ====================== RADAR TÁTICO (PROTEGIDO) ======================
local radarActive = false
local radarConnection = nil
local radarViewportConn = nil
local radarObjects = {}
local playerDots = {}
local playerLabels = {}
local zoomLevel = Config.Radar.MaxDistance
local radarCenterX = 0
local radarCenterY = 0
local radarHalfSize = 95

local function SafeRemove(obj)
    if obj and type(obj) == "table" and obj.Remove then
        pcall(function() obj:Remove() end)
    end
end

local function BuildRadar()
    if not hasDrawing then return end
    for _, obj in pairs(radarObjects) do SafeRemove(obj) end
    radarObjects = {}
    for _, dot in pairs(playerDots) do SafeRemove(dot) end
    playerDots = {}
    for _, lbl in pairs(playerLabels) do SafeRemove(lbl) end
    playerLabels = {}

    if not Camera then return end
    local viewport = Camera.ViewportSize
    local halfSize = radarHalfSize
    local centerX = viewport.X - 190 - 30 + halfSize
    local centerY = viewport.Y / 2
    radarCenterX = centerX
    radarCenterY = centerY

    local bg = Drawing.new("Quad")
    bg.PointA = Vector2.new(centerX - halfSize, centerY - halfSize)
    bg.PointB = Vector2.new(centerX + halfSize, centerY - halfSize)
    bg.PointC = Vector2.new(centerX + halfSize, centerY + halfSize)
    bg.PointD = Vector2.new(centerX - halfSize, centerY + halfSize)
    bg.Thickness = 0
    bg.Filled = true
    bg.Color = Color3.fromRGB(6, 10, 20)
    bg.Transparency = 0.85
    bg.Visible = true
    table.insert(radarObjects, bg)

    local borders = {
        {Vector2.new(centerX - halfSize, centerY - halfSize), Vector2.new(centerX + halfSize, centerY - halfSize)},
        {Vector2.new(centerX + halfSize, centerY - halfSize), Vector2.new(centerX + halfSize, centerY + halfSize)},
        {Vector2.new(centerX + halfSize, centerY + halfSize), Vector2.new(centerX - halfSize, centerY + halfSize)},
        {Vector2.new(centerX - halfSize, centerY + halfSize), Vector2.new(centerX - halfSize, centerY - halfSize)}
    }
    for _, pair in ipairs(borders) do
        local line = Drawing.new("Line")
        line.From = pair[1]
        line.To = pair[2]
        line.Thickness = 2.5
        line.Color = Color3.fromRGB(0, 200, 255)
        line.Visible = true
        table.insert(radarObjects, line)
    end

    for i = 1, 3 do
        local frac = i / 4
        local pos = -halfSize + (190 * frac)
        local vLine = Drawing.new("Line")
        vLine.From = Vector2.new(centerX + pos, centerY - halfSize)
        vLine.To = Vector2.new(centerX + pos, centerY + halfSize)
        vLine.Thickness = 1
        vLine.Color = Color3.fromRGB(30, 60, 90)
        vLine.Transparency = 0.4
        vLine.Visible = true
        table.insert(radarObjects, vLine)
        local hLine = Drawing.new("Line")
        hLine.From = Vector2.new(centerX - halfSize, centerY + pos)
        hLine.To = Vector2.new(centerX + halfSize, centerY + pos)
        hLine.Thickness = 1
        hLine.Color = Color3.fromRGB(30, 60, 90)
        hLine.Transparency = 0.4
        hLine.Visible = true
        table.insert(radarObjects, hLine)
    end

    local function compass(text, x, y, color)
        local txt = Drawing.new("Text")
        txt.Size = 12; txt.Center = true; txt.Font = Drawing.Fonts.UI
        txt.Color = color or Color3.fromRGB(200, 230, 255)
        txt.Position = Vector2.new(centerX + x, centerY + y)
        txt.Text = text; txt.Visible = true
        table.insert(radarObjects, txt)
    end
    compass("N", 0, -halfSize + 16, Color3.fromRGB(0, 255, 255))
    compass("S", 0, halfSize - 16, Color3.fromRGB(255, 100, 100))
    compass("L", halfSize - 16, 0, Color3.fromRGB(200, 200, 200))
    compass("O", -halfSize + 16, 0, Color3.fromRGB(200, 200, 200))

    local dirLine = Drawing.new("Line")
    dirLine.From = Vector2.new(centerX, centerY)
    dirLine.To = Vector2.new(centerX, centerY - halfSize)
    dirLine.Thickness = 2
    dirLine.Color = Color3.fromRGB(255, 255, 255)
    dirLine.Transparency = 0.5
    dirLine.Visible = true
    table.insert(radarObjects, dirLine)
    radarObjects.dirLine = dirLine

    local centerDot = Drawing.new("Circle")
    centerDot.Radius = 6
    centerDot.Position = Vector2.new(centerX, centerY)
    centerDot.Filled = true
    centerDot.Color = Color3.fromRGB(0, 255, 255)
    centerDot.Visible = true
    table.insert(radarObjects, centerDot)

    local statusIcon = Drawing.new("Text")
    statusIcon.Size = 18; statusIcon.Center = false; statusIcon.Font = Drawing.Fonts.UI
    statusIcon.Position = Vector2.new(centerX - halfSize + 8, centerY + halfSize - 28)
    statusIcon.Text = Config.Radar.FrostFilter and "❄️" or "🔥"
    statusIcon.Color = Config.Radar.FrostFilter and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(255, 100, 50)
    statusIcon.Visible = true
    table.insert(radarObjects, statusIcon)
    radarObjects.statusIcon = statusIcon

    local statusText = Drawing.new("Text")
    statusText.Size = 12; statusText.Center = false; statusText.Font = Drawing.Fonts.UI
    statusText.Color = Color3.fromRGB(160, 210, 255)
    statusText.Position = Vector2.new(centerX - halfSize + 32, centerY + halfSize - 25)
    statusText.Text = Config.Radar.FrostFilter and "❄️ Filtro: ON" or "🔥 Filtro: OFF"
    statusText.Visible = true
    table.insert(radarObjects, statusText)
    radarObjects.statusText = statusText

    local zoomText = Drawing.new("Text")
    zoomText.Size = 11; zoomText.Center = false; zoomText.Font = Drawing.Fonts.UI
    zoomText.Color = Color3.fromRGB(100, 200, 255)
    zoomText.Position = Vector2.new(centerX - halfSize + 8, centerY - halfSize + 8)
    zoomText.Text = "🔍 " .. math.floor(zoomLevel) .. "m"
    zoomText.Visible = true
    table.insert(radarObjects, zoomText)
    radarObjects.zoomText = zoomText
end

local function HideAllDots()
    for _, dot in pairs(playerDots) do
        if dot and dot.Visible ~= nil then dot.Visible = false end
    end
    for _, lbl in pairs(playerLabels) do
        if lbl and lbl.Visible ~= nil then lbl.Visible = false end
    end
end

local function UpdateRadar()
    if not radarActive then
        for _, obj in pairs(radarObjects) do
            if obj and obj.Visible ~= nil then obj.Visible = false end
        end
        HideAllDots()
        return
    end

    for _, obj in pairs(radarObjects) do
        if obj and obj.Visible ~= nil then obj.Visible = true end
    end

    if radarObjects.statusText then
        radarObjects.statusText.Text = Config.Radar.FrostFilter and "❄️ Filtro: ON" or "🔥 Filtro: OFF"
    end
    if radarObjects.statusIcon then
        radarObjects.statusIcon.Text = Config.Radar.FrostFilter and "❄️" or "🔥"
        radarObjects.statusIcon.Color = Config.Radar.FrostFilter and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(255, 100, 50)
    end
    if radarObjects.zoomText then
        radarObjects.zoomText.Text = "🔍 " .. math.floor(zoomLevel) .. "m"
    end

    local cam = Camera
    if not cam then HideAllDots() return end
    local char = LocalPlayer.Character
    if not char then HideAllDots() return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then HideAllDots() return end

    local centerX = radarCenterX
    local centerY = radarCenterY
    local halfSize = radarHalfSize
    local maxDist = zoomLevel
    local scale = 190 / (maxDist * 2)
    local localPos = root.Position

    if radarObjects.dirLine then
        local forward = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
        if forward.Magnitude > 0 then
            forward = forward.Unit
            local endX = centerX + (forward.X * halfSize)
            local endY = centerY + (-forward.Z * halfSize)
            radarObjects.dirLine.From = Vector2.new(centerX, centerY)
            radarObjects.dirLine.To = Vector2.new(endX, endY)
            radarObjects.dirLine.Visible = true
        end
    end

    local activePlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local pChar = player.Character
        if not pChar then continue end
        local targetPart = pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart")
        if not targetPart then continue end
        local hum = pChar:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local isSameTeam = false
        if LocalPlayer.Team and player.Team then
            isSameTeam = (LocalPlayer.Team == player.Team)
        end
        if Config.Radar.FrostFilter and isSameTeam then continue end

        local rel = (targetPart.Position - localPos) * Vector3.new(1, 0, 1)
        local dist = rel.Magnitude
        if dist >= maxDist then continue end

        local mapX = centerX + (rel.X * scale)
        local mapY = centerY + (-rel.Z * scale)

        if math.abs(mapX - centerX) > halfSize or math.abs(mapY - centerY) > halfSize then
            continue
        end

        local dot = playerDots[player]
        if not dot then
            dot = Drawing.new("Circle")
            dot.Radius = 4
            dot.Filled = true
            dot.Visible = true
            playerDots[player] = dot
        end
        dot.Position = Vector2.new(mapX, mapY)
        dot.Color = isSameTeam and Color3.fromRGB(80, 255, 255) or Color3.fromRGB(255, 60, 80)
        dot.Visible = true

        local label = playerLabels[player]
        if not label then
            label = Drawing.new("Text")
            label.Size = 10
            label.Center = true
            label.Font = Drawing.Fonts.UI
            label.Outline = true
            label.OutlineColor = Color3.fromRGB(0, 0, 0)
            label.Visible = true
            playerLabels[player] = label
        end

        local hpPercent = math.floor((hum.Health / hum.MaxHealth) * 100)
        local nameColor = isSameTeam and Color3.fromRGB(80, 255, 255) or Color3.fromRGB(255, 60, 80)
        label.Text = string.format("%s | %d%% | %dm", player.Name, hpPercent, math.floor(dist))
        label.Color = nameColor
        label.Position = Vector2.new(mapX, mapY - 16)
        label.Visible = true

        activePlayers[player] = true
    end

    for player, dot in pairs(playerDots) do
        if not activePlayers[player] then
            dot.Visible = false
            if playerLabels[player] then playerLabels[player].Visible = false end
        end
    end
end

local function StartRadar()
    if radarActive or not hasDrawing then return end
    radarActive = true
    Config.Radar.Enabled = true
    BuildRadar()
    if not radarConnection then
        radarConnection = RunService.RenderStepped:Connect(UpdateRadar)
    end
    if not radarViewportConn then
        radarViewportConn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(BuildRadar)
    end
    if ToggleUpdates["Radar"] then ToggleUpdates["Radar"]() end
    print("[🗺️ Radar] ATIVADO")
end

local function StopRadar()
    if not radarActive then return end
    radarActive = false
    Config.Radar.Enabled = false
    if radarConnection then radarConnection:Disconnect(); radarConnection = nil end
    if radarViewportConn then radarViewportConn:Disconnect(); radarViewportConn = nil end
    for _, obj in pairs(radarObjects) do SafeRemove(obj) end
    for _, dot in pairs(playerDots) do SafeRemove(dot) end
    for _, lbl in pairs(playerLabels) do SafeRemove(lbl) end
    radarObjects = {}
    playerDots = {}
    playerLabels = {}
    if ToggleUpdates["Radar"] then ToggleUpdates["Radar"]() end
    print("[🗺️ Radar] DESATIVADO")
end

local function ToggleRadar()
    if radarActive then StopRadar() else StartRadar() end
end

-- ====================== INTERFACE (COM REBIND E SEGURANÇA) ======================
local function CleanupMenu()
    -- Desconecta eventos antigos, se existirem
    pcall(function() if inputBeganConn then inputBeganConn:Disconnect() end end)
    pcall(function() if inputEndedConn then inputEndedConn:Disconnect() end end)
    pcall(function() if inputChangedConn then inputChangedConn:Disconnect() end end)
    if menuScreenGui then menuScreenGui:Destroy() end
end

local function CreateMenu()
    CleanupMenu()
    menuScreenGui = Instance.new("ScreenGui")
    menuScreenGui.Name = "FrostHubMenu"
    menuScreenGui.ResetOnSpawn = false
    menuScreenGui.Parent = CoreGui
    menuScreenGui.Enabled = Config.UI.MenuEnabled

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, Config.UI.WindowWidth, 0, Config.UI.WindowHeight)
    mainFrame.Position = UDim2.new(0.5, -Config.UI.WindowWidth/2, 0.5, -Config.UI.WindowHeight/2)
    mainFrame.BackgroundColor3 = Config.UI.BackgroundColor
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = menuScreenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)
    Instance.new("UIStroke", mainFrame).Color = Config.UI.BorderColor
    mainFrame.UIStroke.Thickness = 1.5

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 42)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -60, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "❄️ FROSTHUB ULTRA"
    titleText.TextColor3 = Config.UI.TextColor
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 18
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -34, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Config.UI.TextColor
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 40, 60)}):Play() end)
    closeBtn.MouseButton1Click:Connect(function() Config.UI.MenuEnabled = false; menuScreenGui.Enabled = false end)

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -66, 0, 6)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    minimizeBtn.Text = "_"
    minimizeBtn.TextColor3 = Config.UI.TextColor
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 14
    minimizeBtn.AutoButtonColor = false
    minimizeBtn.Parent = titleBar
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)
    minimizeBtn.MouseEnter:Connect(function() TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 80)}):Play() end)
    minimizeBtn.MouseLeave:Connect(function() TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 40, 60)}):Play() end)
    minimizeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -24, 0, 36)
    tabBar.Position = UDim2.new(0, 12, 0, 50)
    tabBar.BackgroundColor3 = Config.UI.SectionColor
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame
    Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", tabBar).Color = Config.UI.BorderColor
    tabBar.UIStroke.Thickness = 1

    local tabs = {
        {name = "Aimbot", icon = "🎯"},
        {name = "ESP", icon = "👁️"},
        {name = "Farm", icon = "🧲"},
        {name = "Speed", icon = "⚡"},
        {name = "Fly", icon = "🕊️"},
        {name = "Visual", icon = "☀️"},
        {name = "Radar", icon = "🗺️"},
        {name = "Teclas", icon = "⌨️"},
        {name = "Info", icon = "❄️"}
    }
    local tabButtons = {}
    local tabPages = {}
    local currentTab = "Aimbot"

    local contentArea = Instance.new("ScrollingFrame")
    contentArea.Size = UDim2.new(1, -24, 1, -94)
    contentArea.Position = UDim2.new(0, 12, 0, 90)
    contentArea.BackgroundTransparency = 1
    contentArea.BorderSizePixel = 0
    contentArea.ScrollBarThickness = 3
    contentArea.ScrollBarImageColor3 = Config.UI.AccentColor
    contentArea.CanvasSize = UDim2.new(0, 0, 0, 1200)
    contentArea.ClipsDescendants = true
    contentArea.Parent = mainFrame

    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 48, 1, 0)
        btn.Position = UDim2.new(0, (i-1)*52, 0, 0)
        btn.BackgroundColor3 = tab.name == currentTab and Config.UI.AccentColor or Config.UI.SectionColor
        btn.Text = tab.icon .. " " .. tab.name
        btn.TextColor3 = Config.UI.TextColor
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 8
        btn.AutoButtonColor = false
        btn.Parent = tabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        tabButtons[tab.name] = btn
        btn.MouseEnter:Connect(function()
            if tab.name ~= currentTab then TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 60, 100)}):Play() end
        end)
        btn.MouseLeave:Connect(function()
            if tab.name ~= currentTab then TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Config.UI.SectionColor}):Play() end
        end)

        local page = Instance.new("Frame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.Visible = (tab.name == currentTab)
        page.Parent = contentArea
        tabPages[tab.name] = page

        btn.MouseButton1Click:Connect(function()
            for name, b in pairs(tabButtons) do TweenService:Create(b, TweenInfo.new(0.25), {BackgroundColor3 = Config.UI.SectionColor}):Play() end
            TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = Config.UI.AccentColor}):Play()
            for name, p in pairs(tabPages) do p.Visible = (name == tab.name) end
            currentTab = tab.name
        end)
    end

    local function CreateToggle(page, yPos, text, configTable, configKey, callback, toggleId)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 34)
        frame.Position = UDim2.new(0, 4, 0, yPos)
        frame.BackgroundColor3 = Config.UI.SectionColor
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = page
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", frame).Color = Config.UI.BorderColor
        frame.UIStroke.Thickness = 0.5
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 200, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. (configTable[configKey] and "ON" or "OFF")
        label.TextColor3 = Config.UI.TextColor
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        local switch = Instance.new("Frame")
        switch.Size = UDim2.new(0, 44, 0, 22)
        switch.Position = UDim2.new(1, -56, 0.5, -11)
        switch.BackgroundColor3 = configTable[configKey] and Config.UI.AccentColor or Color3.fromRGB(20, 30, 50)
        switch.BorderSizePixel = 0
        switch.Parent = frame
        Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = configTable[configKey] and UDim2.new(0, 24, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        knob.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
        knob.BorderSizePixel = 0
        knob.Parent = switch
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local function UpdateVisual()
            local enabled = configTable[configKey]
            local targetColor = enabled and Config.UI.AccentColor or Color3.fromRGB(20, 30, 50)
            local targetPos = enabled and UDim2.new(0, 24, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
            label.Text = text .. ": " .. (enabled and "ON" or "OFF")
        end
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                configTable[configKey] = not configTable[configKey]
                UpdateVisual()
                if callback then callback(configTable[configKey]) end
            end
        end)
        if toggleId then ToggleUpdates[toggleId] = UpdateVisual end
        return frame
    end

    local function CreateSlider(page, yPos, text, configTable, configKey, min, max, step, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 60)
        frame.Position = UDim2.new(0, 4, 0, yPos)
        frame.BackgroundColor3 = Config.UI.SectionColor
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = page
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", frame).Color = Config.UI.BorderColor
        frame.UIStroke.Thickness = 0.5
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -24, 0, 18)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. tostring(configTable[configKey])
        label.TextColor3 = Config.UI.TextColor
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, -24, 0, 6)
        sliderBg.Position = UDim2.new(0, 12, 0, 30)
        sliderBg.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = frame
        Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 3)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((configTable[configKey] - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Config.UI.AccentColor
        fill.BorderSizePixel = 0
        fill.Parent = sliderBg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = UDim2.new((configTable[configKey] - min) / (max - min), -7, 0.5, -7)
        knob.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
        knob.BorderSizePixel = 0
        knob.Parent = sliderBg
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local dragging = false
        local function updateValue(inputX)
            local relX = math.clamp((inputX - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local raw = min + (max - min) * relX
            local stepped = math.floor(raw / step + 0.5) * step
            local value = math.clamp(stepped, min, max)
            configTable[configKey] = value
            label.Text = text .. ": " .. tostring(value)
            fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
            knob.Position = UDim2.new((value - min) / (max - min), -7, 0.5, -7)
            if callback then callback(value) end
        end
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; updateValue(input.Position.X) end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateValue(input.Position.X) end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        return frame
    end

    -- ========== ABA AIMBOT ==========
    local aimPage = tabPages["Aimbot"]
    local y = 5
    CreateToggle(aimPage, y, "🎯 Aimbot", Config.Aimbot, "Enabled", function(val) if val then StartAimbot() else StopAimbot() end end, "Aimbot")
    y = y + 40
    CreateSlider(aimPage, y, "FOV (Tamanho)", Config.Aimbot, "FOV", 50, 400, 10, nil)
    y = y + 66
    CreateSlider(aimPage, y, "🎯 Suavidade", Config.Aimbot, "Smoothness", 0, 1, 0.05)
    y = y + 66
    CreateToggle(aimPage, y, "⭕ Mostrar FOV", Config.Aimbot, "ShowFOV", nil, "AimbotFOV")
    y = y + 40
    CreateToggle(aimPage, y, "👁️ Visível Apenas", Config.Aimbot, "VisibleCheck", nil)
    y = y + 40
    CreateToggle(aimPage, y, "🛡️ Team Check", Config, "TeamCheck")
    y = y + 40
    CreateToggle(aimPage, y, "📦 Hitbox Expander", Config.Hitbox, "Enabled", function(val) if val then StartHitbox() else StopHitbox() end end)
    y = y + 40
    CreateSlider(aimPage, y, "Fator Hitbox", Config.Hitbox, "ExpandFactor", 1, 5, 0.1)

    -- ========== ABA ESP ==========
    local espPage = tabPages["ESP"]
    y = 5
    CreateToggle(espPage, y, "👁️ ESP", Config.ESP, "Enabled", function(val) if val then StartESP() else StopESP() end end, "ESP")
    y = y + 40
    CreateToggle(espPage, y, "✨ Highlight", Config.ESP, "HighlightEnabled")
    y = y + 40
    CreateToggle(espPage, y, "📛 Nome", Config.ESP, "ShowName")
    y = y + 40
    CreateToggle(espPage, y, "📏 Distância", Config.ESP, "ShowDistance")
    y = y + 40
    CreateToggle(espPage, y, "❤️ Vida", Config.ESP, "ShowHealth")

    -- ========== ABA AUTO FARM ==========
    local farmPage = tabPages["Farm"]
    y = 5
    CreateToggle(farmPage, y, "🧲 Auto Farm", Config.AutoFarm, "Enabled", function(val) if val then StartAutoFarm() else StopAutoFarm() end end)
    y = y + 40
    CreateSlider(farmPage, y, "Raio", Config.AutoFarm, "Radius", 10, 200, 5)

    -- ========== ABA SPEED ==========
    local speedPage = tabPages["Speed"]
    y = 5
    CreateToggle(speedPage, y, "⚡ WalkSpeed", Config.Speed, "WalkEnabled", function(val) SetWalkEnabled(val) end, "WalkEnabled")
    y = y + 40
    CreateSlider(speedPage, y, "Velocidade", Config.Speed, "WalkSpeed", 1, 200, 1)
    y = y + 66
    CreateToggle(speedPage, y, "🦘 Pulo Explosivo", Config.Speed, "JumpEnabled", function(val) SetJumpEnabled(val) end, "JumpEnabled")
    y = y + 40
    CreateSlider(speedPage, y, "Força do Pulo", Config.Speed, "JumpForce", 10, 1000, 10)

    -- ========== ABA FLY ==========
    local flyPage = tabPages["Fly"]
    y = 5
    CreateToggle(flyPage, y, "🕊️ Fly", Config.Fly, "FlyEnabled", function(val) if val then StartFly() else StopFly() end end, "FlyEnabled")
    y = y + 40
    CreateSlider(flyPage, y, "Velocidade Fly", Config.Fly, "FlySpeed", Config.Fly.FlyMinSpeed, Config.Fly.FlyMaxSpeed, 1)
    y = y + 66
    CreateToggle(flyPage, y, "🚪 NoClip", Config.Fly, "NoClipEnabled", function(val) if val then StartNoClip() else StopNoClip() end end, "NoClipEnabled")

    -- ========== ABA VISUAL ==========
    local visualPage = tabPages["Visual"]
    y = 5
    CreateToggle(visualPage, y, "☀️ Full Bright", Config.Visual, "FullBrightEnabled", function(val) SetFullBrightEnabled(val) end, "FullBright")

    -- ========== ABA RADAR ==========
    local radarPage = tabPages["Radar"]
    y = 5
    CreateToggle(radarPage, y, "🗺️ Radar Tático", Config.Radar, "Enabled", function(val) 
        if val then StartRadar() else StopRadar() end 
    end, "Radar")
    y = y + 40
    CreateSlider(radarPage, y, "🔍 Alcance (Zoom)", Config.Radar, "MaxDistance", 80, 600, 10, function(val)
        zoomLevel = val
        if radarObjects.zoomText then
            radarObjects.zoomText.Text = "🔍 " .. math.floor(zoomLevel) .. "m"
        end
    end)
    y = y + 66
    CreateToggle(radarPage, y, "❄️ Filtro Gélido", Config.Radar, "FrostFilter", nil, "RadarFilter")

    -- ========== ABA TECLAS (REBIND) ==========
    local keysPage = tabPages["Teclas"]
    local keyY = 5

    local function createKeyBindRow(actionName, displayName)
        local bind = KeyBinds[actionName]
        if not bind then return end
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 34)
        frame.Position = UDim2.new(0, 4, 0, keyY)
        frame.BackgroundColor3 = Config.UI.SectionColor
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = keysPage
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", frame).Color = Config.UI.BorderColor
        frame.UIStroke.Thickness = 0.5

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 150, 1, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = displayName .. ":"
        label.TextColor3 = Config.UI.TextColor
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 80, 0, 24)
        keyBtn.Position = UDim2.new(1, -92, 0.5, -12)
        keyBtn.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        local currentKey = bind[1][bind[2]]
        keyBtn.Text = currentKey.Name
        keyBtn.TextColor3 = Config.UI.TextColor
        keyBtn.Font = Enum.Font.Gotham
        keyBtn.TextSize = 11
        keyBtn.AutoButtonColor = false
        keyBtn.Parent = frame
        Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 4)

        keyBtn.MouseButton1Click:Connect(function()
            if rebindingKey then return end
            rebindingKey = actionName
            rebindButton = keyBtn
            keyBtn.Text = "..."
            keyBtn.BackgroundColor3 = Config.UI.AccentColor
        end)

        keyY = keyY + 38
        return keyBtn
    end

    createKeyBindRow("Menu", "Menu (F1)")
    createKeyBindRow("AimbotToggle", "Aimbot (F2)")
    createKeyBindRow("ESPToggle", "ESP (F3)")
    createKeyBindRow("RadarToggle", "Radar (F10)")
    createKeyBindRow("FreeCam", "Free Cam (F4)")
    createKeyBindRow("WalkSpeed", "WalkSpeed (F5)")
    createKeyBindRow("Jump", "Pulo Explosivo (F6)")
    createKeyBindRow("Fly", "Fly (F7)")
    createKeyBindRow("NoClip", "NoClip (F8)")
    createKeyBindRow("FullBright", "Full Bright (F9)")

    -- ========== ABA INFO ==========
    local infoPage = tabPages["Info"]
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -16, 1, -16)
    infoLabel.Position = UDim2.new(0, 8, 0, 8)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = [[
    ❄️ FROSTHUB ULTRA ❄️
    
    🎮 ATALHOS (reconfiguráveis na aba "Teclas"):
    [F1] Menu
    [F2] Aimbot
    [F3] ESP
    [F4] Free Cam
    [F5] WalkSpeed
    [F6] Pulo Explosivo
    [F7] Fly
    [F8] NoClip
    [F9] Full Bright
    [F10] Radar Tático
    [Botão Dir.] Aimbot (Hold)
    
    🔒 AIMBOT BRUTO COM WALLBANG CHECK
    🗺️ RADAR TÁTICO COM NOME, HP E DISTÂNCIA
    🧱 VISÍVEL APENAS (WALLBANG)
    🔫 AIMBOT BASEADO NO XFROST (RIVALS)
    ⚡ SMOOTHNESS PADRÃO = 0 (INSTANTÂNEO)
    ]]
    infoLabel.TextColor3 = Config.UI.SubTextColor
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.RichText = true
    infoLabel.Parent = infoPage

    -- Redimensionamento
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Size = UDim2.new(0, 20, 0, 20)
    resizeHandle.Position = UDim2.new(1, 0, 1, 0)
    resizeHandle.AnchorPoint = Vector2.new(1, 1)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = ""
    resizeHandle.AutoButtonColor = false
    resizeHandle.Parent = mainFrame
    local resizeIcon = Instance.new("ImageLabel")
    resizeIcon.Size = UDim2.new(0, 14, 0, 14)
    resizeIcon.Position = UDim2.new(0, 2, 0, 2)
    resizeIcon.BackgroundTransparency = 1
    resizeIcon.Image = "rbxassetid://6924631287"
    resizeIcon.ImageColor3 = Config.UI.SubTextColor
    resizeIcon.ScaleType = Enum.ScaleType.Fit
    resizeIcon.Parent = resizeHandle
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true; resizeStartPos = input.Position; resizeStartSize = mainFrame.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStartPos
            local newWidth = math.max(Config.UI.MinWidth, resizeStartSize.X + delta.X)
            local newHeight = math.max(Config.UI.MinHeight, resizeStartSize.Y + delta.Y)
            mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
            Config.UI.WindowWidth = newWidth; Config.UI.WindowHeight = newHeight
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
    end)

    -- Arraste
    local dragStart, dragStartPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = input.Position; dragStartPos = mainFrame.Position end
    end)
    inputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X, dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)
        end
    end)
    inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = nil end
    end)

    -- Teclas (com suporte a rebind)
    inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if rebindingKey then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local bind = KeyBinds[rebindingKey]
                if bind then
                    bind[1][bind[2]] = input.KeyCode
                    rebindButton.Text = input.KeyCode.Name
                end
                rebindingKey = nil
                rebindButton.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
                rebindButton = nil
                return
            else
                return
            end
        end

        if UserInputService:GetFocusedTextBox() then return end
        if input.UserInputType == Config.Aimbot.AimKey then
            holdingAimKey = true
        elseif input.KeyCode == Config.UI.KeyToggleMenu then
            Config.UI.MenuEnabled = not Config.UI.MenuEnabled
            if menuScreenGui then
                menuScreenGui.Enabled = Config.UI.MenuEnabled
                if mainFrame then mainFrame.Visible = true end
            else
                if Config.UI.MenuEnabled then CreateMenu() end
            end
        elseif input.KeyCode == Config.UI.KeyToggleAimbot then
            Config.Aimbot.Enabled = not Config.Aimbot.Enabled
            Config.Aimbot.ShowFOV = Config.Aimbot.Enabled
            if Config.Aimbot.Enabled then StartAimbot() else StopAimbot() end
            if ToggleUpdates["Aimbot"] then ToggleUpdates["Aimbot"]() end
            if ToggleUpdates["AimbotFOV"] then ToggleUpdates["AimbotFOV"]() end
        elseif input.KeyCode == Config.UI.KeyToggleESP then
            Config.ESP.Enabled = not Config.ESP.Enabled
            if Config.ESP.Enabled then StartESP() else StopESP() end
            if ToggleUpdates["ESP"] then ToggleUpdates["ESP"]() end
        elseif input.KeyCode == Config.FreeCam.ToggleKey then ToggleFreeCam()
        elseif input.KeyCode == Config.Speed.WalkToggleKey then SetWalkEnabled(not Config.Speed.WalkEnabled)
        elseif input.KeyCode == Config.Speed.JumpToggleKey then SetJumpEnabled(not Config.Speed.JumpEnabled)
        elseif input.KeyCode == Config.Fly.FlyToggleKey then
            Config.Fly.FlyEnabled = not Config.Fly.FlyEnabled
            if Config.Fly.FlyEnabled then StartFly() else StopFly() end
            if ToggleUpdates["FlyEnabled"] then ToggleUpdates["FlyEnabled"]() end
        elseif input.KeyCode == Config.Fly.NoClipToggleKey then
            Config.Fly.NoClipEnabled = not Config.Fly.NoClipEnabled
            if Config.Fly.NoClipEnabled then StartNoClip() else StopNoClip() end
            if ToggleUpdates["NoClipEnabled"] then ToggleUpdates["NoClipEnabled"]() end
        elseif input.KeyCode == Config.Visual.FullBrightKey then SetFullBrightEnabled(not Config.Visual.FullBrightEnabled)
        elseif input.KeyCode == Config.UI.KeyToggleRadar then
            ToggleRadar()
        elseif input.KeyCode == Enum.KeyCode.Space then spaceHeld = true
        end
    end)
    inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Config.Aimbot.AimKey then
            holdingAimKey = false
        elseif input.KeyCode == Enum.KeyCode.Space then spaceHeld = false
        end
    end)
end

-- ====================== INICIALIZAÇÃO ======================
print("[FrostHub Ultra] Iniciando (Xeno compatível)...")
repeat task.wait() until LocalPlayer.Character
repeat task.wait() until workspace.CurrentCamera
CreateMenu()
SaveOriginalLighting()

fovUpdateConn = RunService.RenderStepped:Connect(UpdateFOVCircles)

Players.PlayerRemoving:Connect(function(p)
    cleanupPlayerESP(p)
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    if Config.Speed.WalkEnabled then local hum = char:FindFirstChild("Humanoid"); if hum then ApplyWalk(hum) end; if not walkLoop then SetWalkEnabled(true) end end
    if Config.Fly.FlyEnabled then StopFly(); StartFly() end
    if Config.Fly.NoClipEnabled then StopNoClip(); StartNoClip() end
    if Config.Aimbot.Enabled then StopAimbot(); StartAimbot() end
    if Config.ESP.Enabled then StopESP(); StartESP() end
    if Config.Radar.Enabled then 
        StopRadar() 
        StartRadar() 
    end
    if Config.FreeCam.Enabled and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.Anchored = true; freezedRootPart = root end
    end
end)

RunService.Heartbeat:Connect(function()
    if not Config.Speed.JumpEnabled or not spaceHeld then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Config.Speed.JumpForce, root.AssemblyLinearVelocity.Z)
end)

Players.PlayerRemoving:Connect(function()
    StopAimbot(); StopESP(); StopAutoFarm(); StopHitbox(); DisableFreeCam(); StopRadar()
    if walkLoop then walkLoop:Disconnect() end
    StopFly(); StopNoClip()
    if fullBrightLoop then fullBrightLoop:Disconnect() end
    if fovUpdateConn then fovUpdateConn:Disconnect() end
    CleanupMenu()
end)

print("[FrostHub Ultra] Carregado! ❄️ (Modo Xeno - sem Drawing)")
