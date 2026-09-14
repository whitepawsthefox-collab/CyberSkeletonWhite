--[[
	CYBERSKELETON COMPLETO v3 - Todo en uno (FINAL)
	Incluye: Montaje + Control + Efectos + Interfaz completa + Botones de vuelo
]]
local ASSET_ID = 78060347687239 -- ←←← PON AQUÍ EL ASSET ID DE TU MODELO
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

-------------------------------------------------
-- 1. RED LOCAL
-------------------------------------------------
local network = RS:FindFirstChild("CyberV2Local")
if not network then
	network = Instance.new("Folder")
	network.Name = "CyberV2Local"
	network.Parent = RS
end
local request = network:FindFirstChild("Request") or Instance.new("BindableEvent")
request.Name = "Request"
request.Parent = network
local fx = network:FindFirstChild("FX") or Instance.new("BindableEvent")
fx.Name = "FX"
fx.Parent = network
print("[Cyber] Red lista")

-------------------------------------------------
-- 2. CARGAR TEMPLATE
-------------------------------------------------
local template = RS:FindFirstChild("CyberSkeletonLocalTemplate")
if not template and ASSET_ID > 0 then
	local success, result = pcall(function()
		return game:GetObjects("rbxassetid://" .. ASSET_ID)
	end)
	if success and result and result[1] then
		template = result[1]
		template.Name = "CyberSkeletonLocalTemplate"
		template.Parent = RS
		print("[Cyber] Modelo cargado desde Asset ID")
	end
end
if not template then
	template = RS:WaitForChild("CyberSkeletonLocalTemplate", 6)
end
if not template then
	warn("[Cyber] No se encontró el modelo. Pon el Asset ID correcto.")
	return
end

-------------------------------------------------
-- 3. MONTAJE
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
local mounting = setmetatable({}, {__mode = "k"})
local function install(character)
	if mounting[character] or character:FindFirstChild("CyberSkeletonEquipado") then return end
	mounting[character] = true
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or humanoid.Health <= 0 then return end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn("[Cyber] Solo R15")
		return
	end
	local deadline = os.clock() + 5
	while player.Character == character and not player:HasAppearanceLoaded() and os.clock() < deadline do
		task.wait(0.1)
	end
	if player.Character ~= character or humanoid.Health <= 0 then return end
	local suit = Instance.new("Model")
	suit.Name = "CyberSkeletonEquipado"
	local lowest = 0
	for _, def in ipairs(definitions) do
		local limb = character:WaitForChild(def.body, 5)
		local model = template:FindFirstChild(def.name)
		if not limb or not model then
			suit:Destroy()
			warn("[Cyber] Falta:", def.name)
			return
		end
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
	local distance = math.max(3, -lowest)
	local support = Instance.new("Part")
	support.Name = "SoporteColision"
	support.Size = Vector3.new(2, math.max(1, distance - 1), 2)
	support.Transparency = 1
	support.Anchored = false
	support.Massless = true
	support.CanCollide = true
	support.CanTouch = false
	support.CanQuery = false
	support.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.25, 0, 100, 100)
	local offset = CFrame.new(0, -distance + support.Size.Y / 2, 0)
	support.CFrame = root.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = root, support, offset
	weld.Parent = support
	support.Parent = suit
	local function noSelfCollision(part)
		if not part:IsA("BasePart") or part:IsDescendantOf(suit) then return end
		local c = Instance.new("NoCollisionConstraint")
		c.Part0, c.Part1 = support, part
		c.Parent = support
	end
	for _, part in ipairs(character:GetDescendants()) do noSelfCollision(part) end
	local conn = character.DescendantAdded:Connect(noSelfCollision)
	suit.Destroying:Connect(function() conn:Disconnect() end)
	local hidden = {
		LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
		RightUpperArm=true, RightLowerArm=true, RightHand=true,
		LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
		RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
	}
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and hidden[part.Name] then
			part.Transparency = 1
			part.CanCollide = false
		end
	end
	local previous = humanoid.HipHeight
	humanoid.HipHeight = math.max(0, distance - root.Size.Y / 2 + 0.15)
	character:PivotTo(character:GetPivot() + Vector3.new(0, math.max(0, humanoid.HipHeight - previous), 0))
	for _, item in ipairs(suit:GetDescendants()) do
		if item:IsA("Weld") then
			item.Part1.CFrame = item.Part0.CFrame * item.C0
		end
	end
	suit.Parent = character
	print("[Cyber] Cyberskeleton montado")
end
player.CharacterAdded:Connect(function(char) task.spawn(install, char) end)
if player.Character then task.spawn(install, player.Character) end

-------------------------------------------------
-- 4. CONTROL DE HABILIDADES
-------------------------------------------------
local CONFIG = {
	NeuralPorSegundo = 1, NeuralPorAtaque = 6, Alivio = 30, Cargas = 10,
	AlturaGravity = 10, VelocidadAerea = 38, VelocidadCaida = 210,
	Advertencia = 3, RadioGravity = 45, RadioPulse = 38,
	SandeVelocidad = 100, SandeDuracion = 2.88,
	DashDistancia = 22, DashCargas = 4, DashRecarga = 7,
	VueloVelocidad = 44, VueloDuracion = 20,
}
local states = {}
local function clock() return workspace:GetServerTimeNow() end
local function attr(s, name, value) s.player:SetAttribute("Cyber" .. name, value) end
local function emit(s, name, data) fx:Fire(name, s.player, data or {}) end
local function available(s)
	return s and s.root and s.root.Parent and s.hum.Health > 0
	and s.player.Character == s.char and s.char:FindFirstChild("CyberSkeletonEquipado")
end
local function params(s)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = {s.char}
	p.RespectCanCollide = true
	return p
end
local function footDistance(s) return s.hum.HipHeight + s.root.Size.Y / 2 end
local function ground(s)
	local hit = workspace:Raycast(s.root.Position, Vector3.new(0,-600,0), params(s))
	return hit and hit.Position or s.root.Position - Vector3.new(0,footDistance(s),0)
end
local function visible(s, show)
	if show then
		for part, value in pairs(s.hidden) do
			if part.Parent then part.Transparency = value end
		end
		table.clear(s.hidden)
	else
		for _, part in ipairs(s.char:GetDescendants()) do
			if (part:IsA("BasePart") or part:IsA("Decal")) and s.hidden[part] == nil then
				s.hidden[part] = part.Transparency
				part.Transparency = 1
			end
		end
	end
end
local function mode(s, value)
	s.mode = value
	attr(s, "Mode", value)
end
local function finishMotion(s)
	visible(s, true)
	if s.ownsMotion then
		if s.root.Parent then s.root.Anchored = s.oldAnchored end
		s.hum.AutoRotate = s.oldRotate
		s.hum.WalkSpeed = s.oldWalk
		s.ownsMotion = false
	end
	s.input = Vector3.zero
	mode(s, "Idle")
end
local function startMotion(s, value)
	if s.root.Anchored or s.ownsMotion then return false end
	s.oldAnchored, s.oldRotate, s.oldWalk = s.root.Anchored, s.hum.AutoRotate, s.hum.WalkSpeed
	s.ownsMotion = true
	s.root.Anchored = true
	s.hum.AutoRotate = false
	s.hum.WalkSpeed = 0
	s.root.AssemblyLinearVelocity = Vector3.zero
	s.motionStart = clock()
	s.lastInput = 0
	mode(s, value)
	return true
end
local function move(s, delta)
	if delta.Magnitude < 0.00001 then return nil end
	local distance = footDistance(s)
	local size = Vector3.new(2.5, math.max(2, distance + 1.5), 2.5)
	local cf = s.root.CFrame * CFrame.new(0, (1.5 - distance)/2, 0)
	local hit = workspace:Blockcast(cf, size - Vector3.new(0.1,0.1,0.1), delta, params(s))
	local travel = delta
	if hit then travel = delta.Unit * math.max(0, hit.Distance - 0.12) end
	s.char:PivotTo(s.char:GetPivot() + travel)
	return hit
end
local function load(s, amount)
	s.neural = math.clamp(s.neural + amount, 0, 100)
	attr(s, "Neural", s.neural)
	if s.neural >= 100 then
		finishMotion(s)
		s.hum.Health = 0
		return false
	end
	return true
end
local function cooldown(s, key, seconds)
	s.cooldowns[key] = clock() + seconds
	attr(s, key .. "Ready", s.cooldowns[key])
end
local function ready(s, key)
	return clock() >= (s.cooldowns[key] or 0)
end
local function warning(s)
	visible(s, true)
	mode(s, "Warning")
	s.warningEnd = clock() + CONFIG.Advertencia
	attr(s, "WarningEnd", s.warningEnd)
	emit(s, "Warning", {position = ground(s), duration = CONFIG.Advertencia, radius = CONFIG.RadioGravity})
end
local actions = {}
function actions.Inject(s)
	if s.charges <= 0 or not ready(s, "Inject") then return end
	s.charges = s.charges - 1
	attr(s, "Charges", s.charges)
	load(s, -CONFIG.Alivio)
	cooldown(s, "Inject", 0.65)
	fx:Fire("Inject", s.player, {})
end
function actions.Gravity(s)
	if s.mode == "Phase" then warning(s) return end
	if s.mode ~= "Idle" or s.sandeEnd > clock() or not ready(s, "Gravity") or s.root.Anchored then return end
	if not load(s, CONFIG.NeuralPorAtaque) then return end
	if startMotion(s, "Phase") then
		s.height = s.root.Position.Y + CONFIG.AlturaGravity
		s.hideAt = clock() + 0.32
		emit(s, "Phase", {})
	end
end
function actions.Fly(s)
	if s.mode == "Flight" then finishMotion(s) cooldown(s, "Fly", 4) return end
	if s.mode ~= "Idle" or s.sandeEnd > clock() or not ready(s, "Fly") or s.root.Anchored then return end
	if not load(s, CONFIG.NeuralPorAtaque) then return end
	if startMotion(s, "Flight") then emit(s, "Flight", {}) end
end
function actions.Sandevistan(s)
	if s.mode ~= "Idle" or s.sandeEnd > clock() or not ready(s, "Sandevistan") then return end
	if not load(s, CONFIG.NeuralPorAtaque) then return end
	s.sandeWalk = s.hum.WalkSpeed
	s.hum.WalkSpeed = CONFIG.SandeVelocidad
	s.sandeEnd = clock() + CONFIG.SandeDuracion
	attr(s, "SandeEnd", s.sandeEnd)
	cooldown(s, "Sandevistan", CONFIG.SandeDuracion + 7)
	emit(s, "Sande", {duration = CONFIG.SandeDuracion, count = 24})
end
function actions.Dash(s)
	if s.mode ~= "Idle" or s.dash <= 0 or not ready(s, "DashTap") or s.root.Anchored then return end
	local dir = Vector3.new(s.root.CFrame.LookVector.X, 0, s.root.CFrame.LookVector.Z)
	if dir.Magnitude < 0.1 then return end
	if not load(s, CONFIG.NeuralPorAtaque) then return end
	s.dash = s.dash - 1
	attr(s, "DashCharges", s.dash)
	cooldown(s, "DashTap", 0.3)
	if s.dash == 0 then cooldown(s, "Dash", CONFIG.DashRecarga) end
	local start = s.root.CFrame
	move(s, dir.Unit * CONFIG.DashDistancia)
	emit(s, "Dash", {start = start, finish = s.root.CFrame})
end
function actions.Pulse(s)
	if s.mode ~= "Idle" or not ready(s, "Pulse") then return end
	if not load(s, CONFIG.NeuralPorAtaque) then return end
	cooldown(s, "Pulse", 7)
	emit(s, "Pulse", {position = ground(s), radius = CONFIG.RadioPulse})
end
function actions.Atraction(s)
	if s.mode ~= "Idle" or not ready(s, "Atraction") then return end
	if not load(s, CONFIG.NeuralPorAtaque) then return end
	cooldown(s, "Atraction", 9)
	emit(s, "Attraction", {position = s.root.Position, duration = 1.5, radius = 32})
end
function actions.Punch(s)
	if s.mode ~= "Idle" or not ready(s, "Punch") then return end
	if not load(s, CONFIG.NeuralPorAtaque) then return end
	cooldown(s, "Punch", 0.7)
	s.hand = not s.hand
	emit(s, "Punch", {right = s.hand, position = s.root.Position + s.root.CFrame.LookVector * 4})
end
request.Event:Connect(function(plr, action, data)
	local s = states[plr]
	if type(action) ~= "string" or not available(s) then return end
	local now = clock()
	if action == "Move" then
		if now - (s.moveRequest or 0) < 0.075 then return end
		s.moveRequest = now
		if typeof(data) ~= "Vector3" then return end
		if s.mode ~= "Phase" and s.mode ~= "Flight" then return end
		if s.mode == "Phase" then data = Vector3.new(data.X, 0, data.Z) end
		s.input = data.Magnitude > 1 and data.Unit or data
		s.lastInput = now
		return
	end
	if now - (s.lastRequest or 0) < 0.09 or not actions[action] then return end
	s.lastRequest = now
	actions[action](s)
end)
local function setup(char)
	local previous = states[player]
	if previous then finishMotion(previous) end
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root or player.Character ~= char then return end
	local s = {
		player = player, char = char, hum = hum, root = root,
		neural = 0, charges = CONFIG.Cargas, dash = CONFIG.DashCargas,
		cooldowns = {}, hidden = {}, mode = "Idle", sandeEnd = 0,
		passive = 0, input = Vector3.zero
	}
	states[player] = s
	for _, key in ipairs({"Gravity","Sandevistan","Pulse","Atraction","Dash","Punch","Fly","Inject","DashTap"}) do
		attr(s, key.."Ready", 0)
	end
	attr(s, "Neural", 0)
	attr(s, "Charges", s.charges)
	attr(s, "DashCharges", s.dash)
	attr(s, "SandeEnd", 0)
	attr(s, "Mode", "Idle")
	attr(s, "WarningEnd", 0)
	hum.Died:Connect(function()
		if states[player] ~= s then return end
		finishMotion(s)
		s.sandeEnd = 0
		attr(s, "SandeEnd", 0)
		emit(s, "Stop", {})
	end)
end
player.CharacterAdded:Connect(function(char) task.spawn(setup, char) end)
if player.Character then task.spawn(setup, player.Character) end

RunService.Heartbeat:Connect(function(dt)
	local now = clock()
	local s = states[player]
	if not s then return end
	if available(s) then
		s.passive = s.passive + dt
		if s.passive >= 1 then
			local ticks = math.floor(s.passive)
			s.passive = s.passive - ticks
			load(s, CONFIG.NeuralPorSegundo * ticks)
		end
		if s.hum.Health > 0 then
			if s.dash == 0 and ready(s, "Dash") then
				s.dash = CONFIG.DashCargas
				attr(s, "DashCharges", s.dash)
			end
			if s.sandeEnd > 0 and now >= s.sandeEnd then
				s.hum.WalkSpeed = s.sandeWalk
				s.sandeEnd = 0
				attr(s, "SandeEnd", 0)
			end
			local input = now - (s.lastInput or 0) <= 0.5 and s.input or Vector3.zero
			local step = math.min(dt, 0.1)
			if s.mode == "Phase" then
				if s.hideAt and now >= s.hideAt then visible(s, false) s.hideAt = nil end
				move(s, Vector3.new(input.X, 0, input.Z) * CONFIG.VelocidadAerea * step)
				move(s, Vector3.new(0, math.clamp(s.height - s.root.Position.Y, -20*step, 20*step), 0))
				if now - s.motionStart >= 30 then warning(s) end
			elseif s.mode == "Warning" and now >= s.warningEnd then
				mode(s, "Falling")
				s.fallStart = now
			elseif s.mode == "Falling" then
				local hit = move(s, Vector3.new(0, -CONFIG.VelocidadCaida * step, 0))
				if hit then
					finishMotion(s)
					s.root.AssemblyLinearVelocity = Vector3.zero
					cooldown(s, "Gravity", 5)
					emit(s, "Impact", {position = ground(s), radius = CONFIG.RadioGravity})
				elseif now - s.fallStart > 3 then
					finishMotion(s)
					cooldown(s, "Gravity", 5)
				end
			elseif s.mode == "Flight" then
				move(s, input * CONFIG.VueloVelocidad * step)
				if now - s.motionStart >= CONFIG.VueloDuracion then
					finishMotion(s)
					cooldown(s, "Fly", 4)
				end
			end
		end
	elseif s.ownsMotion then
		finishMotion(s)
	end
end)

-------------------------------------------------
-- 5. EFECTOS VISUALES
-------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "CyberVisualLocal"
folder.Parent = workspace
local rings = {}
local sequences = {}
local flashEnd = 0
local function part(parent, color, size)
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
local function discard(who)
	if rings[who] then
		rings[who].folder:Destroy()
		rings[who] = nil
	end
end
local function warningVisual(who, data)
	discard(who)
	local f = Instance.new("Folder")
	f.Name = "Caution"
	f.Parent = folder
	local pieces = {}
	for layer = 1, 2 do
		local count = layer == 1 and 64 or 40
		for i = 1, count do
			local p = part(f, layer == 1 and Color3.fromRGB(255,45,35) or Color3.fromRGB(255,160,90),
			Vector3.new(layer == 1 and 3.4 or 2.5, 0.12, layer == 1 and 0.75 or 0.18))
			table.insert(pieces, {p = p, angle = i/count * math.pi * 2, layer = layer})
		end
	end
	local anchor = part(f, Color3.new(1,0,0), Vector3.one)
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
	title.Text = " ⚠   CAUTION"
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
	rings[who] = {
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
		local p = part(f, Color3.fromRGB(255,95,65), Vector3.new(3, 0.12, 0.4))
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
		local ring = part(f, Color3.fromRGB(255, 80, 60), Vector3.new(1, 0.15, 1))
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
		local p = part(f, Color3.fromRGB(180, 60, 255), Vector3.new(0.4, 0.4, 0.4))
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
	local p = part(f, Color3.fromRGB(255, 120, 50), Vector3.new(3, 3, 1))
	p.CFrame = CFrame.new(data.position)
	TweenService:Create(p, TweenInfo.new(0.25), {
		Size = Vector3.new(6, 6, 0.2),
		Transparency = 1
	}):Play()
	Debris:AddItem(f, 0.3)
end
local function residue(who, offset, hue)
	local char = who.Character
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
fx.Event:Connect(function(event, who, data)
	if event == "Warning" then
		warningVisual(who, data)
	elseif event == "Impact" then
		discard(who)
		impactVisual(data)
	elseif event == "Stop" then
		discard(who)
	elseif event == "Sande" then
		sequences[who] = {char = who.Character, start = os.clock(), duration = data.duration, count = 0}
	elseif event == "Dash" then
		if who == player then flashEnd = os.clock() + 0.18 end
		local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
		if root and data then
			for i = 0, 3 do
				local pose = data.start:Lerp(data.finish, i/4)
				residue(who, pose * root.CFrame:Inverse(), 0.45 + i * 0.08)
			end
		end
	elseif event == "Phase" then
		if who == player then flashEnd = os.clock() + 0.25 end
	elseif event == "Pulse" then
		pulseVisual(data)
	elseif event == "Attraction" then
		attractionVisual(data)
	elseif event == "Punch" then
		punchVisual(data)
	end
end)

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

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for who, r in pairs(rings) do
		local elapsed = t - r.start
		if elapsed >= r.duration or not who.Parent then
			discard(who)
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
		if not who.Parent or who.Character ~= s.char or elapsed > s.duration + 0.1 then
			sequences[who] = nil
		elseif s.count < 24 and elapsed >= s.count * 0.12 then
			s.count = s.count + 1
			residue(who, CFrame.identity, s.count / 24)
		end
	end
	local active = (player:GetAttribute("CyberSandeEnd") or 0) > workspace:GetServerTimeNow()
	color.Enabled = active or t < flashEnd
	blur.Size = t < flashEnd and 7 or 0

	-- ===== MOVIMIENTO (incluye botones de vuelo) =====
	local mode = player:GetAttribute("CyberMode")
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and (mode == "Phase" or mode == "Flight") then
		local direction = hum.MoveDirection
		local vertical = 0
		if mode == "Flight" and not UIS:GetFocusedTextBox() then
			-- Primero lee los botones de la interfaz
			vertical = player:GetAttribute("CyberLocalLift") or 0
			-- También acepta teclado
			if UIS:IsKeyDown(Enum.KeyCode.E) then
				vertical = 1
			elseif UIS:IsKeyDown(Enum.KeyCode.Q) then
				vertical = -1
			end
		end
		request:Fire(player, "Move", Vector3.new(direction.X, vertical, direction.Z))
	end
end)

-------------------------------------------------
-- 6. INTERFAZ COMPLETA + BOTONES DE VUELO
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
-- Barra de habilidades
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
		request:Fire(player, def[1])
	end)
	buttons[def[1]] = {button = b, status = status}
end

-- ========== BOTONES DE VUELO (SUBIR / BAJAR) ==========
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

-- Panel izquierdo
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
	Text = "PROTOTYPE 07  /  ONLINE",
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

-- Panel derecho
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
local neuralVal, neuralFill = meter(right, "CARGA NEURAL", 58, RED)
local inject = create("TextButton", right, {
	Position = UDim2.fromOffset(12, 105),
	Size = UDim2.fromOffset(216, 42),
	BackgroundColor3 = Color3.fromRGB(10, 35, 45),
	Text = "INYECTAR  [-30%]  [R]",
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = GREEN,
	BorderSizePixel = 0
})
round(inject, 8)
create("UIStroke", inject, {Color = GREEN, Transparency = 0.35, Thickness = 1.2})
inject.Activated:Connect(function()
	request:Fire(player, "Inject")
end)
create("TextLabel", right, {
	Text = "SISTEMA OPERATIVO // TECLAS",
	Position = UDim2.fromOffset(12, 156),
	Size = UDim2.fromOffset(216, 16),
	BackgroundTransparency = 1,
	TextColor3 = CYAN,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left
})
local help = create("TextLabel", right, {
	Text = "[1] Sande  [2] Gravity  [3] Pulse  [4] Attraction\n[5] Dash  [6] Golpe  [7] Vuelo [E/Q] Subir/Bajar",
	Position = UDim2.fromOffset(12, 174),
	Size = UDim2.fromOffset(216, 50),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(185, 220, 230),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top
})

-- Teclado
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R then
		request:Fire(player, "Inject")
	else
		for _, def in ipairs(definitionsUI) do
			if input.KeyCode == def[3] then
				request:Fire(player, def[1])
				break
			end
		end
	end
end)

-- Actualización de Interfaz Dinámica
local function updateUI()
	local n = player:GetAttribute("CyberNeural") or 0
	local c = player:GetAttribute("CyberCharges") or CONFIG.Cargas
	neuralVal.Text = string.format("%d%%", n)
	neuralFill.Size = UDim2.fromScale(math.clamp(n / 100, 0, 1), 1)
	for i = 1, 10 do
		TweenService:Create(doses[i], TweenInfo.new(0.2), {Size = UDim2.fromScale(1, i <= c and 1 or 0)}):Play()
	end
	medical.Text = n >= 100 and "FALLO NEURAL" or n >= 80 and "ALERTA // SOBRECARGA" or "CONTROL NEURAL ACTIVO"
	medical.TextColor3 = n >= 80 and RED or GREEN
	stateLabel.Text = c <= 7 and "INTERFERENCIA NEURAL DETECTADA" or "ENLACE ACTIVO"
	stateLabel.TextColor3 = c <= 7 and RED or GREEN
	inject.Text = c > 0 and "INYECTAR  [-30%]  [R]" or "SIN CARGAS"
end

player:GetAttributeChangedSignal("CyberNeural"):Connect(updateUI)
player:GetAttributeChangedSignal("CyberCharges"):Connect(updateUI)
updateUI()

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local mode = player:GetAttribute("CyberMode") or "Idle"
	-- Mostrar / ocultar botones de vuelo
	lift.Visible = mode == "Flight"
	for action, b in pairs(buttons) do
		local leftTime = math.max(0, (player:GetAttribute("Cyber" .. action .. "Ready") or 0) - now)
		local status = leftTime > 0 and string.format("%.1fs", leftTime) or "LISTO"
		if action == "Dash" and leftTime <= 0 then
			status = (player:GetAttribute("CyberDashCharges") or 4) .. "/4"
		end
		if action == "Sandevistan" and (player:GetAttribute("CyberSandeEnd") or 0) > now then
			status = "ACTIVO"
		end
		b.status.Text = status
	end
end)
