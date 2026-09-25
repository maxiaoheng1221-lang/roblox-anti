-- 轻量绕过版 ESP | 圣奥里适配 | 全图透视 | 强化绕过
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = true,
    ShowName = true,
    ShowJob = true,
    ShowDistance = true,
    MaxDistance = 0,          -- 0 = 不限制（内部用大数值重设，防反作弊改回）
    UpdateRate = 0.15,
    TeamCheck = false,
}

-- 圣奥里职业配色
local JobColors = {
    ["警察"] = Color3.fromRGB(0, 100, 255),
    ["医生"] = Color3.fromRGB(0, 200, 0),
    ["消防员"] = Color3.fromRGB(255, 50, 0),
    ["军人"] = Color3.fromRGB(50, 150, 50),
    ["黑帮"] = Color3.fromRGB(150, 0, 150),
    ["平民"] = Color3.fromRGB(200, 200, 200),
    ["银行家"] = Color3.fromRGB(0, 200, 200),
    ["市长"] = Color3.fromRGB(255, 200, 0),
    ["囚犯"] = Color3.fromRGB(255, 150, 0),
    ["狱警"] = Color3.fromRGB(0, 150, 255),
}

-- ===== 强化绕过：用 getgenv 存状态，减少本地表名特征 =====
local _G = (getgenv and getgenv()) or _G
local ESPList = _G.__esp_cache or {}
_G.__esp_cache = ESPList
local random = Random.new()

-- ==============================
-- 【核心绕过 元表速度劫持 — 扩展版】
-- 追加更多反作弊常扫属性的静默返回
-- ==============================
pcall(function()
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    setreadonly(mt, false)

    -- 本地玩家角色的白名单：只对本地角色的敏感属性做伪装，
    -- 不影响其他玩家，降低被服务器脚本比对的概率
    local localChar = nil
    local function isLocalChar(inst)
        if not inst then return false end
        local model = inst:IsA("Model") and inst or inst.Parent
        return model and model == LocalPlayer.Character
    end

    mt.__index = newcclosure(function(self, key)
        if (key == "AssemblyLinearVelocity"
            or key == "AssemblyAngularVelocity"
            or key == "Velocity"
            or key == "RotVelocity"
            or key == "Position")
            and self:IsA("BasePart")
            and self.Parent
            and self.Parent:IsA("Model")
            and self.Parent:FindFirstChildOfClass("Humanoid")
            and not isLocalChar(self) then
            -- 对其他玩家角色的物理属性返回"静止"伪装值
            -- 对本地玩家角色不干预，避免自己瞬移/卡死
            if key == "Position" then
                return self.Position  -- Position 不能伪装，否则UI全乱；仅速度类伪装
            end
            return Vector3.new()
        end
        return oldIndex(self, key)
    end)

    setreadonly(mt, true)
end)

-- 随机对象名 规避关键词扫描
local function randName()
    local s = ""
    local c = "abcdefghijklmnopqrstuvwxyz0123456789"
    for i=1, random:NextInteger(10, 16) do  -- 长度随机，更难匹配固定模式
        s ..= c:sub(random:NextInteger(1,#c), random:NextInteger(1,#c))
    end
    return s
end

local function GetJob(p)
    return p.Team and p.Team.Name or "平民"
end

local function GetJobColor(job)
    return JobColors[job] or Color3.fromRGB(200,200,200)
end

-- 创建ESP
local function CreateESP(p)
    if p == LocalPlayer or ESPList[p.UserId] then return end
    local char = p.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = randName()
    bill.Adornee = head
    bill.Size = UDim2.new(0, 260, 0, 65)
    bill.StudsOffset = Vector3.new(0, 2.8, 0)
    bill.AlwaysOnTop = true
    -- 【关键修复】用超大数值代替 0，防止游戏/反作弊把 0 当作默认距离(~200)做裁剪
    bill.MaxDistance = 1e9
    bill.Enabled = Config.Enabled
    bill.ResetOnSpawn = false
    bill.Parent = head

    local nameLab = Instance.new("TextLabel")
    nameLab.Size = UDim2.new(1,0,0,26)
    nameLab.Position = UDim2.new(0,0,0,0)
    nameLab.BackgroundTransparency = 1
    nameLab.Text = p.Name
    nameLab.TextColor3 = p.Team and p.Team.TeamColor.Color or Color3.new(1,1,1)
    nameLab.TextSize = 17
    nameLab.Font = Enum.Font.GothamBold
    nameLab.TextXAlignment = Enum.TextXAlignment.Center
    nameLab.Visible = Config.ShowName
    nameLab.Parent = bill

    local jobLab = Instance.new("TextLabel")
    jobLab.Size = UDim2.new(1,0,0,20)
    jobLab.Position = UDim2.new(0,0,26,0)
    jobLab.BackgroundTransparency = 1
    jobLab.Text = GetJob(p)
    jobLab.TextColor3 = GetJobColor(GetJob(p))
    jobLab.TextSize = 14
    jobLab.Font = Enum.Font.GothamBold
    jobLab.TextXAlignment = Enum.TextXAlignment.Center
    jobLab.Visible = Config.ShowJob
    jobLab.Parent = bill

    local distLab = Instance.new("TextLabel")
    distLab.Size = UDim2.new(1,0,0,18)
    distLab.Position = UDim2.new(0,0,46,0)
    distLab.BackgroundTransparency = 1
    distLab.Text = ""
    distLab.TextColor3 = Color3.new(1,1,0)
    distLab.TextSize = 13
    distLab.TextXAlignment = Enum.TextXAlignment.Center
    distLab.Visible = Config.ShowDistance
    distLab.Parent = bill

    if Config.TeamCheck and p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
        bill.Enabled = false
    end

    ESPList[p.UserId] = {
        Billboard = bill,
        NameLabel = nameLab,
        JobLabel = jobLab,
        DistLabel = distLab,
        Player = p,
    }
end

local function RemoveESP(userId)
    if ESPList[userId] then
        if ESPList[userId].Billboard then
            pcall(function() ESPList[userId].Billboard:Destroy() end)
        end
        ESPList[userId] = nil
    end
end

-- ==============================================
-- 【主循环】降频 + 随机抖动 + 属性重入（防反作弊篡改）
-- ==============================================
task.spawn(newcclosure(function()
    while true do
        -- 随机抖动：0.12 ~ 0.20 之间，避免固定节奏被识别
        task.wait(Config.UpdateRate * (0.8 + random:NextNumber() * 0.4))

        -- 清理失效ESP
        for userId, data in pairs(ESPList) do
            if not data.Billboard or not data.Billboard.Parent then
                RemoveESP(userId)
            end
        end

        if not Config.Enabled then continue end

        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then continue end

        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if not p.Character then continue end

            if not ESPList[p.UserId] then
                pcall(CreateESP, p)
            end

            local entry = ESPList[p.UserId]
            if not entry or not entry.Billboard then continue end

            -- 【关键】每帧重设 Billboard 关键属性，覆盖反作弊的篡改
            -- 反作弊常做：把 MaxDistance 改小、AlwaysOnTop 改 false、Enabled 改 false
            entry.Billboard.MaxDistance = 1e9
            entry.Billboard.AlwaysOnTop = true

            -- 更新距离
            local head = p.Character:FindFirstChild("Head")
            if head and Config.ShowDistance then
                local dist = (head.Position - myRoot.Position).Magnitude
                entry.DistLabel.Text = "["..math.floor(dist).."]"
            end

            -- 实时队友屏蔽
            local isTeam = p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team
            if Config.TeamCheck and isTeam then
                entry.Billboard.Enabled = false
            else
                entry.Billboard.Enabled = Config.Enabled
            end
        end
    end
end))

Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p.UserId)
end)

-- ==============================================
-- 【UI】优先挂到 gethui() 隐藏容器，绕 PlayerGui 扫描
-- 回退到 PlayerGui（无 gethui 环境）
-- ==============================================
local function getUIParent()
    -- gethui() 返回核心UI层容器，普通反作弊遍历 PlayerGui 找不到
    local ok, container = pcall(function()
        return gethui and gethui() or PlayerGui
    end)
    if ok and container then return container end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local UIRoot = getUIParent()

local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = randName()
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- 隐藏 GUI 不被 GetGuiObjects() / CoreGui 遍历轻易定位
pcall(function()
    ESPGui.DisplayOrder = 99999
end)
ESPGui.Parent = UIRoot

-- 主面板
local MainFrame = Instance.new("Frame")
MainFrame.Name = "Panel"
MainFrame.Position = UDim2.new(0, 25, 0.28, 0)
MainFrame.Size = UDim2.new(0, 220, 0, 340)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
MainFrame.BackgroundTransparency = 0.15
MainFrame.ClipsDescendants = false
MainFrame.Active = true
MainFrame.Parent = ESPGui

local MainScale = Instance.new("UIScale")
MainScale.Scale = 1
MainScale.Parent = MainFrame

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MainFrame

local Border = Instance.new("UIStroke")
Border.Color = Color3.fromRGB(80, 130, 255)
Border.Thickness = 1
Border.Transparency = 0.3
Border.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 48)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "圣奥里透视助手"
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.TextSize = 19
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = MainFrame

local TitleLine = Instance.new("Frame")
TitleLine.Size = UDim2.new(0.8, 0, 0, 1)
TitleLine.Position = UDim2.new(0.1, 0, 0, 48)
TitleLine.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
TitleLine.BackgroundTransparency = 0.4
TitleLine.Parent = MainFrame

local SwitchContainer = Instance.new("Frame")
SwitchContainer.Name = "Switches"
SwitchContainer.Size = UDim2.new(1, -24, 0, 190)
SwitchContainer.Position = UDim2.new(0, 12, 0, 60)
SwitchContainer.BackgroundTransparency = 1
SwitchContainer.Parent = MainFrame

local function CreateSwitch(index, text, configKey, callback)
    local yOffset = (index - 1) * 38

    local Item = Instance.new("Frame")
    Item.Size = UDim2.new(1, 0, 0, 32)
    Item.Position = UDim2.new(0, 0, 0, yOffset)
    Item.BackgroundTransparency = 1
    Item.Parent = SwitchContainer

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.7, 0, 1, 0)
    Label.Position = UDim2.new(0, 2, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(220, 225, 235)
    Label.TextSize = 14
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Item

    local SwitchBg = Instance.new("Frame")
    SwitchBg.Name = "Bg"
    SwitchBg.Size = UDim2.new(0, 44, 0, 24)
    SwitchBg.Position = UDim2.new(1, -44, 0.5, -12)
    SwitchBg.BackgroundColor3 = Config[configKey] and Color3.fromRGB(70, 130, 255) or Color3.fromRGB(60, 65, 75)
    SwitchBg.Parent = Item

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(0, 12)
    SwitchCorner.Parent = SwitchBg

    local Dot = Instance.new("Frame")
    Dot.Name = "Dot"
    Dot.Size = UDim2.new(0, 18, 0, 18)
    Dot.Position = Config[configKey] and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Dot.BackgroundTransparency = 0.05
    Dot.Parent = SwitchBg

    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(0, 9)
    DotCorner.Parent = Dot

    local ClickBtn = Instance.new("TextButton")
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.ZIndex = 10
    ClickBtn.Parent = SwitchBg

    ClickBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        local value = Config[configKey]
        SwitchBg.BackgroundColor3 = value and Color3.fromRGB(70, 130, 255) or Color3.fromRGB(60, 65, 75)
        Dot.Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        if callback then callback(value) end
    end)
end

CreateSwitch(1, "启用透视", "Enabled", function(value)
    for userId, data in pairs(ESPList) do
        if data.Billboard and data.Billboard.Parent then
            if Config.TeamCheck and data.Player.Team and LocalPlayer.Team and data.Player.Team == LocalPlayer.Team then
                data.Billboard.Enabled = false
            else
                data.Billboard.Enabled = value
            end
        end
    end
end)

CreateSwitch(2, "显示玩家名字", "ShowName", function(value)
    for _, data in pairs(ESPList) do
        if data.NameLabel then data.NameLabel.Visible = value end
    end
end)

CreateSwitch(3, "显示职业", "ShowJob", function(value)
    for _, data in pairs(ESPList) do
        if data.JobLabel then data.JobLabel.Visible = value end
    end
end)

CreateSwitch(4, "显示距离", "ShowDistance", function(value)
    for _, data in pairs(ESPList) do
        if data.DistLabel then data.DistLabel.Visible = value end
    end
end)

CreateSwitch(5, "屏蔽队友", "TeamCheck", function(value)
    for userId, data in pairs(ESPList) do
        if not data.Billboard or not data.Billboard.Parent then continue end
        local isTeam = data.Player.Team and LocalPlayer.Team and data.Player.Team == LocalPlayer.Team
        if value and isTeam then
            data.Billboard.Enabled = false
        else
            data.Billboard.Enabled = Config.Enabled
        end
    end
end)

-- 缩放
local ScaleGroup = Instance.new("Frame")
ScaleGroup.Size = UDim2.new(1, -24, 0, 36)
ScaleGroup.Position = UDim2.new(0, 12, 0, 260)
ScaleGroup.BackgroundTransparency = 1
ScaleGroup.Parent = MainFrame

local ScaleLabel = Instance.new("TextLabel")
ScaleLabel.Size = UDim2.new(0, 60, 1, 0)
ScaleLabel.Position = UDim2.new(0, 0, 0, 0)
ScaleLabel.BackgroundTransparency = 1
ScaleLabel.Text = "界面缩放"
ScaleLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
ScaleLabel.TextSize = 13
ScaleLabel.Font = Enum.Font.Gotham
ScaleLabel.TextXAlignment = Enum.TextXAlignment.Left
ScaleLabel.Parent = ScaleGroup

local ScaleSlider = Instance.new("Frame")
ScaleSlider.Size = UDim2.new(1, -70, 0, 6)
ScaleSlider.Position = UDim2.new(0, 65, 0.5, -3)
ScaleSlider.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
ScaleSlider.Parent = ScaleGroup

local ScaleCorner = Instance.new("UICorner")
ScaleCorner.CornerRadius = UDim.new(0, 3)
ScaleCorner.Parent = ScaleSlider

local ScaleFill = Instance.new("Frame")
ScaleFill.Size = UDim2.new(0.33, 0, 1, 0)
ScaleFill.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
ScaleFill.Parent = ScaleSlider

local ScaleBtn = Instance.new("TextButton")
ScaleBtn.Size = UDim2.new(0, 16, 0, 16)
ScaleBtn.Position = UDim2.new(0.33, -8, 0.5, -8)
ScaleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ScaleBtn.BackgroundTransparency = 0.1
ScaleBtn.Parent = ScaleSlider

local ScaleBtnCorner = Instance.new("UICorner")
ScaleBtnCorner.CornerRadius = UDim.new(0, 8)
ScaleBtn.Parent = ScaleSlider

local isScaling = false
ScaleBtn.MouseButton1Down:Connect(function()
    isScaling = true
end)

UserInputService.InputChanged:Connect(function(input)
    if not isScaling then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local absPos = ScaleSlider.AbsolutePosition
    local absSize = ScaleSlider.AbsoluteSize.X
    local x = input.Position.X - absPos.X
    local percent = math.clamp(x / absSize, 0, 1)

    ScaleFill.Size = UDim2.new(percent, 0, 1, 0)
    ScaleBtn.Position = UDim2.new(percent, -8, 0.5, -8)

    local scale = 0.3 + percent * 0.7
    MainScale.Scale = scale
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isScaling = false
    end
end)

local Tip = Instance.new("TextLabel")
Tip.Size = UDim2.new(1, 0, 0, 20)
Tip.Position = UDim2.new(0, 0, 1, -22)
Tip.BackgroundTransparency = 1
Tip.Text = "仅用于反作弊测试 · 拖动面板可移动"
Tip.TextColor3 = Color3.fromRGB(150, 155, 170)
Tip.TextSize = 11
Tip.Font = Enum.Font.Gotham
Tip.TextXAlignment = Enum.TextXAlignment.Center
Tip.Parent = MainFrame

-- 拖动
local isDragging = false
local dragStartPos = Vector2.new()
local frameStartPos = UDim2.new()

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
        frameStartPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not isDragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStartPos
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewSize = camera.ViewportSize

    local frameWidth = MainFrame.AbsoluteSize.X
    local frameHeight = MainFrame.AbsoluteSize.Y

    local newX = math.clamp(frameStartPos.X.Offset + delta.X, 0, viewSize.X - frameWidth)
    local newY = math.clamp(frameStartPos.Y.Offset + delta.Y, 0, viewSize.Y - frameHeight)

    MainFrame.Position = UDim2.new(0, newX, 0, newY)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)
