-- 轻量绕过版 ESP | 圣奥里适配 | 低负载不卡顿
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = true,
    ShowName = true,
    ShowJob = true,
    ShowDistance = true,
    MaxDistance = 2000,
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

local ESPList = {}
local random = Random.new()

-- ==============================
-- 【核心绕过代码 完全未修改】元表速度劫持
-- ==============================
pcall(function()
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    setreadonly(mt, false)
    
    mt.__index = newcclosure(function(self, key)
        if (key == "AssemblyLinearVelocity" or key == "AssemblyAngularVelocity") 
            and self:IsA("BasePart")
            and self.Parent 
            and self.Parent:IsA("Model") 
            and self.Parent:FindFirstChildOfClass("Humanoid") then
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
    for i=1, 12 do
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

-- 创建ESP 修复：初始状态同步配置
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
    bill.MaxDistance = Config.MaxDistance
    bill.Enabled = Config.Enabled -- 初始同步总开关
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
    nameLab.Visible = Config.ShowName -- 初始同步配置
    nameLab.Parent = bill

    local jobLab = Instance.new("TextLabel")
    jobLab.Size = UDim2.new(1,0,0,20)
    jobLab.Position = UDim2.new(0,0,0,26)
    jobLab.BackgroundTransparency = 1
    jobLab.Text = GetJob(p)
    jobLab.TextColor3 = GetJobColor(GetJob(p))
    jobLab.TextSize = 14
    jobLab.Font = Enum.Font.GothamBold
    jobLab.TextXAlignment = Enum.TextXAlignment.Center
    jobLab.Visible = Config.ShowJob -- 初始同步配置
    jobLab.Parent = bill

    local distLab = Instance.new("TextLabel")
    distLab.Size = UDim2.new(1,0,0,18)
    distLab.Position = UDim2.new(0,0,0,46)
    distLab.BackgroundTransparency = 1
    distLab.Text = ""
    distLab.TextColor3 = Color3.new(1,1,0)
    distLab.TextSize = 13
    distLab.TextXAlignment = Enum.TextXAlignment.Center
    distLab.Visible = Config.ShowDistance -- 初始同步配置
    distLab.Parent = bill

    -- 初始同步队友屏蔽
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
        if ESPList[userId].Billboard then ESPList[userId].Billboard:Destroy() end
        ESPList[userId] = nil
    end
end

-- 修复：降频更新循环 + 有效性校验
task.spawn(newcclosure(function()
    while task.wait(Config.UpdateRate) do
        -- 清理失效的ESP（角色重生/销毁后自动重建）
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

            -- 不存在则创建
            if not ESPList[p.UserId] then
                pcall(CreateESP, p)
            end

            -- 更新距离
            local head = p.Character:FindFirstChild("Head")
            if head and ESPList[p.UserId] and Config.ShowDistance then
                local dist = (head.Position - myRoot.Position).Magnitude
                ESPList[p.UserId].DistLabel.Text = "["..math.floor(dist).."]"
            end

            -- 实时队友屏蔽
            if ESPList[p.UserId] then
                local isTeam = p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team
                if Config.TeamCheck and isTeam then
                    ESPList[p.UserId].Billboard.Enabled = false
                else
                    ESPList[p.UserId].Billboard.Enabled = Config.Enabled
                end
            end
        end
    end
end))

Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p.UserId)
end)

-- ==============================================
-- 【重写UI】修复开关 + 拖动 + 缩放
-- 初始位置：左侧中间偏上
-- ==============================================
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI主容器
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = randName()
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ESPGui.Parent = PlayerGui

-- 主面板
local MainFrame = Instance.new("Frame")
MainFrame.Name = "Panel"
MainFrame.Position = UDim2.new(0, 25, 0.28, 0) -- 初始左侧中间偏上
MainFrame.Size = UDim2.new(0, 220, 0, 340)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
MainFrame.BackgroundTransparency = 0.15
MainFrame.ClipsDescendants = false
MainFrame.Active = true
MainFrame.Parent = ESPGui

-- 全局缩放
local MainScale = Instance.new("UIScale")
MainScale.Scale = 1
MainScale.Parent = MainFrame

-- 圆角
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MainFrame

-- 边框
local Border = Instance.new("UIStroke")
Border.Color = Color3.fromRGB(80, 130, 255)
Border.Thickness = 1
Border.Transparency = 0.3
Border.Parent = MainFrame

-- 标题
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

-- 标题分隔线
local TitleLine = Instance.new("Frame")
TitleLine.Size = UDim2.new(0.8, 0, 0, 1)
TitleLine.Position = UDim2.new(0.1, 0, 0, 48)
TitleLine.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
TitleLine.BackgroundTransparency = 0.4
TitleLine.Parent = MainFrame

-- 开关容器
local SwitchContainer = Instance.new("Frame")
SwitchContainer.Name = "Switches"
SwitchContainer.Size = UDim2.new(1, -24, 0, 190)
SwitchContainer.Position = UDim2.new(0, 12, 0, 60)
SwitchContainer.BackgroundTransparency = 1
SwitchContainer.Parent = MainFrame

-- 创建开关函数 修复：点击生效+逻辑同步
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
    
    -- 点击按钮 最上层确保可点
    local ClickBtn = Instance.new("TextButton")
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.ZIndex = 10
    ClickBtn.Parent = SwitchBg
    
    ClickBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        local value = Config[configKey]
        
        -- 更新开关样式
        SwitchBg.BackgroundColor3 = value and Color3.fromRGB(70, 130, 255) or Color3.fromRGB(60, 65, 75)
        Dot.Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        
        -- 执行回调
        if callback then callback(value) end
    end)
end

-- 功能开关 全部修复实装
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

-- 缩放区域
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
ScaleFill.Size = UDim2.new(0.33, 0, 1, 0) -- 默认1对应0.8-1.5的中间
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
ScaleBtnCorner.Parent = ScaleBtn

-- 缩放逻辑
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
    
    -- 0.3 ~ 1.5 倍缩放
    local scale = 0.3 + percent * 0.7
    MainScale.Scale = scale
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isScaling = false
    end
end)

-- 底部提示
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

-- ==============================
-- 拖动功能 支持鼠标+手机触摸
-- ==============================
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