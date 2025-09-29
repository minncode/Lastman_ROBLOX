-- 게임 매니저: Last Man Standing 게임의 전체 상태와 로직을 관리
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameManager = {}
GameManager.__index = GameManager

-- 게임 상태 열거형
local GameState = {
    WAITING = "WAITING",       -- 플레이어 대기 중
    STARTING = "STARTING",     -- 게임 시작 중 (카운트다운)
    PLAYING = "PLAYING",       -- 게임 진행 중
    ENDING = "ENDING"          -- 게임 종료 중
}

-- 게임 설정
local GAME_CONFIG = {
    MIN_PLAYERS = 2,           -- 게임 시작 최소 플레이어 수
    MAX_PLAYERS = 10,          -- 최대 플레이어 수
    AI_COUNT = 8,              -- AI 개수
    START_COUNTDOWN = 10,      -- 게임 시작 카운트다운 (초)
    ROUND_TIME = 300,          -- 라운드 제한 시간 (초)
    RESPAWN_TIME = 5           -- 다음 라운드까지 대기 시간
}

function GameManager.new()
    local self = setmetatable({}, GameManager)
    
    -- 의존성 로드
    local CharacterManager = require(ReplicatedStorage.Shared.CharacterManager)
    local AISystem = require(ReplicatedStorage.Shared.AISystem)
    local PillarSystem = require(ReplicatedStorage.Shared.PillarSystem)
    
    -- 매니저 인스턴스 생성
    self.characterManager = CharacterManager.new()
    self.aiSystem = AISystem.new(self.characterManager)
    self.pillarSystem = PillarSystem.new()
    
    -- 게임 상태
    self.gameState = GameState.WAITING
    self.players = {}           -- 살아있는 플레이어 목록
    self.deadPlayers = {}       -- 죽은 플레이어 목록  
    self.aiCharacters = {}      -- AI 캐릭터 목록
    self.roundStartTime = 0     -- 라운드 시작 시간
    self.gameStartTime = 0      -- 게임 시작 시간
    
    -- 이벤트
    self.gameStateChanged = Instance.new("BindableEvent")
    self.playerEliminated = Instance.new("BindableEvent")
    self.gameEnded = Instance.new("BindableEvent")
    
    -- 플레이어 연결/해제 이벤트 연결
    Players.PlayerAdded:Connect(function(player)
        self:onPlayerJoined(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:onPlayerLeft(player)
    end)
    
    return self
end

function GameManager:onPlayerJoined(player)
    print("플레이어 참가:", player.Name)
    
    -- 캐릭터 매니저에 플레이어 등록
    self.characterManager:setupPlayer(player)
    
    -- 게임이 진행 중이 아니면 플레이어 목록에 추가
    if self.gameState == GameState.WAITING then
        table.insert(self.players, player)
        
        -- 최소 플레이어 수에 도달했으면 게임 시작 체크
        if #self.players >= GAME_CONFIG.MIN_PLAYERS then
            self:startGameCountdown()
        end
    else
        -- 게임 진행 중이면 관전자로 설정
        self:setPlayerAsSpectator(player)
    end
end

function GameManager:onPlayerLeft(player)
    print("플레이어 떠남:", player.Name)
    
    -- 플레이어 목록에서 제거
    for i, p in ipairs(self.players) do
        if p == player then
            table.remove(self.players, i)
            break
        end
    end
    
    -- 죽은 플레이어 목록에서도 제거
    for i, p in ipairs(self.deadPlayers) do
        if p == player then
            table.remove(self.deadPlayers, i)
            break
        end
    end
    
    -- 게임 중일 때 플레이어가 너무 적어지면 게임 종료
    if self.gameState == GameState.PLAYING and #self.players < 2 then
        self:endGame("플레이어 부족으로 게임이 종료되었습니다.")
    end
end

function GameManager:startGameCountdown()
    if self.gameState ~= GameState.WAITING then
        return
    end
    
    self.gameState = GameState.STARTING
    self.gameStateChanged:Fire(self.gameState)
    
    print("게임 시작 카운트다운:", GAME_CONFIG.START_COUNTDOWN, "초")
    
    -- 카운트다운
    for i = GAME_CONFIG.START_COUNTDOWN, 1, -1 do
        -- 플레이어가 부족하면 카운트다운 중단
        if #self.players < GAME_CONFIG.MIN_PLAYERS then
            self.gameState = GameState.WAITING
            self.gameStateChanged:Fire(self.gameState)
            print("플레이어 부족으로 게임 시작이 취소되었습니다.")
            return
        end
        
        print("게임 시작까지:", i, "초")
        wait(1)
    end
    
    self:startGame()
end

function GameManager:startGame()
    if self.gameState ~= GameState.STARTING then
        return
    end
    
    self.gameState = GameState.PLAYING
    self.gameStartTime = tick()
    self.deadPlayers = {}
    
    print("게임 시작! 플레이어 수:", #self.players)
    
    -- 기둥 시스템 초기화
    self.pillarSystem:createPillars()
    self.pillarSystem:resetAllProgress()
    
    -- 기둥 생성
    self.pillarSystem:createPillars()
    
    -- AI 생성
    self:spawnAI()
    
    -- 플레이어와 AI 스폰
    self:spawnAllCharacters()
    
    self.gameStateChanged:Fire(self.gameState)
    
    -- 게임 시간 제한 체크 시작
    spawn(function()
        self:checkGameTimer()
    end)
end

function GameManager:spawnAI()
    -- 기존 AI 제거
    self.aiSystem:destroyAllAI()
    self.aiCharacters = {}
    
    -- 새로운 AI 캐릭터들 생성
    local spawnPositions = self:generateAISpawnPositions()
    
    for i = 1, GAME_CONFIG.AI_COUNT do
        local position = spawnPositions[i] or Vector3.new(0, 5, 0)
        local aiData = self.aiSystem:createAI("AI_" .. i, position)
        table.insert(self.aiCharacters, aiData)
    end
    
    print("AI 캐릭터 생성 완료:", #self.aiCharacters, "개")
end

function GameManager:generateAISpawnPositions()
    -- AI 전용 스폰 위치 생성 (플레이어와 섞일 예정)
    local positions = {}
    local aiCount = GAME_CONFIG.AI_COUNT
    local radius = math.max(15, aiCount * 2)
    
    for i = 1, aiCount do
        local angle = (i - 1) * (2 * math.pi / aiCount)
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius
        
        table.insert(positions, Vector3.new(x, 5, z))
    end
    
    return positions
end

function GameManager:spawnAllCharacters()
    -- 플레이어와 AI를 모두 동일한 외형으로 스폰
    print("모든 캐릭터 스폰 중...")
    
    -- 스폰 위치들 (원형으로 배치)
    local spawnPositions = self:generateSpawnPositions()
    local allEntities = {}
    
    -- 플레이어들 추가
    for _, player in ipairs(self.players) do
        table.insert(allEntities, {type = "player", entity = player})
    end
    
    -- AI들 추가  
    for _, ai in ipairs(self.aiCharacters) do
        table.insert(allEntities, {type = "ai", entity = ai})
    end
    
    -- 위치 섞기
    for i = #allEntities, 2, -1 do
        local j = math.random(i)
        allEntities[i], allEntities[j] = allEntities[j], allEntities[i]
    end
    
    -- 각 엔티티를 랜덤 위치에 스폰
    for i, entityData in ipairs(allEntities) do
        if i <= #spawnPositions then
            self:spawnEntity(entityData, spawnPositions[i])
        end
    end
end

function GameManager:generateSpawnPositions()
    -- 원형으로 스폰 위치 생성
    local positions = {}
    local totalEntities = #self.players + #self.aiCharacters
    local radius = math.max(20, totalEntities * 3) -- 반지름 조정
    
    for i = 1, totalEntities do
        local angle = (i - 1) * (2 * math.pi / totalEntities)
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius
        
        table.insert(positions, Vector3.new(x, 5, z))
    end
    
    return positions
end

function GameManager:spawnEntity(entityData, position)
    -- 엔티티 스폰 로직 (플레이어 또는 AI)
    if entityData.type == "player" then
        local player = entityData.entity
        
        -- 플레이어 스폰
        if player.Character then
            player.Character:MoveTo(position)
        end
    elseif entityData.type == "ai" then
        -- AI 스폰 (나중에 구현)
        local ai = entityData.entity
        -- AI 캐릭터 생성 및 위치 설정
    end
end

function GameManager:eliminatePlayer(player, reason)
    -- 플레이어 제거
    for i, p in ipairs(self.players) do
        if p == player then
            table.remove(self.players, i)
            table.insert(self.deadPlayers, player)
            
            print("플레이어 탈락:", player.Name, "이유:", reason)
            self.playerEliminated:Fire(player, reason)
            
            self:checkWinCondition()
            break
        end
    end
end

function GameManager:eliminateAI(ai, reason)
    -- AI 제거
    for i, aiCharacter in ipairs(self.aiCharacters) do
        if aiCharacter == ai then
            self.aiSystem:eliminateAI(aiCharacter, reason)
            
            -- 목록에서 제거하지 말고 상태만 변경 (aiSystem에서 관리)
            print("AI 탈락:", ai.name, "이유:", reason)
            
            self:checkWinCondition()
            break
        end
    end
end

function GameManager:checkWinCondition()
    if self.gameState ~= GameState.PLAYING then
        return
    end
    
    -- 살아있는 AI 수 계산
    local aliveAI = 0
    for _, ai in ipairs(self.aiCharacters) do
        if ai.isAlive then
            aliveAI = aliveAI + 1
        end
    end
    
    local totalAlive = #self.players + aliveAI
    
    -- 승리 조건 체크
    if totalAlive <= 1 then
        if #self.players == 1 then
            self:endGame("플레이어 승리: " .. self.players[1].Name)
        elseif #self.players == 0 and aliveAI == 1 then
            self:endGame("AI 승리")
        else
            self:endGame("무승부")
        end
    end
end

function GameManager:checkGameTimer()
    -- 게임 시간 제한 체크
    while self.gameState == GameState.PLAYING do
        local elapsedTime = tick() - self.gameStartTime
        
        if elapsedTime >= GAME_CONFIG.ROUND_TIME then
            self:endGame("시간 초과")
            break
        end
        
        wait(1)
    end
end

function GameManager:endGame(reason)
    if self.gameState ~= GameState.PLAYING then
        return
    end
    
    self.gameState = GameState.ENDING
    print("게임 종료:", reason)
    
    self.gameStateChanged:Fire(self.gameState)
    self.gameEnded:Fire(reason)
    
    -- 잠시 대기 후 다음 라운드 준비
    wait(GAME_CONFIG.RESPAWN_TIME)
    
    self:resetGame()
end

function GameManager:resetGame()
    -- 게임 초기화
    self.gameState = GameState.WAITING
    self.deadPlayers = {}
    self.aiCharacters = {}
    
    -- 시스템 초기화
    self.aiSystem:destroyAllAI()
    self.pillarSystem:resetAllProgress()
    
    -- 플레이어 데이터 초기화
    for _, player in ipairs(Players:GetPlayers()) do
        self.characterManager:resetPlayerData(player)
        self.pillarSystem:resetPlayerProgress(player)
    end
    
    -- 현재 접속한 플레이어들로 플레이어 목록 재구성
    self.players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(self.players, player)
    end
    
    print("게임 초기화 완료. 대기 중...")
    self.gameStateChanged:Fire(self.gameState)
    
    -- 플레이어가 충분하면 바로 다시 시작
    if #self.players >= GAME_CONFIG.MIN_PLAYERS then
        wait(2)
        self:startGameCountdown()
    end
end

function GameManager:setPlayerAsSpectator(player)
    -- 플레이어를 관전자로 설정
    print("관전자 설정:", player.Name)
    -- 관전자 카메라 설정 등 (나중에 구현)
end

function GameManager:getGameState()
    return self.gameState
end

function GameManager:getAlivePlayers()
    return self.players
end

function GameManager:getAliveAI()
    return self.aiSystem:getAllAliveAI()
end

return GameManager