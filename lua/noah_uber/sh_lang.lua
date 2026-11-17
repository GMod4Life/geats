NoahUber = NoahUber or {}
NoahUber.Lang = NoahUber.Lang or {}
NoahUber.LangCodes = { "fr", "en", "de", "es", "pt", "ru", "tr" }

function NoahUber_AddLang(sCode, tPhrases)
  NoahUber.Lang[string.lower(tostring(sCode or ""))] = tPhrases or {}
end

function NoahUber_GetLangCode()
  if CLIENT then
    local cv = GetConVar("noah_uber_language")
    if cv then
      local sValue = string.lower(cv:GetString() or "")
      if NoahUber.Lang[sValue] then return sValue end
    end
  end

  local sCfg = string.lower((NoahUber.Config and NoahUber.Config.Language) or "en")
  if NoahUber.Lang[sCfg] then return sCfg end
  return "en"
end

function NoahUber_L(sKey, ...)
  local sCode = NoahUber_GetLangCode()
  local tLang = NoahUber.Lang[sCode] or NoahUber.Lang.fr or {}
  local sText = tLang[sKey]
  if sText == nil and NoahUber.Lang.en then sText = NoahUber.Lang.en[sKey] end
  if sText == nil and NoahUber.Lang.fr then sText = NoahUber.Lang.fr[sKey] end
  if sText == nil then return tostring(sKey or "") end

  if select("#", ...) > 0 then
    local bOk, sResult = pcall(string.format, sText, ...)
    if bOk then return sResult end
  end

  return sText
end

function NoahUber_CheckLang()
  local tMaster = NoahUber.Lang.en or {}
  for sCode, tPhrases in pairs(NoahUber.Lang) do
    if sCode ~= "en" then
      for sKey in pairs(tMaster) do
        if tPhrases[sKey] == nil then
          local sMsg = "Missing phrase  " .. sCode .. "  " .. sKey
          if NoahUber_Print then
            NoahUber_Print("warn", sMsg)
          else
            print("[Noah Uber] " .. sMsg)
          end
        end
      end
    end
  end
end
