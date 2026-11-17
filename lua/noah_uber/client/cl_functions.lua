NoahUber = NoahUber or {}
NoahUber.Fonts = NoahUber.Fonts or {}
NoahUber.State = NoahUber.State or {
  Online = false,
  Shift = 0,
  Today = 0,
  Total = 0,
  TodayCount = 0,
  Week = 0,
  Offer = nil,
  Active = {},
  Path = {},
  FocusId = 0,
  FocusMode = 1,
  History = {},
  Receipt = nil,
}

CreateClientConVar("noah_uber_language", "", true, false, "fr, en, de, es, pt, ru, tr")

function NoahUber_RX(iValue)
  return (tonumber(iValue) or 0) / 1920 * ScrW()
end

function NoahUber_RY(iValue)
  return (tonumber(iValue) or 0) / 1080 * ScrH()
end

function NoahUber_Font(iSize, sType)
  iSize = math.floor(tonumber(iSize) or 16)
  sType = sType or "Bold"
  local sName = string.format("NoahUber:%d:%s", iSize, sType)
  if not NoahUber.Fonts[sName] then
    local flScale = math.min(ScrW() / 1920, ScrH() / 1080)
    local tWeight = {
      Thin = 200, Light = 300, Medium = 500, SemiBold = 600,
      Bold = 800, ExtraBold = 800, Italic = 500,
    }
    surface.CreateFont(sName, {
      font = ("MontserratWasied %s"):format(sType):Trim(),
      size = math.max(12, math.floor(iSize * flScale)),
      weight = tWeight[sType] or 800,
      extended = true,
      antialias = true,
    })
    NoahUber.Fonts[sName] = true
  end
  return sName
end

function NoahUber_Font3D(iSize)
  iSize = math.floor(tonumber(iSize) or 64)
  local sName = string.format("NoahUber3D:%d:Bold", iSize)
  if not NoahUber.Fonts[sName] then
    surface.CreateFont(sName, {
      font = "MontserratWasied Bold",
      size = iSize,
      weight = 800,
      extended = true,
      antialias = true,
    })
    NoahUber.Fonts[sName] = true
  end
  return sName
end

function NoahUber_Color(sKey)
  local tColors = NoahUber.Constants and NoahUber.Constants.colors
  return (tColors and tColors[sKey]) or color_white
end

function NoahUber_DrawCircle(x, y, radius, col, seg)
  radius = tonumber(radius) or 0
  if radius <= 0.5 or not col then return end
  seg = seg or 20
  draw.NoTexture()
  surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
  local tPoly = { { x = x, y = y } }
  for i = 0, seg do
    local flAng = math.rad((i / seg) * -360)
    tPoly[#tPoly + 1] = {
      x = x + math.sin(flAng) * radius,
      y = y + math.cos(flAng) * radius,
    }
  end
  surface.DrawPoly(tPoly)
end

local function NoahUber_Hash(i)
  local n = math.sin(i * 127.1 + 311.7) * 43758.5453
  return n - math.floor(n)
end

function NoahUber_DrawMap(x, y, w, h, tPins, tLinks, vPlayer)
  draw.RoundedBox(0, x, y, w, h, NoahUber_Color("map"))
  for i = 1, 14 do
    local fw = 26 + NoahUber_Hash(i * 3) * (w * 0.18)
    local fh = 18 + NoahUber_Hash(i * 5) * (h * 0.16)
    local fx = x + 8 + NoahUber_Hash(i * 7) * math.max(8, w - fw - 16)
    local fy = y + 8 + NoahUber_Hash(i * 11) * math.max(8, h - fh - 16)
    draw.RoundedBox(6, fx, fy, fw, fh, NoahUber_Color("mapBlock"))
  end

  local tPts = {}
  for i = 1, #(tPins or {}) do
    if tPins[i].pos then tPts[#tPts + 1] = tPins[i].pos end
  end
  for i = 1, #(tLinks or {}) do
    if tLinks[i][1] then tPts[#tPts + 1] = tLinks[i][1] end
    if tLinks[i][2] then tPts[#tPts + 1] = tLinks[i][2] end
  end
  if vPlayer then tPts[#tPts + 1] = vPlayer end
  if #tPts == 0 then return end

  local minX, maxX = tPts[1].x, tPts[1].x
  local minY, maxY = tPts[1].y, tPts[1].y
  for i = 1, #tPts do
    minX = math.min(minX, tPts[i].x)
    maxX = math.max(maxX, tPts[i].x)
    minY = math.min(minY, tPts[i].y)
    maxY = math.max(maxY, tPts[i].y)
  end
  local spanX = math.max(maxX - minX, 400)
  local spanY = math.max(maxY - minY, 400)
  local function Proj(v)
    local px = x + ((v.x - minX) / spanX) * (w * 0.70) + w * 0.15
    local py = y + (1 - ((v.y - minY) / spanY)) * (h * 0.70) + h * 0.15
    return px, py
  end

  surface.SetDrawColor(20, 20, 20, 235)
  for i = 1, #(tLinks or {}) do
    local a, b = tLinks[i][1], tLinks[i][2]
    if a and b then
      local x1, y1 = Proj(a)
      local x2, y2 = Proj(b)
      for o = -1, 1 do
        surface.DrawLine(x1 + o, y1, x2 + o, y2)
        surface.DrawLine(x1, y1 + o, x2, y2 + o)
      end
    end
  end

  for i = 1, #(tPins or {}) do
    local px, py = Proj(tPins[i].pos)
    NoahUber_DrawCircle(px, py, 10, tPins[i].color or color_white, 18)
    NoahUber_DrawCircle(px, py, 4, color_white, 12)
  end

  if vPlayer then
    local px, py = Proj(vPlayer)
    NoahUber_DrawCircle(px, py, 8, Color(20, 20, 20), 16)
    NoahUber_DrawCircle(px, py, 4, NoahUber_Color("green"), 12)
  end
end

function NoahUber_FitText(sText, sFont, iMax)
  sText = tostring(sText or "")
  surface.SetFont(sFont)
  if surface.GetTextSize(sText) <= iMax then return sText end
  local sCut = sText
  while #sCut > 1 do
    sCut = string.sub(sCut, 1, #sCut - 1)
    local sTry = sCut .. "..."
    if surface.GetTextSize(sTry) <= iMax then return sTry end
  end
  return "..."
end

function NoahUber_ItemLine(tItems)
  local tNames = {}
  for i = 1, #(tItems or {}) do
    tNames[#tNames + 1] = NoahUber_FoodName(tItems[i])
  end
  if #tNames == 0 then return "-" end
  return table.concat(tNames, ", ")
end

function NoahUber_StopRing()
  if NoahUber.Ring and NoahUber.Ring.Stop then
    NoahUber.Ring:Stop()
  end
  NoahUber.Ring = nil
  NoahUber.RingSerial = nil
end

function NoahUber_StartRing(iSerial)
  if NoahUber.RingSerial == iSerial and NoahUber.Ring and NoahUber.Ring.IsPlaying and NoahUber.Ring:IsPlaying() then
    return
  end
  NoahUber_StopRing()
  NoahUber.RingSerial = iSerial
  local sPath = NoahUber.Config.OrderSound or "sound/noah_uber/uber_eats_sounds.wav"
  sound.PlayFile(sPath, "noblock", function(eStation)
    if not IsValid(eStation) then
      surface.PlaySound("buttons/bell1.wav")
      return
    end
    if not NoahUber.State.Offer or NoahUber.State.Offer.serial ~= iSerial then
      eStation:Stop()
      return
    end
    eStation:SetVolume(1)
    if NoahUber.Config.LoopRing then
      eStation:EnableLooping(true)
    end
    eStation:Play()
    NoahUber.Ring = eStation
  end)
end

function NoahUber_PlaySuccess()
  local sPath = NoahUber.Config.SuccessSound or "sound/noah_uber/success.wav"
  sound.PlayFile(sPath, "noblock", function(eStation)
    if not IsValid(eStation) then
      surface.PlaySound("buttons/button15.wav")
      return
    end
    eStation:SetVolume(1)
    eStation:Play()
  end)
end

function NoahUber_HoldingPointTool(pPlayer)
  pPlayer = pPlayer or LocalPlayer()
  if not IsValid(pPlayer) then return false end
  local eWep = pPlayer:GetActiveWeapon()
  if not IsValid(eWep) or eWep:GetClass() ~= "gmod_tool" then return false end
  return pPlayer:GetInfo("gmod_toolmode") == "noah_uber_points"
end
