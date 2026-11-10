
--[[
    NEXUS CONTROL v4.0
    RED DARK EDITION
    Created by: 阿叶ev03
    Roblox Studio - LocalScript
    For your own Roblox experience
]]

-- SERVICES
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
-- 如果物体可能不存在，这样写可以防止崩脚本
local remote = ReplicatedStorage:WaitForChild("NexusGetConfig", 5) 
if not remote then
    warn("未找到指定的远程对象！")
end

--==================================================
-- GITHUB CONFIG LOADER
--==================================================

local RemoteConfig = nil

local Remote = ReplicatedStorage:WaitForChild(
	"NexusGetConfig", 15
)

if Remote and Remote:IsA("RemoteFunction") then
	for attempt = 1, 3 do
		local success, response = pcall(function()
			return Remote:InvokeServer()
		end)

		if success
			and type(response) == "table"
			and response.success == true
			and type(response.config) == "table" then

			RemoteConfig = response.config
			break
		end

		warn("[NEXUS] Config request failed:", response)
		task.wait(1)
	end
end

if not RemoteConfig then
	warn("[NEXUS] Using default configuration")
	RemoteConfig = {}
end

local RemoteWindow = RemoteConfig.window or {}
local RemoteModules = RemoteConfig.modules or {}
local RemoteKeys = RemoteConfig.hotkeys or {}

local function GetKey(name, fallback)
	if type(name) == "string" then
		return Enum.KeyCode[name] or fallback
	end
	return fallback
end

local Version = tostring(RemoteConfig.version or "4.0.0")

local WindowWidth = math.clamp(
	tonumber(RemoteWindow.width) or 590, 450, 900
)

local WindowHeight = math.clamp(
	tonumber(RemoteWindow.height) or 420, 300, 700
)

local Config = {
	FlySpeed = 50,
	WalkSpeed = 32,
	DefaultWalkSpeed = 16,

	Keys = {
		Fly = GetKey(RemoteKeys.fly, Enum.KeyCode.F),
		Noclip = GetKey(RemoteKeys.noclip, Enum.KeyCode.N),
		Speed = GetKey(RemoteKeys.speed, Enum.KeyCode.G),
		Menu = GetKey(RemoteKeys.menu, Enum.KeyCode.RightShift)
	}
}

local EnabledPages = {
	Movement = RemoteModules.movement ~= false,
	Settings = RemoteModules.settings ~= false,
	About = RemoteModules.about ~= false
}

local PanicEnabled = RemoteModules.panicButton ~= false

--==================================================
-- THEME
--==================================================

local C = {
	Background = Color3.fromRGB(14, 12, 16),
	Panel = Color3.fromRGB(24, 18, 23),
	Sidebar = Color3.fromRGB(19, 14, 18),
	Element = Color3.fromRGB(38, 25, 31),
	Red = Color3.fromRGB(190, 40, 58),
	BrightRed = Color3.fromRGB(255, 75, 90),
	Text = Color3.fromRGB(245, 230, 234),
	Muted = Color3.fromRGB(160, 130, 140),
	Green = Color3.fromRGB(55, 160, 105),
	Off = Color3.fromRGB(70, 55, 62)
}

--==================================================
-- STATES
--==================================================

local Modules = {
	Fly = false,
	Noclip = false,
	Speed = false
}

local Character
local Humanoid
local Root

local Connections = {}
local OriginalCollision = {}

local FlyAttachment
local FlyVelocity
local FlyOrientation

local CurrentPage = "Movement"
local Minimized = false

--==================================================
-- CLEAN OLD GUI
--==================================================

local Old = PlayerGui:FindFirstChild("NexusControl")

if Old then
	Old:Destroy()
end

--==================================================
-- GUI ROOT
--==================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "NexusControl"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 100
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(WindowWidth, WindowHeight)
Main.Position = UDim2.new(
	0.5, -WindowWidth / 2,
	0.5, -WindowHeight / 2
)
Main.BackgroundColor3 = C.Background
Main.BorderSizePixel = 0
Main.Parent = Gui

Instance.new("UICorner", Main).CornerRadius =
	UDim.new(0, 12)

local Border = Instance.new("UIStroke")
Border.Color = C.Red
Border.Thickness = 1.5
Border.Parent = Main

--==================================================
-- HEADER
--==================================================

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 65)
Header.BackgroundColor3 = C.Panel
Header.BorderSizePixel = 0
Header.Parent = Main

Instance.new("UICorner", Header).CornerRadius =
	UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Position = UDim2.fromOffset(18, 8)
Title.Size = UDim2.new(0.7, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "NEXUS CONTROL"
Title.TextColor3 = C.BrightRed
Title.Font = Enum.Font.GothamBold
Title.TextSize = 21
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Position = UDim2.fromOffset(19, 37)
Subtitle.Size = UDim2.new(0.7, 0, 0, 18)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "RED EDITION / VERSION " .. Version
Subtitle.TextColor3 = C.Muted
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 10
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(34, 30)
Minimize.Position = UDim2.new(1, -47, 0, 17)
Minimize.BackgroundColor3 = C.Element
Minimize.Text = "—"
Minimize.TextColor3 = C.Text
Minimize.Font = Enum.Font.GothamBold
Minimize.TextSize = 17
Minimize.Parent = Header

Instance.new("UICorner", Minimize).CornerRadius =
	UDim.new(0, 6)

--==================================================
-- DRAG
--==================================================

local Dragging = false
local DragStart
local StartPosition

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = true
		DragStart = input.Position
		StartPosition = Main.Position
	end
end)

UIS.InputChanged:Connect(function(input)
	if Dragging and input.UserInputType ==
		Enum.UserInputType.MouseMovement then

		local Delta = input.Position - DragStart

		Main.Position = UDim2.new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + Delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + Delta.Y
		)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = false
	end
end)

--==================================================
-- SIDEBAR
--==================================================

local Sidebar = Instance.new("Frame")
Sidebar.Position = UDim2.fromOffset(0, 65)
Sidebar.Size = UDim2.new(0, 145, 1, -65)
Sidebar.BackgroundColor3 = C.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 9)
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Parent = Sidebar

local SidePadding = Instance.new("UIPadding")
SidePadding.PaddingTop = UDim.new(0, 18)
SidePadding.PaddingLeft = UDim.new(0, 10)
SidePadding.PaddingRight = UDim.new(0, 10)
SidePadding.Parent = Sidebar

--==================================================
-- CONTENT
--==================================================

local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(160, 78)
Content.Size = UDim2.new(1, -175, 1, -91)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Pages = {}

local function CreatePage(name)
	local Page = Instance.new("ScrollingFrame")
	Page.Name = name
	Page.Size = UDim2.fromScale(1, 1)
	Page.BackgroundTransparency = 1
	Page.BorderSizePixel = 0
	Page.ScrollBarThickness = 3
	Page.ScrollBarImageColor3 = C.Red
	Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Page.CanvasSize = UDim2.new()
	Page.Visible = false
	Page.Parent = Content

	local Layout = Instance.new("UIListLayout")
	Layout.Padding = UDim.new(0, 11)
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Parent = Page

	Pages[name] = Page
	return Page
end

local MovementPage = CreatePage("Movement")
local SettingsPage = CreatePage("Settings")
local AboutPage = CreatePage("About")

--==================================================
-- STATUS
--==================================================

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 30)
Status.BackgroundColor3 = C.Element
Status.Text = "SYSTEM ONLINE"
Status.TextColor3 = C.Green
Status.Font = Enum.Font.GothamBold
Status.TextSize = 12
Status.Parent = MovementPage

Instance.new("UICorner", Status).CornerRadius =
	UDim.new(0, 6)

local function SetStatus(text, color)
	Status.Text = text
	Status.TextColor3 = color or C.Green
end

--==================================================
-- CHARACTER
--==================================================

local function UpdateCharacter()
	Character = Player.Character

	Humanoid = Character and
		Character:FindFirstChildOfClass("Humanoid")

	Root = Character and
		Character:FindFirstChild("HumanoidRootPart")
end

UpdateCharacter()

--==================================================
-- FLY
--==================================================

local function StopFly()
	Modules.Fly = false

	if Connections.Fly then
		Connections.Fly:Disconnect()
		Connections.Fly = nil
	end

	if FlyVelocity then
		FlyVelocity:Destroy()
		FlyVelocity = nil
	end

	if FlyOrientation then
		FlyOrientation:Destroy()
		FlyOrientation = nil
	end

	if FlyAttachment then
		FlyAttachment:Destroy()
		FlyAttachment = nil
	end

	if Humanoid then
		Humanoid.PlatformStand = false
		Humanoid.AutoRotate = true
	end
end

local function StartFly()
	UpdateCharacter()

	if not Root or not Humanoid then
		return false
	end

	StopFly()
	Modules.Fly = true

	Humanoid.PlatformStand = true
	Humanoid.AutoRotate = false

	FlyAttachment = Instance.new("Attachment")
	FlyAttachment.Name = "NexusFlyAttachment"
	FlyAttachment.Parent = Root

	FlyVelocity = Instance.new("LinearVelocity")
	FlyVelocity.Name = "NexusFlyVelocity"
	FlyVelocity.Attachment0 = FlyAttachment
	FlyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	FlyVelocity.MaxForce = 100000000
	FlyVelocity.Parent = Root

	FlyOrientation = Instance.new("AlignOrientation")
	FlyOrientation.Name = "NexusFlyOrientation"
	FlyOrientation.Attachment0 = FlyAttachment
	FlyOrientation.Mode =
		Enum.OrientationAlignmentMode.OneAttachment
	FlyOrientation.MaxTorque = 100000000
	FlyOrientation.Responsiveness = 20
	FlyOrientation.Parent = Root

	Connections.Fly = RunService.RenderStepped:Connect(function()
		if not Modules.Fly or not Root or not Root.Parent then
			StopFly()
			return
		end

		local Camera = workspace.CurrentCamera
		if not Camera then return end

		local Direction = Vector3.zero

		if UIS:IsKeyDown(Enum.KeyCode.W) then
			Direction += Camera.CFrame.LookVector
		end

		if UIS:IsKeyDown(Enum.KeyCode.S) then
			Direction -= Camera.CFrame.LookVector
		end

		if UIS:IsKeyDown(Enum.KeyCode.A) then
			Direction -= Camera.CFrame.RightVector
		end

		if UIS:IsKeyDown(Enum.KeyCode.D) then
			Direction += Camera.CFrame.RightVector
		end

		if UIS:IsKeyDown(Enum.KeyCode.Space) then
			Direction += Vector3.yAxis
		end

		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			Direction -= Vector3.yAxis
		end

		FlyVelocity.VectorVelocity =
			Direction.Magnitude > 0
			and Direction.Unit * Config.FlySpeed
			or Vector3.zero

		FlyOrientation.CFrame = Camera.CFrame
	end)

	return true
end

--==================================================
-- NOCLIP
--==================================================

local function StopNoclip()
	Modules.Noclip = false

	if Connections.Noclip then
		Connections.Noclip:Disconnect()
		Connections.Noclip = nil
	end

	for Part, Original in pairs(OriginalCollision) do
		if Part and Part.Parent then
			Part.CanCollide = Original
		end
	end

	table.clear(OriginalCollision)
end

local function StartNoclip()
	UpdateCharacter()

	if not Character then
		return false
	end

	StopNoclip()
	Modules.Noclip = true

	Connections.Noclip = RunService.Stepped:Connect(function()
		if not Character then return end

		for _, Part in ipairs(Character:GetDescendants()) do
			if Part:IsA("BasePart") then
				if OriginalCollision[Part] == nil then
					OriginalCollision[Part] = Part.CanCollide
				end

				Part.CanCollide = false
			end
		end
	end)

	return true
end

--==================================================
-- SPEED
--==================================================

local function StopSpeed()
	Modules.Speed = false

	if Humanoid then
		Humanoid.WalkSpeed = Config.DefaultWalkSpeed
	end
end

local function StartSpeed()
	UpdateCharacter()

	if not Humanoid then
		return false
	end

	Modules.Speed = true
	Humanoid.WalkSpeed = Config.WalkSpeed

	return true
end

--==================================================
-- MODULE MANAGER
--==================================================

local function SetModule(name, enabled)
	local success = false

	if name == "Fly" then
		if enabled then
			success = StartFly()
		else
			StopFly()
			success = true
		end

	elseif name == "Noclip" then
		if enabled then
			success = StartNoclip()
		else
			StopNoclip()
			success = true
		end

	elseif name == "Speed" then
		if enabled then
			success = StartSpeed()
		else
			StopSpeed()
			success = true
		end
	end

	return success
end

--==================================================
-- UI HELPERS
--==================================================

local ToggleButtons = {}

local function CreateSection(page, text)
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, 0, 0, 30)
	Label.BackgroundTransparency = 1
	Label.Text = text
	Label.TextColor3 = C.BrightRed
	Label.Font = Enum.Font.GothamBold
	Label.TextSize = 15
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = page

	return Label
end

local function CreateToggle(page, name, description, key, module)
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, -5, 0, 58)
	Button.BackgroundColor3 = C.Element
	Button.Text = ""
	Button.AutoButtonColor = false
	Button.Parent = page

	Instance.new("UICorner", Button).CornerRadius =
		UDim.new(0, 8)

	local Name = Instance.new("TextLabel")
	Name.Position = UDim2.fromOffset(12, 5)
	Name.Size = UDim2.new(0.7, 0, 0, 24)
	Name.BackgroundTransparency = 1
	Name.Text = name
	Name.TextColor3 = C.Text
	Name.Font = Enum.Font.GothamBold
	Name.TextSize = 13
	Name.TextXAlignment = Enum.TextXAlignment.Left
	Name.Parent = Button

	local Desc = Instance.new("TextLabel")
	Desc.Position = UDim2.fromOffset(12, 29)
	Desc.Size = UDim2.new(0.7, 0, 0, 20)
	Desc.BackgroundTransparency = 1
	Desc.Text = description .. " [" .. key .. "]"
	Desc.TextColor3 = C.Muted
	Desc.Font = Enum.Font.Gotham
	Desc.TextSize = 10
	Desc.TextXAlignment = Enum.TextXAlignment.Left
	Desc.Parent = Button

	local State = Instance.new("TextLabel")
	State.Size = UDim2.fromOffset(55, 25)
	State.Position = UDim2.new(1, -67, 0.5, -12)
	State.BackgroundColor3 = C.Off
	State.Text = "OFF"
	State.TextColor3 = C.Text
	State.Font = Enum.Font.GothamBold
	State.TextSize = 11
	State.Parent = Button

	Instance.new("UICorner", State).CornerRadius =
		UDim.new(1, 0)

	local function Update()
		local enabled = Modules[module]

		State.Text = enabled and "ON" or "OFF"
		State.BackgroundColor3 = enabled and C.Green or C.Off
	end

	local function Toggle()
		local newState = not Modules[module]
		local success = SetModule(module, newState)

		Update()

		if success then
			SetStatus(name .. (newState and " ENABLED" or " DISABLED"))
		else
			SetStatus("CHARACTER NOT READY", C.BrightRed)
		end
	end

	Button.Activated:Connect(Toggle)
	ToggleButtons[module] = Update

	return Toggle
end

--==================================================
-- MOVEMENT PAGE
--==================================================

CreateSection(MovementPage, "MOVEMENT CONTROL")

local ToggleFly = CreateToggle(
	MovementPage,
	"FLY MODE",
	"Flight control",
	Config.Keys.Fly.Name,
	"Fly"
)

local ToggleNoclip = CreateToggle(
	MovementPage,
	"NOCLIP",
	"Collision test",
	Config.Keys.Noclip.Name,
	"Noclip"
)

local ToggleSpeed = CreateToggle(
	MovementPage,
	"SPEED BOOST",
	"Movement control",
	Config.Keys.Speed.Name,
	"Speed"
)

--==================================================
-- SLIDER
--==================================================

local function CreateSlider(page, label, minValue, maxValue, initial, callback)
	local Holder = Instance.new("Frame")
	Holder.Size = UDim2.new(1, -5, 0, 65)
	Holder.BackgroundColor3 = C.Element
	Holder.Parent = page

	Instance.new("UICorner", Holder).CornerRadius =
		UDim.new(0, 8)

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.fromOffset(12, 5)
	Label.Size = UDim2.new(1, -24, 0, 22)
	Label.BackgroundTransparency = 1
	Label.TextColor3 = C.Text
	Label.Font = Enum.Font.GothamBold
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Holder

	local Track = Instance.new("TextButton")
	Track.Position = UDim2.fromOffset(12, 39)
	Track.Size = UDim2.new(1, -24, 0, 10)
	Track.BackgroundColor3 = C.Off
	Track.Text = ""
	Track.AutoButtonColor = false
	Track.Parent = Holder

	Instance.new("UICorner", Track).CornerRadius =
		UDim.new(1, 0)

	local Fill = Instance.new("Frame")
	Fill.Size = UDim2.new(
		(initial - minValue) / (maxValue - minValue), 0, 1, 0
	)
	Fill.BackgroundColor3 = C.BrightRed
	Fill.BorderSizePixel = 0
	Fill.Parent = Track

	Instance.new("UICorner", Fill).CornerRadius =
		UDim.new(1, 0)

	local dragging = false

	local function SetValue(input)
		local ratio = math.clamp(
			(input.Position.X - Track.AbsolutePosition.X)
				/ Track.AbsoluteSize.X,
			0, 1
		)

		local value = math.floor(
			minValue + ratio * (maxValue - minValue)
		)

		Fill.Size = UDim2.new(ratio, 0, 1, 0)
		Label.Text = label .. ": " .. value

		callback(value)
	end

	Label.Text = label .. ": " .. initial

	Track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			SetValue(input)
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType ==
			Enum.UserInputType.MouseMovement then
			SetValue(input)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

CreateSlider(
	MovementPage,
	"FLIGHT SPEED",
	1, 200,
	Config.FlySpeed,
	function(value)
		Config.FlySpeed = value
	end
)

CreateSlider(
	MovementPage,
	"WALK SPEED",
	1, 200,
	Config.WalkSpeed,
	function(value)
		Config.WalkSpeed = value

		if Modules.Speed and Humanoid then
			Humanoid.WalkSpeed = value
		end
	end
)

--==================================================
-- SETTINGS PAGE
--==================================================

CreateSection(SettingsPage, "GENERAL SETTINGS")

local function CreateInfo(page, text)
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -5, 0, 42)
	Label.BackgroundColor3 = C.Element
	Label.Text = text
	Label.TextColor3 = C.Text
	Label.Font = Enum.Font.Gotham
	Label.TextSize = 12
	Label.TextWrapped = true
	Label.Parent = page

	Instance.new("UICorner", Label).CornerRadius =
		UDim.new(0, 8)
end

CreateInfo(SettingsPage, "FLY KEY: " .. Config.Keys.Fly.Name)
CreateInfo(SettingsPage, "NOCLIP KEY: " .. Config.Keys.Noclip.Name)
CreateInfo(SettingsPage, "SPEED KEY: " .. Config.Keys.Speed.Name)
CreateInfo(SettingsPage, "MENU KEY: " .. Config.Keys.Menu.Name)

--==================================================
-- ABOUT PAGE
--==================================================

CreateSection(AboutPage, "ABOUT NEXUS")

CreateInfo(AboutPage, "NEXUS CONTROL v" .. Version)
CreateInfo(AboutPage, "RED DARK EDITION")
CreateInfo(AboutPage, "Created by: 阿叶ev03")
CreateInfo(AboutPage, "Roblox Studio Test Edition")
CreateInfo(AboutPage, "Created for authorized game testing.")

--==================================================
-- NAVIGATION
--==================================================

local NavButtons = {}

local function ShowPage(name)
	if not EnabledPages[name] then
		name = nil

		for _, pageName in ipairs({
			"Movement",
			"Settings",
			"About"
			}) do
			if EnabledPages[pageName] then
				name = pageName
				break
			end
		end
	end

	if not name then
		return
	end

	CurrentPage = name

	for pageName, page in pairs(Pages) do
		page.Visible =
			pageName == name and EnabledPages[pageName]
	end

	for buttonName, button in pairs(NavButtons) do
		button.Visible = EnabledPages[buttonName]

		button.BackgroundColor3 =
			buttonName == name and C.Red or C.Element
	end
end

local function CreateNav(name, order)
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, 0, 0, 42)
	Button.BackgroundColor3 = C.Element
	Button.Text = name:upper()
	Button.TextColor3 = C.Text
	Button.Font = Enum.Font.GothamBold
	Button.TextSize = 11
	Button.LayoutOrder = order
	Button.Parent = Sidebar

	Instance.new("UICorner", Button).CornerRadius =
		UDim.new(0, 7)

	Button.Activated:Connect(function()
		ShowPage(name)
	end)

	NavButtons[name] = Button
end

CreateNav("Movement", 1)
CreateNav("Settings", 2)
CreateNav("About", 3)

for name, button in pairs(NavButtons) do
	button.Visible = EnabledPages[name]
end

--==================================================
-- PANIC BUTTON
--==================================================

local Panic = Instance.new("TextButton")
Panic.Size = UDim2.new(1, 0, 0, 43)
Panic.BackgroundColor3 = Color3.fromRGB(115, 25, 38)
Panic.Text = "PANIC BUTTON"
Panic.TextColor3 = Color3.new(1, 1, 1)
Panic.Font = Enum.Font.GothamBold
Panic.TextSize = 11
Panic.LayoutOrder = 4
Panic.Visible = PanicEnabled
Panic.Parent = Sidebar

Instance.new("UICorner", Panic).CornerRadius =
	UDim.new(0, 7)

local function PanicStop()
	StopFly()
	StopNoclip()
	StopSpeed()

	for _, update in pairs(ToggleButtons) do
		update()
	end

	SetStatus("ALL MODULES DISABLED", C.BrightRed)
end

Panic.Activated:Connect(PanicStop)

--==================================================
-- MINIMIZE
--==================================================

Minimize.Activated:Connect(function()
	Minimized = not Minimized

	Sidebar.Visible = not Minimized
	Content.Visible = not Minimized

	Main.Size = Minimized
		and UDim2.fromOffset(WindowWidth, 65)
		or UDim2.fromOffset(WindowWidth, WindowHeight)

	Minimize.Text = Minimized and "+" or "—"
end)

--==================================================
-- HOTKEYS
--==================================================

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if UIS:GetFocusedTextBox() then return end

	if input.KeyCode == Config.Keys.Fly then
		ToggleFly()

	elseif input.KeyCode == Config.Keys.Noclip then
		ToggleNoclip()

	elseif input.KeyCode == Config.Keys.Speed then
		ToggleSpeed()

	elseif input.KeyCode == Config.Keys.Menu then
		Main.Visible = not Main.Visible
	end
end)

--==================================================
-- RESPAWN
--==================================================

Player.CharacterAdded:Connect(function(newCharacter)
	StopFly()
	StopNoclip()
	StopSpeed()

	Character = newCharacter
	Humanoid = newCharacter:WaitForChild("Humanoid")
	Root = newCharacter:WaitForChild("HumanoidRootPart")

	OriginalCollision = {}

	for _, update in pairs(ToggleButtons) do
		update()
	end

	SetStatus("CHARACTER READY")
end)

--==================================================
-- INITIALIZE
--==================================================

ShowPage("Movement")
SetStatus("NEXUS SYSTEM ONLINE")

print("================================")
print("NEXUS CONTROL v" .. Version)
print("RED DARK EDITION")
print("Created by: 阿叶ev03")
print("GitHub Config:", RemoteConfig.version or "DEFAULT")
print("F = Fly | N = Noclip | G = Speed")
print("RIGHT SHIFT = Hide / Show")
print("PANIC = Disable all modules")
print("================================")
