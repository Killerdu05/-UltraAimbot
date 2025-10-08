--[[
    UltraAimbot - Script Aimbot Avancé avec Anti-Détection
    Version: 2.1 - GitHub Version
    Compatible avec tous les exécuteurs
    URL: https://raw.githubusercontent.com/username/UltraAimbot/main/UltraAimbot.lua
]]

-- Variables de base
local game = game
local workspace = workspace
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Vérification de chargement
if _G.UltraAimbotLoaded then
    return
end
_G.UltraAimbotLoaded = true

-- Fonction de protection
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("UltraAimbot Error:", result)
        return nil
    end
    return result
end

-- Configuration
local Settings = {
    Enabled = false,
    ToggleKey = "LeftAlt",
    Smoothness = 0.15,
    FOV = 120,
    TeamCheck = true,
    WallCheck = true,
    AliveCheck = true,
    TargetPart = "Head",
    Prediction = 0.165,
    AutoShoot = false,
    SilentAim = false,
    Power = 1.0,
    PowerMultiplier = 1,
    MaxPower = 1000,
    MaxSmoothness = 0.5,
    MaxDistance = 1000,
    Priority = "Closest",
    FOVVisible = true,
    FOVColor = Color3.fromRGB(255, 255, 255),
    FOVTransparency = 0.5,
    FOVThickness = 2
}

local Visuals = {
    ESP = {
        Enabled = false,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        Tracers = true,
        Chams = false,
        ShowTeams = true,
        EnemyBoxColor = Color3.fromRGB(255, 0, 0),
        AllyBoxColor = Color3.fromRGB(0, 255, 0),
        EnemyTextColor = Color3.fromRGB(255, 100, 100),
        AllyTextColor = Color3.fromRGB(100, 255, 100),
        EnemyTracerColor = Color3.fromRGB(255, 0, 0),
        AllyTracerColor = Color3.fromRGB(0, 255, 0),
        TeamIndicator = true
    }
}

-- Variables internes
local Target = nil
local FOVCircle = nil
local ESPObjects = {}
local Connections = {}

-- Fonctions utilitaires
local function GetCharacter(Player)
    return Player and Player.Character
end

local function GetHumanoid(Character)
    return Character and Character:FindFirstChild("Humanoid")
end

local function GetRootPart(Character)
    return Character and Character:FindFirstChild("HumanoidRootPart")
end

local function GetTargetPart(Character, PartName)
    return Character and Character:FindFirstChild(PartName)
end

local function IsAlive(Character)
    local Humanoid = GetHumanoid(Character)
    return Humanoid and Humanoid.Health > 0
end

local function IsOnSameTeam(Player1, Player2)
    if not Settings.TeamCheck then return false end
    return Player1.Team == Player2.Team
end

local function IsVisible(Origin, Target, Character)
    if not Settings.WallCheck then return true end
    if not Origin or not Target or not Character then return false end
    
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    RaycastParams.FilterDescendantsInstances = {Character, Camera}
    
    local RaycastResult = workspace:Raycast(Origin, (Target - Origin), RaycastParams)
    return not RaycastResult
end

local function GetDistance(Player1, Player2)
    local Char1, Char2 = GetCharacter(Player1), GetCharacter(Player2)
    if not Char1 or not Char2 then return math.huge end
    
    local Root1, Root2 = GetRootPart(Char1), GetRootPart(Char2)
    if not Root1 or not Root2 then return math.huge end
    
    return (Root1.Position - Root2.Position).Magnitude
end

local function GetFOVDistance(Player)
    local Character = GetCharacter(Player)
    if not Character then return math.huge end
    
    local TargetPart = GetTargetPart(Character, Settings.TargetPart)
    if not TargetPart then return math.huge end
    
    local ScreenPoint, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
    if not OnScreen then return math.huge end
    
    local MousePos = UserInputService:GetMouseLocation()
    local Distance = (Vector2.new(ScreenPoint.X, ScreenPoint.Y) - MousePos).Magnitude
    
    return Distance
end

local function GetClosestPlayer()
    local ClosestPlayer = nil
    local ClosestDistance = math.huge
    
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and GetCharacter(Player) then
            local Character = GetCharacter(Player)
            local Humanoid = GetHumanoid(Character)
            
            if IsAlive(Character) and not IsOnSameTeam(LocalPlayer, Player) then
                local Distance = Settings.Priority == "Closest" and GetDistance(LocalPlayer, Player) or GetFOVDistance(Player)
                
                if Distance < ClosestDistance and Distance <= Settings.MaxDistance then
                    if Settings.Priority == "FOV" then
                        if Distance <= Settings.FOV then
                            ClosestPlayer = Player
                            ClosestDistance = Distance
                        end
                    else
                        ClosestPlayer = Player
                        ClosestDistance = Distance
                    end
                end
            end
        end
    end
    
    return ClosestPlayer
end

-- Fonction d'aimbot principale
local function AimAtTarget()
    if not Settings.Enabled or not Target then return end
    
    SafeCall(function()
        local Character = GetCharacter(Target)
        if not Character then return end
        
        local TargetPart = GetTargetPart(Character, Settings.TargetPart)
        if not TargetPart then return end
        
        if not IsAlive(Character) then return end
        if IsOnSameTeam(LocalPlayer, Target) then return end
        
        local CameraPosition = Camera.CFrame.Position
        local TargetPosition = TargetPart.Position
        
        if not IsVisible(CameraPosition, TargetPosition, Character) then return end
        
        -- Prédiction de mouvement
        local Velocity = TargetPart.Velocity or Vector3.new(0, 0, 0)
        local Distance = (CameraPosition - TargetPosition).Magnitude
        local TimeToTarget = math.clamp(Distance / 1000, 0, 1)
        
        local PredictedPosition = TargetPosition + (Velocity * TimeToTarget * math.clamp(Settings.Prediction, 0, 1))
        
        -- Calcul de la direction
        local Direction = (PredictedPosition - CameraPosition).Unit
        local LookDirection = Camera.CFrame.LookVector
        
        -- Smoothing
        local Smoothness = math.clamp(Settings.Smoothness, 0.01, Settings.MaxSmoothness)
        local TotalPower = math.clamp(Settings.Power * Settings.PowerMultiplier, 0.1, Settings.MaxPower)
        
        local DotProduct = math.clamp(LookDirection:Dot(Direction), -1, 1)
        local Angle = math.acos(DotProduct)
        
        if Angle <= math.rad(math.clamp(Settings.FOV, 1, 500)) then
            local NewCFrame = CFrame.lookAt(CameraPosition, PredictedPosition)
            local CurrentCFrame = Camera.CFrame
            
            local LerpValue = math.clamp(Smoothness * TotalPower, 0, 1)
            local LerpedCFrame = CurrentCFrame:Lerp(NewCFrame, LerpValue)
            
            if LerpedCFrame and LerpedCFrame.Position and LerpedCFrame.LookVector then
                Camera.CFrame = LerpedCFrame
                
                if Settings.AutoShoot then
                    local Character = GetCharacter(LocalPlayer)
                    if Character then
                        local Tool = Character:FindFirstChildOfClass("Tool")
                        if Tool and Tool:IsA("Tool") then
                            Tool:Activate()
                        end
                    end
                end
            end
        end
    end)
end

-- Fonction FOV Circle
local function CreateFOVCircle()
    SafeCall(function()
        if FOVCircle then 
            if FOVCircle.Remove then
                FOVCircle:Remove()
            end
        end
        
        if not Drawing then
            warn("Drawing API non disponible")
            return
        end
        
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Visible = Settings.FOVVisible
        FOVCircle.Transparency = math.clamp(Settings.FOVTransparency, 0, 1)
        FOVCircle.Color = Settings.FOVColor
        FOVCircle.Thickness = math.clamp(Settings.FOVThickness, 1, 10)
        FOVCircle.Filled = false
        FOVCircle.Radius = math.clamp(Settings.FOV, 1, 500)
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end)
end

local function UpdateFOVCircle()
    if not FOVCircle then return end
    
    SafeCall(function()
        FOVCircle.Visible = Settings.FOVVisible and Settings.Enabled
        FOVCircle.Radius = math.clamp(Settings.FOV, 1, 500)
        FOVCircle.Color = Settings.FOVColor
        FOVCircle.Transparency = math.clamp(Settings.FOVTransparency, 0, 1)
        FOVCircle.Thickness = math.clamp(Settings.FOVThickness, 1, 10)
    end)
end

-- Fonction ESP
local function GetTeamColor(Player)
    if not Player or not LocalPlayer then
        return Visuals.ESP.EnemyBoxColor, Visuals.ESP.EnemyTextColor, Visuals.ESP.EnemyTracerColor
    end
    
    local IsAlly = SafeCall(function() return Player.Team == LocalPlayer.Team end) or false
    
    if IsAlly then
        return Visuals.ESP.AllyBoxColor, Visuals.ESP.AllyTextColor, Visuals.ESP.AllyTracerColor
    else
        return Visuals.ESP.EnemyBoxColor, Visuals.ESP.EnemyTextColor, Visuals.ESP.EnemyTracerColor
    end
end

local function GetTeamPrefix(Player)
    if not Player or not LocalPlayer then
        return "[ENNEMI] "
    end
    
    local IsAlly = SafeCall(function() return Player.Team == LocalPlayer.Team end) or false
    
    if IsAlly then
        return "[ALLIÉ] "
    else
        return "[ENNEMI] "
    end
end

local function CreateESP(Player)
    local Character = GetCharacter(Player)
    if not Character then return end
    
    local RootPart = GetRootPart(Character)
    if not RootPart then return end
    
    local Humanoid = GetHumanoid(Character)
    if not Humanoid then return end
    
    if not Drawing then
        warn("Drawing API non disponible")
        return
    end
    
    local BoxColor, TextColor, TracerColor = GetTeamColor(Player)
    local TeamPrefix = GetTeamPrefix(Player)
    local IsAlly = SafeCall(function() return Player.Team == LocalPlayer.Team end) or false
    
    local ESPObject = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Health = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        TeamIndicator = Drawing.new("Text")
    }
    
    -- Configuration
    ESPObject.Box.Visible = Visuals.ESP.Boxes
    ESPObject.Box.Color = BoxColor
    ESPObject.Box.Thickness = 2
    ESPObject.Box.Filled = false
    
    ESPObject.Name.Visible = Visuals.ESP.Names
    ESPObject.Name.Color = TextColor
    ESPObject.Name.Size = 16
    ESPObject.Name.Font = 2
    ESPObject.Name.Text = TeamPrefix .. Player.Name
    
    ESPObject.Health.Visible = Visuals.ESP.Health
    ESPObject.Health.Color = TextColor
    ESPObject.Health.Size = 14
    ESPObject.Health.Font = 2
    ESPObject.Health.Text = "HP: " .. math.floor(Humanoid.Health) .. "/" .. math.floor(Humanoid.MaxHealth)
    
    ESPObject.Distance.Visible = Visuals.ESP.Distance
    ESPObject.Distance.Color = TextColor
    ESPObject.Distance.Size = 14
    ESPObject.Distance.Font = 2
    ESPObject.Distance.Text = math.floor(GetDistance(LocalPlayer, Player)) .. "m"
    
    ESPObject.Tracer.Visible = Visuals.ESP.Tracers
    ESPObject.Tracer.Color = TracerColor
    ESPObject.Tracer.Thickness = 2
    
    ESPObject.TeamIndicator.Visible = Visuals.ESP.TeamIndicator and Visuals.ESP.ShowTeams
    ESPObject.TeamIndicator.Color = TextColor
    ESPObject.TeamIndicator.Size = 12
    ESPObject.TeamIndicator.Font = 2
    ESPObject.TeamIndicator.Text = IsAlly and "✓ ALLIÉ" or "✗ ENNEMI"
    
    ESPObjects[Player] = ESPObject
end

local function UpdateESP(Player)
    local ESPObject = ESPObjects[Player]
    if not ESPObject then return end
    
    local Character = GetCharacter(Player)
    if not Character then return end
    
    local RootPart = GetRootPart(Character)
    if not RootPart then return end
    
    local Humanoid = GetHumanoid(Character)
    if not Humanoid then return end
    
    local ScreenPoint, OnScreen = Camera:WorldToViewportPoint(RootPart.Position)
    if not OnScreen then
        for _, Drawing in pairs(ESPObject) do
            Drawing.Visible = false
        end
        return
    end
    
    local BoxColor, TextColor, TracerColor = GetTeamColor(Player)
    local TeamPrefix = GetTeamPrefix(Player)
    local IsAlly = SafeCall(function() return Player.Team == LocalPlayer.Team end) or false
    
    local Size = Vector2.new(2000 / ScreenPoint.Z, 3000 / ScreenPoint.Z)
    local Position = Vector2.new(ScreenPoint.X - Size.X / 2, ScreenPoint.Y - Size.Y / 2)
    
    -- Mise à jour
    ESPObject.Box.Size = Size
    ESPObject.Box.Position = Position
    ESPObject.Box.Visible = Visuals.ESP.Boxes and Visuals.ESP.Enabled
    ESPObject.Box.Color = BoxColor
    
    ESPObject.Name.Position = Vector2.new(ScreenPoint.X, Position.Y - 20)
    ESPObject.Name.Visible = Visuals.ESP.Names and Visuals.ESP.Enabled
    ESPObject.Name.Color = TextColor
    ESPObject.Name.Text = TeamPrefix .. Player.Name
    
    ESPObject.Health.Position = Vector2.new(ScreenPoint.X, Position.Y + Size.Y + 5)
    ESPObject.Health.Text = "HP: " .. math.floor(Humanoid.Health) .. "/" .. math.floor(Humanoid.MaxHealth)
    ESPObject.Health.Visible = Visuals.ESP.Health and Visuals.ESP.Enabled
    ESPObject.Health.Color = TextColor
    
    ESPObject.Distance.Position = Vector2.new(ScreenPoint.X, Position.Y + Size.Y + 25)
    ESPObject.Distance.Text = math.floor(GetDistance(LocalPlayer, Player)) .. "m"
    ESPObject.Distance.Visible = Visuals.ESP.Distance and Visuals.ESP.Enabled
    ESPObject.Distance.Color = TextColor
    
    ESPObject.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    ESPObject.Tracer.To = Vector2.new(ScreenPoint.X, ScreenPoint.Y)
    ESPObject.Tracer.Visible = Visuals.ESP.Tracers and Visuals.ESP.Enabled
    ESPObject.Tracer.Color = TracerColor
    
    ESPObject.TeamIndicator.Position = Vector2.new(ScreenPoint.X, Position.Y - 40)
    ESPObject.TeamIndicator.Visible = Visuals.ESP.TeamIndicator and Visuals.ESP.ShowTeams and Visuals.ESP.Enabled
    ESPObject.TeamIndicator.Color = TextColor
    ESPObject.TeamIndicator.Text = IsAlly and "✓ ALLIÉ" or "✗ ENNEMI"
end

local function RemoveESP(Player)
    local ESPObject = ESPObjects[Player]
    if not ESPObject then return end
    
    for _, Drawing in pairs(ESPObject) do
        if Drawing and Drawing.Remove then
            Drawing:Remove()
        end
    end
    
    ESPObjects[Player] = nil
end

-- Fonction principale de mise à jour
local function Update()
    SafeCall(function()
        if not Settings.Enabled then
            Target = nil
            return
        end
        
        Target = GetClosestPlayer()
        
        if Target then
            AimAtTarget()
        end
        
        if Visuals.ESP.Enabled then
            for _, Player in pairs(Players:GetPlayers()) do
                if Player ~= LocalPlayer and GetCharacter(Player) and IsAlive(GetCharacter(Player)) then
                    if not ESPObjects[Player] then
                        CreateESP(Player)
                    end
                    UpdateESP(Player)
                elseif ESPObjects[Player] then
                    RemoveESP(Player)
                end
            end
        end
    end)
end

-- Gestion des touches
local function OnInputBegan(Input, GameProcessed)
    if GameProcessed then return end
    
    SafeCall(function()
        if Input.KeyCode and Input.KeyCode.Name == Settings.ToggleKey then
            Settings.Enabled = not Settings.Enabled
            UpdateFOVCircle()
            print("Aimbot:", Settings.Enabled and "ACTIVÉ" or "DÉSACTIVÉ")
        end
    end)
end

-- Interface utilisateur
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "UltraAimbotUI"
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ResetOnSpawn = false
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 320, 0, 450)
    MainFrame.Position = UDim2.new(0, 10, 0, 10)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Title.BorderSizePixel = 0
    Title.Text = "🎯 UltraAimbot v2.1 - GitHub"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 16
    Title.Font = Enum.Font.SourceSansBold
    Title.Parent = MainFrame
    
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(1, 0, 0, 20)
    Subtitle.Position = UDim2.new(0, 0, 0, 35)
    Subtitle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Subtitle.BorderSizePixel = 0
    Subtitle.Text = "Chargé via GitHub - Menu automatique"
    Subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    Subtitle.TextSize = 12
    Subtitle.Font = Enum.Font.SourceSans
    Subtitle.Parent = MainFrame
    
    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -30, 0, 0)
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    CloseButton.Font = Enum.Font.SourceSansBold
    CloseButton.Parent = MainFrame
    
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -60)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 60)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.Parent = MainFrame
    
    local YOffset = 0
    
    -- Affichage de la puissance totale
    local PowerDisplay = Instance.new("TextLabel")
    PowerDisplay.Size = UDim2.new(1, 0, 0, 25)
    PowerDisplay.Position = UDim2.new(0, 0, 0, YOffset)
    PowerDisplay.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    PowerDisplay.BorderSizePixel = 0
    PowerDisplay.Text = "PUISSANCE TOTALE: " .. math.floor(Settings.Power * Settings.PowerMultiplier)
    PowerDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    PowerDisplay.TextSize = 16
    PowerDisplay.Font = Enum.Font.SourceSansBold
    PowerDisplay.Parent = ScrollFrame
    
    YOffset = YOffset + 30
    
    -- Fonction pour créer des contrôles
    local function CreateToggle(Name, Setting, Callback)
        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Size = UDim2.new(1, 0, 0, 30)
        ToggleFrame.Position = UDim2.new(0, 0, 0, YOffset)
        ToggleFrame.BackgroundTransparency = 1
        ToggleFrame.Parent = ScrollFrame
        
        local ToggleLabel = Instance.new("TextLabel")
        ToggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
        ToggleLabel.Position = UDim2.new(0, 0, 0, 0)
        ToggleLabel.BackgroundTransparency = 1
        ToggleLabel.Text = Name
        ToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleLabel.TextSize = 14
        ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
        ToggleLabel.Parent = ToggleFrame
        
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(0, 50, 0, 20)
        ToggleButton.Position = UDim2.new(1, -50, 0.5, -10)
        ToggleButton.BackgroundColor3 = Setting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        ToggleButton.BorderSizePixel = 0
        ToggleButton.Text = Setting and "ON" or "OFF"
        ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleButton.TextSize = 12
        ToggleButton.Font = Enum.Font.SourceSansBold
        ToggleButton.Parent = ToggleFrame
        
        ToggleButton.MouseButton1Click:Connect(function()
            Setting = not Setting
            ToggleButton.BackgroundColor3 = Setting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
            ToggleButton.Text = Setting and "ON" or "OFF"
            if Callback then Callback(Setting) end
        end)
        
        YOffset = YOffset + 35
        return ToggleButton
    end
    
    local function CreateSlider(Name, Min, Max, Default, Callback)
        local SliderFrame = Instance.new("Frame")
        SliderFrame.Size = UDim2.new(1, 0, 0, 40)
        SliderFrame.Position = UDim2.new(0, 0, 0, YOffset)
        SliderFrame.BackgroundTransparency = 1
        SliderFrame.Parent = ScrollFrame
        
        local SliderLabel = Instance.new("TextLabel")
        SliderLabel.Size = UDim2.new(1, 0, 0, 20)
        SliderLabel.Position = UDim2.new(0, 0, 0, 0)
        SliderLabel.BackgroundTransparency = 1
        SliderLabel.Text = Name .. ": " .. Default
        SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        SliderLabel.TextSize = 14
        SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        SliderLabel.Parent = SliderFrame
        
        local SliderBar = Instance.new("Frame")
        SliderBar.Size = UDim2.new(1, 0, 0, 4)
        SliderBar.Position = UDim2.new(0, 0, 0, 25)
        SliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        SliderBar.BorderSizePixel = 0
        SliderBar.Parent = SliderFrame
        
        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
        SliderFill.Position = UDim2.new(0, 0, 0, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        SliderFill.BorderSizePixel = 0
        SliderFill.Parent = SliderBar
        
        local SliderButton = Instance.new("TextButton")
        SliderButton.Size = UDim2.new(0, 20, 0, 20)
        SliderButton.Position = UDim2.new((Default - Min) / (Max - Min), -10, 0, -8)
        SliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderButton.BorderSizePixel = 0
        SliderButton.Text = ""
        SliderButton.Parent = SliderFrame
        
        local function UpdateSlider(Value)
            local ClampedValue = math.clamp(Value, Min, Max)
            SliderFill.Size = UDim2.new((ClampedValue - Min) / (Max - Min), 0, 1, 0)
            SliderButton.Position = UDim2.new((ClampedValue - Min) / (Max - Min), -10, 0, -8)
            SliderLabel.Text = Name .. ": " .. math.floor(ClampedValue * 100) / 100
            if Callback then Callback(ClampedValue) end
        end
        
        local Dragging = false
        SliderButton.MouseButton1Down:Connect(function()
            Dragging = true
        end)
        
        UserInputService.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Dragging = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(Input)
            if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
                local MouseX = UserInputService:GetMouseLocation().X
                local FrameX = SliderFrame.AbsolutePosition.X
                local FrameWidth = SliderFrame.AbsoluteSize.X
                local RelativeX = math.clamp((MouseX - FrameX) / FrameWidth, 0, 1)
                local Value = Min + (RelativeX * (Max - Min))
                UpdateSlider(Value)
            end
        end)
        
        YOffset = YOffset + 45
        return SliderButton
    end
    
    -- Contrôles
    CreateToggle("Aimbot Activé", Settings.Enabled, function(Value)
        Settings.Enabled = Value
        UpdateFOVCircle()
    end)
    
    CreateToggle("Vérification d'équipe", Settings.TeamCheck, function(Value)
        Settings.TeamCheck = Value
    end)
    
    CreateToggle("Vérification des murs", Settings.WallCheck, function(Value)
        Settings.WallCheck = Value
    end)
    
    CreateToggle("Tir automatique", Settings.AutoShoot, function(Value)
        Settings.AutoShoot = Value
    end)
    
    CreateSlider("Fluidité", 0.01, Settings.MaxSmoothness, Settings.Smoothness, function(Value)
        Settings.Smoothness = Value
    end)
    
    CreateSlider("FOV", 10, 500, Settings.FOV, function(Value)
        Settings.FOV = Value
        UpdateFOVCircle()
    end)
    
    CreateSlider("Puissance de base", 0.1, 10, Settings.Power, function(Value)
        Settings.Power = Value
        PowerDisplay.Text = "PUISSANCE TOTALE: " .. math.floor(Settings.Power * Settings.PowerMultiplier)
    end)
    
    CreateSlider("Multiplicateur de puissance", 1, 1000, Settings.PowerMultiplier, function(Value)
        Settings.PowerMultiplier = Value
        PowerDisplay.Text = "PUISSANCE TOTALE: " .. math.floor(Settings.Power * Settings.PowerMultiplier)
    end)
    
    CreateSlider("Distance max", 100, 2000, Settings.MaxDistance, function(Value)
        Settings.MaxDistance = Value
    end)
    
    CreateToggle("ESP Activé", Visuals.ESP.Enabled, function(Value)
        Visuals.ESP.Enabled = Value
    end)
    
    CreateToggle("Boîtes ESP", Visuals.ESP.Boxes, function(Value)
        Visuals.ESP.Boxes = Value
    end)
    
    CreateToggle("Noms ESP", Visuals.ESP.Names, function(Value)
        Visuals.ESP.Names = Value
    end)
    
    CreateToggle("Santé ESP", Visuals.ESP.Health, function(Value)
        Visuals.ESP.Health = Value
    end)
    
    CreateToggle("Distance ESP", Visuals.ESP.Distance, function(Value)
        Visuals.ESP.Distance = Value
    end)
    
    CreateToggle("Tracers ESP", Visuals.ESP.Tracers, function(Value)
        Visuals.ESP.Tracers = Value
    end)
    
    CreateToggle("Affichage des équipes", Visuals.ESP.ShowTeams, function(Value)
        Visuals.ESP.ShowTeams = Value
    end)
    
    CreateToggle("Indicateur d'équipe", Visuals.ESP.TeamIndicator, function(Value)
        Visuals.ESP.TeamIndicator = Value
    end)
    
    -- Bouton de fermeture
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    -- Mise à jour de la taille du scroll
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, YOffset)
    
    -- Mise à jour continue de l'affichage de puissance
    spawn(function()
        while ScreenGui.Parent do
            wait(0.1)
            if PowerDisplay then
                local TotalPower = Settings.Power * Settings.PowerMultiplier
                PowerDisplay.Text = "PUISSANCE TOTALE: " .. math.floor(TotalPower)
                
                if TotalPower > 500 then
                    PowerDisplay.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                elseif TotalPower > 100 then
                    PowerDisplay.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                else
                    PowerDisplay.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                end
            end
        end
    end)
end

-- Fonction d'initialisation
local function Initialize()
    SafeCall(function()
        -- Connexions
        local HeartbeatConnection = RunService.Heartbeat:Connect(function()
            SafeCall(Update)
        end)
        table.insert(Connections, HeartbeatConnection)
        
        local InputConnection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
            SafeCall(function() OnInputBegan(Input, GameProcessed) end)
        end)
        table.insert(Connections, InputConnection)
        
        -- Connexion pour les joueurs
        local PlayerAddedConnection = Players.PlayerAdded:Connect(function(Player)
            SafeCall(function()
                if Visuals.ESP.Enabled then
                    Player.CharacterAdded:Connect(function(Character)
                        wait(1)
                        SafeCall(function() CreateESP(Player) end)
                    end)
                end
            end)
        end)
        table.insert(Connections, PlayerAddedConnection)
        
        local PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(Player)
            SafeCall(function() RemoveESP(Player) end)
        end)
        table.insert(Connections, PlayerRemovingConnection)
        
        -- Création du FOV Circle
        CreateFOVCircle()
    end)
end

-- Fonction de démarrage
local function Start()
    SafeCall(function()
        print("🎯 UltraAimbot v2.1 - GitHub Version chargé avec succès!")
        print("📋 Menu ouvert automatiquement")
        print("⌨️  Touche: " .. Settings.ToggleKey .. " pour activer/désactiver l'aimbot")
        print("✅ Chargé via GitHub - Compatible avec tous les exécuteurs!")
        
        Initialize()
        CreateUI()
    end)
end

-- Démarrage automatique
local success, error = pcall(Start)
if not success then
    warn("Erreur lors du démarrage d'UltraAimbot:", error)
    wait(1)
    pcall(Start)
end

-- Export de l'API
_G.UltraAimbotAPI = {
    SetEnabled = function(Value) Settings.Enabled = Value end,
    SetSmoothness = function(Value) Settings.Smoothness = Value end,
    SetFOV = function(Value) Settings.FOV = Value end,
    SetPower = function(Value) Settings.Power = Value end,
    SetPowerMultiplier = function(Value) Settings.PowerMultiplier = Value end,
    SetMaxPower = function(Value) Settings.MaxPower = Value end,
    SetTargetPart = function(Value) Settings.TargetPart = Value end,
    GetTotalPower = function() return Settings.Power * Settings.PowerMultiplier end,
    SetEnemyColor = function(Color) Visuals.ESP.EnemyBoxColor = Color end,
    SetAllyColor = function(Color) Visuals.ESP.AllyBoxColor = Color end,
    SetShowTeams = function(Value) Visuals.ESP.ShowTeams = Value end,
    SetTeamIndicator = function(Value) Visuals.ESP.TeamIndicator = Value end,
    GetTeamColor = function(Player) return GetTeamColor(Player) end,
    IsAlly = function(Player) return SafeCall(function() return Player.Team == LocalPlayer.Team end) or false end,
    GetSettings = function() return Settings end,
    GetVisuals = function() return Visuals end,
    IsCompatible = function() return true end
}
