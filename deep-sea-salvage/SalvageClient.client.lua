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
	Size = UDim2.new(0, 330, 0, 44),
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
	Position = UDim2.fromScale(0.53, 0.53),
	Size = UDim2.fromScale(0.62, 0.66),
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
local function renderShop()
	panelTitle.Text = "SUB SHIPYARD"
	panelSubtitle.Text = string.format("Fleet %d/%d", #state.subs, Config.MaxFleet)
	listLayout()

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
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 196),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = content })

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
			Parent = content,
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
			local has = (state.parts[Config.PartKey(ship.id, partName)] or 0) > 0
			text({
				Text = has and ("+ " .. partName) or ("- " .. (hidden and "???" or partName)),
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
-- PANEL SWITCHING
---------------------------------------------------------------------------
local renderers = { Fleet = renderFleet, Shop = renderShop, Logbook = renderLogbook }

local function renderPanel()
	if not currentPanel or not state then
		return
	end
	local scroll = content.CanvasPosition
	clearContent()
	renderers[currentPanel]()
	task.defer(function()
		content.CanvasPosition = scroll
	end)
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
	renderPanel()
end

closeButton.MouseButton1Click:Connect(function()
	currentPanel = nil
	panel.Visible = false
end)

---------------------------------------------------------------------------
-- SIDE MENU
---------------------------------------------------------------------------
local menu = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.new(0, 112, 0, 4 * 52 + 3 * 10),
	BackgroundTransparency = 1,
	Parent = gui,
})
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })

local menuItems = {
	{ label = "FLEET", color = THEME.accent, action = function() openPanel("Fleet") end },
	{ label = "SHOP", color = Color3.fromRGB(80, 200, 110), action = function() openPanel("Shop") end },
	{ label = "LOGBOOK", color = Color3.fromRGB(165, 120, 255), action = function() openPanel("Logbook") end },
	{ label = "MY BAY", color = THEME.gold, action = function() Action:FireServer("GoToBay") end },
}
for i, item in ipairs(menuItems) do
	local b = button({
		Size = UDim2.new(1, 0, 0, 52),
		Text = item.label,
		LayoutOrder = i,
		BackgroundColor3 = THEME.bg,
		TextColor3 = item.color,
		MaxTextSize = 18,
		Parent = menu,
	})
	stroke(b, item.color, 2, 0.15)
	b.MouseButton1Click:Connect(item.action)
end

---------------------------------------------------------------------------
-- SERVER -> CLIENT
---------------------------------------------------------------------------
local displayedCoins = 0

StateUpdate.OnClientEvent:Connect(function(newState)
	state = newState
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
	renderPanel()
end)

local function hex(color)
	return "#" .. color:ToHex()
end

Notify.OnClientEvent:Connect(function(msg)
	local kind = msg.kind
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
		toast(string.format('You hit it %d times: <font color="%s">+%d Pearls</font> <font color="%s">+%s coins</font>',
			msg.hits, hex(THEME.pearl), msg.pearls, hex(THEME.gold), Config.FormatNumber(msg.coins)), Color3.fromRGB(230, 110, 220), 6)
	elseif kind == "bought" then
		toast(msg.sub .. " has joined your fleet and is diving now!", THEME.good, 4)
	elseif kind == "error" then
		toast(msg.text, THEME.danger, 3)
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
