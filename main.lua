-- ============================================================================
-- CYBERSKELETON PROTOTYPE 07 - SCRIPT UNIFICADO CLIENTE (DELTA EXECUTOR)
-- Consolidacion de los 6 scripts locales en una sola ejecucion.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

-- ============================================================================
-- 0. INFRAESTRUCTURA DE RED LOCAL (ADAPTADOR COMPATIBLE CON EXECUTORS)
-- ============================================================================
local networkFolder = ReplicatedStorage:FindFirstChild("CyberV2Local")
if not networkFolder then
	networkFolder = Instance.new("Folder")
	networkFolder.Name = "CyberV2Local"
	networkFolder.Parent = ReplicatedStorage
end

local requestEvent = networkFolder:FindFirstChild("Request")
if not requestEvent then
	requestEvent = Instance.new("BindableEvent")
	requestEvent.Name = "Request"
	requestEvent.Parent = networkFolder
end

local fxEvent = networkFolder:FindFirstChild("FX")
if not fxEvent then
	fxEvent = Instance.new("BindableEvent")
	fxEvent.Name = "FX"
	fxEvent.Parent = networkFolder
end

-- ============================================================================
-- 1. CONFIGURACIÓN Y ESTADO DEL JUGADOR
-- ============================================================================
player:SetAttribute("CyberNeural", player:GetAttribute("CyberNeural") or 0)
player:SetAttribute("CyberCharges", player:GetAttribute("CyberCharges") or 10)
player:SetAttribute("CyberMode", player:GetAttribute("CyberMode") or "Idle")
player:SetAttribute("CyberDashCharges", player:GetAttribute("CyberDashCharges") or 4)
player:SetAttribute("CyberLocalLift", 0)

local function getNow()
	return workspace:GetServerTimeNow()
end

local function triggerFX(evtName, targetPlayer, extraData)
	fxEvent:Fire(evtName, targetPlayer or player, extraData)
end

-- ============================================================================
-- 2. LÓGICA CORE DE HABILIDADES Y COMANDOS (MANEJADOR DE PETICIONES)
-- ============================================================================
local function processSkillRequest(plr, action)
	if plr ~= player then return end
	local now = getNow()
	local mode = player:GetAttribute("CyberMode") or "Idle"

	if action == "Sandevistan" then
		local cd = player:GetAttribute("CyberSandevistanReady") or 0
		if now >= cd then
			player:SetAttribute("CyberSandevistanReady", now + 12)
			player:SetAttribute("CyberSandeEnd", now + 5)
			triggerFX("Sande", player, { duration = 5 })
		end

	elseif action == "Dash" then
		local charges = player:GetAttribute("CyberDashCharges") or 4
		if charges > 0 then
			player:SetAttribute("CyberDashCharges", charges - 1)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local startPos = root.CFrame
				local finishPos = root.CFrame * CFrame.new(0, 0, -25)
				root.CFrame = finishPos
				triggerFX("Dash", player, { start = startPos, finish = finishPos })
			end
			task.delay(3, function()
				local cur = player:GetAttribute("CyberDashCharges") or 0
				if cur < 4 then player:SetAttribute("CyberDashCharges", cur + 1) end
			end)
		end

	elseif action == "Gravity" then
		if mode == "Idle" or mode == "Flight" then
			player:SetAttribute("CyberMode", "Phase")
			triggerFX("Phase", player)
			task.delay(1.5, function()
				if player:GetAttribute("CyberMode") == "Phase" then
					player:SetAttribute("CyberMode", "Idle")
				end
			end)
		end

	elseif action == "Fly" then
		if mode == "Flight" then
			player:SetAttribute("CyberMode", "Idle")
			triggerFX("Stop", player)
		else
			player:SetAttribute("CyberMode", "Flight")
		end

	elseif action == "Inject" then
		local charges = player:GetAttribute("CyberCharges") or 0
		if charges > 0 then
			player:SetAttribute("CyberCharges", charges - 1)
			local neural = player:GetAttribute("CyberNeural") or 0
			player:SetAttribute("CyberNeural", math.max(0, neural - 30))
			triggerFX("Inject", player)
		end
	end
end

requestEvent.Event:Connect(processSkillRequest)

-- ============================================================================
-- 3. INTERFAZ LOCAL (HUD & CONTROLES UI)
-- ============================================================================
local guiParent = player:WaitForChild("PlayerGui")
if not guiParent:FindFirstChild("CyberHUDv2") then
	local CYAN, RED, GREEN = Color3.fromRGB(70,225,255), Color3.fromRGB(255,65,85), Color3.fromRGB(65,255,150)

	local function create(class, parent, props)
		local item = Instance.new(class)
		for k, v in pairs(props or {}) do item[k] = v end
		item.Parent = parent
		return item
	end

	local function round(item, radius) create("UICorner", item, {CornerRadius = UDim.new(0, radius)}) end

	local function label(parent, text, x, y, w, h, color, size)
		return create("TextLabel", parent, {
			Text = text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1, TextColor3 = color or CYAN, TextSize = size or 11,
			Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left
		})
	end

	local gui = create("ScreenGui", guiParent, {Name = "CyberHUDv2", ResetOnSpawn = false, DisplayOrder = 15, IgnoreGuiInset = false})
	local tint = create("Frame", gui, {Name = "Tint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Active = false})
	local greenFlash = create("Frame", gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Active = false})
	local border = create("Frame", gui, {Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1, Active = false})
	create("UIStroke", border, {Color = CYAN, Thickness = 1, Transparency = 0.5})

	local glitch = {}
	for i = 1, 5 do
		glitch[i] = create("Frame", gui, {Size = UDim2.new(0.1 + i * 0.03, 0, 0, 1), Position = UDim2.fromScale(i * 0.13, 0.28 + i * 0.08), BackgroundColor3 = RED, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false})
	end

	local bar = create("ScrollingFrame", gui, {Name = "Habilidades", Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, -24, 0, 82), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 2, BackgroundTransparency = 1, BorderSizePixel = 0})
	create("UIListLayout", bar, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})

	local definitionsUI = {
		{"Sandevistan", "SANDE", Enum.KeyCode.One, CYAN}, {"Gravity", "GRAVITY", Enum.KeyCode.Two, RED},
		{"Pulse", "PULSE", Enum.KeyCode.Three, RED}, {"Atraction", "ATRACTION", Enum.KeyCode.Four, RED},
		{"Dash", "DASH", Enum.KeyCode.Five, CYAN}, {"Punch", "GOLPE", Enum.KeyCode.Six, RED},
		{"Fly", "VUELO", Enum.KeyCode.Seven, CYAN},
	}

	local buttons = {}
	for i, def in ipairs(definitionsUI) do
		local cell = create("Frame", bar, {Size = UDim2.fromOffset(64, 78), BackgroundTransparency = 1, LayoutOrder = i})
		local b = create("TextButton", cell, {Name = def[1], Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(2, 0), BackgroundColor3 = Color3.fromRGB(12, 28, 38), Text = def[2], TextSize = 10, Font = Enum.Font.GothamBlack, TextColor3 = def[4], BorderSizePixel = 0, AutoButtonColor = true})
		create("UICorner", b, {CornerRadius = UDim.new(1, 0)})
		create("UIStroke", b, {Color = def[4], Transparency = 0.25, Thickness = 1.5})
		local status = label(cell, "[" .. i .. "]", 0, 61, 64, 16, def[4], 10)
		status.TextXAlignment = Enum.TextXAlignment.Center
		b.Activated:Connect(function() requestEvent:Fire(player, def[1]) end)
		buttons[def[1]] = {button = b, status = status, def = def}
	end

	local function panel(name, right)
		local p = create("Frame", gui, {Name = name, Size = UDim2.fromOffset(240, 236), Position = UDim2.new(right and 1 or 0, right and -12 or 12, 0, 94), AnchorPoint = Vector2.new(right and 1 or 0, 0), BackgroundColor3 = Color3.fromRGB(6, 19, 26), BackgroundTransparency = 0.13, BorderSizePixel = 0})
		round(p, 9)
		create("UIStroke", p, {Color = right and RED or CYAN, Thickness = 1.4, Transparency = 0.2})
		return p, create("UIScale", p, {Scale = 1})
	end

	local left, scaleL = panel("Sistema", false)
	local right, scaleR = panel("Biomonitor", true)
	label(left, "CYBERSKELETON // LINK", 12, 10, 216, 20, CYAN, 13)
	label(left, "PROTOTYPE 07  /  ONLINE", 12, 32, 216, 15, CYAN, 10)
	label(right, "BIOMONITOR", 12, 10, 216, 20, RED, 13)
	local medical = label(right, "CARGA NEURAL", 12, 32, 216, 15, GREEN, 10)

	local function meter(parent, title, y, color)
		label(parent, title, 12, y, 165, 18, Color3.fromRGB(195, 228, 235), 10)
		local value = label(parent, "", 174, y, 54, 18, color, 11)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local back = create("Frame", parent, {Position = UDim2.fromOffset(12, y + 21), Size = UDim2.fromOffset(216, 13), BackgroundColor3 = Color3.fromRGB(23, 42, 50), BorderSizePixel = 0, ClipsDescendants = true})
		round(back, 5)
		local fill = create("Frame", back, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0})
		round(fill, 5)
		create("UIGradient", fill, {Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.35), color), Rotation = 0})
		return value, fill
	end

	local cap, capFill = meter(left, "CYBERWARE CAPACITY", 58, RED)
	cap.Text = "177/200" capFill.Size = UDim2.fromScale(177 / 200, 1)
	local progress, progressFill = meter(left, "CYBERSKELETON PROGRESS", 105, CYAN)
	progress.Text = "100%" progressFill.Size = UDim2.fromScale(1, 1)
	label(left, "IMMUNOSUPPRESSANT RESERVES", 12, 152, 216, 17, GREEN, 10)

	local doses = {}
	for i = 1, 10 do
		local back = create("Frame", left, {Position = UDim2.fromOffset(12 + (i - 1) * 22, 176), Size = UDim2.fromOffset(18, 31), BackgroundColor3 = Color3.fromRGB(30, 48, 42), BorderSizePixel = 0, ClipsDescendants = true})
		round(back, 3)
		doses[i] = create("Frame", back, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0})
	end

	local stateLabel = label(left, "ENLACE ACTIVO", 12, 214, 216, 15, GREEN, 10)
	local dosesValue, dosesFill = meter(right, "IMMUNOSUPPRESSANTS", 58, GREEN)
	local neuralValue, neuralFill = meter(right, "NEURAL LOAD", 105, CYAN)
	local inject = create("TextButton", right, {Name = "Inyectar", Position = UDim2.fromOffset(12, 156), Size = UDim2.fromOffset(216, 42), Text = "INYECTAR  [-30%]", TextColor3 = GREEN, TextSize = 13, Font = Enum.Font.GothamBlack, BackgroundColor3 = Color3.fromRGB(15, 60, 40), BorderSizePixel = 0})
	round(inject, 9)
	inject.Activated:Connect(function() requestEvent:Fire(player, "Inject") end)

	local soft = true
	local softButton = create("TextButton", right, {Position = UDim2.fromOffset(12, 206), Size = UDim2.fromOffset(216, 22), Text = "FX SUAVES: SI", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = CYAN, BackgroundTransparency = 1})
	softButton.Activated:Connect(function() soft = not soft softButton.Text = soft and "FX SUAVES: SI" or "FX ROJOS: NO" end)

	local lift = create("Frame", gui, {Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(132, 44), BackgroundTransparency = 1, Visible = false})
	local held = {}
	for i, item in ipairs({{"SUBIR", 1}, {"BAJAR", -1}}) do
		local b = create("TextButton", lift, {Position = UDim2.fromOffset((i - 1) * 68, 0), Size = UDim2.fromOffset(64, 44), Text = item[1], TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = CYAN, BackgroundColor3 = Color3.fromRGB(10, 35, 45), BorderSizePixel = 0})
		round(b, 10)
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				held[input] = item[2]
				player:SetAttribute("CyberLocalLift", item[2])
			end
		end)
	end

	UserInputService.InputEnded:Connect(function(input)
		if held[input] then held[input] = nil player:SetAttribute("CyberLocalLift", 0) end
	end)
	UserInputService.WindowFocusReleased:Connect(function() table.clear(held) player:SetAttribute("CyberLocalLift", 0) end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		for _, def in ipairs(definitionsUI) do if input.KeyCode == def[3] then requestEvent:Fire(player, def[1]) return end end
		if input.KeyCode == Enum.KeyCode.R then requestEvent:Fire(player, "Inject") end
	end)

	local function tweenBar(fill, fraction)
		TweenService:Create(fill, TweenInfo.new(0.3), {Size = UDim2.fromScale(fraction, 1)}):Play()
	end

	local function updateUI()
		local n = player:GetAttribute("CyberNeural") or 0
		local c = player:GetAttribute("CyberCharges") or 10
		neuralValue.Text = string.format("%d%%", math.floor(n))
		dosesValue.Text = c .. "/10"
		neuralFill.BackgroundColor3 = n >= 80 and RED or CYAN
		tweenBar(neuralFill, n / 100) tweenBar(dosesFill, c / 10)
		for i, f in ipairs(doses) do
			TweenService:Create(f, TweenInfo.new(0.32), {Size = UDim2.fromScale(1, i <= c and 1 or 0)}):Play()
		end
		medical.Text = n >= 100 and "FALLO NEURAL" or n >= 80 and "ALERTA // SOBRECARGA" or "CONTROL NEURAL ACTIVO"
		medical.TextColor3 = n >= 80 and RED or GREEN
		stateLabel.Text = c <= 7 and "INTERFERENCIA NEURAL DETECTADA" or "ENLACE ACTIVO"
		stateLabel.TextColor3 = c <= 7 and RED or GREEN
		inject.Text = c > 0 and "INYECTAR  [-30%]  [R]" or "SIN CARGAS"
	end

	player:GetAttributeChangedSignal("CyberNeural"):Connect(updateUI)
	player:GetAttributeChangedSignal("CyberCharges"):Connect(updateUI)

	fxEvent.Event:Connect(function(event, who)
		if who ~= player then return end
		if event == "Inject" then
			greenFlash.BackgroundTransparency = 0.83
			TweenService:Create(greenFlash, TweenInfo.new(0.55), {BackgroundTransparency = 1}):Play()
		elseif event == "Stop" then player:SetAttribute("CyberLocalLift", 0) end
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local charges = player:GetAttribute("CyberCharges") or 10
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local severity = hum and hum.Health > 0 and charges <= 7 and (8 - charges) / 8 or 0
		local opacity = soft and severity * (0.04 + 0.08 * (0.5 + 0.5 * math.sin(t * 5))) or 0
		tint.BackgroundTransparency = 1 - opacity
		for i, line in ipairs(glitch) do
			line.BackgroundTransparency = soft and 1 - severity * 0.22 * math.max(0, math.sin(t * 3 + i * 2)) or 1
		end
		accumulator = accumulator + dt
		if accumulator < 0.1 then return end
		accumulator = 0
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			local scale = math.min(1, math.max(0.5, (size.X - 44) / 600), math.max(0.5, (size.Y - 190) / 236))
			scaleL.Scale = scale scaleR.Scale = scale
			bar.Size = UDim2.new(0, math.min(size.X - 24, 7 * 72 - 8), 0, 82)
		end
		local now = getNow()
		local mode = player:GetAttribute("CyberMode") or "Idle"
		lift.Visible = mode == "Flight"
		for action, b in pairs(buttons) do
			local leftTime = math.max(0, (player:GetAttribute("Cyber" .. action .. "Ready") or 0) - now)
			local status = leftTime > 0 and string.format("%.1fs", leftTime) or "LISTO"
			if action == "Dash" and leftTime <= 0 then status = (player:GetAttribute("CyberDashCharges") or 4) .. "/4" end
			if action == "Sandevistan" and (player:GetAttribute("CyberSandeEnd") or 0) > now then status = "ACTIVO" end
			if action == "Gravity" and mode ~= "Idle" and mode ~= "Flight" then status = mode == "Phase" and "CAER" or "IMPACTO" end
			if action == "Fly" and mode == "Flight" then status = "ATERRIZAR" end
			b.status.Text = status
		end
	end)
	player.CharacterAdded:Connect(function() player:SetAttribute("CyberLocalLift", 0) updateUI() end)
	updateUI()
end

-- ============================================================================
-- 4. MONTAJE DE MODELOS Y ARMADURA LOCAL
-- ============================================================================
local template = ReplicatedStorage:FindFirstChild("CyberSkeletonLocalTemplate")
local definitionsMount = {
	{name="BrazoDerecho", body="RightUpperArm", attachment="RightShoulderRigAttachment", reference=CFrame.new(-42.7411651611, 13.0881090164, -32.9585723877, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1), joint=CFrame.new(-0.297488451004, 0.348276019096, -0.00046993792057, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	{name="BrazoIzquierdo", body="LeftUpperArm", attachment="LeftShoulderRigAttachment", reference=CFrame.new(-44.5348587036, 13.0881090164, -32.9585723877, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1), joint=CFrame.new(0.297487974167, 0.348277688026, -0.000469859689474, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	{name="PiernaDerecha", body="RightUpperLeg", attachment="RightHipRigAttachment", reference=CFrame.new(-43.2571563721, 10.8071670532, -33.1414222717, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1), joint=CFrame.new(0.0251421928406, 0.71708124876, 0.00550221651793, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	{name="PiernaIzquierda", body="LeftUpperLeg", attachment="LeftHipRigAttachment", reference=CFrame.new(-44.018863678, 10.8071670532, -33.1414222717, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1), joint=CFrame.new(-0.0251417756081, 0.717080950737, 0.0055021494627, 1, 0, 0, 0, 1, 0, 0, 0, 1)}
}
local mounting = setmetatable({}, {__mode = "k"})

local function installSuit(targetPlayer, character)
	if not template then return end
	if mounting[character] or character:FindFirstChild("CyberSkeletonEquipado") then return end
	mounting[character] = true
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or humanoid.Health <= 0 then return end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return end

	local suit = Instance.new("Model")
	suit.Name = "CyberSkeletonEquipado"
	local lowest = 0

	for _, def in ipairs(definitionsMount) do
		local limb = character:WaitForChild(def.body, 5)
		local model = template:FindFirstChild(def.name)
		if limb and model then
			local attachment = limb:FindFirstChild(def.attachment)
			local attachmentCF = attachment and attachment.CFrame or def.joint
			local conversion = attachmentCF * def.joint:Inverse() * def.reference:Inverse()
			local copy = model:Clone()

			for _, item in ipairs(copy:GetDescendants()) do
				if item:IsA("JointInstance") or item:IsA("Constraint") or item:IsA("BodyMover") or item:IsA("LuaSourceContainer") then
					item:Destroy()
				end
			end

			for _, part in ipairs(copy:GetDescendants()) do
				if part:IsA("BasePart") then
					local offset = conversion * part.CFrame
					part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true
					part.CFrame = limb.CFrame * offset
					local weld = Instance.new("Weld")
					weld.Name = "UnionCyber"
					weld.Part0, weld.Part1, weld.C0, weld.C1 = limb, part, offset, CFrame.identity
					weld.Parent = part
				end
			end
			copy.Parent = suit
		end
	end

	local hidden = {LeftUpperArm=true, LeftLowerArm=true, LeftHand=true, RightUpperArm=true, RightLowerArm=true, RightHand=true, LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true, RightUpperLeg=true, RightLowerLeg=true, RightFoot=true}
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and hidden[part.Name] then
			part.Transparency = 1
			part.CanCollide = false
		end
	end
	suit.Parent = character
end

player.CharacterAdded:Connect(function(char) task.spawn(installSuit, player, char) end)
if player.Character then task.spawn(installSuit, player, player.Character) end

-- ============================================================================
-- 5. SANDEVISTAN Y EFECTOS VISUALES (ESTELAS / BLUR)
-- ============================================================================
local folder = workspace:FindFirstChild("CyberResiduosLocal") or Instance.new("Folder")
folder.Name = "CyberResiduosLocal"
folder.Parent = workspace

local colorCorr = Lighting:FindFirstChild("CyberSandeColorV2") or Instance.new("ColorCorrectionEffect")
colorCorr.Name = "CyberSandeColorV2" colorCorr.TintColor = Color3.fromRGB(180,240,255)
colorCorr.Contrast = 0.08 colorCorr.Saturation = -0.08 colorCorr.Enabled = false colorCorr.Parent = Lighting

local blur = Lighting:FindFirstChild("CyberDashBlurV2") or Instance.new("BlurEffect")
blur.Name = "CyberDashBlurV2" blur.Size = 0 blur.Parent = Lighting

local sequences = {}
local ghosts = {}
local flashEnd = 0

local function residue(who, offset, hue)
	local char = who.Character
	if not char then return end
	local model = Instance.new("Model")
	model.Name = "ResiduoRGB"
	local tint = Color3.fromHSV(hue % 1, 0.8, 1)
	local count = 0

	for _, source in ipairs(char:GetDescendants()) do
		if source:IsA("BasePart") and source.Transparency < 0.95 then
			local p = source:Clone()
			if p then
				for _, child in ipairs(p:GetChildren()) do
					if not child:IsA("DataModelMesh") then child:Destroy()
					elseif child:IsA("SpecialMesh") then child.TextureId = "" child.VertexColor = Vector3.one end
				end
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
				p.LocalTransparencyModifier, p.Transparency, p.Color, p.Material = 0, 0.48, tint, Enum.Material.Neon
				p.CFrame = offset * source.CFrame
				p.Parent = model
				TweenService:Create(p, TweenInfo.new(0.45), {Transparency = 1}):Play()
				count = count + 1
				if count >= 180 then break end
			end
		end
	end

	model.Parent = folder
	local outline = Instance.new("Highlight")
	outline.FillColor = tint outline.OutlineColor = tint
	outline.FillTransparency = 0.75 outline.OutlineTransparency = 0.15
	outline.DepthMode = Enum.HighlightDepthMode.Occluded outline.Parent = model
	TweenService:Create(outline, TweenInfo.new(0.45), {FillTransparency = 1, OutlineTransparency = 1}):Play()
	Debris:AddItem(model, 0.5)

	ghosts[who] = ghosts[who] or {}
	table.insert(ghosts[who], model)
	while #ghosts[who] > 4 do table.remove(ghosts[who], 1):Destroy() end
end

local function closeEnough(who)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	return root and camera and (root.Position - camera.CFrame.Position).Magnitude < 220
end

fxEvent.Event:Connect(function(event, who, data)
	if event == "Sande" then
		sequences[who] = {char = who.Character, start = os.clock(), duration = data.duration, count = 0}
	elseif event == "Dash" then
		if closeEnough(who) then
			local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
			if root then
				for i = 0, 3 do
					local pose = data.start:Lerp(data.finish, i / 4)
					residue(who, pose * root.CFrame:Inverse(), 0.45 + i * 0.08)
				end
			end
		end
		if who == player then flashEnd = os.clock() + 0.18 end
	elseif event == "Phase" then
		if closeEnough(who) then
			local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
			if root then
				for i = 1, 4 do
					local offset = root.CFrame.RightVector * ((i % 2 == 0 and 1 or -1) * i * 0.7)
					residue(who, CFrame.new(offset), 0.5 + i * 0.03)
				end
			end
		end
		if who == player then flashEnd = os.clock() + 0.25 end
	elseif event == "Stop" then
		sequences[who] = nil
		if ghosts[who] then for _, g in ipairs(ghosts[who]) do g:Destroy() end ghosts[who] = nil end
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for who, s in pairs(sequences) do
		local elapsed = t - s.start
		local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if not who.Parent or who.Character ~= s.char or not hum or hum.Health <= 0 or elapsed > s.duration + 0.1 then
			sequences[who] = nil
		elseif s.count < 24 and elapsed >= s.count * 0.12 then
			s.count = s.count + 1
			if closeEnough(who) then residue(who, CFrame.identity, s.count / 24) end
		end
	end
	local active = (player:GetAttribute("CyberSandeEnd") or 0) > getNow()
	colorCorr.Enabled = active or t < flashEnd
	blur.Size = t < flashEnd and 7 or 0
end)

Players.PlayerRemoving:Connect(function(who)
	sequences[who] = nil
	if ghosts[who] then for _, g in ipairs(ghosts[who]) do g:Destroy() end ghosts[who] = nil end
end)
