TOOL.Category = "Roleplay"
TOOL.Name = "Uber Eats"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["name"] = "Pizza Shop"
TOOL.ClientConVar["address"] = "12 rue du Centre"
TOOL.ClientConVar["kind"] = "restaurant"

TOOL.Information = {
  { name = "left" },
  { name = "right" },
  { name = "reload" },
}

if CLIENT then
  language.Add("tool.noah_uber_points.name", "Uber Eats")
  language.Add("tool.noah_uber_points.desc", "Restaurants et clients des livraisons")
  language.Add("tool.noah_uber_points.left", "Ajouter un point")
  language.Add("tool.noah_uber_points.right", "Supprimer le point visé")
  language.Add("tool.noah_uber_points.reload", "Restaurant / client")
end

function TOOL:Allowed()
  if not NoahUber_IsAdmin then return false end
  return NoahUber_IsAdmin(self:GetOwner())
end

function TOOL:LeftClick(tr)
  if CLIENT then return true end
  local pPlayer = self:GetOwner()
  if not IsValid(pPlayer) or not NoahUber_IsAdmin(pPlayer) then return false end
  if not tr or not tr.Hit then return false end
  if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC()) then return false end
  if not NoahUber_ConsumeNet(pPlayer, "tooladd", 0.25) then return false end

  local sKind = string.lower(self:GetClientInfo("kind") or "")
  if sKind ~= "customer" then sKind = "restaurant" end
  local vPos = tr.HitPos + tr.HitNormal * 2
  local bOk, tResult = NoahUber_AddPoint(sKind, self:GetClientInfo("name"), self:GetClientInfo("address"), vPos, pPlayer:EyeAngles().y)
  if not bOk then
    NoahUber_Notify(pPlayer, 1, tResult or "invalid_point")
    return false
  end
  NoahUber_Notify(pPlayer, 0, "point_added", NoahUber_PointLabel(tResult))
  if NoahUber_BroadcastPoints then NoahUber_BroadcastPoints() end
  return true
end

function TOOL:RightClick(tr)
  if CLIENT then return true end
  local pPlayer = self:GetOwner()
  if not IsValid(pPlayer) or not NoahUber_IsAdmin(pPlayer) then return false end
  if not tr or not tr.Hit then return false end
  if not NoahUber_ConsumeNet(pPlayer, "tooldel", 0.25) then return false end
  if not NoahUber_RemoveNearestPoint(tr.HitPos) then
    NoahUber_Notify(pPlayer, 1, "invalid_point")
    return false
  end
  NoahUber_Notify(pPlayer, 0, "point_removed")
  if NoahUber_BroadcastPoints then NoahUber_BroadcastPoints() end
  return true
end

function TOOL:Reload()
  if CLIENT then
    local sCur = string.lower(self:GetClientInfo("kind") or "")
    local sNext = sCur == "customer" and "restaurant" or "customer"
    RunConsoleCommand("noah_uber_points_kind", sNext)
    if notification and notification.AddLegacy then
      notification.AddLegacy(sNext == "customer" and NoahUber_L("type_customer") or NoahUber_L("type_restaurant"), NOTIFY_GENERIC, 2)
    end
  end
  return true
end

if CLIENT then
  function TOOL.BuildCPanel(vPanel)
    vPanel:Help(NoahUber_L("tool_desc"))
    vPanel:TextEntry(NoahUber_L("point_name"), "noah_uber_points_name")
    vPanel:TextEntry(NoahUber_L("point_address"), "noah_uber_points_address")
    vPanel:Help(NoahUber_L("point_type"))

    local vCombo = vgui.Create("DComboBox")
    vCombo:SetTall(22)
    vCombo:AddChoice(NoahUber_L("type_restaurant"), "restaurant")
    vCombo:AddChoice(NoahUber_L("type_customer"), "customer")
    function vCombo:OnSelect(_, _, sData)
      if sData == "restaurant" or sData == "customer" then
        RunConsoleCommand("noah_uber_points_kind", sData)
      end
    end
    local sKind = GetConVar("noah_uber_points_kind") and GetConVar("noah_uber_points_kind"):GetString() or "restaurant"
    vCombo:SetValue(sKind == "customer" and NoahUber_L("type_customer") or NoahUber_L("type_restaurant"))
    vPanel:AddItem(vCombo)

    vPanel:Help(NoahUber_L("tool_left"))
    vPanel:Help(NoahUber_L("tool_right"))
    vPanel:Help(NoahUber_L("tool_reload"))
    vPanel:Help("Workshop véhicule : 2039701689")
    vPanel:Help("noah_uber_registervehicle")
  end
end
