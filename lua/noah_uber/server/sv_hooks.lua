NoahUber = NoahUber or {}

function NoahUber_HandleUberCommand(pPlayer)
  if not IsValid(pPlayer) then return end
  if not NoahUber_ConsumeNet(pPlayer, "open", 0.35) then return end
  local bAllowed = NoahUber_IsCourier(pPlayer) or NoahUber_IsAdmin(pPlayer) or not NoahUber.Config.RequireJob
  if not bAllowed then
    NoahUber_Notify(pPlayer, 1, "need_job")
    return
  end
  net.Start("NoahUber:Open")
  net.Send(pPlayer)
  NoahUber_SendState(pPlayer)
  NoahUber_SendOffer(pPlayer)
  NoahUber_SyncActive(pPlayer)
end

local function NoahUber_RegisterChat()
  if NoahUber.ChatRegistered then return end
  if not DarkRP or not DarkRP.defineChatCommand then return end
  NoahUber.ChatRegistered = true
  DarkRP.defineChatCommand("uber", function(pPlayer)
    NoahUber_HandleUberCommand(pPlayer)
    return ""
  end)
end

hook.Add("Initialize", "NoahUber:Initialize", function()
  NoahUber_CheckLang()
  timer.Simple(0, NoahUber_RegisterChat)
  timer.Simple(5, NoahUber_RegisterChat)
end)

hook.Add("DarkRPFinishedLoading", "NoahUber:DarkRP", function()
  NoahUber_RegisterChat()
end)

hook.Add("PlayerSay", "NoahUber:PlayerSay", function(pPlayer, sText)
  if NoahUber.ChatRegistered then return end
  local sCmd = string.Trim(string.lower(sText or ""))
  if sCmd ~= "/uber" and sCmd ~= "!uber" then return end
  NoahUber_HandleUberCommand(pPlayer)
  return ""
end)

hook.Add("PlayerDisconnected", "NoahUber:Disconnect", function(pPlayer)
  NoahUber_ForceOffline(pPlayer)
end)

hook.Add("OnPlayerChangedTeam", "NoahUber:Team", function(pPlayer, _, iAfter)
  timer.Simple(0, function()
    if not IsValid(pPlayer) then return end
    if not NoahUber_IsCourier(pPlayer) then
      NoahUber_ForceOffline(pPlayer)
      NoahUber_SendState(pPlayer)
      NoahUber_SyncActive(pPlayer)
      NoahUber_SendOffer(pPlayer)
    elseif iAfter == NoahUber_GetTeam() then
      NoahUber_Notify(pPlayer, 0, "job_welcome")
    end
  end)
end)

hook.Add("PlayerInitialSpawn", "NoahUber:Join", function(pPlayer)
  timer.Simple(3, function()
    if not IsValid(pPlayer) then return end
    NoahUber_SendState(pPlayer)
    if NoahUber_IsAdmin(pPlayer) then
      NoahUber_SendPoints(pPlayer)
    end
  end)
end)

hook.Add("KeyPress", "NoahUber:Use", function(pPlayer, iKey)
  if iKey ~= IN_USE then return end
  if not pPlayer.NoahUber_Online then return end
  NoahUber_TryInteract(pPlayer)
end)

hook.Add("PostCleanupMap", "NoahUber:Cleanup", function()
  for _, tOrder in pairs(NoahUber.Orders or {}) do
    if tOrder.state == "accepted" or tOrder.state == "picked" then
      NoahUber_SpawnCustomer(tOrder)
    end
    if tOrder.state == "accepted" then
      NoahUber_SpawnOrderBag(tOrder)
    end
  end
end)

hook.Add("Think", "NoahUber:WornBag", function()
  local tPlayers = player.GetAll()
  for i = 1, #tPlayers do
    local pPlayer = tPlayers[i]
    if IsValid(pPlayer.NoahUber_Bag) and pPlayer:Alive() then
      NoahUber_PlaceWornBag(pPlayer, pPlayer.NoahUber_Bag)
    end
  end
end)

hook.Add("PlayerDeath", "NoahUber:Bag", function(pPlayer)
  if IsValid(pPlayer.NoahUber_Bag) then
    pPlayer.NoahUber_Bag:Remove()
  end
  pPlayer.NoahUber_Bag = nil
end)

hook.Add("PlayerLoadout", "NoahUber:Bag", function(pPlayer)
  timer.Simple(0.2, function()
    if not IsValid(pPlayer) then return end
    if NoahUber_HasPickedOrder and NoahUber_HasPickedOrder(pPlayer) then
      NoahUber_GiveBag(pPlayer)
    end
  end)
end)

hook.Add("canDropWeapon", "NoahUber:Bag", function(_, eWep)
  if IsValid(eWep) and eWep:GetClass() == "noah_uber_bag" then return false end
end)

hook.Add("CanPlayerEnterVehicle", "NoahUber:Scooter", function(pPlayer, eVeh)
  if not IsValid(eVeh) or not eVeh.NoahUberVehicle then return end
  if eVeh.NoahUberOwner == (pPlayer:SteamID64() or "") then return true end
  return false
end)

hook.Add("CanTool", "NoahUber:CanTool", function(pPlayer, _, sTool)
  if sTool ~= "noah_uber_points" then return end
  if not NoahUber_IsAdmin(pPlayer) then return false end
end)

timer.Create("NoahUber:Dispatch", 5, 0, function()
  NoahUber_ExpireOffers()
  NoahUber_Dispatch()
  local tPlayers = player.GetAll()
  for i = 1, #tPlayers do
    local pPlayer = tPlayers[i]
    if pPlayer.NoahUber_Online and NoahUber_CountActive(pPlayer) > 0 and (pPlayer.NoahUber_NextPath or 0) <= CurTime() then
      pPlayer.NoahUber_NextPath = CurTime() + 3
      NoahUber_SyncActive(pPlayer)
    end
  end
end)

timer.Create("NoahUber:Move", 0.5, 0, function()
  NoahUber_MaintainCustomers()
  local tPlayers = player.GetAll()
  for i = 1, #tPlayers do
    local pPlayer = tPlayers[i]
    if pPlayer.NoahUber_Online and NoahUber_CountActive(pPlayer) > 0 then
      NoahUber_TrackMovement(pPlayer)
    end
  end
end)

concommand.Add("noah_uber_open", function(pPlayer)
  if not IsValid(pPlayer) then return end
  NoahUber_HandleUberCommand(pPlayer)
end)

concommand.Add("noah_uber_registervehicle", function(pPlayer)
  if not IsValid(pPlayer) or not NoahUber_IsAdmin(pPlayer) then return end
  if not NoahUber_ConsumeNet(pPlayer, "regveh", 1) then return end
  local eVeh = NoahUber_GetRootVehicle(pPlayer)
  if not IsValid(eVeh) or not NoahUber_LooksLikeVehicle(eVeh) then
    NoahUber_Notify(pPlayer, 1, "sit_in_vehicle")
    return
  end
  local tId = NoahUber_VehicleIdentity(eVeh)
  NoahUber_SaveVehicle({
    class = tId.class,
    model = string.lower(eVeh:GetModel() or ""),
    script = tId.script,
  })
  NoahUber_Notify(pPlayer, 0, "vehicle_saved")
  local sShow = NoahUber.VehicleProfile.script ~= "" and NoahUber.VehicleProfile.script or NoahUber.VehicleProfile.model
  NoahUber_Notify(pPlayer, 0, "register_hint", sShow)
end)

timer.Simple(2, function()
  if TEAM_NOAHUBER or (NoahUber_GetTeam and NoahUber_GetTeam()) then return end
  if not DarkRP or not DarkRP.createJob then return end
  include("darkrp_modules/noah_uber/sh_job.lua")
end)
