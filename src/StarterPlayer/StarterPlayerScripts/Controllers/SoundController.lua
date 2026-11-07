--!strict
--[[
	SoundController  |  StarterPlayer.StarterPlayerScripts.Controllers.SoundController
	------------------------------------------------------------------
	Sons du jeu.

	Astuce : les sons utilisés par défaut sont des sons NATIFS de Roblox
	(rbxasset://sounds/...), donc il n'y a AUCUN asset à importer.
	Pour mettre de la vraie musique, mets un ID audio dans
	GameConfig.Worlds[i].MusicId (ex : "rbxassetid://1837879082").
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local ClientState = require(script.Parent.ClientState)

local SoundController = {}

-- key = { id, volume, pitch, pitchVariance }
local SOUNDS = {
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.25, pitch = 1 },
	ui = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, pitch = 1.2 },
	absorb = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.16, pitch = 1.5, variance = 0.25 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3, pitch = 2, variance = 0.1 },
	golden = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35, pitch = 2.6 },
	vacuum = { id = "rbxasset://sounds/snap.mp3", volume = 0.4, pitch = 0.9 },
	auto = { id = "rbxasset://sounds/switch3.wav", volume = 0.12, pitch = 1.6 },
	teleport = { id = "rbxasset://sounds/swoosh.wav", volume = 0.4, pitch = 1 },
	unlock = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.8 },
	transform = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.3, pitch = 1.35 },
	rebirth = { id = "rbxasset://sounds/bass.wav", volume = 0.5, pitch = 1 },
	event = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.4, pitch = 1.2 },
	achievement = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.4 },
	daily = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.1 },
	buy = { id = "rbxasset://sounds/switch3.wav", volume = 0.35, pitch = 1.1 },
	equip = { id = "rbxasset://sounds/switch3.wav", volume = 0.3, pitch = 1.3 },
	fuse = { id = "rbxasset://sounds/bass.wav", volume = 0.35, pitch = 1.6 },
	egg = { id = "rbxasset://sounds/snap.mp3", volume = 0.35, pitch = 1.2 },
	rarity = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.7 },
	pet = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.15, pitch = 1.8 },
}

local musicSound: Sound? = nil
local currentMusicId: string? = nil
local container: Folder? = nil

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	local folder = Instance.new("Folder")
	folder.Name = "GameSounds"
	folder.Parent = SoundService
	container = folder
	return folder
end

function SoundController.play(key: string, volumeScale: number?)
	if not ClientState.getSetting("sfx") then
		return
	end
	local data = SOUNDS[key]
	if not data then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = data.id
	sound.Volume = math.clamp(data.volume * (volumeScale or 1), 0, 5)
	sound.PlaybackSpeed = data.pitch * (1 + math.random(-10, 10) * 0.01 * (data.variance or 0))
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.Parent = getContainer()
	sound:Play()
	task.delay(4, function()
		sound:Destroy()
	end)
end

--- Joue la musique du monde (si un ID est configuré)
function SoundController.playWorldMusic(worldIndex: number)
	local world = GameConfig.Worlds[worldIndex]
	local musicId = world and world.MusicId or ""
	if not musicId or musicId == "" then
		if currentMusicId ~= "" then
			SoundController.stopMusic()
			currentMusicId = ""
		end
		return
	end
	if currentMusicId == musicId then
		return
	end
	SoundController.stopMusic()
	currentMusicId = musicId
	local sound = Instance.new("Sound")
	sound.Name = "WorldMusic"
	sound.SoundId = musicId
	sound.Volume = 0.25
	sound.Looped = true
	sound.Parent = getContainer()
	if ClientState.getSetting("music") then
		sound:Play()
	end
	musicSound = sound
end

function SoundController.stopMusic()
	if musicSound then
		musicSound:Destroy()
		musicSound = nil
	end
end

function SoundController.applySettings()
	if musicSound then
		if ClientState.getSetting("music") then
			if not musicSound.IsPlaying then
				musicSound:Play()
			end
		else
			musicSound:Stop()
		end
	end
end

function SoundController.start()
	ClientState.Signals.Sound:Connect(function(key, volume)
		SoundController.play(key, volume)
	end)
	ClientState.Signals.World:Connect(function(worldIndex)
		SoundController.playWorldMusic(worldIndex)
	end)
	ClientState.Signals.Profile:Connect(function()
		SoundController.applySettings()
	end)
end

return SoundController
