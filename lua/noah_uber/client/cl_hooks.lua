hook.Add("OnScreenSizeChanged", "NoahUber:Fonts", function()
  NoahUber.Fonts = {}
  NoahUber.Shadow = nil
end)

hook.Add("InitPostEntity", "NoahUber:ClientJob", function()
  timer.Simple(2, function()
    if TEAM_NOAHUBER or (NoahUber_GetTeam and NoahUber_GetTeam()) then return end
    if not DarkRP or not DarkRP.createJob then return end
    include("darkrp_modules/noah_uber/sh_job.lua")
  end)
end)

hook.Add("ShutDown", "NoahUber:StopRing", function()
  if NoahUber_StopRing then NoahUber_StopRing() end
end)
