--[[
	DEEP SEA SALVAGE - Client UI
	Type: LocalScript
	Name it: SalvageClient
	Put it in: StarterPlayer > StarterPlayerScripts

	Builds all of the on-screen UI in code: coin/pearl counters, the event
	banner, the Fleet / Shop / Logbook panels and the loot pop-ups.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("SalvageConfig"))
local remotes = ReplicatedStorage:WaitForChild("SalvageRemotes")
local StateUpdate = remotes:WaitForChild("StateUpdate")
local Notify = remotes:WaitForChild("Notify")
local Action = remotes:WaitForChild("Action")

local player = Players.LocalPlayer
local state = nil

local THEME = {
	bg = Color3.fromRGB(10, 24, 40),
	panel = Color3.fromRGB(16, 38, 62),
	card = Color3.fromRGB(24, 52, 82),
	cardHover = Color3.fromRGB(32, 66, 102),
	accent = Color3.fromRGB(60, 225, 210),
	gold = Color3.fromRGB(255, 205, 80),
	pearl = Color3.fromRGB(235, 230, 255),
	text = Color3.fromRGB(235, 245, 250),
	muted = Color3.fromRGB(140, 168, 190),
	danger = Color3.fromRGB(255, 95, 95),
	good = Color3.fromRGB(110, 235, 140),
}

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------
-- UI HELPERS
---------------------------------------------------------------------------
local function new(className, props)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			obj[key] = value
		end
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or THEME.accent,
		Thickness = thickness or 2,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function text(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = THEME.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in pairs(props) do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = new("TextLabel", defaults)
	new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 22, Parent = label })
	return label
end

local function button(props)
	local defaults = {
		BackgroundColor3 = THEME.card,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.text,
		TextScaled = true,
	}
	for key, value in pairs(props) do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local btn = new("TextButton", defaults)
	corner(btn, 8)
	new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 20, Parent = btn })
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = btn,
	})
	return btn
end

local function gradient(parent, top, bottom)
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

---------------------------------------------------------------------------
-- ROOT GUI
---------------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "SalvageUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

---------------------------------------------------------------------------
-- TOP BAR: coins + pearls
---------------------------------------------------------------------------
local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0, 500, 0, 44),
	BackgroundTransparency = 1,
	Parent = gui,
})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 10),
	Parent = topBar,
})

local function currencyPill(color, symbol, order)
	local pill = new("Frame", {
		Size = UDim2.new(0, 160, 1, 0),
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = topBar,
	})
	corner(pill, 22)
	stroke(pill, color, 2, 0.2)
	local icon = new("Frame", {
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(0, 6, 0.5, -16),
		BackgroundColor3 = color,
		Parent = pill,
	})
	corner(icon, 16)
	stroke(icon, Color3.new(1, 1, 1), 1.5, 0.5)
	text({
		Size = UDim2.fromScale(1, 1),
		Text = symbol,
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.bg,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = icon,
	})
	return text({
		Size = UDim2.new(1, -52, 0.7, 0),
		Position = UDim2.new(0, 46, 0.15, 0),
		Text = "0",
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 24,
		Parent = pill,
	})
end

local coinsLabel = currencyPill(THEME.gold, "$", 1)
local pearlsLabel = currencyPill(THEME.pearl, "P", 2)

-- Level pill with XP bar
local levelPill = new("Frame", {
	Size = UDim2.new(0, 150, 1, 0),
	BackgroundColor3 = THEME.bg,
	BackgroundTransparency = 0.15,
	LayoutOrder = 0,
	Parent = topBar,
})
corner(levelPill, 22)
stroke(levelPill, THEME.accent, 2, 0.2)
local levelLabel = text({
	Size = UDim2.new(1, -24, 0, 22),
	Position = UDim2.new(0, 12, 0, 4),
	Text = "Lv 1",
	Font = Enum.Font.GothamBlack,
	TextColor3 = THEME.accent,
	TextXAlignment = Enum.TextXAlignment.Center,
	MaxTextSize = 20,
	Parent = levelPill,
})
local xpBar = new("Frame", {
	Size = UDim2.new(1, -28, 0, 8),
	Position = UDim2.new(0, 14, 1, -14),
	BackgroundColor3 = Color3.fromRGB(30, 50, 70),
	Parent = levelPill,
})
corner(xpBar, 4)
local xpFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = THEME.accent,
	Parent = xpBar,
})
corner(xpFill, 4)

---------------------------------------------------------------------------
-- EVENT BANNER
---------------------------------------------------------------------------
local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.new(0, 440, 0, 62),
	BackgroundColor3 = THEME.bg,
	BackgroundTransparency = 0.1,
	Visible = false,
	Parent = gui,
})
corner(banner, 12)
local bannerStroke = stroke(banner, THEME.gold, 2.5, 0)
local bannerTitle = text({
	Size = UDim2.new(1, -20, 0, 24),
	Position = UDim2.new(0, 10, 0, 5),
	Font = Enum.Font.GothamBlack,
	TextColor3 = THEME.gold,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = banner,
})
local bannerDesc = text({
	Size = UDim2.new(1, -20, 0, 18),
	Position = UDim2.new(0, 10, 0, 30),
	Font = Enum.Font.Gotham,
	TextColor3 = THEME.text,
	TextXAlignment = Enum.TextXAlignment.Center,
	MaxTextSize = 15,
	Parent = banner,
})
local krakenBar = new("Frame", {
	Size = UDim2.new(1, -20, 0, 8),
	Position = UDim2.new(0, 10, 1, -12),
	BackgroundColor3 = Color3.fromRGB(40, 20, 50),
	Visible = false,
	Parent = banner,
})
corner(krakenBar, 4)
local krakenFill = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(220, 80, 200),
	Parent = krakenBar,
})
corner(krakenFill, 4)

local EVENT_COLORS = {
	StormSurge = Color3.fromRGB(150, 180, 255),
	TreasureTide = THEME.gold,
	Kraken = Color3.fromRGB(230, 110, 220),
}

local function refreshBanner()
	local id = remotes:GetAttribute("EventId")
	if not id or id == "" or not Config.Events[id] then
		banner.Visible = false
		return
	end
	local def = Config.Events[id]
	local color = EVENT_COLORS[id] or THEME.gold
	banner.Visible = true
	bannerStroke.Color = color
	bannerTitle.TextColor3 = color
	local remaining = math.max(0, math.ceil((remotes:GetAttribute("EventEnd") or 0) - now()))
	bannerTitle.Text = string.format("%s  -  %d:%02d", def.name, remaining // 60, remaining % 60)
	bannerDesc.Text = def.desc
	local maxHP = remotes:GetAttribute("KrakenMax") or 0
	if id == "Kraken" and maxHP > 0 then
		krakenBar.Visible = true
		krakenFill.Size = UDim2.fromScale(math.clamp((remotes:GetAttribute("KrakenHP") or 0) / maxHP, 0, 1), 1)
	else
		krakenBar.Visible = false
	end
end
remotes:GetAttributeChangedSignal("EventId"):Connect(refreshBanner)
remotes:GetAttributeChangedSignal("KrakenHP"):Connect(refreshBanner)

---------------------------------------------------------------------------
-- TOASTS + SPLASH
---------------------------------------------------------------------------
local toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 440, 0, 280),
	BackgroundTransparency = 1,
	Parent = gui,
})
new("UIListLayout", {
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
	Parent = toastHolder,
})
local toastCount = 0

local function toast(message, color, duration)
	toastCount += 1
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	})
	corner(frame, 10)
	stroke(frame, color, 2, 0)
	new("Frame", {
		Size = UDim2.new(0, 6, 1, -12),
		Position = UDim2.new(0, 6, 0, 6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = frame,
	})
	local label = text({
		Size = UDim2.new(1, -28, 1, -10),
		Position = UDim2.new(0, 20, 0, 5),
		Text = message,
		TextColor3 = THEME.text,
		RichText = true,
		MaxTextSize = 18,
		Parent = frame,
	})
	local scale = new("UIScale", { Scale = 0.6, Parent = frame })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local children = {}
	for _, child in ipairs(toastHolder:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 6 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end

	task.delay(duration or 3.5, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.wait(0.3)
			frame:Destroy()
		end
	end)
end

local splash = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0.8, 0, 0, 70),
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0,
	MaxTextSize = 54,
	Visible = false,
	Parent = gui,
})
local splashScale = new("UIScale", { Parent = splash })

local function showSplash(message, color)
	splash.Text = message
	splash.TextColor3 = color
	splash.TextTransparency = 0
	splash.TextStrokeTransparency = 0
	splash.Visible = true
	splashScale.Scale = 0.3
	TweenService:Create(splashScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.6, function()
		TweenService:Create(splash, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

---------------------------------------------------------------------------
-- PANEL FRAME (shared by Fleet / Shop / Logbook)
---------------------------------------------------------------------------
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromScale(0.6, 0.66),
	BackgroundColor3 = THEME.panel,
	Visible = false,
	Parent = gui,
})
new("UISizeConstraint", { MaxSize = Vector2.new(720, 470), MinSize = Vector2.new(320, 260), Parent = panel })
corner(panel, 16)
stroke(panel, THEME.accent, 2.5, 0.1)
gradient(panel, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 215))

local header = new("Frame", {
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundColor3 = THEME.bg,
	Parent = panel,
})
corner(header, 16)
local panelTitle = text({
	Size = UDim2.new(0.6, 0, 0, 30),
	Position = UDim2.new(0, 18, 0, 11),
	Font = Enum.Font.GothamBlack,
	TextColor3 = THEME.accent,
	MaxTextSize = 26,
	Parent = header,
})
local panelSubtitle = text({
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.new(0.4, -60, 0, 20),
	Position = UDim2.new(1, -58, 0, 16),
	Font = Enum.Font.Gotham,
	TextColor3 = THEME.muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	MaxTextSize = 15,
	Parent = header,
})
local closeButton = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 9),
	Size = UDim2.new(0, 34, 0, 34),
	Text = "X",
	BackgroundColor3 = THEME.danger,
	Parent = header,
})

local content = new("ScrollingFrame", {
	Position = UDim2.new(0, 12, 0, 62),
	Size = UDim2.new(1, -24, 1, -72),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = THEME.accent,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = panel,
})

local currentPanel = nil
local fleetStatusLabels = {}

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		child:Destroy()
	end
	fleetStatusLabels = {}
end

local function listLayout()
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = content })
end

local function card(height, order, accent)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = THEME.card,
		LayoutOrder = order,
		Parent = content,
	})
	corner(frame, 10)
	stroke(frame, accent or THEME.accent, 1.5, 0.55)
	return frame
end

local function riskColor(chance)
	if chance <= 0 then
		return THEME.good
	elseif chance < 0.1 then
		return THEME.gold
	end
	return THEME.danger
end

local function statusInfo(sub)
	local t = math.max(0, math.ceil(sub.endTime - now()))
	if sub.status == "Diving" then
		return "Diving in " .. Config.Zones[sub.zone].name .. "... " .. t .. "s", Color3.fromRGB(140, 215, 255)
	elseif sub.status == "Surfacing" then
		return "Surfacing!", THEME.good
	elseif sub.status == "Haul" then
		return "HAUL READY - go to your bay and hold E on the crate!", THEME.gold
	elseif sub.status == "Repairing" then
		return "Hull breach! Repairing... " .. t .. "s", THEME.danger
	end
	return "Docked", THEME.muted
end

---------------------------------------------------------------------------
-- FLEET PANEL
---------------------------------------------------------------------------
local function renderFleet()
	panelTitle.Text = "YOUR FLEET"
	local pityLeft = Config.PityLimit - (state.pity or 0)
	panelSubtitle.Text = string.format("%d/%d subs  |  Royal guaranteed in %d", #state.subs, Config.MaxFleet, pityLeft)
	listLayout()

	for i, sub in ipairs(state.subs) do
		local def, tier = Config.GetSub(sub.id)
		local row = card(92, i, def.trimColor)

		local badge = new("Frame", {
			Size = UDim2.new(0, 60, 0, 60),
			Position = UDim2.new(0, 14, 0.5, -30),
			BackgroundColor3 = def.bodyColor,
			Parent = row,
		})
		corner(badge, 30)
		stroke(badge, def.trimColor, 3, 0)
		text({
			Size = UDim2.fromScale(1, 1),
			Text = "T" .. tier,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.4,
			Parent = badge,
		})

		text({
			Size = UDim2.new(0.45, -90, 0, 24),
			Position = UDim2.new(0, 86, 0, 12),
			Text = def.name,
			Font = Enum.Font.GothamBlack,
			MaxTextSize = 22,
			Parent = row,
		})
		local statusText, statusColor = statusInfo(sub)
		local statusLabel = text({
			Size = UDim2.new(0.45, -90, 0, 18),
			Position = UDim2.new(0, 86, 0, 40),
			Text = statusText,
			Font = Enum.Font.GothamMedium,
			TextColor3 = statusColor,
			MaxTextSize = 15,
			Parent = row,
		})
		fleetStatusLabels[i] = statusLabel
		text({
			Size = UDim2.new(0.45, -90, 0, 16),
			Position = UDim2.new(0, 86, 0, 62),
			Text = string.format("Luck x%.2f  |  Hull +%d%%  |  Speed x%.2f", def.luck, math.floor(def.hull * 100 + 0.5), 1 / def.speed),
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.muted,
			MaxTextSize = 13,
			Parent = row,
		})

		-- depth selector
		local zone = Config.Zones[sub.depth]
		local risk = Config.BreachChance(def, sub.depth)
		local selector = new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.new(0.5, 0, 0, 34),
			BackgroundTransparency = 1,
			Parent = row,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			Parent = selector,
		})
		for d = 1, #Config.Zones do
			local unlocked = d <= def.maxDepth
			local selected = d == sub.depth
			local depthButton = button({
				Size = UDim2.new(0, 34, 0, 34),
				Text = unlocked and tostring(d) or "-",
				LayoutOrder = d,
				BackgroundColor3 = selected and THEME.accent or (unlocked and THEME.bg or Color3.fromRGB(30, 35, 45)),
				TextColor3 = selected and THEME.bg or (unlocked and THEME.text or THEME.muted),
				AutoButtonColor = unlocked,
				Parent = selector,
			})
			if unlocked and not selected then
				depthButton.MouseButton1Click:Connect(function()
					Action:FireServer("SetDepth", i, d)
				end)
			end
		end
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 52),
			Size = UDim2.new(0.5, 0, 0, 16),
			Text = string.format('Next dive: %s (%s)  <font color="#%s">%d%% breach</font>',
				zone.name, zone.depthText, riskColor(risk):ToHex(), math.floor(risk * 100 + 0.5)),
			RichText = true,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 14,
			Parent = row,
		})
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 70),
			Size = UDim2.new(0.5, 0, 0, 14),
			Text = string.format("+%d coins per haul", math.floor(zone.coins * (state.multiplier or 1))),
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 13,
			Parent = row,
		})
	end

	for i = #state.subs + 1, Config.MaxFleet do
		local row = card(44, i, THEME.muted)
		text({
			Size = UDim2.new(1, -28, 0, 20),
			Position = UDim2.new(0, 14, 0.5, -10),
			Text = "Empty berth - buy another sub in the Shop",
			Font = Enum.Font.GothamMedium,
			TextColor3 = THEME.muted,
			MaxTextSize = 16,
			Parent = row,
		})
	end
end

---------------------------------------------------------------------------
-- SHOP PANEL
---------------------------------------------------------------------------
local renderWeaponsRef, shopTabsRef, shopTabRef -- set further down

local function renderShop()
	panelTitle.Text = "SUB SHIPYARD"
	panelSubtitle.Text = string.format("Fleet %d/%d", #state.subs, Config.MaxFleet)
	listLayout()
	shopTabsRef()
	if shopTabRef() == "Weapons" then
		renderWeaponsRef()
		return
	end

	for i, def in ipairs(Config.Subs) do
		local row = card(84, i, def.trimColor)
		local badge = new("Frame", {
			Size = UDim2.new(0, 56, 0, 56),
			Position = UDim2.new(0, 14, 0.5, -28),
			BackgroundColor3 = def.bodyColor,
			Parent = row,
		})
		corner(badge, 28)
		stroke(badge, def.trimColor, 3, 0)
		text({
			Size = UDim2.fromScale(1, 1),
			Text = "T" .. i,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.4,
			Parent = badge,
		})
		text({
			Size = UDim2.new(1, -250, 0, 24),
			Position = UDim2.new(0, 82, 0, 12),
			Text = def.name,
			Font = Enum.Font.GothamBlack,
			Parent = row,
		})
		local zone = Config.Zones[def.maxDepth]
		text({
			Size = UDim2.new(1, -250, 0, 16),
			Position = UDim2.new(0, 82, 0, 40),
			Text = "Reaches: " .. zone.name .. " (" .. zone.depthText .. ")",
			Font = Enum.Font.GothamMedium,
			TextColor3 = THEME.accent,
			MaxTextSize = 15,
			Parent = row,
		})
		text({
			Size = UDim2.new(1, -250, 0, 14),
			Position = UDim2.new(0, 82, 0, 60),
			Text = string.format("Luck x%.2f  |  Hull +%d%%  |  Speed x%.2f", def.luck, math.floor(def.hull * 100 + 0.5), 1 / def.speed),
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.muted,
			MaxTextSize = 13,
			Parent = row,
		})

		local isPearls = def.currency == "Pearls"
		local wallet = isPearls and state.pearls or state.coins
		local full = #state.subs >= Config.MaxFleet
		local affordable = wallet >= def.price and not full
		local buy = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0, 150, 0, 46),
			Text = full and "FLEET FULL" or (Config.FormatNumber(def.price) .. (isPearls and " Pearls" or " Coins")),
			BackgroundColor3 = affordable and (isPearls and Color3.fromRGB(150, 120, 230) or Color3.fromRGB(40, 170, 90))
				or Color3.fromRGB(60, 65, 75),
			TextColor3 = affordable and THEME.text or THEME.muted,
			Parent = row,
		})
		buy.MouseButton1Click:Connect(function()
			Action:FireServer("BuySub", def.id)
		end)
	end
end

---------------------------------------------------------------------------
-- LOGBOOK PANEL (collection)
---------------------------------------------------------------------------
local function renderLogbook()
	panelTitle.Text = "SALVAGE LOGBOOK"
	local restored = 0
	for _ in pairs(state.ships) do
		restored += 1
	end
	panelSubtitle.Text = string.format("%d/%d ships  |  Coin bonus x%.2f", restored, #Config.Ships, state.multiplier or 1)
	listLayout()

	-- toolbar: spare fragments + auto-sell
	local spares = 0
	for _, owned in pairs(state.parts) do
		if owned > 1 then
			spares += owned - 1
		end
	end
	local toolbar = card(52, 0)
	text({
		Size = UDim2.new(0.4, 0, 0, 20),
		Position = UDim2.new(0, 14, 0.5, -10),
		Text = spares .. " spare fragments (tradeable)",
		Font = Enum.Font.GothamMedium,
		MaxTextSize = 15,
		Parent = toolbar,
	})
	local autoButton = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.5, 0),
		Size = UDim2.new(0, 170, 0, 36),
		Text = state.autoSell and "Auto-sell spares: ON" or "Auto-sell spares: OFF",
		BackgroundColor3 = state.autoSell and Color3.fromRGB(40, 170, 90) or Color3.fromRGB(70, 75, 90),
		MaxTextSize = 15,
		Parent = toolbar,
	})
	autoButton.MouseButton1Click:Connect(function()
		Action:FireServer("SetAutoSell", not state.autoSell)
	end)
	local sellButton = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 130, 0, 36),
		Text = "Sell spares",
		BackgroundColor3 = spares > 0 and Color3.fromRGB(200, 150, 40) or Color3.fromRGB(60, 65, 75),
		MaxTextSize = 15,
		Parent = toolbar,
	})
	sellButton.MouseButton1Click:Connect(function()
		if spares > 0 then
			Action:FireServer("SellSpares")
		end
	end)

	local grid = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content,
	})
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 196),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	for i, ship in ipairs(Config.Ships) do
		local rarity = Config.Rarities[ship.rarity]
		local owned = 0
		for _, partName in ipairs(ship.parts) do
			if (state.parts[Config.PartKey(ship.id, partName)] or 0) > 0 then
				owned += 1
			end
		end
		local isRestored = state.ships[ship.id] == true
		local hidden = rarity.secret and owned == 0

		local box = new("Frame", {
			BackgroundColor3 = THEME.card,
			LayoutOrder = i,
			Parent = grid,
		})
		corner(box, 10)
		stroke(box, rarity.color, isRestored and 3 or 1.5, isRestored and 0 or 0.5)

		text({
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.new(0, 10, 0, 8),
			Text = hidden and "??? (Secret)" or ship.name,
			Font = Enum.Font.GothamBlack,
			TextColor3 = rarity.color,
			Parent = box,
		})
		text({
			Size = UDim2.new(1, -20, 0, 14),
			Position = UDim2.new(0, 10, 0, 32),
			Text = string.format("%s  |  %d/%d fragments  |  +%d%% coins", rarity.name, owned, #ship.parts, math.floor(ship.bonus * 100 + 0.5)),
			Font = Enum.Font.GothamMedium,
			TextColor3 = THEME.muted,
			MaxTextSize = 13,
			Parent = box,
		})

		local bar = new("Frame", {
			Size = UDim2.new(1, -20, 0, 6),
			Position = UDim2.new(0, 10, 0, 52),
			BackgroundColor3 = THEME.bg,
			Parent = box,
		})
		corner(bar, 3)
		local fill = new("Frame", {
			Size = UDim2.fromScale(owned / #ship.parts, 1),
			BackgroundColor3 = rarity.color,
			Parent = bar,
		})
		corner(fill, 3)

		local partsList = new("Frame", {
			Size = UDim2.new(1, -20, 1, -96),
			Position = UDim2.new(0, 10, 0, 64),
			BackgroundTransparency = 1,
			Parent = box,
		})
		new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 18),
			CellPadding = UDim2.new(0, 4, 0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = partsList,
		})
		for p, partName in ipairs(ship.parts) do
			local count = state.parts[Config.PartKey(ship.id, partName)] or 0
			local has = count > 0
			text({
				Text = has and ("+ " .. partName .. (count > 1 and ("  x" .. count) or ""))
					or ("- " .. (hidden and "???" or partName)),
				Font = has and Enum.Font.GothamBold or Enum.Font.Gotham,
				TextColor3 = has and THEME.text or Color3.fromRGB(95, 115, 135),
				LayoutOrder = p,
				MaxTextSize = 13,
				Parent = partsList,
			})
		end

		local footer = text({
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 1, -28),
			Text = isRestored and "RESTORED - floating at your bay!" or "Find every fragment to restore it",
			Font = isRestored and Enum.Font.GothamBlack or Enum.Font.Gotham,
			TextColor3 = isRestored and THEME.good or THEME.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 14,
			Parent = box,
		})
		footer.Name = "Footer"
	end
end

---------------------------------------------------------------------------
-- PET MODELS (built from parts, used for followers + UI previews)
---------------------------------------------------------------------------
local Models = require(ReplicatedStorage:WaitForChild("SalvageModels"))
local buildPet = Models.Build

---------------------------------------------------------------------------
-- PET FOLLOWERS (everyone's equipped pets swim behind them)
---------------------------------------------------------------------------
local petFolder = new("Folder", { Name = "SalvagePets_" .. player.UserId, Parent = workspace })
local followers = {}
local SLOT_OFFSETS = { Vector3.new(-3.2, 0, 2.5), Vector3.new(3.2, 0, 2.5), Vector3.new(0, 0.9, 4.2) }

local function refreshFollowers(p)
	local key = p:GetAttribute("EquippedPets") or ""
	local entry = followers[p]
	if entry and entry.key == key then
		return
	end
	if entry then
		for _, model in ipairs(entry.models) do
			model:Destroy()
		end
	end
	entry = { key = key, models = {} }
	followers[p] = entry
	for petId in string.gmatch(key, "[^,]+") do
		local def = Config.GetPet(petId)
		if def then
			local model = buildPet(def, 0.9)
			model.Parent = petFolder
			table.insert(entry.models, model)
		end
	end
end

local function watchPlayer(p)
	refreshFollowers(p)
	p:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		refreshFollowers(p)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	local entry = followers[p]
	if entry then
		for _, model in ipairs(entry.models) do
			model:Destroy()
		end
		followers[p] = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local alpha = 1 - math.exp(-dt * 7)
	for p, entry in pairs(followers) do
		local character = p.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			for i, model in ipairs(entry.models) do
				local offset = SLOT_OFFSETS[i] or Vector3.new(0, 0, 3 + i)
				local bob = math.sin(t * 2.2 + i * 1.7) * 0.35
				local target = (hrp.CFrame * CFrame.new(offset.X, offset.Y + 0.4 + bob, offset.Z)).Position
				local current = model:GetPivot().Position
				local pos = target
				if model:GetAttribute("Placed") and (current - target).Magnitude < 60 then
					pos = current:Lerp(target, alpha)
				end
				model:SetAttribute("Placed", true)
				local look = hrp.CFrame.LookVector
				model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z)))
			end
		end
	end
end)

---------------------------------------------------------------------------
-- VIEWPORT PREVIEW (a little 3D window showing a pet)
---------------------------------------------------------------------------
local spinningViewports = {}

local function petViewport(parent, def, size, position, spin)
	local viewport = new("ViewportFrame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 175, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, 1),
		Parent = parent,
	})
	local model = buildPet(def, 1)
	model.Parent = viewport
	local camera = new("Camera", { FieldOfView = 40, Parent = viewport })
	local extents = model:GetExtentsSize().Magnitude
	camera.CFrame = CFrame.lookAt(Vector3.new(extents * 0.8, extents * 0.45, -extents * 1.2), Vector3.new(0, 0, 0))
	viewport.CurrentCamera = camera
	model:PivotTo(CFrame.Angles(0, math.rad(-20), 0))
	if spin then
		table.insert(spinningViewports, model)
	end
	return viewport
end

RunService.RenderStepped:Connect(function()
	for i = #spinningViewports, 1, -1 do
		local model = spinningViewports[i]
		if model.Parent then
			model:PivotTo(CFrame.Angles(0, os.clock() * 1.2, 0))
		else
			table.remove(spinningViewports, i)
		end
	end
end)

local function eggDrawing(parent, eggDef, size, position)
	local egg = new("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = eggDef.color,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = egg })
	stroke(egg, Color3.new(1, 1, 1), 2, 0.6)
	gradient(egg, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 185))
	for _, spot in ipairs({ { 0.3, 0.3, 0.2 }, { 0.65, 0.45, 0.16 }, { 0.4, 0.68, 0.14 } }) do
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot[1], spot[2]),
			Size = UDim2.fromScale(spot[3], spot[3] * 0.8),
			BackgroundColor3 = eggDef.spots,
			Parent = egg,
		})
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
	end
	return egg
end

---------------------------------------------------------------------------
-- HATCH REVEAL
---------------------------------------------------------------------------
local hatchOverlay = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.3,
	Visible = false,
	ZIndex = 50,
	Parent = gui,
})
local hatchStage = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.new(0, 320, 0, 420),
	BackgroundTransparency = 1,
	Parent = hatchOverlay,
})
local hatchFlash = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = hatchOverlay,
})
local hatchQueue = {}
local hatching = false

local function playHatch(eggId, petId)
	local eggDef, def = Config.GetEgg(eggId), Config.GetPet(petId)
	if not eggDef or not def then
		return
	end
	hatching = true
	for _, child in ipairs(hatchStage:GetChildren()) do
		child:Destroy()
	end
	hatchOverlay.Visible = true

	local egg = eggDrawing(hatchStage, eggDef, UDim2.new(0, 170, 0, 215), UDim2.fromScale(0.5, 0.4))
	for i = 1, 8 do
		local angle = (i % 2 == 0 and 1 or -1) * (6 + i * 2)
		local tween = TweenService:Create(egg, TweenInfo.new(0.22 - i * 0.015), { Rotation = angle })
		tween:Play()
		tween.Completed:Wait()
	end
	hatchFlash.BackgroundTransparency = 0
	egg:Destroy()
	TweenService:Create(hatchFlash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()

	local rarity = Config.PetRarities[def.rarity]
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(0, 280, 0, 280),
		BackgroundColor3 = rarity.color,
		BackgroundTransparency = 0.75,
		Parent = hatchStage,
	})
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = glow })
	petViewport(hatchStage, def, UDim2.new(0, 280, 0, 280), UDim2.new(0.5, -140, 0.36, -140), true)
	text({
		Position = UDim2.new(0, 0, 0, 290),
		Size = UDim2.new(1, 0, 0, 34),
		Text = def.name,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 32,
		Parent = hatchStage,
	})
	text({
		Position = UDim2.new(0, 0, 0, 326),
		Size = UDim2.new(1, 0, 0, 22),
		Text = rarity.name:upper(),
		TextColor3 = rarity.color,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = hatchStage,
	})
	text({
		Position = UDim2.new(0, 0, 0, 350),
		Size = UDim2.new(1, 0, 0, 18),
		Text = Config.DescribeBonus(def.bonus),
		TextColor3 = THEME.gold,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 16,
		Parent = hatchStage,
	})
	local continueButton = button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 378),
		Size = UDim2.new(0, 160, 0, 40),
		Text = "AWESOME!",
		BackgroundColor3 = rarity.color,
		TextColor3 = THEME.bg,
		Parent = hatchStage,
	})
	continueButton.MouseButton1Click:Wait()
	hatchOverlay.Visible = false
	hatching = false
	local nextHatch = table.remove(hatchQueue, 1)
	if nextHatch then
		task.spawn(playHatch, nextHatch[1], nextHatch[2])
	end
end

---------------------------------------------------------------------------
-- PETS PANEL
---------------------------------------------------------------------------
local releaseArmed = {}

local function sectionTitle(label, order)
	return text({
		Size = UDim2.new(1, 0, 0, 24),
		Text = label,
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.accent,
		LayoutOrder = order,
		MaxTextSize = 18,
		Parent = content,
	})
end

local function gridSection(order, cellSize)
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = content,
	})
	new("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	return holder
end

local renderPanelRef -- set further down
local pct -- set further down

---------------------------------------------------------------------------
-- CHARMS TAB (inside the PETS panel)
---------------------------------------------------------------------------
local petsTab = "Pets"
local petFilter = "All"
local charmArmed = {}

local function gem(parent, color, size, position, faded)
	local g = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.new(0, size, 0, size),
		Rotation = 45,
		BackgroundColor3 = faded and Color3.fromRGB(55, 65, 80) or color,
		Parent = parent,
	})
	corner(g, math.floor(size / 6))
	stroke(g, faded and THEME.muted or Color3.new(1, 1, 1), 2, faded and 0.6 or 0.3)
	gradient(g, Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 165))
	local shine = new("Frame", {
		Position = UDim2.fromScale(0.18, 0.18),
		Size = UDim2.fromScale(0.28, 0.28),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = faded and 0.85 or 0.35,
		Parent = g,
	})
	corner(shine, 4)
	return g
end

local function petsTabs()
	local owned = 0
	for _, count in pairs(state.charms) do
		owned += count
	end
	local tabs = card(48, 0)
	for i, name in ipairs({ "Pets", "Charms" }) do
		local selected = petsTab == name
		local tab = button({
			Position = UDim2.new((i - 1) * 0.5, 8, 0, 7),
			Size = UDim2.new(0.5, -12, 0, 34),
			Text = name == "Charms" and ("CHARMS (" .. owned .. ")") or ("PETS (" .. #state.pets .. ")"),
			BackgroundColor3 = selected and Color3.fromRGB(255, 130, 200) or THEME.bg,
			TextColor3 = selected and THEME.bg or THEME.text,
			Parent = tabs,
		})
		tab.MouseButton1Click:Connect(function()
			petsTab = name
			renderPanelRef()
		end)
	end
end

local function nonZero(totals)
	local out = {}
	for stat, value in pairs(totals) do
		if value > 0 then
			out[stat] = value
		end
	end
	return out
end

local function renderCharms()
	panelTitle.Text = "SEASON CHARMS"
	panelSubtitle.Text = string.format("Equipped %d/%d", #state.equippedCharms, state.charmSlots)

	local summary = card(64, 1, THEME.accent)
	local bonusText = Config.DescribeBonus(nonZero(Config.CharmBonusTotals(state.equippedCharms)))
	text({
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "Charm bonus: " .. (bonusText ~= "" and bonusText or "none - equip a charm!"),
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.accent,
		MaxTextSize = 16,
		Parent = summary,
	})
	text({
		Position = UDim2.new(0, 14, 0, 34),
		Size = UDim2.new(1, -28, 0, 20),
		Text = string.format("Found in %ss floating in the sea (%d%%), hauls (%d%%) and creatures (%d%%). Only this season!",
			Config.Drifters.name, pct(Config.Drifters.charmChance), pct(Config.CharmChanceHaul), pct(Config.CharmChanceKill)),
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.muted,
		TextWrapped = true,
		MaxTextSize = 13,
		Parent = summary,
	})

	sectionTitle(Config.Season.name:upper() .. " CHARMS", 2)
	local grid = gridSection(3, UDim2.new(0, 150, 0, 206))
	for i, charm in ipairs(Config.Charms) do
		local owned = state.charms[charm.id] or 0
		local thisSeason = charm.season == Config.Season.id
		if owned > 0 or thisSeason then
			local rarity = Config.PetRarities[charm.rarity]
			local equipped = table.find(state.equippedCharms, charm.id) ~= nil
			local box = new("Frame", { BackgroundColor3 = THEME.card, LayoutOrder = i, Parent = grid })
			corner(box, 10)
			stroke(box, rarity.color, equipped and 3 or 1.5, equipped and 0 or (owned > 0 and 0.4 or 0.8))
			gem(box, charm.color, 44, UDim2.new(0.5, 0, 0, 40), owned == 0)
			if owned > 1 then
				text({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 6),
					Size = UDim2.new(0, 40, 0, 18),
					Text = "x" .. owned,
					Font = Enum.Font.GothamBlack,
					TextXAlignment = Enum.TextXAlignment.Right,
					MaxTextSize = 15,
					Parent = box,
				})
			end
			text({
				Position = UDim2.new(0, 6, 0, 76),
				Size = UDim2.new(1, -12, 0, 18),
				Text = owned > 0 and charm.name or "???",
				Font = Enum.Font.GothamBlack,
				TextColor3 = owned > 0 and rarity.color or THEME.muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				MaxTextSize = 15,
				Parent = box,
			})
			text({
				Position = UDim2.new(0, 6, 0, 96),
				Size = UDim2.new(1, -12, 0, 14),
				Text = rarity.name:upper() .. (thisSeason and "" or "  |  OLD SEASON"),
				Font = Enum.Font.GothamBold,
				TextColor3 = rarity.color,
				TextXAlignment = Enum.TextXAlignment.Center,
				MaxTextSize = 11,
				Parent = box,
			})
			text({
				Position = UDim2.new(0, 6, 0, 112),
				Size = UDim2.new(1, -12, 0, 26),
				Text = Config.DescribeBonus(charm.bonus),
				Font = Enum.Font.Gotham,
				TextColor3 = owned > 0 and THEME.gold or THEME.muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = true,
				MaxTextSize = 12,
				Parent = box,
			})
			if owned > 0 then
				local equipButton = button({
					Position = UDim2.new(0, 8, 0, 142),
					Size = UDim2.new(1, -16, 0, 28),
					Text = equipped and "UNEQUIP" or "EQUIP",
					BackgroundColor3 = equipped and Color3.fromRGB(70, 75, 90) or Color3.fromRGB(40, 170, 90),
					MaxTextSize = 14,
					Parent = box,
				})
				equipButton.MouseButton1Click:Connect(function()
					Action:FireServer("EquipCharm", charm.id)
				end)
				local spare = owned - (equipped and 1 or 0)
				local xp = Config.CharmDissolveXp[charm.rarity]
				local dissolve = button({
					Position = UDim2.new(0, 8, 0, 174),
					Size = UDim2.new(1, -16, 0, 24),
					Text = spare > 0 and ("Dissolve +" .. xp .. " season XP") or "No spare to dissolve",
					BackgroundColor3 = Color3.fromRGB(45, 50, 65),
					TextColor3 = spare > 0 and THEME.muted or Color3.fromRGB(90, 100, 115),
					MaxTextSize = 11,
					Parent = box,
				})
				if spare > 0 then
					dissolve.MouseButton1Click:Connect(function()
						if charmArmed[charm.id] then
							charmArmed[charm.id] = nil
							Action:FireServer("DissolveCharm", charm.id)
						else
							charmArmed[charm.id] = true
							dissolve.Text = "TAP AGAIN TO DISSOLVE"
							dissolve.BackgroundColor3 = THEME.danger
							dissolve.TextColor3 = THEME.text
							task.delay(3, function()
								charmArmed[charm.id] = nil
							end)
						end
					end)
				end
			else
				text({
					Position = UDim2.new(0, 6, 0, 150),
					Size = UDim2.new(1, -12, 0, 40),
					Text = "Not found yet. Keep searching the sea!",
					Font = Enum.Font.Gotham,
					TextColor3 = THEME.muted,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = true,
					MaxTextSize = 12,
					Parent = box,
				})
			end
		end
	end
end

local function renderPets()
	listLayout()
	petsTabs()
	if petsTab == "Charms" then
		renderCharms()
		return
	end
	panelTitle.Text = "PET TANK"
	panelSubtitle.Text = string.format("Pets %d/%d  |  Equipped %d/%d", #state.pets, Config.MaxPets, #state.equipped, state.maxEquipped)

	-- bonus summary
	local summary = card(52, 1, THEME.gold)
	local bonusText = Config.DescribeBonus({
		coins = state.petBonus.coins > 0 and state.petBonus.coins or nil,
		luck = state.petBonus.luck > 0 and state.petBonus.luck or nil,
		hull = state.petBonus.hull > 0 and state.petBonus.hull or nil,
		xp = state.petBonus.xp > 0 and state.petBonus.xp or nil,
	})
	text({
		Size = UDim2.new(1, -180, 0, 20),
		Position = UDim2.new(0, 14, 0.5, -10),
		Text = "Pet bonus: " .. (bonusText ~= "" and bonusText or "none yet - equip some pets!"),
		Font = Enum.Font.GothamMedium,
		TextColor3 = THEME.gold,
		MaxTextSize = 15,
		Parent = summary,
	})
	local best = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 150, 0, 36),
		Text = "EQUIP BEST",
		BackgroundColor3 = Color3.fromRGB(40, 170, 90),
		MaxTextSize = 16,
		Parent = summary,
	})
	best.MouseButton1Click:Connect(function()
		Action:FireServer("EquipBest")
	end)

	-- eggs
	sectionTitle("EGGS", 2)
	local hasEggs = false
	local eggGrid = gridSection(3, UDim2.new(0, 150, 0, 196))
	for i, eggDef in ipairs(Config.Eggs) do
		local count = state.eggs[eggDef.id] or 0
		if count > 0 then
			hasEggs = true
			local box = new("Frame", { BackgroundColor3 = THEME.card, LayoutOrder = i, Parent = eggGrid })
			corner(box, 10)
			stroke(box, eggDef.spots, 1.5, 0.4)
			eggDrawing(box, eggDef, UDim2.new(0, 64, 0, 80), UDim2.new(0.5, 0, 0, 52))
			text({
				Position = UDim2.new(0, 6, 0, 98),
				Size = UDim2.new(1, -12, 0, 18),
				Text = eggDef.name .. "  x" .. count,
				TextXAlignment = Enum.TextXAlignment.Center,
				MaxTextSize = 15,
				Parent = box,
			})
			local isPearls = eggDef.currency == "Pearls"
			local canAfford = (isPearls and state.pearls or state.coins) >= eggDef.cost
			local hatch = button({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 124),
				Size = UDim2.new(1, -16, 0, 34),
				Text = "HATCH",
				BackgroundColor3 = canAfford and Color3.fromRGB(40, 170, 90) or Color3.fromRGB(60, 65, 75),
				TextColor3 = canAfford and THEME.text or THEME.muted,
				MaxTextSize = 16,
				Parent = box,
			})
			text({
				Position = UDim2.new(0, 6, 0, 164),
				Size = UDim2.new(1, -12, 0, 16),
				Text = Config.FormatNumber(eggDef.cost) .. (isPearls and " Pearls" or " Coins"),
				TextColor3 = isPearls and THEME.pearl or THEME.gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				MaxTextSize = 14,
				Parent = box,
			})
			hatch.MouseButton1Click:Connect(function()
				Action:FireServer("HatchEgg", eggDef.id)
			end)
		end
	end
	if not hasEggs then
		eggGrid:Destroy()
		text({
			Size = UDim2.new(1, 0, 0, 20),
			Text = "No eggs yet. Every haul has a " .. math.floor(Config.EggChance * 100 + 0.5) .. "% chance to bring one up!",
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.muted,
			LayoutOrder = 3,
			MaxTextSize = 15,
			Parent = content,
		})
	end

	-- pets
	sectionTitle("PETS", 4)
	if #state.pets == 0 then
		text({
			Size = UDim2.new(1, 0, 0, 20),
			Text = "No pets yet. Hatch an egg to get one!",
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.muted,
			LayoutOrder = 5,
			MaxTextSize = 15,
			Parent = content,
		})
		return
	end
	-- filter chips: ALL, EQUIPPED, then each rarity you own (with counts)
	local counts = {}
	for _, pet in ipairs(state.pets) do
		local def = Config.GetPet(pet.id)
		if def then
			counts[def.rarity] = (counts[def.rarity] or 0) + 1
		end
	end
	local chips = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = content,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = chips })
	local filters = { { key = "All", label = "ALL " .. #state.pets, color = THEME.accent },
		{ key = "Equipped", label = "EQUIPPED " .. #state.equipped, color = THEME.good } }
	for r, rarity in ipairs(Config.PetRarities) do
		if counts[r] then
			table.insert(filters, { key = r, label = rarity.name:upper() .. " " .. counts[r], color = rarity.color })
		end
	end
	for i, f in ipairs(filters) do
		local selected = petFilter == f.key
		local chip = button({
			Size = UDim2.new(0, 96, 1, 0),
			Text = f.label,
			LayoutOrder = i,
			BackgroundColor3 = selected and f.color or THEME.bg,
			TextColor3 = selected and THEME.bg or f.color,
			MaxTextSize = 12,
			Parent = chips,
		})
		chip.MouseButton1Click:Connect(function()
			petFilter = f.key
			renderPanelRef()
		end)
	end

	local petGrid = gridSection(6, UDim2.new(0, 150, 0, 214))
	local sorted = {}
	for _, pet in ipairs(state.pets) do
		local def = Config.GetPet(pet.id)
		local equipped = table.find(state.equipped, pet.uid) ~= nil
		if def and (petFilter == "All" or (petFilter == "Equipped" and equipped) or petFilter == def.rarity) then
			table.insert(sorted, pet)
		end
	end
	table.sort(sorted, function(a, b)
		local ea, eb = table.find(state.equipped, a.uid) ~= nil, table.find(state.equipped, b.uid) ~= nil
		if ea ~= eb then
			return ea
		end
		return Config.PetScore(a.id) > Config.PetScore(b.id)
	end)
	for i, pet in ipairs(sorted) do
		local def = Config.GetPet(pet.id)
		if def then
			local rarity = Config.PetRarities[def.rarity]
			local equipped = table.find(state.equipped, pet.uid) ~= nil
			local box = new("Frame", { BackgroundColor3 = THEME.card, LayoutOrder = i, Parent = petGrid })
			corner(box, 10)
			stroke(box, rarity.color, equipped and 3 or 1.5, equipped and 0 or 0.5)
			petViewport(box, def, UDim2.new(1, 0, 0, 96), UDim2.new(0, 0, 0, 0), false)
			text({
				Position = UDim2.new(0, 6, 0, 96),
				Size = UDim2.new(1, -12, 0, 18),
				Text = def.name,
				Font = Enum.Font.GothamBlack,
				TextColor3 = rarity.color,
				TextXAlignment = Enum.TextXAlignment.Center,
				MaxTextSize = 15,
				Parent = box,
			})
			text({
				Position = UDim2.new(0, 6, 0, 116),
				Size = UDim2.new(1, -12, 0, 26),
				Text = Config.DescribeBonus(def.bonus),
				Font = Enum.Font.Gotham,
				TextColor3 = THEME.gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = true,
				MaxTextSize = 12,
				Parent = box,
			})
			local equipButton = button({
				Position = UDim2.new(0, 8, 0, 146),
				Size = UDim2.new(1, -16, 0, 28),
				Text = equipped and "UNEQUIP" or "EQUIP",
				BackgroundColor3 = equipped and Color3.fromRGB(70, 75, 90) or Color3.fromRGB(40, 170, 90),
				MaxTextSize = 14,
				Parent = box,
			})
			equipButton.MouseButton1Click:Connect(function()
				Action:FireServer("EquipPet", pet.uid)
			end)
			local releaseButton = button({
				Position = UDim2.new(0, 8, 0, 178),
				Size = UDim2.new(1, -16, 0, 26),
				Text = releaseArmed[pet.uid] and "TAP AGAIN TO RELEASE"
					or ("Release +" .. Config.FormatNumber(rarity.releaseValue)),
				BackgroundColor3 = releaseArmed[pet.uid] and THEME.danger or Color3.fromRGB(45, 50, 65),
				TextColor3 = releaseArmed[pet.uid] and THEME.text or THEME.muted,
				MaxTextSize = 12,
				Parent = box,
			})
			releaseButton.MouseButton1Click:Connect(function()
				if releaseArmed[pet.uid] then
					releaseArmed[pet.uid] = nil
					Action:FireServer("ReleasePet", pet.uid)
				else
					releaseArmed[pet.uid] = true
					releaseButton.Text = "TAP AGAIN TO RELEASE"
					releaseButton.BackgroundColor3 = THEME.danger
					releaseButton.TextColor3 = THEME.text
					task.delay(3, function()
						releaseArmed[pet.uid] = nil
					end)
				end
			end)
		end
	end
end

---------------------------------------------------------------------------
-- TRADE PANEL
---------------------------------------------------------------------------
local trade = nil -- latest trade snapshot from the server, nil when not trading

local function itemInfo(item)
	if item.kind == "part" then
		local shipId, partName = Config.SplitPartKey(item.id)
		local ship = Config.GetShip(shipId)
		if ship then
			return ship.name .. ": " .. partName, Config.Rarities[ship.rarity].color
		end
	elseif item.kind == "egg" then
		local egg = Config.GetEgg(item.id)
		if egg then
			return egg.name, egg.spots
		end
	elseif item.kind == "pet" then
		local def = Config.GetPet(item.petId)
		if def then
			return def.name .. " (" .. Config.PetRarities[def.rarity].name .. ")", Config.PetRarities[def.rarity].color
		end
	end
	return "Unknown item", THEME.muted
end

local function itemChip(parent, item, order, onClick)
	local label, color = itemInfo(item)
	local chip = button({
		Size = UDim2.new(1, -8, 0, 30),
		Text = label .. ((item.amount or 1) > 1 and ("  x" .. item.amount) or ""),
		TextColor3 = color,
		BackgroundColor3 = THEME.bg,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		MaxTextSize = 14,
		Parent = parent,
	})
	stroke(chip, color, 1, 0.5)
	if onClick then
		chip.MouseButton1Click:Connect(onClick)
	else
		chip.AutoButtonColor = false
	end
	return chip
end

local function offerBox(parent, title, items, ready, position, mine)
	local box = new("Frame", {
		Size = UDim2.new(0.5, -4, 1, 0),
		Position = position,
		BackgroundColor3 = THEME.card,
		Parent = parent,
	})
	corner(box, 10)
	stroke(box, ready and THEME.good or THEME.accent, ready and 3 or 1.5, ready and 0 or 0.5)
	text({
		Position = UDim2.new(0, 10, 0, 6),
		Size = UDim2.new(1, -20, 0, 20),
		Text = title .. (ready and "  - READY" or ""),
		Font = Enum.Font.GothamBlack,
		TextColor3 = ready and THEME.good or THEME.text,
		MaxTextSize = 15,
		Parent = box,
	})
	local list = new("ScrollingFrame", {
		Position = UDim2.new(0, 8, 0, 30),
		Size = UDim2.new(1, -12, 1, -36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = box,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	if #items == 0 then
		text({
			Size = UDim2.new(1, 0, 0, 18),
			Text = mine and "Tap your items below to add them" or "Nothing yet...",
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.muted,
			MaxTextSize = 13,
			Parent = list,
		})
	end
	for i, item in ipairs(items) do
		itemChip(list, item, i, mine and function()
			Action:FireServer("TradeRemove", item.kind, item.id)
		end or nil)
	end
end

local function renderTrade()
	panelTitle.Text = "TRADING"
	listLayout()

	if (state.bestLevel or 1) < Config.TradeUnlockLevel then
		panelSubtitle.Text = "Locked"
		local lock = card(110, 1, THEME.muted)
		text({
			Position = UDim2.new(0, 16, 0, 18),
			Size = UDim2.new(1, -32, 0, 30),
			Text = "Trading unlocks at Level " .. Config.TradeUnlockLevel,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 24,
			Parent = lock,
		})
		text({
			Position = UDim2.new(0, 16, 0, 58),
			Size = UDim2.new(1, -32, 0, 20),
			Text = "You're Level " .. state.level .. ". Every haul gives XP, and deeper zones give more.",
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 15,
			Parent = lock,
		})
		return
	end

	if not trade then
		panelSubtitle.Text = "Pick someone to trade with"
		local others = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				others += 1
				local level = p:GetAttribute("Level") or 1
				local unlocked = level >= Config.TradeUnlockLevel
				local row = card(56, others)
				text({
					Position = UDim2.new(0, 14, 0, 8),
					Size = UDim2.new(0.6, 0, 0, 22),
					Text = p.DisplayName,
					Font = Enum.Font.GothamBlack,
					Parent = row,
				})
				text({
					Position = UDim2.new(0, 14, 0, 32),
					Size = UDim2.new(0.6, 0, 0, 16),
					Text = "Level " .. level .. (unlocked and "" or "  (can't trade yet)"),
					Font = Enum.Font.Gotham,
					TextColor3 = unlocked and THEME.accent or THEME.muted,
					MaxTextSize = 14,
					Parent = row,
				})
				local request = button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0, 150, 0, 38),
					Text = "REQUEST TRADE",
					BackgroundColor3 = unlocked and Color3.fromRGB(230, 140, 40) or Color3.fromRGB(60, 65, 75),
					TextColor3 = unlocked and THEME.text or THEME.muted,
					MaxTextSize = 15,
					Parent = row,
				})
				request.MouseButton1Click:Connect(function()
					if unlocked then
						Action:FireServer("TradeRequest", p.UserId)
					end
				end)
			end
		end
		if others == 0 then
			text({
				Size = UDim2.new(1, 0, 0, 20),
				Text = "No one else is in this server right now.",
				Font = Enum.Font.Gotham,
				TextColor3 = THEME.muted,
				MaxTextSize = 15,
				Parent = content,
			})
		end
		return
	end

	-- active trade
	local bothReady = trade.myReady and trade.theirReady
	panelSubtitle.Text = "Trading with " .. trade.partner
	local offers = new("Frame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content,
	})
	offerBox(offers, "YOUR OFFER", trade.mine, trade.myReady, UDim2.new(0, 0, 0, 0), true)
	offerBox(offers, trade.partner:upper() .. "'S OFFER", trade.theirs, trade.theirReady, UDim2.new(0.5, 4, 0, 0), false)

	local controls = card(56, 2, THEME.gold)
	local statusText
	if bothReady then
		if trade.myConfirm then
			statusText = "Waiting for " .. trade.partner .. " to confirm..."
		else
			statusText = "Both ready! Check the offers, then CONFIRM."
		end
	elseif trade.myReady then
		statusText = "Waiting for " .. trade.partner .. " to be ready..."
	else
		statusText = "Add items, then press READY. Any change un-readies both of you."
	end
	text({
		Position = UDim2.new(0, 12, 0.5, -9),
		Size = UDim2.new(1, -370, 0, 18),
		Text = statusText,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		MaxTextSize = 13,
		Parent = controls,
	})
	local readyButton = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -238, 0.5, 0),
		Size = UDim2.new(0, 110, 0, 38),
		Text = trade.myReady and "UNREADY" or "READY",
		BackgroundColor3 = trade.myReady and Color3.fromRGB(70, 75, 90) or Color3.fromRGB(40, 140, 200),
		MaxTextSize = 15,
		Parent = controls,
	})
	readyButton.MouseButton1Click:Connect(function()
		Action:FireServer("TradeReady")
	end)
	local confirmButton = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -122, 0.5, 0),
		Size = UDim2.new(0, 110, 0, 38),
		Text = trade.myConfirm and "CONFIRMED" or "CONFIRM",
		BackgroundColor3 = (bothReady and not trade.myConfirm) and Color3.fromRGB(40, 170, 90) or Color3.fromRGB(60, 65, 75),
		TextColor3 = bothReady and THEME.text or THEME.muted,
		MaxTextSize = 15,
		Parent = controls,
	})
	confirmButton.MouseButton1Click:Connect(function()
		if bothReady then
			Action:FireServer("TradeConfirm")
		end
	end)
	local cancelButton = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 104, 0, 38),
		Text = "CANCEL",
		BackgroundColor3 = THEME.danger,
		MaxTextSize = 15,
		Parent = controls,
	})
	cancelButton.MouseButton1Click:Connect(function()
		Action:FireServer("TradeCancel")
	end)

	-- your tradeable inventory (what's left after your current offer)
	sectionTitle("YOUR TRADEABLE ITEMS (tap to add)", 3)
	local offered = {}
	for _, item in ipairs(trade.mine) do
		offered[item.kind .. ":" .. tostring(item.id)] = item.amount or 1
	end
	local inventory = {}
	for key, owned in pairs(state.parts) do
		local spare = owned - 1 - (offered["part:" .. key] or 0)
		if spare > 0 then
			table.insert(inventory, { kind = "part", id = key, amount = spare })
		end
	end
	for _, pet in ipairs(state.pets) do
		if not table.find(state.equipped, pet.uid) and not offered["pet:" .. tostring(pet.uid)] then
			table.insert(inventory, { kind = "pet", id = pet.uid, petId = pet.id, amount = 1 })
		end
	end
	for eggId, count in pairs(state.eggs) do
		local left = count - (offered["egg:" .. eggId] or 0)
		if left > 0 then
			table.insert(inventory, { kind = "egg", id = eggId, amount = left })
		end
	end
	table.sort(inventory, function(a, b)
		local la = itemInfo(a)
		local lb = itemInfo(b)
		if a.kind ~= b.kind then
			return a.kind < b.kind
		end
		return la < lb
	end)
	if #inventory == 0 then
		text({
			Size = UDim2.new(1, 0, 0, 34),
			Text = "Nothing to trade. Spare fragments, unequipped pets and eggs show up here. (Tip: turn off Auto-sell in the Logbook to keep spares.)",
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.muted,
			TextWrapped = true,
			LayoutOrder = 4,
			MaxTextSize = 14,
			Parent = content,
		})
	else
		local inventoryGrid = gridSection(4, UDim2.new(0.5, -6, 0, 30))
		for i, item in ipairs(inventory) do
			itemChip(inventoryGrid, item, i, function()
				Action:FireServer("TradeAdd", item.kind, item.id)
			end)
		end
	end
end

---------------------------------------------------------------------------
-- TRADE REQUEST POP-UP
---------------------------------------------------------------------------
local requestPopup = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 132),
	Size = UDim2.new(0, 360, 0, 96),
	BackgroundColor3 = THEME.bg,
	Visible = false,
	ZIndex = 40,
	Parent = gui,
})
corner(requestPopup, 12)
stroke(requestPopup, Color3.fromRGB(230, 140, 40), 2.5, 0)
local requestLabel = text({
	Position = UDim2.new(0, 12, 0, 10),
	Size = UDim2.new(1, -24, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Center,
	Font = Enum.Font.GothamBlack,
	MaxTextSize = 18,
	Parent = requestPopup,
})
local acceptButton = button({
	Position = UDim2.new(0, 16, 0, 46),
	Size = UDim2.new(0.5, -24, 0, 38),
	Text = "ACCEPT",
	BackgroundColor3 = Color3.fromRGB(40, 170, 90),
	Parent = requestPopup,
})
local declineButton = button({
	Position = UDim2.new(0.5, 8, 0, 46),
	Size = UDim2.new(0.5, -24, 0, 38),
	Text = "DECLINE",
	BackgroundColor3 = THEME.danger,
	Parent = requestPopup,
})
local pendingRequestFrom = nil
acceptButton.MouseButton1Click:Connect(function()
	if pendingRequestFrom then
		Action:FireServer("TradeRespond", pendingRequestFrom, true)
	end
	pendingRequestFrom = nil
	requestPopup.Visible = false
end)
declineButton.MouseButton1Click:Connect(function()
	if pendingRequestFrom then
		Action:FireServer("TradeRespond", pendingRequestFrom, false)
	end
	pendingRequestFrom = nil
	requestPopup.Visible = false
end)

---------------------------------------------------------------------------
-- SHARED BITS FOR THE NEW PANELS
---------------------------------------------------------------------------
local stateReceivedAt = os.clock()

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 86400 then
		return string.format("%dd %dh", seconds // 86400, (seconds % 86400) // 3600)
	elseif seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function secondsLeft(value)
	return (value or 0) - (os.clock() - stateReceivedAt)
end

-- 0.15 -> 15 (rounded, so 0.45 never shows as 44)
pct = function(fraction)
	return math.floor(fraction * 100 + 0.5)
end

local function bar(parent, position, size, fraction, color)
	local back = new("Frame", { Position = position, Size = size, BackgroundColor3 = THEME.bg, Parent = parent })
	corner(back, 4)
	local fill = new("Frame", { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color, Parent = back })
	corner(fill, 4)
	return back
end

local armedButtons = {}
-- A button that needs two taps (for things that can't be undone)
local function confirmButton(btn, label, onConfirm)
	btn.MouseButton1Click:Connect(function()
		if armedButtons[label] then
			armedButtons[label] = nil
			onConfirm()
		else
			armedButtons[label] = true
			btn.Text = "TAP AGAIN TO CONFIRM"
			task.delay(3, function()
				armedButtons[label] = nil
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- SHOP: WEAPONS TAB
---------------------------------------------------------------------------
local shopTab = "Subs"

local function shopTabs()
	local tabs = card(48, 0)
	for i, name in ipairs({ "Subs", "Weapons" }) do
		local selected = shopTab == name
		local tab = button({
			Position = UDim2.new((i - 1) * 0.5, 8, 0, 7),
			Size = UDim2.new(0.5, -12, 0, 34),
			Text = name:upper(),
			BackgroundColor3 = selected and THEME.accent or THEME.bg,
			TextColor3 = selected and THEME.bg or THEME.text,
			Parent = tabs,
		})
		tab.MouseButton1Click:Connect(function()
			shopTab = name
			renderPanelRef()
		end)
	end
end

shopTabsRef = function()
	shopTabs()
end
shopTabRef = function()
	return shopTab
end

local function renderWeapons()
	panelTitle.Text = "WEAPONS"
	panelSubtitle.Text = string.format("Damage bonus x%.2f from rebirths", state.multipliers.damage)
	for i, weapon in ipairs(Config.Weapons) do
		local owned = table.find(state.weapons, weapon.id) ~= nil
		local equipped = state.weapon == weapon.id
		if owned or not weapon.seasonOnly then
			local row = card(74, i, weapon.tip)
			local swatch = new("Frame", {
				Size = UDim2.new(0, 46, 0, 46),
				Position = UDim2.new(0, 14, 0.5, -23),
				BackgroundColor3 = weapon.color,
				Parent = row,
			})
			corner(swatch, 10)
			stroke(swatch, weapon.tip, 3, 0)
			text({
				Size = UDim2.new(1, -250, 0, 22),
				Position = UDim2.new(0, 74, 0, 12),
				Text = weapon.name .. (weapon.seasonOnly and "  (Season)" or ""),
				Font = Enum.Font.GothamBlack,
				Parent = row,
			})
			text({
				Size = UDim2.new(1, -250, 0, 16),
				Position = UDim2.new(0, 74, 0, 40),
				Text = string.format("%s damage  |  %d stud reach  |  %.2fs per hit",
					Config.FormatNumber(weapon.damage), weapon.range, weapon.cooldown),
				Font = Enum.Font.GothamMedium,
				TextColor3 = THEME.muted,
				MaxTextSize = 14,
				Parent = row,
			})
			local label, color
			if equipped then
				label, color = "EQUIPPED", Color3.fromRGB(60, 65, 75)
			elseif owned then
				label, color = "EQUIP", Color3.fromRGB(40, 140, 200)
			else
				local isPearls = weapon.currency == "Pearls"
				local affordable = (isPearls and state.pearls or state.coins) >= weapon.price
				label = Config.FormatNumber(weapon.price) .. (isPearls and " Pearls" or " Coins")
				color = affordable and (isPearls and Color3.fromRGB(150, 120, 230) or Color3.fromRGB(40, 170, 90)) or Color3.fromRGB(60, 65, 75)
			end
			local b = button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.new(0, 150, 0, 42),
				Text = label,
				BackgroundColor3 = color,
				Parent = row,
			})
			b.MouseButton1Click:Connect(function()
				if owned and not equipped then
					Action:FireServer("EquipWeapon", weapon.id)
				elseif not owned then
					Action:FireServer("BuyWeapon", weapon.id)
				end
			end)
		end
	end
	local tip = card(46, 99, THEME.muted)
	text({
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.new(0, 12, 0.5, -15),
		Text = "Take a portal on the island to a hunting ground, hold your weapon and click (or tap) to attack.",
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.muted,
		TextWrapped = true,
		MaxTextSize = 13,
		Parent = tip,
	})
end

renderWeaponsRef = renderWeapons

---------------------------------------------------------------------------
-- QUESTS PANEL
---------------------------------------------------------------------------
local function questDef(id)
	for _, pool in ipairs({ Config.DailyQuests, Config.WeeklyQuests }) do
		for _, def in ipairs(pool) do
			if def.id == id then
				return def
			end
		end
	end
	return nil
end

local function questRows(list, scope, startOrder)
	for i, q in ipairs(list) do
		local def = questDef(q.id)
		if def then
			local done = q.progress >= def.target
			local row = card(74, startOrder + i, q.claimed and THEME.muted or (done and THEME.good or THEME.accent))
			text({
				Position = UDim2.new(0, 14, 0, 10),
				Size = UDim2.new(1, -180, 0, 20),
				Text = string.format(def.text, def.target),
				Font = Enum.Font.GothamBlack,
				TextColor3 = q.claimed and THEME.muted or THEME.text,
				MaxTextSize = 17,
				Parent = row,
			})
			bar(row, UDim2.new(0, 14, 0, 36), UDim2.new(1, -180, 0, 8), q.progress / def.target, done and THEME.good or THEME.accent)
			text({
				Position = UDim2.new(0, 14, 0, 50),
				Size = UDim2.new(1, -180, 0, 16),
				Text = string.format('%d/%d   <font color="%s">+%s coins</font>  <font color="%s">+%d pearls</font>  <font color="%s">+%s XP</font>  <font color="%s">+%d season XP</font>',
					q.progress, def.target, "#" .. THEME.gold:ToHex(), Config.FormatNumber(def.reward.coins * math.min(q.level or state.level, state.level)),
					"#" .. THEME.pearl:ToHex(), def.reward.pearls,
					"#" .. THEME.accent:ToHex(), Config.FormatNumber(math.floor(Config.XPToNext(state.level) * (def.reward.levels or 0))),
					"#" .. Color3.fromRGB(255, 90, 220):ToHex(), def.reward.seasonXp),
				RichText = true,
				Font = Enum.Font.GothamMedium,
				TextColor3 = THEME.muted,
				MaxTextSize = 13,
				Parent = row,
			})
			local claim = button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.new(0, 140, 0, 40),
				Text = q.claimed and "CLAIMED" or (done and "CLAIM" or "IN PROGRESS"),
				BackgroundColor3 = (done and not q.claimed) and Color3.fromRGB(40, 170, 90) or Color3.fromRGB(60, 65, 75),
				TextColor3 = (done and not q.claimed) and THEME.text or THEME.muted,
				MaxTextSize = 15,
				Parent = row,
			})
			claim.MouseButton1Click:Connect(function()
				if done and not q.claimed then
					Action:FireServer("ClaimQuest", scope, i)
				end
			end)
		end
	end
end

local questTimerLabels = {}
local function renderQuests()
	panelTitle.Text = "QUESTS"
	panelSubtitle.Text = "Rewards grow with your level"
	listLayout()
	questTimerLabels.daily = sectionTitle("DAILY", 1)
	questRows(state.dailyQuests, "daily", 1)
	questTimerLabels.weekly = sectionTitle("WEEKLY", 50)
	questRows(state.weeklyQuests, "weekly", 50)
end

---------------------------------------------------------------------------
-- SEASON PASS PANEL
---------------------------------------------------------------------------
local TRACK_COLORS = {
	free = Color3.fromRGB(150, 175, 195),
	premium = Color3.fromRGB(255, 205, 80),
	mystic = Color3.fromRGB(255, 90, 220),
	bonus = Color3.fromRGB(235, 230, 255),
}

local function ownsTrack(season, track)
	if track == "free" then
		return true
	elseif track == "premium" then
		return season.premium or season.mystic
	end
	return season.mystic
end

local function renderSeason()
	local cfg = Config.Season
	local season = state.season
	local tier = Config.SeasonTier(season.xp)
	panelTitle.Text = "SEASON PASS"
	panelSubtitle.Text = cfg.name
	listLayout()

	-- header: tier, xp bar, buy + prestige buttons
	local head = card(132, 0, TRACK_COLORS.mystic)
	local tierText = tier <= cfg.tiers and ("TIER " .. tier .. " / " .. cfg.tiers) or ("TIER " .. cfg.tiers .. "  +" .. (tier - cfg.tiers) .. " BONUS")
	text({
		Position = UDim2.new(0, 14, 0, 10),
		Size = UDim2.new(0.5, 0, 0, 26),
		Text = tierText,
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 24,
		Parent = head,
	})
	local stars = ""
	for p = 1, cfg.maxPrestige do
		stars ..= p <= season.prestige and "[*]" or "[ ]"
	end
	text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.new(0.45, 0, 0, 20),
		Text = "Prestige " .. season.prestige .. "/" .. cfg.maxPrestige .. "  " .. stars,
		Font = Enum.Font.GothamBlack,
		TextColor3 = TRACK_COLORS.mystic,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 17,
		Parent = head,
	})
	local into = season.xp % cfg.xpPerTier
	bar(head, UDim2.new(0, 14, 0, 42), UDim2.new(1, -28, 0, 10), into / cfg.xpPerTier, TRACK_COLORS.mystic)
	local bonus = season.mystic and cfg.mysticXpBonus or (season.premium and cfg.premiumXpBonus or 0)
	text({
		Position = UDim2.new(0, 14, 0, 56),
		Size = UDim2.new(1, -28, 0, 16),
		Text = string.format("%d / %d XP to the next tier%s   |   Rewards x%.2f at this prestige",
			into, cfg.xpPerTier, bonus > 0 and (" (+" .. pct(bonus) .. "% season XP)") or "",
			cfg.prestigeMultiplier[season.prestige + 1]),
		Font = Enum.Font.GothamMedium,
		TextColor3 = THEME.muted,
		MaxTextSize = 13,
		Parent = head,
	})

	local function passButton(xScale, key, owned, label, color)
		local b = button({
			Position = UDim2.new(xScale, 14, 0, 82),
			Size = UDim2.new(0.33, -20, 0, 40),
			Text = owned and (label .. " OWNED") or label,
			BackgroundColor3 = owned and Color3.fromRGB(60, 65, 75) or color,
			TextColor3 = owned and THEME.muted or THEME.bg,
			MaxTextSize = 15,
			Parent = head,
		})
		b.MouseButton1Click:Connect(function()
			if not owned then
				Action:FireServer("Buy", key)
			end
		end)
	end
	local premium = Config.GetProductByKey("SeasonPremium")
	local mystic = Config.GetProductByKey("SeasonMystic")
	passButton(0, "SeasonPremium", season.premium or season.mystic,
		(season.premium or season.mystic) and "PREMIUM" or ("PREMIUM  R$" .. premium.price), TRACK_COLORS.premium)
	passButton(0.33, "SeasonMystic", season.mystic, season.mystic and "MYSTIC" or ("MYSTIC  R$" .. mystic.price), TRACK_COLORS.mystic)
	local canPrestige = season.prestige < cfg.maxPrestige and tier >= cfg.tiers + cfg.prestigeExtraTiers
	local prestigeButton = button({
		Position = UDim2.new(0.66, 14, 0, 82),
		Size = UDim2.new(0.34, -28, 0, 40),
		Text = season.prestige >= cfg.maxPrestige and "MAX PRESTIGE"
			or (canPrestige and "PRESTIGE!" or ("PRESTIGE AT TIER " .. (cfg.tiers + cfg.prestigeExtraTiers))),
		BackgroundColor3 = canPrestige and Color3.fromRGB(230, 140, 40) or Color3.fromRGB(60, 65, 75),
		TextColor3 = canPrestige and THEME.text or THEME.muted,
		MaxTextSize = 14,
		Parent = head,
	})
	if canPrestige then
		confirmButton(prestigeButton, "prestige", function()
			Action:FireServer("SeasonPrestige")
		end)
	end

	-- track headers
	local headers = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = content })
	for i, track in ipairs({ "FREE", "PREMIUM", "MYSTIC" }) do
		text({
			Position = UDim2.new(0.1 + (i - 1) * 0.3, 0, 0, 0),
			Size = UDim2.new(0.3, -6, 1, 0),
			Text = track,
			Font = Enum.Font.GothamBlack,
			TextColor3 = TRACK_COLORS[track:lower()],
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 15,
			Parent = headers,
		})
	end

	-- one row per tier
	for t = 1, cfg.tiers do
		local reached = tier >= t
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = reached and THEME.cardHover or THEME.card,
			LayoutOrder = 1 + t,
			Parent = content,
		})
		corner(row, 8)
		text({
			Size = UDim2.new(0.1, -4, 1, 0),
			Text = tostring(t),
			Font = Enum.Font.GothamBlack,
			TextColor3 = reached and THEME.accent or THEME.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 20,
			Parent = row,
		})
		local rewards = cfg.rewards[t] or {}
		for i, track in ipairs({ "free", "premium", "mystic" }) do
			local reward = rewards[track]
			if reward then
				local label, color = Config.DescribeReward(reward, season.prestige)
				local claimed = season.claimed[track .. ":" .. t] == true
				local locked = not ownsTrack(season, track)
				local cell = new("Frame", {
					Position = UDim2.new(0.1 + (i - 1) * 0.3, 0, 0, 5),
					Size = UDim2.new(0.3, -6, 1, -10),
					BackgroundColor3 = claimed and Color3.fromRGB(30, 80, 50) or THEME.bg,
					Parent = row,
				})
				corner(cell, 6)
				stroke(cell, TRACK_COLORS[track], 1.5, locked and 0.75 or 0.2)
				text({
					Position = UDim2.new(0, 6, 0, 2),
					Size = UDim2.new(1, -12, 1, -4),
					Text = (claimed and "GOT: " or (locked and "LOCKED: " or "")) .. label,
					Font = Enum.Font.GothamBold,
					TextColor3 = locked and Color3.fromRGB(110, 120, 135) or color,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = true,
					MaxTextSize = 13,
					Parent = cell,
				})
			end
		end
	end
	local foot = card(40, 100, THEME.muted)
	text({
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.new(0, 12, 0.5, -14),
		Text = "Earn season XP from hauls, creatures, quests, events and " .. Config.Drifters.name .. "s floating in the sea (they can hold season Charms!). Prestige to restart with bigger rewards and upgraded season pets.",
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.muted,
		TextWrapped = true,
		MaxTextSize = 13,
		Parent = foot,
	})
end

---------------------------------------------------------------------------
-- REBIRTH PANEL
---------------------------------------------------------------------------
local function bonusLine(b)
	return string.format("+%d%% coins   +%d%% XP   +%d%% luck   +%d%% damage   +%d health",
		pct(b.coins), pct(b.xp), pct(b.luck), pct(b.damage), b.health)
end

local function robuxButton(parent, position, size, key, label, color)
	local product = Config.GetProductByKey(key)
	local b = button({
		Position = position,
		Size = size,
		Text = label .. "  R$" .. product.price,
		BackgroundColor3 = color,
		MaxTextSize = 14,
		Parent = parent,
	})
	b.MouseButton1Click:Connect(function()
		Action:FireServer("Buy", key)
	end)
	return b
end

local function renderRebirth()
	local rb = Config.Rebirth
	local r = state.rebirths
	panelTitle.Text = "REBIRTH"
	panelSubtitle.Text = "Rebirth " .. r .. " / " .. rb.max
	listLayout()

	local current = card(62, 1, THEME.gold)
	text({
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 20),
		Text = r > 0 and ("YOUR BONUSES FROM " .. r .. " REBIRTH" .. (r > 1 and "S" or "")) or "NO REBIRTHS YET",
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.gold,
		MaxTextSize = 16,
		Parent = current,
	})
	text({
		Position = UDim2.new(0, 14, 0, 34),
		Size = UDim2.new(1, -28, 0, 18),
		Text = r > 0 and bonusLine(Config.RebirthTotals(r)) or "Rebirth to get permanent bonuses that stack up every time.",
		Font = Enum.Font.GothamMedium,
		MaxTextSize = 14,
		Parent = current,
	})

	if r >= rb.max then
		local maxed = card(50, 2, THEME.good)
		text({
			Size = UDim2.new(1, -28, 0, 24),
			Position = UDim2.new(0, 14, 0.5, -12),
			Text = "MAX REBIRTH REACHED. You're a legend of the deep!",
			Font = Enum.Font.GothamBlack,
			TextColor3 = THEME.good,
			MaxTextSize = 18,
			Parent = maxed,
		})
		return
	end

	-- progress toward the next one
	local needLevel, needCoins = Config.RebirthRequirement(r)
	local levelOk, coinsOk = state.level >= needLevel, state.coins >= needCoins
	local req = card(104, 2)
	text({
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "REBIRTH " .. (r + 1) .. " NEEDS",
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.accent,
		MaxTextSize = 16,
		Parent = req,
	})
	text({
		Position = UDim2.new(0, 14, 0, 32),
		Size = UDim2.new(1, -28, 0, 18),
		Text = string.format("Level %d / %d", math.min(state.level, needLevel), needLevel),
		TextColor3 = levelOk and THEME.good or THEME.text,
		MaxTextSize = 15,
		Parent = req,
	})
	bar(req, UDim2.new(0, 14, 0, 52), UDim2.new(1, -28, 0, 8), state.level / needLevel, levelOk and THEME.good or THEME.accent)
	text({
		Position = UDim2.new(0, 14, 0, 64),
		Size = UDim2.new(1, -28, 0, 18),
		Text = string.format("Coins %s / %s", Config.FormatNumber(math.min(state.coins, needCoins)), Config.FormatNumber(needCoins)),
		TextColor3 = coinsOk and THEME.good or THEME.text,
		MaxTextSize = 15,
		Parent = req,
	})
	bar(req, UDim2.new(0, 14, 0, 84), UDim2.new(1, -28, 0, 8), state.coins / needCoins, coinsOk and THEME.good or THEME.gold)

	local nextBonus = Config.RebirthBonusFor(r + 1)
	local info = card(116, 3, THEME.muted)
	text({
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 34),
		Text = "YOU GAIN: " .. bonusLine(nextBonus) .. "   +" .. nextBonus.pearls .. " Pearls",
		Font = Enum.Font.GothamBold,
		TextColor3 = THEME.good,
		TextWrapped = true,
		MaxTextSize = 14,
		Parent = info,
	})
	text({
		Position = UDim2.new(0, 14, 0, 46),
		Size = UDim2.new(1, -28, 0, 18),
		Text = "YOU LOSE: your level, coins, subs and shop weapons.",
		Font = Enum.Font.GothamBold,
		TextColor3 = THEME.danger,
		MaxTextSize = 14,
		Parent = info,
	})
	text({
		Position = UDim2.new(0, 14, 0, 68),
		Size = UDim2.new(1, -28, 0, 40),
		Text = "YOU KEEP: ships, fragments, pets, charms, eggs, pearls, season progress, season weapons, passes and boosts. Each rebirth gives more than the last, and the next one needs more.",
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		MaxTextSize = 13,
		Parent = info,
	})

	local ready = levelOk and coinsOk
	local go = card(60, 4, ready and THEME.gold or THEME.muted)
	local b = button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 260, 0, 44),
		Text = ready and "REBIRTH NOW" or "NOT READY YET",
		BackgroundColor3 = ready and Color3.fromRGB(230, 140, 40) or Color3.fromRGB(60, 65, 75),
		TextColor3 = ready and THEME.text or THEME.muted,
		Parent = go,
	})
	if ready then
		confirmButton(b, "rebirth", function()
			Action:FireServer("Rebirth")
		end)
	end

	-- faster with Robux
	local fast = card(104, 5, THEME.gold)
	text({
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "IN A HURRY?  Daily quests also give XP and coins toward rebirth.",
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.gold,
		MaxTextSize = 14,
		Parent = fast,
	})
	robuxButton(fast, UDim2.new(0, 10, 0, 40), UDim2.new(0.333, -14, 0, 52), "RebirthRush", "2x COINS+XP 30m", Color3.fromRGB(40, 140, 200))
	robuxButton(fast, UDim2.new(0.333, 4, 0, 40), UDim2.new(0.333, -8, 0, 52), "LevelPack", "+3 LEVELS", Color3.fromRGB(40, 170, 90))
	robuxButton(fast, UDim2.new(0.666, 4, 0, 40), UDim2.new(0.334, -14, 0, 52), "InstantRebirth", "REBIRTH NOW", Color3.fromRGB(230, 140, 40))
end

---------------------------------------------------------------------------
-- STORE PANEL (Robux)
---------------------------------------------------------------------------
local STORE_ACCENTS = {
	boost = Color3.fromRGB(110, 235, 140),
	rebirth = Color3.fromRGB(255, 160, 60),
	season = Color3.fromRGB(255, 90, 220),
	pass = Color3.fromRGB(255, 205, 80),
}

local function boostTimeLeft(boost)
	if type(boost) == "table" then
		local least = math.huge
		for _, which in ipairs(boost) do
			least = math.min(least, secondsLeft(state.boostsLeft[which]))
		end
		return least == math.huge and 0 or least
	end
	return secondsLeft(state.boostsLeft[boost])
end

local function storeCard(parent, order, item, owned, accent, extra, badge)
	local box = new("Frame", { BackgroundColor3 = THEME.card, LayoutOrder = order, Parent = parent })
	corner(box, 12)
	stroke(box, owned and THEME.good or accent, owned and 2 or 1.5, owned and 0.2 or 0.35)
	local stripe = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = box })
	corner(stripe, 3)
	if badge then
		local tag = new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 12),
			Size = UDim2.new(0, 84, 0, 20),
			BackgroundColor3 = accent,
			Parent = box,
		})
		corner(tag, 10)
		text({
			Size = UDim2.fromScale(1, 1),
			Text = badge,
			Font = Enum.Font.GothamBlack,
			TextColor3 = THEME.bg,
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 11,
			Parent = tag,
		})
	end
	text({
		Position = UDim2.new(0, 10, 0, 14),
		Size = UDim2.new(1, badge and -100 or -20, 0, 20),
		Text = item.name,
		Font = Enum.Font.GothamBlack,
		TextColor3 = accent,
		MaxTextSize = 16,
		Parent = box,
	})
	text({
		Position = UDim2.new(0, 10, 0, 38),
		Size = UDim2.new(1, -20, 0, 50),
		Text = item.desc .. (extra or ""),
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 13,
		Parent = box,
	})
	local b = button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 34),
		Text = owned and "OWNED" or ("R$ " .. item.price),
		BackgroundColor3 = owned and Color3.fromRGB(60, 65, 75) or Color3.fromRGB(40, 170, 90),
		TextColor3 = owned and THEME.muted or THEME.text,
		MaxTextSize = 16,
		Parent = box,
	})
	b.MouseButton1Click:Connect(function()
		if not owned then
			Action:FireServer("Buy", item.key)
		end
	end)
end

local function renderStore()
	panelTitle.Text = "STORE"
	panelSubtitle.Text = state.studio and "Studio test mode: items without an id are free" or "Thank you for supporting the game!"
	listLayout()

	sectionTitle("BOOSTS  (buy again to add more time)", 1)
	local boosts = gridSection(2, UDim2.new(0.25, -6, 0, 150))
	for i, product in ipairs(Config.Products) do
		if product.boost then
			local left = boostTimeLeft(product.boost)
			storeCard(boosts, i, product, false, STORE_ACCENTS.boost, left > 0 and ("\nActive: " .. formatTime(left)) or "",
				type(product.boost) == "table" and "COMBO" or nil)
		end
	end

	sectionTitle("REBIRTH FASTER", 3)
	local rebirthGrid = gridSection(4, UDim2.new(0.5, -6, 0, 150))
	for i, product in ipairs(Config.Products) do
		if product.levels or product.rebirth then
			storeCard(rebirthGrid, i, product, false, STORE_ACCENTS.rebirth)
		end
	end

	sectionTitle("SEASON PASSES  -  " .. Config.Season.name, 5)
	local seasonGrid = gridSection(6, UDim2.new(0.5, -6, 0, 150))
	for i, product in ipairs(Config.Products) do
		if product.seasonPass then
			local owned = (product.seasonPass == "premium" and (state.season.premium or state.season.mystic))
				or (product.seasonPass == "mystic" and state.season.mystic)
			storeCard(seasonGrid, i, product, owned, product.seasonPass == "mystic" and STORE_ACCENTS.season or STORE_ACCENTS.pass, nil,
				product.seasonPass == "mystic" and "BEST VALUE" or nil)
		end
	end

	sectionTitle("GAME PASSES  (yours forever)", 7)
	local passes = gridSection(8, UDim2.new(0.333, -6, 0, 150))
	for i, pass in ipairs(Config.GamePasses) do
		storeCard(passes, i, pass, state.passes[pass.key] == true, STORE_ACCENTS.pass)
	end
end

---------------------------------------------------------------------------
-- BOOST TIMERS (top right) + UNDERWATER LOOK IN HUNTING GROUNDS
---------------------------------------------------------------------------
local boostHolder = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 60),
	Size = UDim2.new(0, 170, 0, 120),
	BackgroundTransparency = 1,
	Parent = gui,
})
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = boostHolder })
local boostLabels = {}
for _, which in ipairs({ "coins", "luck", "xp" }) do
	local pill = new("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = boostHolder,
	})
	corner(pill, 14)
	stroke(pill, THEME.good, 2, 0.2)
	boostLabels[which] = text({
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.new(0, 8, 0, 3),
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 15,
		Parent = pill,
	})
end

local function updateBoostPills()
	for which, label in pairs(boostLabels) do
		local left = state and state.boostsLeft and secondsLeft(state.boostsLeft[which]) or 0
		label.Parent.Visible = left > 0
		if left > 0 then
			label.Text = "2x " .. which:upper() .. "  " .. formatTime(left)
		end
	end
end

local Lighting = game:GetService("Lighting")
local underwaterCC = nil
local savedLook = nil
local currentArena = nil

local function setUnderwater(arenaDef)
	local atmosphere = Lighting:FindFirstChild("SalvageAtmosphere")
	if arenaDef then
		if not savedLook then
			savedLook = {
				brightness = Lighting.Brightness,
				density = atmosphere and atmosphere.Density,
				color = atmosphere and atmosphere.Color,
				decay = atmosphere and atmosphere.Decay,
				haze = atmosphere and atmosphere.Haze,
			}
		end
		local depthDark = (arenaDef.zone - 1) / 4
		if atmosphere then
			TweenService:Create(atmosphere, TweenInfo.new(1), {
				Density = arenaDef.fog,
				Color = arenaDef.water,
				Decay = arenaDef.water:Lerp(Color3.new(0, 0, 0), 0.5),
				Haze = 2,
			}):Play()
		end
		TweenService:Create(Lighting, TweenInfo.new(1), { Brightness = 2 - depthDark * 1.5 }):Play()
		if not underwaterCC then
			underwaterCC = new("ColorCorrectionEffect", { Name = "UnderwaterLook", Parent = Lighting })
		end
		underwaterCC.TintColor = arenaDef.water:Lerp(Color3.new(1, 1, 1), 0.55)
		underwaterCC.Saturation = 0.1
	elseif savedLook then
		if atmosphere then
			TweenService:Create(atmosphere, TweenInfo.new(1), {
				Density = savedLook.density,
				Color = savedLook.color,
				Decay = savedLook.decay,
				Haze = savedLook.haze,
			}):Play()
		end
		TweenService:Create(Lighting, TweenInfo.new(1), { Brightness = savedLook.brightness }):Play()
		if underwaterCC then
			underwaterCC:Destroy()
			underwaterCC = nil
		end
		savedLook = nil
	end
end

local function updateArenaLook()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local found = nil
	if hrp then
		for i, def in ipairs(Config.Arenas) do
			local offset = hrp.Position - Config.ArenaCenter(i)
			local half = Config.ArenaSize / 2 + 10
			if math.abs(offset.X) <= half and math.abs(offset.Z) <= half and offset.Y > -20 and offset.Y < 150 then
				found = def
			end
		end
	end
	if found ~= currentArena then
		currentArena = found
		setUnderwater(found)
	end
end

---------------------------------------------------------------------------
-- PANEL SWITCHING
---------------------------------------------------------------------------
local renderers = {
	Fleet = renderFleet,
	Shop = renderShop,
	Logbook = renderLogbook,
	Pets = renderPets,
	Trade = renderTrade,
	Quests = renderQuests,
	Season = renderSeason,
	Rebirth = renderRebirth,
	Store = renderStore,
}

local lastPetsSignature = nil

-- The Pets panel has 3D previews, so only rebuild it when something it shows changed
local function petsSignature()
	local affordable = {}
	for _, egg in ipairs(Config.Eggs) do
		affordable[egg.id] = (egg.currency == "Pearls" and state.pearls or state.coins) >= egg.cost
	end
	return HttpService:JSONEncode({ state.pets, state.equipped, state.eggs, affordable, state.charms, state.equippedCharms, petsTab, petFilter })
end

local function renderPanel(force)
	if not currentPanel or not state then
		return
	end
	if currentPanel == "Pets" then
		local signature = petsSignature()
		if not force and signature == lastPetsSignature then
			return
		end
		lastPetsSignature = signature
	end
	local scroll = content.CanvasPosition
	clearContent()
	renderers[currentPanel]()
	task.defer(function()
		content.CanvasPosition = scroll
	end)
end

renderPanelRef = function()
	renderPanel(true)
end

local function openPanel(name)
	if currentPanel == name then
		currentPanel = nil
		panel.Visible = false
		return
	end
	currentPanel = name
	panel.Visible = true
	content.CanvasPosition = Vector2.new()
	local scale = panel:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = panel })
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	renderPanel(true)
end

closeButton.MouseButton1Click:Connect(function()
	currentPanel = nil
	panel.Visible = false
end)

---------------------------------------------------------------------------
-- SIDE MENU
---------------------------------------------------------------------------
local function makeMenu(items, onRight)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(onRight and 1 or 0, 0.5),
		Position = UDim2.new(onRight and 1 or 0, onRight and -12 or 12, 0.5, 20),
		Size = UDim2.new(0, 108, 0, #items * 46 + (#items - 1) * 7),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	for i, item in ipairs(items) do
		local b = button({
			Size = UDim2.new(1, 0, 0, 46),
			Text = item.label,
			LayoutOrder = i,
			BackgroundColor3 = THEME.bg,
			TextColor3 = item.color,
			MaxTextSize = 17,
			Parent = holder,
		})
		stroke(b, item.color, 2, 0.15)
		b.MouseButton1Click:Connect(item.action)
	end
end

makeMenu({
	{ label = "FLEET", color = THEME.accent, action = function() openPanel("Fleet") end },
	{ label = "SHOP", color = Color3.fromRGB(80, 200, 110), action = function() openPanel("Shop") end },
	{ label = "PETS", color = Color3.fromRGB(255, 130, 200), action = function() openPanel("Pets") end },
	{ label = "LOGBOOK", color = Color3.fromRGB(165, 120, 255), action = function() openPanel("Logbook") end },
	{ label = "QUESTS", color = Color3.fromRGB(120, 200, 255), action = function() openPanel("Quests") end },
}, false)
makeMenu({
	{ label = "SEASON", color = Color3.fromRGB(255, 90, 220), action = function() openPanel("Season") end },
	{ label = "STORE", color = THEME.gold, action = function() openPanel("Store") end },
	{ label = "REBIRTH", color = Color3.fromRGB(255, 160, 60), action = function() openPanel("Rebirth") end },
	{ label = "TRADE", color = Color3.fromRGB(230, 140, 40), action = function() openPanel("Trade") end },
	{ label = "MY BAY", color = THEME.text, action = function() Action:FireServer("GoToBay") end },
}, true)

---------------------------------------------------------------------------
-- SERVER -> CLIENT
---------------------------------------------------------------------------
local displayedCoins = 0

StateUpdate.OnClientEvent:Connect(function(newState)
	state = newState
	stateReceivedAt = os.clock()
	local target = state.coins
	local from = displayedCoins
	displayedCoins = target
	-- count-up animation for coins
	task.spawn(function()
		local steps = 12
		for s = 1, steps do
			if displayedCoins ~= target then
				return
			end
			coinsLabel.Text = Config.FormatNumber(from + (target - from) * s / steps)
			task.wait(0.025)
		end
	end)
	pearlsLabel.Text = Config.FormatNumber(state.pearls)
	levelLabel.Text = "Lv " .. state.level
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(state.xp / state.xpNeeded, 0, 1), 1) }):Play()
	renderPanel()
end)

local function hex(color)
	return "#" .. color:ToHex()
end

-- Short UI sounds using sounds built into Roblox (swap in your own uploads later)
local SoundService = game:GetService("SoundService")
local PING = "rbxasset://sounds/electronicpingshort.wav"
local function playSound(id, volume, pitch)
	local sound = new("Sound", { SoundId = id, Volume = volume or 0.4, PlaybackSpeed = pitch or 1, Parent = SoundService })
	SoundService:PlayLocalSound(sound)
	task.delay(4, function()
		sound:Destroy()
	end)
end
local SOUND_FOR = {
	levelup = { 0.6, 1.3 },
	ship = { 0.7, 0.8 },
	hatch = { 0.6, 1.1 },
	purchase = { 0.5, 1.2 },
	rebirth = { 0.7, 0.7 },
	seasonTier = { 0.5, 1.4 },
	charm = { 0.5, 1.5 },
	questDone = { 0.4, 1.2 },
}

Notify.OnClientEvent:Connect(function(msg)
	local kind = msg.kind
	local sound = SOUND_FOR[kind]
	if sound then
		playSound(PING, sound[1], sound[2])
	elseif kind == "loot" and (msg.isNew or msg.rarity >= 3) then
		playSound(PING, 0.3 + msg.rarity * 0.06, 0.8 + msg.rarity * 0.12)
	end
	if kind == "loot" then
		local rarity = Config.Rarities[msg.rarity]
		local ship = Config.GetShip(msg.ship)
		if msg.isNew then
			toast(string.format('<font color="%s">NEW %s</font>  %s - %s', hex(rarity.color), rarity.name:upper(), ship.name, msg.part),
				rarity.color, 4.5)
		else
			toast(string.format('<font color="%s">%s</font> %s (duplicate) sold for <font color="%s">+%s</font>',
				hex(rarity.color), rarity.name, msg.part, hex(THEME.gold), Config.FormatNumber(msg.sold)), rarity.color, 3)
		end
		if msg.rarity == 5 then
			showSplash("SECRET GHOST FRAGMENT!", rarity.color)
		elseif msg.rarity == 4 and msg.isNew then
			showSplash("ROYAL FRAGMENT!", rarity.color)
		end
	elseif kind == "coins" then
		toast(string.format('Haul sold: <font color="%s">+%s coins</font>', hex(THEME.gold), Config.FormatNumber(msg.amount)), THEME.gold, 2.5)
	elseif kind == "ship" then
		local ship = Config.GetShip(msg.ship)
		local color = Config.Rarities[ship.rarity].color
		showSplash("SHIP RESTORED: " .. ship.name:upper(), color)
		toast(string.format("%s now floats at your bay! Permanent +%d%% coins.", ship.name, math.floor(ship.bonus * 100 + 0.5)), color, 6)
	elseif kind == "breach" then
		toast(string.format('<font color="%s">HULL BREACH!</font> %s lost its haul in %s.', hex(THEME.danger), msg.sub, msg.zone),
			THEME.danger, 4)
	elseif kind == "announce" then
		toast(msg.text, msg.color or THEME.accent, 5)
	elseif kind == "chest" then
		toast(string.format('Treasure! <font color="%s">+%d Pearls</font>  <font color="%s">+%s coins</font>',
			hex(THEME.pearl), msg.pearls, hex(THEME.gold), Config.FormatNumber(msg.coins)), THEME.gold, 3)
	elseif kind == "kraken" then
		showSplash("KRAKEN DEFEATED!", Color3.fromRGB(230, 110, 220))
		if msg.egg then
			toast("You earned a KRAKEN EGG! Hatch it in the PETS menu.", Color3.fromRGB(255, 150, 190), 6)
		end
		toast(string.format('You hit it %d times: <font color="%s">+%d Pearls</font> <font color="%s">+%s coins</font>',
			msg.hits, hex(THEME.pearl), msg.pearls, hex(THEME.gold), Config.FormatNumber(msg.coins)), Color3.fromRGB(230, 110, 220), 6)
	elseif kind == "bought" then
		toast(msg.sub .. " has joined your fleet and is diving now!", THEME.good, 4)
	elseif kind == "error" then
		toast(msg.text, THEME.danger, 3)
	elseif kind == "info" then
		toast(msg.text, THEME.accent, 3)
	elseif kind == "purchase" then
		toast(msg.text, THEME.good, 5)
	elseif kind == "charm" then
		local charm = Config.GetCharm(msg.id)
		if charm then
			local color = Config.PetRarities[charm.rarity].color
			toast(string.format('%s <font color="#%s">%s</font> (%s)%s', msg.isNew and "NEW CHARM!" or "Charm:", color:ToHex(), charm.name,
				Config.DescribeBonus(charm.bonus), msg.isNew and "  Equipped it for you." or ""), color, 5)
			if charm.rarity >= 4 then
				showSplash(charm.name:upper() .. "!", color)
			end
		end
	elseif kind == "drifter" then
		toast(string.format('%s opened: <font color="#%s">+%s coins</font> +%d season XP', Config.Drifters.name, THEME.gold:ToHex(),
			Config.FormatNumber(msg.coins), msg.seasonXp), Config.Drifters.color, 3)
	elseif kind == "seasonTier" then
		showSplash("SEASON TIER " .. msg.tier .. "!", Color3.fromRGB(255, 90, 220))
	elseif kind == "seasonRewards" then
		for _, entry in ipairs(msg.rewards) do
			local label, color = Config.DescribeReward(entry.reward, entry.raw and 0 or msg.prestige)
			toast(string.format('<font color="#%s">%s</font> tier %d: %s', TRACK_COLORS[entry.track]:ToHex(), entry.track:upper(), entry.tier, label),
				color, 5)
		end
	elseif kind == "seasonPrestige" then
		showSplash("SEASON PRESTIGE " .. msg.prestige .. "!", Color3.fromRGB(255, 90, 220))
		toast("The pass has reset. Every reward is bigger now, and season pets are upgraded!", Color3.fromRGB(255, 90, 220), 7)
	elseif kind == "questDone" then
		toast("Quest complete: " .. msg.text .. ". Claim it in QUESTS!", THEME.good, 5)
	elseif kind == "questClaimed" then
		toast(string.format('Quest reward: <font color="#%s">+%s coins</font> +%d pearls +%s XP +%d season XP',
			THEME.gold:ToHex(), Config.FormatNumber(msg.coins), msg.pearls, Config.FormatNumber(msg.xp or 0), msg.seasonXp), THEME.good, 4)
	elseif kind == "rebirth" then
		showSplash("REBIRTH " .. msg.rebirths .. "!", THEME.gold)
		toast("+" .. (msg.pearls or 0) .. " Pearls! Your rebirth bonuses are permanent. Time to dive again!", THEME.gold, 6)
	elseif kind == "kill" then
		if msg.boss then
			showSplash("LEVIATHAN SLAIN!", Color3.fromRGB(60, 255, 230))
		end
		toast(string.format('Defeated %s  <font color="#%s">+%s coins</font>%s', msg.enemy, THEME.gold:ToHex(),
			Config.FormatNumber(msg.coins), msg.pearls and ("  +" .. msg.pearls .. " pearls") or ""), Color3.fromRGB(255, 120, 120), 2)
	elseif kind == "egg" then
		local egg = Config.GetEgg(msg.egg)
		toast(string.format('<font color="%s">EGG!</font> You found a %s. Hatch it in the PETS menu.', hex(egg.spots), egg.name), egg.spots, 5)
	elseif kind == "levelup" then
		showSplash("LEVEL " .. msg.level .. "!", THEME.accent)
		if msg.tradeUnlocked then
			toast("TRADING UNLOCKED! Open the TRADE menu. Turn off Auto-sell in the Logbook to keep spares.", Color3.fromRGB(230, 140, 40), 8)
		end
	elseif kind == "hatch" then
		if hatching then
			table.insert(hatchQueue, { msg.egg, msg.pet })
		else
			task.spawn(playHatch, msg.egg, msg.pet)
		end
	elseif kind == "released" then
		local def = Config.GetPet(msg.pet)
		toast(string.format('Released %s: <font color="%s">+%s coins</font>', def and def.name or "pet", hex(THEME.gold), Config.FormatNumber(msg.coins)), THEME.muted, 3)
	elseif kind == "soldSpares" then
		toast(string.format('Sold %d spares for <font color="%s">+%s coins</font>', msg.count, hex(THEME.gold), Config.FormatNumber(msg.coins)), THEME.gold, 3)
	elseif kind == "tradeRequest" then
		pendingRequestFrom = msg.fromUserId
		requestLabel.Text = msg.from .. " wants to trade!"
		requestPopup.Visible = true
		local thisRequest = msg.fromUserId
		task.delay(20, function()
			if pendingRequestFrom == thisRequest then
				pendingRequestFrom = nil
				requestPopup.Visible = false
			end
		end)
	elseif kind == "trade" then
		local first = trade == nil
		trade = msg
		if first and currentPanel ~= "Trade" then
			openPanel("Trade")
		else
			renderPanel()
		end
	elseif kind == "tradeEnded" then
		trade = nil
		toast(msg.text, msg.color or THEME.accent, 4)
		renderPanel()
	elseif kind == "welcome" then
		toast("Welcome to Deep Sea Salvage! Your sub is already diving.", THEME.accent, 7)
		toast("When it surfaces, hold E on the crate at your bay to haul it up.", THEME.accent, 8)
		if not msg.canSave then
			toast("Saving is OFF on this server (see README: enable API Services).", THEME.danger, 8)
		end
	end
end)

---------------------------------------------------------------------------
-- LIVE COUNTDOWNS
---------------------------------------------------------------------------
Action:FireServer("RequestState")

while true do
	task.wait(0.2)
	refreshBanner()
	updateBoostPills()
	updateArenaLook()
	if currentPanel == "Quests" and state then
		if questTimerLabels.daily and questTimerLabels.daily.Parent then
			questTimerLabels.daily.Text = "DAILY  -  new quests in " .. formatTime(secondsLeft(state.dailyResetIn))
		end
		if questTimerLabels.weekly and questTimerLabels.weekly.Parent then
			questTimerLabels.weekly.Text = "WEEKLY  -  new quests in " .. formatTime(secondsLeft(state.weeklyResetIn))
		end
		if secondsLeft(state.dailyResetIn) < -2 then
			Action:FireServer("RequestState")
			state.dailyResetIn = 1e9
		end
	end
	if currentPanel == "Fleet" and state then
		for i, label in pairs(fleetStatusLabels) do
			local sub = state.subs[i]
			if sub and label.Parent then
				local statusText, statusColor = statusInfo(sub)
				label.Text = statusText
				label.TextColor3 = statusColor
			end
		end
	end
end
