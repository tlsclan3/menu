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

-- [REST OF FILE TRUNCATED FOR BACKUP - This is the original unmodified version]
