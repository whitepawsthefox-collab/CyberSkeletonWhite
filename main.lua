--[[
	CYBERSKELETON COMPLETO v3.3 - Versión Adaptada para Ejecutores (Delta)
	Autocontenido (Client-Only Direct Physics & Controls)
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local ASSET_ID = 78060347687239
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

-------------------------------------------------
-- 1. CONFIGURACIÓN Y RED LOCAL
-------------------------------------------------
local CONFIG = {
	NeuralPorSegundo = 1, NeuralPorAtaque = 6, Alivio = 30, Cargas = 10,
	AlturaGravity = 10, VelocidadAerea = 38, VelocidadCaida = 210,
	Advertencia = 3, RadioGravity = 45, RadioPulse = 38,
	SandeVelocidad = 100, SandeDuracion = 2.88,
	DashDistancia = 22, DashCargas = 4, DashRecarga = 7,
	VueloVelocidad = 44, VueloDuracion = 20,
}

local state = {
	neural = 0,
	charges = CONFIG.Cargas,
	dash = CONFIG.DashCargas,
	cooldowns = {},
	hidden = {},
	mode = "Idle",
	sandeEnd = 0,
	passive = 0,
	input = Vector3.zero,
	lastInput = 0,
	ownsMotion = false,
	oldAnchored = false,
	oldRotate = true,
	oldWalk = 16,
	warningEnd = 0,
	motionStart = 0,
	fallStart = 0,
	height = 0,
	hideAt = nil,
	hand = false
}

local function clock() return workspace:GetServerTimeNow() end

local function setAttr(name, value)
	player:SetAttribute("Cyber" .. name, value)
end

-------------------------------------------------
-- 2. CARGAR TEMPLATE DE MODELO
-------------------------------------------------
local template = RS:FindFirstChild("CyberSkeletonLocalTemplate")
if not template and ASSET_ID > 0 then
	pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. ASSET_ID)
		if objs and objs[1] then
			template = objs[1]
			template.Name = "CyberSkeletonLocalTemplate"
			template.Parent = RS
		end
	end)
end

-------------------------------------------------
-- 3. MONTAJE DE LA ARMADURA
-------------------------------------------------
local definitions = {
	{name="BrazoDerecho", body="RightUpperArm", attachment="RightShoulderRigAttachment",
		reference=CFrame.new(-42.7411651611, 13.0881090164, -32.9585723877, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1),
		joint=CFrame.new(-0.297488451004, 0.348276019096, -0.00046993792057, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	{name="BrazoIzquierdo", body="LeftUpperArm", attachment="LeftShoulderRigAttachment",
		reference=CFrame.new(-44.5348587036, 13.0881090164, -32.9585723877, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1),
		joint=CFrame.new(0.297487974167, 0.348277688026, -0.000469859689474, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	{name="PiernaDerecha", body="RightUpperLeg", attachment="RightHipRigAttachment",
		reference=CFrame.new(-43.2571563721, 10.8071670532, -33.1414222717, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1),
		joint=CFrame.new(0.0251421928406, 0.71708124876, 0.00550221651793, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	{name="PiernaIzquierda", body="LeftUpperLeg", attachment="LeftHipRigAttachment",
		reference=CFrame.new(-44.018863678, 10.8071670532, -33.1414222717, 1, 4.87890977618e-19, 0, 4.87890977618e-19, 1, 0, 0, 0, 1),
		joint=CFrame.new(-0.0251417756081, 0.717080950737, 0.0055021494627, 1, 0, 0, 0, 1, 0, 0, 0, 1)}
}

local function install(character)
	if not character or character:FindFirstChild("CyberSkeletonEquipado") then return end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or humanoid.Health <= 0 then return end

	if not template then
		warn("[Cyber] Modelo template no encontrado.")
		return
	end

	local suit = Instance.new("Model")
	suit.Name = "CyberSkeletonEquipado"
	local lowest = 0

	for _, def in ipairs(definitions) do
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
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					part.CFrame = limb.CFrame * offset

					local weld = Instance.new("Weld")
					weld.Name = "UnionCyber"
					weld.Part0 = limb
					weld.Part1 = part
					weld.C0 = offset
					weld.C1 = CFrame.identity
					weld.Parent = part

					if string.find(def.name, "Pierna") then
						local relative = root.CFrame:ToObjectSpace(part.CFrame)
						for x = -1, 1, 2 do
							for y = -1, 1, 2 do
								for z = -1, 1, 2 do
									local corner = relative:PointToWorldSpace(part.Size * Vector3.new(x,y,z) / 2)
									lowest = math.min(lowest, corner.Y)
								end
							end
						end
					end
				end
			end
			copy.Parent = suit
		end
	end

	local hidden = {
		LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
		RightUpperArm=true, RightLowerArm=true, RightHand=true,
		LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
		RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
	}
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and hidden[part.Name] then
			part.Transparency = 1
		end
	end

	suit.Parent = character
	print("[Cyber] Cyberskeleton montado correctamente")
end

-------------------------------------------------
-- 4. EFECTOS VISUALES & RENDERIZADO
-------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "CyberVisualLocal"
folder.Parent = workspace

local rings = {}
local sequences = {}
local flashEnd = 0

local function createPart(parent, color, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Parent = parent
	return p
end

local function discardRing()
	if rings[player] then
		rings[player].folder:Destroy()
		rings[player] = nil
	end
end

local function warningVisual(data)
	discardRing()
	local f = Instance.new("Folder")
	f.Name = "Caution"
	f.Parent = folder
	local pieces = {}
	for layer = 1, 2 do
		local count = layer == 1 and 64 or 40
		for i = 1, count do
			local p = createPart(f, layer == 1 and Color3.fromRGB(255,45,35) or Color3.fromRGB(255,160,90),
				Vector3.new(layer == 1 and 3.4 or 2.5, 0.12, layer == 1 and 0.75 or 0.18))
			table.insert(pieces, {p = p, angle = i/count * math.pi * 2, layer = layer})
		end
	end
	local anchor = createPart(f, Color3.new(1,0,0), Vector3.one)
	anchor.Transparency = 1
	anchor.Position = data.position + Vector3.new(0, 5, 0)

	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(320, 104)
	board.AlwaysOnTop = false
	board.MaxDistance = 220
	board.Parent = anchor

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.65)
	title.BackgroundTransparency = 1
	title.Text = "⚠ CAUTION"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255,70,45)
	title.TextStrokeTransparency = 0.4
	title.Parent = board

	local subtitle = title:Clone()
	subtitle.Size = UDim2.fromScale(1, 0.3)
	subtitle.Position = UDim2.fromScale(0, 0.67)
	subtitle.Text = "GRAVITATIONAL FIELD // IMPACT IMMINENT"
	subtitle.Parent = board

	rings[player] = {
		folder = f, pieces = pieces, start = os.clock(),
		duration = data.duration, center = data.position + Vector3.new(0,0.2,0),
		radius = data.radius, title = title, subtitle = subtitle
	}
end

local function impactVisual(data)
	local f = Instance.new("Folder")
	f.Name = "Escombros"
	f.Parent = folder
	for i = 1, 48 do
		local a = i/48 * math.pi * 2
		local p = createPart(f, Color3.fromRGB(255,95,65), Vector3.new(3, 0.12, 0.4))
		p.CFrame = CFrame.new(data.position + Vector3.new(math.cos(a)*4, 0.3, math.sin(a)*4)) * CFrame.Angles(0, -a, 0)
		TweenService:Create(p, TweenInfo.new(0.55), {
			Position = data.position + Vector3.new(math.cos(a)*data.radius, 0.3, math.sin(a)*data.radius),
			Transparency = 1
		}):Play()
	end
	Debris:AddItem(f, 1.1)
end

local function pulseVisual(data)
	local f = Instance.new("Folder")
	f.Name = "Pulse"
	f.Parent = folder
	for i = 1, 3 do
		local ring = createPart(f, Color3.fromRGB(255, 80, 60), Vector3.new(1, 0.15, 1))
		ring.CFrame = CFrame.new(data.position + Vector3.new(0, 0.5, 0))
		TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(data.radius * 2, 0.1, data.radius * 2),
			Transparency = 1
		}):Play()
	end
	Debris:AddItem(f, 0.7)
end

local function attractionVisual(data)
	local f = Instance.new("Folder")
	f.Name = "Attraction"
	f.Parent = folder
	for i = 1, 12 do
		local a = i/12 * math.pi * 2
		local p = createPart(f, Color3.fromRGB(180, 60, 255), Vector3.new(0.4, 0.4, 0.4))
		p.CFrame = CFrame.new(data.position + Vector3.new(math.cos(a)*8, 1, math.sin(a)*8))
		TweenService:Create(p, TweenInfo.new(0.8), {
			Position = data.position + Vector3.new(0, 1, 0),
			Transparency = 1
		}):Play()
	end
	Debris:AddItem(f, 1)
end

local function punchVisual(data)
	local f = Instance.new("Folder")
	f.Name = "Punch"
	f.Parent = folder
	local p = createPart(f, Color3.fromRGB(255, 120, 50), Vector3.new(3, 3, 1))
	p.CFrame = CFrame.new(data.position)
	TweenService:Create(p, TweenInfo.new(0.25), {
		Size = Vector3.new(6, 6, 0.2),
		Transparency = 1
	}):Play()
	Debris:AddItem(f, 0.3)
end

local function residue(offset, hue)
	local char = player.Character
	if not char then return end
	local model = Instance.new("Model")
	model.Name = "Residuo"
	local tint = Color3.fromHSV(hue % 1, 0.8, 1)
	local count = 0
	for _, source in ipairs(char:GetDescendants()) do
		if source:IsA("BasePart") and source.Transparency < 0.95 then
			local p = source:Clone()
			for _, child in ipairs(p:GetChildren()) do
				if not child:IsA("DataModelMesh") then child:Destroy() end
			end
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Transparency = 0.48
			p.Color = tint
			p.Material = Enum.Material.Neon
			p.CFrame = offset * source.CFrame
			p.Parent = model
			TweenService:Create(p, TweenInfo.new(0.45), {Transparency = 1}):Play()
			count = count + 1
			if count >= 100 then break end
		end
	end
	model.Parent = folder
	Debris:AddItem(model, 0.5)
end

-- Post-Procesado Visual
local color = Instance.new("ColorCorrectionEffect")
color.Name = "CyberSandeColor"
color.TintColor = Color3.fromRGB(180, 240, 255)
color.Contrast = 0.08
color.Saturation = -0.08
color.Enabled = false
color.Parent = Lighting

local blur = Instance.new("BlurEffect")
blur.Name = "CyberDashBlur"
blur.Size = 0
blur.Parent = Lighting

-------------------------------------------------
-- 5. LÓGICA DE CONTROL Y HABILIDADES
-------------------------------------------------
local function getChar()
	local c = player.Character
	if c then
		local h = c:FindFirstChildOfClass("Humanoid")
		local r = c:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 then
			return c, h, r
		end
	end
	return nil, nil, nil
end

local function getParams(char)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = {char}
	p.RespectCanCollide = true
	return p
end

local function getGroundPos(char, root, hum)
	local hit = workspace:Raycast(root.Position, Vector3.new(0,-600,0), getParams(char))
	return hit and hit.Position or root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
end

local function setVisibility(char, show)
	if show then
		for part, val in pairs(state.hidden) do
			if part.Parent then part.Transparency = val end
		end
		table.clear(state.hidden)
	else
		for _, part in ipairs(char:GetDescendants()) do
			if (part:IsA("BasePart") or part:IsA("Decal")) and state.hidden[part] == nil then
				state.hidden[part] = part.Transparency
				part.Transparency = 1
			end
		end
	end
end

local function setMode(m)
	state.mode = m
	setAttr("Mode", m)
end

local function finishMotion()
	local char, hum, root = getChar()
	if char then setVisibility(char, true) end
	if state.ownsMotion then
		if root then root.Anchored = state.oldAnchored end
		if hum then
			hum.AutoRotate = state.oldRotate
			hum.WalkSpeed = state.oldWalk
		end
		state.ownsMotion = false
	end
	state.input = Vector3.zero
	setMode("Idle")
end

local function startMotion(m)
	local char, hum, root = getChar()
	if not char or root.Anchored or state.ownsMotion then return false end
	state.oldAnchored, state.oldRotate, state.oldWalk = root.Anchored, hum.AutoRotate, hum.WalkSpeed
	state.ownsMotion = true
	root.Anchored = true
	hum.AutoRotate = false
	hum.WalkSpeed = 0
	root.AssemblyLinearVelocity = Vector3.zero
	state.motionStart = clock()
	state.lastInput = 0
	setMode(m)
	return true
end

local function moveChar(delta)
	local char, hum, root = getChar()
	if not char or delta.Magnitude < 0.00001 then return nil end
	local distance = hum.HipHeight + root.Size.Y / 2
	local size = Vector3.new(2.5, math.max(2, distance + 1.5), 2.5)
	local cf = root.CFrame * CFrame.new(0, (1.5 - distance)/2, 0)
	local hit = workspace:Blockcast(cf, size - Vector3.new(0.1,0.1,0.1), delta, getParams(char))
	local travel = delta
	if hit then travel = delta.Unit * math.max(0, hit.Distance - 0.12) end
	char:PivotTo(char:GetPivot() + travel)
	return hit
end

local function addNeural(amount)
	local char, hum = getChar()
	state.neural = math.clamp(state.neural + amount, 0, 100)
	setAttr("Neural", state.neural)
	if state.neural >= 100 and hum then
		finishMotion()
		hum.Health = 0
		return false
	end
	return true
end

local function setCooldown(key, seconds)
	state.cooldowns[key] = clock() + seconds
	setAttr(key .. "Ready", state.cooldowns[key])
end

local function isReady(key)
	return clock() >= (state.cooldowns[key] or 0)
end

local function warningState()
	local char, hum, root = getChar()
	if not char then return end
	setVisibility(char, true)
	setMode("Warning")
	state.warningEnd = clock() + CONFIG.Advertencia
	setAttr("WarningEnd", state.warningEnd)
	warningVisual({position = getGroundPos(char, root, hum), duration = CONFIG.Advertencia, radius = CONFIG.RadioGravity})
end

-- Habilidades
local actions = {}
function actions.Inject()
	if state.charges <= 0 or not isReady("Inject") then return end
	state.charges = state.charges - 1
	setAttr("Charges", state.charges)
	addNeural(-CONFIG.Alivio)
	setCooldown("Inject", 0.65)
end

function actions.Gravity()
	local char, hum, root = getChar()
	if not char then return end
	if state.mode == "Phase" then warningState() return end
	if state.mode ~= "Idle" or state.sandeEnd > clock() or not isReady("Gravity") or root.Anchored then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end
	if startMotion("Phase") then
		state.height = root.Position.Y + CONFIG.AlturaGravity
		state.hideAt = clock() + 0.32
		flashEnd = clock() + 0.25
	end
end

function actions.Fly()
	local char, hum, root = getChar()
	if not char then return end
	if state.mode == "Flight" then finishMotion() setCooldown("Fly", 4) return end
	if state.mode ~= "Idle" or state.sandeEnd > clock() or not isReady("Fly") or root.Anchored then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end
	startMotion("Flight")
end

function actions.Sandevistan()
	local char, hum = getChar()
	if not char or state.mode ~= "Idle" or state.sandeEnd > clock() or not isReady("Sandevistan") then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end
	state.sandeEnd = clock() + CONFIG.SandeDuracion
	setAttr("SandeEnd", state.sandeEnd)
	hum.WalkSpeed = CONFIG.SandeVelocidad
	setCooldown("Sandevistan", CONFIG.SandeDuracion + 7)
	sequences[player] = {char = char, start = clock(), duration = CONFIG.SandeDuracion, count = 0}
end

function actions.Dash()
	local char, hum, root = getChar()
	if not char or state.mode ~= "Idle" or state.dash <= 0 or not isReady("DashTap") or root.Anchored then return end
	local dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if dir.Magnitude < 0.1 then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end

	state.dash = state.dash - 1
	setAttr("DashCharges", state.dash)
	setCooldown("DashTap", 0.3)
	if state.dash == 0 then setCooldown("Dash", CONFIG.DashRecarga) end

	flashEnd = clock() + 0.18
	local startCF = root.CFrame
	moveChar(dir.Unit * CONFIG.DashDistancia)

	for i = 0, 3 do
		local pose = startCF:Lerp(root.CFrame, i/4)
		residue(pose * root.CFrame:Inverse(), 0.45 + i * 0.08)
	end
end

function actions.Pulse()
	local char, hum, root = getChar()
	if not char or state.mode ~= "Idle" or not isReady("Pulse") then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Pulse", 7)
	pulseVisual({position = getGroundPos(char, root, hum), radius = CONFIG.RadioPulse})
end

function actions.Atraction()
	local char, hum, root = getChar()
	if not char or state.mode ~= "Idle" or not isReady("Atraction") then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Atraction", 9)
	attractionVisual({position = root.Position, duration = 1.5, radius = 32})
end

function actions.Punch()
	local char, hum, root = getChar()
	if not char or state.mode ~= "Idle" or not isReady("Punch") then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Punch", 0.7)
	state.hand = not state.hand
	punchVisual({position = root.Position + root.CFrame.LookVector * 4})
end

local function executeAction(actName)
	if actions[actName] then
		actions[actName]()
	end
end

-------------------------------------------------
-- 6. CICLO DE EJECUCIÓN (HEARTBEAT Y RENDERSTEPPED)
-------------------------------------------------
player.CharacterAdded:Connect(function(char)
	finishMotion()
	task.spawn(install, char)
	setAttr("Neural", 0)
	setAttr("Charges", CONFIG.Cargas)
	setAttr("DashCharges", CONFIG.DashCargas)
	setAttr("SandeEnd", 0)
	setAttr("Mode", "Idle")
	setAttr("WarningEnd", 0)
	state.neural = 0
	state.charges = CONFIG.Cargas
	state.dash = CONFIG.DashCargas
	state.sandeEnd = 0
end)

if player.Character then task.spawn(install, player.Character) end

RunService.Heartbeat:Connect(function(dt)
	local now = clock()
	local char, hum, root = getChar()

	if char and hum and root then
		state.passive = state.passive + dt
		if state.passive >= 1 then
			local ticks = math.floor(state.passive)
			state.passive = state.passive - ticks
			addNeural(CONFIG.NeuralPorSegundo * ticks)
		end

		if state.dash < CONFIG.DashCargas and isReady("Dash") then
			state.dash = CONFIG.DashCargas
			setAttr("DashCharges", state.dash)
		end

		if state.sandeEnd > 0 and now >= state.sandeEnd then
			hum.WalkSpeed = state.oldWalk
			state.sandeEnd = 0
			setAttr("SandeEnd", 0)
		end

		local input = (now - state.lastInput <= 0.5) and state.input or Vector3.zero
		local step = math.min(dt, 0.1)

		if state.mode == "Phase" then
			if state.hideAt and now >= state.hideAt then setVisibility(char, false) state.hideAt = nil end
			moveChar(Vector3.new(input.X, 0, input.Z) * CONFIG.VelocidadAerea * step)
			moveChar(Vector3.new(0, math.clamp(state.height - root.Position.Y, -20*step, 20*step), 0))
			if now - state.motionStart >= 30 then warningState() end

		elseif state.mode == "Warning" and now >= state.warningEnd then
			setMode("Falling")
			state.fallStart = now

		elseif state.mode == "Falling" then
			local hit = moveChar(Vector3.new(0, -CONFIG.VelocidadCaida * step, 0))
			if hit then
				finishMotion()
				root.AssemblyLinearVelocity = Vector3.zero
				setCooldown("Gravity", 5)
				impactVisual({position = getGroundPos(char, root, hum), radius = CONFIG.RadioGravity})
			elseif now - state.fallStart > 3 then
				finishMotion()
				setCooldown("Gravity", 5)
			end

		elseif state.mode == "Flight" then
			moveChar(input * CONFIG.VueloVelocidad * step)
			if now - state.motionStart >= CONFIG.VueloDuracion then
				finishMotion()
				setCooldown("Fly", 4)
			end
		end
	else
		if state.ownsMotion then finishMotion() end
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()

	for who, r in pairs(rings) do
		local elapsed = t - r.start
		if elapsed >= r.duration then
			discardRing()
		else
			local scale = 1 - (1 - math.clamp(elapsed / 0.55, 0, 1))^3
			local flicker = 0.12 + 0.35 * (0.5 + 0.5 * math.sin(t * 10))
			r.title.TextTransparency = flicker
			r.subtitle.TextTransparency = flicker
			for _, item in ipairs(r.pieces) do
				local angle = item.angle + elapsed * (item.layer == 1 and 1.25 or -0.8)
				local radius = r.radius * (item.layer == 1 and 1 or 0.8) * scale
				item.p.CFrame = CFrame.new(r.center + Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)) * CFrame.Angles(0, -angle + 0.6, 0)
				item.p.Transparency = flicker
			end
		end
	end

	for who, s in pairs(sequences) do
		local elapsed = t - s.start
		if elapsed > s.duration + 0.1 then
			sequences[who] = nil
		elseif s.count < 24 and elapsed >= s.count * 0.12 then
			s.count = s.count + 1
			residue(CFrame.identity, s.count / 24)
		end
	end

	local active = state.sandeEnd > clock()
	color.Enabled = active or t < flashEnd
	blur.Size = t < flashEnd and 7 or 0

	-- Lógica de Movimiento & Teclas de Vuelo
	local char, hum, root = getChar()
	if hum and (state.mode == "Phase" or state.mode == "Flight") then
		local direction = hum.MoveDirection
		local vertical = 0
		if state.mode == "Flight" and not UIS:GetFocusedTextBox() then
			vertical = player:GetAttribute("CyberLocalLift") or 0
			if UIS:IsKeyDown(Enum.KeyCode.E) then
				vertical = 1
			elseif UIS:IsKeyDown(Enum.KeyCode.Q) then
				vertical = -1
			end
		end
		local moveVec = Vector3.new(direction.X, vertical, direction.Z)
		if state.mode == "Phase" then moveVec = Vector3.new(moveVec.X, 0, moveVec.Z) end
		state.input = moveVec.Magnitude > 1 and moveVec.Unit or moveVec
		state.lastInput = clock()
	end
end)

-------------------------------------------------
-- 7. INTERFAZ HUD & BOTONES PARA MÓVIL/PC
-------------------------------------------------
local guiParent = player:WaitForChild("PlayerGui")
if guiParent:FindFirstChild("CyberHUDv2") then
	guiParent.CyberHUDv2:Destroy()
end

local CYAN = Color3.fromRGB(70, 225, 255)
local RED = Color3.fromRGB(255, 65, 85)
local GREEN = Color3.fromRGB(65, 255, 150)

local function create(class, parent, props)
	local item = Instance.new(class)
	for k, v in pairs(props or {}) do item[k] = v end
	item.Parent = parent
	return item
end

local function round(item, radius)
	create("UICorner", item, {CornerRadius = UDim.new(0, radius)})
end

local gui = create("ScreenGui", guiParent, {
	Name = "CyberHUDv2",
	ResetOnSpawn = false,
	DisplayOrder = 15,
	IgnoreGuiInset = false
})

local bar = create("ScrollingFrame", gui, {
	Name = "Habilidades",
	Position = UDim2.new(0.5, 0, 0, 4),
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(1, -24, 0, 82),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 2,
	BackgroundTransparency = 1
})

create("UIListLayout", bar, {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder
})

local definitionsUI = {
	{"Sandevistan", "SANDE", Enum.KeyCode.One, CYAN},
	{"Gravity", "GRAVITY", Enum.KeyCode.Two, RED},
	{"Pulse", "PULSE", Enum.KeyCode.Three, RED},
	{"Atraction", "ATRACTION", Enum.KeyCode.Four, RED},
	{"Dash", "DASH", Enum.KeyCode.Five, CYAN},
	{"Punch", "GOLPE", Enum.KeyCode.Six, RED},
	{"Fly", "VUELO", Enum.KeyCode.Seven, CYAN},
}

local buttons = {}
for i, def in ipairs(definitionsUI) do
	local cell = create("Frame", bar, {
		Size = UDim2.fromOffset(64, 78),
		BackgroundTransparency = 1,
		LayoutOrder = i
	})
	local b = create("TextButton", cell, {
		Name = def[1],
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(2, 0),
		BackgroundColor3 = Color3.fromRGB(12, 28, 38),
		Text = def[2],
		TextSize = 10,
		Font = Enum.Font.GothamBlack,
		TextColor3 = def[4],
		BorderSizePixel = 0
	})
	create("UICorner", b, {CornerRadius = UDim.new(1, 0)})
	create("UIStroke", b, {Color = def[4], Transparency = 0.25, Thickness = 1.5})
	local status = create("TextLabel", cell, {
		Text = "[" .. i .. "]",
		Position = UDim2.fromOffset(0, 61),
		Size = UDim2.fromOffset(64, 16),
		BackgroundTransparency = 1,
		TextColor3 = def[4],
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center
	})
	b.Activated:Connect(function()
		executeAction(def[1])
	end)
	buttons[def[1]] = {button = b, status = status}
end

-- BOTONES DE VUELO (SUBIR / BAJAR)
local lift = create("Frame", gui, {
	Position = UDim2.new(0.5, 0, 0, 90),
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(132, 44),
	BackgroundTransparency = 1,
	Visible = false
})

local held = {}
for i, item in ipairs({{"SUBIR", 1}, {"BAJAR", -1}}) do
	local b = create("TextButton", lift, {
		Position = UDim2.fromOffset((i-1)*68, 0),
		Size = UDim2.fromOffset(64, 44),
		Text = item[1],
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextColor3 = CYAN,
		BackgroundColor3 = Color3.fromRGB(10, 35, 45),
		BorderSizePixel = 0
	})
	round(b, 10)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			held[input] = item[2]
			player:SetAttribute("CyberLocalLift", item[2])
		end
	end)
end

UIS.InputEnded:Connect(function(input)
	if held[input] then
		held[input] = nil
		player:SetAttribute("CyberLocalLift", 0)
	end
end)

UIS.WindowFocusReleased:Connect(function()
	table.clear(held)
	player:SetAttribute("CyberLocalLift", 0)
end)

-- Panel Izquierdo
local left = create("Frame", gui, {
	Name = "Sistema",
	Size = UDim2.fromOffset(240, 236),
	Position = UDim2.new(0, 12, 0, 94),
	BackgroundColor3 = Color3.fromRGB(6, 19, 26),
	BackgroundTransparency = 0.13,
	BorderSizePixel = 0
})
round(left, 9)
create("UIStroke", left, {Color = CYAN, Thickness = 1.4, Transparency = 0.2})

create("TextLabel", left, {
	Text = "CYBERSKELETON // LINK",
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.fromOffset(216, 20),
	BackgroundTransparency = 1,
	TextColor3 = CYAN,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left
})

create("TextLabel", left, {
	Text = "PROTOTYPE 07 / ONLINE",
	Position = UDim2.fromOffset(12, 32),
	Size = UDim2.fromOffset(216, 15),
	BackgroundTransparency = 1,
	TextColor3 = CYAN,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left
})

local function meter(parent, title, y, color)
	create("TextLabel", parent, {
		Text = title,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.fromOffset(165, 18),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(195, 228, 235),
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local value = create("TextLabel", parent, {
		Text = "",
		Position = UDim2.fromOffset(174, y),
		Size = UDim2.fromOffset(54, 18),
		BackgroundTransparency = 1,
		TextColor3 = color,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right
	})
	local back = create("Frame", parent, {
		Position = UDim2.fromOffset(12, y + 21),
		Size = UDim2.fromOffset(216, 13),
		BackgroundColor3 = Color3.fromRGB(23, 42, 50),
		BorderSizePixel = 0,
		ClipsDescendants = true
	})
	round(back, 5)
	local fill = create("Frame", back, {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0
	})
	round(fill, 5)
	return value, fill
end

local cap, capFill = meter(left, "CYBERWARE CAPACITY", 58, RED)
cap.Text = "177/200"
capFill.Size = UDim2.fromScale(177/200, 1)

local progress, progressFill = meter(left, "CYBERSKELETON PROGRESS", 105, CYAN)
progress.Text = "100%"
progressFill.Size = UDim2.fromScale(1, 1)

create("TextLabel", left, {
	Text = "IMMUNOSUPPRESSANT RESERVES",
	Position = UDim2.fromOffset(12, 152),
	Size = UDim2.fromOffset(216, 17),
	BackgroundTransparency = 1,
	TextColor3 = GREEN,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left
})

local doses = {}
for i = 1, 10 do
	local back = create("Frame", left, {
		Position = UDim2.fromOffset(12 + (i-1)*22, 176),
		Size = UDim2.fromOffset(18, 31),
		BackgroundColor3 = Color3.fromRGB(30, 48, 42),
		BorderSizePixel = 0,
		ClipsDescendants = true
	})
	round(back, 3)
	doses[i] = create("Frame", back, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0
	})
end

local stateLabel = create("TextLabel", left, {
	Text = "ENLACE ACTIVO",
	Position = UDim2.fromOffset(12, 214),
	Size = UDim2.fromOffset(216, 15),
	BackgroundTransparency = 1,
	TextColor3 = GREEN,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left
})

-- Panel Derecho
local right = create("Frame", gui, {
	Name = "Biomonitor",
	Size = UDim2.fromOffset(240, 236),
	Position = UDim2.new(1, -12, 0, 94),
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(6, 19, 26),
	BackgroundTransparency = 0.13,
	BorderSizePixel = 0
})
round(right, 9)
create("UIStroke", right, {Color = RED, Thickness = 1.4, Transparency = 0.2})

create("TextLabel", right, {
	Text = "BIOMONITOR",
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.fromOffset(216, 20),
	BackgroundTransparency = 1,
	TextColor3 = RED,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left
})

local medical = create("TextLabel", right, {
	Text = "CONTROL NEURAL ACTIVO",
	Position = UDim2.fromOffset(12, 32),
	Size = UDim2.fromOffset(216, 15),
	BackgroundTransparency = 1,
	TextColor3 = GREEN,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left
})

local dosesValue, dosesFill = meter(right, "IMMUNOSUPPRESSANTS", 58, GREEN)
local neuralValue, neuralFill = meter(right, "NEURAL LOAD", 105, CYAN)

local inject = create("TextButton", right, {
	Name = "Inyectar",
	Position = UDim2.fromOffset(12, 156),
	Size = UDim2.fromOffset(216, 42),
	Text = "INYECTAR [-30%] [R]",
	TextColor3 = GREEN,
	TextSize = 13,
	Font = Enum.Font.GothamBlack,
	BackgroundColor3 = Color3.fromRGB(15, 60, 40),
	BorderSizePixel = 0
})
round(inject, 9)
inject.Activated:Connect(function()
	executeAction("Inject")
end)

-- Teclado
UIS.InputBegan:Connect(function(input, processed)
	if processed or UIS:GetFocusedTextBox() then return end
	for _, def in ipairs(definitionsUI) do
		if input.KeyCode == def[3] then
			executeAction(def[1])
			return
		end
	end
	if input.KeyCode == Enum.KeyCode.R then
		executeAction("Inject")
	end
end)

-- Actualizar Interfaz
local function updateUI()
	local n = state.neural
	local c = state.charges
	neuralValue.Text = string.format("%d%%", math.floor(n))
	dosesValue.Text = c .. "/10"
	neuralFill.BackgroundColor3 = n >= 80 and RED or CYAN
	TweenService:Create(neuralFill, TweenInfo.new(0.3), {Size = UDim2.fromScale(n/100, 1)}):Play()
	TweenService:Create(dosesFill, TweenInfo.new(0.3), {Size = UDim2.fromScale(c/10, 1)}):Play()
	for i, f in ipairs(doses) do
		TweenService:Create(f, TweenInfo.new(0.32), {Size = UDim2.fromScale(1, i <= c and 1 or 0)}):Play()
	end
	medical.Text = n >= 100 and "FALLO NEURAL" or n >= 80 and "ALERTA // SOBRECARGA" or "CONTROL NEURAL ACTIVO"
	medical.TextColor3 = n >= 80 and RED or GREEN
	stateLabel.Text = c <= 7 and "INTERFERENCIA NEURAL DETECTADA" or "ENLACE ACTIVO"
	stateLabel.TextColor3 = c <= 7 and RED or GREEN
	inject.Text = c > 0 and "INYECTAR [-30%] [R]" or "SIN CARGAS"
end

player:GetAttributeChangedSignal("CyberNeural"):Connect(updateUI)
player:GetAttributeChangedSignal("CyberCharges"):Connect(updateUI)
updateUI()

RunService.RenderStepped:Connect(function()
	local now = clock()
	local mode = state.mode
	lift.Visible = (mode == "Flight")
	for action, b in pairs(buttons) do
		local leftTime = math.max(0, (state.cooldowns[action] or 0) - now)
		local statusText = leftTime > 0 and string.format("%.1fs", leftTime) or "LISTO"
		if action == "Dash" and leftTime <= 0 then
			statusText = state.dash .. "/4"
		end
		if action == "Sandevistan" and state.sandeEnd > now then
			statusText = "ACTIVO"
		end
		if action == "Gravity" and mode ~= "Idle" and mode ~= "Flight" then
			statusText = mode == "Phase" and "CAER" or "IMPACTO"
		end
		if action == "Fly" and mode == "Flight" then
			statusText = "ATERRIZAR"
		end
		b.status.Text = statusText
	end
end)

print("[Cyber] Sistema Delta Autocontenido Cargado ✓")
