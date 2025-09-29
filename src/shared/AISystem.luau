-- AI 시스템: 부자연스러운 움직임 패턴으로 플레이어와 구별되는 AI 구현
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISystem = {}
AISystem.__index = AISystem

-- AI 설정
local AI_CONFIG = {
    -- 이동 패턴
    MOVEMENT_PATTERNS = {
        STOP_AND_TURN = 0.7,      -- 70% 확률로 멈췄다가 방향 전환
        RANDOM_WALK = 0.2,        -- 20% 확률로 랜덤 워크
        FOLLOW_PLAYER = 0.1       -- 10% 확률로 플레이어 따라가기
    },
    
    -- 타이밍 설정  
    MIN_STOP_TIME = 0.5,         -- 최소 멈춤 시간
    MAX_STOP_TIME = 2.0,         -- 최대 멈춤 시간
    MIN_MOVE_TIME = 1.0,         -- 최소 이동 시간  
    MAX_MOVE_TIME = 3.0,         -- 최대 이동 시간
    
    -- 이동 설정
    WALK_SPEED = 14,             -- AI 걷기 속도 (플레이어보다 약간 느림)
    DETECTION_RANGE = 30,        -- 플레이어 감지 범위
    PUNCH_RANGE = 5,             -- 펀치 사거리
    PUNCH_COOLDOWN = 1.0,        -- 펀치 쿨다운
    
    -- 행동 확률
    PUNCH_PROBABILITY = 0.3,     -- 근처에 다른 캐릭터 있을 때 공격 확률
    PILLAR_INTEREST = 0.1        -- 기둥에 관심 보일 확률 (낮음)
}

function AISystem.new(characterManager)
    local self = setmetatable({}, AISystem)
    
    self.characterManager = characterManager
    self.aiCharacters = {}
    self.connections = {}
    
    return self
end

function AISystem:createAI(name, position)
    -- AI 캐릭터 생성
    local aiCharacter = self.characterManager:createAICharacter(name, position)
    
    local aiData = {
        character = aiCharacter,
        name = name,
        isAlive = true,
        
        -- 상태 관리
        state = "idle",              -- idle, moving, stopped, attacking
        stateStartTime = tick(),
        nextStateChange = 0,
        
        -- 이동 관련
        targetPosition = nil,
        currentDirection = Vector3.new(0, 0, 0),
        lastPosition = position,
        
        -- 행동 패턴
        movementPattern = "STOP_AND_TURN",
        lastPatternChange = tick(),
        
        -- 전투 관련
        lastPunchTime = 0,
        targetEnemy = nil,
        
        -- 기둥 관련
        pillarsTouched = 0,
        lastPillarTime = 0
    }
    
    -- 초기 패턴 설정
    aiData.movementPattern = self:selectRandomPattern()
    aiData.nextStateChange = tick() + math.random() * 2
    
    table.insert(self.aiCharacters, aiData)
    
    -- AI 업데이트 루프 시작
    local connection = RunService.Heartbeat:Connect(function()
        self:updateAI(aiData)
    end)
    
    self.connections[aiData] = connection
    
    print("AI 생성:", name, "패턴:", aiData.movementPattern)
    return aiData
end

function AISystem:selectRandomPattern()
    local rand = math.random()
    local cumulative = 0
    
    for pattern, probability in pairs(AI_CONFIG.MOVEMENT_PATTERNS) do
        cumulative = cumulative + probability
        if rand <= cumulative then
            return pattern
        end
    end
    
    return "STOP_AND_TURN" -- 기본값
end

function AISystem:updateAI(aiData)
    if not aiData.isAlive or not aiData.character then
        return
    end
    
    local humanoid = aiData.character:FindFirstChild("Humanoid")
    local rootPart = aiData.character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then
        return
    end
    
    local currentTime = tick()
    
    -- 주기적으로 패턴 변경 (30-60초마다)
    if currentTime - aiData.lastPatternChange > math.random(30, 60) then
        aiData.movementPattern = self:selectRandomPattern()
        aiData.lastPatternChange = currentTime
        print(aiData.name .. " 패턴 변경:", aiData.movementPattern)
    end
    
    -- 상태별 행동 처리
    if aiData.movementPattern == "STOP_AND_TURN" then
        self:handleStopAndTurn(aiData, humanoid, rootPart, currentTime)
    elseif aiData.movementPattern == "RANDOM_WALK" then
        self:handleRandomWalk(aiData, humanoid, rootPart, currentTime)
    elseif aiData.movementPattern == "FOLLOW_PLAYER" then
        self:handleFollowPlayer(aiData, humanoid, rootPart, currentTime)
    end
    
    -- 전투 체크
    self:checkCombat(aiData, rootPart, currentTime)
end

function AISystem:handleStopAndTurn(aiData, humanoid, rootPart, currentTime)
    -- 멈췄다가 방향 전환하는 패턴 (가장 부자연스러운 패턴)
    
    if currentTime >= aiData.nextStateChange then
        if aiData.state == "moving" then
            -- 이동 중 -> 멈춤
            aiData.state = "stopped"
            humanoid:MoveTo(rootPart.Position) -- 제자리에서 멈춤
            aiData.nextStateChange = currentTime + math.random() * 
                (AI_CONFIG.MAX_STOP_TIME - AI_CONFIG.MIN_STOP_TIME) + AI_CONFIG.MIN_STOP_TIME
            
        elseif aiData.state == "stopped" or aiData.state == "idle" then
            -- 멈춤 -> 새로운 방향으로 이동
            aiData.state = "moving"
            
            -- 랜덤 방향 선택 (90도 단위로 회전하여 부자연스럽게)
            local angles = {0, 90, 180, 270}
            local randomAngle = angles[math.random(#angles)]
            local radians = math.rad(randomAngle)
            
            local direction = Vector3.new(math.cos(radians), 0, math.sin(radians))
            local distance = math.random(10, 25)
            local targetPos = rootPart.Position + (direction * distance)
            
            -- 맵 경계 체크
            targetPos = self:clampToMap(targetPos)
            
            humanoid:MoveTo(targetPos)
            aiData.targetPosition = targetPos
            aiData.nextStateChange = currentTime + math.random() * 
                (AI_CONFIG.MAX_MOVE_TIME - AI_CONFIG.MIN_MOVE_TIME) + AI_CONFIG.MIN_MOVE_TIME
        end
    end
    
    -- 목적지에 도달했는지 체크
    if aiData.state == "moving" and aiData.targetPosition then
        local distance = (rootPart.Position - aiData.targetPosition).Magnitude
        if distance < 3 then
            aiData.state = "stopped"
            aiData.nextStateChange = currentTime + math.random() * 
                (AI_CONFIG.MAX_STOP_TIME - AI_CONFIG.MIN_STOP_TIME) + AI_CONFIG.MIN_STOP_TIME
        end
    end
end

function AISystem:handleRandomWalk(aiData, humanoid, rootPart, currentTime)
    -- 조금 더 자연스러운 랜덤 워크 패턴
    
    if currentTime >= aiData.nextStateChange or not aiData.targetPosition then
        -- 새로운 목적지 선택
        local angle = math.random() * 2 * math.pi
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local distance = math.random(8, 20)
        local targetPos = rootPart.Position + (direction * distance)
        
        targetPos = self:clampToMap(targetPos)
        
        humanoid:MoveTo(targetPos)
        aiData.targetPosition = targetPos
        aiData.state = "moving"
        aiData.nextStateChange = currentTime + math.random(2, 5)
    end
end

function AISystem:handleFollowPlayer(aiData, humanoid, rootPart, currentTime)
    -- 가까운 플레이어를 따라가는 패턴
    
    local nearestPlayer = self:findNearestPlayer(rootPart.Position)
    
    if nearestPlayer and nearestPlayer.Character then
        local targetRootPart = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if targetRootPart then
            local distance = (rootPart.Position - targetRootPart.Position).Magnitude
            
            if distance > 15 then
                -- 너무 멀면 따라가기
                humanoid:MoveTo(targetRootPart.Position)
                aiData.state = "following"
            elseif distance < 5 then
                -- 너무 가까우면 멈춤
                humanoid:MoveTo(rootPart.Position)
                aiData.state = "stopped"
            end
        end
    else
        -- 플레이어가 없으면 랜덤 워크로 전환
        self:handleRandomWalk(aiData, humanoid, rootPart, currentTime)
    end
end

function AISystem:checkCombat(aiData, rootPart, currentTime)
    -- 전투 가능 상태 체크
    if currentTime - aiData.lastPunchTime < AI_CONFIG.PUNCH_COOLDOWN then
        return
    end
    
    -- 주변 캐릭터 탐지
    local nearbyTargets = self:findNearbyTargets(rootPart.Position, AI_CONFIG.PUNCH_RANGE)
    
    if #nearbyTargets > 0 and math.random() < AI_CONFIG.PUNCH_PROBABILITY then
        local target = nearbyTargets[math.random(#nearbyTargets)]
        self:performAIPunch(aiData, target)
    end
end

function AISystem:findNearbyTargets(position, range)
    local targets = {}
    
    -- 플레이어들 체크
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
            if distance <= range then
                table.insert(targets, {type = "player", entity = player, character = player.Character})
            end
        end
    end
    
    -- 다른 AI들 체크
    for _, otherAI in ipairs(self.aiCharacters) do
        if otherAI.isAlive and otherAI.character and otherAI.character:FindFirstChild("HumanoidRootPart") then
            local distance = (otherAI.character.HumanoidRootPart.Position - position).Magnitude
            if distance <= range then
                table.insert(targets, {type = "ai", entity = otherAI, character = otherAI.character})
            end
        end
    end
    
    return targets
end

function AISystem:findNearestPlayer(position)
    local nearestPlayer = nil
    local nearestDistance = math.huge
    
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = player
            end
        end
    end
    
    return nearestPlayer
end

function AISystem:performAIPunch(aiData, target)
    aiData.lastPunchTime = tick()
    
    print(aiData.name .. "이(가) 공격!", target.type)
    
    -- 공격 로직
    if target.type == "player" then
        -- 플레이어 공격 - 서버에 알림
        -- RemoteEvent 처리 필요
        self:eliminateTarget(target.entity, "AI에게 공격받음")
    elseif target.type == "ai" then
        -- 다른 AI 공격
        self:eliminateAI(target.entity, "다른 AI에게 공격받음")
    end
end

function AISystem:eliminateAI(aiData, reason)
    aiData.isAlive = false
    
    if aiData.character then
        aiData.character:Destroy()
    end
    
    -- 연결 해제
    if self.connections[aiData] then
        self.connections[aiData]:Disconnect()
        self.connections[aiData] = nil
    end
    
    print("AI 제거:", aiData.name, "이유:", reason)
end

function AISystem:eliminateTarget(player, reason)
    -- 플레이어 제거는 GameManager를 통해 처리
    print("플레이어 제거 요청:", player.Name, "이유:", reason)
    -- 이후 GameManager에서 처리하도록 이벤트 발생
end

function AISystem:clampToMap(position)
    -- 맵 경계 내로 제한 (기본 맵 크기 256x256 가정)
    local maxX, maxZ = 100, 100
    
    position = Vector3.new(
        math.clamp(position.X, -maxX, maxX),
        position.Y,
        math.clamp(position.Z, -maxZ, maxZ)
    )
    
    return position
end

function AISystem:getAllAliveAI()
    local aliveAI = {}
    
    for _, aiData in ipairs(self.aiCharacters) do
        if aiData.isAlive then
            table.insert(aliveAI, aiData)
        end
    end
    
    return aliveAI
end

function AISystem:destroyAllAI()
    for _, aiData in ipairs(self.aiCharacters) do
        if aiData.character then
            aiData.character:Destroy()
        end
        
        if self.connections[aiData] then
            self.connections[aiData]:Disconnect()
        end
    end
    
    self.aiCharacters = {}
    self.connections = {}
    
    print("모든 AI 제거 완료")
end

return AISystem