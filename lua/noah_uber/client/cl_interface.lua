local function C(sKey)
  return NoahUber_Color(sKey)
end

local function NoahUber_BlankButton(pParent)
  local vBtn = vgui.Create("DButton", pParent)
  vBtn:SetText("")
  vBtn:SetCursor("hand")
  return vBtn
end

function NoahUber_ClosePhone()
  if IsValid(NoahUber.Phone) then
    NoahUber.Phone:Remove()
  end
  NoahUber.Phone = nil
end

function NoahUber_RebuildScreen()
  local vFrame = NoahUber.Phone
  if not IsValid(vFrame) or not IsValid(vFrame.Content) then return end
  local sScreen = vFrame.Screen or "home"
  local bNav = sScreen ~= "offer" and sScreen ~= "receipt"
  vFrame.Nav:SetVisible(bNav)
  vFrame.Nav:SetTall(bNav and NoahUber_RY(64) or 0)
  function vFrame.Content:PerformLayout() end
  vFrame.Content.Paint = function() end
  vFrame.Content:Clear()
  if sScreen == "offer" then
    NoahUber_BuildOffer(vFrame.Content)
  elseif sScreen == "trip" then
    NoahUber_BuildTrip(vFrame.Content)
  elseif sScreen == "earnings" then
    NoahUber_BuildEarnings(vFrame.Content)
  elseif sScreen == "receipt" then
    NoahUber_BuildReceipt(vFrame.Content)
  else
    NoahUber_BuildHome(vFrame.Content)
  end
end

function NoahUber_SetScreen(sName)
  if not IsValid(NoahUber.Phone) then return end
  NoahUber.Phone.Screen = sName or "home"
  NoahUber_RebuildScreen()
end

function NoahUber_CreatePhone()
  if IsValid(NoahUber.Phone) then return end

  local iW = math.floor(ScrW() * (430 / 1920))
  local iH = math.floor(iW * (860 / 430))
  if iH > ScrH() * 0.92 then
    iH = math.floor(ScrH() * 0.92)
    iW = math.floor(iH * (430 / 860))
  end

  local vFrame = vgui.Create("DFrame")
  vFrame:SetSize(iW, iH)
  vFrame:Center()
  vFrame:SetTitle("")
  vFrame:ShowCloseButton(false)
  vFrame:SetDraggable(false)
  vFrame:MakePopup()
  vFrame:NoClipping(true)
  vFrame.Screen = "home"
  function vFrame:Paint(w, h)
    draw.RoundedBox(36, 8, 12, w, h, Color(0, 0, 0, 60))
    draw.RoundedBox(36, 0, 0, w, h, C("phone"))
    draw.SimpleText(os.date("%H:%M"), NoahUber_Font(13, "Bold"), NoahUber_RX(22), NoahUber_RY(26), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end
  function vFrame:OnKeyCodePressed(iKey)
    if iKey ~= KEY_ESCAPE then return end
    NoahUber_ClosePhone()
    if gui and gui.HideGameUI then gui.HideGameUI() end
  end
  function vFrame:Think()
    if not input.IsKeyDown(KEY_ESCAPE) then
      self.NoahUberEsc = nil
      return
    end
    if self.NoahUberEsc then return end
    self.NoahUberEsc = true
    NoahUber_ClosePhone()
    if gui and gui.HideGameUI then gui.HideGameUI() end
  end

  local vClose = NoahUber_BlankButton(vFrame)
  vClose:SetSize(NoahUber_RX(30), NoahUber_RX(30))
  vClose:SetZPos(8)
  function vClose:Paint(w, h)
    draw.RoundedBox(w * 0.5, 0, 0, w, h, Color(255, 255, 255, 28))
    draw.SimpleText("X", NoahUber_Font(14, "Bold"), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  function vClose:DoClick()
    NoahUber_ClosePhone()
  end
  vClose:SetPos(iW - NoahUber_RX(44), NoahUber_RY(12))
  vClose:SetZPos(20)

  local vScreen = vgui.Create("DPanel", vFrame)
  vScreen:Dock(FILL)
  vScreen:DockMargin(NoahUber_RX(12), NoahUber_RY(48), NoahUber_RX(12), NoahUber_RY(12))
  function vScreen:Paint(w, h)
    draw.RoundedBox(26, 0, 0, w, h, C("background"))
    draw.RoundedBox(8, w * 0.5 - NoahUber_RX(36), 6, NoahUber_RX(72), NoahUber_RY(14), C("phone"))
  end

  local vNav = vgui.Create("DPanel", vScreen)
  vNav:Dock(BOTTOM)
  vNav:SetTall(NoahUber_RY(64))
  function vNav:Paint(w, h)
    surface.SetDrawColor(230, 230, 230, 255)
    surface.DrawRect(0, 0, w, 1)
  end

  local tTabs = {
    { id = "home", key = "nav_home" },
    { id = "trip", key = "nav_trips" },
    { id = "earnings", key = "nav_earnings" },
  }
  vNav.Buttons = {}
  for i = 1, #tTabs do
    local tTab = tTabs[i]
    local vBtn = NoahUber_BlankButton(vNav)
    vBtn.Tab = tTab.id
    function vBtn:Paint(w, h)
      local bOn = IsValid(NoahUber.Phone) and NoahUber.Phone.Screen == self.Tab
      local col = bOn and C("green") or C("muted")
      if bOn then
        draw.RoundedBox(3, w * 0.5 - 10, 10, 20, 4, C("green"))
      end
      draw.SimpleText(NoahUber_L(tTab.key), NoahUber_Font(15, "Bold"), w * 0.5, h * 0.58, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    function vBtn:DoClick()
      if self.Tab == "earnings" then
        net.Start("NoahUber:RequestHistory")
        net.SendToServer()
      end
      NoahUber_SetScreen(self.Tab)
    end
    vNav.Buttons[i] = vBtn
  end
  function vNav:PerformLayout(w, h)
    local iBw = math.floor(w / 3)
    for i = 1, #self.Buttons do
      self.Buttons[i]:SetSize(iBw, h)
      self.Buttons[i]:SetPos((i - 1) * iBw, 0)
    end
  end

  local vContent = vgui.Create("DPanel", vScreen)
  vContent:Dock(FILL)
  function vContent:Paint(w, h)
    draw.RoundedBox(0, 0, 0, w, h, C("background"))
  end

  vFrame.Nav = vNav
  vFrame.Content = vContent
  NoahUber.Phone = vFrame

  net.Start("NoahUber:RequestState")
  net.SendToServer()
end

function NoahUber_OpenPhone(bKeep)
  if IsValid(NoahUber.Phone) and not bKeep then
    NoahUber_ClosePhone()
    return
  end
  NoahUber_CreatePhone()
  if NoahUber.State.Offer then
    NoahUber_SetScreen("offer")
  elseif #(NoahUber.State.Active or {}) > 0 then
    NoahUber_SetScreen("trip")
  else
    NoahUber_SetScreen("home")
  end
end

local function NoahUber_SendOnline(bOnline)
  net.Start("NoahUber:SetOnline")
  net.WriteBool(bOnline)
  net.SendToServer()
end

function NoahUber_BuildHome(pContent)
  local vLang = NoahUber_BlankButton(pContent)
  function vLang:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 18))
    draw.SimpleText(string.upper(NoahUber_GetLangCode()), NoahUber_Font(13, "Bold"), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  function vLang:DoClick()
    local tCodes = NoahUber.LangCodes or { "fr" }
    local sCur = NoahUber_GetLangCode()
    local iNext = 1
    for i = 1, #tCodes do
      if tCodes[i] == sCur then iNext = (i % #tCodes) + 1 end
    end
    RunConsoleCommand("noah_uber_language", tCodes[iNext])
    NoahUber_RebuildScreen()
  end

  local vGo = NoahUber_BlankButton(pContent)
  function vGo:Paint(w, h)
    local bOn = NoahUber.State.Online
    draw.RoundedBox(14, 0, 0, w, h, bOn and Color(32, 32, 32) or C("green"))
    draw.SimpleText(NoahUber_L(bOn and "go_offline" or "go_online"), NoahUber_Font(18, "Bold"), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  function vGo:DoClick()
    NoahUber_SendOnline(not NoahUber.State.Online)
  end

  local vBike = NoahUber_BlankButton(pContent)
  function vBike:Paint(w, h)
    draw.RoundedBox(14, 0, 0, w, h, Color(22, 22, 24))
    draw.SimpleText(NoahUber_L("spawn_vehicle"), NoahUber_Font(16, "Bold"), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  function vBike:DoClick()
    net.Start("NoahUber:SpawnVehicle")
    net.SendToServer()
  end

  local vTrip = NoahUber_BlankButton(pContent)
  function vTrip:Paint(w, h)
    if #(NoahUber.State.Active or {}) == 0 then return end
    draw.RoundedBox(14, 0, 0, w, h, C("soft"))
    local tOrder = NoahUber.State.Active[1]
    draw.SimpleText(NoahUber_L("order_ready"), NoahUber_Font(16, "Bold"), 16, h * 0.35, C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tOrder and tOrder.restaurant or "", NoahUber_Font(14, "Medium"), 16, h * 0.68, C("muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(NoahUber_L("nav_trips"), NoahUber_Font(14, "Bold"), w - 16, h * 0.5, C("green"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
  end
  function vTrip:Think()
    self:SetVisible(#(NoahUber.State.Active or {}) > 0)
  end
  function vTrip:DoClick()
    if #(NoahUber.State.Active or {}) > 0 then
      NoahUber_SetScreen("trip")
    end
  end

  function pContent:PerformLayout(w, h)
    if not IsValid(vLang) or not IsValid(vGo) or not IsValid(vBike) or not IsValid(vTrip) then return end
    vLang:SetSize(NoahUber_RX(52), NoahUber_RY(26))
    vLang:SetPos(w - NoahUber_RX(68), NoahUber_RY(18))
    vGo:SetSize(w - NoahUber_RX(32), NoahUber_RY(50))
    vGo:SetPos(NoahUber_RX(16), h - NoahUber_RY(66))
    vBike:SetSize(w - NoahUber_RX(32), NoahUber_RY(42))
    vBike:SetPos(NoahUber_RX(16), h - NoahUber_RY(116))
    vTrip:SetSize(w - NoahUber_RX(32), NoahUber_RY(54))
    vTrip:SetPos(NoahUber_RX(16), h - NoahUber_RY(180))
  end

  function pContent:Paint(w, h)
    local iHead = math.floor(h * 0.36)
    draw.RoundedBox(0, 0, 0, w, iHead, C("phone"))
    draw.RoundedBox(22, 0, iHead - 28, w, h, C("sheet"))
    draw.SimpleText(NoahUber.Config.Brand or "Uber Eats", NoahUber_Font(18, "Bold"), NoahUber_RX(20), NoahUber_RY(36), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.DrawText(NoahUber_L("tagline"), NoahUber_Font(26, "Bold"), NoahUber_RX(20), NoahUber_RY(62), color_white, TEXT_ALIGN_LEFT)

    local sStatus = NoahUber.State.Online and NoahUber_L("online") or NoahUber_L("offline")
    local colDot = NoahUber.State.Online and C("green") or C("muted")
    draw.SimpleText(sStatus, NoahUber_Font(16, "Bold"), NoahUber_RX(36), iHead + NoahUber_RY(8), C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    NoahUber_DrawCircle(NoahUber_RX(22), iHead + NoahUber_RY(8), 5, colDot, 14)

    local sHint = NoahUber.State.Online and NoahUber_L("searching") or NoahUber_L("connect_hint")
    if #(NoahUber.State.Active or {}) > 0 then
      sHint = NoahUber_L("trip_progress", 1, #NoahUber.State.Active)
    end
    draw.SimpleText(sHint, NoahUber_Font(14, "Medium"), NoahUber_RX(20), iHead + NoahUber_RY(32), C("muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local tStats = {
      { NoahUber_L("shift_salary"), NoahUber_FormatMoney(NoahUber.State.Shift or 0) },
      { NoahUber_L("today_salary"), NoahUber_FormatMoney(NoahUber.State.Today or 0) },
      { NoahUber_L("total_salary"), NoahUber_FormatMoney(NoahUber.State.Total or 0) },
    }
    local iBoxW = (w - NoahUber_RX(48)) / 3
    local iBoxY = iHead + NoahUber_RY(56)
    for i = 1, 3 do
      local iX = NoahUber_RX(16) + (i - 1) * (iBoxW + NoahUber_RX(8))
      draw.RoundedBox(14, iX, iBoxY, iBoxW, NoahUber_RY(78), C("soft"))
      draw.SimpleText(NoahUber_FitText(tStats[i][2], NoahUber_Font(15, "Bold"), iBoxW - 10), NoahUber_Font(15, "Bold"), iX + iBoxW * 0.5, iBoxY + NoahUber_RY(28), C("ink"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
      draw.SimpleText(NoahUber_FitText(tStats[i][1], NoahUber_Font(11, "Medium"), iBoxW - 8), NoahUber_Font(11, "Medium"), iX + iBoxW * 0.5, iBoxY + NoahUber_RY(52), C("muted"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
  end
end

function NoahUber_BuildOffer(pContent)
  local vAccept = NoahUber_BlankButton(pContent)
  function vAccept:Paint(w, h)
    draw.RoundedBox(14, 0, 0, w, h, C("green"))
    local iLeft = 0
    if NoahUber.State.Offer then
      iLeft = math.max(0, math.ceil(NoahUber.State.Offer.expires - CurTime()))
    end
    local sText = NoahUber_L("accept")
    if iLeft > 0 then sText = sText .. "   " .. iLeft .. "s" end
    draw.SimpleText(sText, NoahUber_Font(20, "Bold"), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  function vAccept:DoClick()
    NoahUber_StopRing()
    net.Start("NoahUber:RespondOffer")
    net.WriteBool(true)
    net.SendToServer()
  end

  local vDecline = NoahUber_BlankButton(pContent)
  function vDecline:Paint(w, h)
    draw.RoundedBox(14, 0, 0, w, h, Color(22, 22, 24))
    draw.SimpleText(NoahUber_L("decline"), NoahUber_Font(16, "Bold"), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  function vDecline:DoClick()
    NoahUber_StopRing()
    net.Start("NoahUber:RespondOffer")
    net.WriteBool(false)
    net.SendToServer()
  end

  function pContent:PerformLayout(w, h)
    if not IsValid(vAccept) or not IsValid(vDecline) then return end
    vAccept:SetSize(w - NoahUber_RX(32), NoahUber_RY(50))
    vAccept:SetPos(NoahUber_RX(16), h - NoahUber_RY(66))
    vDecline:SetSize(w - NoahUber_RX(32), NoahUber_RY(40))
    vDecline:SetPos(NoahUber_RX(16), h - NoahUber_RY(114))
  end

  function pContent:Paint(w, h)
    local tOffer = NoahUber.State.Offer
    local tOrders = (tOffer and tOffer.orders) or {}
    local tFirst = tOrders[1]
    if not tFirst then return end

    local iCount = #tOrders
    local iMap = (iCount > 1) and math.floor(h * 0.28) or math.floor(h * 0.40)
    local tPins, tLinks = {}, {}
    tPins[1] = { pos = tFirst.restPos, color = C("green") }
    for i = 1, iCount do
      tPins[#tPins + 1] = { pos = tOrders[i].custPos, color = C("ink") }
      tLinks[#tLinks + 1] = { tFirst.restPos, tOrders[i].custPos }
    end
    NoahUber_DrawMap(0, 0, w, iMap + 30, tPins, tLinks)

    draw.RoundedBox(22, 0, iMap, w, h - iMap + 40, C("sheet"))
    local flDur = math.max(1, tonumber(NoahUber.Config.OfferDuration) or 30)
    local flLeft = math.max(0, (tOffer.expires or 0) - CurTime())
    draw.RoundedBox(0, 18, iMap, (w - 36) * math.Clamp(flLeft / flDur, 0, 1), 4, C("green"))

    local sBadge = NoahUber_L("delivery")
    surface.SetFont(NoahUber_Font(13, "Bold"))
    local iBadgeW = surface.GetTextSize(sBadge)
    local iBadgeX, iBadgeY = NoahUber_RX(18), iMap + NoahUber_RY(18)
    draw.RoundedBox(10, iBadgeX, iBadgeY, iBadgeW + NoahUber_RX(16), NoahUber_RY(24), C("green"))
    draw.SimpleText(sBadge, NoahUber_Font(13, "Bold"), iBadgeX + NoahUber_RX(8), iBadgeY + NoahUber_RY(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local sExtra = iCount > 1 and NoahUber_L("double_order") or ((tFirst.payout or 0) >= 50000 and NoahUber_L("exclusive") or nil)
    if sExtra then
      surface.SetFont(NoahUber_Font(13, "Bold"))
      local iExtraW = surface.GetTextSize(sExtra)
      local iExtraX = iBadgeX + iBadgeW + NoahUber_RX(24)
      draw.RoundedBox(10, iExtraX, iBadgeY, iExtraW + NoahUber_RX(16), NoahUber_RY(24), C("exclusive"))
      draw.SimpleText(sExtra, NoahUber_Font(13, "Bold"), iExtraX + NoahUber_RX(8), iBadgeY + NoahUber_RY(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local iPay = 0
    for i = 1, iCount do
      iPay = iPay + (tOrders[i].payout or 0)
    end
    local iTextY = iMap + NoahUber_RY(52)
    draw.SimpleText(NoahUber_FormatMoney(iCount > 1 and iPay or tFirst.payout), NoahUber_Font(40, "Bold"), NoahUber_RX(18), iTextY, C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(NoahUber_L("tip_included"), NoahUber_Font(14, "Medium"), NoahUber_RX(18), iTextY + NoahUber_RY(46), C("muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(NoahUber_FormatEta(tFirst.eta, tFirst.distance), NoahUber_Font(16, "Bold"), NoahUber_RX(18), iTextY + NoahUber_RY(70), C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local iRow = iTextY + NoahUber_RY(102)
    for i = 1, iCount do
      local tOrder = tOrders[i]
      draw.SimpleText(NoahUber_FitText(tOrder.restaurant or "", NoahUber_Font(18, "Bold"), w - NoahUber_RX(36)), NoahUber_Font(18, "Bold"), NoahUber_RX(18), iRow, C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
      draw.SimpleText(NoahUber_FitText(tOrder.restAddress or "", NoahUber_Font(14, "Medium"), w - NoahUber_RX(36)), NoahUber_Font(14, "Medium"), NoahUber_RX(18), iRow + NoahUber_RY(22), C("muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
      local sWho = (tOrder.customer or "") .. "  ·  " .. (tOrder.custAddress or "")
      draw.SimpleText(NoahUber_FitText(sWho, NoahUber_Font(14, "Medium"), w - NoahUber_RX(36)), NoahUber_Font(14, "Medium"), NoahUber_RX(18), iRow + NoahUber_RY(42), C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
      if iCount > 1 then
        draw.SimpleText(NoahUber_FormatMoney(tOrder.payout), NoahUber_Font(14, "Bold"), w - NoahUber_RX(18), iRow, C("green"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
      end
      iRow = iRow + NoahUber_RY(68)
    end
    if iCount > 1 then
      draw.SimpleText(NoahUber_L("double_total", NoahUber_FormatMoney(iPay)), NoahUber_Font(15, "Bold"), NoahUber_RX(18), h - NoahUber_RY(132), C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
  end
end

function NoahUber_CurrentFocus()
  local tActive = NoahUber.State.Active or {}
  for i = 1, #tActive do
    if tActive[i].id == NoahUber.State.FocusId then return tActive[i] end
  end
  return tActive[1]
end

function NoahUber_BuildTrip(pContent)
  local vAct = NoahUber_BlankButton(pContent)
  function vAct:Paint(w, h)
    local tOrder = NoahUber_CurrentFocus()
    if not tOrder then return end
    local bDrop = NoahUber.State.FocusMode == 2 or tOrder.state == 2
    draw.RoundedBox(14, 0, 0, w, h, C("green"))
    local sText = NoahUber_L(bDrop and "dropoff_action" or "pickup_action")
    draw.SimpleText(sText, NoahUber_Font(18, "Bold"), w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  end
  function vAct:DoClick()
    local tOrder = NoahUber_CurrentFocus()
    if not tOrder then return end
    local bDrop = NoahUber.State.FocusMode == 2 or tOrder.state == 2
    net.Start(bDrop and "NoahUber:Deliver" or "NoahUber:Pickup")
    net.WriteUInt(tOrder.id or 0, 32)
    net.SendToServer()
  end
  function pContent:PerformLayout(w, h)
    if not IsValid(vAct) then return end
    vAct:SetSize(w - NoahUber_RX(32), NoahUber_RY(52))
    vAct:SetPos(NoahUber_RX(16), h - NoahUber_RY(68))
  end
  function pContent:Paint(w, h)
    local tActive = NoahUber.State.Active or {}
    local tFocus = NoahUber_CurrentFocus()
    local iMap = math.floor(h * 0.34)
    if not tFocus then
      draw.SimpleText(NoahUber_L("active_empty"), NoahUber_Font(18, "Bold"), w * 0.5, h * 0.4, C("muted"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
      return
    end

    local tPins, tLinks = {}, {}
    local vPlayer = IsValid(LocalPlayer()) and LocalPlayer():GetPos() or nil
    for i = 1, #tActive do
      local tOrder = tActive[i]
      if tOrder.state ~= 2 then
        tPins[#tPins + 1] = { pos = tOrder.restPos, color = C("green") }
        if vPlayer then tLinks[#tLinks + 1] = { vPlayer, tOrder.restPos } end
      else
        tPins[#tPins + 1] = { pos = tOrder.custPos, color = C("ink") }
        if vPlayer then tLinks[#tLinks + 1] = { vPlayer, tOrder.custPos } end
      end
    end
    NoahUber_DrawMap(0, 0, w, iMap + 24, tPins, tLinks, vPlayer)
    draw.RoundedBox(22, 0, iMap, w, h, C("sheet"))

    local bDrop = NoahUber.State.FocusMode == 2 or tFocus.state == 2
    draw.SimpleText(NoahUber_L("trip_progress", 1, math.max(1, #tActive)), NoahUber_Font(13, "Bold"), NoahUber_RX(18), iMap + NoahUber_RY(16), C("green"))
    draw.SimpleText(NoahUber_L(bDrop and "step_dropoff" or "step_pickup"), NoahUber_Font(22, "Bold"), NoahUber_RX(18), iMap + NoahUber_RY(36), C("ink"))

    local sTitle = bDrop and (tFocus.customer or "") or (tFocus.restaurant or "")
    local sSub = bDrop and (tFocus.custAddress or "") or (tFocus.restAddress or "")
    draw.SimpleText(NoahUber_FitText(sTitle, NoahUber_Font(18, "Bold"), w - 36), NoahUber_Font(18, "Bold"), NoahUber_RX(18), iMap + NoahUber_RY(72), C("ink"))
    draw.SimpleText(NoahUber_FitText(sSub, NoahUber_Font(14, "Medium"), w - 36), NoahUber_Font(14, "Medium"), NoahUber_RX(18), iMap + NoahUber_RY(96), C("muted"))
    draw.SimpleText(NoahUber_FormatKm(tFocus.distance) .. "   ·   " .. NoahUber_FormatMoney(tFocus.payout), NoahUber_Font(15, "Bold"), NoahUber_RX(18), iMap + NoahUber_RY(122), C("ink"))
    draw.SimpleText(NoahUber_L("deliver_between", NoahUber_FormatClock(tFocus.windowStart), NoahUber_FormatClock(tFocus.windowEnd)), NoahUber_Font(13, "Medium"), NoahUber_RX(18), iMap + NoahUber_RY(146), C("muted"))
    draw.SimpleText(NoahUber_ItemLine(tFocus.items), NoahUber_Font(14, "Medium"), NoahUber_RX(18), iMap + NoahUber_RY(170), C("ink"))

    local iRow = iMap + NoahUber_RY(204)
    for i = 1, #tActive do
      local tOrder = tActive[i]
      local bThis = tOrder.id == tFocus.id
      local sState = (tOrder.state == 2) and NoahUber_L("to_drop") or NoahUber_L("to_pickup")
      draw.RoundedBox(10, NoahUber_RX(16), iRow, w - NoahUber_RX(32), NoahUber_RY(36), bThis and Color(6, 193, 103, 28) or C("soft"))
      draw.SimpleText(NoahUber_FitText((tOrder.customer or "") .. " · " .. sState, NoahUber_Font(13, "Bold"), w - NoahUber_RX(120)), NoahUber_Font(13, "Bold"), NoahUber_RX(28), iRow + NoahUber_RY(18), C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText(NoahUber_FormatMoney(tOrder.payout), NoahUber_Font(13, "Bold"), w - NoahUber_RX(28), iRow + NoahUber_RY(18), C("green"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
      iRow = iRow + NoahUber_RY(44)
    end
  end
end

function NoahUber_BuildEarnings(pContent)
  function pContent:Paint(w, h)
    draw.RoundedBox(0, 0, 0, w, h, C("sheet"))
  end

  local vHead = vgui.Create("DPanel", pContent)
  vHead:Dock(TOP)
  vHead:SetTall(NoahUber_RY(168))
  function vHead:Paint(w, h)
    draw.SimpleText(NoahUber_L("nav_earnings"), NoahUber_Font(14, "Bold"), NoahUber_RX(18), NoahUber_RY(28), C("green"))
    draw.SimpleText(NoahUber_L("total_salary"), NoahUber_Font(14, "Medium"), NoahUber_RX(18), NoahUber_RY(50), C("muted"))
    draw.SimpleText(NoahUber_FormatMoney(NoahUber.State.Total or 0), NoahUber_Font(36, "Bold"), NoahUber_RX(18), NoahUber_RY(68), C("ink"))
    draw.SimpleText(NoahUber_L("today_salary") .. "  " .. NoahUber_FormatMoney(NoahUber.State.Today or 0), NoahUber_Font(14, "Bold"), NoahUber_RX(18), NoahUber_RY(118), C("ink"))
    draw.SimpleText(NoahUber_L("today_count", NoahUber.State.TodayCount or 0), NoahUber_Font(14, "Medium"), NoahUber_RX(18), NoahUber_RY(140), C("muted"))
  end

  local vScroll = vgui.Create("DScrollPanel", pContent)
  vScroll:Dock(FILL)
  local vBar = vScroll:GetVBar()
  vBar:SetWide(6)
  function vBar:Paint() end
  if IsValid(vBar.btnUp) then function vBar.btnUp:Paint() end end
  if IsValid(vBar.btnDown) then function vBar.btnDown:Paint() end end
  if IsValid(vBar.btnGrip) then
    function vBar.btnGrip:Paint(w, h)
      draw.RoundedBox(4, 0, 0, w, h, C("green"))
    end
  end

  local tRows = NoahUber.State.History or {}
  if #tRows == 0 then
    local vEmpty = vgui.Create("DPanel", vScroll)
    vEmpty:Dock(TOP)
    vEmpty:SetTall(NoahUber_RY(80))
    function vEmpty:Paint(w, h)
      draw.SimpleText(NoahUber_L("no_history"), NoahUber_Font(15, "Medium"), w * 0.5, h * 0.5, C("muted"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return
  end

  for i = 1, #tRows do
    local tRow = tRows[i]
    local vRow = NoahUber_BlankButton(vScroll)
    vRow:Dock(TOP)
    vRow:SetTall(NoahUber_RY(68))
    vRow:DockMargin(NoahUber_RX(16), NoahUber_RY(6), NoahUber_RX(16), 0)
    function vRow:Paint(w, h)
      draw.RoundedBox(12, 0, 0, w, h, C("soft"))
      draw.SimpleText(NoahUber_FitText(tRow.restaurant or "", NoahUber_Font(15, "Bold"), w - 130), NoahUber_Font(15, "Bold"), 14, 16, C("ink"))
      draw.SimpleText(NoahUber_FormatDate(tRow.delivered) .. "  " .. NoahUber_FormatClock(tRow.delivered), NoahUber_Font(12, "Medium"), 14, 40, C("muted"))
      draw.SimpleText(NoahUber_FormatMoney((tRow.payout or 0) + (tRow.tip or 0)), NoahUber_Font(15, "Bold"), w - 14, h * 0.5, C("green"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    function vRow:DoClick()
      NoahUber.State.Receipt = tRow
      NoahUber_SetScreen("receipt")
    end
  end
end

function NoahUber_BuildReceipt(pContent)
  local vBack = NoahUber_BlankButton(pContent)
  vBack:Dock(TOP)
  vBack:SetTall(NoahUber_RY(42))
  function vBack:Paint(w, h)
    draw.SimpleText("<  " .. NoahUber_L("back"), NoahUber_Font(15, "Bold"), 16, h * 0.5, C("green"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end
  function vBack:DoClick()
    NoahUber_SetScreen("earnings")
  end

  function pContent:Paint(w, h)
    local tRow = NoahUber.State.Receipt
    draw.RoundedBox(0, 0, 0, w, h, Color(244, 246, 244))
    if not tRow then return end

    local iPad = NoahUber_RX(14)
    local iTip = math.floor(tonumber(tRow.tip) or 0)
    local iBase = math.floor(tonumber(tRow.payout) or 0)
    local iSum = iBase + iTip
    local iPayH = iTip > 0 and NoahUber_RY(108) or NoahUber_RY(78)
    local iPayY = h - iPayH - NoahUber_RY(12)
    local iY = NoahUber_RY(46)

    draw.SimpleText(NoahUber_L("receipt_title"), NoahUber_Font(22, "Bold"), iPad, iY, C("ink"))
    local sNum = NoahUber_L("invoice_id", tRow.id)
    surface.SetFont(NoahUber_Font(12, "Bold"))
    local iNumW = surface.GetTextSize(sNum)
    draw.RoundedBox(8, iPad, iY + NoahUber_RY(28), iNumW + NoahUber_RX(16), NoahUber_RY(22), Color(6, 193, 103, 30))
    draw.SimpleText(sNum, NoahUber_Font(12, "Bold"), iPad + NoahUber_RX(8), iY + NoahUber_RY(39), C("green"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local sWhen = tRow.onTime and NoahUber_L("on_time") or NoahUber_L("status_late")
    surface.SetFont(NoahUber_Font(12, "Bold"))
    local iWhenW = surface.GetTextSize(sWhen)
    local iWhenX = w - iPad - iWhenW - NoahUber_RX(16)
    local colWhen = tRow.onTime and C("green") or C("danger")
    draw.RoundedBox(8, iWhenX, iY + NoahUber_RY(28), iWhenW + NoahUber_RX(16), NoahUber_RY(22), Color(colWhen.r, colWhen.g, colWhen.b, 28))
    draw.SimpleText(sWhen, NoahUber_Font(12, "Bold"), iWhenX + NoahUber_RX(8), iY + NoahUber_RY(39), colWhen, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    iY = iY + NoahUber_RY(60)
    draw.RoundedBox(14, iPad, iY, w - iPad * 2, NoahUber_RY(72), color_white)
    draw.SimpleText(NoahUber_L("created_at", NoahUber_FormatDate(tRow.created), NoahUber_FormatClock(tRow.created)), NoahUber_Font(13, "Medium"), iPad + 12, iY + NoahUber_RY(14), C("ink"))
    draw.SimpleText(NoahUber_L("expected_at", NoahUber_FormatClock(tRow.windowStart), NoahUber_FormatClock(tRow.windowEnd)), NoahUber_Font(13, "Medium"), iPad + 12, iY + NoahUber_RY(34), C("muted"))
    draw.SimpleText(NoahUber_L("delivered_on", NoahUber_FormatDate(tRow.delivered), NoahUber_FormatClock(tRow.delivered)), NoahUber_Font(13, "Medium"), iPad + 12, iY + NoahUber_RY(52), C("ink"))

    iY = iY + NoahUber_RY(82)
    draw.RoundedBox(14, iPad, iY, w - iPad * 2, NoahUber_RY(96), color_white)
    NoahUber_DrawCircle(iPad + 20, iY + NoahUber_RY(28), 5, C("green"), 12)
    NoahUber_DrawCircle(iPad + 20, iY + NoahUber_RY(70), 5, C("ink"), 12)
    surface.SetDrawColor(220, 220, 220, 255)
    surface.DrawRect(iPad + 19, iY + NoahUber_RY(36), 2, NoahUber_RY(28))
    draw.SimpleText(NoahUber_FitText(tRow.restaurant or "", NoahUber_Font(15, "Bold"), w - iPad * 2 - 48), NoahUber_Font(15, "Bold"), iPad + 36, iY + NoahUber_RY(18), C("ink"))
    draw.SimpleText(NoahUber_L("restaurant"), NoahUber_Font(11, "Medium"), iPad + 36, iY + NoahUber_RY(36), C("muted"))
    local sWho = (tRow.customer or "") .. "   " .. (tRow.address or "")
    draw.SimpleText(NoahUber_FitText(sWho, NoahUber_Font(15, "Bold"), w - iPad * 2 - 48), NoahUber_Font(15, "Bold"), iPad + 36, iY + NoahUber_RY(58), C("ink"))
    draw.SimpleText(NoahUber_L("customer"), NoahUber_Font(11, "Medium"), iPad + 36, iY + NoahUber_RY(76), C("muted"))

    iY = iY + NoahUber_RY(106)
    if iY + NoahUber_RY(58) < iPayY - 8 then
      draw.RoundedBox(14, iPad, iY, w - iPad * 2, NoahUber_RY(54), color_white)
      draw.SimpleText(NoahUber_L("items"), NoahUber_Font(11, "Bold"), iPad + 12, iY + NoahUber_RY(10), C("muted"))
      draw.SimpleText(NoahUber_FormatKm(tRow.distance), NoahUber_Font(12, "Bold"), w - iPad - 12, iY + NoahUber_RY(10), C("green"), TEXT_ALIGN_RIGHT)
      draw.SimpleText(NoahUber_FitText(NoahUber_ItemLine(tRow.items), NoahUber_Font(13, "Medium"), w - iPad * 2 - 24), NoahUber_Font(13, "Medium"), iPad + 12, iY + NoahUber_RY(30), C("ink"))
    end

    draw.RoundedBox(16, iPad, iPayY, w - iPad * 2, iPayH, color_white)
    local iLine = iPayY + NoahUber_RY(16)
    draw.SimpleText(NoahUber_L("course_pay"), NoahUber_Font(13, "Medium"), iPad + 14, iLine, C("muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(NoahUber_FormatMoney(iBase), NoahUber_Font(14, "Bold"), w - iPad - 14, iLine, C("ink"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    if iTip > 0 then
      iLine = iLine + NoahUber_RY(26)
      draw.SimpleText(NoahUber_L("tip_label"), NoahUber_Font(13, "Medium"), iPad + 14, iLine, C("muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText(NoahUber_FormatMoney(iTip), NoahUber_Font(14, "Bold"), w - iPad - 14, iLine, C("green"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    surface.SetDrawColor(230, 230, 230, 255)
    surface.DrawRect(iPad + 14, iPayY + iPayH - NoahUber_RY(40), w - iPad * 2 - 28, 1)
    draw.SimpleText(NoahUber_L("receipt_total"), NoahUber_Font(13, "Bold"), iPad + 14, iPayY + iPayH - NoahUber_RY(22), C("ink"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(NoahUber_FormatMoney(iSum), NoahUber_Font(20, "Bold"), w - iPad - 14, iPayY + iPayH - NoahUber_RY(22), C("green"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
  end
end
