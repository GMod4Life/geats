AddCSLuaFile()

SWEP.PrintName = "Sac de livraison"
SWEP.Author = "Noah Uber"
SWEP.Category = "Noah Uber"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.UseHands = true
SWEP.ViewModel = Model("models/weapons/bags/thief_bag_open.mdl")
SWEP.WorldModel = "models/weapons/bags/thief_bag.mdl"
SWEP.ViewModelFOV = 62
SWEP.Slot = 1
SWEP.SlotPos = 5

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
  self:SetHoldType("normal")
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:ShouldDropOnDie()
  return false
end

function SWEP:DrawWorldModel()
  local pOwner = self:GetOwner()
  if not IsValid(pOwner) then
    self:DrawModel()
    return
  end

  local iBone = pOwner:LookupBone("ValveBiped.Bip01_L_Hand")
  if not iBone then
    self:DrawModel()
    return
  end

  local vPos, aAng = pOwner:GetBonePosition(iBone)
  if not vPos or not aAng then
    self:DrawModel()
    return
  end

  vPos = vPos + aAng:Forward() * 19 + aAng:Right() * -5 + aAng:Up() * -3
  aAng:RotateAroundAxis(aAng:Right(), 90)
  aAng:RotateAroundAxis(aAng:Up(), 21)
  aAng:RotateAroundAxis(aAng:Forward(), 26)
  self:SetRenderOrigin(vPos)
  self:SetRenderAngles(aAng)
  self:DrawModel()
  self:SetRenderOrigin(nil)
  self:SetRenderAngles(nil)
end
