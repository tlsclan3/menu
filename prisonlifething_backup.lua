--v5 --latest i got my hands on--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

--------------------------------------------------------------------------------
-- CONFIGURATION & STATE
--------------------------------------------------------------------------------
local RAY_DISTANCE = 1200
local isMoving = false
local MAX_HEIGHT = 120
local COOLDOWN_DURATION = 5
local lastTeleportTime = 0

-- Teleport keybind
local tpInputType  = Enum.UserInputType.Keyboard
local tpKeyCode    = Enum.KeyCode.LeftControl
local isBindingTP  = false

-- Follow TP keybind
local followInputType = Enum.UserInputType.Keyboard
local followKeyCode   = Enum.KeyCode.T
local isBindingFollow = false

local Settings = {
    TeamCheck=false,
    Movement = { Noclip=false, InfJump=false, BHop=false, Spinbot=false, AntiAim=false, AntiVoid=false },
    Aimbot   = { Enabled=false, ShowFov=false, WallCheck=false, FovSize=150, Smoothness=5, DistancePriority=false },
    Teleport = { Enabled=true, ClickTP=false, FollowTP=false },
    ESP      = { Box=false, Corner=false, Name=false, Distance=false, Tracers=false, Skeleton=false, Trails=false, TeamColor=false },
}

if isfile and readfile then
    pcall(function()
        if isfile("KarbonHub_Settings.json") then
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, readfile("KarbonHub_Settings.json"))
            if ok and decoded then
                for k, v in pairs(decoded) do
                    if type(v)=="table" and Settings[k] then
                        for sk, sv in pairs(v) do Settings[k][sk] = sv end
                    end
                end
            end
        end
    end)
end

local function SaveSettings()
    if writefile then pcall(function() writefile("KarbonHub_Settings.json", HttpService:JSONEncode(Settings)) end) end
end

--------------------------------------------------------------------------------
-- BOUNDARY REPLACEMENT
--------------------------------------------------------------------------------
local function processBoundary(child)
    if child.Name:upper():find("BOUND") then
        task.wait()
        if not child:IsA("BasePart") then return end
        local sz, cf, par = child.Size, child.CFrame, child.Parent
        child:Destroy()
        local rp = Instance.new("Part")
        rp.Name="SafeWall"; rp.Size=sz+Vector3.new(5,5,5); rp.CFrame=cf
        rp.Transparency=0.6; rp.Color=Color3.fromRGB(168,85,247)
        rp.Material=Enum.Material.SmoothPlastic; rp.CanCollide=true; rp.Anchored=true; rp.Parent=par
    end
end
for _, c in Workspace:GetChildren() do processBoundary(c) end
Workspace.ChildAdded:Connect(processBoundary)

-- Killbrick check throttled to 0.25s intervals (was every Stepped frame = massive lag)
local killTimer = 0
RunService.Heartbeat:Connect(function(dt)
    killTimer += dt
    if killTimer < 0.25 then return end
    killTimer = 0
    local char = player.Character
    if not char then return end
    for _, part in char:GetDescendants() do
        if part:IsA("BasePart") then
            for _, touch in part:GetTouchingParts() do
                if not touch:IsDescendantOf(char) then
                    local n = touch.Name:lower()
                    if n:find("kill") or n:find("lava") or n:find("death") or n:find("hurt") or n:find("bound") then
                        touch.CanTouch = false; touch:Destroy()
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- KARBON HUB UI LIBRARY
--------------------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(15,15,20),
    Panel      = Color3.fromRGB(25,25,35),
    Accent     = Color3.fromRGB(255,255,255), -- Will use gradient
    Hover      = Color3.fromRGB(40,40,55),
    Text       = Color3.fromRGB(250,250,250),
    TextDim    = Color3.fromRGB(161,161,170),
    Outline    = Color3.fromRGB(60,60,80),
    Font       = Enum.Font.GothamMedium
}

local function ApplyGradient(parent)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 105, 180)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(135, 206, 235))
    })
    grad.Parent = parent
    return grad
end

local UI = {}
local screenGui = Instance.new("ScreenGui")
screenGui.Name="KarbonHubUI"; screenGui.ResetOnSpawn=false
screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local cgOk, cgRes = pcall(function() return game:GetService("CoreGui") end)
screenGui.Parent = cgOk and cgRes or player:WaitForChild("PlayerGui")

local ToastsFrame = Instance.new("Frame", screenGui)
ToastsFrame.Size=UDim2.new(0,300,1,-40); ToastsFrame.Position=UDim2.new(1,-320,0,20)
ToastsFrame.BackgroundTransparency=1
local tLayout = Instance.new("UIListLayout", ToastsFrame)
tLayout.SortOrder=Enum.SortOrder.LayoutOrder; tLayout.VerticalAlignment=Enum.VerticalAlignment.Bottom; tLayout.Padding=UDim.new(0,10)

function UI:Notify(title, text, dur)
    dur = dur or 3
    local toast = Instance.new("Frame", ToastsFrame)
    toast.Size=UDim2.new(1,0,0,60); toast.BackgroundColor3=Theme.Panel
    Instance.new("UICorner",toast).CornerRadius=UDim.new(0,6)
    local s=Instance.new("UIStroke",toast); s.Color=Theme.Outline; s.Thickness=1
    local tl=Instance.new("TextLabel",toast)
    tl.Size=UDim2.new(1,-20,0,20); tl.Position=UDim2.new(0,10,0,10); tl.BackgroundTransparency=1
    tl.Text=title; tl.TextColor3=Theme.Accent; tl.Font=Enum.Font.GothamBold; tl.TextSize=14; tl.TextXAlignment=Enum.TextXAlignment.Left
    local bl=Instance.new("TextLabel",toast)
    bl.Size=UDim2.new(1,-20,0,20); bl.Position=UDim2.new(0,10,0,30); bl.BackgroundTransparency=1
    bl.Text=text; bl.TextColor3=Theme.Text; bl.Font=Theme.Font; bl.TextSize=13; bl.TextXAlignment=Enum.TextXAlignment.Left; bl.TextWrapped=true
    toast.Position=UDim2.new(1,20,0,0)
    TweenService:Create(toast,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,0,0)}):Play()
    task.delay(dur, function()
        local tw=TweenService:Create(toast,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(1,20,0,0)})
        tw:Play(); tw.Completed:Connect(function() toast:Destroy() end)
    end)
end

function UI:CreateWindow(titleText)
    local window = {Tabs={}, CurrentTab=nil}

    local MainFrame = Instance.new("Frame", screenGui)
    MainFrame.Name="MainFrame"; MainFrame.Size=UDim2.new(0,580,0,400)
    MainFrame.Position=UDim2.new(0.5,-290,0.5,-200); MainFrame.BackgroundColor3=Theme.Background; MainFrame.Active=true
    Instance.new("UICorner",MainFrame).CornerRadius=UDim.new(0,8)
    local ms=Instance.new("UIStroke",MainFrame); ms.Color=Theme.Outline; ms.Thickness=1

    local TitleBar=Instance.new("Frame",MainFrame)
    TitleBar.Size=UDim2.new(1,0,0,40); TitleBar.BackgroundColor3=Theme.Background
    Instance.new("UICorner",TitleBar).CornerRadius=UDim.new(0,8)
    local tbFix=Instance.new("Frame",TitleBar)
    tbFix.Size=UDim2.new(1,0,0,10); tbFix.Position=UDim2.new(0,0,1,-10); tbFix.BackgroundColor3=Theme.Background; tbFix.BorderSizePixel=0
    local tbLine=Instance.new("Frame",TitleBar)
    tbLine.Size=UDim2.new(1,0,0,1); tbLine.Position=UDim2.new(0,0,1,-1); tbLine.BackgroundColor3=Theme.Outline; tbLine.BorderSizePixel=0; tbLine.ZIndex=2
    local TitleText=Instance.new("TextLabel",TitleBar)
    TitleText.Size=UDim2.new(1,-20,1,0); TitleText.Position=UDim2.new(0,20,0,0); TitleText.BackgroundTransparency=1
    TitleText.Text=titleText; TitleText.TextColor3=Color3.fromRGB(255,255,255); TitleText.Font=Enum.Font.GothamBold; TitleText.TextSize=16; TitleText.TextXAlignment=Enum.TextXAlignment.Left
    ApplyGradient(TitleText)

    local dragging,dragInput,dragStart,startPos
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=MainFrame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    TitleBar.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dragInput=i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i==dragInput and dragging then
            local d=i.Position-dragStart
            MainFrame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)

    local RH=Instance.new("TextButton",MainFrame)
    RH.Size=UDim2.new(0,20,0,20); RH.Position=UDim2.new(1,-20,1,-20); RH.BackgroundTransparency=1; RH.Text=""; RH.ZIndex=10
    local resizing,resizeStart,startSize
    RH.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            resizing=true; resizeStart=i.Position; startSize=MainFrame.AbsoluteSize
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then resizing=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if resizing and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-resizeStart
            MainFrame.Size=UDim2.new(0,math.max(420,startSize.X+d.X),0,math.max(300,startSize.Y+d.Y))
        end
    end)

    local Sidebar=Instance.new("Frame",MainFrame)
    Sidebar.Size=UDim2.new(0,140,1,-40); Sidebar.Position=UDim2.new(0,0,0,40); Sidebar.BackgroundColor3=Theme.Panel; Sidebar.BorderSizePixel=0
    Instance.new("UICorner",Sidebar).CornerRadius=UDim.new(0,8)
    local sbFix=Instance.new("Frame",Sidebar); sbFix.Size=UDim2.new(0,10,1,0); sbFix.Position=UDim2.new(1,-10,0,0); sbFix.BackgroundColor3=Theme.Panel; sbFix.BorderSizePixel=0
    local sbLine=Instance.new("Frame",Sidebar); sbLine.Size=UDim2.new(0,1,1,0); sbLine.Position=UDim2.new(1,-1,0,0); sbLine.BackgroundColor3=Theme.Outline; sbLine.BorderSizePixel=0

    local TabContainer=Instance.new("ScrollingFrame",Sidebar)
    TabContainer.Size=UDim2.new(1,0,1,-20); TabContainer.Position=UDim2.new(0,0,0,10); TabContainer.BackgroundTransparency=1; TabContainer.ScrollBarThickness=0
    local TabLL=Instance.new("UIListLayout",TabContainer); TabLL.SortOrder=Enum.SortOrder.LayoutOrder; TabLL.Padding=UDim.new(0,5); TabLL.HorizontalAlignment=Enum.HorizontalAlignment.Center

    local ContentContainer=Instance.new("Frame",MainFrame)
    ContentContainer.Size=UDim2.new(1,-140,1,-40); ContentContainer.Position=UDim2.new(0,140,0,40); ContentContainer.BackgroundTransparency=1; ContentContainer.ClipsDescendants=true

    function window:AddTab(tabName)
        local tab={}
        local TabBtn=Instance.new("TextButton",TabContainer)
        TabBtn.Size=UDim2.new(1,-20,0,32); TabBtn.BackgroundColor3=Theme.Background
        TabBtn.Text=tabName; TabBtn.TextColor3=Theme.TextDim; TabBtn.Font=Theme.Font; TabBtn.TextSize=13; TabBtn.AutoButtonColor=false
        Instance.new("UICorner",TabBtn).CornerRadius=UDim.new(0,6)
        local btnGrad = ApplyGradient(TabBtn); btnGrad.Enabled = false

        local ContentScroll=Instance.new("ScrollingFrame",ContentContainer)
        ContentScroll.Size=UDim2.new(1,-20,1,-20); ContentScroll.Position=UDim2.new(0,10,0,10)
        ContentScroll.BackgroundTransparency=1; ContentScroll.ScrollBarThickness=4; ContentScroll.ScrollBarImageColor3=Theme.Outline; ContentScroll.Visible=false
        local CL=Instance.new("UIListLayout",ContentScroll); CL.SortOrder=Enum.SortOrder.LayoutOrder; CL.Padding=UDim.new(0,10)
        CL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ContentScroll.CanvasSize=UDim2.new(0,0,0,CL.AbsoluteContentSize.Y+10) end)

        TabBtn.MouseEnter:Connect(function() if window.CurrentTab~=tab then TweenService:Create(TabBtn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Hover,TextColor3=Theme.Text}):Play() end end)
        TabBtn.MouseLeave:Connect(function() if window.CurrentTab~=tab then TweenService:Create(TabBtn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Background,TextColor3=Theme.TextDim}):Play() end end)
        TabBtn.MouseButton1Click:Connect(function()
            if window.CurrentTab==tab then return end
            if window.CurrentTab then 
                TweenService:Create(window.CurrentTab.Btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Background,TextColor3=Theme.TextDim}):Play()
                window.CurrentTab.Grad.Enabled = false
                window.CurrentTab.Content.Visible=false 
            end
            window.CurrentTab=tab
            TweenService:Create(TabBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(255,255,255),TextColor3=Color3.fromRGB(255,255,255)}):Play()
            btnGrad.Enabled = true
            ContentScroll.Visible=true; ContentScroll.Position=UDim2.new(0,30,0,10); ContentScroll.CanvasPosition=Vector2.zero
            TweenService:Create(ContentScroll,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,10,0,10)}):Play()
        end)

        tab.Btn=TabBtn; tab.Content=ContentScroll; tab.Grad=btnGrad
        if not window.CurrentTab then
            window.CurrentTab=tab; TabBtn.BackgroundColor3=Color3.fromRGB(255,255,255); TabBtn.TextColor3=Color3.fromRGB(255,255,255); btnGrad.Enabled=true; ContentScroll.Visible=true
        end

        function tab:AddToggle(text, default, callback)
            local TF=Instance.new("Frame",ContentScroll); TF.Size=UDim2.new(1,0,0,36); TF.BackgroundColor3=Theme.Panel
            Instance.new("UICorner",TF).CornerRadius=UDim.new(0,6); local ts=Instance.new("UIStroke",TF); ts.Color=Theme.Outline; ts.Thickness=1
            local Tlbl=Instance.new("TextLabel",TF); Tlbl.Size=UDim2.new(1,-60,1,0); Tlbl.Position=UDim2.new(0,15,0,0); Tlbl.BackgroundTransparency=1
            Tlbl.Text=text; Tlbl.TextColor3=Theme.Text; Tlbl.Font=Theme.Font; Tlbl.TextSize=13; Tlbl.TextXAlignment=Enum.TextXAlignment.Left
            local TBG=Instance.new("Frame",TF); TBG.Size=UDim2.new(0,40,0,20); TBG.Position=UDim2.new(1,-50,0.5,-10)
            TBG.BackgroundColor3=default and Color3.fromRGB(255,255,255) or Theme.Background
            local togGrad = ApplyGradient(TBG); togGrad.Enabled = default
            Instance.new("UICorner",TBG).CornerRadius=UDim.new(1,0); local tgs=Instance.new("UIStroke",TBG); tgs.Color=Theme.Outline; tgs.Thickness=1
            local C=Instance.new("Frame",TBG); C.Size=UDim2.new(0,16,0,16); C.Position=UDim2.new(0,default and 22 or 2,0.5,-8); C.BackgroundColor3=Color3.fromRGB(255,255,255)
            Instance.new("UICorner",C).CornerRadius=UDim.new(1,0)
            local btn=Instance.new("TextButton",TF); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
            
            local obj = {}
            local state = default
            function obj:Set(val)
                if state == val then return end
                state = val
                togGrad.Enabled = state
                TweenService:Create(TBG,TweenInfo.new(0.15),{BackgroundColor3=state and Color3.fromRGB(255,255,255) or Theme.Background}):Play()
                TweenService:Create(C,TweenInfo.new(0.15),{Position=UDim2.new(0,state and 22 or 2,0.5,-8)}):Play()
                callback(state); SaveSettings()
            end
            btn.MouseButton1Click:Connect(function() obj:Set(not state) end)
            return obj
        end

        function tab:AddSlider(text, smin, smax, default, callback)
            local SF=Instance.new("Frame",ContentScroll); SF.Size=UDim2.new(1,0,0,50); SF.BackgroundColor3=Theme.Panel
            Instance.new("UICorner",SF).CornerRadius=UDim.new(0,6); local ss=Instance.new("UIStroke",SF); ss.Color=Theme.Outline; ss.Thickness=1
            local Slbl=Instance.new("TextLabel",SF); Slbl.Size=UDim2.new(1,-20,0,25); Slbl.Position=UDim2.new(0,15,0,0); Slbl.BackgroundTransparency=1
            Slbl.Text=text; Slbl.TextColor3=Theme.Text; Slbl.Font=Theme.Font; Slbl.TextSize=13; Slbl.TextXAlignment=Enum.TextXAlignment.Left
            local VL=Instance.new("TextLabel",SF); VL.Size=UDim2.new(0,50,0,25); VL.Position=UDim2.new(1,-65,0,0); VL.BackgroundTransparency=1
            VL.Text=tostring(default); VL.TextColor3=Color3.fromRGB(255,105,180); VL.Font=Enum.Font.GothamBold; VL.TextSize=13; VL.TextXAlignment=Enum.TextXAlignment.Right
            ApplyGradient(VL)
            local SBG=Instance.new("Frame",SF); SBG.Size=UDim2.new(1,-30,0,6); SBG.Position=UDim2.new(0,15,0,32); SBG.BackgroundColor3=Theme.Background
            Instance.new("UICorner",SBG).CornerRadius=UDim.new(1,0)
            local SFill=Instance.new("Frame",SBG); SFill.Size=UDim2.new(math.clamp((default-smin)/(smax-smin),0,1),0,1,0); SFill.BackgroundColor3=Color3.fromRGB(255,255,255)
            ApplyGradient(SFill)
            Instance.new("UICorner",SFill).CornerRadius=UDim.new(1,0)
            local Handle=Instance.new("Frame",SFill); Handle.Size=UDim2.new(0,14,0,14); Handle.Position=UDim2.new(1,-7,0.5,-7); Handle.BackgroundColor3=Color3.fromRGB(255,255,255)
            Instance.new("UICorner",Handle).CornerRadius=UDim.new(1,0)
            local isDragging=false
            -- OPTIMIZED: Direct set, no tween per mouse move
            local function update(inp)
                local pct=math.clamp((inp.Position.X-SBG.AbsolutePosition.X)/SBG.AbsoluteSize.X,0,1)
                local val=math.floor(smin+(smax-smin)*pct)
                SFill.Size=UDim2.new(pct,0,1,0); VL.Text=tostring(val); callback(val); SaveSettings()
            end
            local SBtn=Instance.new("TextButton",SBG); SBtn.Size=UDim2.new(1,20,1,20); SBtn.Position=UDim2.new(0,-10,0,-10); SBtn.BackgroundTransparency=1; SBtn.Text=""
            SBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then isDragging=true; update(i) end end)
            SBtn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then isDragging=false end end)
            UserInputService.InputChanged:Connect(function(i) if isDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then update(i) end end)
        end

        function tab:AddButton(text, callback)
            local BF=Instance.new("TextButton",ContentScroll); BF.Size=UDim2.new(1,0,0,36); BF.BackgroundColor3=Theme.Panel
            BF.Text=text; BF.TextColor3=Theme.Text; BF.Font=Theme.Font; BF.TextSize=13; BF.AutoButtonColor=false
            Instance.new("UICorner",BF).CornerRadius=UDim.new(0,6); local bs=Instance.new("UIStroke",BF); bs.Color=Theme.Outline; bs.Thickness=1
            BF.MouseEnter:Connect(function() TweenService:Create(BF,TweenInfo.new(0.15),{BackgroundColor3=Theme.Hover}):Play() end)
            BF.MouseLeave:Connect(function() TweenService:Create(BF,TweenInfo.new(0.15),{BackgroundColor3=Theme.Panel}):Play() end)
            BF.MouseButton1Down:Connect(function() TweenService:Create(BF,TweenInfo.new(0.08),{Size=UDim2.new(0.98,0,0,34),Position=UDim2.new(0.01,0,0,1)}):Play() end)
            BF.MouseButton1Up:Connect(function() TweenService:Create(BF,TweenInfo.new(0.08),{Size=UDim2.new(1,0,0,36),Position=UDim2.new(0,0,0,0)}):Play(); callback() end)
        end

        function tab:AddLabel(text)
            local L=Instance.new("TextLabel",ContentScroll); L.Size=UDim2.new(1,0,0,20); L.BackgroundTransparency=1
            L.Text=text; L.TextColor3=Theme.TextDim; L.Font=Theme.Font; L.TextSize=13; L.TextXAlignment=Enum.TextXAlignment.Left
            return L
        end

        return tab
    end
    return window
end

--------------------------------------------------------------------------------
-- BUILD UI
--------------------------------------------------------------------------------
local Window      = UI:CreateWindow("Karbon Hub")
local AimbotTab   = Window:AddTab("Aimbot")
local ESPTab      = Window:AddTab("Visuals")
local MovementTab = Window:AddTab("Movement")
local TeleportTab = Window:AddTab("Teleport")
local UtilsTab    = Window:AddTab("Utils")

-- AIMBOT
AimbotTab:AddToggle("Enable Aimbot",     Settings.Aimbot.Enabled,         function(v) Settings.Aimbot.Enabled          = v end)
AimbotTab:AddToggle("Distance Priority", Settings.Aimbot.DistancePriority, function(v) Settings.Aimbot.DistancePriority = v end)
AimbotTab:AddToggle("Show FOV Circle",   Settings.Aimbot.ShowFov,          function(v) Settings.Aimbot.ShowFov          = v end)
AimbotTab:AddToggle("Wall Check",        Settings.Aimbot.WallCheck,        function(v) Settings.Aimbot.WallCheck        = v end)
AimbotTab:AddToggle("Team Check",        Settings.TeamCheck,               function(v) Settings.TeamCheck               = v end)
AimbotTab:AddSlider("FOV Size",    10, 800, Settings.Aimbot.FovSize,    function(v) Settings.Aimbot.FovSize    = v end)
AimbotTab:AddSlider("Smoothness",   1,  30, Settings.Aimbot.Smoothness, function(v) Settings.Aimbot.Smoothness = v end)

-- ESP
local boxTog, cornerTog
boxTog = ESPTab:AddToggle("Box ESP",      Settings.ESP.Box,      function(v) 
    Settings.ESP.Box = v
    if v and cornerTog then cornerTog:Set(false) end
end)
cornerTog = ESPTab:AddToggle("Corner ESP",   Settings.ESP.Corner,   function(v) 
    Settings.ESP.Corner = v
    if v and boxTog then boxTog:Set(false) end
end)
ESPTab:AddToggle("Name ESP",     Settings.ESP.Name,     function(v) Settings.ESP.Name     = v end)
ESPTab:AddToggle("Distance ESP", Settings.ESP.Distance, function(v) Settings.ESP.Distance = v end)
ESPTab:AddToggle("Tracers",      Settings.ESP.Tracers,  function(v) Settings.ESP.Tracers  = v end)
ESPTab:AddToggle("Skeleton ESP", Settings.ESP.Skeleton, function(v) Settings.ESP.Skeleton = v end)
ESPTab:AddToggle("Trails",       Settings.ESP.Trails,   function(v) Settings.ESP.Trails   = v end)
ESPTab:AddToggle("Team Color",   Settings.ESP.TeamColor,function(v) Settings.ESP.TeamColor= v end)
ESPTab:AddToggle("Team Check",   Settings.TeamCheck,    function(v) Settings.TeamCheck    = v end)

-- MOVEMENT
MovementTab:AddToggle("Enable Noclip", Settings.Movement.Noclip, function(v) Settings.Movement.Noclip = v end)
MovementTab:AddToggle("Infinite Jump", Settings.Movement.InfJump, function(v) Settings.Movement.InfJump = v end)
MovementTab:AddToggle("Bunny Hop", Settings.Movement.BHop, function(v) Settings.Movement.BHop = v end)
MovementTab:AddToggle("Spinbot", Settings.Movement.Spinbot, function(v) Settings.Movement.Spinbot = v end)
MovementTab:AddToggle("Anti-Aim (Jitter)", Settings.Movement.AntiAim, function(v) Settings.Movement.AntiAim = v end)
MovementTab:AddToggle("Anti-Void", Settings.Movement.AntiVoid, function(v) Settings.Movement.AntiVoid = v end)

-- TELEPORT
TeleportTab:AddToggle("Enable Teleport", Settings.Teleport.Enabled, function(v) Settings.Teleport.Enabled = v end)
TeleportTab:AddToggle("Click TP", Settings.Teleport.ClickTP, function(v) Settings.Teleport.ClickTP = v end)
TeleportTab:AddToggle("Follow TP", Settings.Teleport.FollowTP, function(v) Settings.Teleport.FollowTP = v end)
local tpBindLabel  = TeleportTab:AddLabel("TP Keybind: " .. tpKeyCode.Name)
TeleportTab:AddButton("Bind TP Key", function()
    isBindingTP = true
    tpBindLabel.Text = "TP Keybind: Press any key..."
    tpBindLabel.TextColor3 = Theme.Accent
end)
local tpStatusLabel = TeleportTab:AddLabel("Status: READY")

-- UTILS
UtilsTab:AddButton("Give Keycard", function()
    local ok, err = pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local backpack = player:WaitForChild("Backpack")
        local tools = RS:WaitForChild("Tools")
        local keyCard = tools:WaitForChild("Key card")
        local clone = keyCard:Clone()
        clone.Parent = backpack
    end)
    if ok then UI:Notify("Utils", "Key card added to backpack.", 3)
    else UI:Notify("Utils", "Failed: " .. tostring(err), 4) end
end)
UtilsTab:AddButton("Delete All Doors", function()
    local doors = Workspace:FindFirstChild("Doors")
    if not doors then UI:Notify("Utils","No Doors folder found.",3); return end
    local ch = doors:GetChildren()
    local targets = {
        ch[3],ch[4],ch[5],ch[7],ch[8],ch[9],ch[10],ch[12],ch[14],ch[15],ch[16],
        doors:FindFirstChild("door_v3"), doors:FindFirstChild("door_v3_cellblock1"),
        doors:FindFirstChild("door_v3_ct"), doors:FindFirstChild("door_v3_small"),
        doors:FindFirstChild("gate_v3"),
    }
    local count = 0
    for _, obj in pairs(targets) do
        if obj and obj.Parent then obj:Destroy(); count += 1 end
    end
    UI:Notify("Utils", "Deleted "..count.." doors.", 3)
end)

UI:Notify("Welcome", "Karbon Hub injected successfully.", 4)

--------------------------------------------------------------------------------
-- TELEPORT LOGIC
--------------------------------------------------------------------------------
local function spawnVisualizer(pos)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(1.5, 1.5, 1.5); p.Color = Color3.fromRGB(255, 105, 180); p.Material = Enum.Material.Neon
    p.Anchored = true; p.CanCollide = false; p.Position = pos; p.Parent = Workspace
    task.delay(0.5, function()
        for i = 1, 10 do p.Transparency = i / 10; task.wait(0.03) end
        p:Destroy()
    end)
end

local function buildWaypoints(startPos, endPos)
    local dir = endPos - startPos
    local unit = Vector3.new(dir.X, 0, dir.Z).Unit
    local perp = Vector3.new(-unit.Z, 0, unit.X)
    local points = {}
    local steps = 8
    for i = 1, steps do
        local t = i / (steps + 1)
        local base = Vector3.new(startPos.X + dir.X * t, 0, startPos.Z + dir.Z * t)
        local side = (i % 2 == 0) and 1 or -1
        local offset = perp * (side * (3 + math.random() * 3))
        local jitter = Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
        table.insert(points, Vector3.new((base + offset + jitter).X, 0, (base + offset + jitter).Z))
    end
    table.insert(points, Vector3.new(endPos.X, 0, endPos.Z))
    return points
end

local function findGround(pos, character)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}; params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(pos, Vector3.new(0, -2000, 0), params)
    return result and result.Position.Y or pos.Y
end

local function spawnPlatform(pos)
    local platform = Instance.new("Part")
    platform.Name = "MoverPlatform"; platform.Size = Vector3.new(8, 0.6, 8); platform.Color = Color3.fromRGB(135, 206, 235)
    platform.Material = Enum.Material.Neon; platform.Transparency = 1; platform.Anchored = true
    platform.CanCollide = false; platform.CastShadow = false; platform.Parent = Workspace
    platform.CFrame = CFrame.new(pos)
    return platform
end

local function getClosestTarget(mouseLoc)
    local closestTarget=nil; local shortest=Settings.Aimbot.FovSize; local closest3D=math.huge
    local fovSq=Settings.Aimbot.FovSize*Settings.Aimbot.FovSize; local camPos=camera.CFrame.Position
    for _,p in Players:GetPlayers() do
        if p==player then continue end
        if Settings.TeamCheck and p.Team and player.Team and p.Team==player.Team then continue end
        local char=p.Character; if not char then continue end
        local head=char:FindFirstChild("Head"); if not head then continue end
        local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
        if Settings.Aimbot.WallCheck then
            local origin=camera.CFrame.Position
            local pParams=RaycastParams.new(); pParams.FilterDescendantsInstances={player.Character,head.Parent}; pParams.FilterType=Enum.RaycastFilterType.Exclude
            if Workspace:Raycast(origin,head.Position-origin,pParams)~=nil then continue end
        end
        local sp,onScreen=camera:WorldToViewportPoint(head.Position); if not onScreen then continue end
        local dx=sp.X-mouseLoc.X; local dy=sp.Y-mouseLoc.Y; local dsq=dx*dx+dy*dy
        if dsq>fovSq then continue end
        if Settings.Aimbot.DistancePriority then
            local d3=(head.Position-camPos).Magnitude; if d3<closest3D then closest3D=d3; closestTarget=head end
        else
            local d=math.sqrt(dsq); if d<shortest then shortest=d; closestTarget=head end
        end
    end
    return closestTarget
end

local function moveCharacter(targetPos)
    if isMoving then return end
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    isMoving = true; lastTeleportTime = os.clock()
    hrp.Anchored = true; humanoid.PlatformStand = true; humanoid.AutoRotate = false
    local _, currentYRot = hrp.CFrame:ToEulerAnglesYXZ()
    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, currentYRot, 0)
    local PLATFORM_OFFSET = Vector3.new(0, -3.1, 0)
    local platform = spawnPlatform(hrp.Position + PLATFORM_OFFSET)
    local startPos = hrp.Position
    local peakY = math.min(startPos.Y + MAX_HEIGHT, startPos.Y + MAX_HEIGHT)
    local waypoints = buildWaypoints(startPos, targetPos)
    local wpIndex = 1
    local RISE_SPEED = 600; local TRAVEL_SPEED = 600; local DESCENT_SPEED = 300
    local phase = "rise"; local groundY = nil
    local speed = TRAVEL_SPEED; local lastPulse = os.clock(); local nextPulseIn = 1 + math.random()
    local inDip = false; local dipStart = 0
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then
            if connection then connection:Disconnect() end
            if platform and platform.Parent then platform:Destroy() end
            isMoving = false; return
        end
        local currentPos = root.Position
        local _, yr = root.CFrame:ToEulerAnglesYXZ()
        if phase == "rise" then
            local newY = math.min(currentPos.Y + RISE_SPEED * dt, peakY)
            if newY >= peakY then newY = peakY; phase = "travel" end
            root.CFrame = CFrame.new(currentPos.X, newY, currentPos.Z) * CFrame.Angles(0, yr, 0)
            platform.CFrame = CFrame.new(root.Position + PLATFORM_OFFSET)
            return
        end
        if phase == "travel" then
            local now = os.clock()
            if not inDip and (now - lastPulse) >= nextPulseIn then inDip = true; dipStart = now; speed = 40 end
            if inDip and (now - dipStart) >= 0.07 then inDip = false; speed = math.random(100, 120); lastPulse = now; nextPulseIn = 1 + math.random() end
            if wpIndex > #waypoints then phase = "descend"; groundY = findGround(Vector3.new(targetPos.X, currentPos.Y, targetPos.Z), char); return end
            local wp = waypoints[wpIndex]
            local flatTarget = Vector3.new(wp.X, math.min(peakY, startPos.Y + MAX_HEIGHT), wp.Z)
            local diff = flatTarget - currentPos
            local dist = diff.Magnitude
            local step = speed * dt
            if dist <= step + 0.05 then
                root.CFrame = CFrame.new(flatTarget) * CFrame.Angles(0, yr, 0); wpIndex += 1
            else
                local newPos = currentPos + diff.Unit * step
                root.CFrame = CFrame.new(Vector3.new(newPos.X, math.min(newPos.Y, startPos.Y + MAX_HEIGHT), newPos.Z)) * CFrame.Angles(0, yr, 0)
            end
            platform.CFrame = CFrame.new(root.Position + PLATFORM_OFFSET)
            return
        end
        if phase == "descend" then
            local newY = currentPos.Y - DESCENT_SPEED * dt
            local targetGroundY = (groundY or targetPos.Y) + 3.1
            if newY <= targetGroundY then
                root.CFrame = CFrame.new(targetPos.X, targetGroundY, targetPos.Z) * CFrame.Angles(0, yr, 0)
                platform.CFrame = CFrame.new(root.Position + PLATFORM_OFFSET)
                connection:Disconnect()
                task.wait(0.05)
                local _, fyr = root.CFrame:ToEulerAnglesYXZ()
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, fyr, 0)
                hum.PlatformStand = false; hum.AutoRotate = true; root.Anchored = false
                platform:Destroy(); isMoving = false; return
            end
            root.CFrame = CFrame.new(targetPos.X, newY, targetPos.Z) * CFrame.Angles(0, yr, 0)
            platform.CFrame = CFrame.new(root.Position + PLATFORM_OFFSET)
        end
    end)
end

-- Teleport function called by input handlers
local function executeTeleport()
    if (COOLDOWN_DURATION-(os.clock()-lastTeleportTime)) > 0 or isMoving then return end
    
    if Settings.Teleport.FollowTP then
        local mouseLoc = UserInputService:GetMouseLocation()
        local targetHead = getClosestTarget(mouseLoc)
        if targetHead then
            spawnVisualizer(targetHead.Position)
            moveCharacter(targetHead.Position)
            return
        end
    end
    
    local mouse = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local params = RaycastParams.new()
    if player.Character then params.FilterDescendantsInstances={player.Character}; params.FilterType=Enum.RaycastFilterType.Exclude end
    local result = Workspace:Raycast(ray.Origin, ray.Direction*RAY_DISTANCE, params)
    if result then 
        spawnVisualizer(result.Position)
        moveCharacter(result.Position) 
    end
end

--------------------------------------------------------------------------------
-- KEYBIND INPUT HANDLER
--------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if isBindingTP then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            tpInputType = Enum.UserInputType.Keyboard; tpKeyCode = input.KeyCode
        elseif input.UserInputType ~= Enum.UserInputType.Focus and input.UserInputType ~= Enum.UserInputType.MouseMovement then
            tpInputType = input.UserInputType; tpKeyCode = Enum.KeyCode.Unknown
        else return end
        isBindingTP = false
        local n = tpInputType==Enum.UserInputType.Keyboard and tpKeyCode.Name or tpInputType.Name
        tpBindLabel.Text = "TP Keybind: "..n; tpBindLabel.TextColor3 = Theme.TextDim
        UI:Notify("Keybind Set","TP bound to "..n,3); return
    end

    if not Settings.Teleport.Enabled then return end

    -- Click TP: left mouse click
    if Settings.Teleport.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 then
        executeTeleport()
        return
    end

    -- Keybind TP
    local isTPKey = (tpInputType==Enum.UserInputType.Keyboard and input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==tpKeyCode)
                 or (tpInputType~=Enum.UserInputType.Keyboard and input.UserInputType==tpInputType)
    if isTPKey then
        executeTeleport()
    end
end)

--------------------------------------------------------------------------------
-- AIMBOT & ESP ENGINE
--------------------------------------------------------------------------------
local fovCircle=Drawing.new("Circle")
fovCircle.Thickness=1.5; fovCircle.Color=Color3.fromRGB(255, 105, 180); fovCircle.Filled=false; fovCircle.Transparency=1


-- ESP Data
local espCache={}
local BLACK=Color3.fromRGB(0,0,0); local WHITE=Color3.fromRGB(255,255,255)

local bonePairsR15={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local bonePairsR6={
    {"Head","Torso"},
    {"Torso","Left Arm", Vector3.new(-1, 0.5, 0), Vector3.new(0, 0.5, 0)},
    {"Left Arm","Left Arm", Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0)},
    {"Torso","Right Arm", Vector3.new(1, 0.5, 0), Vector3.new(0, 0.5, 0)},
    {"Right Arm","Right Arm", Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0)},
    {"Torso","Left Leg", Vector3.new(-0.5, -1, 0), Vector3.new(0, 0.5, 0)},
    {"Left Leg","Left Leg", Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0)},
    {"Torso","Right Leg", Vector3.new(0.5, -1, 0), Vector3.new(0, 0.5, 0)},
    {"Right Leg","Right Leg", Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0)}
}

local function newLine(thick, col)
    local l=Drawing.new("Line"); l.Thickness=thick; l.Color=col; l.Visible=false; return l
end

local function createPlayerESP(p)
    local d={
        box=Drawing.new("Square"),boxOut=Drawing.new("Square"),
        name=Drawing.new("Text"), distance=Drawing.new("Text"),
        tracer=newLine(1.5,WHITE), tracerOut=newLine(3,BLACK),
        corners={}, cornersOut={}, skelLines={}, skelOut={}, trailLines={}, trailOut={}, history={},
    }
    d.boxOut.Thickness=4.5; d.boxOut.Filled=false; d.boxOut.Color=BLACK; d.boxOut.Visible=false
    d.box.Thickness=2.5;    d.box.Filled=false;    d.box.Color=WHITE; d.box.Visible=false
    d.name.Size=14; d.name.Center=true; d.name.Outline=true; d.name.Color=WHITE; d.name.Visible=false
    d.distance.Size=12; d.distance.Center=true; d.distance.Outline=true; d.distance.Color=Color3.fromRGB(200,200,200); d.distance.Visible=false
    for i=1,8 do d.corners[i]=newLine(2.5,WHITE); d.cornersOut[i]=newLine(4.5,BLACK) end
    espCache[p]=d
end

local function hideAllESP(d)
    d.box.Visible=false; d.boxOut.Visible=false; d.name.Visible=false; d.distance.Visible=false
    d.tracer.Visible=false; d.tracerOut.Visible=false
    for i=1,8 do d.corners[i].Visible=false; d.cornersOut[i].Visible=false end
    for _,l in pairs(d.skelLines) do l.Visible=false end; for _,l in pairs(d.skelOut) do l.Visible=false end
    for _,l in pairs(d.trailLines) do l.Visible=false end; for _,l in pairs(d.trailOut) do l.Visible=false end
end

local function removePlayerESP(p)
    local d=espCache[p]; if not d then return end
    d.box:Remove(); d.boxOut:Remove(); d.name:Remove(); d.distance:Remove(); d.tracer:Remove(); d.tracerOut:Remove()
    for i=1,8 do d.corners[i]:Remove(); d.cornersOut[i]:Remove() end
    for _,l in pairs(d.skelLines) do l:Remove() end; for _,l in pairs(d.skelOut) do l:Remove() end
    for _,l in pairs(d.trailLines) do l:Remove() end; for _,l in pairs(d.trailOut) do l:Remove() end
    espCache[p]=nil
end

for _,p in Players:GetPlayers() do if p~=player then createPlayerESP(p) end end
Players.PlayerAdded:Connect(function(p) if p~=player then createPlayerESP(p) end end)
Players.PlayerRemoving:Connect(removePlayerESP)

-- Pre-alloc corner From/To to avoid GC pressure per frame
local _cFrom={} local _cTo={}
for i=1,8 do _cFrom[i]=Vector2.new(0,0); _cTo[i]=Vector2.new(0,0) end

-- SINGLE unified render loop (was multiple connections)
RunService.RenderStepped:Connect(function()
    local camPos=camera.CFrame.Position; local vp=camera.ViewportSize
    local mLoc=UserInputService:GetMouseLocation(); local now=os.clock()

    -- FOV Circle
    fovCircle.Position=mLoc; fovCircle.Radius=Settings.Aimbot.FovSize; fovCircle.Visible=Settings.Aimbot.ShowFov

    -- Target acquisition (only if needed)
    local needTarget=Settings.Aimbot.Enabled or Settings.Teleport.FollowTP
    local targetHead=needTarget and getClosestTarget(mLoc) or nil

    -- Aimbot
    if Settings.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) and targetHead then
        local sf=math.clamp(1/math.max(1,Settings.Aimbot.Smoothness),0.01,1)
        camera.CFrame=camera.CFrame:Lerp(CFrame.new(camPos,targetHead.Position),sf)
    end

    -- TP Status
    local rem=math.max(0,COOLDOWN_DURATION-(now-lastTeleportTime))
    if isMoving then
        tpStatusLabel.Text="Status: MOVING..."; tpStatusLabel.TextColor3=Color3.fromRGB(255,170,0)
    elseif rem>0 then
        tpStatusLabel.Text=string.format("Status: COOLDOWN %.1fs",rem); tpStatusLabel.TextColor3=Color3.fromRGB(255,80,80)
    else
        tpStatusLabel.Text="Status: READY"; tpStatusLabel.TextColor3=Theme.Accent
    end

    -- Skip ESP entirely if all off
    local espAny=Settings.ESP.Box or Settings.ESP.Corner or Settings.ESP.Name or Settings.ESP.Distance or Settings.ESP.Tracers or Settings.ESP.Skeleton or Settings.ESP.Trails
    local halfW=vp.X*0.5; local botY=vp.Y

    for p,d in pairs(espCache) do
        local char=p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not (char and hrp and hum and hum.Health>0 and not (Settings.TeamCheck and p.Team and player.Team and p.Team==player.Team)) or not espAny then
            hideAllESP(d); d.history={}; continue
        end
        local hrpSP,onScreen=camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then hideAllESP(d); d.history={}; continue end

        local head=char:FindFirstChild("Head")
        local hSP=head and camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.5,0)) or hrpSP
        local lSP=camera:WorldToViewportPoint(hrp.Position-Vector3.new(0,3,0))
        local height=math.abs(hSP.Y-lSP.Y); local width=height*0.65
        local bx=hrpSP.X-width*0.5; local by=hSP.Y
        local bxw=bx+width; local byh=by+height
        local pV2=Vector2.new(hrpSP.X,hrpSP.Y); local bPos=Vector2.new(bx,by); local bSz=Vector2.new(width,height)

        local eCol = WHITE
        if Settings.ESP.TeamColor and p.Team then eCol = p.Team.TeamColor.Color end

        -- Box
        d.box.Visible=Settings.ESP.Box; d.boxOut.Visible=false
        if Settings.ESP.Box then d.boxOut.Position=bPos; d.boxOut.Size=bSz; d.box.Position=bPos; d.box.Size=bSz; d.box.Color=eCol end

        -- Corners
        local cv=Settings.ESP.Corner
        for i=1,8 do d.corners[i].Visible=cv; d.cornersOut[i].Visible=false; d.corners[i].Color=eCol end
        if cv then
            local cL=width*0.25
            _cFrom[1]=Vector2.new(bx,by);   _cTo[1]=Vector2.new(bx+cL,by)
            _cFrom[2]=Vector2.new(bx,by);   _cTo[2]=Vector2.new(bx,by+cL)
            _cFrom[3]=Vector2.new(bxw,by);  _cTo[3]=Vector2.new(bxw-cL,by)
            _cFrom[4]=Vector2.new(bxw,by);  _cTo[4]=Vector2.new(bxw,by+cL)
            _cFrom[5]=Vector2.new(bx,byh);  _cTo[5]=Vector2.new(bx+cL,byh)
            _cFrom[6]=Vector2.new(bx,byh);  _cTo[6]=Vector2.new(bx,byh-cL)
            _cFrom[7]=Vector2.new(bxw,byh); _cTo[7]=Vector2.new(bxw-cL,byh)
            _cFrom[8]=Vector2.new(bxw,byh); _cTo[8]=Vector2.new(bxw,byh-cL)
            for i=1,8 do
                d.corners[i].From=_cFrom[i]; d.corners[i].To=_cTo[i]
                d.cornersOut[i].From=_cFrom[i]; d.cornersOut[i].To=_cTo[i]
            end
        end

        -- Name
        d.name.Visible=Settings.ESP.Name
        if Settings.ESP.Name then d.name.Text=p.Name; d.name.Position=Vector2.new(hrpSP.X,by-18) end

        -- Distance
        d.distance.Visible=Settings.ESP.Distance
        if Settings.ESP.Distance then d.distance.Text=math.floor((hrp.Position-camPos).Magnitude).."m"; d.distance.Position=Vector2.new(hrpSP.X,byh+2) end

        -- Tracer
        d.tracer.Visible=Settings.ESP.Tracers; d.tracerOut.Visible=false
        if Settings.ESP.Tracers then
            local fV=Vector2.new(halfW,botY)
            d.tracerOut.From=fV; d.tracerOut.To=pV2; d.tracer.From=fV; d.tracer.To=pV2; d.tracer.Color=eCol
        end

        -- Skeleton
        if Settings.ESP.Skeleton then
            local isR6=char:FindFirstChild("Torso")~=nil
            local bpairs=isR6 and bonePairsR6 or bonePairsR15
            local idx=1
            for _,pair in ipairs(bpairs) do
                local pA=char:FindFirstChild(pair[1]); local pB=char:FindFirstChild(pair[2])
                if pA and pB then
                    local wA = pA.CFrame; if pair[3] then wA = wA * CFrame.new(pair[3]) end
                    local wB = pB.CFrame; if pair[4] then wB = wB * CFrame.new(pair[4]) end
                    local spA,vA=camera:WorldToViewportPoint(wA.Position)
                    local spB,vB=camera:WorldToViewportPoint(wB.Position)
                    if not d.skelLines[idx] then d.skelOut[idx]=newLine(3,BLACK); d.skelLines[idx]=newLine(1.5,eCol) end
                    local lo=d.skelOut[idx]; local l=d.skelLines[idx]; l.Color=eCol
                    if vA and vB then
                        local f=Vector2.new(spA.X,spA.Y); local t=Vector2.new(spB.X,spB.Y)
                        lo.From=f; lo.To=t; lo.Visible=false; l.From=f; l.To=t; l.Visible=true
                    else lo.Visible=false; l.Visible=false end
                    idx+=1
                end
            end
            for i=idx,#d.skelLines do
                if d.skelLines[i] then d.skelLines[i].Visible=false end
                if d.skelOut[i] then d.skelOut[i].Visible=false end
            end
        else
            for _,l in pairs(d.skelLines) do l.Visible=false end
            for _,l in pairs(d.skelOut) do l.Visible=false end
        end

        -- Trails
        if Settings.ESP.Trails then
            local hist=d.history; hist[#hist+1]=hrp.Position
            if #hist>12 then table.remove(hist,1) end
            for i=1,#hist-1 do
                local p1,v1=camera:WorldToViewportPoint(hist[i])
                local p2,v2=camera:WorldToViewportPoint(hist[i+1])
                if not d.trailLines[i] then d.trailOut[i]=newLine(3.5,BLACK); d.trailLines[i]=newLine(2,Color3.fromRGB(255,200,0)) end
                local tlo=d.trailOut[i]; local tl=d.trailLines[i]
                if v1 and v2 then
                    local f=Vector2.new(p1.X,p1.Y); local t=Vector2.new(p2.X,p2.Y)
                    tlo.From=f; tlo.To=t; tlo.Visible=true; tl.From=f; tl.To=t; tl.Visible=true
                else tlo.Visible=false; tl.Visible=false end
            end
        else
            d.history={}
            for _,l in pairs(d.trailLines) do l.Visible=false end
            for _,l in pairs(d.trailOut) do l.Visible=false end
        end
    end
end)

--------------------------------------------------------------------------------
-- MOVEMENT LOGIC
--------------------------------------------------------------------------------
local rs = game:GetService("ReplicatedStorage")
if rs then
    task.spawn(function()
        local scriptsFolder = rs:WaitForChild("Scripts", 5)
        if scriptsFolder then
            local CharacterCollision = scriptsFolder:FindFirstChild("CharacterCollision")
            if CharacterCollision then CharacterCollision:Destroy() end
        end
    end)
end

UserInputService.JumpRequest:Connect(function()
    if Settings.Movement.InfJump and player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local function SetupCharacter(Character)
    local Humanoid = Character:WaitForChild("Humanoid", 3)
    local Head = Character:WaitForChild("Head", 3)
    
    if Humanoid then
        task.spawn(function()
            local Jump = Humanoid:GetPropertyChangedSignal("Jump")
            task.wait(1)
            if getconnections then
                for _, Connection in pairs(getconnections(Jump)) do Connection:Disable() end
            end
        end)
    end
    
    if Head then
        task.spawn(function()
            if getconnections then
                for _, Connection in pairs(getconnections(Head:GetPropertyChangedSignal("CanCollide"))) do Connection:Disable() end
            end
        end)
    end

    task.spawn(function()
        while Character and Character.Parent and Humanoid and Humanoid.Health > 0 do
            task.wait()
            
            local root = Character:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            if Settings.Movement.Noclip then
                for _, v in pairs(Character:GetDescendants()) do
                    if v:IsA('BasePart') and v.CanCollide then
                        v.CanCollide = false
                    end
                end
            end
            if Settings.Movement.BHop then
                if Humanoid.FloorMaterial ~= Enum.Material.Air then
                    Humanoid.Jump = true
                end
            end
            if Settings.Movement.Spinbot then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(50), 0)
            end
            if Settings.Movement.AntiAim then
                root.CFrame = root.CFrame * CFrame.new(math.random(-1,1)*0.05, 0, math.random(-1,1)*0.05)
            end
            if Settings.Movement.AntiVoid then
                if root.Position.Y < -50 then
                    root.CFrame = root.CFrame + Vector3.new(0, 150, 0)
                    local platform = Instance.new("Part")
                    platform.Size = Vector3.new(10, 1, 10); platform.Anchored = true; platform.Position = root.Position - Vector3.new(0, 3, 0)
                    platform.Parent = Workspace; game.Debris:AddItem(platform, 3)
                end
            end
        end
    end)
end

if player.Character then SetupCharacter(player.Character) end
player.CharacterAdded:Connect(SetupCharacter)

