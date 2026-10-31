if not game:GetService("RunService"):IsClient() then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- SETTINGS (Cố định các cấu hình tối ưu nhất, chỉ để Enabled điều khiển bằng nút)
local Settings = {
    Enabled = false,
    Mode = "Aimlock",
    TargetMode = "NPC",
    AimPartMode = "Auto",
    BulletSpeed = 300,
    PredictionStrength = 1,
    GravityEnabled = false,
    GravityStrength = 196.2,
    AimRadius = 150,
    ShowRadius = true,
    WallCheck = true,
    WallCheckStrength = "High",
    AimbotSmoothing = 0.3,
    AntiLag = true,
    StrongAntiLag = true,
}

-- UI (Đã xóa toàn bộ phần Settings Panel và Settings Button)
local Gui = Instance.new("ScreenGui", game.CoreGui)
Gui.Name = "AimSystemGui"
Gui.ResetOnSpawn = false

local function createDraggableButton(name, size, position, text)
    local frame = Instance.new("Frame", Gui)
    frame.Name = name
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
    frame.BorderSizePixel = 0
    frame.Active = true
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0,12)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    local moved = false
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
            moved = false
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                moved = true
            end
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input == dragInput then
            dragging = false
            if not moved then
                frame:FindFirstChild("ClickEvent"):Fire()
            end
        end
    end)
    local clickEvent = Instance.new("BindableEvent")
    clickEvent.Name = "ClickEvent"
    clickEvent.Parent = frame
    return frame, label, clickEvent
end

-- Chỉ tạo duy nhất một nút bấm Bật/Tắt AIM
local MainFrame, MainLabel, MainClick = createDraggableButton("MainButton", UDim2.new(0,120,0,45), UDim2.new(0.05,0,0.5,0), "AIM: OFF")

local RadiusCircle = Drawing.new("Circle")
RadiusCircle.Visible = Settings.ShowRadius
RadiusCircle.Filled = false
RadiusCircle.Thickness = 2
RadiusCircle.Transparency = 1
RadiusCircle.Color = Color3.fromRGB(0,170,255)
RadiusCircle.NumSides = 100

MainClick.Event:Connect(function()
    Settings.Enabled = not Settings.Enabled
    MainLabel.Text = Settings.Enabled and "AIM: ON" or "AIM: OFF"
end)

local function isNPC(model)
    return model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(model)
end

local function isPlayer(model)
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local function isValidTarget(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if not character:FindFirstChild("HumanoidRootPart") and not character:FindFirstChild("Torso") and not character:FindFirstChild("Head") then
        return false
    end
    return true
end

local function isInViewport(part)
    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    return onScreen
end

local function isInRadius(part)
    local centerPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if onScreen then
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - centerPos).Magnitude
        return dist <= Settings.AimRadius
    end
    return false
end

local function getTargetsInViewport()
    local targets = {}
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and isValidTarget(model) then
            local inView = false
            local aimParts = {}
            if model:FindFirstChild("Head") then table.insert(aimParts, model.Head) end
            if model:FindFirstChild("HumanoidRootPart") then table.insert(aimParts, model.HumanoidRootPart) end
            if model:FindFirstChild("Torso") then table.insert(aimParts, model.Torso) end
            if model:FindFirstChild("UpperTorso") then table.insert(aimParts, model.UpperTorso) end
            if model:FindFirstChild("LowerTorso") then table.insert(aimParts, model.LowerTorso) end
            
            for _, part in ipairs(aimParts) do
                if isInViewport(part) then
                    inView = true
                    break
                end
            end
            
            if inView then
                if Settings.TargetMode == "NPC" and isNPC(model) then
                    table.insert(targets, model)
                elseif Settings.TargetMode == "Player" and isPlayer(model) and model ~= LocalPlayer.Character then
                    table.insert(targets, model)
                elseif Settings.TargetMode == "All" and (isNPC(model) or (isPlayer(model) and model ~= LocalPlayer.Character)) then
                    table.insert(targets, model)
                end
            end
        end
    end
    return targets
end

local function getValidTargetsInRadius()
    local targets = {}
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and isValidTarget(model) then
            local hasPartInRadius = false
            local aimParts = {}
            if model:FindFirstChild("Head") then table.insert(aimParts, model.Head) end
            if model:FindFirstChild("HumanoidRootPart") then table.insert(aimParts, model.HumanoidRootPart) end
            if model:FindFirstChild("Torso") then table.insert(aimParts, model.Torso) end
            if model:FindFirstChild("UpperTorso") then table.insert(aimParts, model.UpperTorso) end
            if model:FindFirstChild("LowerTorso") then table.insert(aimParts, model.LowerTorso) end
            
            for _, part in ipairs(aimParts) do
                if isInRadius(part) then
                    hasPartInRadius = true
                    break
                end
            end
            
            if hasPartInRadius then
                if Settings.TargetMode == "NPC" and isNPC(model) then
                    table.insert(targets, model)
                elseif Settings.TargetMode == "Player" and isPlayer(model) and model ~= LocalPlayer.Character then
                    table.insert(targets, model)
                elseif Settings.TargetMode == "All" and (isNPC(model) or (isPlayer(model) and model ~= LocalPlayer.Character)) then
                    table.insert(targets, model)
                end
            end
        end
    end
    return targets
end

local function getAimParts(character)
    local parts = {}
    
    if Settings.AimPartMode == "Auto" then
        if character:FindFirstChild("Head") then table.insert(parts, character.Head) end
        if character:FindFirstChild("HumanoidRootPart") then table.insert(parts, character.HumanoidRootPart) end
        if character:FindFirstChild("Torso") then table.insert(parts, character.Torso) end
        if character:FindFirstChild("UpperTorso") then table.insert(parts, character.UpperTorso) end
        if character:FindFirstChild("LowerTorso") then table.insert(parts, character.LowerTorso) end
    elseif Settings.AimPartMode == "Torso" then
        if character:FindFirstChild("HumanoidRootPart") then table.insert(parts, character.HumanoidRootPart) end
        if character:FindFirstChild("Torso") then table.insert(parts, character.Torso) end
        if character:FindFirstChild("UpperTorso") then table.insert(parts, character.UpperTorso) end
        if character:FindFirstChild("LowerTorso") then table.insert(parts, character.LowerTorso) end
    elseif Settings.AimPartMode == "Head" then
        if character:FindFirstChild("Head") then table.insert(parts, character.Head) end
    end
    
    return parts
end

local function enhancedWallCheck(origin, targetPart)
    if not Settings.WallCheck then return true end
    local targetPos = targetPart.Position
    local direction = (targetPos - origin).Unit
    local distance = (targetPos - origin).Magnitude
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    if Settings.WallCheckStrength == "High" then
        local checkPoints = {
            targetPos,
            targetPos + Vector3.new(0.5, 0.5, 0),
            targetPos + Vector3.new(-0.5, 0.5, 0),
            targetPos + Vector3.new(0.5, -0.5, 0),
            targetPos + Vector3.new(-0.5, -0.5, 0),
        }
        local hitCount = 0
        for _, point in ipairs(checkPoints) do
            local result = workspace:Raycast(origin, (point - origin), params)
            if result and result.Instance and not result.Instance:IsDescendantOf(targetPart.Parent) then
                hitCount = hitCount + 1
            end
        end
        return hitCount <= 2
    else
        local offsetDirection = direction + Vector3.new(0, 0.3, 0)
        local result = workspace:Raycast(origin, offsetDirection * distance, params)
        if result and result.Instance and not result.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
        return true
    end
end

local function predictPosition(part)
    local velocity = part.AssemblyLinearVelocity
    local distance = (Camera.CFrame.Position - part.Position).Magnitude
    local travelTime = distance / Settings.BulletSpeed
    local predictedPos = part.Position + (velocity * travelTime * Settings.PredictionStrength)
    if Settings.GravityEnabled then
        local drop = 0.5 * Settings.GravityStrength * (travelTime * travelTime)
        predictedPos = Vector3.new(predictedPos.X, predictedPos.Y + drop, predictedPos.Z)
    end
    return predictedPos
end

local currentTarget = nil
local scanFrames = 0 

local function getClosestToCenterTarget()
    local centerPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    if currentTarget and currentTarget.Parent and isValidTarget(currentTarget.Parent) then
        local screenPos, onScreen = Camera:WorldToViewportPoint(currentTarget.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - centerPos).Magnitude
            if dist <= Settings.AimRadius and enhancedWallCheck(Camera.CFrame.Position, currentTarget) then
                return currentTarget
            end
        end
    end
    
    currentTarget = nil
    local closestPart = nil
    local closestDist = Settings.AimRadius
    
    local targets
    if Settings.StrongAntiLag then
        scanFrames = scanFrames + 1
        if scanFrames % 3 == 0 then 
            targets = getTargetsInViewport()
        else
            targets = {}
        end
    elseif Settings.AntiLag then
        targets = getValidTargetsInRadius()
    else
        targets = getValidTargetsAll()
    end
    
    for _, character in ipairs(targets) do
        for _, part in ipairs(getAimParts(character)) do
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - centerPos).Magnitude
                if dist < closestDist and enhancedWallCheck(Camera.CFrame.Position, part) then
                    closestDist = dist
                    closestPart = part
                end
            end
        end
    end
    
    currentTarget = closestPart
    return closestPart
end

local function aimAt(position)
    if Settings.Mode == "Aimlock" then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, position)
    else
        local smoothFactor = 1 - Settings.AimbotSmoothing
        if smoothFactor <= 0.01 then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, position)
        else
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, position), smoothFactor)
        end
    end
end

RunService.RenderStepped:Connect(function()
    RadiusCircle.Visible = Settings.ShowRadius
    RadiusCircle.Radius = Settings.AimRadius
    RadiusCircle.Position = UserInputService:GetMouseLocation()
    
    if not Settings.Enabled then
        currentTarget = nil
        return
    end
    
    local targetPart = getClosestToCenterTarget()
    if targetPart then
        local character = targetPart.Parent
        if isValidTarget(character) then
            if enhancedWallCheck(Camera.CFrame.Position, targetPart) then
                local aimPos = predictPosition(targetPart)
                aimAt(aimPos)
            end
        else
            currentTarget = nil
        end
    else
        currentTarget = nil
    end
end)
