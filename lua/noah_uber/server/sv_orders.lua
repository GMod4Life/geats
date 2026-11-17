NoahUber = NoahUber or {}
NoahUber.Orders = NoahUber.Orders or {}
NoahUber.OfferOf = NoahUber.OfferOf or {}
NoahUber.NextOrderId = NoahUber.NextOrderId or 1

local function NoahUber_CopyPos(vPos)
  return Vector(vPos.x, vPos.y, vPos.z)
end

function NoahUber_RandomPerson(sExclude)
  local tNames = NoahUber.Constants["customers"] or { "Noah" }
  local sName = tNames[math.random(#tNames)]
  if sName == sExclude and #tNames > 1 then
    sName = tNames[math.random(#tNames)]
  end
  return sName
end

function NoahUber_PickItems()
  local tPool = NoahUber.Constants["foods"] or { "burger" }
  local tUsed, tItems = {}, {}
  local iWant = math.random(2, 4)
  local iGuard = 0
  while #tItems < iWant and iGuard < 12 do
    iGuard = iGuard + 1
    local sKey = tPool[math.random(#tPool)]
    if not tUsed[sKey] then
      tUsed[sKey] = true
      tItems[#tItems + 1] = sKey
    end
  end
  if #tItems == 0 then tItems[1] = tPool[1] end
  return tItems
end

function NoahUber_AddressOf(tPoint)
  if tPoint and tPoint.address and tPoint.address ~= "" then return tPoint.address end
  return NoahUber_L("address_fallback")
end

function NoahUber_MakeOrder(tRestaurant, tCustomer, sExcludeName)
  local flDist = tRestaurant.pos:Distance(tCustomer.pos)
  local iPay = NoahUber_ComputePay(flDist)
  local iEta = NoahUber_EtaSeconds(flDist)
  local iNow = os.time()
  local iId = NoahUber.NextOrderId
  NoahUber.NextOrderId = iId + 1

  return {
    id = iId,
    state = "draft",
    payout = iPay,
    distance = math.floor(flDist),
    eta = iEta,
    restaurantName = NoahUber_PointLabel(tRestaurant),
    restaurantAddress = NoahUber_AddressOf(tRestaurant),
    restaurantPos = NoahUber_CopyPos(tRestaurant.pos),
    customerName = NoahUber_RandomPerson(sExcludeName),
    customerAddress = NoahUber_AddressOf(tCustomer),
    customerPos = NoahUber_CopyPos(tCustomer.pos),
    customerYaw = tCustomer.yaw or 0,
    items = NoahUber_PickItems(),
    created = iNow,
    windowStart = iNow,
    windowEnd = iNow + iEta,
    owner = nil,
    paid = false,
    npc = nil,
  }
end

function NoahUber_OrdersOf(pPlayer, bIncludeOffer)
  local sId = NoahUber_ValidSteam(pPlayer)
  local tList = {}
  if not sId then return tList end
  for _, tOrder in pairs(NoahUber.Orders) do
    if tOrder.owner == sId then
      local bActive = tOrder.state == "accepted" or tOrder.state == "picked"
      local bOffer = bIncludeOffer and tOrder.state == "offered"
      if bActive or bOffer then
        tList[#tList + 1] = tOrder
      end
    end
  end
  table.sort(tList, function(a, b) return a.id < b.id end)
  return tList
end

function NoahUber_HasPickedOrder(pPlayer)
  local tList = NoahUber_OrdersOf(pPlayer, false)
  for i = 1, #tList do
    if tList[i].state == "picked" then return true end
  end
  return false
end

local sBagModel = "models/weapons/bags/thief_bag.mdl"

function NoahUber_PlaceWornBag(pPlayer, eBag)
  if not IsValid(pPlayer) or not IsValid(eBag) then return end
  local iBone = pPlayer:LookupBone("ValveBiped.Bip01_L_Hand")
  if not iBone then return end
  local vPos, aAng = pPlayer:GetBonePosition(iBone)
  if not vPos or not aAng then return end
  vPos = vPos + aAng:Forward() * 19 + aAng:Right() * -5 + aAng:Up() * -3
  aAng:RotateAroundAxis(aAng:Right(), 90)
  aAng:RotateAroundAxis(aAng:Up(), 21)
  aAng:RotateAroundAxis(aAng:Forward(), 26)
  eBag:SetPos(vPos)
  eBag:SetAngles(aAng)
end

function NoahUber_GiveBag(pPlayer)
  if not IsValid(pPlayer) then return end
  if pPlayer:HasWeapon("noah_uber_bag") then
    pPlayer:StripWeapon("noah_uber_bag")
  end
  if IsValid(pPlayer.NoahUber_Bag) then return end
  local eBag = ents.Create("prop_dynamic")
  if not IsValid(eBag) then return end
  eBag:SetModel(sBagModel)
  eBag:SetPos(pPlayer:GetPos())
  eBag:Spawn()
  eBag:Activate()
  eBag:SetNotSolid(true)
  eBag:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
  eBag.NoahUberWorn = true
  pPlayer.NoahUber_Bag = eBag
  NoahUber_PlaceWornBag(pPlayer, eBag)
end

function NoahUber_RemoveBag(pPlayer)
  if not IsValid(pPlayer) then return end
  if IsValid(pPlayer.NoahUber_Bag) then
    pPlayer.NoahUber_Bag:Remove()
  end
  pPlayer.NoahUber_Bag = nil
  if pPlayer:HasWeapon("noah_uber_bag") then
    pPlayer:StripWeapon("noah_uber_bag")
  end
end

function NoahUber_RemoveOrderBag(tOrder)
  if not tOrder then return end
  if IsValid(tOrder.bag) then
    local eBag = tOrder.bag
    tOrder.bag = nil
    local bShared = false
    for _, tOther in pairs(NoahUber.Orders or {}) do
      if tOther ~= tOrder and tOther.bag == eBag then
        bShared = true
        break
      end
    end
    if not bShared then
      eBag:Remove()
    end
  end
  tOrder.bag = nil
end

function NoahUber_SpawnOrderBag(tOrder)
  if not tOrder or not isvector(tOrder.restaurantPos) or IsValid(tOrder.bag) then return end
  for _, tOther in pairs(NoahUber.Orders or {}) do
    if tOther ~= tOrder and IsValid(tOther.bag) and isvector(tOther.restaurantPos) and tOther.restaurantPos:DistToSqr(tOrder.restaurantPos) < (80 * 80) then
      tOrder.bag = tOther.bag
      return
    end
  end

  local vPos = tOrder.restaurantPos
  local tTrace = util.TraceLine({
    start = vPos + Vector(0, 0, 48),
    endpos = vPos - Vector(0, 0, 160),
    mask = MASK_SOLID_BRUSHONLY,
  })
  local vPut = tTrace.Hit and (tTrace.HitPos + Vector(0, 0, 6)) or (vPos + Vector(0, 0, 8))
  local eBag = ents.Create("prop_dynamic")
  if not IsValid(eBag) then return end
  eBag:SetModel(sBagModel)
  eBag:SetPos(vPut)
  eBag:SetAngles(Angle(0, math.random(0, 359), 0))
  eBag:Spawn()
  eBag:Activate()
  eBag:SetNotSolid(true)
  eBag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
  eBag.NoahUberPickup = true
  tOrder.bag = eBag
end

function NoahUber_CountActive(pPlayer)
  local tList = NoahUber_OrdersOf(pPlayer, false)
  return #tList
end

function NoahUber_OwnedOrder(pPlayer, iId, sState)
  local sId = NoahUber_ValidSteam(pPlayer)
  if not sId then return end
  iId = math.floor(tonumber(iId) or 0)
  local tOrder = NoahUber.Orders[iId]
  if not tOrder or tOrder.owner ~= sId then return end
  if sState and tOrder.state ~= sState then return end
  if tOrder.paid then return end
  return tOrder
end

function NoahUber_ClearOffer(sId, bDelete)
  local tOffer = NoahUber.OfferOf[sId]
  if not tOffer then return end
  if bDelete then
    for i = 1, #(tOffer.ids or {}) do
      local tOrder = NoahUber.Orders[tOffer.ids[i]]
      if tOrder and tOrder.state == "offered" then
        NoahUber.Orders[tOffer.ids[i]] = nil
      end
    end
  end
  NoahUber.OfferOf[sId] = nil
end

function NoahUber_CancelPlayerOrders(pPlayer)
  local sId = NoahUber_ValidSteam(pPlayer)
  if sId then NoahUber_ClearOffer(sId, true) end
  if not sId then return end
  local tDrop = {}
  for iId, tOrder in pairs(NoahUber.Orders) do
    if tOrder.owner == sId then
      tDrop[#tDrop + 1] = iId
    end
  end
  for i = 1, #tDrop do
    NoahUber_RemoveCustomer(NoahUber.Orders[tDrop[i]])
    NoahUber_RemoveOrderBag(NoahUber.Orders[tDrop[i]])
    NoahUber.Orders[tDrop[i]] = nil
  end
end

function NoahUber_CanReceive(pPlayer)
  if not IsValid(pPlayer) or not pPlayer:Alive() then return false end
  if not pPlayer.NoahUber_Online then return false end
  if not NoahUber_IsCourier(pPlayer) then return false end
  if pPlayer.isArrested and pPlayer:isArrested() then return false end
  local sId = NoahUber_ValidSteam(pPlayer)
  if not sId then return false end
  if NoahUber.OfferOf[sId] then return false end
  if NoahUber_CountActive(pPlayer) > 0 then return false end
  if (pPlayer.NoahUber_NextOffer or 0) > CurTime() then return false end
  return true
end

function NoahUber_FindCourier()
  local pBest
  local tPlayers = player.GetAll()
  for i = 1, #tPlayers do
    local pPlayer = tPlayers[i]
    if NoahUber_CanReceive(pPlayer) then
      if not IsValid(pBest) or (pPlayer.NoahUber_LastOffer or 0) < (pBest.NoahUber_LastOffer or 0) then
        pBest = pPlayer
      end
    end
  end
  return pBest
end

function NoahUber_WarnMissingPoints()
  if (NoahUber.NextPointWarn or 0) > CurTime() then return end
  local bBusy = false
  local tPlayers = player.GetAll()
  for i = 1, #tPlayers do
    if tPlayers[i].NoahUber_Online and NoahUber_IsCourier(tPlayers[i]) then
      bBusy = true
      break
    end
  end
  if not bBusy then return end
  NoahUber.NextPointWarn = CurTime() + 180
  for i = 1, #tPlayers do
    if NoahUber_IsAdmin(tPlayers[i]) or (tPlayers[i].NoahUber_Online and NoahUber_IsCourier(tPlayers[i])) then
      NoahUber_Notify(tPlayers[i], 1, "no_points")
    end
  end
end

function NoahUber_FocusOrder(pPlayer)
  local tOrders = NoahUber_OrdersOf(pPlayer, false)
  local vPos = NoahUber_ActorPos(pPlayer)
  local tBest, flBest
  for i = 1, #tOrders do
    local tOrder = tOrders[i]
    if tOrder.state == "accepted" then
      local flDist = vPos:Distance(tOrder.restaurantPos)
      if not tBest or flDist < flBest then
        tBest, flBest = tOrder, flDist
      end
    end
  end
  if tBest then return tBest, "pickup" end
  for i = 1, #tOrders do
    local tOrder = tOrders[i]
    if tOrder.state == "picked" then
      local vDest = IsValid(tOrder.npc) and tOrder.npc:GetPos() or tOrder.customerPos
      local flDist = vPos:Distance(vDest)
      if not tBest or flDist < flBest then
        tBest, flBest = tOrder, flDist
      end
    end
  end
  if tBest then return tBest, "dropoff" end
end

function NoahUber_ExpireOffers()
  local flNow = CurTime()
  for sId, tOffer in pairs(NoahUber.OfferOf) do
    if (tOffer.expire or 0) <= flNow then
      NoahUber_ClearOffer(sId, true)
      local pPlayer = NoahUber_PlayerBySid(sId)
      if IsValid(pPlayer) then
        pPlayer.NoahUber_NextOffer = flNow + (tonumber(NoahUber.Config.RefuseCooldown) or 18)
        NoahUber_Notify(pPlayer, 1, "expired")
        if NoahUber_SendOffer then NoahUber_SendOffer(pPlayer) end
      end
    end
  end
end

function NoahUber_Dispatch()
  if not NoahUber_HasDeliverySpots() then
    NoahUber_WarnMissingPoints()
    return
  end

  local pPlayer = NoahUber_FindCourier()
  if not IsValid(pPlayer) then return end
  local sId = NoahUber_ValidSteam(pPlayer)
  if not sId then return end

  local tRestaurant = NoahUber_RandomRestaurant()
  local tCustomer = tRestaurant and NoahUber_RandomCustomerPoint(tRestaurant.pos)
  if not tRestaurant or not tCustomer then
    if (NoahUber.NextRouteWarn or 0) <= CurTime() then
      NoahUber.NextRouteWarn = CurTime() + 180
      local tPlayers = player.GetAll()
      for i = 1, #tPlayers do
        if NoahUber_IsAdmin(tPlayers[i]) then
          NoahUber_Notify(tPlayers[i], 1, "points_too_close")
        end
      end
    end
    return
  end

  local tFirst = NoahUber_MakeOrder(tRestaurant, tCustomer)
  local tMade = { tFirst }
  local flChance = math.Clamp(tonumber(NoahUber.Config.DoubleOrderChance) or 0, 0, 1)
  if math.Rand(0, 1) <= flChance then
    local tSecondPoint = NoahUber_RandomCustomerPoint(tRestaurant.pos, tCustomer.id)
    if tSecondPoint then
      tMade[#tMade + 1] = NoahUber_MakeOrder(tRestaurant, tSecondPoint, tFirst.customerName)
    end
  end

  if #tMade > (NoahUber.Constants["hardMaxOrders"] or 2) then return end

  local tIds = {}
  local flExpire = CurTime() + (tonumber(NoahUber.Config.OfferDuration) or 30)
  for i = 1, #tMade do
    local tOrder = tMade[i]
    tOrder.state = "offered"
    tOrder.owner = sId
    tOrder.expireAt = flExpire
    NoahUber.Orders[tOrder.id] = tOrder
    tIds[#tIds + 1] = tOrder.id
  end

  NoahUber.OfferOf[sId] = { ids = tIds, expire = flExpire }
  pPlayer.NoahUber_LastOffer = CurTime()
  if NoahUber_SendOffer then NoahUber_SendOffer(pPlayer) end
end

function NoahUber_SetOnline(pPlayer, bOnline)
  if not IsValid(pPlayer) then return end
  if bOnline then
    if NoahUber.Config.RequireJob and not NoahUber_IsCourier(pPlayer) then
      NoahUber_Notify(pPlayer, 1, "need_job")
      return
    end
    if not pPlayer:Alive() then return end
    if pPlayer.isArrested and pPlayer:isArrested() then
      NoahUber_Notify(pPlayer, 1, "arrested")
      return
    end
    pPlayer.NoahUber_Online = true
    pPlayer.NoahUber_Shift = pPlayer.NoahUber_Shift or 0
    pPlayer.NoahUber_NextOffer = CurTime() + 4
    NoahUber_Notify(pPlayer, 0, "now_online")
    NoahUber_Log(pPlayer, "went online")
    local bSpawned, sErr = pcall(NoahUber_SpawnDeliveryVehicle, pPlayer)
    if not bSpawned then
      ErrorNoHalt("[NoahUber] Scooter : " .. tostring(sErr) .. "\n")
      NoahUber_Notify(pPlayer, 1, "vehicle_gone")
    end
  else
    if NoahUber_CountActive(pPlayer) > 0 then
      NoahUber_Notify(pPlayer, 1, "finish_first")
      return
    end
    local sId = NoahUber_ValidSteam(pPlayer)
    if sId then NoahUber_ClearOffer(sId, true) end
    pPlayer.NoahUber_Online = false
    pPlayer.NoahUber_Shift = 0
    NoahUber_RemoveDeliveryVehicle(pPlayer)
    NoahUber_RemoveBag(pPlayer)
    NoahUber_Notify(pPlayer, 0, "now_offline")
    NoahUber_Log(pPlayer, "went offline")
    if NoahUber_SendOffer then NoahUber_SendOffer(pPlayer) end
  end
end

function NoahUber_ForceOffline(pPlayer)
  if not IsValid(pPlayer) then return end
  NoahUber_CancelPlayerOrders(pPlayer)
  pPlayer.NoahUber_Online = false
  pPlayer.NoahUber_Shift = 0
  NoahUber_RemoveDeliveryVehicle(pPlayer)
  NoahUber_RemoveBag(pPlayer)
end

function NoahUber_RespondOffer(pPlayer, bAccept)
  local sId = NoahUber_ValidSteam(pPlayer)
  if not sId then return end
  local tOffer = NoahUber.OfferOf[sId]
  if not tOffer then
    NoahUber_Notify(pPlayer, 1, "unavailable")
    if NoahUber_SendOffer then NoahUber_SendOffer(pPlayer) end
    return
  end

  if not bAccept then
    NoahUber_ClearOffer(sId, true)
    pPlayer.NoahUber_NextOffer = CurTime() + (tonumber(NoahUber.Config.RefuseCooldown) or 18)
    NoahUber_Notify(pPlayer, 0, "refused")
    NoahUber_Log(pPlayer, "refused an offer")
    if NoahUber_SendOffer then NoahUber_SendOffer(pPlayer) end
    return
  end

  if not pPlayer:Alive() or not pPlayer.NoahUber_Online or not NoahUber_IsCourier(pPlayer) then
    NoahUber_Notify(pPlayer, 1, "need_job")
    return
  end

  local tAccepted = {}
  for i = 1, #(tOffer.ids or {}) do
    local tOrder = NoahUber.Orders[tOffer.ids[i]]
    if not tOrder or tOrder.state ~= "offered" or tOrder.owner ~= sId or (tOrder.expireAt or 0) < CurTime() then
      NoahUber_ClearOffer(sId, true)
      NoahUber_Notify(pPlayer, 1, "expired")
      if NoahUber_SendOffer then NoahUber_SendOffer(pPlayer) end
      return
    end
    tAccepted[#tAccepted + 1] = tOrder
  end

  if #tAccepted == 0 or #tAccepted > (NoahUber.Constants["hardMaxOrders"] or 2) then
    NoahUber_ClearOffer(sId, true)
    return
  end
  if NoahUber_CountActive(pPlayer) + #tAccepted > (NoahUber.Constants["hardMaxOrders"] or 2) then
    NoahUber_Notify(pPlayer, 1, "unavailable")
    return
  end

  NoahUber.OfferOf[sId] = nil
  local vPos = NoahUber_ActorPos(pPlayer)
  for i = 1, #tAccepted do
    local tOrder = tAccepted[i]
    tOrder.state = "accepted"
    tOrder.legStart = CurTime()
    tOrder.legFrom = vPos
    NoahUber_SpawnCustomer(tOrder)
    NoahUber_SpawnOrderBag(tOrder)
  end
  pPlayer.NoahUber_SpeedFlags = 0
  NoahUber_Notify(pPlayer, 0, "go_restaurant")
  NoahUber_Log(pPlayer, "accepted an offer")
  if NoahUber_SyncActive then NoahUber_SyncActive(pPlayer) end
  if NoahUber_SendOffer then NoahUber_SendOffer(pPlayer) end
end

function NoahUber_TryPickup(pPlayer, iOrderId)
  local tOrder = NoahUber_OwnedOrder(pPlayer, iOrderId, "accepted")
  if not tOrder then
    NoahUber_Notify(pPlayer, 1, "unavailable")
    return
  end
  if not NoahUber_MovementAllowed(pPlayer, tOrder) then return end
  if NoahUber_ActorPos(pPlayer):Distance(tOrder.restaurantPos) > (tonumber(NoahUber.Config.InteractDistance) or 380) then
    NoahUber_Notify(pPlayer, 1, "too_far")
    return
  end
  if not NoahUber_HasDeliveryVehicle(pPlayer) then
    NoahUber_Notify(pPlayer, 1, NoahUber_VehicleFailureKey())
    return
  end

  local vPos = NoahUber_ActorPos(pPlayer)
  local tOrders = NoahUber_OrdersOf(pPlayer, false)
  for i = 1, #tOrders do
    local tOther = tOrders[i]
    if tOther.state == "accepted" and tOther.restaurantPos:DistToSqr(tOrder.restaurantPos) < (80 * 80) then
      tOther.state = "picked"
      tOther.legStart = CurTime()
      tOther.legFrom = vPos
      NoahUber_RemoveOrderBag(tOther)
    end
  end

  NoahUber_Notify(pPlayer, 0, "picked_up")
  NoahUber_Log(pPlayer, "picked up an order")
  NoahUber_GiveBag(pPlayer)
  if NoahUber_SyncActive then NoahUber_SyncActive(pPlayer) end
end

function NoahUber_TryDeliver(pPlayer, iOrderId)
  local tOrder = NoahUber_OwnedOrder(pPlayer, iOrderId, "picked")
  if not tOrder or tOrder.paid then
    NoahUber_Notify(pPlayer, 1, "unavailable")
    return
  end
  if not NoahUber_MovementAllowed(pPlayer, tOrder) then return end

  local vDest = IsValid(tOrder.npc) and tOrder.npc:GetPos() or tOrder.customerPos
  if NoahUber_ActorPos(pPlayer):Distance(vDest) > (tonumber(NoahUber.Config.InteractDistance) or 380) then
    NoahUber_Notify(pPlayer, 1, "too_far")
    return
  end
  if not NoahUber_HasDeliveryVehicle(pPlayer) then
    NoahUber_Notify(pPlayer, 1, NoahUber_VehicleFailureKey())
    return
  end

  local iMin, iMax = NoahUber_GetPayBounds()
  local iPay = math.floor(tonumber(tOrder.payout) or 0)
  if not iPay or iPay ~= iPay then return end
  iPay = math.Clamp(iPay, iMin, iMax)

  local iTip = 0
  local tTips = NoahUber.Config.Tips
  local iTipMax = tonumber(NoahUber.Constants.hardMaxTip) or 25000
  if istable(tTips) and #tTips > 0 then
    iTip = math.floor(tonumber(tTips[math.random(#tTips)]) or 0)
    if iTip < 0 or iTip > iTipMax then iTip = 0 end
  end

  tOrder.paid = true
  tOrder.state = "delivered"
  tOrder.onTime = os.time() <= (tOrder.windowEnd or 0)
  tOrder.tip = iTip

  local iGain = iPay + iTip
  if pPlayer.addMoney then
    local bOk, sErr = pcall(pPlayer.addMoney, pPlayer, iGain)
    if not bOk then
      ErrorNoHalt("[NoahUber] addMoney : " .. tostring(sErr) .. "\n")
    end
  end

  pPlayer.NoahUber_Shift = math.floor((pPlayer.NoahUber_Shift or 0) + iGain)
  NoahUber_SaveInvoice(pPlayer, tOrder, iPay, iTip)
  NoahUber_RemoveCustomer(tOrder)
  NoahUber.Orders[tOrder.id] = nil

  NoahUber_Log(pPlayer, "delivered an order for " .. NoahUber_FormatMoney(iGain) .. " (tip " .. NoahUber_FormatMoney(iTip) .. ")")
  NoahUber_Notify(pPlayer, 0, "paid", NoahUber_FormatMoney(iGain))
  if iTip > 0 then
    NoahUber_Notify(pPlayer, 0, "tip_received", NoahUber_FormatMoney(iTip))
    net.Start("NoahUber:Tip")
    net.WriteUInt(iTip, 32)
    net.Send(pPlayer)
  end

  if not NoahUber_HasPickedOrder(pPlayer) then
    NoahUber_RemoveBag(pPlayer)
  end
  if NoahUber_CountActive(pPlayer) == 0 then
    pPlayer.NoahUber_NextOffer = CurTime() + (tonumber(NoahUber.Config.AfterDeliveryCooldown) or 10)
  end
  if NoahUber_SyncActive then NoahUber_SyncActive(pPlayer) end
  if NoahUber_SendState then NoahUber_SendState(pPlayer) end
end

function NoahUber_TryInteract(pPlayer)
  if not NoahUber_ConsumeNet(pPlayer, "interact", 0.45) then return end
  if not pPlayer.NoahUber_Online or not NoahUber_IsCourier(pPlayer) then return end

  local tTrace = pPlayer:GetEyeTrace()
  if tTrace and IsValid(tTrace.Entity) and not tTrace.Entity.NoahUber and not tTrace.Entity:GetNWBool("NoahUber_Customer") then
    if tTrace.HitPos:Distance(pPlayer:GetShootPos()) < 110 then
      return
    end
  end

  local tOrders = NoahUber_OrdersOf(pPlayer, false)
  local vPos = NoahUber_ActorPos(pPlayer)
  local tBest, flBest, sMode
  local flMax = tonumber(NoahUber.Config.InteractDistance) or 380
  for i = 1, #tOrders do
    local tOrder = tOrders[i]
    if tOrder.state == "picked" then
      local vDest = IsValid(tOrder.npc) and tOrder.npc:GetPos() or tOrder.customerPos
      local flDist = vPos:Distance(vDest)
      if flDist <= flMax and (not tBest or flDist < flBest) then
        tBest, flBest, sMode = tOrder, flDist, "deliver"
      end
    elseif tOrder.state == "accepted" then
      local flDist = vPos:Distance(tOrder.restaurantPos)
      if flDist <= flMax and (not tBest or flDist < flBest) then
        tBest, flBest, sMode = tOrder, flDist, "pickup"
      end
    end
  end
  if not tBest then return end
  if sMode == "deliver" then
    NoahUber_TryDeliver(pPlayer, tBest.id)
  else
    NoahUber_TryPickup(pPlayer, tBest.id)
  end
end
