Modes = {
	handlers = {},
}

function Modes.Register(modeId, handler)
	if not modeId or type(handler) ~= "table" then
		return
	end
	Modes.handlers[modeId] = handler
end

function Modes.Get(modeId)
	local normalized = SharedUtils.NormalizeModeId(modeId)
	return Modes.handlers[normalized] or Modes.handlers.ffa
end

function Modes.OnMatchStart(lobbyId, lobby)
	local handler = Modes.Get(lobby.gameMode)
	if handler.onMatchStart then
		handler.onMatchStart(lobbyId, lobby)
	end
end

function Modes.ApplyHitScoring(lobbyId, lobby, victimId, killerId, creditKiller)
	local handler = Modes.Get(lobby.gameMode)
	if handler.applyHitScoring then
		return handler.applyHitScoring(lobbyId, lobby, victimId, killerId, creditKiller)
	end
	return nil
end

function Modes.OnPlayerHit(lobbyId, lobby, victimId, killerId, creditKiller)
	local handler = Modes.Get(lobby.gameMode)
	if handler.onPlayerHit then
		handler.onPlayerHit(lobbyId, lobby, victimId, killerId, creditKiller)
	end
end

function Modes.OnPlayerEliminated(lobbyId, lobby, playerId)
	local handler = Modes.Get(lobby.gameMode)
	if handler.onPlayerEliminated then
		handler.onPlayerEliminated(lobbyId, lobby, playerId)
	end
end

function Modes.ShouldRespawn(lobby)
	local handler = Modes.Get(lobby.gameMode)
	if handler.shouldRespawn then
		return handler.shouldRespawn(lobby)
	end
	return not SharedUtils.IsLmsEnabled(lobby)
end

function Modes.ShouldEnterSpectator(lobby)
	local handler = Modes.Get(lobby.gameMode)
	if handler.shouldEnterSpectator then
		return handler.shouldEnterSpectator(lobby)
	end
	return SharedUtils.IsLmsEnabled(lobby)
end
