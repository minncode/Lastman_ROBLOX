-- 캐릭터 시스템: 모든 플레이어와 AI가 동일한 외형을 갖도록 관리
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterManager = {}
CharacterManager.__index = CharacterManager

-- 캐릭터 설정
local CHARACTER_CONFIG = {
    -- 기본 이동 속도
    BASE_WALKSPEED = 16,
    RUN_WALKSPEED = 25,
    
    -- 기둥 태그에 따른 속도 감소
    SPEED_REDUCTION_PER_TAG = 0.3, -- 30% 감소
    
    -- 외형 설정 (모든 캐릭터 동일)
    BODY_COLORS = {
        HeadColor3 = Color3.fromRGB(163, 162, 165),
        LeftArmColor3 = Color3.fromRGB(163, 162, 165), 
        LeftLegColor3 = Color3.fromRGB(163, 162, 165),
        RightArmColor3 = Color3.fromRGB(163, 162, 165),
        RightLegColor3 = Color3.fromRGB(163, 162, 165),
        TorsoColor3 = Color3.fromRGB(163, 162, 165)
    },
    
    -- 의상 제거할 클래스들
    REMOVE_ACCESSORIES = {
        "Accessory",
        "Hat", 
        "Shirt",
        "Pants",
        "ShirtGraphic"
    }
}

function CharacterManager.new()
    local self = setmetatable({}, CharacterManager)
    
    -- 플레이어별 데이터 저장
    self.playerData = {}
    
    -- 애니메이션 상태
    self.animations = {}
    
    return self
end

function CharacterManager:setupPlayer(player)
    -- 플레이어 초기 설정
    self.playerData[player] = {
        pillarsTouched = 0,      -- 태그한 기둥 수
        isRunning = false,       -- 달리기 상태
        isCrouching = false,     -- 앉기 상태
        canPunch = true,         -- 펀치 가능 여부
        lastPunchTime = 0        -- 마지막 펀치 시간
    }
    
    -- 캐릭터 스폰 시 설정 적용
    player.CharacterAdded:Connect(function(character)
        self:setupCharacter(character, player)
    end)
    
    -- 이미 캐릭터가 있다면 바로 적용
    if player.Character then
        self:setupCharacter(player.Character, player)
    end
end

function CharacterManager:setupCharacter(character, player)
    -- Humanoid 설정 대기
    local humanoid = character:WaitForChild("Humanoid")
    
    -- 기본 설정 적용
    self:applyCharacterAppearance(character)
    self:setupMovement(character, player)
    self:setupAnimations(character)
    
    print("캐릭터 설정 완료:", player and player.Name or "AI")
end

function CharacterManager:applyCharacterAppearance(character)
    -- 모든 액세서리 제거
    for _, item in pairs(character:GetChildren()) do
        for _, className in pairs(CHARACTER_CONFIG.REMOVE_ACCESSORIES) do
            if item:IsA(className) then
                item:Destroy()
            end
        end
    end
    
    -- 신체 색상 통일
    local bodyColors = character:FindFirstChild("Body Colors")
    if bodyColors then
        for property, color in pairs(CHARACTER_CONFIG.BODY_COLORS) do
            bodyColors[property] = color
        end
    else
        -- Body Colors가 없으면 생성
        bodyColors = Instance.new("BodyColors")
        bodyColors.Parent = character
        for property, color in pairs(CHARACTER_CONFIG.BODY_COLORS) do
            bodyColors[property] = color
        end
    end
    
    -- 머리 얼굴 제거 (선택사항)
    local head = character:FindFirstChild("Head")
    if head then
        local face = head:FindFirstChild("face")
        if face then
            face:Destroy()
        end
    end
    
    print("캐릭터 외형 통일 완료")
end

function CharacterManager:setupMovement(character, player)
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- 기본 이동 속도 설정
    humanoid.WalkSpeed = CHARACTER_CONFIG.BASE_WALKSPEED
    
    -- 플레이어별 데이터 초기화
    if player and self.playerData[player] then
        self.playerData[player].pillarsTouched = 0
        self:updatePlayerSpeed(player)
    end
end

function CharacterManager:setupAnimations(character)
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- 기본 애니메이션 로드
    local animationIds = {
        idle = "rbxasset://animations/idle.xml",
        walk = "rbxasset://animations/walk.xml", 
        run = "rbxasset://animations/run.xml",
        jump = "rbxasset://animations/jump.xml"
    }
    
    self.animations[character] = {}
    
    for animName, animId in pairs(animationIds) do
        local animation = Instance.new("Animation")
        animation.AnimationId = animId
        
        local animTrack = humanoid:LoadAnimation(animation)
        self.animations[character][animName] = animTrack
    end
end

function CharacterManager:handleInput(player, input)
    if not self.playerData[player] then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local playerData = self.playerData[player]
    
    -- 달리기 (Shift)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        if input.UserInputState == Enum.UserInputState.Begin then
            playerData.isRunning = true
        elseif input.UserInputState == Enum.UserInputState.End then
            playerData.isRunning = false
        end
        self:updatePlayerSpeed(player)
        
    -- 앉기 (Ctrl 또는 C)
    elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
        if input.UserInputState == Enum.UserInputState.Begin then
            self:toggleCrouch(player)
        end
        
    -- 펀치 (마우스 클릭)
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        if input.UserInputState == Enum.UserInputState.Begin then
            self:performPunch(player)
        end
    end
end

function CharacterManager:updatePlayerSpeed(player)
    if not self.playerData[player] then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local playerData = self.playerData[player]
    local baseSpeed = CHARACTER_CONFIG.BASE_WALKSPEED
    
    -- 달리기 속도 적용
    if playerData.isRunning then
        baseSpeed = CHARACTER_CONFIG.RUN_WALKSPEED
    end
    
    -- 기둥 태그에 따른 속도 감소 적용
    local speedReduction = playerData.pillarsTouched * CHARACTER_CONFIG.SPEED_REDUCTION_PER_TAG
    local finalSpeed = baseSpeed * (1 - speedReduction)
    
    -- 최소 속도 보장 (완전히 멈추지 않게)
    finalSpeed = math.max(finalSpeed, 2)
    
    humanoid.WalkSpeed = finalSpeed
    
    print(player.Name .. " 속도 업데이트:", finalSpeed, "(기둥:", playerData.pillarsTouched .. "개)")
end

function CharacterManager:toggleCrouch(player)
    if not self.playerData[player] then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local playerData = self.playerData[player]
    playerData.isCrouching = not playerData.isCrouching
    
    if playerData.isCrouching then
        -- 앉기 상태
        humanoid.WalkSpeed = humanoid.WalkSpeed * 0.3  -- 30% 속도로 감소
        humanoid.HipHeight = -1.5  -- 낮은 자세
        print(player.Name .. " 앉기")
    else
        -- 일어서기
        self:updatePlayerSpeed(player)  -- 원래 속도로 복구
        humanoid.HipHeight = 0  -- 일반 자세
        print(player.Name .. " 일어서기")
    end
end

function CharacterManager:performPunch(player)
    if not self.playerData[player] then return end
    
    local playerData = self.playerData[player]
    local currentTime = tick()
    
    -- 펀치 쿨다운 체크 (0.5초)
    if not playerData.canPunch or currentTime - playerData.lastPunchTime < 0.5 then
        return
    end
    
    playerData.canPunch = false
    playerData.lastPunchTime = currentTime
    
    -- 펀치 애니메이션 및 로직
    self:executePunch(player)
    
    -- 쿨다운 후 다시 펀치 가능
    spawn(function()
        wait(0.5)
        playerData.canPunch = true
    end)
end

function CharacterManager:executePunch(player)
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- 펀치 사거리 체크 (앞쪽 5 유닛)
    local rayOrigin = humanoidRootPart.Position
    local rayDirection = humanoidRootPart.CFrame.LookVector * 5
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {character}
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if raycastResult and raycastResult.Instance then
        local hitPart = raycastResult.Instance
        local hitCharacter = hitPart.Parent
        
        -- 다른 캐릭터를 맞혔는지 확인
        local hitHumanoid = hitCharacter:FindFirstChild("Humanoid")
        if hitHumanoid and hitCharacter ~= character then
            self:onPunchHit(player, hitCharacter)
        end
    end
    
    print(player.Name .. " 펀치!")
end

function CharacterManager:onPunchHit(attacker, targetCharacter)
    -- 펀치가 맞았을 때 처리
    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    
    if targetPlayer then
        print(attacker.Name .. "이(가) " .. targetPlayer.Name .. "을(를) 공격!")
        -- RemoteEvent를 통해 서버에 공격 알림
        local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
        local playerPunch = remoteEvents:WaitForChild("PlayerPunch")
        playerPunch:FireServer(targetPlayer)
    else
        -- AI를 공격한 경우
        print(attacker.Name .. "이(가) AI를 공격!")
        -- AI 제거 로직 (나중에 구현)
    end
end

function CharacterManager:onPillarTagged(player)
    -- 기둥을 태그했을 때 호출
    if not self.playerData[player] then return end
    
    local playerData = self.playerData[player]
    playerData.pillarsTouched = playerData.pillarsTouched + 1
    
    print(player.Name .. " 기둥 태그! 총 " .. playerData.pillarsTouched .. "개")
    
    -- 속도 업데이트
    self:updatePlayerSpeed(player)
    
    -- 3개 태그 시 달리기 불가 처리
    if playerData.pillarsTouched >= 3 then
        playerData.isRunning = false
        print(player.Name .. " 달리기 불가!")
    end
    
    -- 서버에 기둥 태그 알림
    local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
    local playerTagPillar = remoteEvents:WaitForChild("PlayerTagPillar")
    playerTagPillar:FireServer(player, playerData.pillarsTouched)
end

function CharacterManager:createAICharacter(name, position)
    -- AI 캐릭터 생성
    local aiModel = Instance.new("Model")
    aiModel.Name = name
    aiModel.Parent = workspace
    
    -- 기본 Humanoid 캐릭터 구조 생성
    local humanoidRootPart = Instance.new("Part")
    humanoidRootPart.Name = "HumanoidRootPart"
    humanoidRootPart.Size = Vector3.new(2, 2, 1)
    humanoidRootPart.Position = position
    humanoidRootPart.CanCollide = false
    humanoidRootPart.Parent = aiModel
    
    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = aiModel
    
    -- R6 캐릭터 부위들 생성 (간단한 버전)
    self:createR6Parts(aiModel, humanoidRootPart)
    
    -- 동일한 외형 적용
    self:applyCharacterAppearance(aiModel)
    
    return aiModel
end

function CharacterManager:createR6Parts(character, rootPart)
    -- R6 캐릭터의 기본 부위들 생성
    local parts = {
        {name = "Head", size = Vector3.new(2, 1, 1), offset = Vector3.new(0, 1.5, 0)},
        {name = "Torso", size = Vector3.new(2, 2, 1), offset = Vector3.new(0, 0, 0)},
        {name = "Left Arm", size = Vector3.new(1, 2, 1), offset = Vector3.new(-1.5, 0, 0)}, 
        {name = "Right Arm", size = Vector3.new(1, 2, 1), offset = Vector3.new(1.5, 0, 0)},
        {name = "Left Leg", size = Vector3.new(1, 2, 1), offset = Vector3.new(-0.5, -2, 0)},
        {name = "Right Leg", size = Vector3.new(1, 2, 1), offset = Vector3.new(0.5, -2, 0)}
    }
    
    for _, partInfo in ipairs(parts) do
        local part = Instance.new("Part")
        part.Name = partInfo.name
        part.Size = partInfo.size
        part.Position = rootPart.Position + partInfo.offset
        part.Parent = character
        
        -- 관절 연결 (기본적인 Motor6D)
        if partInfo.name ~= "Torso" then
            local motor = Instance.new("Motor6D")
            motor.Name = partInfo.name:gsub(" ", "")
            motor.Part0 = character:FindFirstChild("Torso") or rootPart
            motor.Part1 = part
            motor.Parent = motor.Part0
        end
    end
end

function CharacterManager:getPlayerData(player)
    return self.playerData[player]
end

function CharacterManager:resetPlayerData(player)
    if self.playerData[player] then
        self.playerData[player] = {
            pillarsTouched = 0,
            isRunning = false,
            isCrouching = false,
            canPunch = true,
            lastPunchTime = 0
        }
    end
end

return CharacterManager