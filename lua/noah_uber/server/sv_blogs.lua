NoahUber = NoahUber or {}

local function NoahUber_FormatLog(pPlayer, sText)
	local sName = IsValid(pPlayer) and pPlayer:Nick() or "Unknown"
	local sSteam = IsValid(pPlayer) and (pPlayer:SteamID() or "") or ""
	if sSteam ~= "" then
		return sName .. " (" .. sSteam .. ") " .. sText
	end
	return sName .. " " .. sText
end

local function NoahUber_RegisterGAS()
	if NoahUber.BLogs == "gas" then return true end
	if not GAS or not GAS.Logging or not GAS.Logging.MODULE then return false end

	local MODULE = GAS.Logging:MODULE()
	MODULE.Category = "Noah Uber"
	MODULE.Name = "Deliveries"
	MODULE.Colour = Color(6, 193, 103)

	MODULE:Setup(function()
		MODULE:Hook("NoahUber:Log", "noah_uber", function(pPlayer, sText)
			local sLine = tostring(sText or "")
			if GAS.Logging.Escape then
				sLine = GAS.Logging:Escape(sLine)
			end
			MODULE:Log("{1} {2}", GAS.Logging:FormatPlayer(pPlayer), sLine)
		end)
	end)

	GAS.Logging:AddModule(MODULE)
	NoahUber.BLogs = "gas"
	return true
end

local function NoahUber_RegisterLegacy()
	if NoahUber.BLogs then return true end
	if not bLogs or not bLogs.Module then return false end

	local MODULE = bLogs:Module()
	MODULE.Category = "Noah Uber"
	MODULE.Name = "Deliveries"
	MODULE.Colour = Color(6, 193, 103)

	MODULE:Hook("NoahUber:Log", "noah_uber", function(pPlayer, sText)
		MODULE:Log(bLogs:FormatPlayer(pPlayer) .. " " .. tostring(sText or ""))
	end)

	bLogs:AddModule(MODULE)
	NoahUber.BLogs = "legacy"
	return true
end

function NoahUber_RegisterBLogs()
	if NoahUber_RegisterGAS() then return end
	NoahUber_RegisterLegacy()
end

hook.Add("gmodadminsuite:Load", "NoahUber:bLogs", NoahUber_RegisterBLogs)
hook.Add("bLogs_FullyLoaded", "NoahUber:bLogs", NoahUber_RegisterBLogs)

NoahUber_RegisterBLogs()
