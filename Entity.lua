--[[
	Entity script by script_ing.
	See Types script for optional parameters
]]

local PathfindingService = game:GetService('PathfindingService')
local Types = require(script.Parent.Types)
local EntityAnimations = require(script.EntityAnimations)

local PATHFINDING_DEBUG = false 

return function(_f : Types.SFramework)
	local Utilities : Types.Utilities = _f.Utilities 
	local Entity = Utilities.class({}, function(self)
		assert(self.obj, `Entity didn't receive a valid object!`)
		
		self.name = self.obj.Name 
		self.hrp = self.obj:FindFirstChild("HumanoidRootPart")
		self.animations = {}
		self.currentAnimationName = ""
		
		self.humanoid = self.obj:FindFirstChildOfClass("Humanoid")

		if not self.humanoid then 
			self.humanoid = Instance.new("Humanoid", self.obj)
 
			if self.health then 
				self.humanoid.Health = self.health 
			end

			if self.maxHealth then 
				self.humanoid.MaxHealth = self.maxHealth 
			end

			if self.walkSpeed then 
				self.humanoid.WalkSpeed = self.walkSpeed 
			end
		end
		
		local animations = EntityAnimations[self.name]
		
		for animationName, animationId in next, animations do 
			self.animations[animationName] = self.humanoid:LoadAnimation(
				Utilities.Create("Animation"){
					AnimationId = `rbxassetid://{animationId}`,
					Name = animationName,
				}
			)
		end
		
		-- Load Animations 

		self:PlayAnimation("Idle")
		
		return self 
	end)
	
	function Entity:PlayAnimation(animationName : string)
		--pcall(function()
		--	if self.currentAnimationName ~= 'Idle' then 
		--		self.animations[self.currentAnimationName]:Stop()
		--	end
		--end)
		
		self:StopNonIdleAnimations()
		
		if self.animations[animationName] then 
			self.currentAnimationName = animationName
			self.animations[animationName]:Play()
		end
	end
	
	function Entity:StopNonIdleAnimations()
		local playingTracks = self.humanoid:GetPlayingAnimationTracks()
		for i, v in next, playingTracks do 
			if v.Name ~= 'Idle' then 
				v:Stop()
			end
		end
	end
	
	function Entity:SetAnimationSpeed(animationName, speed : number)
		if self.animations[animationName] then 
			self.animations[animationName]:AdjustSpeed(speed)
		end
	end
	
	function Entity:GetSize()
		return self.obj:GetExtentsSize()
	end
	
	function Entity:CalculateAgentHeightAndRadius()
		return self:GetSize().Y + 2, math.max(self:GetSize().X, self:GetSize().Z) + 2
	end
	
	function Entity:GetPathToPosition(pos : Vector3)
		local agentHeight, agentRadius = self:CalculateAgentHeightAndRadius()
		local path = PathfindingService:CreatePath({
			AgentRadius = agentRadius,
			AgentHeight = agentHeight,
			AgentCanJump = self.canJump,
			AgentCanClimb = false,
			WaypointSpacing = 2,
			Costs = self.pathfindingCosts or {
				Water = math.huge
			}
		})

		local startPosition = self.hrp.Position

		local success, errorMessage = pcall(function()
			path:ComputeAsync(startPosition, pos)
		end)
		
		if success and path.Status == Enum.PathStatus.Success then
			return path 
		end
		
		return nil 
	end
	
	function Entity:WalkTo(pos: Vector3)
		self:StopWalking()
		
		local path : Path = self:GetPathToPosition(pos)
		
		self.canWalk = true 
		self.walkToPosition = pos 
		
		-- For each waypoint, create a part to visualize the path

		if PATHFINDING_DEBUG then 
			for _, waypoint in path:GetWaypoints() do
				local part = Instance.new("Part")
				part.Position = waypoint.Position
				part.Size = Vector3.new(0.5, 0.5, 0.5)
				part.Color = Color3.new(1, 0, 1)
				part.Anchored = true
				part.CanCollide = false
				part.Parent = workspace
				
				if waypoint.Action == Enum.PathWaypointAction.Jump then 
					part.Color = Color3.new(1, 0, 0)
				end
			end
		end
		
		self:PlayAnimation("Walk")
		
		for _, waypoint in path:GetWaypoints() do
			if not self.canWalk then 
				break 
			end
			if self.walkToPosition ~= pos then 
				break 
			end
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.humanoid.Jump = true
			end
			self.humanoid:MoveTo(waypoint.Position)
			self.humanoid.MoveToFinished:Wait()
		end
		
		self:StopNonIdleAnimations()
	end
	
	function Entity:StopWalking()
		self.canWalk = false 
	end
	
	function Entity:GetPosition()
		return self.obj.PrimaryPart.Position
	end
	
	return Entity
end
