-- ===================================================================
-- CYBERSKELETON - SCRIPT UNIFICADO LOCAL (FORZADO PARA DELTA / EXECUTORS)
-- ===================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
-- GENERADOR PROCEDURAL DEL SUIT (ARMADURA Y VISUALES)
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
-- ADAPTACIÓN E INSTALACIÓN EN EL PERSONAJE (R15 Y R6)
-- ===================================================================
local function installCyberSkeleton(character)
	if not character then return end
	if character:FindFirstChild("CyberSkeletonEquipado") then
		character.CyberSkeletonEquipado:Destroy()
	end

	local humanoid = character:WaitForChild("Humanoid", 5)
	local root = character:WaitForChild("HumanoidRootPart", 5)

	if not humanoid or not root then
		warn("[CyberSkeleton] No se encontró el Humanoid o HumanoidRootPart.")
		return
	end

	print("[CyberSkeleton] Instalando traje en el personaje...")

	local isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)
	
	-- Definición de extremidades adaptables
	local limbsToAttach = isR15 and {
		{name="BrazoDerecho", body="RightUpperArm"},
		{name="BrazoIzquierdo", body="LeftUpperArm"},
		{name="PiernaDerecha", body="RightUpperLeg"},
		{name="PiernaIzquierda", body="LeftUpperLeg"}
	} or {
		{name="BrazoDerecho", body="Right Arm"},
		{name="BrazoIzquierdo", body="Left Arm"},
		{name="PiernaDerecha", body="Right Leg"},
		{name="PiernaIzquierda", body="Left Leg"}
	}

	local suit = Instance.new("Model")
	suit.Name = "CyberSkeletonEquipado"

	for _, def in ipairs(limbsToAttach) do
		local limb = character:FindFirstChild(def.body)
		if limb then
			local model = createPieceModel(def.name)
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					part.CFrame = limb.CFrame

					local weld = Instance.new("Weld")
					weld.Name = "UnionCyber"
					weld.Part0 = limb
					weld.Part1 = part
					weld.C0 = CFrame.new(0, 0, 0)
					weld.C1 = CFrame.identity
					weld.Parent = part
				end
			end
			model.Parent = suit
		end
	end

	-- Ocultar extremidades originales
	local hiddenParts = isR15 and {
		LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
		RightUpperArm=true, RightLowerArm=true, RightHand=true,
		LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
		RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
	} or {
		["Right Arm"]=true, ["Left Arm"]=true, ["Right Leg"]=true, ["Left Leg"]=true
	}

	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and hiddenParts[part.Name] then
			part.Transparency = 1
			part.CanCollide = false
		end
	end

	suit.Parent = character
	print("[CyberSkeleton] ¡CyberSkeleton activado con éxito!")
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

	local size = Vector3.new(2.5, 4, 2.5)
	local cf = root.CFrame
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

local function triggerAreaEffect(char, radius, actionType)
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
-- ACCIONES DE HABILIDADES
-- ===================================================================
local actions = {}

function actions.Inject(char)
	if state.charges <= 0 or not isReady("Inject") then return end
	state.charges = state.charges - 1
	addNeuralLoad(-CONFIG.Alivio)
	setCooldown("Inject", 0.65)
	print("[CyberSkeleton] Inyección usada. Carga neural reducida.")
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
		print("[CyberSkeleton] Modo Phase / Gravitacional activado.")
	end
end

function actions.Fly(char)
	if state.mode == "Flight" then
		finishMotion(char)
		setCooldown("Fly", 4)
		print("[CyberSkeleton] Vuelo desactivado.")
		return
	end
	if state.mode ~= "Idle" or not isReady("Fly") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	startMotion(char, "Flight")
	print("[CyberSkeleton] Modo Vuelo activado.")
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
		print("[CyberSkeleton] SANDEVISTAN ACTIVADO.")
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
	print("[CyberSkeleton] Dash realizado.")
end

function actions.Pulse(char)
	if state.mode ~= "Idle" or not isReady("Pulse") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Pulse", 7)
	triggerAreaEffect(char, CONFIG.RadioPulse, "Pulse")
	print("[CyberSkeleton] Pulso realizado.")
end

function actions.Attraction(char)
	if state.mode ~= "Idle" or not isReady("Atraction") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Atraction", 9)
	state.attractEnd = getClock() + 1.5
	state.attractTick = 0
	print("[CyberSkeleton] Atracción activada.")
end

function actions.Punch(char)
	if state.mode ~= "Idle" or not isReady("Punch") then return end
	if not addNeuralLoad(CONFIG.NeuralPorAtaque) then return end
	setCooldown("Punch", 0.7)
	state.handToggle = not state.handToggle
	triggerAreaEffect(char, 16, "Punch")
end

-- ===================================================================
-- CONTROLES DE TECLADO
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
-- BUCLE PRINCIPAL DE ACTUALIZACIÓN
-- ===================================================================
local passiveTimer = 0

RunService.Heartbeat:Connect(function(dt)
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("CyberSkeletonEquipado") then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return end

	local now = getClock()

	passiveTimer = passiveTimer + dt
	if passiveTimer >= 1 then
		local ticks = math.floor(passiveTimer)
		passiveTimer = passiveTimer - ticks
		addNeuralLoad(CONFIG.NeuralPorSegundo * ticks)
	end

	if state.dashCharges == 0 and isReady("Dash") then
		state.dashCharges = CONFIG.DashCargas
	end

	if state.sandeActive and now >= state.sandeEnd then
		state.sandeActive = false
		hum.WalkSpeed = state.oldWalk or 16
	end

	if state.attractEnd and now < state.attractEnd and now >= state.attractTick then
		state.attractTick = now + 0.2
		triggerAreaEffect(char, 32, "Attraction")
	end

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
			triggerAreaEffect(char, CONFIG.RadioGravity, "Gravity")
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
-- EJECUCIÓN INMEDIATA
-- ===================================================================
if LocalPlayer.Character then
	installCyberSkeleton(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(installCyberSkeleton, char)
end)
