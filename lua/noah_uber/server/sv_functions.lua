NoahUber = NoahUber or {}

function NoahUber_Log(pPlayer, sText)
  hook.Run("NoahUber:Log", pPlayer, tostring(sText or ""))
end

function NoahUber_Notify(pPlayer, iType, sKey, ...)
  if not IsValid(pPlayer) or not pPlayer:IsPlayer() then return end
  local sText = NoahUber_L(sKey, ...)
  iType = math.floor(tonumber(iType) or 0)
  if DarkRP and DarkRP.notify then
    DarkRP.notify(pPlayer, iType, 6, sText)
    return
  end
  pPlayer:ChatPrint("[" .. (NoahUber.Config.Brand or "Uber") .. "] " .. sText)
end

function NoahUber_ActorPos(pPlayer)
  local vVehicle = NoahUber_GetRootVehicle(pPlayer)
  if IsValid(vVehicle) then return vVehicle:GetPos() end
  return pPlayer:GetPos()
end

function NoahUber_GetRootVehicle(pPlayer)
  if not IsValid(pPlayer) then return end
  local eVeh = pPlayer:GetVehicle()
  if not IsValid(eVeh) then return end

  local iGuard = 0
  while iGuard < 6 do
    local eParent = eVeh:GetParent()
    if not IsValid(eParent) then break end
    local sClass = eParent:GetClass() or ""
    if eParent:IsVehicle() or sClass == "gmod_sent_vehicle_fphysics_base" or string.find(sClass, "vehicle", 1, true) then
      eVeh = eParent
    else
      break
    end
    iGuard = iGuard + 1
  end

  return eVeh
end

function NoahUber_VehicleIdentity(eEnt)
  local sScript = ""
  if eEnt.GetVehicleClass then
    local bOk, sValue = pcall(eEnt.GetVehicleClass, eEnt)
    if bOk and isstring(sValue) then sScript = sValue end
  end
  return {
    class = eEnt:GetClass() or "",
    model = string.lower(eEnt:GetModel() or ""),
    script = string.lower(sScript),
  }
end

function NoahUber_LooksLikeVehicle(eEnt)
  if not IsValid(eEnt) then return false end
  local sClass = eEnt:GetClass() or ""
  if sClass == "prop_vehicle_prisoner_pod" then return false end
  return eEnt:IsVehicle() or sClass == "gmod_sent_vehicle_fphysics_base" or string.find(sClass, "vehicle", 1, true) ~= nil
end

function NoahUber_IsUberVehicle(eEnt)
  if not NoahUber_LooksLikeVehicle(eEnt) then return false end
  local tId = NoahUber_VehicleIdentity(eEnt)
  local tSaved = NoahUber.VehicleProfile
  if tSaved and ((tSaved.script and tSaved.script ~= "") or (tSaved.model and tSaved.model ~= "")) then
    if tSaved.script ~= "" and string.lower(tSaved.script) == tId.script and tId.script ~= "" then return true end
    if tSaved.model ~= "" and string.lower(tSaved.model) == tId.model and tId.model ~= "" then return true end
    return false
  end

  local sBlob = string.lower(tId.class .. " " .. tId.model .. " " .. tId.script)
  return string.find(sBlob, "address", 1, true)
    or string.find(sBlob, "suzuki", 1, true)
    or string.find(sBlob, "ubereats", 1, true)
    or string.find(sBlob, "uber_eats", 1, true)
    or string.find(sBlob, "azok", 1, true)
end

function NoahUber_HasDeliveryVehicle(pPlayer)
  if not NoahUber.Config.RequireVehicle then return true end
  if NoahUber_IsUberVehicle(NoahUber_GetRootVehicle(pPlayer)) then return true end

  local flDist = tonumber(NoahUber.Config.VehicleDistance) or 520
  local tNear = ents.FindInSphere(pPlayer:GetPos(), flDist)
  for i = 1, #tNear do
    if NoahUber_IsUberVehicle(tNear[i]) then return true end
  end
  return false
end

function NoahUber_VehicleFailureKey()
  local tSaved = NoahUber.VehicleProfile
  if tSaved and ((tSaved.model and tSaved.model ~= "") or (tSaved.script and tSaved.script ~= "")) then
    return "need_vehicle"
  end
  return "vehicle_missing"
end

function NoahUber_VehicleTable()
  local sName = NoahUber.Config.VehicleList or "azok30_suzuki_address_uber_eats"
  local tList = list.Get("Vehicles")
  if tList and tList[sName] then return sName, tList[sName] end
  if tList and tList["azok30_suzuki_address"] then
    return "azok30_suzuki_address", tList["azok30_suzuki_address"]
  end
  return sName, {
    Class = NoahUber.Config.VehicleClass or "prop_vehicle_jeep",
    Model = NoahUber.Config.VehicleModel or "models/codeandmodeling/julian/suzuki_address_uber_eats.mdl",
    KeyValues = {
      vehiclescript = NoahUber.Config.VehicleScript or "scripts/vehicles/azok30/suzuki_address.txt",
    },
  }
end

function NoahUber_RemoveDeliveryVehicle(pPlayer)
  if not IsValid(pPlayer) then return end
  if IsValid(pPlayer.NoahUber_Scooter) then
    pPlayer.NoahUber_Scooter:Remove()
  end
  pPlayer.NoahUber_Scooter = nil
end

local function NoahUber_ScooterSpot(pPlayer, vDir)
  local vStart = pPlayer:GetPos() + Vector(0, 0, 24)
  local tMove = util.TraceHull({
    start = vStart,
    endpos = vStart + vDir,
    mins = Vector(-18, -18, 0),
    maxs = Vector(18, 18, 40),
    filter = pPlayer,
    mask = MASK_SOLID,
  })
  local vPos = tMove.HitPos
  if tMove.Hit then
    vPos = tMove.HitPos - vDir:GetNormalized() * 16
  end
  local tGround = util.TraceLine({
    start = vPos + Vector(0, 0, 64),
    endpos = vPos - Vector(0, 0, 180),
    filter = pPlayer,
    mask = MASK_SOLID_BRUSHONLY,
  })
  if tGround.Hit then
    vPos = tGround.HitPos + Vector(0, 0, 14)
  end
  return vPos
end

function NoahUber_SpawnDeliveryVehicle(pPlayer)
  if not IsValid(pPlayer) or not pPlayer:Alive() then return end
  if NoahUber.Config.RequireJob and not NoahUber_IsCourier(pPlayer) then
    NoahUber_Notify(pPlayer, 1, "need_job")
    return
  end

  local eOld = pPlayer.NoahUber_Scooter
  if IsValid(eOld) and eOld:GetPos():Distance(pPlayer:GetPos()) < 2200 then
    NoahUber_Notify(pPlayer, 0, "vehicle_ready")
    return eOld
  end
  NoahUber_RemoveDeliveryVehicle(pPlayer)

  local sName, tVeh = NoahUber_VehicleTable()
  local sModel = tVeh.Model or ""
  if sModel == "" or not util.IsValidModel(sModel) then
    NoahUber_Notify(pPlayer, 1, "vehicle_gone")
    return
  end

  local aAng = Angle(0, pPlayer:EyeAngles().y, 0)
  local vPos = NoahUber_ScooterSpot(pPlayer, aAng:Forward() * -120 + aAng:Right() * 48)
  local eVeh = ents.Create(tVeh.Class or "prop_vehicle_jeep")
  if not IsValid(eVeh) then
    NoahUber_Notify(pPlayer, 1, "vehicle_gone")
    return
  end

  eVeh:SetModel(sModel)
  local tKeys = tVeh.KeyValues or {}
  for sKey, sValue in pairs(tKeys) do
    eVeh:SetKeyValue(sKey, sValue)
  end
  eVeh:SetPos(vPos)
  eVeh:SetAngles(aAng)
  eVeh:Spawn()
  eVeh:Activate()
  eVeh.VehicleName = sName
  eVeh.VehicleTable = tVeh
  eVeh.ClassOverride = tVeh.Class
  if eVeh.SetVehicleClass then
    eVeh:SetVehicleClass(sName)
  end

  eVeh.NoahUberVehicle = true
  eVeh.NoahUberOwner = pPlayer:SteamID64() or ""
  eVeh:SetNWBool("NoahUber_Vehicle", true)
  if eVeh.CPPISetOwner then
    eVeh:CPPISetOwner(pPlayer)
  end
  if eVeh.keysOwn then
    pcall(eVeh.keysOwn, eVeh, pPlayer)
  end
  if eVeh.keysUnLock then
    pcall(eVeh.keysUnLock, eVeh)
  end

  pPlayer.NoahUber_Scooter = eVeh
  if not IsValid(pPlayer:GetVehicle()) then
    pcall(pPlayer.EnterVehicle, pPlayer, eVeh)
  end
  NoahUber_Notify(pPlayer, 0, "vehicle_spawned")
  return eVeh
end

function NoahUber_PlayerBySid(sId)
  if not sId then return end
  local tPlayers = player.GetAll()
  for i = 1, #tPlayers do
    if NoahUber_ValidSteam(tPlayers[i]) == sId then return tPlayers[i] end
  end
end

function NoahUber_AreaOK(aArea)
  return aArea and aArea.GetID and aArea.GetCenter and aArea.GetAdjacentAreas
end

function NoahUber_BuildPath(vFrom, vTo)
  if not isvector(vFrom) or not isvector(vTo) then return { vTo } end
  if not navmesh or not navmesh.IsLoaded or not navmesh.IsLoaded() then
    return { vFrom, vTo }
  end

  local aStart = navmesh.GetNearestNavArea(vFrom, false, 800, false, true)
  local aGoal = navmesh.GetNearestNavArea(vTo, false, 800, false, true)
  if not NoahUber_AreaOK(aStart) or not NoahUber_AreaOK(aGoal) then
    return { vFrom, vTo }
  end
  if aStart:GetID() == aGoal:GetID() then
    return { vFrom, aStart:GetCenter(), vTo }
  end

  local iGoal = aGoal:GetID()
  local tQueue = { aStart }
  local iHead = 1
  local tCame = {}
  local tSeen = { [aStart:GetID()] = true }
  local bFound = false
  local iVisits = 0

  while tQueue[iHead] and iVisits < 400 do
    local aCurrent = tQueue[iHead]
    iHead = iHead + 1
    iVisits = iVisits + 1
    if aCurrent:GetID() == iGoal then
      bFound = true
      break
    end
    local tAdj = aCurrent:GetAdjacentAreas() or {}
    for i = 1, #tAdj do
      local aNext = tAdj[i]
      if NoahUber_AreaOK(aNext) then
        local iId = aNext:GetID()
        if not tSeen[iId] then
          tSeen[iId] = true
          tCame[iId] = aCurrent
          tQueue[#tQueue + 1] = aNext
        end
      end
    end
  end

  if not bFound then return { vFrom, vTo } end

  local tChain = {}
  local aCursor = aGoal
  local iGuard = 0
  while NoahUber_AreaOK(aCursor) and iGuard < 300 do
    tChain[#tChain + 1] = aCursor:GetCenter()
    if aCursor:GetID() == aStart:GetID() then break end
    aCursor = tCame[aCursor:GetID()]
    iGuard = iGuard + 1
  end

  local tPath = { vFrom }
  for i = #tChain, 1, -1 do
    tPath[#tPath + 1] = tChain[i]
  end
  tPath[#tPath + 1] = vTo

  if #tPath > 28 then
    local tSlim = { tPath[1] }
    local iStep = math.max(1, math.ceil(#tPath / 26))
    for i = iStep, #tPath - 1, iStep do
      tSlim[#tSlim + 1] = tPath[i]
    end
    tSlim[#tSlim + 1] = tPath[#tPath]
    return tSlim
  end

  return tPath
end

function NoahUber_SafePath(vFrom, vTo)
  local bOk, tPath = pcall(NoahUber_BuildPath, vFrom, vTo)
  if not bOk or not istable(tPath) or #tPath == 0 then
    return { vFrom, vTo }
  end
  local tClean = {}
  for i = 1, math.min(#tPath, 28) do
    if isvector(tPath[i]) then
      tClean[#tClean + 1] = tPath[i]
    end
  end
  if #tClean == 0 then return { vTo } end
  return tClean
end

function NoahUber_TrackMovement(pPlayer)
  if not IsValid(pPlayer) then return end
  local vPos = NoahUber_ActorPos(pPlayer)
  local flNow = CurTime()
  local vLast = pPlayer.NoahUber_LastPos
  local flLast = pPlayer.NoahUber_LastPosAt or flNow
  if vLast then
    local flDt = flNow - flLast
    if flDt > 2 then
      pPlayer.NoahUber_LastPos = vPos
      pPlayer.NoahUber_LastPosAt = flNow
      return
    end
    if flDt >= 0.2 then
      local flDist = vLast:Distance(vPos)
      local flAllowed = (tonumber(NoahUber.Config.MaxLegalSpeed) or 7000) * math.max(flDt, 0.25) * 1.25
      if flDist > flAllowed and flDist > 1800 then
        pPlayer.NoahUber_SpeedFlags = (pPlayer.NoahUber_SpeedFlags or 0) + 1
        pPlayer.NoahUber_SpeedUntil = flNow + 20
        print("[NoahUber] Déplacement anormal : " .. pPlayer:Nick() .. " (" .. (pPlayer:SteamID() or "?") .. ")")
      end
    end
  end
  if (pPlayer.NoahUber_SpeedUntil or 0) < flNow then
    pPlayer.NoahUber_SpeedFlags = 0
  end
  pPlayer.NoahUber_LastPos = vPos
  pPlayer.NoahUber_LastPosAt = flNow
end

function NoahUber_MovementAllowed(pPlayer, tOrder)
  if not IsValid(pPlayer) or not pPlayer:Alive() then return false end
  if pPlayer:GetMoveType() == MOVETYPE_NOCLIP then
    NoahUber_Notify(pPlayer, 1, "no_noclip")
    return false
  end
  if pPlayer.isArrested and pPlayer:isArrested() then
    NoahUber_Notify(pPlayer, 1, "arrested")
    return false
  end
  if not NoahUber.Config.AntiTeleport then return true end
  if (pPlayer.NoahUber_SpeedFlags or 0) > 0 and (pPlayer.NoahUber_SpeedUntil or 0) > CurTime() then
    NoahUber_Notify(pPlayer, 1, "too_fast")
    return false
  end

  local vFrom = tOrder.legFrom or NoahUber_ActorPos(pPlayer)
  local vTarget = tOrder.state == "accepted" and tOrder.restaurantPos or tOrder.customerPos
  if not isvector(vFrom) or not isvector(vTarget) then return true end
  local flSpeed = tonumber(NoahUber.Config.MaxLegalSpeed) or 7000
  if flSpeed < 800 then flSpeed = 800 end
  local flNeed = vFrom:Distance(vTarget) / flSpeed
  if CurTime() - (tOrder.legStart or CurTime()) < flNeed then
    NoahUber_Notify(pPlayer, 1, "too_fast")
    return false
  end
  return true
end
