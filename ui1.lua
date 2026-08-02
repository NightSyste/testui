--[[
	═══════════════════════════════════════════════════════════════
	  VORTEX UI LIBRARY
	  Design 1:1 nach Vorlage  •  kein "General"-Tab-Button
	  API bleibt kompatibel (MakeWindow / MakeTab / AddToggle / ...)
	═══════════════════════════════════════════════════════════════
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local Debris           = game:GetService("Debris")
local SoundService     = game:GetService("SoundService")
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer and LocalPlayer:GetMouse()

local Library = {
	Elements      = {},
	ThemeObjects  = {},
	Connections   = {},
	Flags         = {},
	ClickSound    = true,
	SelectedTheme = "Default",
	Font          = Enum.Font.Gotham,
	Themes = {
		Default = {
			Main     = Color3.fromRGB(15, 13, 19),   -- Fensterhintergrund
			Second   = Color3.fromRGB(28, 25, 35),   -- Zeilen / Karten
			Third    = Color3.fromRGB(38, 34, 48),   -- Eingabefelder / Pills
			Stroke   = Color3.fromRGB(44, 40, 55),   -- Rahmen / Linien
			Divider  = Color3.fromRGB(34, 31, 43),   -- Scrollbar
			Text     = Color3.fromRGB(237, 236, 242),
			TextDark = Color3.fromRGB(136, 133, 148),
			Accent   = Color3.fromRGB(139, 92, 246), -- Lila Akzent
		}
	}
}

local function Theme()  return Library.Themes[Library.SelectedTheme] end
local function Accent() return Theme().Accent end

local function Lighten(c, amt)
	return Color3.fromRGB(
		math.clamp(c.R * 255 + amt, 0, 255),
		math.clamp(c.G * 255 + amt, 0, 255),
		math.clamp(c.B * 255 + amt, 0, 255)
	)
end

local function Tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- ═══════════════════ Config Speichern / Laden ═══════════════════

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
	local Success, Data = pcall(function() return HttpService:JSONDecode(Config) end)
	if not Success or type(Data) ~= "table" then return end
	for a, b in pairs(Data) do
		if Library.Flags[a] then
			task.spawn(function()
				if Library.Flags[a].Type == "Colorpicker" then
					Library.Flags[a]:Set(UnpackColor(b))
				else
					Library.Flags[a]:Set(b)
				end
			end)
		end
	end
end

local function SaveCfg(Name)
	if not Library.SaveCfg then return end
	local Data = {}
	for i, v in pairs(Library.Flags) do
		if v.Save then
			if v.Type == "Colorpicker" then
				Data[i] = PackColor(v.Value)
			else
				Data[i] = v.Value
			end
		end
	end
	pcall(function()
		writefile(Library.Folder .. "/" .. Name .. ".txt", tostring(HttpService:JSONEncode(Data)))
	end)
end

function Library:Init()
	if not Library.SaveCfg then return end
	task.defer(function()
		pcall(function()
			local path = Library.Folder .. "/" .. tostring(game.GameId) .. ".txt"
			if isfile(path) then
				local raw = readfile(path)
				if raw and raw ~= "" then
					LoadCfg(raw)
					Library:MakeNotification({
						Name    = "Config geladen",
						Content = "Deine Einstellungen wurden wiederhergestellt.",
						Time    = 4
					})
				end
			end
		end)
	end)
end

-- ═══════════════════ ScreenGui ═══════════════════

local function GetGuiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

function Library:CleanupInstance()
	pcall(function()
		for _, instance in pairs(GetGuiParent():GetChildren()) do
			if instance:IsA("ScreenGui") and instance.Name:match("^[A-Z]%d%d%d$") then
				instance:Destroy()
			end
		end
	end)
end

Library:CleanupInstance()

local Container = Instance.new("ScreenGui")
Container.Name         = string.char(math.random(65, 90)) .. tostring(math.random(100, 999))
Container.DisplayOrder = 2147483647
Container.ResetOnSpawn = false
Container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() Container.Parent = GetGuiParent() end)
pcall(function() if syn and syn.protect_gui then syn.protect_gui(Container) end end)

function Library:IsRunning()
	return Container and Container.Parent ~= nil
end

local function AddConnection(Signal, Function)
	if not Library:IsRunning() then return end
	local SignalConnect = Signal:Connect(Function)
	table.insert(Library.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while Library:IsRunning() do task.wait() end
	for _, Connection in next, Library.Connections do
		pcall(function() Connection:Disconnect() end)
	end
end)

local function PlayClick()
	if not Library.ClickSound then return end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume  = 0.35
		sound.Parent  = SoundService
		sound:Play()
		Debris:AddItem(sound, 1)
	end)
end

-- ═══════════════════ Basis-Helfer ═══════════════════

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do Object[i] = v end
	for i, v in next, Children   or {} do v.Parent = Object end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	Library.Elements[ElementName] = function(...) return ElementFunction(...) end
end

local function MakeElement(ElementName, ...)
	return Library.Elements[ElementName](...)
end

local function SetProps(Element, Props)
	for Property, Value in next, Props do Element[Property] = Value end
	return Element
end

local function SetChildren(Element, Children)
	for _, Child in next, Children do Child.Parent = Element end
	return Element
end

local function Round(Number, Factor)
	if not Factor or Factor == 0 then return Number end
	local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") then return "BackgroundColor3" end
	if Object:IsA("ScrollingFrame")                     then return "ScrollBarImageColor3" end
	if Object:IsA("UIStroke")                           then return "Color" end
	if Object:IsA("TextLabel") or Object:IsA("TextBox")  then return "TextColor3" end
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then return "ImageColor3" end
end

local function AddThemeObject(Object, Type)
	if not Library.ThemeObjects[Type] then Library.ThemeObjects[Type] = {} end
	table.insert(Library.ThemeObjects[Type], Object)
	Object[ReturnProperty(Object)] = Theme()[Type]
	return Object
end

local function SetTheme()
	for Name, Type in pairs(Library.ThemeObjects) do
		for _, Object in pairs(Type) do
			if Object and Object.Parent then
				Object[ReturnProperty(Object)] = Theme()[Name]
			end
		end
	end
end

function Library:SetAccent(Color)
	Theme().Accent = Color
	SetTheme()
end

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3, Enum.UserInputType.Touch}
local BlacklistedKeys  = {Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right, Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in next, Table do
		if v == Key then return true end
	end
end

-- ═══════════════════ Element-Bausteine ═══════════════════

CreateElement("Corner", function(Scale, Offset)
	return Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 8)})
end)

CreateElement("Stroke", function(Color, Thickness)
	return Create("UIStroke", {Color = Color or Color3.fromRGB(255,255,255), Thickness = Thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end)

CreateElement("List", function(Scale, Offset)
	return Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(Scale or 0, Offset or 0)})
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	return Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft   = UDim.new(0, Left   or 4),
		PaddingRight  = UDim.new(0, Right  or 4),
		PaddingTop    = UDim.new(0, Top    or 4)
	})
end)

CreateElement("TFrame", function()
	return Create("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0})
end)

CreateElement("Frame", function(Color)
	return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255,255,255), BorderSizePixel = 0})
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255,255,255), BorderSizePixel = 0}, {
		Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 8)})
	})
end)

CreateElement("Button", function(silent)
	local Button = Create("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0})
	if not silent then
		Button.MouseButton1Click:Connect(PlayClick)
	end
	return Button
end)

CreateElement("ScrollFrame", function(Color, Width)
	return Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage    = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage    = "rbxassetid://7445543667",
		ScrollBarImageColor3 = Color,
		BorderSizePixel      = 0,
		ScrollBarThickness   = Width,
		CanvasSize           = UDim2.new(0,0,0,0)
	})
end)

CreateElement("Image", function(ImageID)
	return Create("ImageLabel", {Image = ImageID or "", BackgroundTransparency = 1})
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	return Create("TextLabel", {
		Text             = Text or "",
		TextColor3       = Theme().Text,
		TextTransparency = Transparency or 0,
		TextSize         = TextSize or 14,
		Font             = Enum.Font.GothamMedium,
		RichText         = true,
		BackgroundTransparency = 1,
		TextXAlignment   = Enum.TextXAlignment.Left
	})
end)

-- ═══════════════════ Vektor-Icons (ohne Asset-IDs) ═══════════════════

local function Bar(parent, w, h, xOff, yOff, rot, color, zi)
	local bar = Create("Frame", {
		Parent           = parent,
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Position         = UDim2.new(0.5, xOff, 0.5, yOff),
		Size             = UDim2.new(0, w, 0, h),
		Rotation         = rot or 0,
		BackgroundColor3 = color,
		BorderSizePixel  = 0,
		ZIndex           = zi or 3
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = bar})
	return bar
end

-- Icon-Typen: "search" | "chevron" | "minus" | "close"
local function BuildGlyph(parent, kind, color)
	local parts = {}
	if kind == "search" then
		local ring = Create("Frame", {
			Parent = parent, AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.new(0.5,-1,0.5,-1), Size = UDim2.new(0,10,0,10),
			BackgroundTransparency = 1, ZIndex = 3
		})
		Create("UICorner", {CornerRadius = UDim.new(1,0), Parent = ring})
		local st = Create("UIStroke", {Parent = ring, Color = color, Thickness = 1.5})
		table.insert(parts, st)
		table.insert(parts, Bar(parent, 5, 1.5, 4, 4, 45, color))
	elseif kind == "chevron" then
		table.insert(parts, Bar(parent, 8, 1.6, -2.6, 0, -40, color))
		table.insert(parts, Bar(parent, 8, 1.6,  2.6, 0,  40, color))
	elseif kind == "minus" then
		table.insert(parts, Bar(parent, 11, 1.6, 0, 0, 0, color))
	elseif kind == "close" then
		table.insert(parts, Bar(parent, 12, 1.6, 0, 0,  45, color))
		table.insert(parts, Bar(parent, 12, 1.6, 0, 0, -45, color))
	end
	return parts
end

local function MakeTopButton(kind)
	local Btn = Create("TextButton", {
		Size = UDim2.new(0, 26, 0, 26),
		BackgroundColor3 = Theme().Second,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "", AutoButtonColor = false
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Btn})

	local IconColor = Theme().TextDark
	local Glyph = Create("Frame", {Parent = Btn, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 2})
	local parts = BuildGlyph(Glyph, kind, IconColor)

	local function paint(c, bgT)
		for _, p in ipairs(parts) do
			if p:IsA("UIStroke") then p.Color = c else p.BackgroundColor3 = c end
		end
		Tween(Btn, 0.15, {BackgroundTransparency = bgT})
	end

	Btn.MouseEnter:Connect(function() paint(Theme().Text, 0.55) end)
	Btn.MouseLeave:Connect(function() paint(Theme().TextDark, 1) end)

	return Btn, Glyph, parts
end

-- ═══════════════════ Drag & Resize ═══════════════════

local function MakeDraggable(DragPoint, Main)
	local Dragging, DragInput, MousePos, FramePos = false, nil, nil, nil
	local Locked = false

	DragPoint.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			if Locked then return end
			Dragging = true
			MousePos = Input.Position
			FramePos = Main.Position
			Input.Changed:Connect(function()
				if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
			end)
		end
	end)
	DragPoint.InputChanged:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
			DragInput = Input
		end
	end)
	UserInputService.InputChanged:Connect(function(Input)
		if Input == DragInput and Dragging and not Locked then
			local Delta = Input.Position - MousePos
			Tween(Main, 0.25, {
				Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
			})
		end
	end)

	return function(state)
		Locked = state
		if state then Dragging = false end
	end
end

local function MakeResizable(Grip, Main, MinSize, MaxSize, SetLocked)
	local Resizing, StartSize, StartPos = false, nil, nil
	Grip.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Resizing  = true
			if SetLocked then SetLocked(true) end
			StartSize = Main.Size
			StartPos  = Vector2.new(Mouse.X, Mouse.Y)
		end
	end)
	Grip.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Resizing = false
			if SetLocked then SetLocked(false) end
		end
	end)
	UserInputService.InputChanged:Connect(function()
		if Resizing then
			local Delta = Vector2.new(Mouse.X, Mouse.Y) - StartPos
			Main.Size = UDim2.new(0,
				math.clamp(StartSize.X.Offset + Delta.X, MinSize.X, MaxSize.X), 0,
				math.clamp(StartSize.Y.Offset + Delta.Y, MinSize.Y, MaxSize.Y))
		end
	end)
end

-- ═══════════════════ Notifications ═══════════════════

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder           = Enum.SortOrder.LayoutOrder,
		VerticalAlignment   = Enum.VerticalAlignment.Bottom,
		Padding             = UDim.new(0, 8)
	})
}), {
	Position    = UDim2.new(1, -25, 1, -25),
	Size        = UDim2.new(0, 290, 1, -25),
	AnchorPoint = Vector2.new(1, 1),
	Parent      = Container
})

function Library:MakeNotification(NotificationConfig)
	task.spawn(function()
		NotificationConfig         = NotificationConfig or {}
		NotificationConfig.Name    = NotificationConfig.Name    or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or ""
		NotificationConfig.Time    = NotificationConfig.Time    or 6

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size          = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent        = NotificationHolder
		})

		local Frame = SetChildren(SetProps(MakeElement("RoundFrame", Theme().Second, 0, 10), {
			Parent        = NotificationParent,
			Size          = UDim2.new(1, 0, 0, 0),
			Position      = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", Theme().Stroke, 1),
			MakeElement("Padding", 12, 14, 14, 12),
			Create("Frame", {
				Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 0, 0, 2),
				BackgroundColor3 = Accent(), BorderSizePixel = 0
			}, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 14), {
				Size     = UDim2.new(1, -14, 0, 18),
				Position = UDim2.new(0, 12, 0, 0),
				Font     = Enum.Font.GothamBold,
				Name     = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 12), {
				Size          = UDim2.new(1, -12, 0, 0),
				Position      = UDim2.new(0, 12, 0, 22),
				Name          = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3    = Theme().TextDark,
				TextWrapped   = true
			})
		})

		Tween(Frame, 0.45, {Position = UDim2.new(0, 0, 0, 0)})
		task.wait(NotificationConfig.Time)
		Tween(Frame, 0.5, {Position = UDim2.new(1, 20, 0, 0)})
		task.wait(0.5)
		NotificationParent:Destroy()
	end)
end

-- ═══════════════════ Fenster ═══════════════════

function Library:MakeWindow(WindowConfig)
	local FirstTab   = true
	local Collapsed  = false
	local UIHidden   = false

	WindowConfig                 = WindowConfig or {}
	WindowConfig.Name            = WindowConfig.Name            or "Vortex"
	WindowConfig.ConfigFolder    = WindowConfig.ConfigFolder    or WindowConfig.Name
	WindowConfig.SaveConfig      = WindowConfig.SaveConfig      or false
	WindowConfig.CloseCallback   = WindowConfig.CloseCallback   or function() end
	WindowConfig.Size            = WindowConfig.Size            or Vector2.new(620, 360)
	if WindowConfig.IntroEnabled == nil then WindowConfig.IntroEnabled = true end
	if WindowConfig.Accent then Theme().Accent = WindowConfig.Accent end

	Library.Folder  = WindowConfig.ConfigFolder
	Library.SaveCfg = WindowConfig.SaveConfig
	if WindowConfig.SaveConfig then
		pcall(function()
			if not isfolder(WindowConfig.ConfigFolder) then makefolder(WindowConfig.ConfigFolder) end
		end)
	end

	local SIDEBAR = 150
	local TOPBAR  = 46

	----------------------------------------------------------------
	-- Hauptfenster
	----------------------------------------------------------------
	local MainWindow = AddThemeObject(SetProps(MakeElement("RoundFrame", Theme().Main, 0, 10), {
		Parent           = Container,
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Position         = UDim2.new(0.5, 0, 0.5, 0),
		Size             = UDim2.new(0, WindowConfig.Size.X, 0, WindowConfig.Size.Y),
		ClipsDescendants = true
	}), "Main")
	AddThemeObject(MakeElement("Stroke", Theme().Stroke, 1), "Stroke").Parent = MainWindow

	----------------------------------------------------------------
	-- Topbar
	----------------------------------------------------------------
	local TopBar = SetProps(MakeElement("TFrame"), {
		Size   = UDim2.new(1, 0, 0, TOPBAR),
		Name   = "TopBar",
		Parent = MainWindow
	})

	-- Logo (rundes Icon mit Fadenkreuz)
	local Logo = Create("Frame", {
		Parent           = TopBar,
		AnchorPoint      = Vector2.new(0, 0.5),
		Position         = UDim2.new(0, 14, 0.5, 0),
		Size             = UDim2.new(0, 24, 0, 24),
		BackgroundColor3 = Accent(),
		BorderSizePixel  = 0
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Logo})
	Create("UIGradient", {
		Parent   = Logo,
		Rotation = 45,
		Color    = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(167, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB( 91,  84, 240))
		}
	})
	do -- Fadenkreuz im Logo
		local ring = Create("Frame", {
			Parent = Logo, AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.new(0.5,0,0.5,0), Size = UDim2.new(0,9,0,9),
			BackgroundTransparency = 1, ZIndex = 3
		})
		Create("UICorner", {CornerRadius = UDim.new(1,0), Parent = ring})
		Create("UIStroke", {Parent = ring, Color = Color3.fromRGB(255,255,255), Thickness = 1.4})
		Bar(Logo, 13, 1.4, 0, 0,  0, Color3.fromRGB(255,255,255), 4)
		Bar(Logo, 13, 1.4, 0, 0, 90, Color3.fromRGB(255,255,255), 4)
	end

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 17), {
		Parent      = TopBar,
		AnchorPoint = Vector2.new(0, 0.5),
		Position    = UDim2.new(0, 46, 0.5, 0),
		Size        = UDim2.new(0, 200, 0, 20),
		Font        = Enum.Font.GothamBold
	}), "Text")

	-- Fenster-Buttons: Suche  ^  −  ✕
	local SearchBtn   = MakeTopButton("search")
	local CollapseBtn = MakeTopButton("chevron")
	local MinimizeBtn = MakeTopButton("minus")
	local CloseBtn    = MakeTopButton("close")

	SearchBtn.Parent   = TopBar; SearchBtn.Position   = UDim2.new(1, -132, 0.5, -13)
	CollapseBtn.Parent = TopBar; CollapseBtn.Position = UDim2.new(1,  -98, 0.5, -13)
	MinimizeBtn.Parent = TopBar; MinimizeBtn.Position = UDim2.new(1,  -66, 0.5, -13)
	CloseBtn.Parent    = TopBar; CloseBtn.Position    = UDim2.new(1,  -34, 0.5, -13)

	-- Suchfeld (klappt in der Topbar auf)
	local SearchBox = Create("TextBox", {
		Parent                 = TopBar,
		AnchorPoint            = Vector2.new(1, 0.5),
		Position               = UDim2.new(1, -140, 0.5, 0),
		Size                   = UDim2.new(0, 0, 0, 26),
		BackgroundColor3       = Theme().Third,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Text                   = "",
		PlaceholderText        = "Suchen...",
		PlaceholderColor3      = Theme().TextDark,
		TextColor3             = Theme().Text,
		TextSize               = 12,
		Font                   = Enum.Font.GothamMedium,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ClearTextOnFocus       = false,
		Visible                = false
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SearchBox})
	Create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = SearchBox})

	local TopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Parent   = TopBar,
		Size     = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1)
	}), "Stroke")

	----------------------------------------------------------------
	-- Sidebar
	----------------------------------------------------------------
	local Sidebar = SetProps(MakeElement("TFrame"), {
		Parent = MainWindow,
		Size   = UDim2.new(0, SIDEBAR, 1, -TOPBAR),
		Position = UDim2.new(0, 0, 0, TOPBAR),
		Name   = "Sidebar"
	})

	local SidebarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Parent   = Sidebar,
		Size     = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0)
	}), "Stroke")

	local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Theme().Divider, 3), {
		Parent = Sidebar,
		Size   = UDim2.new(1, -1, 1, 0)
	}), {
		MakeElement("List", 0, 2),
		MakeElement("Padding", 10, 0, 4, 10)
	}), "Divider")

	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 20)
	end)

	----------------------------------------------------------------
	-- Inhaltsfläche (Hintergrund minimal heller als das Fenster)
	----------------------------------------------------------------
	local ContentBG = SetProps(MakeElement("Frame", Lighten(Theme().Main, 4)), {
		Parent   = MainWindow,
		Size     = UDim2.new(1, -SIDEBAR, 1, -TOPBAR),
		Position = UDim2.new(0, SIDEBAR, 0, TOPBAR),
		Name     = "ContentBG"
	})

	-- Resize-Griff unten rechts (unsichtbar)
	local Grip = SetProps(MakeElement("Button", true), {
		Parent      = MainWindow,
		AnchorPoint = Vector2.new(1, 1),
		Position    = UDim2.new(1, 0, 1, 0),
		Size        = UDim2.new(0, 14, 0, 14),
		BackgroundTransparency = 1
	})

	-- Drag-Fläche liegt in der Topbar, aber unter allen Buttons (ZIndex 0)
	local DragPoint = SetProps(MakeElement("TFrame"), {
		Parent = TopBar, Size = UDim2.new(1, 0, 1, 0), ZIndex = 0
	})
	local SetDragLocked = MakeDraggable(DragPoint, MainWindow)
	MakeResizable(Grip, MainWindow, Vector2.new(520, 300), Vector2.new(900, 620), SetDragLocked)

	----------------------------------------------------------------
	-- Mobile Reopen-Button
	----------------------------------------------------------------
	local MobileReopenButton = SetChildren(SetProps(MakeElement("Button"), {
		Parent           = Container,
		Size             = UDim2.new(0, 42, 0, 42),
		Position         = UDim2.new(0.5, -21, 0, 20),
		BackgroundColor3 = Theme().Main,
		BackgroundTransparency = 0.1,
		Visible          = false
	}), {
		MakeElement("Corner", 1),
		MakeElement("Stroke", Theme().Stroke, 1)
	})
	do
		local ring = Create("Frame", {
			Parent = MobileReopenButton, AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.new(0.5,0,0.5,0), Size = UDim2.new(0,12,0,12),
			BackgroundTransparency = 1, ZIndex = 3
		})
		Create("UICorner", {CornerRadius = UDim.new(1,0), Parent = ring})
		Create("UIStroke", {Parent = ring, Color = Accent(), Thickness = 1.6})
		Bar(MobileReopenButton, 18, 1.6, 0, 0,  0, Accent(), 4)
		Bar(MobileReopenButton, 18, 1.6, 0, 0, 90, Accent(), 4)
	end

	----------------------------------------------------------------
	-- Suche
	----------------------------------------------------------------
	local CurrentTab = nil
	local SearchOpen = false

	local function ApplySearch(TabData, query)
		if not TabData then return end
		query = string.lower(query or "")
		for _, item in ipairs(TabData.Search) do
			if item.Frame and item.Frame.Parent then
				item.Frame.Visible = (query == "") or (string.find(string.lower(item.Name), query, 1, true) ~= nil)
			end
		end
		for _, sec in ipairs(TabData.Sections) do
			if query == "" then
				sec.Frame.Visible = true
			else
				local any = false
				for _, it in ipairs(sec.Items) do
					if it.Frame and it.Frame.Visible then any = true break end
				end
				sec.Frame.Visible = any
			end
		end
	end

	SearchBtn.MouseButton1Click:Connect(function()
		PlayClick()
		SearchOpen = not SearchOpen
		if SearchOpen then
			SearchBox.Visible = true
			Tween(SearchBox, 0.2, {Size = UDim2.new(0, 170, 0, 26), BackgroundTransparency = 0})
			Tween(WindowName, 0.2, {TextTransparency = 1})
			task.wait(0.1)
			SearchBox:CaptureFocus()
		else
			SearchBox.Text = ""
			ApplySearch(CurrentTab, "")
			Tween(WindowName, 0.2, {TextTransparency = 0})
			local t = Tween(SearchBox, 0.2, {Size = UDim2.new(0, 0, 0, 26), BackgroundTransparency = 1})
			t.Completed:Connect(function() SearchBox.Visible = false end)
		end
	end)

	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		ApplySearch(CurrentTab, SearchBox.Text)
	end)

	----------------------------------------------------------------
	-- Fenster-Buttons Logik
	----------------------------------------------------------------
	CollapseBtn.MouseButton1Click:Connect(function()
		PlayClick()
		Collapsed = not Collapsed
		Tween(CollapseBtn:FindFirstChildOfClass("Frame"), 0.2, {Rotation = Collapsed and 180 or 0})
		if Collapsed then
			TopBarLine.Visible = false
			Tween(MainWindow, 0.35, {Size = UDim2.new(0, WindowConfig.Size.X, 0, TOPBAR)})
			task.wait(0.15)
			Sidebar.Visible   = false
			ContentBG.Visible = false
			for _, c in ipairs(MainWindow:GetChildren()) do
				if c.Name == "ItemContainer" then c.Visible = false end
			end
		else
			Sidebar.Visible   = true
			ContentBG.Visible = true
			if CurrentTab then CurrentTab.Container.Visible = true end
			TopBarLine.Visible = true
			Tween(MainWindow, 0.35, {Size = UDim2.new(0, WindowConfig.Size.X, 0, WindowConfig.Size.Y)})
		end
	end)

	local function HideUI()
		MainWindow.Visible = false
		UIHidden = true
		if UserInputService.TouchEnabled then MobileReopenButton.Visible = true end
		Library:MakeNotification({
			Name    = "Interface versteckt",
			Content = UserInputService.TouchEnabled and "Tippe den Button oder Left Control zum Öffnen." or "Drücke Left Control zum Öffnen.",
			Time    = 5
		})
	end

	MinimizeBtn.MouseButton1Click:Connect(function() PlayClick() HideUI() end)
	CloseBtn.MouseButton1Click:Connect(function()
		PlayClick()
		HideUI()
		WindowConfig.CloseCallback()
		-- Komplett schließen statt verstecken? Dann stattdessen:  Library:Destroy()
	end)

	AddConnection(UserInputService.InputBegan, function(Input, gpe)
		if gpe then return end
		if Input.KeyCode == Enum.KeyCode.LeftControl and UIHidden then
			MainWindow.Visible = true
			MobileReopenButton.Visible = false
			UIHidden = false
		end
	end)

	AddConnection(MobileReopenButton.Activated, function()
		MainWindow.Visible = true
		MobileReopenButton.Visible = false
		UIHidden = false
	end)

	----------------------------------------------------------------
	-- Intro / Loader
	----------------------------------------------------------------
	local function LoadSequence()
		MainWindow.Visible = false

		local LoaderFrame = Create("Frame", {
			Parent           = Container,
			AnchorPoint      = Vector2.new(0.5, 0.5),
			Position         = UDim2.new(0.5, 0, 0.53, 0),
			Size             = UDim2.new(0, 240, 0, 70),
			BackgroundColor3 = Theme().Main,
			BorderSizePixel  = 0,
			ZIndex           = 10
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = LoaderFrame})
		local FrameStroke = Create("UIStroke", {Parent = LoaderFrame, Color = Accent(), Thickness = 1, Transparency = 0.5})

		local Dot = Create("Frame", {
			Parent = LoaderFrame, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, -6), Size = UDim2.new(0, 20, 0, 20),
			BackgroundColor3 = Accent(), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 11
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Dot})

		local TitleLabel = Create("TextLabel", {
			Parent = LoaderFrame, Position = UDim2.new(0, 46, 0, 12),
			Size = UDim2.new(1, -56, 0, 18), Text = WindowConfig.Name,
			TextColor3 = Theme().Text, TextTransparency = 1, TextSize = 15,
			Font = Enum.Font.GothamBold, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11
		})
		local StatusLabel = Create("TextLabel", {
			Parent = LoaderFrame, Position = UDim2.new(0, 46, 0, 32),
			Size = UDim2.new(1, -56, 0, 14), Text = "Initializing...",
			TextColor3 = Theme().TextDark, TextTransparency = 1, TextSize = 11,
			Font = Enum.Font.GothamMedium, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11
		})
		local BarBG = Create("Frame", {
			Parent = LoaderFrame, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -32, 0, 2),
			BackgroundColor3 = Theme().Third, BorderSizePixel = 0, ZIndex = 11
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BarBG})
		local BarFill = Create("Frame", {
			Parent = BarBG, Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = Accent(), BorderSizePixel = 0, ZIndex = 12
		})
		Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BarFill})

		Tween(LoaderFrame, 0.4, {Position = UDim2.new(0.5, 0, 0.5, 0)})
		Tween(Dot, 0.35, {BackgroundTransparency = 0})
		task.wait(0.12)
		Tween(TitleLabel, 0.3, {TextTransparency = 0})
		Tween(StatusLabel, 0.3, {TextTransparency = 0})

		local steps = {
			{text = "Loading modules...", progress = 0.25, delay = 0.28},
			{text = "Building UI...",     progress = 0.55, delay = 0.40},
			{text = "Applying theme...",  progress = 0.80, delay = 0.32},
			{text = "Almost ready...",    progress = 0.95, delay = 0.26},
		}
		for _, step in ipairs(steps) do
			task.wait(step.delay)
			StatusLabel.Text = step.text
			Tween(BarFill, step.delay + 0.1, {Size = UDim2.new(step.progress, 0, 1, 0)})
			Tween(FrameStroke, 0.15, {Transparency = 0.1})
			task.wait(0.14)
			Tween(FrameStroke, 0.3, {Transparency = 0.5})
		end

		task.wait(0.18)
		StatusLabel.Text = "Done!"
		Tween(BarFill, 0.25, {Size = UDim2.new(1, 0, 1, 0)})
		task.wait(0.4)

		Tween(LoaderFrame, 0.3, {BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.47, 0)})
		Tween(Dot, 0.25, {BackgroundTransparency = 1})
		Tween(TitleLabel, 0.25, {TextTransparency = 1})
		Tween(StatusLabel, 0.25, {TextTransparency = 1})
		Tween(FrameStroke, 0.25, {Transparency = 1})
		Tween(BarBG, 0.25, {BackgroundTransparency = 1})
		Tween(BarFill, 0.25, {BackgroundTransparency = 1})
		task.wait(0.35)
		LoaderFrame:Destroy()
		MainWindow.Visible = true
	end

	if WindowConfig.IntroEnabled then LoadSequence() end

	----------------------------------------------------------------
	-- Tab-Aufbau
	----------------------------------------------------------------
	local AllTabs = {}

	local function BuildTab(TabConfig, ParentHolder)
		TabConfig             = TabConfig or {}
		TabConfig.Name        = TabConfig.Name        or "Tab"
		TabConfig.Icon        = TabConfig.Icon        or ""
		TabConfig.PremiumOnly = TabConfig.PremiumOnly or false

		local TabData = {Search = {}, Sections = {}}

		local TabFrame = SetChildren(SetProps(MakeElement("Button", true), {
			Size   = UDim2.new(1, -8, 0, 30),
			Parent = ParentHolder,
			BackgroundColor3 = Theme().Second,
			BackgroundTransparency = 1
		}), {
			MakeElement("Corner", 0, 7),
			SetProps(MakeElement("Image", TabConfig.Icon), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size        = UDim2.new(0, 16, 0, 16),
				Position    = UDim2.new(0, 12, 0.5, 0),
				ImageColor3 = Theme().TextDark,
				Name        = "Ico"
			}),
			SetProps(MakeElement("Label", TabConfig.Name, 13), {
				Size       = UDim2.new(1, -38, 1, 0),
				Position   = UDim2.new(0, 36, 0, 0),
				Font       = Enum.Font.GothamMedium,
				TextColor3 = Theme().TextDark,
				Name       = "Title"
			})
		})

		-- Ohne Icon rückt der Text nach links
		if TabConfig.Icon == "" then
			TabFrame.Ico.Visible   = false
			TabFrame.Title.Position = UDim2.new(0, 14, 0, 0)
			TabFrame.Title.Size     = UDim2.new(1, -16, 1, 0)
		end

		local TabItemContainer = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Theme().Divider, 3), {
			Size     = UDim2.new(1, -SIDEBAR, 1, -TOPBAR),
			Position = UDim2.new(0, SIDEBAR, 0, TOPBAR),
			Parent   = MainWindow,
			Visible  = false,
			Name     = "ItemContainer"
		}), {
			MakeElement("List", 0, 8),
			MakeElement("Padding", 14, 14, 14, 12)
		}), "Divider")

		TabData.Frame     = TabFrame
		TabData.Container = TabItemContainer
		table.insert(AllTabs, TabData)

		AddConnection(TabItemContainer.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			TabItemContainer.CanvasSize = UDim2.new(0, 0, 0, TabItemContainer.UIListLayout.AbsoluteContentSize.Y + 26)
		end)

		local function Activate()
			for _, t in ipairs(AllTabs) do
				Tween(t.Frame.Ico,   0.2, {ImageColor3 = Theme().TextDark})
				Tween(t.Frame.Title, 0.2, {TextColor3  = Theme().TextDark})
				Tween(t.Frame,       0.2, {BackgroundTransparency = 1})
				t.Container.Visible = false
			end
			Tween(TabFrame.Ico,   0.2, {ImageColor3 = Accent()})
			Tween(TabFrame.Title, 0.2, {TextColor3  = Accent()})
			TabItemContainer.Visible = true
			CurrentTab = TabData
			ApplySearch(TabData, SearchOpen and SearchBox.Text or "")
		end
		TabData.Activate = Activate

		if FirstTab then
			FirstTab = false
			TabFrame.Ico.ImageColor3 = Accent()
			TabFrame.Title.TextColor3 = Accent()
			TabItemContainer.Visible = true
			CurrentTab = TabData
		end

		AddConnection(TabFrame.MouseEnter, function()
			if CurrentTab ~= TabData then Tween(TabFrame, 0.15, {BackgroundTransparency = 0.55}) end
		end)
		AddConnection(TabFrame.MouseLeave, function()
			Tween(TabFrame, 0.15, {BackgroundTransparency = 1})
		end)
		AddConnection(TabFrame.MouseButton1Click, function()
			PlayClick()
			Activate()
		end)

		------------------------------------------------------------
		-- Elemente
		------------------------------------------------------------
		local function GetElements(ItemParent, SectionData)

			local function Register(Frame, Name)
				local entry = {Frame = Frame, Name = tostring(Name or "")}
				table.insert(TabData.Search, entry)
				if SectionData then table.insert(SectionData.Items, entry) end
				return entry
			end

			-- Standard-Zeile
			local function Row(height, name)
				local RowFrame = AddThemeObject(SetProps(MakeElement("RoundFrame", Theme().Second, 0, 8), {
					Size   = UDim2.new(1, 0, 0, height or 44),
					Parent = ItemParent
				}), "Second")
				Register(RowFrame, name)
				return RowFrame
			end

			local function Hoverable(RowFrame, Click)
				AddConnection(Click.MouseEnter, function()
					Tween(RowFrame, 0.18, {BackgroundColor3 = Lighten(Theme().Second, 6)})
				end)
				AddConnection(Click.MouseLeave, function()
					Tween(RowFrame, 0.18, {BackgroundColor3 = Theme().Second})
				end)
			end

			local function Title(RowFrame, Text)
				return AddThemeObject(SetProps(MakeElement("Label", Text, 14), {
					Parent      = RowFrame,
					AnchorPoint = Vector2.new(0, 0.5),
					Size        = UDim2.new(1, -110, 0, 18),
					Position    = UDim2.new(0, 16, 0.5, 0),
					Font        = Enum.Font.GothamMedium,
					Name        = "Content"
				}), "Text")
			end

			local ElementFunction = {}

			--------------------------------------------------------
			function ElementFunction:AddLabel(Text)
				local LabelFrame = Row(40, Text)
				local Lbl = Title(LabelFrame, Text)
				local LabelFunction = {}
				function LabelFunction:Set(ToChange) Lbl.Text = ToChange end
				return LabelFunction
			end

			--------------------------------------------------------
			function ElementFunction:AddParagraph(Text, Content)
				Text, Content = Text or "Text", Content or ""
				local Frame = Row(46, Text)
				local Head = AddThemeObject(SetProps(MakeElement("Label", Text, 14), {
					Parent = Frame, Size = UDim2.new(1, -28, 0, 16),
					Position = UDim2.new(0, 16, 0, 12), Font = Enum.Font.GothamBold, Name = "Title"
				}), "Text")
				local Body = AddThemeObject(SetProps(MakeElement("Label", "", 12), {
					Parent = Frame, Size = UDim2.new(1, -32, 0, 0),
					Position = UDim2.new(0, 16, 0, 32), Name = "Content", TextWrapped = true
				}), "TextDark")
				AddConnection(Body:GetPropertyChangedSignal("Text"), function()
					Body.Size  = UDim2.new(1, -32, 0, Body.TextBounds.Y)
					Frame.Size = UDim2.new(1, 0, 0, Body.TextBounds.Y + 46)
				end)
				Body.Text = Content
				local ParagraphFunction = {}
				function ParagraphFunction:Set(ToChange) Body.Text = ToChange end
				return ParagraphFunction
			end

			--------------------------------------------------------
			function ElementFunction:AddButton(ButtonConfig)
				ButtonConfig          = ButtonConfig or {}
				ButtonConfig.Name     = ButtonConfig.Name     or "Button"
				ButtonConfig.Callback = ButtonConfig.Callback or function() end

				local Button = {}
				local Frame  = Row(44, ButtonConfig.Name)
				local Lbl    = Title(Frame, ButtonConfig.Name)
				local Click  = SetProps(MakeElement("Button", true), {Parent = Frame, Size = UDim2.new(1, 0, 1, 0)})

				-- Pfeil rechts
				local ArrowHolder = Create("Frame", {
					Parent = Frame, AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.new(0, 14, 0, 14),
					BackgroundTransparency = 1
				})
				Bar(ArrowHolder, 7, 1.6, 0, -2.4, 40, Theme().TextDark)
				Bar(ArrowHolder, 7, 1.6, 0,  2.4, -40, Theme().TextDark)

				Hoverable(Frame, Click)
				AddConnection(Click.MouseButton1Click, function()
					PlayClick()
					task.spawn(ButtonConfig.Callback)
				end)

				function Button:Set(t) Lbl.Text = t end
				return Button
			end

			--------------------------------------------------------
			function ElementFunction:AddToggle(ToggleConfig)
				ToggleConfig          = ToggleConfig or {}
				ToggleConfig.Name     = ToggleConfig.Name     or "Toggle"
				ToggleConfig.Default  = ToggleConfig.Default  or false
				ToggleConfig.Callback = ToggleConfig.Callback or function() end
				ToggleConfig.Color    = ToggleConfig.Color    or Accent()
				ToggleConfig.Save     = ToggleConfig.Save     or false

				local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save, Type = "Toggle"}
				local Frame  = Row(44, ToggleConfig.Name)
				Title(Frame, ToggleConfig.Name)
				local Click  = SetProps(MakeElement("Button", true), {Parent = Frame, Size = UDim2.new(1, 0, 1, 0)})

				local Box = SetChildren(SetProps(MakeElement("RoundFrame", ToggleConfig.Color, 0, 6), {
					Parent      = Frame,
					Size        = UDim2.new(0, 26, 0, 26),
					AnchorPoint = Vector2.new(1, 0.5),
					Position    = UDim2.new(1, -16, 0.5, 0)
				}), {
					SetProps(MakeElement("Stroke", ToggleConfig.Color, 1), {Name = "Stroke"}),
					SetProps(MakeElement("Image", "rbxassetid://3944680095"), {
						Size        = UDim2.new(0, 18, 0, 18),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position    = UDim2.new(0.5, 0, 0.5, 0),
						ImageColor3 = Color3.fromRGB(255, 255, 255),
						Name        = "Ico"
					})
				})

				function Toggle:Set(Value)
					Toggle.Value = Value and true or false
					Tween(Box, 0.25, {BackgroundColor3 = Toggle.Value and ToggleConfig.Color or Theme().Third})
					Tween(Box.Stroke, 0.25, {Color = Toggle.Value and ToggleConfig.Color or Theme().Stroke})
					Tween(Box.Ico, 0.25, {
						ImageTransparency = Toggle.Value and 0 or 1,
						Size = Toggle.Value and UDim2.new(0, 18, 0, 18) or UDim2.new(0, 8, 0, 8)
					})
					ToggleConfig.Callback(Toggle.Value)
				end

				Toggle:Set(Toggle.Value)
				Hoverable(Frame, Click)
				AddConnection(Click.MouseButton1Click, function()
					PlayClick()
					Toggle:Set(not Toggle.Value)
					SaveCfg(game.GameId)
				end)

				if ToggleConfig.Flag then Library.Flags[ToggleConfig.Flag] = Toggle end
				return Toggle
			end

			--------------------------------------------------------
			function ElementFunction:AddBind(BindConfig)
				BindConfig          = BindConfig or {}
				BindConfig.Name     = BindConfig.Name     or "Keybind"
				BindConfig.Default  = BindConfig.Default  or Enum.KeyCode.Unknown
				BindConfig.Hold     = BindConfig.Hold     or false
				BindConfig.Callback = BindConfig.Callback or function() end
				BindConfig.Save     = BindConfig.Save     or false

				local Bind    = {Value = nil, Binding = false, Type = "Bind", Save = BindConfig.Save}
				local Holding = false

				local Frame = Row(44, BindConfig.Name)
				Title(Frame, BindConfig.Name)
				local Click = SetProps(MakeElement("Button", true), {Parent = Frame, Size = UDim2.new(1, 0, 1, 0)})

				local Pill = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Theme().Third, 0, 6), {
					Parent      = Frame,
					Size        = UDim2.new(0, 90, 0, 26),
					AnchorPoint = Vector2.new(1, 0.5),
					Position    = UDim2.new(1, -16, 0.5, 0)
				}), {
					AddThemeObject(SetProps(MakeElement("Label", "", 12), {
						Size           = UDim2.new(1, 0, 1, 0),
						Font           = Enum.Font.GothamMedium,
						TextXAlignment = Enum.TextXAlignment.Center,
						Name           = "Value"
					}), "TextDark")
				}), "Third")

				AddConnection(Pill.Value:GetPropertyChangedSignal("Text"), function()
					Tween(Pill, 0.2, {Size = UDim2.new(0, math.max(Pill.Value.TextBounds.X + 22, 46), 0, 26)})
				end)

				AddConnection(Click.MouseButton1Click, function()
					PlayClick()
					if Bind.Binding then return end
					Bind.Binding = true
					Pill.Value.Text = "..."
					Tween(Pill, 0.2, {BackgroundColor3 = Accent()})
				end)

				AddConnection(UserInputService.InputBegan, function(Input)
					if UserInputService:GetFocusedTextBox() then return end
					if (Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value) and not Bind.Binding then
						if BindConfig.Hold then
							Holding = true
							BindConfig.Callback(Holding)
						else
							BindConfig.Callback()
						end
					elseif Bind.Binding then
						local Key
						pcall(function() if not CheckKey(BlacklistedKeys, Input.KeyCode) then Key = Input.KeyCode end end)
						pcall(function() if CheckKey(WhitelistedMouse, Input.UserInputType) and not Key then Key = Input.UserInputType end end)
						Key = Key or Bind.Value
						Bind:Set(Key)
						Tween(Pill, 0.2, {BackgroundColor3 = Theme().Third})
						SaveCfg(game.GameId)
					end
				end)

				AddConnection(UserInputService.InputEnded, function(Input)
					if Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value then
						if BindConfig.Hold and Holding then
							Holding = false
							BindConfig.Callback(Holding)
						end
					end
				end)

				Hoverable(Frame, Click)

				function Bind:Set(Key)
					Bind.Binding = false
					Bind.Value   = Key or Bind.Value
					Bind.Value   = (typeof(Bind.Value) == "EnumItem" and Bind.Value.Name) or Bind.Value
					Pill.Value.Text = tostring(Bind.Value)
				end

				Bind:Set(BindConfig.Default)
				if BindConfig.Flag then Library.Flags[BindConfig.Flag] = Bind end
				return Bind
			end

			--------------------------------------------------------
			function ElementFunction:AddSlider(SliderConfig)
				SliderConfig           = SliderConfig or {}
				SliderConfig.Name      = SliderConfig.Name      or "Slider"
				SliderConfig.Min       = SliderConfig.Min       or 0
				SliderConfig.Max       = SliderConfig.Max       or 100
				SliderConfig.Increment = SliderConfig.Increment or 1
				SliderConfig.Default   = SliderConfig.Default   or SliderConfig.Min
				SliderConfig.Callback  = SliderConfig.Callback  or function() end
				SliderConfig.ValueName = SliderConfig.ValueName or ""
				SliderConfig.Color     = SliderConfig.Color     or Accent()
				SliderConfig.Save      = SliderConfig.Save      or false

				local Slider   = {Value = SliderConfig.Default, Save = SliderConfig.Save, Type = "Slider"}
				local Dragging = false

				local Frame = Row(58, SliderConfig.Name)
				AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 14), {
					Parent = Frame, Size = UDim2.new(1, -110, 0, 16),
					Position = UDim2.new(0, 16, 0, 11), Font = Enum.Font.GothamMedium
				}), "Text")

				local ValueLabel = AddThemeObject(SetProps(MakeElement("Label", "", 12), {
					Parent = Frame, Size = UDim2.new(0, 90, 0, 16),
					Position = UDim2.new(1, -106, 0, 12), TextXAlignment = Enum.TextXAlignment.Right
				}), "TextDark")

				local Track = AddThemeObject(SetProps(MakeElement("RoundFrame", Theme().Third, 1, 0), {
					Parent = Frame, Size = UDim2.new(1, -32, 0, 5), Position = UDim2.new(0, 16, 0, 38)
				}), "Third")

				local Fill = SetProps(MakeElement("RoundFrame", SliderConfig.Color, 1, 0), {
					Parent = Track, Size = UDim2.new(0, 0, 1, 0)
				})

				local Knob = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 1, 0), {
					Parent = Track, Size = UDim2.new(0, 12, 0, 12),
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 3
				}), {MakeElement("Stroke", SliderConfig.Color, 1.5)})

				local Hit = SetProps(MakeElement("Button", true), {
					Parent = Frame, Size = UDim2.new(1, -32, 0, 22), Position = UDim2.new(0, 16, 0, 30),
					BackgroundTransparency = 1
				})

				Hit.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = true
						Tween(Knob, 0.15, {Size = UDim2.new(0, 15, 0, 15)})
					end
				end)
				Hit.InputEnded:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = false
						Tween(Knob, 0.15, {Size = UDim2.new(0, 12, 0, 12)})
						SaveCfg(game.GameId)
					end
				end)
				AddConnection(UserInputService.InputChanged, function()
					if Dragging then
						local scale = math.clamp((Mouse.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
						Slider:Set(SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * scale))
					end
				end)

				function Slider:Set(Value)
					local inc = SliderConfig.Increment
					if type(inc) ~= "number" or inc <= 0 then inc = 1 end
					self.Value = math.clamp(Round(Value, inc), SliderConfig.Min, SliderConfig.Max)
					local a = (self.Value - SliderConfig.Min) / math.max(SliderConfig.Max - SliderConfig.Min, 1e-6)
					Tween(Fill, 0.12, {Size = UDim2.fromScale(a, 1)}, Enum.EasingStyle.Quad)
					Tween(Knob, 0.12, {Position = UDim2.new(a, 0, 0.5, 0)}, Enum.EasingStyle.Quad)
					ValueLabel.Text = tostring(self.Value) .. (SliderConfig.ValueName ~= "" and (" " .. SliderConfig.ValueName) or "")
					SliderConfig.Callback(self.Value)
				end

				Slider:Set(Slider.Value)
				if SliderConfig.Flag then Library.Flags[SliderConfig.Flag] = Slider end
				return Slider
			end

			--------------------------------------------------------
			function ElementFunction:AddDropdown(DropdownConfig)
				DropdownConfig          = DropdownConfig or {}
				DropdownConfig.Name     = DropdownConfig.Name     or "Dropdown"
				DropdownConfig.Options  = DropdownConfig.Options  or {}
				DropdownConfig.Default  = DropdownConfig.Default  or ""
				DropdownConfig.Callback = DropdownConfig.Callback or function() end
				DropdownConfig.Save     = DropdownConfig.Save     or false

				local Dropdown = {
					Value = DropdownConfig.Default, Options = DropdownConfig.Options,
					Buttons = {}, Toggled = false, Type = "Dropdown", Save = DropdownConfig.Save
				}
				local MaxElements = 5
				if not table.find(Dropdown.Options, Dropdown.Value) then Dropdown.Value = "..." end

				local Frame = AddThemeObject(SetProps(MakeElement("RoundFrame", Theme().Second, 0, 8), {
					Size = UDim2.new(1, 0, 0, 44), Parent = ItemParent, ClipsDescendants = true
				}), "Second")
				Register(Frame, DropdownConfig.Name)

				local List      = MakeElement("List", 0, 4)
				local Options   = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Theme().Divider, 3), {
					Parent = Frame, Position = UDim2.new(0, 10, 0, 46),
					Size = UDim2.new(1, -20, 1, -56), ClipsDescendants = true
				}), {List}), "Divider")

				local Head = SetProps(MakeElement("TFrame"), {Parent = Frame, Size = UDim2.new(1, 0, 0, 44), Name = "F"})
				AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 14), {
					Parent = Head, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -150, 0, 18),
					Position = UDim2.new(0, 16, 0.5, 0), Font = Enum.Font.GothamMedium, Name = "Content"
				}), "Text")
				local Selected = AddThemeObject(SetProps(MakeElement("Label", "...", 12), {
					Parent = Head, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.new(0, 150, 0, 16),
					Position = UDim2.new(1, -38, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, Name = "Selected"
				}), "TextDark")

				local ChevHolder = Create("Frame", {
					Parent = Head, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
					Size = UDim2.new(0, 14, 0, 14), BackgroundTransparency = 1
				})
				Bar(ChevHolder, 7, 1.6, -2.3, 0,  40, Theme().TextDark)
				Bar(ChevHolder, 7, 1.6,  2.3, 0, -40, Theme().TextDark)

				local Click = SetProps(MakeElement("Button", true), {Parent = Head, Size = UDim2.new(1, 0, 1, 0)})

				AddConnection(List:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					Options.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y)
				end)

				local function AddOptions(opts)
					for _, Option in pairs(opts) do
						local OptionBtn = AddThemeObject(SetChildren(SetProps(MakeElement("Button", true), {
							Parent = Options, Size = UDim2.new(1, 0, 0, 28),
							BackgroundColor3 = Theme().Third, BackgroundTransparency = 0.35
						}), {
							MakeElement("Corner", 0, 6),
							AddThemeObject(SetProps(MakeElement("Label", Option, 12, 0.35), {
								Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -10, 1, 0), Name = "Title"
							}), "Text")
						}), "Third")
						AddConnection(OptionBtn.MouseButton1Click, function()
							PlayClick()
							Dropdown:Set(Option)
							SaveCfg(game.GameId)
						end)
						Dropdown.Buttons[Option] = OptionBtn
					end
				end

				function Dropdown:Refresh(opts, Delete)
					if Delete then
						for _, v in pairs(Dropdown.Buttons) do v:Destroy() end
						table.clear(Dropdown.Options)
						table.clear(Dropdown.Buttons)
					end
					Dropdown.Options = opts
					AddOptions(Dropdown.Options)
				end

				function Dropdown:Set(Value)
					for _, v in pairs(Dropdown.Buttons) do
						Tween(v, 0.15, {BackgroundColor3 = Theme().Third, BackgroundTransparency = 0.35}, Enum.EasingStyle.Quad)
						Tween(v.Title, 0.15, {TextTransparency = 0.35}, Enum.EasingStyle.Quad)
					end
					if not table.find(Dropdown.Options, Value) then
						Dropdown.Value = "..."
						Selected.Text  = Dropdown.Value
						return
					end
					Dropdown.Value = Value
					Selected.Text  = Value
					Tween(Dropdown.Buttons[Value], 0.15, {BackgroundColor3 = Accent(), BackgroundTransparency = 0.15}, Enum.EasingStyle.Quad)
					Tween(Dropdown.Buttons[Value].Title, 0.15, {TextTransparency = 0}, Enum.EasingStyle.Quad)
					return DropdownConfig.Callback(Dropdown.Value)
				end

				AddConnection(Click.MouseButton1Click, function()
					PlayClick()
					Dropdown.Toggled = not Dropdown.Toggled
					for _, b in ipairs(ChevHolder:GetChildren()) do
						if b:IsA("Frame") then Tween(b, 0.15, {Rotation = -b.Rotation}, Enum.EasingStyle.Quad) end
					end
					local h = (#Dropdown.Options > MaxElements)
						and (44 + MaxElements * 32 + 10)
						or  (44 + List.AbsoluteContentSize.Y + 14)
					Tween(Frame, 0.2, {Size = Dropdown.Toggled and UDim2.new(1, 0, 0, h) or UDim2.new(1, 0, 0, 44)}, Enum.EasingStyle.Quad)
				end)

				Dropdown:Refresh(Dropdown.Options, false)
				Dropdown:Set(Dropdown.Value)
				if DropdownConfig.Flag then Library.Flags[DropdownConfig.Flag] = Dropdown end
				return Dropdown
			end

			--------------------------------------------------------
			function ElementFunction:AddTextbox(TextboxConfig)
				TextboxConfig               = TextboxConfig or {}
				TextboxConfig.Name          = TextboxConfig.Name          or "Textbox"
				TextboxConfig.Default       = TextboxConfig.Default       or ""
				TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false
				TextboxConfig.Callback      = TextboxConfig.Callback      or function() end

				local Frame = Row(44, TextboxConfig.Name)
				Title(Frame, TextboxConfig.Name)
				local Click = SetProps(MakeElement("Button", true), {Parent = Frame, Size = UDim2.new(1, 0, 1, 0)})

				local Box = AddThemeObject(SetProps(MakeElement("RoundFrame", Theme().Third, 0, 6), {
					Parent = Frame, Size = UDim2.new(0, 120, 0, 26),
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0)
				}), "Third")

				local Input = Create("TextBox", {
					Parent = Box, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
					BackgroundTransparency = 1, Text = TextboxConfig.Default,
					PlaceholderText = "...", PlaceholderColor3 = Theme().TextDark,
					TextColor3 = Theme().Text, TextSize = 12, Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = false
				})

				Hoverable(Frame, Click)
				AddConnection(Click.MouseButton1Click, function() Input:CaptureFocus() end)
				AddConnection(Input.Focused,  function() Tween(Box, 0.15, {BackgroundColor3 = Lighten(Theme().Third, 8)}) end)
				AddConnection(Input.FocusLost, function()
					Tween(Box, 0.15, {BackgroundColor3 = Theme().Third})
					TextboxConfig.Callback(Input.Text)
					if TextboxConfig.TextDisappear then Input.Text = "" end
				end)

				local TB = {}
				function TB:Set(t) Input.Text = t end
				return TB
			end

			--------------------------------------------------------
			function ElementFunction:AddColorpicker(ColorpickerConfig)
				ColorpickerConfig          = ColorpickerConfig or {}
				ColorpickerConfig.Name     = ColorpickerConfig.Name     or "Colorpicker"
				ColorpickerConfig.Default  = ColorpickerConfig.Default  or Accent()
				ColorpickerConfig.Callback = ColorpickerConfig.Callback or function() end
				ColorpickerConfig.Save     = ColorpickerConfig.Save     or false
				-- Optional: zusätzliche Checkbox rechts (wie "FOV" in der Vorlage)
				ColorpickerConfig.Toggle          = ColorpickerConfig.Toggle          or false
				ColorpickerConfig.ToggleDefault   = ColorpickerConfig.ToggleDefault   or false
				ColorpickerConfig.ToggleCallback  = ColorpickerConfig.ToggleCallback  or function() end

				local Colorpicker = {Value = ColorpickerConfig.Default, Toggled = false, Type = "Colorpicker", Save = ColorpickerConfig.Save}
				local ColorH, ColorS, ColorV = Color3.toHSV(ColorpickerConfig.Default)

				local Frame = AddThemeObject(SetProps(MakeElement("RoundFrame", Theme().Second, 0, 8), {
					Size = UDim2.new(1, 0, 0, 44), Parent = ItemParent, ClipsDescendants = true
				}), "Second")
				Register(Frame, ColorpickerConfig.Name)

				local Head = SetProps(MakeElement("TFrame"), {Parent = Frame, Size = UDim2.new(1, 0, 0, 44), Name = "F"})
				AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 14), {
					Parent = Head, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -110, 0, 18),
					Position = UDim2.new(0, 16, 0.5, 0), Font = Enum.Font.GothamMedium, Name = "Content"
				}), "Text")

				local SwatchX = ColorpickerConfig.Toggle and -50 or -16
				local Swatch  = SetChildren(SetProps(MakeElement("RoundFrame", Colorpicker.Value, 0, 6), {
					Parent = Head, Size = UDim2.new(0, 26, 0, 26),
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, SwatchX, 0.5, 0)
				}), {MakeElement("Stroke", Theme().Stroke, 1)})

				local Click = SetProps(MakeElement("Button", true), {Parent = Head, Size = UDim2.new(1, 0, 1, 0)})

				-- optionale Checkbox
				local SideToggle
				if ColorpickerConfig.Toggle then
					local Box = SetChildren(SetProps(MakeElement("RoundFrame", Accent(), 0, 6), {
						Parent = Head, Size = UDim2.new(0, 26, 0, 26),
						AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), ZIndex = 3
					}), {
						SetProps(MakeElement("Stroke", Accent(), 1), {Name = "Stroke"}),
						SetProps(MakeElement("Image", "rbxassetid://3944680095"), {
							Size = UDim2.new(0, 18, 0, 18), AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.5, 0, 0.5, 0), ImageColor3 = Color3.fromRGB(255,255,255), Name = "Ico", ZIndex = 4
						}),
						SetProps(MakeElement("Button", true), {Size = UDim2.new(1, 0, 1, 0), Name = "Hit", ZIndex = 5})
					})
					SideToggle = {Value = ColorpickerConfig.ToggleDefault}
					function SideToggle:Set(v)
						SideToggle.Value = v and true or false
						Tween(Box, 0.25, {BackgroundColor3 = SideToggle.Value and Accent() or Theme().Third})
						Tween(Box.Stroke, 0.25, {Color = SideToggle.Value and Accent() or Theme().Stroke})
						Tween(Box.Ico, 0.25, {
							ImageTransparency = SideToggle.Value and 0 or 1,
							Size = SideToggle.Value and UDim2.new(0, 18, 0, 18) or UDim2.new(0, 8, 0, 8)
						})
						ColorpickerConfig.ToggleCallback(SideToggle.Value)
					end
					SideToggle:Set(ColorpickerConfig.ToggleDefault)
					Box.Hit.MouseButton1Click:Connect(function()
						PlayClick()
						SideToggle:Set(not SideToggle.Value)
					end)
					Colorpicker.Toggle = SideToggle
				end

				-- Panel
				local Panel = SetProps(MakeElement("TFrame"), {
					Parent = Frame, Position = UDim2.new(0, 0, 0, 44),
					Size = UDim2.new(1, 0, 0, 100), ClipsDescendants = true
				})

				local Sat = Create("ImageLabel", {
					Parent = Panel, Position = UDim2.new(0, 16, 0, 4),
					Size = UDim2.new(1, -52, 0, 88), Image = "rbxassetid://4155801252",
					BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1), BorderSizePixel = 0, Visible = false
				})
				Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Sat})

				local SatCursor = Create("Frame", {
					Parent = Sat, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 12, 0, 12),
					Position = UDim2.new(ColorS, 0, 1 - ColorV, 0), BackgroundTransparency = 1, ZIndex = 3
				})
				Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SatCursor})
				Create("UIStroke", {Parent = SatCursor, Color = Color3.fromRGB(255,255,255), Thickness = 2})

				local Hue = Create("Frame", {
					Parent = Panel, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 4),
					Size = UDim2.new(0, 16, 0, 88), BackgroundColor3 = Color3.fromRGB(255,255,255),
					BorderSizePixel = 0, Visible = false
				})
				Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Hue})
				Create("UIGradient", {Parent = Hue, Rotation = 270, Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,   0,   4)),
					ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234, 255,   0)),
					ColorSequenceKeypoint.new(0.40, Color3.fromRGB( 21, 255,   0)),
					ColorSequenceKeypoint.new(0.60, Color3.fromRGB(  0, 255, 255)),
					ColorSequenceKeypoint.new(0.80, Color3.fromRGB(  0,  17, 255)),
					ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255,   0, 251)),
					ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,   0,   4))
				}})

				local HueCursor = Create("Frame", {
					Parent = Hue, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 14, 0, 14),
					Position = UDim2.new(0.5, 0, 1 - ColorH, 0), BackgroundTransparency = 1, ZIndex = 3
				})
				Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = HueCursor})
				Create("UIStroke", {Parent = HueCursor, Color = Color3.fromRGB(255,255,255), Thickness = 2})

				local ColorInput, HueInput

				local function UpdateColor()
					Sat.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
					Colorpicker:Set(Color3.fromHSV(ColorH, ColorS, ColorV))
				end

				AddConnection(Sat.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if ColorInput then ColorInput:Disconnect() end
						ColorInput = AddConnection(RunService.RenderStepped, function()
							local x = math.clamp(Mouse.X - Sat.AbsolutePosition.X, 0, Sat.AbsoluteSize.X) / Sat.AbsoluteSize.X
							local y = math.clamp(Mouse.Y - Sat.AbsolutePosition.Y, 0, Sat.AbsoluteSize.Y) / Sat.AbsoluteSize.Y
							SatCursor.Position = UDim2.new(x, 0, y, 0)
							ColorS, ColorV = x, 1 - y
							UpdateColor()
						end)
					end
				end)
				AddConnection(Sat.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if ColorInput then ColorInput:Disconnect() end
						SaveCfg(game.GameId)
					end
				end)
				AddConnection(Hue.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if HueInput then HueInput:Disconnect() end
						HueInput = AddConnection(RunService.RenderStepped, function()
							local y = math.clamp(Mouse.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y
							HueCursor.Position = UDim2.new(0.5, 0, y, 0)
							ColorH = 1 - y
							UpdateColor()
						end)
					end
				end)
				AddConnection(Hue.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if HueInput then HueInput:Disconnect() end
						SaveCfg(game.GameId)
					end
				end)

				AddConnection(Click.MouseButton1Click, function()
					PlayClick()
					Colorpicker.Toggled = not Colorpicker.Toggled
					Sat.Visible = Colorpicker.Toggled
					Hue.Visible = Colorpicker.Toggled
					Tween(Frame, 0.2, {Size = Colorpicker.Toggled and UDim2.new(1, 0, 0, 44 + 100) or UDim2.new(1, 0, 0, 44)}, Enum.EasingStyle.Quad)
				end)

				function Colorpicker:Set(Value)
					Colorpicker.Value      = Value
					Swatch.BackgroundColor3 = Value
					ColorpickerConfig.Callback(Value)
				end

				Colorpicker:Set(Colorpicker.Value)
				if ColorpickerConfig.Flag then Library.Flags[ColorpickerConfig.Flag] = Colorpicker end
				return Colorpicker
			end

			return ElementFunction
		end

		------------------------------------------------------------
		-- Sections (kleine graue Überschrift wie "Silent Aim Option")
		------------------------------------------------------------
		local ElementFunction = {}

		function ElementFunction:AddSection(SectionConfig)
			SectionConfig      = SectionConfig or {}
			SectionConfig.Name = SectionConfig.Name or "Section"

			local SectionData = {Items = {}}

			local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
				Size   = UDim2.new(1, 0, 0, 26),
				Parent = TabItemContainer
			}), {
				AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 12), {
					Size     = UDim2.new(1, -8, 0, 14),
					Position = UDim2.new(0, 4, 0, 0),
					Font     = Enum.Font.GothamMedium
				}), "TextDark"),
				SetChildren(SetProps(MakeElement("TFrame"), {
					Size     = UDim2.new(1, 0, 1, -22),
					Position = UDim2.new(0, 0, 0, 22),
					Name     = "Holder"
				}), {MakeElement("List", 0, 8)}),
			})

			SectionData.Frame = SectionFrame
			table.insert(TabData.Sections, SectionData)

			AddConnection(SectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
				local y = SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y
				SectionFrame.Size        = UDim2.new(1, 0, 0, y + 26)
				SectionFrame.Holder.Size = UDim2.new(1, 0, 0, y)
			end)

			local SectionFunction = {}
			for i, v in next, GetElements(SectionFrame.Holder, SectionData) do SectionFunction[i] = v end
			return SectionFunction
		end

		for i, v in next, GetElements(TabItemContainer, nil) do ElementFunction[i] = v end

		if TabConfig.PremiumOnly then
			for i in next, ElementFunction do ElementFunction[i] = function() end end
			local ll = TabItemContainer:FindFirstChild("UIListLayout"); if ll then ll:Destroy() end
			local pp = TabItemContainer:FindFirstChild("UIPadding");    if pp then pp:Destroy() end
			SetChildren(SetProps(MakeElement("TFrame"), {Size = UDim2.new(1, 0, 1, 0), Parent = TabItemContainer}), {
				AddThemeObject(SetProps(MakeElement("Label", "Unauthorised Access", 14), {
					Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 20, 0, 20)
				}), "TextDark")
			})
		end

		return ElementFunction, TabFrame, TabData
	end

	----------------------------------------------------------------
	-- Tabs / Gruppen / Drag & Drop
	----------------------------------------------------------------
	local TabFunction      = {}
	local tabLayoutOrder   = 0
	local tabGroupRegistry = {}
	local allGroups        = {}

	local function NextOrder()
		tabLayoutOrder = tabLayoutOrder + 1
		return tabLayoutOrder
	end

	local Drag = {active = false, src = nil, ghost = nil}

	local function GetOrderedTabs()
		local t = {}
		for _, c in ipairs(TabHolder:GetChildren()) do
			if c:IsA("TextButton") and c:FindFirstChild("Ico") and c:FindFirstChild("Title") then
				table.insert(t, c)
			end
		end
		table.sort(t, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		return t
	end

	local function TabUnderMouse(exclude)
		for _, c in ipairs(TabHolder:GetChildren()) do
			if c:IsA("TextButton") and c:FindFirstChild("Ico") and c ~= exclude and c.Visible then
				local p, s = c.AbsolutePosition, c.AbsoluteSize
				if Mouse.X >= p.X and Mouse.X <= p.X + s.X and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y then return c end
			end
		end
	end

	local function GroupHeaderUnderMouse()
		for _, g in ipairs(allGroups) do
			local h = g.header
			if h then
				local p, s = h.AbsolutePosition, h.AbsoluteSize
				if Mouse.X >= p.X and Mouse.X <= p.X + s.X and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y then return g end
			end
		end
	end

	local function RemoveFromGroup(tabBtn)
		local reg = tabGroupRegistry[tabBtn]
		if not reg then return end
		for i, v in ipairs(reg.frames) do
			if v == tabBtn then table.remove(reg.frames, i) break end
		end
		tabGroupRegistry[tabBtn] = nil
	end

	local function AddToGroup(tabBtn, groupData)
		RemoveFromGroup(tabBtn)
		table.insert(groupData.frames, tabBtn)
		tabGroupRegistry[tabBtn] = groupData
		tabBtn.Visible = not groupData.collapsed
	end

	local function EndDrag()
		Drag.active = false
		if Drag.ghost then Drag.ghost:Destroy() Drag.ghost = nil end
		Drag.src = nil
		for _, c in ipairs(TabHolder:GetChildren()) do
			if c:IsA("TextButton") then Tween(c, 0.1, {BackgroundTransparency = 1}) end
		end
	end

	local function StartDrag(tabFrame)
		Drag.active = true
		Drag.src    = tabFrame
		tabFrame.BackgroundColor3       = Accent()
		tabFrame.BackgroundTransparency = 0.6

		local ghost = Create("Frame", {
			Parent = Container,
			Size = UDim2.new(0, tabFrame.AbsoluteSize.X, 0, tabFrame.AbsoluteSize.Y),
			BackgroundColor3 = Accent(), BackgroundTransparency = 0.35,
			BorderSizePixel = 0, ZIndex = 30
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 7), Parent = ghost})
		Create("TextLabel", {
			Parent = ghost, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1, Text = tabFrame.Title.Text, TextColor3 = Color3.fromRGB(255,255,255),
			Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31
		})
		Drag.ghost = ghost

		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not Drag.active then conn:Disconnect() return end
			if Drag.ghost then Drag.ghost.Position = UDim2.new(0, Mouse.X + 8, 0, Mouse.Y - 10) end
			local hovered = TabUnderMouse(tabFrame)
			local hgroup  = GroupHeaderUnderMouse()
			for _, c in ipairs(TabHolder:GetChildren()) do
				if c:IsA("TextButton") and c ~= tabFrame then
					local isTarget = (c == hovered) or (hgroup and c == hgroup.header)
					c.BackgroundTransparency = isTarget and 0.6 or 1
					if isTarget then c.BackgroundColor3 = Accent() end
				end
			end
		end)
	end

	local function AttachDrag(tabFrame)
		local timer, dragging = nil, false
		tabFrame.InputBegan:Connect(function(inp)
			if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			dragging = false
			timer = task.delay(0.28, function()
				if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					dragging = true
					StartDrag(tabFrame)
				end
			end)
		end)
		tabFrame.InputEnded:Connect(function(inp)
			if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if timer then pcall(task.cancel, timer) timer = nil end
			if not dragging then return end
			dragging = false
			if not (Drag.active and Drag.src == tabFrame) then return end

			local targetTab   = TabUnderMouse(tabFrame)
			local targetGroup = GroupHeaderUnderMouse()

			if targetGroup then
				RemoveFromGroup(tabFrame)
				local lastOrder = targetGroup.header.LayoutOrder
				for _, f in ipairs(targetGroup.frames) do
					if f.LayoutOrder > lastOrder then lastOrder = f.LayoutOrder end
				end
				tabFrame.LayoutOrder = lastOrder + 0.5
				local sorted = GetOrderedTabs()
				for i, btn in ipairs(sorted) do btn.LayoutOrder = i * 10 end
				tabLayoutOrder = #sorted * 10
				AddToGroup(tabFrame, targetGroup)
			elseif targetTab then
				local srcOrder = tabFrame.LayoutOrder
				tabFrame.LayoutOrder  = targetTab.LayoutOrder
				targetTab.LayoutOrder = srcOrder
				local tg = tabGroupRegistry[targetTab]
				if tg then
					AddToGroup(tabFrame, tg)
				elseif tabGroupRegistry[tabFrame] then
					RemoveFromGroup(tabFrame)
					tabFrame.Visible = true
				end
			end
			EndDrag()
		end)
	end

	function TabFunction:MakeTab(TabConfig)
		local ef, frame = BuildTab(TabConfig, TabHolder)
		if frame then
			frame.LayoutOrder = NextOrder()
			AttachDrag(frame)
		end
		return ef
	end

	function TabFunction:MakeTabGroup(GroupConfig)
		GroupConfig           = GroupConfig or {}
		GroupConfig.Name      = GroupConfig.Name      or "Group"
		GroupConfig.Collapsed = GroupConfig.Collapsed or false

		local collapsed     = GroupConfig.Collapsed
		local groupFrames   = {}
		local headerCreated = false
		local GroupLabel, headerBtn

		local groupData = {frames = groupFrames, header = nil, collapsed = collapsed}
		table.insert(allGroups, groupData)

		local function SetCollapsed(state)
			collapsed = state
			groupData.collapsed = state
			for _, tf in ipairs(groupFrames) do tf.Visible = not collapsed end
			if GroupLabel then
				Tween(GroupLabel, 0.2, {TextColor3 = collapsed and Theme().TextDark or Accent()})
			end
		end

		local function EnsureHeader()
			if headerCreated then return end
			headerCreated = true
			headerBtn = Create("TextButton", {
				Parent = TabHolder, Size = UDim2.new(1, -8, 0, 24),
				BackgroundTransparency = 1, BorderSizePixel = 0,
				Text = "", AutoButtonColor = false, LayoutOrder = NextOrder()
			})
			groupData.header = headerBtn
			GroupLabel = Create("TextLabel", {
				Parent = headerBtn, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1, Text = string.upper(GroupConfig.Name),
				TextColor3 = collapsed and Theme().TextDark or Accent(),
				TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left
			})
			headerBtn.MouseButton1Click:Connect(function() PlayClick() SetCollapsed(not collapsed) end)
			headerBtn.MouseEnter:Connect(function() Tween(GroupLabel, 0.15, {TextColor3 = Lighten(Accent(), 40)}) end)
			headerBtn.MouseLeave:Connect(function() Tween(GroupLabel, 0.15, {TextColor3 = collapsed and Theme().TextDark or Accent()}) end)
		end

		local GroupFunction = {}
		function GroupFunction:MakeTab(TabConfig)
			EnsureHeader()
			local tabEF, tabBtn = BuildTab(TabConfig, TabHolder)
			if tabBtn then
				tabBtn.LayoutOrder = NextOrder()
				table.insert(groupFrames, tabBtn)
				tabGroupRegistry[tabBtn] = groupData
				tabBtn.Visible = not collapsed
				AttachDrag(tabBtn)
			end
			return tabEF
		end
		return GroupFunction
	end

	function TabFunction:SetTitle(t) WindowName.Text = t end
	function TabFunction:Destroy()   Container:Destroy() end

	return TabFunction
end

-- ═══════════════════ Zweites Notification-System (kompatibel) ═══════════════════

local Configs_HUB = {
	Cor_Hub       = Theme().Second,
	Cor_Stroke    = Theme().Stroke,
	Cor_Text      = Theme().Text,
	Cor_DarkText  = Theme().TextDark,
	Corner_Radius = UDim.new(0, 10),
	Text_Font     = Enum.Font.GothamMedium
}

local function Create2(instance, parent, props)
	local new = Instance.new(instance)
	if props then for prop, value in pairs(props) do new[prop] = value end end
	new.Parent = parent
	return new
end

local function CreateTween(instance, prop, value, time, tweenWait)
	local tween = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Linear), {[prop] = value})
	tween:Play()
	if tweenWait then tween.Completed:Wait() end
end

local NotifiRoot = Create2("Frame", Container, {
	Size = UDim2.new(0, 300, 1, 0), Position = UDim2.new(1, 0, 0, 0),
	AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1
})
Create2("UIPadding", NotifiRoot, {PaddingLeft = UDim.new(0, 25), PaddingTop = UDim.new(0, 25), PaddingBottom = UDim.new(0, 50)})
Create2("UIListLayout", NotifiRoot, {Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Bottom})

function Library:MakeNotifi(Configs)
	Configs = Configs or {}
	local Title    = Configs.Title or "Title!"
	local text     = Configs.Text  or ""
	local timewait = Configs.Time  or 5

	local Holder = Create2("Frame", NotifiRoot, {Size = UDim2.new(2, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y})
	local Card   = Create2("Frame", Holder, {
		Size = UDim2.new(0, 250, 0, 0), BackgroundColor3 = Configs_HUB.Cor_Hub,
		Position = UDim2.new(0, 300, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0
	})
	Create2("UICorner", Card, {CornerRadius = Configs_HUB.Corner_Radius})
	Create2("UIStroke", Card, {Color = Configs_HUB.Cor_Stroke, Thickness = 1})

	Create2("TextLabel", Card, {
		Size = UDim2.new(1, -40, 0, 22), Font = Enum.Font.GothamBold, BackgroundTransparency = 1,
		Text = Title, TextSize = 15, Position = UDim2.new(0, 16, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Configs_HUB.Cor_Text
	})
	local CloseB = Create2("TextButton", Card, {
		Text = "", Font = Configs_HUB.Text_Font, BackgroundTransparency = 1,
		Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 22, 0, 22)
	})
	BuildGlyph(CloseB, "close", Configs_HUB.Cor_DarkText)

	Create2("TextLabel", Card, {
		Size = UDim2.new(1, -32, 0, 0), Position = UDim2.new(0, 16, 0, 34), TextSize = 12,
		TextColor3 = Configs_HUB.Cor_DarkText, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y, Text = text,
		Font = Configs_HUB.Text_Font, BackgroundTransparency = 1, TextWrapped = true
	})
	local Line = Create2("Frame", Card, {
		Size = UDim2.new(1, -32, 0, 2), BackgroundColor3 = Accent(),
		Position = UDim2.new(0, 16, 0, 30), BorderSizePixel = 0
	})
	Create2("UICorner", Line, {CornerRadius = UDim.new(1, 0)})
	Create2("Frame", Card, {Size = UDim2.new(0, 0, 0, 12), Position = UDim2.new(0, 0, 1, 6), BackgroundTransparency = 1})

	task.spawn(function() CreateTween(Line, "Size", UDim2.new(0, 0, 0, 2), timewait, true) end)

	local function Close()
		CreateTween(Card, "Position", UDim2.new(0, 300, 0, 0), 0.35, true)
		Holder:Destroy()
	end
	CloseB.MouseButton1Click:Connect(Close)
	task.spawn(function()
		CreateTween(Card, "Position", UDim2.new(0, 0, 0, 0), 0.4, true)
		task.wait(timewait)
		if Card and Card.Parent then Close() end
	end)
end

function Library:Destroy()
	Container:Destroy()
end

return Library
