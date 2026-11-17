local function NoahUber_ReadOrder(bActive)
  local tOrder = {
    id = net.ReadUInt(32),
    payout = net.ReadUInt(32),
    distance = net.ReadUInt(24),
    eta = net.ReadUInt(16),
    restaurant = net.ReadString(),
    restAddress = net.ReadString(),
    customer = net.ReadString(),
    custAddress = net.ReadString(),
    restPos = net.ReadVector(),
    custPos = net.ReadVector(),
    items = {},
  }
  local iItems = net.ReadUInt(3)
  for i = 1, iItems do
    tOrder.items[i] = net.ReadString()
  end
  tOrder.windowStart = net.ReadUInt(32)
  tOrder.windowEnd = net.ReadUInt(32)
  if bActive then
    tOrder.state = net.ReadUInt(2)
  end
  return tOrder
end

net.Receive("NoahUber:Open", function()
  if NoahUber_OpenPhone then NoahUber_OpenPhone(false) end
end)

net.Receive("NoahUber:State", function()
  NoahUber.State.Online = net.ReadBool()
  NoahUber.State.Shift = net.ReadUInt(32)
  NoahUber.State.Today = net.ReadUInt(32)
  NoahUber.State.Total = net.ReadUInt(32)
  NoahUber.State.TodayCount = net.ReadUInt(16)
  NoahUber.State.Week = net.ReadUInt(32)
end)

net.Receive("NoahUber:Offer", function()
  local bHas = net.ReadBool()
  if not bHas then
    NoahUber.State.Offer = nil
    NoahUber_StopRing()
    if IsValid(NoahUber.Phone) and NoahUber.Phone.Screen == "offer" and NoahUber_SetScreen then
      local sNext = #(NoahUber.State.Active or {}) > 0 and "trip" or "home"
      NoahUber_SetScreen(sNext)
    end
    return
  end

  local iCount = net.ReadUInt(3)
  local tOrders = {}
  for i = 1, iCount do
    tOrders[i] = NoahUber_ReadOrder(false)
  end
  local iLeft = net.ReadUInt(8)
  local iSerial = tOrders[1] and tOrders[1].id or 0
  local bSame = NoahUber.State.Offer and NoahUber.State.Offer.serial == iSerial
  NoahUber.State.Offer = {
    serial = iSerial,
    orders = tOrders,
    expires = CurTime() + iLeft,
  }
  if not bSame then
    NoahUber_StartRing(iSerial)
    if NoahUber.Config.AutoOpenOffer and NoahUber_CreatePhone and NoahUber_SetScreen then
      if not IsValid(NoahUber.Phone) then NoahUber_CreatePhone() end
      NoahUber_SetScreen("offer")
    end
  end
end)

net.Receive("NoahUber:Active", function()
  local iCount = net.ReadUInt(3)
  local tOrders = {}
  for i = 1, iCount do
    tOrders[i] = NoahUber_ReadOrder(true)
  end
  local iPath = net.ReadUInt(5)
  local tPath = {}
  for i = 1, iPath do
    tPath[i] = net.ReadVector()
  end
  NoahUber.State.Active = tOrders
  NoahUber.State.Path = tPath
  NoahUber.State.FocusId = net.ReadUInt(32)
  NoahUber.State.FocusMode = net.ReadUInt(2)
  if #tOrders == 0 and IsValid(NoahUber.Phone) and NoahUber.Phone.Screen == "trip" and NoahUber_SetScreen and not NoahUber.State.Offer then
    NoahUber_SetScreen("home")
  end
end)

net.Receive("NoahUber:History", function()
  NoahUber.State.Total = net.ReadUInt(32)
  NoahUber.State.Today = net.ReadUInt(32)
  NoahUber.State.TodayCount = net.ReadUInt(16)
  local iRows = net.ReadUInt(8)
  local tRows = {}
  for i = 1, iRows do
    local tRow = {
      id = net.ReadUInt(32),
      payout = net.ReadUInt(32),
      tip = net.ReadUInt(32),
      created = net.ReadUInt(32),
      delivered = net.ReadUInt(32),
      distance = net.ReadUInt(24),
      restaurant = net.ReadString(),
      customer = net.ReadString(),
      address = net.ReadString(),
      windowStart = net.ReadUInt(32),
      windowEnd = net.ReadUInt(32),
      onTime = net.ReadBool(),
      items = {},
    }
    local iItems = net.ReadUInt(3)
    for j = 1, iItems do
      tRow.items[j] = net.ReadString()
    end
    tRows[i] = tRow
  end
  NoahUber.State.History = tRows
  if IsValid(NoahUber.Phone) and NoahUber.Phone.Screen == "earnings" and NoahUber_RebuildScreen then
    NoahUber_RebuildScreen()
  end
end)

net.Receive("NoahUber:Tip", function()
  local iTip = net.ReadUInt(32)
  if iTip <= 0 or iTip > 25000 then return end
  if NoahUber_PlaySuccess then NoahUber_PlaySuccess() end
end)

net.Receive("NoahUber:Points", function()
  local iCount = net.ReadUInt(8)
  local tPoints = {}
  for i = 1, iCount do
    tPoints[i] = {
      id = net.ReadUInt(16),
      kind = net.ReadUInt(2) == 2 and "customer" or "restaurant",
      name = net.ReadString(),
      address = net.ReadString(),
      pos = net.ReadVector(),
    }
  end
  NoahUber.AdminPoints = tPoints
end)
