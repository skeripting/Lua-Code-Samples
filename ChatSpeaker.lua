return function(ChatService)
  -- ChatSpeaker class for my chatting system
	local SPAM_CONSIDERATION_DELAY = 2
	local SPAM_CONSIDERATION_COUNT = 3
	local GroupRankToRank = {
		[3] = "Contributor",
		[252] = "Moderator",
		[253] = "Administrator",
		[254] = "Developer",
		[255] = "Owner"
	}
	local Utilities = ChatService.Utilities
	local ChatSpeaker = Utilities.class({
		Rank = 'Player',
		Level = 1,
		__isChatSpeaker = true
	}, function(self)
		if self.player and not self.Name then 
			self.Name = self.player.Name
		end
		if not self.Name then 
			warn('ChatSpeaker Error: Speaker does not have a name!')
		end
		if not self.Nickname then 
			self.Nickname = self.Name 
		end
		if self.player then 
			local r = tonumber(self.player:GetRankInGroup(33187916))
			if r >= 3 then 
				self.Rank = GroupRankToRank[r]
			end
		end
		if self.Name == 'script_ingdev' then 
			self.Level = 1337
		end
		self.MessageLog = {}
		self.PotentialSpamCount = 0
		self.BypassSpam = false
		if self.Rank == 'Developer' or self.Rank == 'Owner' then 
			self.BypassSpam = true
		end	
		self.Created = Utilities.Signal() 
		self.MessageSent = Utilities.Signal()
		self.MessageAttempted = Utilities.Signal()
		self.OnMuted = Utilities.Signal()
		self.OnUnmuted = Utilities.Signal()
		self.MessageLogged = Utilities.Signal()
		self.Created:fire(self)
	end)
	
	function ChatSpeaker:GetChatService()
		return ChatService
	end
	
	function ChatSpeaker:GetName(forcedName)
		if self.Nickname and not forcedName then 
			return self.Nickname
		else
			return self.Name 
		end
	end
	
	function ChatSpeaker:ForceName(name)
		self.Nickname = tostring(name)
	end
	
	function ChatSpeaker:Internal_HandleSpam()
		if not self.player or self.BypassSpam then 
			return true 
		end
		if #self.MessageLog > 1 then 
			local dt = self.MessageLog[#self.MessageLog].Time - self.MessageLog[#self.MessageLog-1].Time
			if dt < SPAM_CONSIDERATION_DELAY then 
				self.PotentialSpamCount = self.PotentialSpamCount + 1 
			else
				self.PotentialSpamCount = 0
			end
			if self.PotentialSpamCount == SPAM_CONSIDERATION_COUNT then 
				ChatService:SendSystemMessage('Stop spamming! You will be muted if you continue to spam.', self.player)
				return false 
			elseif self.PotentialSpamCount > SPAM_CONSIDERATION_COUNT then 
				ChatService:MuteSpeaker(self, self, "~spam", 30)
				return false 
			end
			return true 
		end
		return true 
	end
	
	function ChatSpeaker:LogMessage(msg)
		local date = os.date("*t")
		local messageData = {
			Time = tick(),
			Date = tostring(date.month).."/"..tostring(date.day).."/"..tostring(date.year),
			Message = msg 
		}
		self.MessageLogged:fire(messageData)
		
		table.insert(self.MessageLog, messageData)
	end
	
	function ChatSpeaker:SayMessage(msg)
		self.MessageAttempted:fire()
		self:LogMessage(msg)
		if self:Internal_HandleSpam() then 
			--self.MessageSent:fire()
			ChatService:SendMessage(self, msg)
		end
		return true 
	end
	
	function ChatSpeaker:SendMessage(msg)
		return self:SayMessage(msg)
	end
	
	function ChatSpeaker:Say(msg)
		return self:SendMessage(msg)
	end
	
	function ChatSpeaker:Mention(msg)
		return ChatService:SendSystemMessage('@'..self:GetName()..', '..msg)
	end
	
	function ChatSpeaker:IsMuted()
		return self.Muted 
	end
	
	function ChatSpeaker:IsBot()
		return self.Rank == "Bot"
	end
	
	function ChatSpeaker:Mute(msg)
		self.Muted = true 
		--self.OnMuted:fire(self)
		if self.player and msg then 
			ChatService:SendSystemMessage(msg, self.player)
		end
	end
	
	function ChatSpeaker:Unmute(msg)
		self.Muted = false 
		self.OnUnmuted:fire(self)
		if self.player and msg then 
			ChatService:SendSystemMessage(msg, self.player)
		end
	end
	
	function ChatSpeaker:GetPlayer()
		return self.player
	end
	
	function ChatSpeaker:BindCommand(msg, fn)
		if not self:GetPlayer() then 
			ChatService.BotCommands[msg] = {Bot = self, Fn = fn} 
		end
	end
	
	function ChatSpeaker:Destroy()
		self = nil 
		pcall(function() ChatService.Speakers[self:GetName(true)] = nil end)
	end
	
	function ChatSpeaker:destroy()
		self:Destroy()
	end
	
	return ChatSpeaker
end
