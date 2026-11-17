NoahUber = NoahUber or {}

function NoahUber_Sanitize(sText, iMax)
  sText = tostring(sText or "")
  sText = string.gsub(sText, "[%c%z]", "")
  sText = string.gsub(sText, "%%", "")
  iMax = math.floor(tonumber(iMax) or 48)

  if utf8 and utf8.len and utf8.sub then
    local bOk, iLen = pcall(utf8.len, sText)
    if bOk and iLen and iLen > iMax then
      local bCut, sCut = pcall(utf8.sub, sText, 1, iMax)
      if bCut and sCut then return sCut end
    elseif bOk then
      return sText
    end
  end

  if #sText > iMax then
    sText = string.sub(sText, 1, iMax)
  end
  return sText
end

function NoahUber_ValidSteam(pPlayer)
  if not IsValid(pPlayer) or not pPlayer:IsPlayer() or pPlayer:IsBot() then return end
  local sId = pPlayer:SteamID64()
  if not sId or not string.match(sId, "^7656119%d%d%d%d%d%d%d%d%d%d$") then return end
  return sId
end

function NoahUber_IsAdmin(pPlayer)
  if not IsValid(pPlayer) or not pPlayer:IsPlayer() then return false end
  if pPlayer:IsSuperAdmin() or pPlayer:IsAdmin() then return true end
  local tRanks = NoahUber.Config.AdminRanks or {}
  return tRanks[string.lower(pPlayer:GetUserGroup() or "")] == true
end

function NoahUber_GetTeam()
  return TEAM_NOAHUBER
end

function NoahUber_IsCourier(pPlayer)
  if not IsValid(pPlayer) or not pPlayer:IsPlayer() or pPlayer:IsBot() then return false end
  if not NoahUber.Config.RequireJob then return true end
  local iTeam = NoahUber_GetTeam()
  return iTeam ~= nil and pPlayer:Team() == iTeam
end

function NoahUber_GetPayBounds()
  local iHard = tonumber(NoahUber.Constants["hardMaxPay"]) or 75000
  local iMin = math.floor(tonumber(NoahUber.Config.MinPay) or 10000)
  local iMax = math.floor(tonumber(NoahUber.Config.MaxPay) or iHard)
  iMin = math.Clamp(iMin, 1, iHard)
  iMax = math.Clamp(iMax, iMin, iHard)
  return iMin, iMax
end

function NoahUber_ComputePay(iDistance)
  local iMin, iMax = NoahUber_GetPayBounds()
  local iMinDist = tonumber(NoahUber.Config.MinDistance) or 1800
  local iMaxDist = tonumber(NoahUber.Config.MaxDistance) or 16000
  local flFrac = 0
  if iMaxDist > iMinDist then
    flFrac = math.Clamp((iDistance - iMinDist) / (iMaxDist - iMinDist), 0, 1)
  end
  flFrac = flFrac ^ 0.85
  local iPay = math.floor(iMin + (iMax - iMin) * flFrac + math.random(-350, 350))
  iPay = math.floor(iPay / 50) * 50
  if iPay ~= iPay then return iMin end
  return math.Clamp(iPay, iMin, iMax)
end

function NoahUber_FormatMoney(iAmount)
  iAmount = math.floor(tonumber(iAmount) or 0)
  if DarkRP and DarkRP.formatMoney then
    return DarkRP.formatMoney(iAmount)
  end
  local sSign = iAmount < 0 and "-" or ""
  local sDigits = tostring(math.abs(iAmount))
  local sPretty = string.reverse(sDigits):gsub("(%d%d%d)", "%1 "):reverse()
  if string.sub(sPretty, 1, 1) == " " then sPretty = string.sub(sPretty, 2) end
  return sSign .. sPretty
end

function NoahUber_FormatKm(iUnits)
  local flPer = tonumber(NoahUber.Config.UnitsPerKm) or 1600
  if flPer <= 0 then flPer = 1600 end
  local flKm = (tonumber(iUnits) or 0) / flPer
  if flKm < 0.1 then
    return string.format("%d m", math.max(0, math.floor(flKm * 1000)))
  end
  return string.format("%.1f km", flKm)
end

function NoahUber_EtaSeconds(iUnits)
  local flPer = tonumber(NoahUber.Config.UnitsPerKm) or 1600
  if flPer <= 0 then flPer = 1600 end
  local flKm = (tonumber(iUnits) or 0) / flPer
  local iMinutes = math.Clamp(math.ceil(flKm * (tonumber(NoahUber.Config.MinutesPerKm) or 3)), 3, 25)
  return iMinutes * 60
end

function NoahUber_FormatEta(iSeconds, iUnits)
  local iMinutes = math.max(1, math.ceil((tonumber(iSeconds) or 60) / 60))
  return NoahUber_L("min_total", iMinutes, NoahUber_FormatKm(iUnits))
end

function NoahUber_FormatDate(iUnix)
  return os.date("%d/%m/%Y", math.floor(tonumber(iUnix) or os.time()))
end

function NoahUber_FormatClock(iUnix)
  return os.date("%H:%M", math.floor(tonumber(iUnix) or os.time()))
end

function NoahUber_FoodName(sKey)
  if not NoahUber.Constants.foods then return tostring(sKey or "") end
  for _, sFood in ipairs(NoahUber.Constants.foods) do
    if sFood == sKey then return NoahUber_L("food_" .. sKey) end
  end
  return NoahUber_L("food_burger")
end

function NoahUber_PointLabel(tPoint)
  if tPoint and tPoint.name and tPoint.name ~= "" then return tPoint.name end
  local tNames = NoahUber.Constants["defaultRestaurants"] or { "Pizza Shop" }
  local iIndex = ((tonumber(tPoint and tPoint.id) or 0) % #tNames) + 1
  return tNames[iIndex]
end

function NoahUber_ConsumeNet(pPlayer, sAction, flDelay)
  if not IsValid(pPlayer) or not pPlayer:IsPlayer() or pPlayer:IsBot() then return false end
  local flNow = CurTime()
  pPlayer.NoahUberNet = pPlayer.NoahUberNet or {}
  local tBucket = pPlayer.NoahUberNet
  if (tBucket._window or 0) <= flNow then
    tBucket._window = flNow + 1
    tBucket._count = 0
  end
  tBucket._count = (tBucket._count or 0) + 1
  if tBucket._count > 12 then return false end
  if (tBucket[sAction] or 0) > flNow then return false end
  tBucket[sAction] = flNow + (tonumber(flDelay) or 0.4)
  return true
end
