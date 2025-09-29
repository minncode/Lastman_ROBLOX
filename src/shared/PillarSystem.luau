-- 기둥 시스템: 맵의 네 모서리에 황금 기둥을 배치하고 태그 기능 구현
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PillarSystem = {}
PillarSystem.__index = PillarSystem

-- 기둥 설정
local PILLAR_CONFIG = {
    -- 기둥 위치 (맵의 네 모서리)
    POSITIONS = {
        Vector3.new(80, 10, 80),    -- 북동쪽
        Vector3.new(-80, 10, 80),   -- 북서쪽  
        Vector3.new(-80, 10, -80),  -- 남서쪽
        Vector3.new(80, 10, -80)    -- 남동쪽
    },
    
    -- 기둥 외형
    SIZE = Vector3.new(4, 20, 4),
    COLOR = Color3.fromRGB(255, 215, 0),  -- 금색
    MATERIAL = Enum.Material.Neon,
    
    -- 상호작용
    DETECTION_RANGE = 8,         -- 태그 감지 범위
    TAG_COOLDOWN = 1.0,          -- 태그 쿨다운 (초)
    
    -- 이펙트
    TAGGED_COLOR = Color3.fromRGB(0, 255, 0),  -- 태그된 기둥 색상 (초록)
    PARTICLE_COUNT = 50
}

function PillarSystem.new()
    local self = setmetatable({}, PillarSystem)
    
    self.pillars = {}              -- 기둥 객체들
    self.playerTagCooldowns = {}   -- 플레이어별 태그 쿨다운
    self.playerTaggedPillars = {}  -- 플레이어별 태그한 기둥 목록
    
    return self
end

function PillarSystem:createPillars()
    -- 기존 기둥들 제거
    self:destroyPillars()
    
    -- 기둥 폴더 생성
    local pillarsFolder = workspace:FindFirstChild("Pillars")
    if not pillarsFolder then
        pillarsFolder = Instance.new("Folder")
        pillarsFolder.Name = "Pillars"
        pillarsFolder.Parent = workspace
    end
    
    -- 네 개의 기둥 생성
    for i, position in ipairs(PILLAR_CONFIG.POSITIONS) do
        local pillar = self:createSinglePillar(i, position)
        pillar.Parent = pillarsFolder
        table.insert(self.pillars, pillar)
    end
    
    print("기둥 4개 생성 완료")
end

function PillarSystem:createSinglePillar(pillarNumber, position)
    -- 메인 기둥 Part
    local pillar = Instance.new("Part")
    pillar.Name = "Pillar_" .. pillarNumber
    pillar.Size = PILLAR_CONFIG.SIZE
    pillar.Position = position
    pillar.Material = PILLAR_CONFIG.MATERIAL
    pillar.Color = PILLAR_CONFIG.COLOR
    pillar.Anchored = true
    pillar.CanCollide = false
    
    -- 기둥 데이터 저장
    local intValue = Instance.new("IntValue")
    intValue.Name = "PillarNumber"
    intValue.Value = pillarNumber
    intValue.Parent = pillar
    
    local taggedBy = Instance.new("ObjectValue")
    taggedBy.Name = "TaggedBy"
    taggedBy.Parent = pillar
    
    -- 감지 영역 (투명한 Part)
    local detectionZone = Instance.new("Part")
    detectionZone.Name = "DetectionZone"
    detectionZone.Size = Vector3.new(
        PILLAR_CONFIG.DETECTION_RANGE * 2,
        PILLAR_CONFIG.SIZE.Y,
        PILLAR_CONFIG.DETECTION_RANGE * 2
    )
    detectionZone.Position = position
    detectionZone.Transparency = 1
    detectionZone.CanCollide = false
    detectionZone.Anchored = true
    detectionZone.Parent = pillar
    
    -- 파티클 효과 (선택사항)
    self:addPillarEffects(pillar)
    
    -- 터치 감지
    local connection = detectionZone.Touched:Connect(function(hit)
        self:onPillarTouched(pillar, hit)
    end)
    
    -- 연결 저장 (나중에 정리용)
    pillar:SetAttribute("Connection", connection)
    
    return pillar
end

function PillarSystem:addPillarEffects(pillar)
    -- 기둥 주위 파티클 효과
    local attachment = Instance.new("Attachment")
    attachment.Name = "PillarAttachment"
    attachment.Position = Vector3.new(0, PILLAR_CONFIG.SIZE.Y/2, 0)
    attachment.Parent = pillar
    
    -- 황금 반짝임 효과
    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Name = "GoldSparkles"
    sparkles.Parent = attachment
    
    sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkles.Color = ColorSequence.new(PILLAR_CONFIG.COLOR)
    sparkles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0.1)
    }
    sparkles.Lifetime = NumberRange.new(1, 2)
    sparkles.Rate = 20
    sparkles.VelocityInheritance = 0
    sparkles.Speed = NumberRange.new(2, 5)
    sparkles.SpreadAngle = Vector2.new(360, 360)
    
    -- 기둥 빛 효과
    local pointLight = Instance.new("PointLight")
    pointLight.Name = "PillarLight"
    pointLight.Parent = pillar
    pointLight.Color = PILLAR_CONFIG.COLOR
    pointLight.Brightness = 2
    pointLight.Range = 15
end

function PillarSystem:onPillarTouched(pillar, hit)
    -- 플레이어 캐릭터인지 확인
    local character = hit.Parent
    local humanoid = character:FindFirstChild("Humanoid")
    local player = game.Players:GetPlayerFromCharacter(character)
    
    if not humanoid or not player then
        return
    end
    
    local pillarNumber = pillar.PillarNumber.Value
    local currentTime = tick()
    
    -- 쿨다운 체크
    local cooldownKey = player.Name .. "_" .. pillarNumber
    if self.playerTagCooldowns[cooldownKey] and 
       currentTime - self.playerTagCooldowns[cooldownKey] < PILLAR_CONFIG.TAG_COOLDOWN then
        return
    end
    
    -- 이미 이 기둥을 태그했는지 확인
    if not self.playerTaggedPillars[player] then
        self.playerTaggedPillars[player] = {}
    end
    
    if self.playerTaggedPillars[player][pillarNumber] then
        return -- 이미 태그함
    end
    
    -- 기둥 태그!
    self:tagPillar(pillar, player, pillarNumber)
    self.playerTagCooldowns[cooldownKey] = currentTime
end

function PillarSystem:tagPillar(pillar, player, pillarNumber)
    -- 기둥을 태그했다고 표시
    self.playerTaggedPillars[player][pillarNumber] = true
    pillar.TaggedBy.Value = player
    
    -- 기둥 색상 변경 (해당 플레이어에게만 보이게 하려면 클라이언트에서 처리)
    pillar.Color = PILLAR_CONFIG.TAGGED_COLOR
    
    -- 태그 효과
    self:playTagEffect(pillar, player)
    
    -- 서버에 태그 이벤트 전송
    local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
    local playerTagPillar = remoteEvents:WaitForChild("PlayerTagPillar")
    playerTagPillar:FireServer(player, pillarNumber)
    
    print(player.Name .. "이(가) 기둥 " .. pillarNumber .. " 태그!")
end

function PillarSystem:playTagEffect(pillar, player)
    -- 태그 성공 시 이펙트
    
    -- 폭발 파티클
    local attachment = pillar:FindFirstChild("PillarAttachment")
    if attachment then
        local explosion = Instance.new("ParticleEmitter")
        explosion.Name = "TagExplosion"
        explosion.Parent = attachment
        
        explosion.Texture = "rbxasset://textures/particles/fire_main.dds"
        explosion.Color = ColorSequence.new(PILLAR_CONFIG.TAGGED_COLOR)
        explosion.Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 2),
            NumberSequenceKeypoint.new(1, 0)
        }
        explosion.Lifetime = NumberRange.new(0.5, 1)
        explosion.Rate = 100
        explosion.Speed = NumberRange.new(5, 15)
        explosion.SpreadAngle = Vector2.new(360, 360)
        
        -- 일정 시간 후 제거
        explosion:Emit(50)
        game:GetService("Debris"):AddItem(explosion, 2)
    end
    
    -- 소리 효과 (선택사항)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    sound.Volume = 0.5
    sound.Parent = pillar
    sound:Play()
    
    game:GetService("Debris"):AddItem(sound, 3)
end

function PillarSystem:getPlayerTaggedCount(player)
    if not self.playerTaggedPillars[player] then
        return 0
    end
    
    local count = 0
    for pillarNumber, tagged in pairs(self.playerTaggedPillars[player]) do
        if tagged then
            count = count + 1
        end
    end
    
    return count
end

function PillarSystem:resetPlayerProgress(player)
    -- 플레이어 진행도 초기화
    self.playerTaggedPillars[player] = {}
    
    -- 해당 플레이어가 태그한 기둥들 색상 복구
    for _, pillar in ipairs(self.pillars) do
        if pillar.TaggedBy.Value == player then
            pillar.TaggedBy.Value = nil
            pillar.Color = PILLAR_CONFIG.COLOR
        end
    end
end

function PillarSystem:resetAllProgress()
    -- 모든 플레이어 진행도 초기화
    self.playerTaggedPillars = {}
    self.playerTagCooldowns = {}
    
    -- 모든 기둥 색상 복구
    for _, pillar in ipairs(self.pillars) do
        pillar.TaggedBy.Value = nil
        pillar.Color = PILLAR_CONFIG.COLOR
    end
    
    print("모든 기둥 진행도 초기화")
end

function PillarSystem:destroyPillars()
    -- 기존 기둥들 제거
    local pillarsFolder = workspace:FindFirstChild("Pillars")
    if pillarsFolder then
        pillarsFolder:Destroy()
    end
    
    -- 연결 해제
    for _, pillar in ipairs(self.pillars) do
        local connection = pillar:GetAttribute("Connection")
        if connection then
            connection:Disconnect()
        end
    end
    
    self.pillars = {}
    print("기존 기둥들 제거 완료")
end

function PillarSystem:getPillars()
    return self.pillars
end

return PillarSystem