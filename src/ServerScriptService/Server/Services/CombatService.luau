--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		AttackResult = Knit.CreateSignal(),
	},
})

local _lastAttackTime: { [Player]: number } = {}

local GameService: any
local EnemyService: any

function CombatService.Client:Attack(player: Player)
	self.Server:_processAttack(player)
end

function CombatService:_processAttack(player: Player)
	local now = tick()
	local weapon = GameConfig.Weapons.Sword
	local lastAttack = _lastAttackTime[player] or 0

	if (now - lastAttack) < weapon.SwingCooldown then
		return
	end
	_lastAttackTime[player] = now

	local char = player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local stats = GameService:GetPlayerStats(player)
	if not stats or stats.Health <= 0 then
		return
	end

	local position = root.Position
	local lookDir = root.CFrame.LookVector
	local damage = math.floor(weapon.Damage * stats.DamageMultiplier)

	-- Find enemies in range and arc
	local enemies = EnemyService:GetEnemiesInRadius(position, weapon.Range)
	local hitCount = 0
	local arcRad = math.rad(weapon.ArcAngle / 2)

	for _, enemy in enemies do
		if not enemy.Alive or not enemy.Model.PrimaryPart then
			continue
		end

		local toEnemy = (enemy.Model.PrimaryPart.Position - position).Unit
		local dot = lookDir:Dot(toEnemy)
		local angle = math.acos(math.clamp(dot, -1, 1))

		if angle <= arcRad then
			EnemyService:DamageEnemy(enemy, damage, player)
			hitCount += 1

			-- Knockback
			local body = enemy.Model.PrimaryPart
			local knockDir = (body.Position - position).Unit
			local knockback = Instance.new("VectorForce")
			knockback.Force = knockDir * weapon.KnockbackForce * body:GetMass()

			local att = body:FindFirstChild("MoveAttachment") :: Attachment?
			if att then
				knockback.Attachment0 = att
				knockback.Parent = body
				task.delay(0.15, function()
					knockback:Destroy()
				end)
			else
				knockback:Destroy()
			end
		end
	end

	-- Notify client of attack result
	self.Client.AttackResult:Fire(player, hitCount, position, lookDir)
end

function CombatService:KnitInit()
	Players.PlayerRemoving:Connect(function(player: Player)
		_lastAttackTime[player] = nil
	end)
end

function CombatService:KnitStart()
	GameService = Knit.GetService("GameService")
	EnemyService = Knit.GetService("EnemyService")
end

return CombatService
