Interaction = {}

local arenaRelationshipGroup
local defaultRelationshipGroup = joaat("PLAYER")
local relationshipGroupsReady = false

local function EnsureRelationshipGroups()
	if relationshipGroupsReady then
		return
	end

	AddRelationshipGroup("AIRSOFT_ARENA")
	arenaRelationshipGroup = joaat("AIRSOFT_ARENA")

	SetRelationshipBetweenGroups(0, arenaRelationshipGroup, defaultRelationshipGroup)
	SetRelationshipBetweenGroups(0, defaultRelationshipGroup, arenaRelationshipGroup)
	SetRelationshipBetweenGroups(5, arenaRelationshipGroup, arenaRelationshipGroup)

	relationshipGroupsReady = true
end

function Interaction.IsPlayerInMatch(serverId)
	if not serverId then
		return false
	end

	local playerState = Player(serverId).state
	return playerState.airsoftInMatch == true
end

function Interaction.IsPlayerSpectating(serverId)
	if not serverId then
		return false
	end

	return Player(serverId).state.airsoftSpectating == true
end

function Interaction.ShouldBlockCombatBetween(attackerServerId, victimServerId)
	if not attackerServerId or not victimServerId then
		return false
	end

	if Interaction.IsPlayerSpectating(attackerServerId) or Interaction.IsPlayerSpectating(victimServerId) then
		return true
	end

	local attackerInMatch = Interaction.IsPlayerInMatch(attackerServerId)
	local victimInMatch = Interaction.IsPlayerInMatch(victimServerId)

	return attackerInMatch ~= victimInMatch
end

function Interaction.GetPlayerServerIdFromPed(ped)
	if not ped or ped == 0 or not IsPedAPlayer(ped) then
		return nil
	end

	local playerIndex = NetworkGetPlayerIndexFromPed(ped)
	if not playerIndex or playerIndex == -1 then
		return nil
	end

	return GetPlayerServerId(playerIndex)
end

function Interaction.ApplyMatchState(inMatch)
	EnsureRelationshipGroups()

	local playerPed = PlayerPedId()
	if not playerPed or playerPed == 0 then
		return
	end

	if inMatch then
		SetPedRelationshipGroupHash(playerPed, arenaRelationshipGroup)
	else
		SetPedRelationshipGroupHash(playerPed, defaultRelationshipGroup)
	end
end

function Interaction.StartDamageFilter()
	AddEventHandler("gameEventTriggered", function(event, data)
		if event ~= "CEventNetworkEntityDamage" then
			return
		end

		local victim = data[1]
		local attacker = data[2]
		if not victim or victim == 0 or not attacker or attacker == 0 then
			return
		end

		local victimServerId = Interaction.GetPlayerServerIdFromPed(victim)
		local attackerServerId = Interaction.GetPlayerServerIdFromPed(attacker)
		if not victimServerId or not attackerServerId then
			return
		end

		if not Interaction.ShouldBlockCombatBetween(attackerServerId, victimServerId) then
			return
		end

		local previousHealth = GetEntityHealth(victim)
		local previousArmor = GetPedArmour(victim)

		SetTimeout(0, function()
			if DoesEntityExist(victim) then
				SetEntityHealth(victim, previousHealth)
				SetPedArmour(victim, previousArmor)
				ClearPedBloodDamage(victim)
			end
		end)
	end)
end

RegisterNetEvent("matti-airsoft:matchStateChanged", function(inMatch)
	Interaction.ApplyMatchState(inMatch == true)
end)
