--!strict
--[[
	PetFollowController  |  StarterPlayer.StarterPlayerScripts.Controllers.PetFollowController
	------------------------------------------------------------------
	Fait apparaître les pets équipés autour du personnage et les fait
	flotter/tourner (100% client : le serveur ne gère que les données).

	• Aucun pet en double (clé = uid)
	• Positions en cercle derrière le joueur, lissage par interpolation
	• Les pets rares brillent et laissent des particules (PetFactory)
	• Désactivable dans les paramètres (optimisation mobile)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)
local PetFactory = require(script.Parent.PetFactory)

local PetFollowController = {}

local petModels: { [string]: Model } = {}
local petAngles: { [string]: number } = {}
local petBob: { [string]: number } = {}
local container: Folder? = nil
local lastSignature = ""

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	local folder = Instance.new("Folder")
	folder.Name = "LocalPets"
	folder.Parent = Workspace
	container = folder
	return folder
end

local function clearAll()
	for uid, model in pairs(petModels) do
		if model then
			model:Destroy()
		end
		petModels[uid] = nil
	end
end

local function syncPets()
	local equipped = ClientState.getEquippedPets()
	local signature = {}
	for _, pet in ipairs(equipped) do
		table.insert(signature, pet.uid .. ":" .. tostring(pet.level))
	end
	local signatureString = table.concat(signature, ",")

	if not ClientState.getSetting("petsVisible") then
		if lastSignature ~= "hidden" then
			clearAll()
			lastSignature = "hidden"
		end
		return
	end
	if signatureString == lastSignature then
		return
	end
	lastSignature = signatureString

	-- Supprime les pets qui ne sont plus équipés
	local equippedSet = {}
	for _, pet in ipairs(equipped) do
		equippedSet[pet.uid] = true
	end
	for uid, model in pairs(petModels) do
		if not equippedSet[uid] then
			model:Destroy()
			petModels[uid] = nil
			petAngles[uid] = nil
			petBob[uid] = nil
		end
	end

	-- Crée / recrée les pets manquants ou de niveau différent
	for _, pet in ipairs(equipped) do
		local existing = petModels[pet.uid]
		local levelAttribute = existing and existing:GetAttribute("PetLevel")
		if not existing or levelAttribute ~= pet.level then
			if existing then
				existing:Destroy()
			end
			local model = PetFactory.create(pet.id, pet.level)
			model.Parent = getContainer()
			petModels[pet.uid] = model
			petAngles[pet.uid] = math.random() * math.pi * 2
			petBob[pet.uid] = math.random() * math.pi * 2
		end
	end
end

local function updatePets(deltaTime: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local count = 0
	for _ in pairs(petModels) do
		count = count + 1
	end
	if count == 0 then
		return
	end

	local time = os.clock()
	local origin = (root :: BasePart).CFrame
	local index = 0
	for uid, model in pairs(petModels) do
		index = index + 1
		if not model.PrimaryPart or not model.Parent then
			petModels[uid] = nil
		else
			petAngles[uid] = (petAngles[uid] or 0) + deltaTime * 0.9
			petBob[uid] = (petBob[uid] or 0) + deltaTime * 2.2

			local angle = petAngles[uid] + (index / count) * math.pi * 2
			local radius = 3.2 + count * 0.32
			local height = 1.6 + math.sin(petBob[uid]) * 0.45

			-- Position derrière/autour du joueur (recalée par rapport à son orientation)
			local localOffset = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius * 0.75)
			local targetPosition = (origin + origin:VectorToWorldSpace(localOffset)).Position
			local currentPosition = model:GetPivot().Position
			local smoothed = currentPosition:Lerp(targetPosition, math.clamp(deltaTime * 7, 0, 1))

			model:PivotTo(CFrame.new(smoothed) * CFrame.Angles(0, angle + math.pi / 2, 0))
		end
	end
end

function PetFollowController.start()
	ClientState.Signals.Profile:Connect(function()
		task.defer(syncPets)
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		syncPets()
	end)
	RunService.Heartbeat:Connect(updatePets)
	syncPets()
	print("[PetFollowController] Démarré")
end

return PetFollowController
