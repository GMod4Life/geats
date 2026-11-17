--[[
	Delivery job.
	Change the name, the command, the salary, the models and the category here.
	Leave TEAM_NOAHUBER as it is: the addon uses it to recognise the courier.
]]

if not DarkRP or not DarkRP.createJob then return end
if TEAM_NOAHUBER then return end

TEAM_NOAHUBER = DarkRP.createJob("Delivery Driver", {
	color = Color(6, 193, 103, 255),
	model = {
		"models/player/Group01/Male_07.mdl",
		"models/player/Group01/Female_02.mdl",
	},
	description = [[Deliver food orders around the city.
Type /uber to open the app.]],
	weapons = {},
	command = "delivery",
	max = 4,
	salary = 45,
	admin = 0,
	vote = false,
	hasLicense = false,
	candemote = true,
	category = "Citizens",
	sortOrder = 100,
})
