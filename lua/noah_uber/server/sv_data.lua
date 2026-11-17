NoahUber = NoahUber or {}
NoahUber.VehicleProfile = NoahUber.VehicleProfile or nil

local function NoahUber_Query(sQuery)
  local tResult = sql.Query(sQuery)
  if tResult == false then
    ErrorNoHalt("[NoahUber] SQL : " .. tostring(sql.LastError()) .. "\n")
    return false
  end
  return tResult
end

function NoahUber_InitSQL()
  NoahUber_Query([[CREATE TABLE IF NOT EXISTS noah_uber_invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    steamid TEXT NOT NULL,
    order_uid INTEGER NOT NULL,
    payout INTEGER NOT NULL,
    created INTEGER NOT NULL,
    delivered INTEGER NOT NULL,
    restaurant TEXT NOT NULL,
    customer TEXT NOT NULL,
    address TEXT NOT NULL,
    distance INTEGER NOT NULL,
    window_start INTEGER NOT NULL,
    window_end INTEGER NOT NULL,
    on_time INTEGER NOT NULL,
    payload TEXT NOT NULL
  )]])
  NoahUber_Query("CREATE INDEX IF NOT EXISTS noah_uber_inv_sid ON noah_uber_invoices (steamid, delivered)")
  local bTip = false
  local tCols = sql.Query("PRAGMA table_info(noah_uber_invoices)")
  if istable(tCols) then
    for i = 1, #tCols do
      if tCols[i].name == "tip" then bTip = true end
    end
  end
  if not bTip then
    NoahUber_Query("ALTER TABLE noah_uber_invoices ADD COLUMN tip INTEGER NOT NULL DEFAULT 0")
  end
  NoahUber_Query([[CREATE TABLE IF NOT EXISTS noah_uber_totals (
    steamid TEXT PRIMARY KEY,
    total INTEGER NOT NULL
  )]])
end

function NoahUber_SaveInvoice(pPlayer, tOrder, iPay, iTip)
  local sId = NoahUber_ValidSteam(pPlayer)
  if not sId or not tOrder then return end

  iPay = math.floor(tonumber(iPay) or 0)
  iTip = math.Clamp(math.floor(tonumber(iTip) or 0), 0, NoahUber.Constants.hardMaxTip or 25000)
  local iNow = os.time()
  local sItems = util.TableToJSON(tOrder.items or {}) or "[]"
  if #sItems > 2000 then sItems = "[]" end

  local bOk = NoahUber_Query(string.format(
    "INSERT INTO noah_uber_invoices (steamid, order_uid, payout, tip, created, delivered, restaurant, customer, address, distance, window_start, window_end, on_time, payload) VALUES (%s, %d, %d, %d, %d, %d, %s, %s, %s, %d, %d, %d, %d, %s)",
    sql.SQLStr(sId),
    math.floor(tonumber(tOrder.id) or 0),
    iPay,
    iTip,
    math.floor(tonumber(tOrder.created) or iNow),
    iNow,
    sql.SQLStr(NoahUber_Sanitize(tOrder.restaurantName, 48)),
    sql.SQLStr(NoahUber_Sanitize(tOrder.customerName, 32)),
    sql.SQLStr(NoahUber_Sanitize(tOrder.customerAddress, 80)),
    math.floor(tonumber(tOrder.distance) or 0),
    math.floor(tonumber(tOrder.windowStart) or iNow),
    math.floor(tonumber(tOrder.windowEnd) or iNow),
    tOrder.onTime and 1 or 0,
    sql.SQLStr(sItems)
  ))

  if bOk == false then return end

  local tRow = sql.QueryRow("SELECT total FROM noah_uber_totals WHERE steamid = " .. sql.SQLStr(sId))
  if tRow and tonumber(tRow.total) then
    local iTotal = math.floor(tonumber(tRow.total) + iPay + iTip)
    NoahUber_Query("UPDATE noah_uber_totals SET total = " .. iTotal .. " WHERE steamid = " .. sql.SQLStr(sId))
  else
    NoahUber_Query("INSERT INTO noah_uber_totals (steamid, total) VALUES (" .. sql.SQLStr(sId) .. ", " .. (iPay + iTip) .. ")")
  end
end

local function NoahUber_WeekStart()
  local tNow = os.date("*t")
  tNow.hour, tNow.min, tNow.sec = 0, 0, 0
  local iToday = os.time(tNow)
  local iBack = (tNow.wday - 2) % 7
  if iBack < 0 then iBack = iBack + 7 end
  return iToday - (iBack * 86400)
end

function NoahUber_QueryEarnings(sId)
  local iTotal, iToday, iCount, iWeek = 0, 0, 0, 0
  if not sId then return iTotal, iToday, iCount, iWeek end

  local tTotal = sql.QueryRow("SELECT total FROM noah_uber_totals WHERE steamid = " .. sql.SQLStr(sId))
  if tTotal and tonumber(tTotal.total) then
    iTotal = math.floor(tonumber(tTotal.total))
  end

  local tNow = os.date("*t")
  local iStart = os.time({ year = tNow.year, month = tNow.month, day = tNow.day, hour = 0, min = 0, sec = 0 })
  local sSum = "SUM(payout + COALESCE(tip, 0))"
  local tToday = sql.QueryRow("SELECT " .. sSum .. " AS s, COUNT(*) AS c FROM noah_uber_invoices WHERE steamid = " .. sql.SQLStr(sId) .. " AND delivered >= " .. math.floor(iStart))
  if tToday then
    iToday = math.floor(tonumber(tToday.s) or 0)
    iCount = math.floor(tonumber(tToday.c) or 0)
  end

  local tWeek = sql.QueryRow("SELECT " .. sSum .. " AS s FROM noah_uber_invoices WHERE steamid = " .. sql.SQLStr(sId) .. " AND delivered >= " .. math.floor(NoahUber_WeekStart()))
  if tWeek then
    iWeek = math.floor(tonumber(tWeek.s) or 0)
  end

  return iTotal, iToday, iCount, iWeek
end

function NoahUber_QueryHistory(sId)
  local tList = {}
  if not sId then return tList end

  local tRows = sql.Query("SELECT id, payout, tip, created, delivered, restaurant, customer, address, distance, window_start, window_end, on_time, payload FROM noah_uber_invoices WHERE steamid = " .. sql.SQLStr(sId) .. " ORDER BY delivered DESC LIMIT 25")
  if tRows == false or not istable(tRows) then return tList end

  local tAllowed = {}
  for _, sFood in ipairs(NoahUber.Constants.foods or {}) do
    tAllowed[sFood] = true
  end

  for i = 1, #tRows do
    local tRow = tRows[i]
    local tItems = {}
    local tPayload = util.JSONToTable(tostring(tRow.payload or "[]"))
    if istable(tPayload) then
      for j = 1, math.min(#tPayload, 6) do
        if tAllowed[tPayload[j]] then
          tItems[#tItems + 1] = tPayload[j]
        end
      end
    end

    tList[#tList + 1] = {
      id = math.floor(tonumber(tRow.id) or 0),
      payout = math.Clamp(math.floor(tonumber(tRow.payout) or 0), 0, NoahUber.Constants["hardMaxPay"] or 75000),
      tip = math.Clamp(math.floor(tonumber(tRow.tip) or 0), 0, NoahUber.Constants["hardMaxTip"] or 25000),
      created = math.floor(tonumber(tRow.created) or 0),
      delivered = math.floor(tonumber(tRow.delivered) or 0),
      restaurant = NoahUber_Sanitize(tRow.restaurant, 48),
      customer = NoahUber_Sanitize(tRow.customer, 32),
      address = NoahUber_Sanitize(tRow.address, 80),
      distance = math.floor(tonumber(tRow.distance) or 0),
      windowStart = math.floor(tonumber(tRow.window_start) or 0),
      windowEnd = math.floor(tonumber(tRow.window_end) or 0),
      onTime = tonumber(tRow.on_time) == 1,
      items = tItems,
    }
  end

  return tList
end

function NoahUber_LoadVehicle()
  if not file.Exists("noah_uber/vehicle.json", "DATA") then return end
  local sRaw = file.Read("noah_uber/vehicle.json", "DATA")
  if not sRaw or #sRaw > 4000 then return end
  local tData = util.JSONToTable(sRaw)
  if not istable(tData) then return end
  NoahUber.VehicleProfile = {
    class = NoahUber_Sanitize(tData.class, 64),
    model = NoahUber_Sanitize(tData.model, 128),
    script = NoahUber_Sanitize(tData.script, 64),
  }
end

function NoahUber_SaveVehicle(tProfile)
  file.CreateDir("noah_uber")
  NoahUber.VehicleProfile = {
    class = NoahUber_Sanitize(tProfile.class, 64),
    model = NoahUber_Sanitize(tProfile.model, 128),
    script = NoahUber_Sanitize(tProfile.script, 64),
  }
  file.Write("noah_uber/vehicle.json", util.TableToJSON(NoahUber.VehicleProfile))
end

NoahUber_InitSQL()
NoahUber_LoadVehicle()
