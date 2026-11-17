NoahUber = NoahUber or {}
NoahUber.Version = "1.0.0"

local COL_TAG = Color(6, 193, 103)
local COL_TEXT = Color(235, 235, 235)
local COL_DIM = Color(150, 150, 150)
local COL_OK = Color(120, 220, 140)
local COL_WARN = Color(255, 186, 70)
local COL_BAD = Color(255, 90, 90)

function NoahUber_Print(sLevel, sText)
	local col = COL_TEXT
	if sLevel == "ok" then col = COL_OK
	elseif sLevel == "warn" then col = COL_WARN
	elseif sLevel == "bad" then col = COL_BAD
	elseif sLevel == "dim" then col = COL_DIM
	end
	MsgC(COL_TAG, "[Noah Uber] ", col, tostring(sText or ""), "\n")
end

local function NoahUber_Load(sRealm, sFile)
	local sPath = "noah_uber/" .. sFile
	local bInclude = (sRealm == "sh") or (sRealm == "sv" and SERVER) or (sRealm == "cl" and CLIENT)

	if SERVER and (sRealm == "sh" or sRealm == "cl") then
		AddCSLuaFile(sPath)
	end

	if not bInclude then
		NoahUber_Print("dim", string.format("%-8s %s", "client", sFile))
		return true
	end

	local bOk, sErr = pcall(include, sPath)
	if not bOk then
		NoahUber_Print("bad", string.format("%-8s %s", sRealm, sFile))
		NoahUber_Print("bad", "         " .. tostring(sErr))
		return false
	end

	NoahUber_Print("ok", string.format("%-8s %s", sRealm, sFile))
	return true
end

local function NoahUber_WorkshopState(sId)
	sId = tostring(sId or "")
	if not string.match(sId, "^%d+$") then
		return "empty", "no workshop ID set"
	end

	local tAddons = engine.GetAddons and engine.GetAddons() or {}
	for i = 1, #tAddons do
		local tAddon = tAddons[i]
		if tostring(tAddon.wsid) == sId then
			if tAddon.mounted then
				return "ok", (tAddon.title or "workshop addon") .. "  (" .. sId .. ")"
			end
			return "warn", "downloaded but not mounted  (" .. sId .. ")"
		end
	end

	return "bad", "not in the server collection  (" .. sId .. ")"
end

MsgC(COL_TAG, "[Noah Uber] ", COL_DIM, "--------------------------------\n")
NoahUber_Print("text", "Noah Uber  v" .. NoahUber.Version)
MsgC(COL_TAG, "[Noah Uber] ", COL_DIM, "--------------------------------\n")

NoahUber_Load("sh", "config.lua")
NoahUber_Load("sh", "constants.lua")
NoahUber_Load("sh", "sh_lang.lua")
NoahUber_Load("sh", "sh_util.lua")

local tLangs = { "fr", "en", "de", "es", "pt", "ru", "tr" }
for i = 1, #tLangs do
	NoahUber_Load("sh", "lang/" .. tLangs[i] .. ".lua")
end

if SERVER then
	local function NoahUber_AddWorkshop(sId)
		sId = tostring(sId or "")
		if not string.match(sId, "^%d+$") then return end
		resource.AddWorkshop(sId)
	end

	NoahUber_AddWorkshop(NoahUber.Config.VehicleWorkshopID)
	NoahUber_AddWorkshop(NoahUber.Config.ContentWorkshopID)

	local tFiles = {
		"resource/fonts/montserratwasied-bold.ttf",
		"resource/fonts/montserratwasied-extrabold.ttf",
		"resource/fonts/montserratwasied-light.ttf",
		"resource/fonts/montserratwasied-medium.ttf",
		"resource/fonts/montserratwasied-semibold.ttf",
		"resource/fonts/montserratwasied-thin.ttf",
		"resource/fonts/montserratwasied-italic.ttf",
		"sound/noah_uber/uber_eats_sounds.wav",
		"sound/noah_uber/success.wav",
		"materials/noah_uber/livraison.png",
		"materials/noah_uber/livraison.vmt",
		"models/weapons/bags/thief_bag.mdl",
		"models/weapons/bags/thief_bag.vvd",
		"models/weapons/bags/thief_bag.dx90.vtx",
		"models/weapons/bags/thief_bag.dx80.vtx",
		"models/weapons/bags/thief_bag.phy",
		"models/weapons/bags/thief_bag_open.mdl",
		"models/weapons/bags/thief_bag_open.vvd",
		"models/weapons/bags/thief_bag_open.dx90.vtx",
		"models/weapons/bags/thief_bag_open.dx80.vtx",
		"materials/models/textures_bags/duffel_grey.vmt",
		"materials/models/textures_bags/duffel_grey_d.vtf",
		"materials/models/textures_bags/duffel_n.vtf",
	}

	local iMissing = 0
	for i = 1, #tFiles do
		if file.Exists(tFiles[i], "GAME") then
			resource.AddFile(tFiles[i])
		else
			iMissing = iMissing + 1
			NoahUber_Print("warn", "missing   " .. tFiles[i])
		end
	end
	if iMissing == 0 then
		NoahUber_Print("ok", "files     fonts, sounds, icon and bag")
	end

	util.PrecacheModel("models/weapons/bags/thief_bag.mdl")
	util.PrecacheModel("models/weapons/bags/thief_bag_open.mdl")

	local sContentLevel, sContentText = NoahUber_WorkshopState(NoahUber.Config.ContentWorkshopID)
	local sVehicleLevel, sVehicleText = NoahUber_WorkshopState(NoahUber.Config.VehicleWorkshopID)
	NoahUber_Print(sContentLevel, "content   " .. sContentText)
	NoahUber_Print(sVehicleLevel, "vehicle   " .. sVehicleText)

	NoahUber_Load("sv", "server/sv_data.lua")
	NoahUber_Load("sv", "server/sv_functions.lua")
	NoahUber_Load("sv", "server/sv_points.lua")
	NoahUber_Load("sv", "server/sv_npc.lua")
	NoahUber_Load("sv", "server/sv_orders.lua")
	NoahUber_Load("sv", "server/sv_network.lua")
	NoahUber_Load("sv", "server/sv_hooks.lua")
	NoahUber_Load("sv", "server/sv_blogs.lua")

	NoahUber_Load("cl", "client/cl_functions.lua")
	NoahUber_Load("cl", "client/cl_shadow.lua")
	NoahUber_Load("cl", "client/cl_hooks.lua")
	NoahUber_Load("cl", "client/cl_hud.lua")
	NoahUber_Load("cl", "client/cl_interface.lua")
	NoahUber_Load("cl", "client/cl_network.lua")

	timer.Simple(8, function()
		if NoahUber_RegisterBLogs then NoahUber_RegisterBLogs() end
		if NoahUber.BLogs == "gas" then
			NoahUber_Print("ok", "blogs     GAS Logging")
		elseif NoahUber.BLogs == "legacy" then
			NoahUber_Print("ok", "blogs     bLogs")
		else
			NoahUber_Print("dim", "blogs     not installed")
		end
	end)
else
	NoahUber_Load("cl", "client/cl_functions.lua")
	NoahUber_Load("cl", "client/cl_shadow.lua")
	NoahUber_Load("cl", "client/cl_hooks.lua")
	NoahUber_Load("cl", "client/cl_hud.lua")
	NoahUber_Load("cl", "client/cl_interface.lua")
	NoahUber_Load("cl", "client/cl_network.lua")
end

NoahUber_Print("ok", "ready     v" .. NoahUber.Version)
