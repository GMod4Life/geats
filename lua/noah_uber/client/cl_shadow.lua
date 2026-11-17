-- Soft shadow helper from gcreator (github.com/wasied/gcreator)
-- Kept on NoahUber.Shadow so it does not replace another addon's global.

NoahUber = NoahUber or {}

function NoahUber_InitShadow()
  if NoahUber.Shadow and NoahUber.Shadow.Ready then return end
  local iW, iH = ScrW(), ScrH()
  local sRes = iW .. "x" .. iH
  local tShadow = {}
  tShadow.Ready = true
  tShadow.RT1 = GetRenderTarget("noah_uber_shadow_a_" .. sRes, iW, iH)
  tShadow.RT2 = GetRenderTarget("noah_uber_shadow_b_" .. sRes, iW, iH)
  tShadow.Mat = CreateMaterial("noah_uber_shadow_mat_" .. sRes, "UnlitGeneric", {
    ["$translucent"] = 1,
    ["$vertexalpha"] = 1,
    ["$alpha"] = 1,
    ["$color"] = "0 0 0",
    ["$color2"] = "0 0 0",
  })
  tShadow.MatClean = CreateMaterial("noah_uber_shadow_clean_" .. sRes, "UnlitGeneric", {
    ["$translucent"] = 1,
    ["$vertexalpha"] = 1,
    ["$alpha"] = 1,
  })

  function tShadow:BeginShadow()
    render.PushRenderTarget(self.RT1)
    render.OverrideAlphaWriteEnable(true, true)
    render.Clear(0, 0, 0, 0)
    render.OverrideAlphaWriteEnable(false, false)
    cam.Start2D()
  end

  function tShadow:EndShadow(iIntensity, iBlur, iOpacity, iDistance)
    iIntensity = iIntensity or 2
    iBlur = iBlur or 2
    iOpacity = iOpacity or 180
    iDistance = iDistance or 8
    render.CopyRenderTargetToTexture(self.RT2)
    if iBlur > 0 then
      render.OverrideAlphaWriteEnable(true, true)
      render.BlurRenderTarget(self.RT2, 1, 1, iBlur)
      render.OverrideAlphaWriteEnable(false, false)
    end
    render.PopRenderTarget()
    self.Mat:SetTexture("$basetexture", self.RT2)
    self.Mat:SetFloat("$alpha", iOpacity / 255)
    render.SetMaterial(self.Mat)
    for i = 1, math.ceil(iIntensity) do
      render.DrawScreenQuadEx(0, iDistance, iW, iH)
    end
    self.MatClean:SetTexture("$basetexture", self.RT1)
    render.SetMaterial(self.MatClean)
    render.DrawScreenQuad()
    cam.End2D()
  end

  NoahUber.Shadow = tShadow
end
