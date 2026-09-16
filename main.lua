--[[
	CYBERSKELETON COMPLETO v3.8 - Versión Adaptada para Ejecutores (Delta)
	Autocontenido (efectos y animaciones locales).
    Sustituye el archivo anterior completo. En Studio: LocalScript en StarterPlayerScripts.
    M1 o GOLPE: impacto -> arrastre -> remate (puedes anticipar el tercer clic durante el arrastre).
    R: inmunosupresor. Teclas 1-7 y botones: habilidades. Vuelo: E/Q o SUBIR/BAJAR.
    La animacion se calcula con Motor6D; no requiere IDs de animacion.
    Los escombros son visuales locales, no destruyen el mapa ni garantizan dano/atraccion sobre otros usuarios.
    Fase final: grito 4 s -> Sande 10 s -> dialogo 3 s -> musica hasta 2:50 -> muerte local.
    Si el audio no esta disponible, se usa un reloj de respaldo de 170 s.
    La reaparicion real depende del servidor del juego; se reinstala al recibir un nuevo personaje.
    La fidelidad de las poses depende de las proporciones del avatar y requiere prueba en Roblox.
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

-- Limpieza sincronica entre ejecuciones de esta version.
local runtimeParent = player:WaitForChild("PlayerScripts")
local previousRuntime = runtimeParent:FindFirstChild("CyberRuntimeV34")
if previousRuntime then
    local shutdown = previousRuntime:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableFunction") then
        local ok, err = pcall(function() shutdown:Invoke() end)
        if not ok then warn("[Cyber] No se pudo cerrar la instancia anterior: " .. tostring(err)) return end
    else
        warn("[Cyber] Hay una instancia iniciandose. No ejecutes dos copias simultaneamente.")
        return
    end
end
local runtime = Instance.new("Folder")
runtime.Name = "CyberRuntimeV34"
runtime.Parent = runtimeParent
local alive = true
local connections, cleanups = {}, {}
local function connect(signal, callback)
    local connection = signal:Connect(function(...)
        if alive then callback(...) end
    end)
    table.insert(connections, connection)
    return connection
end
local function shutdownRuntime()
    if not alive then return end
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for i = #cleanups, 1, -1 do
        local ok, err = pcall(cleanups[i])
        if not ok then warn("[Cyber] Limpieza: " .. tostring(err)) end
    end
    runtime:Destroy()
end
local shutdown = Instance.new("BindableFunction")
shutdown.Name = "Shutdown"
shutdown.OnInvoke = shutdownRuntime
shutdown.Parent = runtime


-------------------------------------------------
-- 1. CONFIGURACIÓN Y RED LOCAL
-------------------------------------------------
local CONFIG = {
	NeuralPorSegundo = 1, NeuralPorAtaque = 6, Alivio = 30, Cargas = 10,
	AlturaGravity = 10, VelocidadAerea = 38, VelocidadCaida = 210,
	Advertencia = 3, RadioGravity = 45, RadioPulse = 38,
	SandeVelocidad = 100, SandeDuracion = 2.88,
	MaxResiduos = 24, ResiduosSimultaneos = 4, VidaResiduo = 0.48,
	DashDistancia = 22, DashCargas = 4, DashRecarga = 7,
	VueloVelocidad = 44, VueloDuracion = 20,
    GritoID = 109891992335274,
    SandeAudioID = 130840290979991, GravityAudioID = 137797799677635, PunchAudioID = 123089289852687,
    DashAudioID=104594227753486, AttractionAudioID=116385162980412,
    LaughAudioID=126229292760665, MusicAudioID=130330000022898, DialogueAudioID=138566469626743,
    MusicDuration=170,
    InjectAudioID = 97293299660553, InjectRecarga = 4,
    GritoDuracion = 4, NegroEspera = 3,
    UmbralFinal = 85, SandeFinalDuracion = 10,
    CabezaBajar = 0.65, CabezaPausa = 0.25, CabezaSubir = 0.30,
    RojoDuracion = 1.0, NegroDuracion = 1.2,
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

local function clock() return os.clock() end -- Un solo reloj para TODOS los temporizadores.

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

if not alive then return end

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

local mounting=setmetatable({}, {__mode="k"})
local function install(character)
	if not alive or player.Character ~= character or not character or character:FindFirstChild("CyberSkeletonEquipado") then return end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not alive or player.Character ~= character or not humanoid or not root or humanoid.Health <= 0 then return end

	if not template then
		warn("[Cyber] Modelo template no encontrado.")
		return
	end

	local suit = Instance.new("Model")
	suit.Name = "CyberSkeletonEquipado"
	local lowest = 0

	for _, def in ipairs(definitions) do
		local r6={RightUpperArm="Right Arm",LeftUpperArm="Left Arm",RightUpperLeg="Right Leg",LeftUpperLeg="Left Leg"}
        local limb = character:FindFirstChild(def.body) or character:FindFirstChild(r6[def.body]) or character:WaitForChild(def.body, 5)
		local model = template:FindFirstChild(def.name, true)
		if not alive or player.Character ~= character then suit:Destroy() return end
		if limb and model then
			local attachment = limb:FindFirstChild(def.attachment)
			local attachmentCF = attachment and attachment.CFrame or def.joint
			local conversion = attachmentCF * def.joint:Inverse() * def.reference:Inverse()
			local wasArchivable=model.Archivable
            model.Archivable=true
            local copy = model:Clone()
            model.Archivable=wasArchivable

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

	if #suit:GetChildren() ~= 4 then suit:Destroy() error("[Cyber] Faltan extremidades o modelos para completar el montaje") end
	local hidden = {
		LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
		RightUpperArm=true, RightLowerArm=true, RightHand=true,
		LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
		RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
        ["Right Arm"]=true,["Left Arm"]=true,["Right Leg"]=true,["Left Leg"]=true,
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
table.insert(cleanups, function() folder:Destroy() end)

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
		folder = f, pieces = pieces, start = clock(),
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

local ghosts = {}
local function clearGhosts()
    for _, model in ipairs(ghosts) do model:Destroy() end
    table.clear(ghosts)
end

local function residue(offset, hue)
    local char = player.Character
    if not alive or not char then return end
    local model = Instance.new("Model")
    model.Name = "ResiduoRGB"
    local tint = Color3.fromHSV(hue % 1, 0.8, 1)
    local count = 0
    for _, source in ipairs(char:GetDescendants()) do
        if source:IsA("BasePart") and source.Transparency < 0.95 then
            local archivable = source.Archivable
            local ok, p = pcall(function()
                source.Archivable = true
                return source:Clone()
            end)
            source.Archivable = archivable
            if ok and p then
                -- Quitar texturas y controladores; conservar la geometria de cada pieza.
                for _, child in ipairs(p:GetChildren()) do
                    if not child:IsA("DataModelMesh") then child:Destroy()
                    elseif child:IsA("SpecialMesh") then
                        child.TextureId = ""
                        child.VertexColor = Vector3.one
                    end
                end
                p.Anchored = true
                p.CanCollide = false
                p.CanTouch = false
                p.CanQuery = false
                p.CastShadow = false
                p.LocalTransparencyModifier = 0
                p.Transparency = 0.38
                p.Color = tint
                p.Material = Enum.Material.Neon
                p.MaterialVariant = ""
                if p:IsA("MeshPart") then p.TextureID = "" end
                if p:IsA("UnionOperation") then p.UsePartColor = true end
                p.CFrame = offset * source.CFrame
                p.Parent = model
                TweenService:Create(p, TweenInfo.new(CONFIG.VidaResiduo), {Transparency = 1}):Play()
                count = count + 1
                if count >= 200 then break end
            end
        end
    end
    if count == 0 then model:Destroy() return end
    model.Parent = folder
    table.insert(ghosts, model)
    while #ghosts > CONFIG.ResiduosSimultaneos do table.remove(ghosts, 1):Destroy() end
    Debris:AddItem(model, CONFIG.VidaResiduo + 0.05)
end

-- Dos propulsores azules anclados visualmente a la espalda, sin agregar fuerzas.
local jetsRoot
local jets = {}
local function clearJets()
    for _, item in ipairs(jets) do item:Destroy() end
    table.clear(jets)
    jetsRoot = nil
end
local function updateJets(root)
    if state.mode ~= "Flight" or not root then clearJets() return end
    if jetsRoot == root then
        local t=clock()
        for _, item in ipairs(jets) do
            if item.Name=="CyberThrusterTip" then
                item.Position=Vector3.new(item.Position.X,-1.3,6.4+math.sin(t*27+item.Position.X)*1.1)
            elseif item.Name=="CyberThrusterStart" then
                for _, fx in ipairs(item:GetChildren()) do
                    if fx:IsA("Beam") then fx.Width0=(fx.Name=="Core" and 0.4 or 1.2)*(0.85+0.15*math.sin(t*35)) end
                    if fx:IsA("PointLight") then fx.Brightness=1.6+0.7*math.sin(t*21) end
                end
            end
        end
        return
    end
    clearJets()
    jetsRoot = root
    for _, side in ipairs({-1, 1}) do
        local start = Instance.new("Attachment")
        start.Name = "CyberThrusterStart"
        start.Position = Vector3.new(side * 1.1, 0.4, 1.2)
        start.Parent = root
        table.insert(jets, start)
        local tip = Instance.new("Attachment")
        tip.Name = "CyberThrusterTip"
        tip.Position = Vector3.new(side * 1.1, -1.3, 7)
        tip.Parent = root
        table.insert(jets, tip)
        local beam = Instance.new("Beam")
        beam.Attachment0 = start
        beam.Attachment1 = tip
        beam.FaceCamera = true
        beam.Width0 = 1.1
        beam.Width1 = 0.05
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Color = ColorSequence.new(Color3.fromRGB(220,255,255), Color3.fromRGB(30,125,255))
        beam.Transparency = NumberSequence.new(0.05,1)
        beam.Parent = start
        local core = beam:Clone()
        core.Name="Core"
        core.Width0 = 0.38
        core.Width1 = 0.02
        core.Color = ColorSequence.new(Color3.fromRGB(235,255,255))
        core.Parent = start
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(70,200,255)
        light.Brightness = 1.5
        light.Range = 9
        light.Parent = start
        local sparks=Instance.new("ParticleEmitter")
        sparks.Texture="rbxasset://textures/particles/sparkles_main.dds"
        sparks.Color=ColorSequence.new(Color3.fromRGB(200,255,255),Color3.fromRGB(25,140,255))
        sparks.EmissionDirection=Enum.NormalId.Back
        sparks.Lifetime=NumberRange.new(0.12,0.3) sparks.Speed=NumberRange.new(18,32)
        sparks.Rate=35 sparks.SpreadAngle=Vector2.new(9,9) sparks.LightEmission=1
        sparks.Size=NumberSequence.new(0.25,0)
        sparks.Transparency=NumberSequence.new(0.1,1)
        sparks.Parent=start
    end
end
table.insert(cleanups, clearJets)

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

local function resetScreen()
    flashEnd = 0
    color.Enabled = false
    blur.Size = 0
    blur.Enabled = false
end
local function stopSande()
    local hum = state.sandeHum
    if hum and hum.Parent and state.sandeWalk ~= nil then
        hum.WalkSpeed = state.sandeWalk
    end
    state.sandeHum = nil
    state.sandeWalk = nil
    state.sandeEnd = 0
    sequences[player] = nil
    setAttr("SandeEnd", 0)
end
table.insert(cleanups, function()
    stopSande()
    clearGhosts()
    resetScreen()
    color:Destroy()
    blur:Destroy()
end)
resetScreen()


-- Finale: audio, duplicaciones verdes y fundido local de muerte.
local finale = {used = false, phase = nil}
-- Retirar solo overlays propios que pudieran quedar de versiones anteriores.
for _, old in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
    if old.Name=="CyberFinaleOverlay" then old:Destroy() end
end
local deathGui = Instance.new("ScreenGui")
deathGui.Name = "CyberFinaleOverlay"
deathGui.IgnoreGuiInset = true
deathGui.ResetOnSpawn = false
deathGui.DisplayOrder = 1000
deathGui.Enabled=false
deathGui.Parent = player:WaitForChild("PlayerGui")
local redVeil = Instance.new("Frame")
redVeil.Size = UDim2.fromScale(1,1)
redVeil.BackgroundColor3 = Color3.fromRGB(165,0,15)
redVeil.BackgroundTransparency = 1
redVeil.BorderSizePixel = 0
redVeil.Parent = deathGui
local blackVeil = redVeil:Clone()
blackVeil.Name = "Negro"
blackVeil.BackgroundColor3 = Color3.new(0,0,0)
blackVeil.ZIndex = 2
blackVeil.Parent = deathGui
local countdown = Instance.new("TextLabel")
countdown.Size = UDim2.new(0.8,0,0,36)
countdown.Position = UDim2.fromScale(0.1,0.76)
countdown.BackgroundTransparency = 1
countdown.Font = Enum.Font.GothamBlack
countdown.TextSize = 18
countdown.TextColor3 = Color3.fromRGB(100,255,160)
countdown.Text = ""
countdown.ZIndex = 3
countdown.Parent = deathGui
local overlayUntil=0
local overlaySerial=0
local function hideFinalOverlay()
    deathGui.Enabled=false
    redVeil.BackgroundTransparency=1
    blackVeil.BackgroundTransparency=1
    countdown.Text=""
    overlayUntil=0
end
local function leaseOverlay(seconds)
    overlaySerial=overlaySerial+1
    local serial=overlaySerial
    overlayUntil=clock()+seconds
    deathGui.Enabled=true
    task.delay(seconds,function()
        if alive and serial==overlaySerial then hideFinalOverlay() end
    end)
end
-- Independiente del controlador de ataques: siempre libera el fundido.
connect(RunService.Heartbeat,function()
    if overlayUntil>0 and clock()>=overlayUntil then hideFinalOverlay() end
    if finale.phase~="Dead" and finale.phase~="AfterIntro" then
        blackVeil.BackgroundTransparency=1
    end
end)
local scream = Instance.new("Sound")
scream.Name = "CyberDavidScream"
scream.SoundId = "rbxassetid://" .. CONFIG.GritoID
scream.Volume = 0.8
scream.Looped = false
scream.Parent = game:GetService("SoundService")
task.spawn(function()
    local ok, err = pcall(function()
        game:GetService("ContentProvider"):PreloadAsync({scream})
    end)
    if alive and (not ok or not scream.IsLoaded) then
        warn("[Cyber] No se pudo precargar el grito. Revisa permisos del audio. " .. tostring(err or ""))
    end
end)
local abilitySounds = {}
for name, id in pairs({Sandevistan=CONFIG.SandeAudioID, Gravity=CONFIG.GravityAudioID, Punch=CONFIG.PunchAudioID, Inject=CONFIG.InjectAudioID, Dash=CONFIG.DashAudioID, Atraction=CONFIG.AttractionAudioID, Laugh=CONFIG.LaughAudioID, Music=CONFIG.MusicAudioID, Dialogue=CONFIG.DialogueAudioID}) do
    local sound=Instance.new("Sound")
    sound.Name="CyberAudio"..name
    sound.SoundId="rbxassetid://"..id
    sound.Volume=0.7
    sound.Looped=false
    sound.Parent=game:GetService("SoundService")
    abilitySounds[name]=sound
end
local function playAbilitySound(name)
    local sound=abilitySounds[name]
    if sound then sound:Stop() sound.TimePosition=0 sound:Play() end
end
local function stopAbilitySounds()
    for _, sound in pairs(abilitySounds) do sound:Stop() end
end
task.spawn(function()
    local list={}
    for _, sound in pairs(abilitySounds) do table.insert(list,sound) end
    pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)
table.insert(cleanups,function()
    for _, sound in pairs(abilitySounds) do sound:Destroy() end
end)
local headEchoes = {}
local function clearHeadEchoes()
    for _, echo in ipairs(headEchoes) do echo.model:Destroy() end
    table.clear(headEchoes)
end
local function headBurst(char, head)
    clearHeadEchoes()
    if not head then return end
    local camera = workspace.CurrentCamera
    local right = camera and camera.CFrame.RightVector or head.CFrame.RightVector
    local up = camera and camera.CFrame.UpVector or Vector3.new(0,1,0)
    local sources = {head}
    local headTypes={Hat=true,Hair=true,Face=true,Eyebrow=true,Eyelash=true}
    for _, accessory in ipairs(char:GetChildren()) do
        if accessory:IsA("Accessory") then
            local onHead=headTypes[accessory.AccessoryType.Name] or false
            for _, item in ipairs(accessory:GetDescendants()) do
                if item:IsA("JointInstance") and (item.Part0==head or item.Part1==head) then onHead=true end
                if item:IsA("Attachment") and head:FindFirstChild(item.Name) then onHead=true end
            end
            if onHead then
                for _, part in ipairs(accessory:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency<1 then table.insert(sources,part) end
                end
            end
        end
    end
    for directionIndex, direction in ipairs({up,-up,right,-right}) do
        for layer = 1,3 do
            local model = Instance.new("Model")
            model.Name = "EcoVerdeCabeza"
            local parts = {}
            for _, source in ipairs(sources) do
                local original = source.Archivable
                local ok,p = pcall(function() source.Archivable=true return source:Clone() end)
                source.Archivable=original
                if ok and p then
                    for _, child in ipairs(p:GetChildren()) do
                        if not child:IsA("DataModelMesh") and not child:IsA("Decal") then child:Destroy() end
                    end
                    p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
                    p.LocalTransparencyModifier=0 p.CastShadow=false
                    p.Color=Color3.fromRGB(45,255,120) p.Material=Enum.Material.Neon
                    if p:IsA("MeshPart") then p.TextureID="" end
                    for _, child in ipairs(p:GetDescendants()) do
                        if child:IsA("SpecialMesh") then child.TextureId="" end
                        if child:IsA("Decal") then child.Transparency=1 end
                    end
                    p.Transparency=0.35
                    p.CFrame=source.CFrame
                    p.Parent=model
                    table.insert(parts,{part=p,offset=head.CFrame:ToObjectSpace(source.CFrame)})
                end
            end
            model.Parent=folder
            table.insert(headEchoes,{model=model,parts=parts,head=head,start=clock(),direction=direction,layer=layer,hue=directionIndex*0.17+layer*0.1})
        end
    end
end
local function updateHeadEchoes(now)
    for i=#headEchoes,1,-1 do
        local echo=headEchoes[i]
        local elapsed=now-echo.start
        local p=((elapsed+ (echo.layer-1)*0.22)%0.85)/0.85
        if elapsed>=CONFIG.GritoDuracion or not echo.head.Parent then echo.model:Destroy() table.remove(headEchoes,i)
        else
            local displacement=echo.direction*(3.4*(1-(1-p)^3))
            for _,data in ipairs(echo.parts) do
                data.part.CFrame=CFrame.new(displacement)*echo.head.CFrame*data.offset
                data.part.Transparency=0.3+p*0.7
                data.part.Color=Color3.fromHSV((echo.hue+elapsed*0.35)%1,0.8,1)
            end
        end
    end
end
table.insert(cleanups,function() clearHeadEchoes() scream:Destroy() deathGui:Destroy() end)

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
	local char, hum, root = state.motionChar, state.motionHum, state.motionRoot
    if not char then char, hum, root = getChar() end
    setVisibility(char, true)
    clearJets()
	if state.ownsMotion then
		if root then root.Anchored = state.oldAnchored end
		if hum then
			hum.AutoRotate = state.oldRotate
			hum.WalkSpeed = state.oldWalk
		end
		state.ownsMotion = false
	end
	state.input = Vector3.zero
    state.motionChar, state.motionHum, state.motionRoot = nil, nil, nil
    state.hideAt = nil
    setMode("Idle")
end

table.insert(cleanups, finishMotion)

local function startMotion(m)
	local char, hum, root = getChar()
	if not char or root.Anchored or state.ownsMotion then return false end
	state.oldAnchored, state.oldRotate, state.oldWalk = root.Anchored, hum.AutoRotate, hum.WalkSpeed
	state.ownsMotion = true
    state.motionChar, state.motionHum, state.motionRoot = char, hum, root
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


-- Animacion procedural de articulaciones y efectos locales con limites de piezas.
local combat = {kind=nil,stage=1,nextLaugh=0,rocks={},motors={},char=nil,walkPhase=0}
do
    local function surface(position)
        local char=player.Character
        local hit=workspace:Raycast(position+Vector3.new(0,8,0),Vector3.new(0,-100,0),getParams(char))
        return hit and hit.Position or position, hit
    end
    local function dust(position,amount)
        local p=createPart(folder,Color3.fromRGB(130,120,105),Vector3.one*0.1)
        p.Position=position p.Transparency=1
        local emitter=Instance.new("ParticleEmitter")
        emitter.Texture="rbxasset://textures/particles/smoke_main.dds"
        emitter.Color=ColorSequence.new(Color3.fromRGB(145,133,115))
        emitter.Lifetime=NumberRange.new(0.5,1.1)
        emitter.Speed=NumberRange.new(5,15)
        emitter.SpreadAngle=Vector2.new(80,80)
        emitter.Rate=0 emitter.Drag=4
        emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,5)})
        emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.55),NumberSequenceKeypoint.new(1,1)})
        emitter.Parent=p emitter:Emit(amount or 14)
        Debris:AddItem(p,1.5)
    end
    local function wave(position,radius,tint,duration)
        local f=Instance.new("Folder") f.Name="CyberShockwave" f.Parent=folder
        for i=1,40 do
            local a=i*math.pi*2/40
            local p=createPart(f,tint,Vector3.new(0.25,0.12,0.8))
            p.CFrame=CFrame.new(position+Vector3.new(math.cos(a),0.1,math.sin(a)))*CFrame.Angles(0,-a,0)
            TweenService:Create(p,TweenInfo.new(duration or 0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                Position=position+Vector3.new(math.cos(a)*radius,0.15,math.sin(a)*radius),
                Size=Vector3.new(0.25,0.1,radius*0.15),Transparency=1
            }):Play()
        end
        Debris:AddItem(f,1)
    end
    combat.wave=wave combat.dust=dust
    local function newRock(position)
        local floor,hit=surface(position)
        local p=createPart(folder,hit and hit.Instance:IsA("BasePart") and hit.Instance.Color or Color3.fromRGB(90,85,80),Vector3.new(0.7+math.random(),0.5+math.random(),0.7+math.random()))
        p.Material=hit and hit.Material or Enum.Material.Concrete
        p.CFrame=CFrame.new(floor)*CFrame.Angles(math.random(),math.random(),math.random())
        return {part=p,ground=floor,origin=floor,rotation=p.CFrame.Rotation,start=clock()}
    end
    function combat.scatter(position,count)
        for i=1,count or 12 do
            local a=i*2.399
            local r=newRock(position+Vector3.new(math.cos(a)*3,0,math.sin(a)*3))
            r.mode="ballistic" r.origin=r.ground+Vector3.new(0,0.3,0)
            r.velocity=Vector3.new(math.cos(a)*12,12+math.random()*12,math.sin(a)*12)
            r.expire=clock()+1.8
            table.insert(combat.rocks,r)
        end
        dust(position,22)
    end
    function combat.restore()
        for motor,data in pairs(combat.motors) do
            if motor.Parent then motor.C0=data.base motor.Transform=CFrame.identity end
        end
    end
    function combat.reset()
        combat.restore()
        for _,r in ipairs(combat.rocks) do if r.part.Parent then r.part:Destroy() end end
        table.clear(combat.rocks) table.clear(combat.motors)
        if combat.field then combat.field:Destroy() combat.field=nil end
        if combat.kind then finishMotion() end
        combat.kind=nil combat.char=nil combat.stage=1 combat.queue=false combat.windowEnd=nil
        combat.nextLaugh=clock()+12
    end
    function combat.bind(char)
        if combat.char==char then return end
        combat.restore() table.clear(combat.motors) combat.char=char
        if not char then return end
        for _,m in ipairs(char:GetDescendants()) do
            if m:IsA("Motor6D") and m.Part1 then
                local n=m.Name:gsub(" ","")
                if n=="RightShoulder" or n=="LeftShoulder" or n=="RightHip" or n=="LeftHip" or n=="Neck" or n=="Waist" or n=="RootJoint" or n=="Root" or n=="RightElbow" or n=="LeftElbow" or n=="RightKnee" or n=="LeftKnee" then
                    combat.motors[m]={base=m.C0,key=n}
                end
            end
        end
    end
    function combat.start(kind,duration)
        if combat.kind then return false end
        if not startMotion("BodyAction") then return false end
        combat.kind=kind combat.startTime=clock() combat.duration=duration combat.hit=false
        combat.bind(player.Character)
        return true
    end
    function combat.finish()
        combat.kind=nil
        finishMotion()
        combat.restore()
    end
    function combat.liftRocks(root)
        for i=1,12 do
            local a=i*2.399
            local r=newRock(root.Position+root.CFrame.LookVector*(3+math.random()*4)+Vector3.new(math.cos(a)*3,0,math.sin(a)*3))
            r.mode="held" r.height=3+math.random()*2 r.group="combo"
            table.insert(combat.rocks,r)
        end
        combat.windowEnd=clock()+0.5 combat.stage=3
    end
    function combat.slamRocks()
        for _,r in ipairs(combat.rocks) do
            if r.group=="combo" and r.mode=="held" then
                r.mode="marked" r.start=clock() r.origin=r.part.Position
                r.part.Material=Enum.Material.Neon r.part.Color=Color3.fromRGB(65,235,255)
            end
        end
        combat.stage=1 combat.windowEnd=nil
    end
    function combat.updateRocks(now,root)
        for i=#combat.rocks,1,-1 do
            local r=combat.rocks[i]
            local p=r.part
            if not p.Parent then table.remove(combat.rocks,i)
            else
                local age=now-r.start
                if r.mode=="held" then
                    p.Position=r.ground+Vector3.new(0,r.height*math.min(age/0.16,1),0)
                    if combat.windowEnd and now>=combat.windowEnd and not combat.queue then
                        r.mode="fall" r.start=now r.origin=p.Position r.velocity=Vector3.new(0,-15,0)
                    end
                elseif r.mode=="marked" then
                    p.Transparency=0.1+0.25*(0.5+0.5*math.sin(now*24))
                    if age>=0.12 then r.mode="fall" r.start=now r.origin=p.Position r.velocity=Vector3.new(0,-120,0) end
                elseif r.mode=="orbit" and root then
                    local a=r.angle+age*7
                    local target=root.Position+Vector3.new(math.cos(a)*r.radius,math.sin(a*2)*1.2,math.sin(a)*r.radius)
                    p.CFrame=CFrame.new(r.origin:Lerp(target,math.min(age/0.4,1)))*CFrame.Angles(age*3,a,age)
                elseif r.mode=="fall" or r.mode=="ballistic" then
                    local target=r.origin+r.velocity*age+Vector3.new(0,-65*age*age,0)
                    local hit=workspace:Raycast(p.Position,target-p.Position,getParams(player.Character))
                    if hit then
                        p.Position=hit.Position+Vector3.new(0,p.Size.Y/2,0)
                        dust(hit.Position,5)
                        r.mode="rest" r.expire=r.expire or now+0.5
                    else p.Position=target end
                end
                if r.expire and now>=r.expire then p:Destroy() table.remove(combat.rocks,i) end
            end
        end
        if combat.windowEnd and now>=combat.windowEnd and not combat.queue then combat.windowEnd=nil combat.stage=1 end
    end
    function combat.update(dt)
        local now=clock()
        local char,hum,root=getChar()
        combat.bind(char)
        combat.updateRocks(now,root)
        if not char then if combat.kind then combat.reset() end return end
        local k=combat.kind
        if k then
            local t=now-combat.startTime
            if k=="Punch1" and t>=0.95 and not combat.hit then
                combat.hit=true
                local ground=surface(root.Position+root.CFrame.LookVector*5)
                combat.scatter(ground,14) wave(ground,12,Color3.fromRGB(255,75,55),0.4)
                playAbilitySound("Punch")
            elseif k=="Punch2" then
                if t<0.7 then moveChar(root.CFrame.LookVector*math.min(dt,0.08)*4) end
                if t>=0.65 and not combat.hit then
                    combat.hit=true combat.liftRocks(root) playAbilitySound("Punch")
                end
            elseif k=="Pulse" and t>=0.6 and not combat.hit then
                combat.hit=true
                local ground=surface(root.Position)
                wave(ground,CONFIG.RadioPulse,Color3.fromRGB(255,65,45),0.6)
                wave(ground+Vector3.new(0,0.3,0),CONFIG.RadioPulse*0.75,Color3.fromRGB(70,225,255),0.8)
                combat.scatter(ground,16)
            elseif k=="Atraction" then
                if t<0.5 then moveChar(Vector3.new(0,math.min(dt,0.08)*2.6,0)) end
                if combat.field then
                    combat.field.Position=root.Position
                    local size=math.min(t/0.4,1)*(17+math.sin(t*9)*0.4)
                    combat.field.Size=Vector3.one*math.max(0.1,size)
                end
                if t>=3 and not combat.hit then
                    combat.hit=true
                    for _,r in ipairs(combat.rocks) do
                        if r.mode=="orbit" then
                            local dir=r.part.Position-root.Position
                            r.mode="ballistic" r.origin=r.part.Position r.start=now r.expire=now+2
                            r.velocity=dir.Unit*22+Vector3.new(0,10,0)
                        end
                    end
                    if combat.field then combat.field:Destroy() combat.field=nil end
                    wave(surface(root.Position),22,Color3.fromRGB(255,60,80),0.55)
                end
            end
            if t>=combat.duration then
                combat.finish()
                if k=="Punch1" then combat.stage=2 combat.comboExpires=now+4 end
                if k=="Punch2" and combat.queue then
                    combat.queue=false combat.slamRocks() combat.start("Punch3",0.5)
                end
            end
        elseif not finale.phase and state.mode=="Idle" and state.charges<=4 and now>=combat.nextLaugh then
            combat.nextLaugh=now+math.random(10,16)
            if state.sandeEnd<=now and math.random()<0.55 and combat.start("Laugh",5) then playAbilitySound("Laugh") end
        end
        if combat.stage==2 and combat.comboExpires and now>=combat.comboExpires then combat.stage=1 end
    end
    -- Poses locales de torso, hombros, codos, caderas y cuello; no son solo particulas.
    connect(RunService.PreSimulation,function(dt)
        local char,hum,root=getChar()
        if not char then return end
        combat.bind(char)
        local k=combat.kind
        local t=clock()-(combat.startTime or clock())
        local pose={}
        local function angle(x,y,z) return CFrame.Angles(math.rad(x or 0),math.rad(y or 0),math.rad(z or 0)) end
        if k=="Punch1" then
            local a=t<0.8 and t/0.8 or (1-math.clamp((t-0.8)/0.18,0,1))
            pose.RightShoulder=angle(-155*a-35,0,15)
            pose.RightElbow=angle(-35*a,0,0) pose.Waist=angle(t<0.8 and -12*a or 28,0,-8)
            pose.LeftShoulder=angle(-12,0,-20) pose.Neck=angle(10,0,0)
        elseif k=="Punch2" then
            local p=math.clamp(t/0.75,0,1)
            pose.LeftShoulder=angle(-105+140*p,0,-18)
            pose.LeftElbow=angle(-35,0,0) pose.Waist=angle(28-15*p,-20*p,0)
            pose.RightHip=angle(math.sin(t*9)*18,0,0) pose.LeftHip=angle(-math.sin(t*9)*18,0,0)
        elseif k=="Punch3" then
            pose.RightShoulder=angle(-90+150*math.clamp(t/0.3,0,1),0,10)
            pose.LeftShoulder=angle(-90+150*math.clamp(t/0.3,0,1),0,-10)
            pose.Waist=angle(20,0,0)
        elseif k=="Laugh" then
            local p=math.min(t/0.6,1)*math.min((5-t)/0.5,1)
            pose.Neck=angle(-32*p+math.sin(t*17)*3,0,0)
            pose.Waist=angle(-12*p+math.sin(t*14)*2,0,0)
            pose.RightShoulder=angle(15,0,40*p+math.sin(t*7)*3)
            pose.LeftShoulder=angle(15,0,-40*p-math.sin(t*7)*3)
            pose.RightElbow=angle(-12,0,0) pose.LeftElbow=angle(-12,0,0)
        elseif k=="Atraction" then
            pose.RightShoulder=angle(-55,0,55) pose.LeftShoulder=angle(-55,0,-55)
            pose.Neck=angle(-18,0,0) pose.Waist=angle(-8,0,0)
            pose.RightHip=angle(-12,0,5) pose.LeftHip=angle(-12,0,-5)
        elseif k=="Pulse" then
            local a=math.clamp(t/0.6,0,1)
            pose.RightShoulder=angle(-110*a,0,30) pose.LeftShoulder=angle(-110*a,0,-30)
            pose.Waist=angle(-10+25*a,0,0)
        elseif combat.dashPoseEnd and clock()<combat.dashPoseEnd then
            pose.Waist=angle(28,0,0) pose.RightShoulder=angle(35,0,15) pose.LeftShoulder=angle(35,0,-15)
        elseif state.sandeEnd>clock() and not finale.neck then
            pose.Waist=angle(12,0,0) pose.RightShoulder=angle(20,0,10) pose.LeftShoulder=angle(20,0,-10)
        elseif state.mode=="Phase" then
            pose.RightShoulder=angle(-30,0,30) pose.LeftShoulder=angle(-30,0,-30) pose.Waist=angle(-8,0,0)
        elseif state.mode=="Warning" then
            pose.RightShoulder=angle(-130,0,25) pose.LeftShoulder=angle(-130,0,-25)
            pose.Waist=angle(-12,0,0)
        elseif state.mode=="Falling" then
            pose.RightShoulder=angle(-40,0,15) pose.LeftShoulder=angle(-40,0,-15)
            pose.Waist=angle(28,0,0) pose.RightHip=angle(-25,0,0) pose.LeftHip=angle(-25,0,0)
        elseif state.mode=="Flight" then
            pose.Waist=angle(15,0,0) pose.RightShoulder=angle(20,0,15) pose.LeftShoulder=angle(20,0,-15)
        elseif finale.phase=="AfterIntro" then
            pose.Neck=angle(-18*math.min((clock()-finale.afterStart)/2,1),0,0)
            pose.Waist=angle(-7,0,0) pose.RightShoulder=angle(8,0,10) pose.LeftShoulder=angle(8,0,-10)
        elseif (not finale.phase or finale.phase=="Music") and hum.MoveDirection.Magnitude>0.05 and state.sandeEnd<=clock() then
            combat.walkPhase=combat.walkPhase+dt*4.2
            local a=math.sin(combat.walkPhase)
            pose.RightShoulder=angle(a*13,0,9) pose.LeftShoulder=angle(-a*13,0,-9)
            pose.RightHip=angle(-a*22,0,0) pose.LeftHip=angle(a*22,0,0)
            pose.Waist=angle(6+math.abs(a)*2,0,a*2) pose.Neck=angle(-5,0,0)
        end
        for m,data in pairs(combat.motors) do
            if m.Parent then
                local target=pose[data.key]
                if target then
                    m.C0=m.C0:Lerp(data.base*target,1-math.exp(-dt*18))
                    m.Transform=CFrame.identity
                elseif not (data.key=="Neck" and finale.neck) then
                    m.C0=m.C0:Lerp(data.base,1-math.exp(-dt*16))
                end
            end
        end
    end)
    table.insert(cleanups,combat.reset)
end

-- Maquina de estados del Sandevistan final; no usa esperas encadenadas.
local function restoreFinalPose()
    if finale.neck and finale.neck.Parent and finale.neckC0 then finale.neck.C0=finale.neckC0 end
    finale.neck,finale.neckC0=nil,nil
end
local function restoreFinalCamera()
    local camera=finale.camera
    if camera and camera==workspace.CurrentCamera and finale.cameraType then
        camera.CameraType=finale.cameraType
        camera.FieldOfView=finale.fov
        local char=player.Character
        camera.CameraSubject=(char and char:FindFirstChildOfClass("Humanoid")) or finale.subject
        camera.CFrame=finale.cameraCF
    end
    finale.camera=nil
end
local function cancelFinale(resetLife)
    hideFinalOverlay()
    finale.musicElapsed=0
    overlaySerial=overlaySerial+1
    restoreFinalPose()
    restoreFinalCamera()
    if finale.phase then finishMotion() stopSande() resetScreen() end
    scream:Stop()
    stopAbilitySounds()
    clearHeadEchoes()
    finale.phase=nil
    finale.char=nil
    finale.deadline=nil
    if resetLife then finale.used=false end
    redVeil.BackgroundTransparency=1
    blackVeil.BackgroundTransparency=1
    countdown.Text=""
end
local function beginFinale()
    local char,hum,root=getChar()
    if not char or finale.used or finale.phase or state.charges~=0 or state.neural<CONFIG.UmbralFinal then return false end
    finale.used=true
    combat.reset()
    finishMotion()
    stopSande()
    resetScreen()
    clearGhosts()
    discardRing()
    finale.phase="Intro"
    finale.char,finale.hum,finale.root=char,hum,root
    finale.start=clock()
    state.neural=0 state.passive=0
    setAttr("Neural",0)
    -- Solo el cuello: sin romper articulaciones ni reemplazar la cabeza.
    for _, item in ipairs(char:GetDescendants()) do
        if item:IsA("Motor6D") and item.Name=="Neck" then
            finale.neck=item finale.neckC0=item.C0 break
        end
    end
    startMotion("FinalIntro")
    local camera=workspace.CurrentCamera
    if camera and camera.CameraType~=Enum.CameraType.Scriptable then
        finale.camera=camera finale.cameraType=camera.CameraType
        finale.subject=camera.CameraSubject finale.cameraCF=camera.CFrame finale.fov=camera.FieldOfView
        camera.CameraType=Enum.CameraType.Scriptable
        camera.FieldOfView=60
    end
    countdown.Text="LIMITE NEURAL // ULTIMA ACTIVACION"
    return true
end
local function startFinalSande(now)
    clearHeadEchoes()
    scream:Stop()
    restoreFinalPose()
    restoreFinalCamera()
    finishMotion()
    finale.phase="Active"
    finale.activeStart=now
    finale.deadline=now+CONFIG.SandeFinalDuracion
    state.sandeHum=finale.hum
    state.sandeWalk=finale.hum.WalkSpeed
    state.sandeEnd=finale.deadline
    finale.hum.WalkSpeed=CONFIG.SandeVelocidad
    setAttr("SandeEnd",state.sandeEnd)
    sequences[player]={char=finale.char,start=now,duration=CONFIG.SandeFinalDuracion,count=0}
    playAbilitySound("Sandevistan")
end
local function releaseScream(now)
    finale.phase="Scream"
    finale.screamEnd=now+CONFIG.GritoDuracion
    countdown.Text="LIMITE NEURAL // SOBRECARGA"
    -- La duracion no depende de la longitud ni de los permisos del audio.
    if scream.IsLoaded then
        scream.TimePosition=0
        scream:Play()
    else
        warn("[Cyber] Grito no disponible: la secuencia continuara sin audio.")
    end
    headBurst(finale.char,finale.char:FindFirstChild("Head"))
end
local function finalDeath(now)
    finale.phase="Dead"
    finale.deathStart=now
    combat.reset()
    finishMotion() stopSande() resetScreen() clearGhosts() clearHeadEchoes()
    restoreFinalPose() restoreFinalCamera()
    scream:Stop() stopAbilitySounds()
    leaseOverlay(3)
    local victim=finale.hum
    if victim and victim.Parent then victim.Health=0 end
end
local function beginAfterIntro(now)
    combat.reset() stopSande() resetScreen() clearGhosts() clearHeadEchoes()
    restoreFinalPose() restoreFinalCamera() stopAbilitySounds()
    finale.phase="AfterIntro" finale.afterStart=now
    startMotion("FinalDialogue")
    local camera=workspace.CurrentCamera
    if camera then
        finale.camera=camera finale.cameraType=camera.CameraType
        finale.subject=camera.CameraSubject finale.cameraCF=camera.CFrame finale.fov=camera.FieldOfView
        camera.CameraType=Enum.CameraType.Scriptable camera.FieldOfView=48
    end
    blackVeil.BackgroundTransparency=0
    leaseOverlay(3.1)
    playAbilitySound("Dialogue")
end
local function updateFinale(now)
    local phase=finale.phase
    if not phase then return end
    if player.Character~=finale.char then cancelFinale(true) return end
    if phase=="Dead" then
        local elapsed=now-finale.deathStart
        if elapsed>=3 then hideFinalOverlay() finale.phase=nil return end
        redVeil.BackgroundTransparency=1-math.clamp(elapsed/0.5,0,1)
        blackVeil.BackgroundTransparency=1-math.clamp((elapsed-0.5)/0.5,0,1)
        countdown.Text=""
        return
    end
    if not finale.hum.Parent or finale.hum.Health<=0 then cancelFinale(false) return end
    if phase=="Intro" then
        local elapsed=now-finale.start
        local lower=CONFIG.CabezaBajar
        local rise=lower+CONFIG.CabezaPausa
        local finish=rise+CONFIG.CabezaSubir
        local angle
        if elapsed<lower then angle=-38*math.clamp(elapsed/lower,0,1)
        elseif elapsed<rise then angle=-38
        else angle=-38+63*math.clamp((elapsed-rise)/CONFIG.CabezaSubir,0,1) end
        if finale.neck and finale.neck.Parent then finale.neck.C0=finale.neckC0*CFrame.Angles(math.rad(angle),0,0) end
        if elapsed>=finish then releaseScream(now) end
    elseif phase=="Scream" then
        if now>=finale.screamEnd then startFinalSande(now) end
    elseif phase=="Active" then
        if now>=finale.deadline then beginAfterIntro(now) return end
        countdown.Text=string.format("SANDEVISTAN FINAL // %.1f s",math.max(0,finale.deadline-now))
    elseif phase=="AfterIntro" then
        blackVeil.BackgroundTransparency=math.clamp((now-finale.afterStart)/1.2,0,1)
        if now-finale.afterStart>=3 then
            hideFinalOverlay() restoreFinalCamera() combat.restore() finishMotion()
            abilitySounds.Dialogue:Stop()
            finale.phase="Music" finale.musicStart=now finale.musicElapsed=0
            finale.audioLast=0 finale.audioChanged=now
            state.neural=100 setAttr("Neural",100)
            playAbilitySound("Music")
        end
    elseif phase=="Music" then
        local sound=abilitySounds.Music
        local wall=now-finale.musicStart
        local audio=sound.TimePosition
        if audio>finale.audioLast then finale.audioLast=audio finale.audioChanged=now end
        -- Sincronizar con la posicion real del audio; reloj de respaldo si no carga/se detiene.
        local elapsed=(sound.IsPlaying and audio>0 and now-finale.audioChanged<2) and audio or math.max(finale.musicElapsed,wall)
        finale.musicElapsed=math.max(finale.musicElapsed,elapsed)
        state.neural=100
        if finale.musicElapsed>=CONFIG.MusicDuration then finalDeath(now) return end
    end
    local camera=finale.camera
    local head=finale.char:FindFirstChild("Head")
    if camera and camera==workspace.CurrentCamera and head then
        local position=head.Position+finale.root.CFrame.LookVector*6+Vector3.new(0,0.5,0)
        camera.CFrame=CFrame.lookAt(position,head.Position)
    end
end
table.insert(cleanups,function() cancelFinale(false) end)

local function addNeural(amount)
	if finale.phase=="Music" then return true end
    if finale.phase then return false end
	local char, hum = getChar()
	state.neural = math.clamp(state.neural + amount, 0, 100)
	setAttr("Neural", state.neural)
	if beginFinale() then return false end
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
    playAbilitySound("Gravity")
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
	setCooldown("Inject", CONFIG.InjectRecarga)
    playAbilitySound("Inject")
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
	if startMotion("Flight") then updateJets(root) end
end

function actions.Sandevistan()
	local char, hum = getChar()
	if not char or state.mode ~= "Idle" or state.sandeEnd > clock() or not isReady("Sandevistan") then return end
	if not addNeural(CONFIG.NeuralPorAtaque) then return end
	state.sandeHum = hum
    state.sandeWalk = hum.WalkSpeed
    state.sandeEnd = clock() + CONFIG.SandeDuracion
	setAttr("SandeEnd", state.sandeEnd)
	hum.WalkSpeed = CONFIG.SandeVelocidad
	setCooldown("Sandevistan", CONFIG.SandeDuracion + 7)
    playAbilitySound("Sandevistan")
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
    playAbilitySound("Dash")
    combat.dashPoseEnd=clock()+0.22
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
    local char=getChar()
    if not char or state.mode~="Idle" or combat.kind or not isReady("Pulse") then return end
    if not addNeural(CONFIG.NeuralPorAtaque) then return end
    if combat.start("Pulse",1.1) then setCooldown("Pulse",7) end
end
function actions.Atraction()
    local char,hum,root=getChar()
    if not char or state.mode~="Idle" or combat.kind or not isReady("Atraction") then return end
    if not addNeural(CONFIG.NeuralPorAtaque) then return end
    if not combat.start("Atraction",3.05) then return end
    setCooldown("Atraction",9) playAbilitySound("Atraction")
    combat.field=createPart(folder,Color3.fromRGB(255,65,85),Vector3.one)
    combat.field.Shape=Enum.PartType.Ball combat.field.Transparency=0.93
    combat.field.Position=root.Position
    -- Escombros locales; no destruye ni arranca piezas del mapa.
    for i=1,22 do
        local a=i*math.pi*2/22
        local pos=root.Position+Vector3.new(math.cos(a)*14,-3,math.sin(a)*14)
        local p=createPart(folder,Color3.fromRGB(90,85,80),Vector3.one*(0.6+math.random()))
        p.Material=Enum.Material.Concrete p.Position=pos
        table.insert(combat.rocks,{part=p,mode="orbit",origin=pos,start=clock(),angle=a,radius=5+math.random()*3})
    end
end
function actions.Punch()
    local char=getChar()
    if not char then return end
    if combat.kind=="Punch2" then
        if not combat.queue then
            if not addNeural(CONFIG.NeuralPorAtaque) then return end
            combat.queue=true
        end
        return
    end
    if combat.kind or state.mode~="Idle" then return end
    if combat.stage==3 and combat.windowEnd and clock()<=combat.windowEnd then
        if not addNeural(CONFIG.NeuralPorAtaque) then return end
        combat.slamRocks() combat.start("Punch3",0.5) playAbilitySound("Punch")
        return
    end
    if not isReady("Punch") then return end
    if not addNeural(CONFIG.NeuralPorAtaque) then return end
    if combat.stage==2 then
        combat.queue=false combat.start("Punch2",0.8)
    else
        combat.stage=1
        if combat.start("Punch1",1.25) then setCooldown("Punch",1.9) end
    end
end

local function executeAction(actName)
	local char = getChar()
	if not alive or not char or (finale.phase and finale.phase~="Music") then return end
    if combat.kind and actName~="Punch" then return end
	if actions[actName] then
		actions[actName]()
	end
end

-------------------------------------------------
-- 6. CICLO DE EJECUCIÓN (HEARTBEAT Y RENDERSTEPPED)
-------------------------------------------------
local deathConnection
local boundCharacter
local function resetCharacterState(char)
    boundCharacter=char
    combat.reset()
    hideFinalOverlay()
    stopAbilitySounds()
    cancelFinale(true)
    if deathConnection then deathConnection:Disconnect() deathConnection = nil end
    finishMotion()
    stopSande()
    resetScreen()
    clearGhosts()
    discardRing()
    state.neural, state.charges, state.dash = 0, CONFIG.Cargas, CONFIG.DashCargas
    state.passive, state.lastInput, state.warningEnd = 0, 0, 0
    table.clear(state.cooldowns)
    table.clear(sequences)
    setAttr("Neural", 0)
    setAttr("Charges", CONFIG.Cargas)
    setAttr("DashCharges", CONFIG.DashCargas)
    setAttr("WarningEnd", 0)
    player:SetAttribute("CyberLocalLift", 0)
    for _, key in ipairs({"Sandevistan","Dash","DashTap","Gravity","Fly","Pulse","Punch","Atraction","Inject"}) do
        setAttr(key .. "Ready", 0)
    end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if not alive or player.Character ~= char or not hum then return end
        deathConnection = hum.Died:Connect(function()
            if not alive or player.Character ~= char then return end
            if finale.phase ~= "Dead" then cancelFinale(false) end
            combat.reset()
            finishMotion()
            stopSande()
            resetScreen()
            clearGhosts()
            discardRing()
        end)
        if mounting[char] then return end
        mounting[char]=true
        for attempt=1,6 do
            if not alive or player.Character~=char or hum.Health<=0 then break end
            local ok,err=pcall(install,char)
            if ok and char:FindFirstChild("CyberSkeletonEquipado") then break end
            if not ok then warn("[Cyber] Reintentando montaje: "..tostring(err)) end
            task.wait(1)
        end
        mounting[char]=nil
    end)
end
table.insert(cleanups, function() if deathConnection then deathConnection:Disconnect() end end)
connect(player.CharacterAdded, resetCharacterState)
if player.Character then resetCharacterState(player.Character) end

connect(RunService.Heartbeat, function(dt)
    if player.Character and player.Character~=boundCharacter then resetCharacterState(player.Character) end
	local now = clock()
    updateFinale(now)
    combat.update(dt)
	local char, hum, root = getChar()

	if char and hum and root then
		state.passive = finale.phase and 0 or (state.passive + dt)
		if state.passive >= 1 then
			local ticks = math.floor(state.passive)
			state.passive = state.passive - ticks
			addNeural(CONFIG.NeuralPorSegundo * ticks)
		end

		if state.dash == 0 and state.cooldowns.Dash and isReady("Dash") then
			state.dash = CONFIG.DashCargas
			setAttr("DashCharges", state.dash)
		end

		if (not finale.phase or finale.phase=="Music") and state.sandeEnd > 0 and now >= state.sandeEnd then
			stopSande()
		end

		if hum.Health <= 0 then return end

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
                combat.scatter(getGroundPos(char,root,hum),24)
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
        stopSande()
        resetScreen()
        clearJets()
    end
end)

connect(RunService.RenderStepped, function()
	local t = clock()
    updateFinale(t)
    updateHeadEchoes(t)
    if state.sandeEnd<=t then abilitySounds.Sandevistan:Stop() end
	local currentChar, currentHum, currentRoot = getChar()
    local active = currentHum ~= nil and state.sandeEnd > t
    local flash = currentHum ~= nil and t < flashEnd
    -- Actualizar antes de generar cualquier otro efecto: no deja filtros permanentes.
    color.TintColor = finale.phase == "Active" and Color3.fromRGB(165,255,195) or Color3.fromRGB(180,240,255)
    color.Enabled = active or flash
    blur.Enabled = flash
    blur.Size = flash and 7 or 0
    updateJets(currentRoot)


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
		if player.Character ~= s.char or elapsed >= s.duration or state.sandeEnd <= t then
			sequences[who] = nil
		elseif s.count < CONFIG.MaxResiduos and elapsed >= s.count * (s.duration / CONFIG.MaxResiduos) then
			s.count = s.count + 1
			residue(CFrame.identity, s.count / CONFIG.MaxResiduos)
		end
	end


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

table.insert(cleanups, function() gui:Destroy() end)

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
	connect(b.Activated, function()
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
	connect(b.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			held[input] = item[2]
			player:SetAttribute("CyberLocalLift", item[2])
		end
	end)
end

connect(UIS.InputEnded, function(input)
	if held[input] then
		held[input] = nil
		player:SetAttribute("CyberLocalLift", 0)
	end
end)

connect(UIS.WindowFocusReleased, function()
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
	round(fill, 3)
    create("UIGradient",fill,{Color=ColorSequence.new(color,Color3.fromRGB(225,255,255)),Rotation=0})
    for i=1,19 do
        create("Frame",back,{Position=UDim2.fromScale(i/20,0),Size=UDim2.new(0,2,1,0),BackgroundColor3=Color3.fromRGB(3,12,19),BackgroundTransparency=0.3,BorderSizePixel=0,ZIndex=2})
    end
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
connect(inject.Activated, function()
	executeAction("Inject")
end)

-- Visor optico: datos reales y decoracion de baja opacidad.
local optic=create("Frame",gui,{Name="VisorOptico",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=0})
for side=0,1 do
    for i=0,15 do
        create("Frame",optic,{Position=UDim2.new(side,side==1 and -10 or 6,0.24+i*0.029,0),Size=UDim2.fromOffset(i%4==0 and 12 or 5,1),BackgroundColor3=CYAN,BackgroundTransparency=0.55,BorderSizePixel=0})
    end
    for bottom=0,1 do
        local x=side==1 and -48 or 6
        create("Frame",optic,{Position=UDim2.new(side,x,bottom,bottom==1 and -8 or 3),Size=UDim2.fromOffset(42,2),BackgroundColor3=CYAN,BorderSizePixel=0})
        create("Frame",optic,{Position=UDim2.new(side,side==1 and -8 or 6,bottom,bottom==1 and -42 or 3),Size=UDim2.fromOffset(2,34),BackgroundColor3=CYAN,BorderSizePixel=0})
    end
end
local telemetry=create("TextLabel",gui,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-10),Size=UDim2.new(0.65,0,0,24),BackgroundColor3=Color3.fromRGB(3,12,20),BackgroundTransparency=0.35,BorderSizePixel=0,TextColor3=CYAN,Font=Enum.Font.Code,TextSize=11,Text=""})
round(telemetry,4)
local scan=create("Frame",optic,{Size=UDim2.new(1,0,0,1),BackgroundColor3=CYAN,BackgroundTransparency=0.92,BorderSizePixel=0})
local scales={create("UIScale",left,{}),create("UIScale",right,{})}
for _,panel in ipairs({left,right}) do
    panel.BackgroundColor3=Color3.fromRGB(3,10,19)
    create("UIGradient",panel,{Color=ColorSequence.new(Color3.fromRGB(150,215,235),Color3.fromRGB(35,60,90)),Rotation=70})
    create("Frame",panel,{Position=UDim2.fromOffset(12,51),Size=UDim2.fromOffset(216,1),BackgroundColor3=CYAN,BackgroundTransparency=0.4,BorderSizePixel=0})
end
local signalBars={}
for i=1,24 do
    signalBars[i]=create("Frame",right,{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromOffset(12+(i-1)*9,228),Size=UDim2.fromOffset(5,4),BackgroundColor3=CYAN,BackgroundTransparency=0.35,BorderSizePixel=0})
end
local uiAccumulator=0
connect(RunService.RenderStepped,function(dt)
    uiAccumulator=uiAccumulator+dt
    if uiAccumulator<0.08 then return end
    uiAccumulator=0
    local t=clock()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if pg and gui.Parent~=pg then gui.Parent=pg end
    if pg and deathGui.Parent~=pg then deathGui.Parent=pg end
    local camera=workspace.CurrentCamera
    local view=camera and camera.ViewportSize or Vector2.new(1280,720)
    local scale=math.clamp(math.min(view.X/1100,view.Y/650),0.60,1)
    for _,item in ipairs(scales) do item.Scale=scale end
    bar.Size=UDim2.new(1,-24,0,82)
    scan.Position=UDim2.fromScale(0,(t*0.09)%1)
    local char,hum,root=getChar()
    telemetry.Text=string.format("ARASAKA // MK.07   |   %s   |   VEL %03d   |   %s",state.mode,root and math.floor(root.AssemblyLinearVelocity.Magnitude) or 0,char and "ENLACE ACTIVO" or "ESPERANDO AVATAR")
    for i,item in ipairs(signalBars) do
        item.Size=UDim2.fromOffset(5,3+(1+math.sin(t*4+i*0.8))*7)
        item.BackgroundColor3=state.neural>=80 and RED or CYAN
    end
    local remaining=math.max(0,(state.cooldowns.Inject or 0)-t)
    inject.Active=char~=nil and (not finale.phase or finale.phase=="Music") and state.charges>0 and remaining<=0
    inject.AutoButtonColor=inject.Active
    inject.Text=remaining>0 and string.format("INYECTANDO // %.1f s",remaining) or (state.charges>0 and "INYECTAR [-30%] [R]" or "SIN CARGAS")
    inject.BackgroundColor3=remaining>0 and Color3.fromRGB(8,32,30) or Color3.fromRGB(15,60,40)
end)

-- Teclado
connect(UIS.InputBegan, function(input, processed)
	if processed or UIS:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 then executeAction("Punch") return end
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

connect(player:GetAttributeChangedSignal("CyberNeural"), updateUI)
connect(player:GetAttributeChangedSignal("CyberCharges"), updateUI)
updateUI()

connect(RunService.RenderStepped, function()
	local now = clock()
	local mode = state.mode
	lift.Visible = (mode == "Flight")
	for action, b in pairs(buttons) do
		local leftTime = math.max(0, (state.cooldowns[action] or 0) - now)
		local statusText = leftTime > 0 and string.format("%.1fs", leftTime) or "LISTO"
		if action == "Dash" then
            statusText = state.dash .. "/" .. CONFIG.DashCargas
            if leftTime > 0 then statusText = statusText .. " " .. string.format("%.1fs", leftTime) end
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
		if finale.phase and finale.phase~="Music" then
            statusText = action == "Sandevistan" and finale.phase == "Active"
                and string.format("%.1fs",math.max(0,finale.deadline-now)) or "BLOQUEADO"
        end
        if action=="Punch" and not finale.phase then
            if combat.kind=="Punch2" then statusText=combat.queue and "REMATE LISTO" or "PULSA REMATE"
            elseif combat.stage==3 then statusText="REMATAR"
            elseif combat.stage==2 and leftTime<=0 then statusText="ARRASTRAR"
            elseif combat.kind=="Punch1" then statusText="IMPACTO" end
        end
        b.status.Text = statusText
	end
end)

-- Telemetria de colapso: solo se habilita durante la fase musical.
do
    local failure=create("Frame",gui,{Name="ColapsoNeural",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(130,0,12),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=30,Visible=false})
    local edges={}
    for _,d in ipairs({{UDim2.fromScale(0,0),UDim2.new(1,0,0,18)},{UDim2.new(0,0,1,-18),UDim2.new(1,0,0,18)},{UDim2.fromScale(0,0),UDim2.new(0,18,1,0)},{UDim2.new(1,-18,0,0),UDim2.new(0,18,1,0)}}) do
        table.insert(edges,create("Frame",failure,{Position=d[1],Size=d[2],BackgroundColor3=RED,BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=31}))
    end
    local banner=create("TextLabel",failure,{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,88),Size=UDim2.new(0.62,0,0,32),BackgroundColor3=Color3.fromRGB(45,0,10),BackgroundTransparency=0.25,TextColor3=RED,Text="",Font=Enum.Font.Code,TextSize=14,BorderSizePixel=0,ZIndex=32})
    local timer=create("TextLabel",failure,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-42),Size=UDim2.new(0.7,0,0,26),BackgroundTransparency=1,TextColor3=RED,Text="",Font=Enum.Font.Code,TextSize=13,ZIndex=32})
    local glitches={}
    for i=1,7 do
        glitches[i]=create("Frame",failure,{Size=UDim2.new(0.15+i*0.035,0,0,1+i%3),BackgroundColor3=RED,BackgroundTransparency=0.85,BorderSizePixel=0,ZIndex=31})
    end
    local lastBucket=-1
    local accumulator=0
    connect(RunService.RenderStepped,function(dt)
        accumulator=accumulator+dt
        if accumulator<0.08 then return end
        accumulator=0
        local active=finale.phase=="Music"
        failure.Visible=active
        if not active then
            left.Position=UDim2.new(0,12,0,94) right.Position=UDim2.new(1,-12,0,94)
            return
        end
        local elapsed=finale.musicElapsed or 0
        local progress=math.clamp(elapsed/CONFIG.MusicDuration,0,1)
        local pulse=(math.sin(clock()*math.pi*2*1.3)+1)/2
        failure.BackgroundTransparency=1-progress*0.28
        for _,edge in ipairs(edges) do edge.BackgroundTransparency=0.88-progress*0.4-pulse*0.12 end
        banner.Text=progress<0.4 and "WARNING // INESTABILIDAD NEURAL" or progress<0.8 and "CRITICAL // FALLO DE SINCRONIZACION" or "FATAL // COLAPSO INMINENTE"
        banner.TextTransparency=0.05+pulse*progress*0.3
        local remaining=math.max(0,CONFIG.MusicDuration-elapsed)
        timer.Text=string.format("NEURAL LOAD 100%% // LIMITE %02d:%02d // SISTEMA DEGRADADO",math.floor(remaining/60),math.floor(remaining%60))
        local bucket=math.floor(clock()*2)
        if bucket~=lastBucket then
            lastBucket=bucket
            for _,stripe in ipairs(glitches) do
                stripe.Position=UDim2.fromScale(math.random()*0.7,math.random())
                stripe.Visible=math.random()<0.15+progress*0.65
            end
            local offset=math.random()<progress and math.random(-3,3) or 0
            left.Position=UDim2.new(0,12+offset,0,94)
            right.Position=UDim2.new(1,-12-offset,0,94)
            medical.Text=progress>0.7 and "ERROR // ENLACE NEURAL CORRUPTO" or "SOBRECARGA // PROTOCOLO FINAL"
            medical.TextColor3=RED
        end
    end)
end

print("[Cyber] v3.8 // Sistema local listo")
