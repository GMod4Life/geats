local mGlow
local mIcon
local tCustomerCache = {}
local flCustomerScan = 0
local flArrowYaw = 0

local function NoahUber_Glow()
  if not mGlow then mGlow = Material("sprites/light_glow02_add") end
  return mGlow
end

local function NoahUber_Icon()
  if mIcon and not mIcon:IsError() then return mIcon end
  mIcon = Material("noah_uber/livraison.png", "smooth noclamp")
  if mIcon:IsError() then
    mIcon = Material("noah_uber/livraison", "smooth noclamp")
  end
  return mIcon
end

function NoahUber_TargetPos()
  local tOrder = NoahUber_CurrentFocus and NoahUber_CurrentFocus() or nil
  if not tOrder then
    local tActive = NoahUber.State and NoahUber.State.Active or {}
    tOrder = tActive[1]
  end
  if not tOrder then return end
  local bDrop = (NoahUber.State.FocusMode == 2) or tOrder.state == 2
  if bDrop then return tOrder.custPos, "dropoff", tOrder end
  return tOrder.restPos, "pickup", tOrder
end

local function NoahUber_FloorAt(vPos, pFilter)
  local tTrace = util.TraceLine({
    start = vPos + Vector(0, 0, 48),
    endpos = vPos - Vector(0, 0, 160),
    filter = pFilter,
    mask = MASK_SOLID,
  })
  if tTrace.Hit then return tTrace.HitPos + Vector(0, 0, 2) end
  return vPos + Vector(0, 0, 2)
end

local function NoahUber_Chevron(vOrigin, vDir, flScale, iAlpha)
  local vN = Vector(vDir.x, vDir.y, 0)
  if vN:LengthSqr() < 1 then return end
  vN:Normalize()
  local vR = Vector(-vN.y, vN.x, 0)
  local vUp = Vector(0, 0, 1.5)
  local vTip = vOrigin + vN * (26 * flScale) + vUp
  local vL = vOrigin - vN * (10 * flScale) + vR * (18 * flScale) + vUp
  local vRgt = vOrigin - vN * (10 * flScale) - vR * (18 * flScale) + vUp
  local vIn = vOrigin + vN * (2 * flScale) + vUp
  local iG, iW = iAlpha, math.floor(iAlpha * 0.85)

  render.SetColorMaterial()
  mesh.Begin(MATERIAL_TRIANGLES, 2)
    mesh.Position(vTip) mesh.Color(6, 193, 103, iG) mesh.AdvanceVertex()
    mesh.Position(vL) mesh.Color(6, 193, 103, iG) mesh.AdvanceVertex()
    mesh.Position(vIn) mesh.Color(255, 255, 255, iW) mesh.AdvanceVertex()

    mesh.Position(vTip) mesh.Color(6, 193, 103, iG) mesh.AdvanceVertex()
    mesh.Position(vIn) mesh.Color(255, 255, 255, iW) mesh.AdvanceVertex()
    mesh.Position(vRgt) mesh.Color(6, 193, 103, iG) mesh.AdvanceVertex()
  mesh.End()
end

local function NoahUber_DrawGroundArrow(pPlayer, vTarget)
  local vFlat = vTarget - pPlayer:GetPos()
  vFlat.z = 0
  if vFlat:LengthSqr() < 140 * 140 then return end

  local flWant = vFlat:Angle().y
  flArrowYaw = math.ApproachAngle(flArrowYaw, flWant, FrameTime() * 280)
  local aAim = Angle(0, flArrowYaw, 0)
  local vDir = aAim:Forward()

  local aFace = Angle(0, pPlayer:EyeAngles().y, 0)
  local eVeh = pPlayer:GetVehicle()
  if IsValid(eVeh) then
    aFace = Angle(0, eVeh:GetAngles().y, 0)
  end
  local vStart = NoahUber_FloorAt(pPlayer:GetPos() + aFace:Forward() * 115, pPlayer)
  local flPulse = 0.92 + math.sin(CurTime() * 5) * 0.08
  NoahUber_Chevron(vStart, vDir, flPulse, 235)
  NoahUber_Chevron(vStart + vDir * 34, vDir, flPulse * 0.82, 160)
  NoahUber_Chevron(vStart + vDir * 62, vDir, flPulse * 0.64, 80)
end

local function NoahUber_DrawScreenPin(vPos, flDist)
  local tScreen = (vPos + Vector(0, 0, 72)):ToScreen()
  local iMargin = 72
  local iX, iY = tScreen.x, tScreen.y
  local bOn = tScreen.visible and iX > iMargin and iX < ScrW() - iMargin and iY > iMargin and iY < ScrH() - iMargin
  if not bOn then
    local pPlayer = LocalPlayer()
    local aDir = (vPos - pPlayer:EyePos()):Angle()
    local flYaw = math.rad(math.AngleDifference(aDir.y, pPlayer:EyeAngles().y))
    iX = math.Clamp(ScrW() * 0.5 + math.sin(flYaw) * (ScrW() * 0.5 - iMargin), iMargin, ScrW() - iMargin)
    iY = math.Clamp(ScrH() * 0.5 - math.cos(flYaw) * (ScrH() * 0.5 - iMargin), iMargin + 40, ScrH() - iMargin)
  end

  local iSize = 64
  local mPin = NoahUber_Icon()
  if mPin and not mPin:IsError() then
    surface.SetMaterial(mPin)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(iX - iSize * 0.5, iY - iSize * 0.5 - 6, iSize, iSize)
  else
    NoahUber_DrawCircle(iX, iY - 8, 16, NoahUber_Color("green"), 20)
  end

  local sDist = NoahUber_FormatKm(flDist)
  surface.SetFont(NoahUber_Font(14, "Bold"))
  local iText = surface.GetTextSize(sDist)
  local iPillW = iText + 18
  local iPillY = iY + iSize * 0.5 - 2
  draw.RoundedBox(10, iX - iPillW * 0.5, iPillY, iPillW, 22, Color(12, 12, 14, 220))
  draw.SimpleText(sDist, NoahUber_Font(14, "Bold"), iX, iPillY + 11, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "NoahUber:HUD", function()
  local pPlayer = LocalPlayer()
  if not IsValid(pPlayer) then return end

  if NoahUber_HoldingPointTool(pPlayer) then
    local sKind = string.lower(pPlayer:GetInfo("noah_uber_points_kind") or "restaurant")
    local sLabel = sKind == "customer" and NoahUber_L("type_customer") or NoahUber_L("type_restaurant")
    draw.RoundedBox(8, 24, ScrH() - 84, 280, 36, Color(12, 12, 14, 220))
    draw.SimpleText(sLabel, NoahUber_Font(16, "Bold"), 40, ScrH() - 66, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end

  local vPos, sMode, tOrder = NoahUber_TargetPos()
  local iTop = 24

  if NoahUber.State.Online then
    local sMoney = NoahUber_FormatMoney(NoahUber.State.Week or 0)
    local sWeek = NoahUber_L("week_salary")
    surface.SetFont(NoahUber_Font(18, "Bold"))
    local iMoneyW = surface.GetTextSize(sMoney)
    local iBarW = math.max(220, iMoneyW + 86)
    local iBarX = ScrW() * 0.5 - iBarW * 0.5
    draw.RoundedBox(16, iBarX, iTop, iBarW, 48, Color(12, 12, 14, 230))
    NoahUber_DrawCircle(iBarX + 22, iTop + 24, 5, NoahUber_Color("green"), 12)
    draw.SimpleText(sWeek, NoahUber_Font(12, "Medium"), iBarX + 36, iTop + 14, Color(180, 180, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(sMoney, NoahUber_Font(18, "Bold"), iBarX + 36, iTop + 32, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    iTop = iTop + 58
  end

  if NoahUber.State.Offer and not IsValid(NoahUber.Phone) then
    local tFirst = NoahUber.State.Offer.orders and NoahUber.State.Offer.orders[1]
    local iLeft = math.max(0, math.ceil(NoahUber.State.Offer.expires - CurTime()))
    local sMoney = tFirst and NoahUber_FormatMoney(tFirst.payout) or ""
    draw.RoundedBox(14, ScrW() * 0.5 - 190, ScrH() - 120, 380, 64, Color(12, 12, 14, 230))
    draw.SimpleText(NoahUber_L("new_offer"), NoahUber_Font(16, "Bold"), ScrW() * 0.5, ScrH() - 98, NoahUber_Color("green"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(sMoney .. "   ·   " .. iLeft .. "s   ·   /uber", NoahUber_Font(15, "Bold"), ScrW() * 0.5, ScrH() - 74, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end

  if not vPos or not tOrder then return end
  local flDist = pPlayer:GetPos():Distance(vPos)
  local sTitle = (sMode == "dropoff") and NoahUber_L("focus_drop", tOrder.customer or "") or NoahUber_L("focus_pickup", tOrder.restaurant or "")
  draw.RoundedBox(16, ScrW() * 0.5 - 210, iTop, 420, 52, Color(12, 12, 14, 225))
  draw.RoundedBox(0, ScrW() * 0.5 - 210, iTop, 6, 52, NoahUber_Color("green"))
  draw.SimpleText(sTitle, NoahUber_Font(16, "Bold"), ScrW() * 0.5, iTop + 16, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  local sHint = flDist <= (tonumber(NoahUber.Config.InteractDistance) or 380) and NoahUber_L(sMode == "dropoff" and "use_drop" or "use_pickup") or NoahUber_FormatKm(flDist)
  draw.SimpleText(sHint, NoahUber_Font(14, "Medium"), ScrW() * 0.5, iTop + 36, Color(210, 210, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

  NoahUber_DrawScreenPin(vPos, flDist)
end)

hook.Add("PostDrawTranslucentRenderables", "NoahUber:World", function(bDepth, bSky)
  if bSky or bDepth then return end
  local pPlayer = LocalPlayer()
  if not IsValid(pPlayer) then return end

  local vPos, sMode, tOrder = NoahUber_TargetPos()
  if vPos and tOrder then
    NoahUber_DrawGroundArrow(pPlayer, vPos)
    if sMode == "pickup" then
      local aAng = Angle(0, pPlayer:EyeAngles().y - 90, 90)
      cam.Start3D2D(vPos + Vector(0, 0, 78), aAng, 0.08)
        draw.SimpleText(tOrder.restaurant or "", NoahUber_Font3D(56), 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
      cam.End3D2D()
    end
  end

  if flCustomerScan <= CurTime() then
    flCustomerScan = CurTime() + 0.4
    tCustomerCache = {}
    if NoahUber.State.Online or NoahUber_HoldingPointTool(pPlayer) then
      local tNear = ents.FindInSphere(pPlayer:GetPos(), 1800)
      for i = 1, #tNear do
        if IsValid(tNear[i]) and tNear[i]:GetNWBool("NoahUber_Customer") then
          tCustomerCache[#tCustomerCache + 1] = tNear[i]
        end
      end
    end
  end

  for i = 1, #tCustomerCache do
    local eEnt = tCustomerCache[i]
    if IsValid(eEnt) and eEnt:GetNWBool("NoahUber_Customer") then
      local sName = eEnt:GetNWString("NoahUber_Name", "")
      if sName ~= "" then
        local iHead = math.max(eEnt:OBBMaxs().z, 72) + 16
        local aAng = Angle(0, pPlayer:EyeAngles().y - 90, 90)
        cam.Start3D2D(eEnt:GetPos() + Vector(0, 0, iHead), aAng, 0.08)
          draw.SimpleText(NoahUber.Config.Brand or "Uber Eats", NoahUber_Font3D(36), 0, -6, NoahUber_Color("green"), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
          draw.SimpleText(sName, NoahUber_Font3D(58), 0, 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        cam.End3D2D()
      end
    end
  end

  if not NoahUber_HoldingPointTool(pPlayer) then return end
  local tPoints = NoahUber.AdminPoints or {}
  for i = 1, #tPoints do
    local tPoint = tPoints[i]
    local col = tPoint.kind == "customer" and Color(20, 20, 20) or NoahUber_Color("green")
    render.SetMaterial(NoahUber_Glow())
    render.DrawSprite(tPoint.pos + Vector(0, 0, 16), 18, 18, col)
    local aAng = Angle(0, pPlayer:EyeAngles().y - 90, 90)
    cam.Start3D2D(tPoint.pos + Vector(0, 0, 48), aAng, 0.07)
      local sKind = tPoint.kind == "customer" and NoahUber_L("type_customer") or NoahUber_L("type_restaurant")
      draw.SimpleText(sKind .. " · " .. (tPoint.name ~= "" and tPoint.name or sKind), NoahUber_Font3D(48), 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
  end
end)
