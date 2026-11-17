NoahUber = NoahUber or {}
NoahUber.Customers = NoahUber.Customers or {}

local tModels = {
  "models/humans/group01/male_01.mdl",
  "models/humans/group01/male_02.mdl",
  "models/humans/group01/male_04.mdl",
  "models/humans/group01/male_07.mdl",
  "models/humans/group01/female_01.mdl",
  "models/humans/group01/female_02.mdl",
  "models/humans/group01/female_04.mdl",
}

local tIdles = { "idle_subtle", "idle_all_01", "LineIdle01", "idle_unarmed", "idle01" }

local function NoahUber_Ground(vPos)
  local tTrace = util.TraceLine({
    start = vPos + Vector(0, 0, 72),
    endpos = vPos - Vector(0, 0, 240),
    mask = MASK_SOLID_BRUSHONLY,
  })
  if tTrace.Hit then return tTrace.HitPos + Vector(0, 0, 1) end
  return vPos
end

local function NoahUber_Idle(eNpc)
  if not IsValid(eNpc) then return end
  for i = 1, #tIdles do
    local iSeq = eNpc:LookupSequence(tIdles[i])
    if iSeq and iSeq >= 0 then
      eNpc:ResetSequence(iSeq)
      eNpc:SetCycle(0)
      eNpc:SetPlaybackRate(1)
      return
    end
  end
end

local function NoahUber_Stand(eNpc, flYaw)
  if not IsValid(eNpc) then return end
  eNpc:SetAngles(Angle(0, flYaw or 0, 0))
  eNpc:SetLocalVelocity(vector_origin)
  eNpc:SetMoveType(MOVETYPE_NONE)
end

function NoahUber_RemoveCustomer(tOrder)
  if not tOrder then return end
  if IsValid(tOrder.npc) then
    tOrder.npc:Remove()
  end
  tOrder.npc = nil
end

function NoahUber_SpawnCustomer(tOrder)
  if not tOrder or not isvector(tOrder.customerPos) then return end
  NoahUber_RemoveCustomer(tOrder)

  local flYaw = (tonumber(tOrder.customerYaw) or math.random(0, 359)) + 180
  local vPos = NoahUber_Ground(tOrder.customerPos)
  local eNpc = ents.Create("prop_dynamic")
  if not IsValid(eNpc) then return end

  eNpc:SetModel(tModels[math.random(#tModels)])
  eNpc:SetKeyValue("DefaultAnim", "idle_subtle")
  eNpc:SetKeyValue("solid", "2")
  eNpc:SetPos(vPos)
  eNpc:SetAngles(Angle(0, flYaw, 0))
  eNpc:Spawn()
  eNpc:Activate()

  eNpc.NoahUber = true
  eNpc.NoahUberOrder = tOrder.id
  eNpc.NoahUberYaw = flYaw
  eNpc:SetNWBool("NoahUber_Customer", true)
  eNpc:SetNWString("NoahUber_Name", NoahUber_Sanitize(tOrder.customerName, 32))

  if eNpc.SkinCount and eNpc:SkinCount() > 1 then
    eNpc:SetSkin(math.random(0, eNpc:SkinCount() - 1))
  end

  NoahUber_Idle(eNpc)
  eNpc:SetSolid(SOLID_BBOX)
  eNpc:SetCollisionBounds(Vector(-14, -14, 0), Vector(14, 14, 72))
  eNpc:SetCollisionGroup(COLLISION_GROUP_PLAYER)
  NoahUber_Stand(eNpc, flYaw)

  tOrder.npc = eNpc
  NoahUber.Customers[#NoahUber.Customers + 1] = eNpc

  timer.Simple(0.15, function()
    if not IsValid(eNpc) then return end
    NoahUber_Idle(eNpc)
    NoahUber_Stand(eNpc, flYaw)
  end)
end

function NoahUber_MaintainCustomers()
  for i = #NoahUber.Customers, 1, -1 do
    local eNpc = NoahUber.Customers[i]
    if not IsValid(eNpc) then
      table.remove(NoahUber.Customers, i)
    else
      local aAng = eNpc:GetAngles()
      if math.abs(aAng.p) > 1 or math.abs(aAng.r) > 1 then
        NoahUber_Stand(eNpc, eNpc.NoahUberYaw or aAng.y)
      elseif eNpc:GetMoveType() ~= MOVETYPE_NONE then
        eNpc:SetMoveType(MOVETYPE_NONE)
      end
    end
  end
end

hook.Add("EntityTakeDamage", "NoahUber:ProtectCustomer", function(eEnt)
  if not IsValid(eEnt) then return end
  if eEnt.NoahUber or eEnt:GetNWBool("NoahUber_Customer") then
    return true
  end
end)

hook.Add("PlayerUse", "NoahUber:BlockCustomerUse", function(_, eEnt)
  if IsValid(eEnt) and (eEnt.NoahUber or eEnt:GetNWBool("NoahUber_Customer")) then
    return false
  end
end)
