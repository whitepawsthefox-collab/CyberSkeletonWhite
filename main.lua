-- ===================================================================
-- CYBERSKELETON - SCRIPT UNIFICADO LOCAL (COMPATIBLE CON DELTA EXECUTOR)
-- ===================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

-- Configuración general de habilidades
local CONFIG = {
	NeuralPorSegundo = 1,
	NeuralPorAtaque = 6,
	Alivio = 30,
	Cargas = 10,
	AlturaGravity = 10,
	VelocidadAerea = 38,
	VelocidadCaida = 210,
	Advertencia = 3,
	RadioGravity = 45,
	RadioPulse = 38,
	SandeVelocidad = 100,
	SandeDuracion = 2.88,
	DashDistancia = 22,
	DashCargas = 4,
	DashRecarga = 7,
	VueloVelocidad = 44,
	VueloDuracion = 20,
}

-- Definición de extremidades R15 para el montaje
local definitions = {
	{name="BrazoDerecho", body="RightUpperArm", attachment="RightShoulderRigAttachment", joint=CFrame.new(-0.297, 0.348, -0.0004)},
	{name="BrazoIzquierdo", body="LeftUpperArm", attachment="LeftShoulderRigAttachment", joint=CFrame.new(0.297, 0.348, -0.0004)},
	{name="PiernaDerecha", body="RightUpperLeg", attachment="RightHipRigAttachment", joint=CFrame.new(0.025, 0.717, 0.0055)},
	{name="PiernaIzquierda", body="LeftUpperLeg", attachment="LeftHipRigAttachment", joint=CFrame.new(-0.025, 0.717, 0.0055)}
}

-- Estado del jugador
local state = {
	mode = "Idle",
	neural = 0,
	charges = CONFIG.Cargas,
	dashCharges = CONFIG.DashCargas,
	cooldowns = {},
	hidden = {},
	inputVector = Vector3.zero,
	sandeActive = false,
	handToggle = false,
	lastInput = 0,
	motionStart = 0,
	ownsMotion = false,
}

local function getClock() return os.clock() end

-- ===================================================================
-- CONSTRUCTOR PROCEDURAL DEL MODELO CYBERSKELETON
-- (Genera las partes biomecánicas sin necesidad de ServerStorage)
-- ===================================================================
local function createPieceModel(name)
	local model = Instance.new("Model")
	model.Name = name

	local mainPart = Instance.new("Part")
	mainPart.Name = "MainFrame"
	mainPart.Size = Vector3.new(1.2, 2.2, 1.2)
	mainPart.Material = Enum.Material.SmoothPlastic
	mainPart.Color = Color3.fromRGB(30, 30, 35)
	mainPart.Parent = model

	local coreGlow = Instance.new("Part")
	coreGlow.Name = "NeonCore"
	coreGlow.Size = Vector3.new(0.8, 1.8, 0.8)
	coreGlow.Material = Enum.Material.Neon
	coreGlow.Color = Color3.fromRGB(0, 255, 200)
	coreGlow.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = mainPart
	weld.Part1 = coreGlow
	weld.Parent = mainPart

	return model
end

-- ===================================================================
-- SISTEMA DE MONTAJE Y ADAPTACIÓN AL AVATAR
-- ===================================================================
local function installCyberSkeleton(character)
	if not character or character:FindFirstChild("CyberSkeletonEquipado") then return end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or humanoid.Health <= 0 then return end

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn("CyberSkeleton: Diseñado principalmente para avatares R15.")
	end

	local suit = Instance.new("Model")
	suit.Name = "CyberSkeletonEquipado"

	local lowestY = 0

	for _, def in ipairs(definitions) do
		local limb = character:WaitForChild(def.body, 5)
		if limb then
			local model = createPieceModel(def.name)
			local attachment = limb:FindFirstChild(def.attachment)
			local attachmentCF = attachment and attachment.CFrame or def.joint

			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					part.CFrame = limb.CFrame * attachmentCF

					local weld = Instance.new("Weld")
					weld.Name = "UnionCyber"
					weld.Part0 = limb
					weld.Part1 = part
					weld.C0 = attachmentCF
					weld.C1 = CFrame.identity
					weld.Parent = part

					if string.find(def.name, "Pierna") then
						lowestY = math.min(lowestY, -2.5)
					end
				end
			end
			model.Parent = suit
		end
	end

	-- Soporte de colisión central
	local distance = math.max(3, -lowestY)
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

	-- Ocultar extremidades del avatar original
	local hiddenParts = {
		LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
		RightUpperArm=true, RightLowerArm=true, RightHand=true,
		LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
		RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
	}

	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and hiddenParts[part.Name] then
			part.Transparency = 1
			part.CanCollide = false
		end
	end

	humanoid.HipHeight = math.max(0, distance - root.Size.Y / 2 + 0.15)
	suit.Parent = character
end

-- ===================================================================
-- LÓGICA DE MOVIMIENTO Y HABILIDADES
-- ===================================================================
local function getRayParams(char)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = {char}
	p.RespectCanCollide = true
	return p
end

local function footDistance(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return 3 end
	return hum.HipHeight + root.Size.Y / 2
end

local function getGroundPosition(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return Vector3.zero end
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -600, 0), getRayParams(char))
	return hit and hit.Position or root.Position - Vector3.new(0, footDistance(char), 0)
end

local function toggleVisibility(char, visible)
	if visible then
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

local function finishMotion(char)
	toggleVisibility(char, true)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if state.ownsMotion and hum and root then
		root.Anchored = false
		hum.AutoRotate = true
		state.ownsMotion = false
	end
	state.inputVector = Vector3.zero
	state.mode = "Idle"
end

local function startMotion(char, newMode)
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or root.Anchored or state.ownsMotion then return false end

	state.ownsMotion = true
	root.Anchored = true
	hum.AutoRotate = false
	root.AssemblyLinearVelocity = Vector3.zero
	state.motionStart = getClock()
	state.mode = newMode
	return true
end

local function sweepMove(char, delta)
	if delta.Magnitude < 0.00001 then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local dist = footDistance(char)
	local size = Vector3.new(2.5, math.max(2, dist + 1.5), 2.5)
	local cf = root.CFrame * CFrame.new(0, (1.5 - dist) / 2, 0)
	local hit = workspace:Blockcast(cf, size - Vector3.new(0.1, 0.1, 0.1), delta, getRayParams(char))
	local travel = hit and (delta.Unit * math.max(0, hit.Distance - 0.12)) or delta

	char:PivotTo(char:GetPivot() + travel)
	return hit
end

local function addNeuralLoad(amount)
	state.neural = math.clamp(state.neural + amount, 0, 100)
	if state.neural >= 100 then
		local char = LocalPlayer.Character
		if char then
			finishMotion(char)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
		end
		return false
	end
	return true
end

local function isReady(key)
	return getClock() >= (state.cooldowns[key] or 0)
end

local function setCooldown(key, seconds)
	state.cooldowns[key] = getClock() + seconds
end

-- Efectos de área e impulso
local function triggerAreaEffect(char, radius, actionType, damage)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = {char}

	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, radius, overlap)) do
		if part.AssemblyRootPart and not part.AssemblyRootPart.Anchored then
			local diff = part.Position - root.Position
			local dir = diff.Magnitude > 0.1 and diff.Unit or root.CFrame.LookVector
			local force = dir * 65 + Vector3.new(0, 22, 0)

			if actionType == "Attraction" then force = -dir * 22 + Vector3.new(0, 5, 0) end
			if actionType == "Gravity" then force = dir * 50 + Vector3.new(0, 12, 0) end
			if actionType == "Punch" then force = root.CFrame.LookVector * 50 + Vector3.new(0, 8, 0) end

			part.AssemblyRootPart:ApplyImpulse(force * part.AssemblyRootPart.AssemblyMass)
		end
	end
end

-- ===================================================================
-- COMANDOS Y ACCIONES DE HABILIDADES
-- ===================================================================
local actions = {}

function actions.Inject(char)
	if state.charges <= 0 or not isReady("Inject") then return end
	state.charges = state.charges - 1
	addNeuralLoad(-CONFIG.Alivio)
	setCooldown("Inject", 0.65)
end

function actions.Gravity(char)
	if state.mode == "Phase" then
		toggleVisibility(char, true)
		state.mode = "Warning"
		state.warningEnd = getClock() + CONFIG.Advertencia
		return
	end
	if state.mode ~= "Idle" or not isReady("Gravity") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end

	if startMotion(char, "Phase") then
		local root = char:FindFirstChild("HumanoidRootPart")
		state.height = root.Position.Y + CONFIG.AlturaGravity
		state.hideAt = getClock() + 0.32
	end
end

function actions.Fly(char)
	if state.mode == "Flight" then
		finishMotion(char)
		setCooldown("Fly", 4)
		return
	end
	if state.mode ~= "Idle" or not isReady("Fly") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	startMotion(char, "Flight")
end

function actions.Sandevistan(char)
	if state.mode ~= "Idle" or not isReady("Sandevistan") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		state.oldWalk = hum.WalkSpeed
		hum.WalkSpeed = CONFIG.SandeVelocidad
		state.sandeActive = true
		state.sandeEnd = getClock() + CONFIG.SandeDuracion
		setCooldown("Sandevistan", CONFIG.SandeDuracion + 7)
	end
end

function actions.Dash(char)
	if state.mode ~= "Idle" or state.dashCharges <= 0 or not isReady("DashTap") then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end

	state.dashCharges = state.dashCharges - 1
	setCooldown("DashTap", 0.3)
	if state.dashCharges == 0 then setCooldown("Dash", CONFIG.DashRecarga) end

	sweepMove(char, dir.Unit * CONFIG.DashDistancia)
end

function actions.Pulse(char)
	if state.mode ~= "Idle" or not isReady("Pulse") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Pulse", 7)
	triggerAreaEffect(char, CONFIG.RadioPulse, "Pulse", 20)
end

function actions.Attraction(char)
	if state.mode ~= "Idle" or not isReady("Atraction") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Atraction", 9)
	state.attractEnd = getClock() + 1.5
	state.attractTick = 0
end

function actions.Punch(char)
	if state.mode ~= "Idle" or not isReady("Punch") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Punch", 0.7)
	state.handToggle = not state.handToggle
	triggerAreaEffect(char, 16, "Punch", 18)
end

-- ===================================================================
-- ASIGNACIÓN DE TECLAS Y CONTROLES (TECLADO)
-- ===================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("CyberSkeletonEquipado") then return end

	if input.KeyCode == Enum.KeyCode.E then actions.Dash(char) end
	if input.KeyCode == Enum.KeyCode.Q then actions.Sandevistan(char) end
	if input.KeyCode == Enum.KeyCode.F then actions.Gravity(char) end
	if input.KeyCode == Enum.KeyCode.R then actions.Fly(char) end
	if input.KeyCode == Enum.KeyCode.C then actions.Pulse(char) end
	if input.KeyCode == Enum.KeyCode.V then actions.Attraction(char) end
	if input.KeyCode == Enum.KeyCode.Z then actions.Inject(char) end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then actions.Punch(char) end
end)

-- Captura de dirección de movimiento para vuelo/fase
RunService.RenderStepped:Connect(function()
	local moveDir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Vector3.new(0, 0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir + Vector3.new(0, 0, 1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir + Vector3.new(-1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Vector3.new(1, 0, 0) end

	local camera = workspace.CurrentCamera
	if camera and moveDir.Magnitude > 0 then
		state.inputVector = camera.CFrame:VectorToWorldSpace(moveDir)
	else
		state.inputVector = Vector3.zero
	end
end)

-- ===================================================================
-- BUCLE PRINCIPAL DE ACTUALIZACIÓN (HEARTBEAT)
-- ===================================================================
local passiveTimer = 0

RunService.Heartbeat:Connect(function(dt)
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("CyberSkeletonEquipado") then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return end

	local now = getClock()

	-- Carga neural pasiva
	passiveTimer = passiveTimer + dt
	if passiveTimer >= 1 then
		local ticks = math.floor(passiveTimer)
		passiveTimer = passiveTimer - ticks
		addNeuralLoad(CONFIG.NeuralPorSegundo * ticks)
	end

	-- Recarga de Dash
	if state.dashCharges == 0 and isReady("Dash") then
		state.dashCharges = CONFIG.DashCargas
	end

	-- Fin de Sandevistan
	if state.sandeActive and now >= state.sandeEnd then
		state.sandeActive = false
		hum.WalkSpeed = state.oldWalk or 16
	end

	-- Atracción continua
	if state.attractEnd and now < state.attractEnd and now >= state.attractTick then
		state.attractTick = now + 0.2
		triggerAreaEffect(char, 32, "Attraction", 0)
	end

	-- Bucle de Estados de Movimiento
	local step = math.min(dt, 0.1)

	if state.mode == "Phase" then
		if state.hideAt and now >= state.hideAt then
			toggleVisibility(char, false)
			state.hideAt = nil
		end
		sweepMove(char, Vector3.new(state.inputVector.X, 0, state.inputVector.Z) * CONFIG.VelocidadAerea * step)
		sweepMove(char, Vector3.new(0, math.clamp(state.height - root.Position.Y, -20 * step, 20 * step), 0))

		if now - state.motionStart >= 30 then
			toggleVisibility(char, true)
			state.mode = "Warning"
			state.warningEnd = now + CONFIG.Advertencia
		end

	elseif state.mode == "Warning" and now >= state.warningEnd then
		state.mode = "Falling"
		state.fallStart = now

	elseif state.mode == "Falling" then
		local hit = sweepMove(char, Vector3.new(0, -CONFIG.VelocidadCaida * step, 0))
		if hit then
			finishMotion(char)
			root.AssemblyLinearVelocity = Vector3.zero
			setCooldown("Gravity", 5)
			triggerAreaEffect(char, CONFIG.RadioGravity, "Gravity", 35)
		elseif now - state.fallStart > 3 then
			finishMotion(char)
			setCooldown("Gravity", 5)
		end

	elseif state.mode == "Flight" then
		sweepMove(char, state.inputVector * CONFIG.VueloVelocidad * step)
		if now - state.motionStart >= CONFIG.VueloDuracion then
			finishMotion(char)
			setCooldown("Fly", 4)
		end
	end
end)

-- ===================================================================
-- INICIALIZACIÓN
-- ===================================================================
if LocalPlayer.Character then
	task.spawn(installCyberSkeleton, LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(installCyberSkeleton, char)
end)
