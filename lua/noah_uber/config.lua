NoahUber = NoahUber or {}
NoahUber.Config = {}

--[[
	Noah Uber
	Edit this file for your server. The job itself is edited in
	lua/darkrp_modules/noah_uber/sh_job.lua
]]

-- Language used when a player has not chosen one.
-- fr, en, de, es, pt, ru, tr
NoahUber.Config.Language = "en"

-- Name shown on the phone, the HUD and in chat.
-- Rename it if you do not want to use the Uber Eats trademark on your store page.
NoahUber.Config.Brand = "Uber Eats"

-- true: only the job created in sh_job.lua can take orders.
-- false: every player can open the app with /uber.
NoahUber.Config.RequireJob = true

-- Lowest and highest payout for one delivery, in your DarkRP money.
-- A single delivery is never paid above 75,000. A double order is two deliveries.
NoahUber.Config.MinPay = 10000
NoahUber.Config.MaxPay = 75000

-- Chance from 0 to 1 that a courier is offered two deliveries at once.
NoahUber.Config.DoubleOrderChance = 0.35

-- Tip added on top of the delivery pay. The server picks one value at random.
-- 10,000 and 15,000 are listed twice, so they are picked more often.
NoahUber.Config.Tips = { 5000, 10000, 10000, 15000, 15000, 20000, 25000 }

-- Seconds the courier has to accept or refuse an offer.
NoahUber.Config.OfferDuration = 30

-- Seconds to wait after a courier refuses an offer.
NoahUber.Config.RefuseCooldown = 18

-- Seconds to wait after the last delivery before a new offer.
NoahUber.Config.AfterDeliveryCooldown = 10

-- Shortest and longest trip, in map units, between a restaurant and a customer.
NoahUber.Config.MinDistance = 1800
NoahUber.Config.MaxDistance = 16000

-- Map units that count as one kilometre on the phone and the HUD.
NoahUber.Config.UnitsPerKm = 1600

-- Minutes added to the delivery window for each kilometre.
NoahUber.Config.MinutesPerKm = 3

-- How close the courier must be to pick up or deliver, in map units.
NoahUber.Config.InteractDistance = 380

-- The scooter must be within this distance, unless the courier is sitting on it.
NoahUber.Config.VehicleDistance = 520

-- true: pickup and delivery are blocked without the delivery scooter.
NoahUber.Config.RequireVehicle = true

-- true: a teleport or a noclip during a trip cancels the payout.
NoahUber.Config.AntiTeleport = true

-- Fastest honest speed, in map units per second, before a move is flagged.
NoahUber.Config.MaxLegalSpeed = 7000

-- true: the phone opens by itself when a new offer arrives.
NoahUber.Config.AutoOpenOffer = true

-- true: the offer ringtone loops until the courier answers.
NoahUber.Config.LoopRing = true

-- Offer ringtone. The file must exist on the server.
NoahUber.Config.OrderSound = "sound/noah_uber/uber_eats_sounds.wav"

-- Sound played when a tip is received.
NoahUber.Config.SuccessSound = "sound/noah_uber/success.wav"

-- Workshop addon that contains the fonts, the ringtone and the tip sound.
-- Leave it empty until you have published noah_uber_content, then paste the ID.
-- The loader checks that this ID is mounted in the server collection.
NoahUber.Config.ContentWorkshopID = "3814659866"

-- Workshop addon for the Suzuki Address scooter.
-- The model is not included: its author forbids republication.
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2039701689
NoahUber.Config.VehicleWorkshopID = "2039701689"

-- Vehicle entry from that addon. Used when the scooter is spawned.
NoahUber.Config.VehicleList = "azok30_suzuki_address_uber_eats"

-- Model spawned for the scooter if the vehicle list is not ready yet.
NoahUber.Config.VehicleModel = "models/codeandmodeling/julian/suzuki_address_uber_eats.mdl"

-- Vehicle script used with the model above.
NoahUber.Config.VehicleScript = "scripts/vehicles/azok30/suzuki_address.txt"

-- Entity class of the scooter.
NoahUber.Config.VehicleClass = "prop_vehicle_jeep"

-- Extra usergroups that can place delivery points and register a vehicle.
-- superadmin and admin are always allowed.
NoahUber.Config.AdminRanks = {
	["superadmin"] = true,
	["admin"] = true,
	["fondateur"] = true,
}

-- Maximum number of restaurant and customer points on the map.
NoahUber.Config.MaxPoints = 80
