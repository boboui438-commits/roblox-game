--!strict
--[[
	LeaderboardManager  |  ServerScriptService.Systems.LeaderboardManager
	------------------------------------------------------------------
	Deux classements :
	  • SERVEUR : tri en mémoire des joueurs connectés (temps réel)
	  • MONDIAL : OrderedDataStore, top 25 des puissances à vie

	Met aussi à jour le panneau dans le lobby (SurfaceGui) et pousse les
	données aux clients toutes les 8 secondes.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local DataManager = require(script.Parent.DataManager)

local LeaderboardManager = {}

local orderedStore: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}
local globalCache = {}
local lastGlobalFetch = 0
local lastPush = 0

local function getOrderedStore(): OrderedDataStore?
	if orderedStore then
		return orderedStore
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(GameConfig.DataStoreName .. "_GlobalPower")
	end)
	if ok then
		orderedStore = store
		return store
	end
	return nil
end

-- ============================================================
-- CLASSEMENT SERVEUR
-- ============================================================
function LeaderboardManager.getServerTop(limit: number?)
	local list = {}
	for player, profile in pairs(DataManager.getProfiles()) do
		if player.Parent then
			table.insert(list, {
				UserId = player.UserId,
				Name = player.DisplayName,
				Power = math.floor(profile.power),
				BestPower = math.floor(profile.bestPower),
				Rebirths = profile.rebirths,
				Title = profile.titleSelected,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Power > b.Power
	end)
	local max = limit or GameConfig.Misc.LeaderboardTop
	if #list > max then
		local trimmed = {}
		for index = 1, max do
			trimmed[index] = list[index]
		end
		return trimmed
	end
	return list
end

-- ============================================================
-- CLASSEMENT MONDIAL
-- ============================================================
local function resolveName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	nameCache[userId] = "Joueur " .. tostring(userId)
	return nameCache[userId]
end

function LeaderboardManager.submitScore(player: Player)
	local profile = DataManager.getProfile(player)
	local store = getOrderedStore()
	if not profile or not store then
		return
	end
	local value = math.floor(math.max(profile.bestPower, profile.power))
	if value < 1 then
		return
	end
	if value > 9.2e18 then
		value = 9.2e18
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(player.UserId), value)
		end)
		if not ok then
			warn("[LeaderboardManager] submit : " .. tostring(err))
		end
	end)
end

function LeaderboardManager.fetchGlobal(force: boolean?)
	if not force and os.clock() - lastGlobalFetch < 60 and #globalCache > 0 then
		return globalCache
	end
	local store = getOrderedStore()
	if not store then
		return globalCache
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, math.clamp(GameConfig.Misc.LeaderboardTop, 1, 100))
	end)
	if not ok then
		warn("[LeaderboardManager] GetSortedAsync : " .. tostring(pages))
		return globalCache
	end

	local list = {}
	local success, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if success and type(page) == "table" then
		for rank, entry in ipairs(page) do
			local userId = tonumber(entry.key)
			if userId then
				table.insert(list, {
					Rank = rank,
					UserId = userId,
					Name = resolveName(userId),
					Power = entry.value,
				})
			end
		end
	end
	globalCache = list
	lastGlobalFetch = os.clock()
	return list
end

-- ============================================================
-- PANNEAU DANS LE LOBBY
-- ============================================================
local function updateLobbyBoard()
	local lobby = Workspace:FindFirstChild("Lobby")
	local board = lobby and lobby:FindFirstChild("ServerBoard")
	local gui = board and board:FindFirstChild("ServerLeaderboard")
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end

	local top = LeaderboardManager.getServerTop(10)
	local children = list:GetChildren()
	for _, child in ipairs(children) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	for index = 1, math.max(#top, 1) do
		local label = Instance.new("TextLabel")
		label.Name = "Row" .. tostring(index)
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, 36)
		label.BackgroundTransparency = 0.85
		label.BackgroundColor3 = index == 1 and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextScaled = true
		local entry = top[index]
		if entry then
			label.Text = string.format("  #%d  %s   —   %s ⚡", index, entry.Name, Formulas.formatNumber(entry.Power))
			label.TextColor3 = index == 1 and Color3.fromRGB(60, 40, 0) or Color3.fromRGB(230, 240, 255)
		else
			label.Text = index == 1 and "  En attente de joueurs…" or ""
			label.TextColor3 = Color3.fromRGB(150, 160, 180)
		end
		label.Parent = list
	end
end

-- ============================================================
-- DÉMARRAGE
-- ============================================================
function LeaderboardManager.start()
	Net.func("GetLeaderboards").OnServerInvoke = function(player)
		local globalList = LeaderboardManager.fetchGlobal(false)
		local serverList = LeaderboardManager.getServerTop(GameConfig.Misc.LeaderboardTop)
		return globalList, serverList
	end

	-- Soumission des scores
	Players.PlayerRemoving:Connect(function(player)
		LeaderboardManager.submitScore(player)
	end)

	-- Précharge le classement mondial (les noms coûtent cher la 1re fois)
	task.spawn(function()
		task.wait(10)
		LeaderboardManager.fetchGlobal(true)
	end)

	task.spawn(function()
		while true do
			task.wait(8)
			updateLobbyBoard()
			local serverList = LeaderboardManager.getServerTop(GameConfig.Misc.LeaderboardTop)
			Net.event("LeaderboardData"):FireAllClients(globalCache, serverList)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(45)
			for _, player in ipairs(Players:GetPlayers()) do
				LeaderboardManager.submitScore(player)
			end
			LeaderboardManager.fetchGlobal(true)
		end
	end)

	print("[LeaderboardManager] Démarré")
end

return LeaderboardManager
