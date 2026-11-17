NoahUber = NoahUber or {}
NoahUber.Points = NoahUber.Points or {}
NoahUber.NextPointId = NoahUber.NextPointId or 1

local function NoahUber_ToVector(tData)
  if not istable(tData) then return end
  local x = tonumber(tData.x)
  local y = tonumber(tData.y)
  local z = tonumber(tData.z)
  if not x or not y or not z then return end
  if x ~= x or y ~= y or z ~= z then return end
  if math.abs(x) > 200000 or math.abs(y) > 200000 or math.abs(z) > 200000 then return end
  return Vector(x, y, z)
end

function NoahUber_GetPoints(sKind)
  local tList = {}
  for i = 1, #NoahUber.Points do
    local tPoint = NoahUber.Points[i]
    if not sKind or tPoint.kind == sKind then
      tList[#tList + 1] = tPoint
    end
  end
  return tList
end

function NoahUber_HasDeliverySpots()
  return #NoahUber_GetPoints("restaurant") > 0 and #NoahUber_GetPoints("customer") > 0
end

function NoahUber_SavePoints()
  file.CreateDir("noah_uber")
  local tSave = { nextId = NoahUber.NextPointId, points = {} }
  for i = 1, #NoahUber.Points do
    local tPoint = NoahUber.Points[i]
    tSave.points[#tSave.points + 1] = {
      id = tPoint.id,
      kind = tPoint.kind,
      name = tPoint.name,
      address = tPoint.address,
      x = tPoint.pos.x,
      y = tPoint.pos.y,
      z = tPoint.pos.z,
      yaw = tPoint.yaw or 0,
    }
  end
  file.Write("noah_uber/points.json", util.TableToJSON(tSave))
end

function NoahUber_LoadPoints()
  NoahUber.Points = {}
  NoahUber.NextPointId = 1
  if not file.Exists("noah_uber/points.json", "DATA") then return end
  local sRaw = file.Read("noah_uber/points.json", "DATA")
  if not sRaw or #sRaw > 250000 then return end
  local tData = util.JSONToTable(sRaw)
  if not istable(tData) or not istable(tData.points) then return end

  local iMax = math.floor(tonumber(NoahUber.Config.MaxPoints) or 80)
  local tSeen = {}
  for i = 1, #tData.points do
    if #NoahUber.Points >= iMax then break end
    local tRaw = tData.points[i]
    if istable(tRaw) then
      local iId = math.floor(tonumber(tRaw.id) or 0)
      local sKind = tRaw.kind == "customer" and "customer" or (tRaw.kind == "restaurant" and "restaurant" or nil)
      local vPos = NoahUber_ToVector(tRaw)
      if iId > 0 and sKind and vPos and not tSeen[iId] then
        tSeen[iId] = true
        NoahUber.Points[#NoahUber.Points + 1] = {
          id = iId,
          kind = sKind,
          name = NoahUber_Sanitize(tRaw.name, 40),
          address = NoahUber_Sanitize(tRaw.address, 80),
          pos = vPos,
          yaw = math.Clamp(tonumber(tRaw.yaw) or 0, -360, 360),
        }
        if iId >= NoahUber.NextPointId then
          NoahUber.NextPointId = iId + 1
        end
      end
    end
  end
end

function NoahUber_AddPoint(sKind, sName, sAddress, vPos, flYaw)
  if sKind ~= "restaurant" and sKind ~= "customer" then return false, "invalid_point" end
  if not isvector(vPos) then return false, "invalid_point" end
  local iMax = math.floor(tonumber(NoahUber.Config.MaxPoints) or 80)
  if #NoahUber.Points >= iMax then return false, "point_limit" end

  for i = 1, #NoahUber.Points do
    if NoahUber.Points[i].pos:Distance(vPos) < 48 then
      return false, "point_exists"
    end
  end

  local tPoint = {
    id = NoahUber.NextPointId,
    kind = sKind,
    name = NoahUber_Sanitize(sName, 40),
    address = NoahUber_Sanitize(sAddress, 80),
    pos = Vector(vPos.x, vPos.y, vPos.z),
    yaw = math.Clamp(tonumber(flYaw) or 0, -360, 360),
  }
  NoahUber.NextPointId = NoahUber.NextPointId + 1
  NoahUber.Points[#NoahUber.Points + 1] = tPoint
  NoahUber_SavePoints()
  return true, tPoint
end

function NoahUber_RemoveNearestPoint(vPos)
  if not isvector(vPos) then return false end
  local tBest, flBest
  for i = 1, #NoahUber.Points do
    local flDist = NoahUber.Points[i].pos:Distance(vPos)
    if flDist <= 160 and (not tBest or flDist < flBest) then
      tBest = NoahUber.Points[i]
      flBest = flDist
    end
  end
  if not tBest then return false end

  for i = #NoahUber.Points, 1, -1 do
    if NoahUber.Points[i].id == tBest.id then
      table.remove(NoahUber.Points, i)
    end
  end
  NoahUber_SavePoints()
  return true
end

function NoahUber_RandomRestaurant()
  local tList = NoahUber_GetPoints("restaurant")
  if #tList == 0 then return end
  return tList[math.random(#tList)]
end

function NoahUber_RandomCustomerPoint(vOrigin, iExclude)
  local tList = NoahUber_GetPoints("customer")
  local iMin = tonumber(NoahUber.Config.MinDistance) or 1800
  local iMax = tonumber(NoahUber.Config.MaxDistance) or 16000
  local tPool = {}
  for i = 1, #tList do
    local tPoint = tList[i]
    if tPoint.id ~= iExclude then
      local flDist = tPoint.pos:Distance(vOrigin)
      if flDist >= iMin and flDist <= iMax then
        tPool[#tPool + 1] = tPoint
      end
    end
  end
  if #tPool == 0 then return end
  return tPool[math.random(#tPool)]
end

NoahUber_LoadPoints()
