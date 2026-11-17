NoahUber = NoahUber or {}

util.AddNetworkString("NoahUber:Open")
util.AddNetworkString("NoahUber:State")
util.AddNetworkString("NoahUber:Offer")
util.AddNetworkString("NoahUber:Active")
util.AddNetworkString("NoahUber:History")
util.AddNetworkString("NoahUber:Points")
util.AddNetworkString("NoahUber:SetOnline")
util.AddNetworkString("NoahUber:RespondOffer")
util.AddNetworkString("NoahUber:Pickup")
util.AddNetworkString("NoahUber:Deliver")
util.AddNetworkString("NoahUber:RequestState")
util.AddNetworkString("NoahUber:RequestHistory")
util.AddNetworkString("NoahUber:SpawnVehicle")
util.AddNetworkString("NoahUber:Tip")

-- Le client n'envoie jamais d'argent, de position ou de gain.
-- Pickup / Deliver n'envoient qu'un identifiant, revérifié ici.

function NoahUber_WriteOrder(tOrder, bActive)
  net.WriteUInt(math.min(math.floor(tOrder.id or 0), 4294967295), 32)
  net.WriteUInt(math.Clamp(math.floor(tOrder.payout or 0), 0, 75000), 32)
  net.WriteUInt(math.min(math.floor(tOrder.distance or 0), 16777215), 24)
  net.WriteUInt(math.min(math.floor(tOrder.eta or 0), 65535), 16)
  net.WriteString(NoahUber_Sanitize(tOrder.restaurantName, 48))
  net.WriteString(NoahUber_Sanitize(tOrder.restaurantAddress, 80))
  net.WriteString(NoahUber_Sanitize(tOrder.customerName, 32))
  net.WriteString(NoahUber_Sanitize(tOrder.customerAddress, 80))
  net.WriteVector(tOrder.restaurantPos or vector_origin)
  net.WriteVector(tOrder.customerPos or vector_origin)
  local tItems = tOrder.items or {}
  local iCount = math.min(#tItems, 6)
  net.WriteUInt(iCount, 3)
  for i = 1, iCount do
    net.WriteString(tItems[i])
  end
  net.WriteUInt(math.min(math.floor(tOrder.windowStart or 0), 4294967295), 32)
  net.WriteUInt(math.min(math.floor(tOrder.windowEnd or 0), 4294967295), 32)
  if bActive then
    net.WriteUInt(tOrder.state == "picked" and 2 or 1, 2)
  end
end

function NoahUber_SendState(pPlayer)
  if not IsValid(pPlayer) then return end
  local sId = NoahUber_ValidSteam(pPlayer)
  local iTotal, iToday, iCount, iWeek = NoahUber_QueryEarnings(sId)
  net.Start("NoahUber:State")
  net.WriteBool(pPlayer.NoahUber_Online == true)
  net.WriteUInt(math.min(math.floor(pPlayer.NoahUber_Shift or 0), 4294967295), 32)
  net.WriteUInt(math.min(iToday, 4294967295), 32)
  net.WriteUInt(math.min(iTotal, 4294967295), 32)
  net.WriteUInt(math.min(iCount, 65535), 16)
  net.WriteUInt(math.min(iWeek or 0, 4294967295), 32)
  net.Send(pPlayer)
end

function NoahUber_SendOffer(pPlayer)
  if not IsValid(pPlayer) then return end
  local sId = NoahUber_ValidSteam(pPlayer)
  local tOffer = sId and NoahUber.OfferOf[sId] or nil
  local tOrders = {}
  if tOffer then
    for i = 1, #(tOffer.ids or {}) do
      local tOrder = NoahUber.Orders[tOffer.ids[i]]
      if tOrder and tOrder.state == "offered" and tOrder.owner == sId then
        tOrders[#tOrders + 1] = tOrder
      end
    end
  end

  net.Start("NoahUber:Offer")
  if #tOrders == 0 then
    net.WriteBool(false)
  else
    net.WriteBool(true)
    net.WriteUInt(#tOrders, 3)
    for i = 1, #tOrders do
      NoahUber_WriteOrder(tOrders[i], false)
    end
    local iLeft = math.max(0, math.ceil((tOffer.expire or CurTime()) - CurTime()))
    net.WriteUInt(math.min(iLeft, 255), 8)
  end
  net.Send(pPlayer)
end

function NoahUber_SyncActive(pPlayer)
  if not IsValid(pPlayer) then return end
  local tOrders = NoahUber_OrdersOf(pPlayer, false)
  local tFocus, sMode = NoahUber_FocusOrder(pPlayer)
  local tPath = {}
  if tFocus then
    local vTarget = tFocus.restaurantPos
    if sMode == "dropoff" then
      vTarget = IsValid(tFocus.npc) and tFocus.npc:GetPos() or tFocus.customerPos
    end
    tPath = NoahUber_SafePath(NoahUber_ActorPos(pPlayer), vTarget)
  end

  net.Start("NoahUber:Active")
  net.WriteUInt(math.min(#tOrders, 7), 3)
  for i = 1, math.min(#tOrders, 7) do
    NoahUber_WriteOrder(tOrders[i], true)
  end
  local iPath = math.min(#tPath, 28)
  net.WriteUInt(iPath, 5)
  for i = 1, iPath do
    net.WriteVector(tPath[i])
  end
  net.WriteUInt(tFocus and math.min(tFocus.id, 4294967295) or 0, 32)
  net.WriteUInt(sMode == "dropoff" and 2 or 1, 2)
  net.Send(pPlayer)
end

function NoahUber_SendHistory(pPlayer)
  if not IsValid(pPlayer) then return end
  local sId = NoahUber_ValidSteam(pPlayer)
  local iTotal, iToday, iCount = NoahUber_QueryEarnings(sId)
  local tRows = NoahUber_QueryHistory(sId)

  net.Start("NoahUber:History")
  net.WriteUInt(math.min(iTotal, 4294967295), 32)
  net.WriteUInt(math.min(iToday, 4294967295), 32)
  net.WriteUInt(math.min(iCount, 65535), 16)
  net.WriteUInt(math.min(#tRows, 25), 8)
  for i = 1, math.min(#tRows, 25) do
    local tRow = tRows[i]
    net.WriteUInt(math.min(tRow.id, 4294967295), 32)
    net.WriteUInt(math.min(tRow.payout, 75000), 32)
    net.WriteUInt(math.min(tRow.tip or 0, 25000), 32)
    net.WriteUInt(math.min(tRow.created, 4294967295), 32)
    net.WriteUInt(math.min(tRow.delivered, 4294967295), 32)
    net.WriteUInt(math.min(tRow.distance, 16777215), 24)
    net.WriteString(tRow.restaurant or "")
    net.WriteString(tRow.customer or "")
    net.WriteString(tRow.address or "")
    net.WriteUInt(math.min(tRow.windowStart, 4294967295), 32)
    net.WriteUInt(math.min(tRow.windowEnd, 4294967295), 32)
    net.WriteBool(tRow.onTime == true)
    local iItems = math.min(#(tRow.items or {}), 6)
    net.WriteUInt(iItems, 3)
    for j = 1, iItems do
      net.WriteString(tRow.items[j])
    end
  end
  net.Send(pPlayer)
end

function NoahUber_SendPoints(pPlayer)
  if not IsValid(pPlayer) or not NoahUber_IsAdmin(pPlayer) then return end
  local iCount = math.min(#NoahUber.Points, 80)
  net.Start("NoahUber:Points")
  net.WriteUInt(iCount, 8)
  for i = 1, iCount do
    local tPoint = NoahUber.Points[i]
    net.WriteUInt(math.min(tPoint.id, 65535), 16)
    net.WriteUInt(tPoint.kind == "customer" and 2 or 1, 2)
    net.WriteString(tPoint.name or "")
    net.WriteString(tPoint.address or "")
    net.WriteVector(tPoint.pos)
  end
  net.Send(pPlayer)
end

function NoahUber_BroadcastPoints()
  local tPlayers = player.GetAll()
  for i = 1, #tPlayers do
    if NoahUber_IsAdmin(tPlayers[i]) then
      NoahUber_SendPoints(tPlayers[i])
    end
  end
end

net.Receive("NoahUber:SetOnline", function(_, pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "online", 0.6) then return end
  local bOnline = net.ReadBool()
  NoahUber_SetOnline(pPlayer, bOnline)
  NoahUber_SendState(pPlayer)
end)

net.Receive("NoahUber:RespondOffer", function(_, pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "offer", 0.4) then return end
  local bAccept = net.ReadBool()
  NoahUber_RespondOffer(pPlayer, bAccept)
  NoahUber_SendState(pPlayer)
end)

net.Receive("NoahUber:Pickup", function(_, pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "pickup", 0.45) then return end
  local iId = net.ReadUInt(32)
  NoahUber_TryPickup(pPlayer, iId)
end)

net.Receive("NoahUber:Deliver", function(_, pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "deliver", 0.45) then return end
  local iId = net.ReadUInt(32)
  NoahUber_TryDeliver(pPlayer, iId)
end)

net.Receive("NoahUber:RequestState", function(_, pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "state", 0.4) then return end
  NoahUber_SendState(pPlayer)
  NoahUber_SendOffer(pPlayer)
  NoahUber_SyncActive(pPlayer)
end)

net.Receive("NoahUber:SpawnVehicle", function(_, pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "spawnveh", 2) then return end
  if not pPlayer.NoahUber_Online then
    NoahUber_Notify(pPlayer, 1, "need_online")
    return
  end
  NoahUber_SpawnDeliveryVehicle(pPlayer)
end)

net.Receive("NoahUber:RequestHistory", function(_, pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "history", 1.5) then return end
  if NoahUber.Config.RequireJob and not NoahUber_IsCourier(pPlayer) and not NoahUber_IsAdmin(pPlayer) then return end
  NoahUber_SendHistory(pPlayer)
end)
