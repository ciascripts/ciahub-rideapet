--============================================================
-- CiaHub • RIDE A PET
-- USE BUNDLED CIAHUB UI
-- AUTO STEAL + FLY/TELEPORT MODE
-- EGG ESP + SAVE POINT
-- ENGLISH • MOBILE
--============================================================

--============================================================
-- 1. SERVICES
--============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--============================================================
-- 2. GAME CHECK
--============================================================

if game.PlaceId ~= 124216119978534 then
    warn("[CiaHub] This script is for Ride a Pet.")
    return
end

--============================================================
-- 3. BUNDLED CIAHUB UI
--============================================================

-- UI is bundled below; no external UI download is needed.

--============================================================
-- 4. CONFIG
--============================================================

local Config = {

    AutoSteal = false,

    StealMode = "Teleport",

    Priority = "Highest Luck",

    Speed = 300,
    MinSpeed = 40,
    MaxSpeed = 1000,

    EggESP = false,

    SavedPoint = nil,

    Language = "EN",

    Stop = false,

    Busy = false
}

--============================================================
-- 5. COLORS
--============================================================

local ACCENT = Color3.fromRGB(172, 255, 104)
local DARK_BUTTON = Color3.fromRGB(22, 28, 35)

--============================================================
-- 6. LANGUAGE
--============================================================

local Lang = {

    EN = {

        AutoSteal =
            "Auto steal",

        TeleportMode =
            "Teleport to egg · Fly back",

        FlyMode =
            "Fly to egg · Fly back",

        CurrentMode =
            "Print current mode",

        Stop =
            "Stop auto steal",

        HighestLuck =
            "Prioritize highest luck",

        Rarest =
            "Prioritize rarest egg",

        SavePoint =
            "Save current position",

        FlyPoint =
            "Fly to saved position",

        ClearPoint =
            "Clear saved position",

        EggESP =
            "Egg ESP",

        ClearESP =
            "Clear egg markers",

        Speed =
            "Flight speed",

        Vietnamese =
            "Vietnamese",

        English =
            "English"
    }
}

local function T(Name)

    return Lang[
        Config.Language
    ][Name]
end

--============================================================
-- 7. GAME OBJECTS
--============================================================

local GameRemotes = nil
local ActiveEggs = nil
local EggsModule = nil

pcall(function()

    local Remotes =
        ReplicatedStorage:FindFirstChild(
            "Remotes"
        )

    if Remotes then

        GameRemotes =
            Remotes:FindFirstChild(
                "Game"
            )
    end

    local ServerData =
        ReplicatedStorage:FindFirstChild(
            "ServerData"
        )

    if ServerData then

        ActiveEggs =
            ServerData:FindFirstChild(
                "ActiveEggs"
            )
    end

    local GameData =
        ReplicatedStorage:FindFirstChild(
            "GameData"
        )

    if GameData then

        local Eggs =
            GameData:FindFirstChild(
                "Eggs"
            )

        if Eggs then

            EggsModule =
                require(Eggs)
        end
    end
end)

--============================================================
-- 8. CHARACTER
--============================================================

local function GetCharacter()

    local Character =
        Player.Character

    if not Character then
        return nil, nil, nil
    end

    local Humanoid =
        Character:FindFirstChildOfClass(
            "Humanoid"
        )

    local Root =
        Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not Humanoid
        or not Root then

        return nil, nil, nil
    end

    if Humanoid.Health <= 0 then

        return nil, nil, nil
    end

    return Character,
        Humanoid,
        Root
end

--============================================================
-- 9. EGG RARITY
--============================================================

local RarityOrder = {

    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4,
    Mythic = 5,
    Divine = 6,
    Ethereal = 7
}

--============================================================
-- 10. EGG INFO
--============================================================

local function GetEggInfo(Egg)

    if not Egg then

        return nil,
            0,
            "Common"
    end

    local EggName =
        Egg:GetAttribute(
            "Egg"
        )

    if not EggName then

        return nil,
            0,
            "Common"
    end

    local Luck =
        tonumber(
            Egg:GetAttribute(
                "Luck"
            )
        ) or 0

    local Rarity =
        "Common"

    if EggsModule then

        pcall(function()

            local Data =
                EggsModule[EggName]

            if type(Data) == "table" then

                Luck =
                    tonumber(
                        Data.Luck
                    )
                    or Luck

                Rarity =
                    Data.Rarity
                    or Rarity
            end
        end)
    end

    return EggName,
        Luck,
        Rarity
end

--============================================================
-- 11. FIND BEST EGG
--============================================================

local function FindBestEgg()

    if not ActiveEggs then
        return nil
    end

    local _, _, Root =
        GetCharacter()

    if not Root then
        return nil
    end

    local BestEgg =
        nil

    local BestScore =
        -math.huge

    for _, Egg in ipairs(
        ActiveEggs:GetChildren()
    ) do

        local EggName,
            Luck,
            Rarity =
            GetEggInfo(Egg)

        local Position =
            Egg:GetAttribute(
                "Position"
            )

        if EggName
            and typeof(Position)
            == "Vector3" then

            local Distance =
                (
                    Root.Position
                    - Position
                ).Magnitude

            local Score

            if Config.Priority
                == "Highest Luck" then

                Score =
                    Luck * 100000
                    - Distance

            else

                local RarityValue =
                    RarityOrder[Rarity]
                    or 1

                Score =
                    RarityValue
                    * 100000
                    + Luck * 1000
                    - Distance
            end

            if Score > BestScore then

                BestScore =
                    Score

                BestEgg = {

                    Object = Egg,

                    Name = EggName,

                    Luck = Luck,

                    Rarity = Rarity,

                    Position = Position
                }
            end
        end
    end

    return BestEgg
end

--============================================================
-- 12. STOP MOVEMENT
--============================================================

local CurrentTween = nil

local function StopMovement()

    Config.Stop =
        true

    if CurrentTween then

        pcall(function()

            CurrentTween:Cancel()

        end)

        CurrentTween =
            nil
    end

    local Character,
        Humanoid,
        Root =
        GetCharacter()

    if Root then

        Root.AssemblyLinearVelocity =
            Vector3.zero

        Root.AssemblyAngularVelocity =
            Vector3.zero
    end

    if Humanoid then

        Humanoid.PlatformStand =
            false

        Humanoid.AutoRotate =
            true
    end
end

--============================================================
-- 13. FLIGHT WITH ARRIVAL VERIFICATION
--============================================================
local FlightBusy = false
local function FlyTo(Position)
    if typeof(Position) ~= "Vector3" or FlightBusy then return false end
    local Character, Humanoid, Root = GetCharacter()
    if not Root then return false end
    FlightBusy = true
    Config.Stop = false
    local collisions = {}
    local oldStand, oldRotate = Humanoid.PlatformStand, Humanoid.AutoRotate
    local rotation = Root.CFrame.Rotation
    local arrived = false
    local stepConnection
    local ok, err = pcall(function()
        Humanoid.PlatformStand = true
        Humanoid.AutoRotate = false
        -- Keep physics from fighting the tween, including newly added parts.
        stepConnection = game:GetService("RunService").Stepped:Connect(function()
            if not Root.Parent then return end
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if collisions[part] == nil then collisions[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
        -- Recheck after settling. A completed tween alone is not proof of arrival.
        for attempt = 1, 3 do
            if Config.Stop or Humanoid.Health <= 0 or not Root.Parent then break end
            local distance = (Root.Position - Position).Magnitude
            if distance > 1.5 then
                local speed = math.clamp(tonumber(Config.Speed) or 300, Config.MinSpeed, Config.MaxSpeed)
                local tween = TweenService:Create(Root,
                    TweenInfo.new(math.max(0.1, distance / speed), Enum.EasingStyle.Linear),
                    {CFrame = CFrame.new(Position) * rotation})
                CurrentTween = tween
                tween:Play()
                repeat
                    task.wait()
                    if Config.Stop or Humanoid.Health <= 0 or not Root.Parent then tween:Cancel();break end
                until tween.PlaybackState ~= Enum.PlaybackState.Playing
                if CurrentTween == tween then CurrentTween = nil end
                if tween.PlaybackState ~= Enum.PlaybackState.Completed then break end
            end
            task.wait(0.25)
            if not Config.Stop and Root.Parent and Humanoid.Health > 0
                and (Root.Position - Position).Magnitude <= 3 then
                arrived = true
                break
            end
        end
    end)
    if stepConnection then stepConnection:Disconnect() end
    if CurrentTween then CurrentTween:Cancel();CurrentTween = nil end
    for part, value in pairs(collisions) do
        if part.Parent then part.CanCollide = value end
    end
    if Humanoid.Parent then Humanoid.PlatformStand = oldStand;Humanoid.AutoRotate = oldRotate end
    if Root.Parent then
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end
    FlightBusy = false
    if not ok then warn("[CiaHub] Flight failed: " .. tostring(err)) end
    if arrived then
        task.wait(0.2)
        arrived = not Config.Stop and Root.Parent ~= nil and Humanoid.Health > 0
            and (Root.Position - Position).Magnitude <= 5
    end
    return ok and arrived
end

--============================================================
-- 14. TELEPORT
--============================================================

local function TeleportTo(Position)

    local _, _, Root =
        GetCharacter()

    if not Root then
        return false
    end

    Root.AssemblyLinearVelocity =
        Vector3.zero

    Root.AssemblyAngularVelocity =
        Vector3.zero

    Root.CFrame =
        CFrame.new(
            Position
        )
        * Root.CFrame.Rotation

    return true
end

--============================================================
-- 15. OWNED PLOT SURFACE
--============================================================
local function GetPlotPosition()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local data = plot:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        local mine = false
        if owner then
            pcall(function()
                mine = owner.Value == Player or tostring(owner.Value) == tostring(Player.UserId)
                    or owner.Value == Player.Name
            end)
        end
        if mine then
            local base = plot:FindFirstChild("Baseplate", true)
            if base and base:IsA("BasePart") then
                local _, humanoid, root = GetCharacter()
                local clearance = humanoid and root and (humanoid.HipHeight + root.Size.Y / 2 + 1) or 4
                -- Aim above the top surface, rather than inside a thick baseplate.
                return base.CFrame:PointToWorldSpace(Vector3.new(0, base.Size.Y / 2, 0))
                    + Vector3.new(0, clearance, 0)
            end
        end
    end
    return nil
end

--============================================================
-- 16. RETURN POSITION
--============================================================

local function GetReturnPosition()

    if Config.SavedPoint then

        return Config.SavedPoint.Position
    end

    return GetPlotPosition()
end

--============================================================
-- 17. PICKUP
--============================================================

local function GetBasketCount()

    local Basket =
        Player:FindFirstChild(
            "Basket"
        )

    if not Basket then
        return 0
    end

    return #Basket:GetChildren()
end

local function PickupEgg(Egg)

    if not Egg then
        return false
    end

    if not GameRemotes then
        return false
    end

    local Remote =
        GameRemotes:FindFirstChild(
            "EggPickup"
        )

    if not Remote then
        return false
    end

    local Before =
        GetBasketCount()

    pcall(function()

        if Remote:IsA(
            "RemoteEvent"
        ) then

            Remote:FireServer(
                Egg.Object.Name
            )

        elseif Remote:IsA(
            "RemoteFunction"
        ) then

            Remote:InvokeServer(
                Egg.Object.Name
            )
        end
    end)

    local EndTime =
        os.clock() + 2

    while os.clock()
        < EndTime do

        if Config.Stop then
            return false
        end

        if GetBasketCount()
            > Before then

            return true
        end

        task.wait(0.05)
    end

    return false
end

--============================================================
-- 18. FLY BACK
--============================================================

local function FlyBack()

    local Target =
        GetReturnPosition()

    if not Target then

        warn(
            "[CiaHub] Plot not found. Save a return position at your plot."
        )

        return false
    end

    return FlyTo(Target)
end

--============================================================
-- 19. AUTO STEAL
--============================================================

local function AutoStealLoop()

    if Config.Busy then
        return
    end

    Config.Busy =
        true

    Config.Stop =
        false

    task.spawn(function()

        while Config.AutoSteal do

            if Config.Stop then
                break
            end

            local BestEgg =
                FindBestEgg()

            if not BestEgg then

                task.wait(0.4)

                continue
            end

            if not BestEgg.Object
                or not BestEgg.Object.Parent then

                task.wait(0.1)

                continue
            end

            local EggPosition =
                BestEgg.Position
                + Vector3.new(
                    0,
                    3,
                    0
                )

            --================================================
            -- ĐI TỚI TRỨNG
            --================================================

            local Reached = false

            if Config.StealMode
                == "Teleport" then

                Reached =
                    TeleportTo(
                        EggPosition
                    )

                task.wait(0.15)

            else

                Reached =
                    FlyTo(
                        EggPosition
                    )
            end

            if not Reached then

                task.wait(0.2)

                continue
            end

            --================================================
            -- PICKUP
            --================================================

            local Picked =
                false

            for i = 1, 3 do

                if not Config.AutoSteal
                    or Config.Stop then

                    break
                end

                Picked =
                    PickupEgg(
                        BestEgg
                    )

                if Picked then
                    break
                end

                task.wait(0.1)
            end

            --================================================
            -- BAY VỀ
            --================================================

            if Picked then

                if not FlyBack() then
                    warn("[CiaHub] Return failed. Stand at your plot delivery spot and use Save current position, then restart.")
                    Config.AutoSteal = false
                    Config.Stop = true
                    break
                end

            else

                task.wait(0.3)
            end

            task.wait(0.2)
        end

        Config.Busy =
            false
    end)
end

--============================================================
-- 20. EGG ESP
--============================================================

local ESPObjects = {}

local function RemoveESP(Egg)

    local Object =
        ESPObjects[Egg]

    if Object then

        pcall(function()

            Object:Destroy()

        end)

        ESPObjects[Egg] =
            nil
    end
end

local function CreateESP(Egg)

    if not Config.EggESP then
        return
    end

    local EggName,
        Luck =
        GetEggInfo(Egg)

    local Position =
        Egg:GetAttribute(
            "Position"
        )

    if not EggName
        or typeof(Position)
        ~= "Vector3" then

        return
    end

    local Part =
        ESPObjects[Egg]

    if not Part then

        Part =
            Instance.new("Part")

        Part.Name =
            "CIAHUB_EGG_ESP"

        Part.Size =
            Vector3.new(
                0.1,
                0.1,
                0.1
            )

        Part.Transparency =
            1

        Part.Anchored =
            true

        Part.CanCollide =
            false

        Part.CanTouch =
            false

        Part.CanQuery =
            false

        Part.Parent =
            workspace

        local Billboard =
            Instance.new(
                "BillboardGui"
            )

        Billboard.Size =
            UDim2.new(
                0,
                180,
                0,
                45
            )

        Billboard.StudsOffset =
            Vector3.new(
                0,
                3,
                0
            )

        Billboard.AlwaysOnTop =
            true

        Billboard.Parent =
            Part

        local Text =
            Instance.new(
                "TextLabel"
            )

        Text.Name =
            "Text"

        Text.Size =
            UDim2.fromScale(
                1,
                1
            )

        Text.BackgroundTransparency =
            1

        Text.TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            )

        Text.TextStrokeTransparency =
            0

        Text.Font =
            Enum.Font.GothamBold

        Text.TextSize =
            14

        Text.Parent =
            Billboard

        ESPObjects[Egg] =
            Part
    end

    Part.CFrame =
        CFrame.new(
            Position
        )

    local Billboard =
        Part:FindFirstChildOfClass(
            "BillboardGui"
        )

    if Billboard then

        local Text =
            Billboard:FindFirstChild(
                "Text"
            )

        if Text then

            Text.Text =
                tostring(
                    EggName
                )
                .. "\nLuck: "
                .. tostring(
                    Luck
                )
                .. "x"
        end
    end
end

local function UpdateESP()

    if not Config.EggESP then
        return
    end

    if not ActiveEggs then
        return
    end

    local Existing = {}

    for _, Egg in ipairs(
        ActiveEggs:GetChildren()
    ) do

        Existing[Egg] =
            true

        pcall(function()

            CreateESP(Egg)

        end)
    end

    for Egg in pairs(
        ESPObjects
    ) do

        if not Existing[Egg]
            or not Egg.Parent then

            RemoveESP(Egg)
        end
    end
end

local function ClearESP()

    for Egg in pairs(
        ESPObjects
    ) do

        RemoveESP(Egg)
    end
end

task.spawn(function()

    while task.wait(0.2) do

        if Config.EggESP then

            pcall(
                UpdateESP
            )
        end
    end
end)

--============================================================
-- 21. LOAD CIAHUB UI
--============================================================

-- UI adapted from the supplied Minh Kha library.
local function LoadLibrary()
    local UIS = game:GetService("UserInputService")
    local palette = {
        base = Color3.fromRGB(13,17,22), card = Color3.fromRGB(22,28,35),
        edge = Color3.fromRGB(43,53,64), text = Color3.fromRGB(240,245,248),
        muted = Color3.fromRGB(146,161,174), lime = Color3.fromRGB(172,255,104)
    }
    local old = PlayerGui:FindFirstChild("CiaHub_RideAPet")
    if old then old:Destroy() end
    local connections = {}
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(connections, connection)
        return connection
    end
    local function make(class, props, parent)
        local object = Instance.new(class)
        for key,value in pairs(props) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function corner(object, radius)
        make("UICorner", {CornerRadius=UDim.new(0,radius or 5)}, object)
    end
    local function stroke(object, color)
        return make("UIStroke", {Color=color or palette.edge, Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, object)
    end
    local function animate(object, props)
        TweenService:Create(object, TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props):Play()
    end
    local function label(parent, text, size, position, dimensions, color, font)
        return make("TextLabel", {Text=text, TextSize=size, Font=font or Enum.Font.Gotham,
            TextColor3=color or palette.text, BackgroundTransparency=1, Position=position, Size=dimensions,
            TextXAlignment=Enum.TextXAlignment.Left},parent)
    end
    local function button(parent, text, size, position)
        local object = make("TextButton",{Text=text,Size=size,Position=position or UDim2.new(),
            BackgroundColor3=palette.card,BorderSizePixel=0,AutoButtonColor=false,
            TextColor3=palette.text,TextSize=14,Font=Enum.Font.GothamMedium},parent)
        corner(object)
        local outline=stroke(object)
        connect(object.MouseEnter,function() animate(outline,{Color=palette.lime}) end)
        connect(object.MouseLeave,function() animate(outline,{Color=palette.edge}) end)
        return object
    end
    local gui=make("ScreenGui",{Name="CiaHub_RideAPet",ResetOnSpawn=false,IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=30},PlayerGui)
    gui.Destroying:Connect(function()
        for _,connection in ipairs(connections) do connection:Disconnect() end
    end)
    local main=make("Frame",{Size=UDim2.fromOffset(620,460),AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),BackgroundColor3=palette.base,BorderSizePixel=0,ClipsDescendants=true},gui)
    corner(main,7);stroke(main)
    local scale=make("UIScale",{Scale=1},main)
    local cameraConnection
    local function fit()
        local camera=workspace.CurrentCamera
        if camera then
            scale.Scale=math.max(.1, math.min(1,(camera.ViewportSize.X-24)/620,(camera.ViewportSize.Y-24)/460))
        end
    end
    local function bindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        if workspace.CurrentCamera then cameraConnection=connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end
        fit()
    end
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"),bindCamera);bindCamera()
    make("Frame",{Size=UDim2.new(1,0,0,3),BackgroundColor3=palette.lime,BorderSizePixel=0},main)
    local top=make("Frame",{Size=UDim2.new(1,-70,0,76),BackgroundTransparency=1,Active=true},main)
    label(top,"CiaHub",27,UDim2.fromOffset(22,15),UDim2.fromOffset(180,32),palette.text,Enum.Font.GothamBold)
    label(top,"RIDE A PET / CIASCRIPTS",11,UDim2.fromOffset(23,49),UDim2.fromOffset(300,18),palette.muted,Enum.Font.Code)
    local close=button(main,"−",UDim2.fromOffset(34,32),UDim2.new(1,-52,0,23))
    close.TextSize=22
    make("Frame",{Position=UDim2.fromOffset(0,76),Size=UDim2.new(1,0,0,1),BackgroundColor3=palette.edge,BorderSizePixel=0},main)
    local nav=make("Frame",{Position=UDim2.fromOffset(16,93),Size=UDim2.new(0,142,1,-137),BackgroundTransparency=1},main)
    make("UIListLayout",{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},nav)
    local content=make("Frame",{Position=UDim2.fromOffset(176,93),Size=UDim2.new(1,-194,1,-137),BackgroundTransparency=1},main)
    local title=label(content,"",19,UDim2.new(),UDim2.new(1,0,0,26),palette.text,Enum.Font.GothamBold)
    local description=label(content,"",12,UDim2.fromOffset(0,30),UDim2.new(1,0,0,20),palette.muted)
    make("Frame",{Position=UDim2.new(0,16,1,-34),Size=UDim2.new(1,-32,0,1),BackgroundColor3=palette.edge,BorderSizePixel=0},main)
    label(main,"CIA / RIDE A PET",10,UDim2.new(0,22,1,-27),UDim2.fromOffset(200,18),palette.muted,Enum.Font.Code)
    local status=label(main,"READY",10,UDim2.new(1,-160,1,-27),UDim2.fromOffset(138,18),palette.lime,Enum.Font.Code)
    status.TextXAlignment=Enum.TextXAlignment.Right
    local launcher=button(gui,"CIA",UDim2.fromOffset(58,40),UDim2.new(0,18,.5,-20))
    launcher.TextColor3=palette.lime;launcher.Font=Enum.Font.GothamBold
    local opening=false
    local function show()
        if opening then return end
        opening=true
        main.Visible=not main.Visible
        if main.Visible then
            fit();local target=scale.Scale;scale.Scale=target*.97;animate(scale,{Scale=target})
        end
        task.delay(.18,function() opening=false end)
    end
    connect(close.Activated,show)
    local function draggable(handle,target,onClick)
        local active,start,origin,moved
        connect(handle.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                active=input;start=input.Position;origin=target.Position;moved=false
            end
        end)
        connect(UIS.InputChanged,function(input)
            if active and (input==active or (active.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)) then
                local delta=input.Position-start
                if delta.Magnitude>5 then moved=true end
                if moved then target.Position=UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,origin.Y.Scale,origin.Y.Offset+delta.Y) end
            end
        end)
        connect(UIS.InputEnded,function(input)
            if input==active then active=nil;if onClick and not moved then onClick() end end
        end)
    end
    draggable(top,main);draggable(launcher,launcher,show)
    local pages={}
    local Library={}
    local descriptions={['Auto Steal']='Choose your travel mode and egg priority.',Point='Save a destination and return to it.',['Egg ESP']='Track eggs and their luck values.',Settings='Adjust flight speed from 40 to 1,000 studs/s.'}
    local function run(callback,...)
        local ok,err=pcall(callback,...)
        if not ok then status.Text='ACTION ERROR';warn('[CiaHub] '..tostring(err)) end
    end
    function Library:CreateTab(name)
        name=name:gsub('^[^%a]+','')
        local index=#pages+1
        local tab=button(nav,string.format('%02d  %s',index,name),UDim2.new(1,0,0,44))
        tab.TextXAlignment=Enum.TextXAlignment.Left
        make('UIPadding',{PaddingLeft=UDim.new(0,12)},tab)
        local page=make('ScrollingFrame',{Position=UDim2.fromOffset(0,64),Size=UDim2.new(1,0,1,-64),
            BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=palette.lime,
            CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},content)
        make('UIPadding',{PaddingTop=UDim.new(0,2),PaddingLeft=UDim.new(0,2),PaddingBottom=UDim.new(0,4),PaddingRight=UDim.new(0,8)},page)
        make('UIListLayout',{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},page)
        table.insert(pages,{page=page,tab=tab})
        local function select()
            for _,entry in ipairs(pages) do
                entry.page.Visible=entry.page==page
                animate(entry.tab,{BackgroundColor3=entry.tab==tab and palette.lime or palette.card,
                    TextColor3=entry.tab==tab and palette.base or palette.muted})
            end
            title.Text=name;description.Text=descriptions[name] or '';page.CanvasPosition=Vector2.zero
        end
        connect(tab.Activated,select)
        if index==1 then select() end
        local api={}
        function api:CreateButton(text,callback)
            local control=button(page,text,UDim2.new(1,0,0,46))
            control.TextXAlignment=Enum.TextXAlignment.Left
            make('UIPadding',{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,12)},control)
            connect(control.Activated,function() run(callback) end)
            return control
        end
        function api:CreateToggle(text,default,callback)
            local row=button(page,'',UDim2.new(1,0,0,52))
            label(row,text,14,UDim2.fromOffset(14,0),UDim2.new(1,-90,1,0),palette.text,Enum.Font.GothamMedium)
            local track=make('Frame',{Size=UDim2.fromOffset(42,22),Position=UDim2.new(1,-56,.5,-11),BorderSizePixel=0,BackgroundColor3=palette.edge},row)
            corner(track,4)
            local knob=make('Frame',{Size=UDim2.fromOffset(16,16),Position=UDim2.fromOffset(3,3),BorderSizePixel=0,BackgroundColor3=palette.text},track)
            corner(knob,2)
            local enabled=default
            local function update()
                animate(track,{BackgroundColor3=enabled and palette.lime or palette.edge})
                animate(knob,{Position=UDim2.fromOffset(enabled and 23 or 3,3),BackgroundColor3=enabled and palette.base or palette.text})
                run(callback,enabled)
            end
            connect(row.Activated,function() enabled=not enabled;update() end)
            update()
        end
        function api:CreateDropdown(text, options, default, callback)
            local height = 68
            local row = make("Frame", {Size=UDim2.new(1,0,0,height),BackgroundColor3=palette.card,
                BorderSizePixel=0,ClipsDescendants=true},page)
            corner(row);stroke(row)
            label(row,text,11,UDim2.fromOffset(14,7),UDim2.new(1,-28,0,18),palette.muted,Enum.Font.GothamMedium)
            local selected=button(row,default .. "  v",UDim2.new(1,-20,0,32),UDim2.fromOffset(10,28))
            selected.TextColor3=palette.lime
            local expanded=false
            local choices={}
            local function expand(value)
                expanded=value
                animate(row,{Size=UDim2.new(1,0,0,expanded and height+#options*38+6 or height)})
            end
            connect(selected.Activated,function() expand(not expanded) end)
            for index,option in ipairs(options) do
                local choice=button(row,option,UDim2.new(1,-20,0,32),UDim2.fromOffset(10,height+(index-1)*38))
                choices[option]=choice
                choice.TextColor3=option==default and palette.lime or palette.text
                connect(choice.Activated,function()
                    selected.Text=option .. "  v"
                    for name,item in pairs(choices) do item.TextColor3=name==option and palette.lime or palette.text end
                    expand(false);run(callback,option)
                end)
            end
        end
        function api:CreateInput(text,default,callback)
            local row=make('Frame',{Size=UDim2.new(1,0,0,90),BackgroundColor3=palette.card,BorderSizePixel=0},page)
            corner(row);stroke(row)
            label(row,text,14,UDim2.fromOffset(14,10),UDim2.new(1,-110,0,28),palette.text,Enum.Font.GothamMedium)
            local box=make('TextBox',{Position=UDim2.new(1,-82,0,10),Size=UDim2.fromOffset(68,28),BackgroundColor3=palette.base,
                BorderSizePixel=0,Text=tostring(default),TextColor3=palette.lime,TextSize=14,Font=Enum.Font.Code,ClearTextOnFocus=false},row)
            corner(box,3);stroke(box)
            local hit=make('TextButton',{Text='',Position=UDim2.fromOffset(14,43),Size=UDim2.new(1,-28,0,30),BackgroundTransparency=1},row)
            local bar=make('Frame',{Position=UDim2.new(0,0,.5,-2),Size=UDim2.new(1,0,0,4),BackgroundColor3=palette.edge,BorderSizePixel=0},hit)
            local fill=make('Frame',{Size=UDim2.new(),BackgroundColor3=palette.lime,BorderSizePixel=0},bar)
            local thumb=make('Frame',{Size=UDim2.fromOffset(10,14),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=palette.lime,BorderSizePixel=0},bar)
            corner(thumb,2)
            local value=default
            local function set(number)
                value=math.clamp(math.floor(number+.5),Config.MinSpeed,Config.MaxSpeed)
                local ratio=(value-Config.MinSpeed)/(Config.MaxSpeed-Config.MinSpeed)
                box.Text=tostring(value);fill.Size=UDim2.new(ratio,0,1,0);thumb.Position=UDim2.fromScale(ratio,.5)
                run(callback,value)
            end
            local sliding
            local function pointer(input)
                set(Config.MinSpeed+math.clamp((input.Position.X-bar.AbsolutePosition.X)/math.max(1,bar.AbsoluteSize.X),0,1)*(Config.MaxSpeed-Config.MinSpeed))
            end
            connect(hit.InputBegan,function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then sliding=input;pointer(input) end
            end)
            connect(UIS.InputChanged,function(input)
                if sliding and (input==sliding or (sliding.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)) then pointer(input) end
            end)
            connect(UIS.InputEnded,function(input) if input==sliding then sliding=nil end end)
            connect(box.FocusLost,function() set(tonumber(box.Text) or value) end)
            set(default)
        end
        return api
    end
    return Library
end

local Library = LoadLibrary()

--============================================================
-- 22. CREATE TABS
--============================================================

local MainTab =
    Library:CreateTab(
        "🥚 Auto Steal"
    )

local PointTab =
    Library:CreateTab(
        "📍 Point"
    )

local ESPTab =
    Library:CreateTab(
        "👁️ Egg ESP"
    )

local SettingsTab =
    Library:CreateTab(
        "⚙️ Settings"
    )

-- Dropdown selections display the active mode and priority directly.

--============================================================
-- 25. AUTO STEAL TOGGLE
--============================================================

MainTab:CreateToggle(

    T("AutoSteal"),

    false,

    function(State)

        Config.AutoSteal =
            State

        if State then

            Config.Stop =
                false

            AutoStealLoop()

        else

            Config.Stop =
                true

            StopMovement()
        end
    end
)

--============================================================
-- 26. TRAVEL MODE
--============================================================
MainTab:CreateDropdown("Steal mode", {"Teleport to egg / Fly back", "Fly both ways"},
    "Teleport to egg / Fly back", function(value)
        Config.StealMode = value == "Fly both ways" and "Fly" or "Teleport"
    end)

--============================================================
-- 29. STOP
--============================================================

MainTab:CreateButton(

    T("Stop"),

    function()

        Config.AutoSteal =
            false

        Config.Stop =
            true

        StopMovement()
    end
)

--============================================================
-- 30. EGG PRIORITY
--============================================================
MainTab:CreateDropdown("Prioritize", {"Highest Luck", "Rarest"}, Config.Priority, function(value)
    Config.Priority = value
end)

--============================================================
-- 31. POINT
--============================================================

PointTab:CreateButton(

    T("SavePoint"),

    function()

        local _, _, Root =
            GetCharacter()

        if not Root then
            return
        end

        Config.SavedPoint =
            Root.CFrame

        print(
            "[CiaHub] Point saved."
        )
    end
)

PointTab:CreateButton(

    T("FlyPoint"),

    function()

        if not Config.SavedPoint then

            warn(
                "[CiaHub] Save a return position first."
            )

            return
        end

        task.spawn(function()

            FlyTo(
                Config.SavedPoint.Position
            )
        end)
    end
)

PointTab:CreateButton(

    T("ClearPoint"),

    function()

        Config.SavedPoint =
            nil
    end
)

--============================================================
-- 32. ESP
--============================================================

ESPTab:CreateToggle(

    T("EggESP"),

    false,

    function(State)

        Config.EggESP =
            State

        if State then

            UpdateESP()

        else

            ClearESP()
        end
    end
)

ESPTab:CreateButton(

    T("ClearESP"),

    function()

        ClearESP()
    end
)

--============================================================
-- 33. SETTINGS
--============================================================

SettingsTab:CreateInput(

    T("Speed"),

    300,

    function(Value)

        Config.Speed =
            math.clamp(
                tonumber(Value)
                    or 300,

                Config.MinSpeed,
                Config.MaxSpeed
            )

        print(
            "[CiaHub] Fly Speed:",
            Config.Speed
        )
    end
)

--============================================================
-- 34. ACTIVE EGG EVENTS
--============================================================

if ActiveEggs then

    ActiveEggs.ChildAdded:Connect(

        function(Egg)

            if Config.EggESP then

                task.wait(0.05)

                pcall(function()

                    CreateESP(Egg)

                end)
            end
        end
    )

    ActiveEggs.ChildRemoved:Connect(

        function(Egg)

            RemoveESP(Egg)
        end
    )
end

-- Dropdowns initialize their selected values during construction.

--============================================================
-- 36. RESPAWN
--============================================================

Player.CharacterAdded:Connect(

    function()

        Config.Stop =
            true

        task.wait(1)

        if Config.AutoSteal then

            Config.Busy =
                false

            Config.Stop =
                false

            AutoStealLoop()
        end
    end
)

--============================================================
-- DONE
--============================================================

print("==========================================")
print(" CiaHub • RIDE A PET")
print(" BUNDLED CIAHUB UI")
print(" AUTO STEAL READY")
print(" TELEPORT → EGG → FLY BACK")
print(" FLY → EGG → FLY BACK")
print(" DEFAULT SPEED: 300")
print("==========================================")
