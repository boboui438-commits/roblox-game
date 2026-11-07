--!strict
--[[
	Signal  |  ReplicatedStorage.Modules.Signal
	------------------------------------------------------------------
	Implémentation légère de signaux (comme GoodSignal) pour découpler
	les systèmes serveur sans dépendances externes.
]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, callback)
	return setmetatable({ _signal = signal, _callback = callback, Connected = true }, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	if signal then
		for index, connection in ipairs(signal._listeners) do
			if connection == self then
				table.remove(signal._listeners, index)
				break
			end
		end
	end
	self._callback = nil
	self._signal = nil
end

function Signal.new()
	return setmetatable({ _listeners = {}, _yielding = {} }, Signal)
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect attend une fonction")
	local connection = Connection.new(self, callback)
	table.insert(self._listeners, connection)
	return connection
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, connection in ipairs(self._listeners) do
		if connection.Connected then
			local ok, err = pcall(connection._callback, ...)
			if not ok then
				warn("[Signal] erreur dans un listener : " .. tostring(err))
			end
		end
	end
end

function Signal:DisconnectAll()
	for _, connection in ipairs(self._listeners) do
		connection.Connected = false
	end
	table.clear(self._listeners)
end

function Signal:Destroy()
	self:DisconnectAll()
	self._listeners = {}
end

return Signal
