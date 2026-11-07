--!strict
--[[
	Util  |  ReplicatedStorage.Modules.Util
	------------------------------------------------------------------
	Petites fonctions utilitaires partagées.
]]

local Util = {}

--- Copie profonde (tables uniquement)
function Util.deepCopy(source)
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = Util.deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

--- Fusionne `overrides` dans `base` de façon récursive (base est modifié)
function Util.deepMerge(base, overrides)
	for key, value in pairs(overrides) do
		if type(value) == "table" and type(base[key]) == "table" then
			Util.deepMerge(base[key], value)
		else
			base[key] = Util.deepCopy(value)
		end
	end
	return base
end

function Util.count(tbl): number
	local total = 0
	for _ in pairs(tbl) do
		total = total + 1
	end
	return total
end

function Util.sumKeys(tbl): number
	local total = 0
	for key, value in pairs(tbl) do
		if type(key) == "number" then
			total = total + value
		end
	end
	return total
end

--- Choisit une clé au hasard selon des poids { A = 5, B = 1 }
function Util.weightedChoice(weights, randomObject)
	local rng = randomObject or Random.new()
	local total = 0
	for _, weight in pairs(weights) do
		total = total + weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	local accumulator = 0
	for key, weight in pairs(weights) do
		accumulator = accumulator + weight
		if roll <= accumulator then
			return key
		end
	end
	return nil
end

function Util.pickRandom(list, randomObject)
	local rng = randomObject or Random.new()
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

--- Retourne une version "safe" d'une chaîne pour un nom d'instance
function Util.sanitizeName(text: string): string
	return (string.gsub(text, "[^%w_%-]", "_"))
end

--- Arrondi "propre" pour l'affichage (jamais de décimale inutile)
function Util.round(value: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(value * mult + 0.5) / mult
end

--- Sérialise rapidement pour le debug
function Util.debugTable(tbl, depth: number?): string
	local d = depth or 0
	local indent = string.rep("  ", d)
	local out = {}
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			table.insert(out, indent .. tostring(key) .. " = " .. Util.debugTable(value, d + 1))
		else
			table.insert(out, indent .. tostring(key) .. " = " .. tostring(value))
		end
	end
	return "{\n" .. table.concat(out, ",\n") .. "\n" .. string.rep("  ", math.max(0, d - 1)) .. "}"
end

--- Vérifie qu'une valeur est un nombre fini et positif (anti-exploit)
function Util.isValidNumber(value: any, allowZero: boolean?): boolean
	if type(value) ~= "number" then
		return false
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return false
	end
	if allowZero then
		return value >= 0
	end
	return value > 0
end

--- Lerp pour Color3
function Util.lerpColor(a: Color3, b: Color3, alpha: number): Color3
	return a:Lerp(b, math.clamp(alpha, 0, 1))
end

--- Retire les éléments d'un tableau qui ne passent pas le filtre
function Util.filter(list, predicate)
	local out = {}
	for _, value in ipairs(list) do
		if predicate(value) then
			table.insert(out, value)
		end
	end
	return out
end

function Util.map(list, mapper)
	local out = {}
	for index, value in ipairs(list) do
		out[index] = mapper(value, index)
	end
	return out
end

function Util.indexOf(list, value): number
	for index, item in ipairs(list) do
		if item == value then
			return index
		end
	end
	return -1
end

function Util.removeValue(list, value): boolean
	local index = Util.indexOf(list, value)
	if index > 0 then
		table.remove(list, index)
		return true
	end
	return false
end

--- Encodage base36 pour des uid de pets compacts
local BASE36 = "0123456789abcdefghijklmnopqrstuvwxyz"
function Util.base36(numberValue: number): string
	local n = math.floor(math.abs(numberValue))
	if n == 0 then
		return "0"
	end
	local out = ""
	while n > 0 do
		local digit = n % 36
		out = string.sub(BASE36, digit + 1, digit + 1) .. out
		n = math.floor(n / 36)
	end
	return out
end

--- Génère un identifiant unique de pet
function Util.generateUid(randomObject: Random?): string
	local rng = randomObject or Random.new()
	return string.format("%s%s%s", Util.base36(os.time()), Util.base36(rng:NextInteger(0, 1679615)), Util.base36(rng:NextInteger(0, 1679615)))
end

return Util
