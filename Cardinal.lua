--[[
	Cardinal System
	Responsible for the economy and administration.

  After watching Sword Art Online: Alicization, I was obsessed with having admin commands that can control the game as I'm playing it. 

  Basically, this is a Cardinal system based off SAO.. a really advanced SAO: Alicization version of admin commands.
--]]

	==Commands Template==
	System Call: Generate Part - Creates a Part 
	Form Element, (35, 35, 35) Size - Makes that Part have 35, 35, 35 Size
	
]]
local function printStackTrace() print(debug.traceback()) end

local RBXServices = {
	Workspace = game:GetService('Workspace'),
	ReplicatedStorage = game:GetService('ReplicatedStorage'),
	Lighting = game:GetService('Lighting'),
	ServerScriptService = game:GetService('ServerScriptService'),
	ServerStorage = game:GetService('ServerStorage'),
}

local Utilities = require(RBXServices.ReplicatedStorage:FindFirstChild('Utilities'))
local Tween = Utilities.Tween

local rc4 = Utilities.rc4
local sha256 = Utilities.sha256

local CUtil = require(script.CardinalUtilities)
local Permissions = require(script.CardinalPermissions)

local undefined, null = unpack(CUtil:getEtc())
local create = Utilities.Create 

local tnum, tstr = tonumber, tostring 

local jsonManip = CUtil:getLib('json_manip')
local printLib = CUtil:getLib('print')
local easingLib = CUtil:getLib('easing')
local BezierCurve = CUtil:getLib('BezierCurve')({Utilities = Utilities}) --change when added in game

local jsonEncode = jsonManip.json_encode
local jsonDecode = jsonManip.json_decode

local storage = RBXServices.ReplicatedStorage

local PLACE_ID = game.PlaceId

local DEFAULT_PERMISSION = 'Player'
local DEFAULT_LIGHT_BRIGHTNESS_KEY = 'DEFAULT_LIGHT_BRIGHTNESS'
local DEFAULT_LIGHT_BRIGHTNESS_VAL = 10
local UNKNOWN_VECTOR = 'VECTOR_UNKNOWN_VAL'
local PLAYER_REGEX = "[%w_]+"
local MINI_CARDINAL_PREFIX = '!'
local MINI_CARDINAL_PREFIX_KEY = string.format('MINI_PREFIX:%s', MINI_CARDINAL_PREFIX)
local Constants = {
	[DEFAULT_PERMISSION] = DEFAULT_PERMISSION,
	[DEFAULT_LIGHT_BRIGHTNESS_KEY] = DEFAULT_LIGHT_BRIGHTNESS_VAL,
	[MINI_CARDINAL_PREFIX_KEY] = MINI_CARDINAL_PREFIX,
	[PLACE_ID] = game.PlaceId,
	[PLAYER_REGEX] = PLAYER_REGEX,
	[UNKNOWN_VECTOR] = UNKNOWN_VECTOR
}

local ChatService = nil 
if RBXServices.ServerScriptService:FindFirstChild('ChatService') then 
	ChatService = require(RBXServices.ServerScriptService:WaitForChild('ChatService'))
end

local Request = Utilities.class({}, function(id, player)
	local self = {}
	if id then 
		self.id = id 
	else
		self.id = Utilities.uid()
	end
	self.player = player 
	return self 
end)

local Cardinal = {
	tPlayerRequests = {},
	currentPlayerRequests = {},
	queue = {},
	luminanceMultiplier = 1,
	sizeMultipliers = {0.5, 2, 3.5, 5, 10},
	runningEvents = {}
}

function Cardinal:SyncChatService()
	ChatService:RegisterMessagingService()
	self:ConnectEvent(ChatService.ChatEvent, 'OnServerEvent', function(player, msg)
		local args = ChatService.Utilities.split(msg, " ")
		local speakerPlayer = ChatService:GetSpeaker(player.Name)
		if args[1] == "!pm" then
			local to = args[2]
			local actualMessage = tostring(ChatService:GetCombinedArgs(args, 3))
			ChatService:SendPrivateMessage(speakerPlayer, ChatService:GetSpeaker(to), actualMessage)
		elseif ChatService.BotCommands[args[1]] then
			local cmdData = ChatService.BotCommands[args[1]]
			cmdData.Fn(cmdData, player, args)
		else
			speakerPlayer:SendMessage(msg:sub(1, ChatService.MAX_MESSAGE_LENGTH))
		end
	end)
	self:ConnectEvent('Players', 'PlayerAdded', function(player)
		local speakerPlayer = ChatService:CreateSpeaker({Name = player.Name, player = player})
		for i, speaker in next, ChatService.Speakers do 
			if speaker.WelcomeMessage and speaker:IsBot() then
				speaker:SendMessage(ChatService:FormatMessage(speaker.WelcomeMessage, nil, speaker, speakerPlayer.Name))
			end
		end
		if not game:GetService("RunService"):IsStudio() then
			if self:IsBanned(player) then
				ChatService:HandleBannedPlayer(player)               
			end
		end
	end)
	ChatService.Cardinal = self 
end

function Cardinal:IsBanned(player)
	return ChatService:IsBanned(player)
end

function Cardinal:Try(...) --no identifier support yet
	local args = {...}
	local arg1 = args[1]
	local identifier, fn;
	if type(arg1) == 'function' then 
		fn = arg1 
	elseif type(arg1) == 'string' then 
		identifier = arg1
		fn = args[2]
	end
	if type(fn) == 'function' then 
		local s, r = pcall(function()
			return fn()
		end)
		return r 
	end
end

function Cardinal:toId(str)
	return str:lower()--str:lower():gsub(' ', '-')
end

function Cardinal:processPlayerRequest(player, req)
	if not self.currentPlayerRequests[player] then 
		if self:GetDataType(player) == 'Player' then 
			self.currentPlayerRequests[player] = {}
		else
			return false 
		end
	end
	for i, r in next, self.currentPlayerRequests[player] do 
		if r.id == req.id then 
			return false 
		end
	end
	if req.invalid  then 
		return false 
	end
	table.insert(self.currentPlayerRequests[player], req)
	return true 
end

function Cardinal:expireRequest(player, rid)
	if self.currentPlayerRequests[player] then 
		for i, rq in next, self.currentPlayerRequests[player] do 
			if rq.id == rid then 
				self.currentPlayerRequests[player][i] = nil 
				rq = nil
				break
			end
		end
	end
end

function Cardinal:clearRequests(player)
	if self.currentPlayerRequests[player] then 
		for i, rq in next, self.currentPlayerRequests[player] do 
			rq = nil 
		end
	end
	self.currentPlayerRequests[player] = {}
	return true 
end

function Cardinal:makeRequest(...)
	local args = {...}
	local req = nil
	if not args[2] then return false end 
	if self:GetDataType(args[2]) ~= 'Player' then 
		return false 
	end
	if type(args[1]) == 'string' then 
		req = Request:new(args[1], args[2]) --hmm?
	end
	return req 
end

function Cardinal:getRequest(player, rid)
	if self.currentPlayerRequests[player] then 
		for i, rq in next, self.currentPlayerRequests[player] do 
			if rq.id == rid then 
				return rq 
			end
		end
	end
end

function Cardinal:getRequestFromPartialID(player, rqid)
	if self.currentPlayerRequests[player] then 
		for i, rq in next, self.currentPlayerRequests[player] do 
			if rq.id:find(rqid) then 
				return rq 
			end
		end
	end
end

function Cardinal:getSysCommandRequest(player, rqid)
	return self:getRequest(player, 'SYS_COMMAND: ' .. tostring(rqid))
end

function Cardinal:Compare(obj1, obj2)
	return self:Try(function() return obj1 == obj2 end)
end

function Cardinal:GetDataType(obj)
	local objType = typeof(obj)
	if objType == 'Instance' then 
		return self:Try(function()
			return obj.ClassName
		end)
	end
	return objType
end

function Cardinal:GetPermissions(player)
	local perms = {
		[ChatService:GetSpeaker(player).Rank] = true 
	}
	if self:GetDataType(player) == 'Player' then 
		local pPerm = self:Try(function()
			for u, c in next, Permissions do 
				for id, isPermitted in next, c do 
					if self:Compare(id, player.UserId) then 
						return u
					end
				end
			end
			return DEFAULT_PERMISSION
		end)
		perms[pPerm] = true 
	end
	
	perms.Owner = true 
	
	return perms 
end

function Cardinal:ParseString(str)
	local prefix = str:match('([%w|? ?]+):')
	if not prefix then 
		return 
	end
	if prefix == 'Get' then 
		local item = str:match('[%w]+: ([%w%p]+)')
		if Constants[item] then 
			return Constants[item]
		end
	elseif prefix == 'System Call' then 
		local sargs = {}
		local pCommand = str:match('[%w ?]+: ([%w%s]+)%.?!?')
		sargs.IsSystem = true
		sargs.Prefix = prefix
		sargs.Command = pCommand
		return sargs
		--	print(pCommand)
	elseif prefix == '|' then 
		local sargs = {
			Prefix = prefix,
			Command = str:match('|: ([%w%s%p]+)'),
			IsPartialCommand = true,
		}
		return sargs
	end
	return 
end

function Cardinal:GetService(...)
	local r = {}
	local args = {...}
	for _, arg in next, {...} do 
		if RBXServices[arg] then 
			table.insert(r, RBXServices[arg])
		elseif game:GetService(arg) then 
			table.insert(r, game:GetService(arg))
		end
	end
	return #r > 1 and r or table.remove(r, 1)
end


function Cardinal:ConnectEvent(obj, eventName, ...)
	local funcs = {...}
	for i, func in next, funcs do 
		if self:GetDataType(func) ~= 'function' then 
			return false 
		end
	end
	self:Run(function()
		if self:GetService(obj) then 
			obj = self:GetService(obj)
		end
		return true 
	end)
	if self:Run(function()
			return obj[eventName]
		end) == false then 
		return false 
	end
	
	for i, func in next, funcs do 
		obj[eventName]:connect(func)
	end
	return true 
end

function Cardinal:Hash(algorithm, ...)
	local acceptableAlgorithms = {'sha256', 'rc4'}
	if not acceptableAlgorithms[algorithm] then 
		return false 
	end
	return self[algorithm:upper()](...)
end

function Cardinal:RC4(...)
	local q = {}
	if #({...}) > 0 then 
		for i, v in next, ({...}) do 
			if type(v) == 'string' then 
				q[i] = rc4(v)
			end
		end
	end
	return unpack(q)
end

function Cardinal:SHA256(...)
	local q = {}
	if #({...}) > 0 then 
		for i, v in next, ({...}) do 
			if type(v) == 'string' then 
				q[i] = sha256(v)
			end
		end
	end
	return unpack(q)
end

function Cardinal:GetEntryPoint(player)
	return self:GetService('Workspace'):FindFirstChild(player.Name):FindFirstChild('HumanoidRootPart')
end

function Cardinal:resolvePlayers(sender, str)
	str = str:lower()
	if str == 'me' or str == 'self' then 
		return {sender}
	elseif str == 'all' then 
		local t = {}
		for _, v in next, game:GetService('Players'):GetPlayers() do 
			table.insert(t, v)
		end
		return t 
	elseif str == 'others' then 
		local t = {}
		for _, v in next, game:GetService('Players'):GetPlayers() do 
			if v ~= sender then 
				table.insert(t, v)
			end
		end
		return t 
	else
		local t = {}
		local args;
		if str:find(', ') then 
			args = Utilities.split(str, ', ')
		end
		if not args then 
			args = {str}
		end
		for i, plr in next, game:GetService('Players'):GetPlayers() do 
			for u, arg in next, args do 
				if string.lower(plr.Name:sub(1, #arg)) == string.lower(arg) then 
					table.insert(t, plr)
				end
			end
		end
		return t 
	end
end

function Cardinal:GetCommandTargets(sender, target)
	local targ = nil 
	if self:GetDataType(target) ~= 'string' then 
		return false 
	end
	target = target:lower()
	
	
	local players = self:resolvePlayers(sender, target)
	local targets = {}
	local Workspace = self:GetService('Workspace')
	for i, player in next, players do 
		table.insert(targets, self:GetEntryPoint(player))
	end
	
	local targetId = self:toId(target)
	--if targetId:sub(1, 5) == 'mouse' then 
	----	local suffix = targetId:sub(7)
	----	if (suffix == 'pos' or suffix == 'hit' or suffix == 'cframe' or suffix == 'position' or suffix == ''
	--	return player
	--end
	
	return targets 
end

function Cardinal:Warn(...)
	for i, arg in next, ({...}) do 
		warn(string.format('CardinalWarning: %s', tostring(arg)))
	end
end

function Cardinal:GetStringTarget(player, str, ignoringPlayers)
	local myHrp = self:GetEntryPoint(player)
	local magnitude = 80
	local cf = myHrp.CFrame
	if str == 'front' then 
		return (cf + cf.lookVector * magnitude).p
	elseif str == 'back' then 
		return (cf - cf.lookVector * magnitude).p
	elseif str == 'left' then 
		return (cf - cf.rightVector * magnitude).p
	elseif str == 'right' then 
		return (cf + cf.rightVector * magnitude).p
	elseif str:match('[%w]+ '..PLAYER_REGEX) then 
		if ignoringPlayers then 
			return
		end
		local matchedPlayer;
		for i, v in pairs({'at', 'to'}) do 
			local match = str:match(string.format('%s %s', v, '('..PLAYER_REGEX..')'))
			if match then 
				print(match)
				matchedPlayer = match 
				break 
			end
		end
		if not matchedPlayer then 
			return false 
		end
		local targets = {}
		local players = self:resolvePlayers(player, matchedPlayer)
		if #players ~= 1 then 
			return UNKNOWN_VECTOR
		end
		local targetPart = self:GetEntryPoint(unpack(players))
		return targetPart.CFrame + targetPart.CFrame.lookVector * 3
	end
end

function Cardinal:ModifyPart(part, prop, propVal, player)
	return self:Try(function()
		local Vector3Regex = '%([%d]+, [%d]+, [%d]+%)'
		local Vector3ComponentRegex = '%(([%d]+), ([%d]+), ([%d]+)%)'
		local WordRegex = "[%w]+"
		if prop == 'shape' then 
			if propVal == 'ball' or propVal == 'sphere' then 
				part.Shape = "Ball"
				return true 
			elseif propVal == 'block' or propVal == 'cube' then 
				part.Shape = "Block"
				return true 
			elseif propVal == 'cylinder' then 
				part.Shape = "Cylinder"
				return true 
			end
		elseif prop == 'size' then
			local propValToIndex = {
				small = 1,
				tiny  = 1,
				medium = 2,
				big = 3,
				large = 3,
				giant = 4,
				huge = 4,
				ginormous = 4,
				humongous = 4,
				insane = 5
			}
			if propValToIndex[propVal] then 
				part.Size = part.Size * self.sizeMultipliers[propValToIndex[propVal]]
			elseif propVal:match(Vector3Regex) then 
				local sizex, sizey, sizez = propVal:match(Vector3ComponentRegex)
				sizex = tonumber(sizex)
				sizey = tonumber(sizey)
				sizez = tonumber(sizez)
				part.Size = Vector3.new(sizex, sizey, sizez)
			end
		elseif prop:match(WordRegex) == 'color' or prop:match(WordRegex) == 'brickcolor' then 
			local newColor = propVal:match('([%w%s%p]+)')
			if newColor:sub(1, 1):match("[a-z]") then 
				local cindex = newColor:sub(1, 1):upper()..newColor:sub(2)
				if BrickColor[cindex] then 
					part.BrickColor = BrickColor[cindex]()
				elseif BrickColor.new(cindex) then 
					part.BrickColor = BrickColor.new(cindex)
				end
			elseif newColor:match(Vector3Regex) then --colors can be signified as vectors too
				local r, g, b = newColor:match(Vector3ComponentRegex)
				r = tonumber(r)
				g = tonumber(g)
				b = tonumber(b)
				if (r > 1 and g > 1 and b > 1) then 
					part.Color = Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
				else
					part.Color = Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
				end
			end
		elseif prop:match(WordRegex) == 'material' or prop:match(WordRegex) == 'mat' then 
			local newMaterial = propVal:sub(1, 1):upper()..propVal:sub(2)
			if Enum.Material[newMaterial] then 
				part.Material = Enum.Material[newMaterial]
			end
		elseif prop == 'pos' or prop == 'position' then 
			local firstWord = propVal:find(WordRegex)
			local wordToAngle = {near = math.random(), behind = math.rad(180)}
			if wordToAngle[firstWord] then 
				local radius = (part.Size.X + part.Size.Y + part.Size.Z) / 3
				local theta = 0 
				if wordToAngle[firstWord] then 
					theta = wordToAngle[firstWord]*math.pi*2
				end
				part.Position = self:GetEntryPoint(player).Position + Vector3.new(math.cos(theta), firstWord == 'above' and 2 or 0, math.sin(theta)) * radius
			elseif propVal == "random" then 
				local roll = math.random(-360, 360)
				part.Position = self:GetEntryPoint(player).Position + Vector3.new(roll, roll, roll)
			elseif #self:GetCommandTargets(player, propVal) > 0 then 
				local hrps = self:GetCommandTargets(player, propVal)
				for i, hrp in next, hrps do 
					part.Position = hrp.CFrame + hrp.lookVector * 3
				end
			elseif propVal:match(Vector3Regex) then 
				local px, py, pz = propVal:match(Vector3ComponentRegex)
				px = tonumber(px)
				py = tonumber(py)
				pz = tonumber(pz)
				part.Size = Vector3.new(px, py, pz)
			end
		end
	end)
end

function Cardinal:RunSystemCommand(player, rargs)
	if not player then 
		return false 
	end
	local command = rargs.Command
	local cid = self:toId(command)
	local rqid = string.format('SYS_COMMAND: %s', cid)
	if cid:sub(1, 8) == 'generate' then
		if not self:getRequestFromPartialID(player, cid) then 
			self:clearRequests(player)
		end
	end
	local r = self:getRequest(player, rqid) 
	local phrp = self:GetEntryPoint(player)
	if not r and not self:getRequestFromPartialID(player, 'SYS_COMMAND') then 
		r = self:makeRequest(rqid, player)
		if not r then 
			return false 
		end
		if not self:processPlayerRequest(player, r) then 
			return false 
		end
	end
	local function send(...)
		ChatService:SendCardinalMessage(..., player)
	end
	local format = string.format 
	
	if cid == 'generate luminous element' then 
		local light = create('PointLight'){
			Parent = storage
		}
		r.item = light 
		send('Luminous Element Generated. Type Adhere <target> to adhere it.')
	elseif cid == 'generate part' then 
		local part = create('Part'){
			Parent = self:GetService('Workspace'),
			CFrame = phrp.CFrame + phrp.CFrame.lookVector * 5,
			Transparency = 1,
		}
		Tween(.65, 'easeOutCubic', function(a)
			part.Transparency = 1 - a
		end)
		part.Material = Enum.Material.Plastic
		r.item = part 
		send('Generated Part.')
	elseif cid:match('[%w]+ [%w]+') == 'form element' then 
		local propVal, prop = cid:match('[%w]+ [%w]+%p? (%(?[%w%p%d ]+%)?) ([%w%p%s]+)')
		local partReq = self:getSysCommandRequest(player, 'generate part')
		if partReq then 
			local part = partReq.item
			if part then 
				local result = self:Try(function()
					self:ModifyPart(part, prop, propVal, player)
				end)
				if not result then 
					self:Warn(result)
				end
			end
		end
		send(format('%s has been changed to %s.', prop, propVal))
	elseif cid:match('[%w]+') == 'discharge' then 
		local partReq = self:getSysCommandRequest(player, 'generate part')
		local target = self:GetStringTarget(player, cid:match('[%w]+ ([%w%s]+)'))
		if target == UNKNOWN_VECTOR then 
			return false 
		end
		local part = partReq.item 
		local oPos = part.Position
		local bezier = BezierCurve:new(oPos, Vector3.new(0, 0, 0), target)
		bezier:ResolveMiddle()
		Tween(1.5, 'easeOutCubic', function(a)
			part.Position = bezier:Solve(a)
		end)
		send('Discharged part.')
	elseif cid:match('[%w]+') == 'adhere' then 
		local lightReq = self:getSysCommandRequest(player, 'generate luminous element')
		local sParent = cid:match('[%w]+ ([%w%s]+)')
		if sParent then 
			local targets = self:GetCommandTargets(player, sParent)
			local pointLight = lightReq.item 
			if pointLight then 
				if #targets > 1 then 
					for i, target in next, targets do 
						local nPointLight = pointLight:Clone()
						nPointLight.Parent = target 
						nPointLight.Brightness = Constants[DEFAULT_LIGHT_BRIGHTNESS_KEY] * self.luminanceMultiplier
					end
					pointLight:Destroy()
				else
					pointLight.Parent = targets[1]
					pointLight.Brightness = Constants[DEFAULT_LIGHT_BRIGHTNESS_KEY] * self.luminanceMultiplier
				end
				return true 
			end
		end
		send('Adhered previously generated Luminous Element.')
	elseif cid:match('[%w]+ [%w]+') == 'set time' then 
		local ti = cid:match('[%w]+ [%w]+ ([%d]+)')
		local nowTime = self:GetService('Lighting').ClockTime
		Tween(2, 'easeOutCubic', function(a)
			self:GetService('Lighting').ClockTime = nowTime + (tonumber(ti) - nowTime) * a
		end)
		send(format('Time has successfully been set to %s', ti))
	end
end

function Cardinal:RunCommand(speaker, args)
	return ChatService.Commands[args[1]].cmd(speaker, args) 
end

function Cardinal:Run(...) --:Run("System Call: Generate Luminous Element.", "Adhere")
	local args = {...}
	local arg1 = args[1]
	if self:Compare(self:GetDataType(arg1), 'Player') then 
		local cResults = {}
		for i = 0, #args-1 do 
			local currentString = select(2+i, ...)
			if not currentString then 
				break
			end
			if not currentString:match('[%w]+:') and self:getRequestFromPartialID(arg1, 'SYS_COMMAND') then 
				currentString = '|: '..currentString
			end
			local rargs = self:ParseString(currentString)
			if rargs then 
				if self:Compare(rargs.Prefix:lower(), 'system call') or self:Compare(rargs.Prefix, '|') then 
					local player = arg1 
					local playerPerms = self:GetPermissions(player)
					if playerPerms['Owner'] then 
						local commandResult = self:RunSystemCommand(player, rargs)
						if commandResult then 
							self:Try(function()
								table.insert(cResults, commandResult)
							end)
						end
					else
						ChatService:SendErrorMessage('Cardinal Access Denied.', player)
					end
				end
			elseif self:Compare(currentString:sub(1, 1), Constants[MINI_CARDINAL_PREFIX_KEY]) then 
				local player = arg1 
				local playerPerms = self:GetPermissions(player)
				local speakerPlayer = ChatService:GetSpeaker(player)
				if speakerPlayer then 
					if (playerPerms['Owner'] or playerPerms['Developer']) then 
						local cParams = Utilities.split(currentString:sub(2), ' ')
						if ChatService.Commands[cParams[1]] then 
							self:Try(function()
								table.insert(cResults, self:RunCommand(speakerPlayer, cParams))
							end)
						else
							ChatService:SendErrorMessage("You cannot execute commands.", player)
						end
					end
				end
			end
		end
		return cResults
	elseif self:Compare(self:GetDataType(arg1), 'function') then 
		return self:Try(...)
	end
end

Cardinal:SyncChatService()

return Cardinal
