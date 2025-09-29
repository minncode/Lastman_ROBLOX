-- Last Man Standing 게임 서버
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 게임 매니저 로드
local GameManager = require(ReplicatedStorage.Shared.GameManager)

-- 게임 인스턴스 생성
local gameInstance = GameManager.new()

print("Last Man Standing 서버가 시작되었습니다!")

-- RemoteEvent 연결 대기 및 설정
spawn(function()
    local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
    
    -- 게임 상태 변경 이벤트 처리
    gameInstance.gameStateChanged.Event:Connect(function(newState)
        print("게임 상태 변경:", newState)
        local gameStateChanged = remoteEvents:FindFirstChild("GameStateChanged")
        if gameStateChanged then
            gameStateChanged:FireAllClients(newState)
        end
    end)

    -- 플레이어 탈락 이벤트 처리  
    gameInstance.playerEliminated.Event:Connect(function(player, reason)
        print("플레이어 탈락 알림:", player.Name, "-", reason)
        local playerEliminated = remoteEvents:FindFirstChild("PlayerEliminated")
        if playerEliminated then
            playerEliminated:FireAllClients(player, reason)
        end
    end)

    -- 게임 종료 이벤트 처리
    gameInstance.gameEnded.Event:Connect(function(reason)
        print("게임 종료 알림:", reason)
        local gameEnded = remoteEvents:FindFirstChild("GameEnded")
        if gameEnded then
            gameEnded:FireAllClients(reason)
        end
    end)
    
    -- 플레이어 펀치 이벤트 처리
    local playerPunch = remoteEvents:WaitForChild("PlayerPunch")
    playerPunch.OnServerEvent:Connect(function(attackerPlayer, targetPlayer)
        print("펀치 이벤트:", attackerPlayer.Name, "->", targetPlayer and targetPlayer.Name or "Unknown")
        
        -- 유효성 검사
        if not targetPlayer or not targetPlayer.Parent then
            return
        end
        
        -- 게임이 진행 중인지 확인
        if gameInstance:getGameState() ~= "PLAYING" then
            return
        end
        
        -- 공격자와 타겟이 모두 살아있는지 확인
        local alivePlayers = gameInstance:getAlivePlayers()
        local attackerAlive = false
        local targetAlive = false
        
        for _, player in ipairs(alivePlayers) do
            if player == attackerPlayer then
                attackerAlive = true
            end
            if player == targetPlayer then
                targetAlive = true
            end
        end
        
        if attackerAlive and targetAlive then
            -- 타겟 플레이어 제거
            gameInstance:eliminatePlayer(targetPlayer, attackerPlayer.Name .. "에게 공격받음")
        end
    end)
    
    -- 기둥 태그 이벤트 처리
    local playerTagPillar = remoteEvents:WaitForChild("PlayerTagPillar")
    playerTagPillar.OnServerEvent:Connect(function(player, pillarNumber)
        print("기둥 태그 이벤트:", player.Name, "기둥", pillarNumber)
        
        -- 게임이 진행 중인지 확인
        if gameInstance:getGameState() ~= "PLAYING" then
            return
        end
        
        -- 플레이어가 살아있는지 확인
        local alivePlayers = gameInstance:getAlivePlayers()
        local playerAlive = false
        
        for _, p in ipairs(alivePlayers) do
            if p == player then
                playerAlive = true
                break
            end
        end
        
        if playerAlive then
            -- 기둥 태그 처리 (CharacterManager를 통해)
            gameInstance.characterManager:onPillarTagged(player)
            
            -- 4개 모두 태그했는지 확인
            local playerData = gameInstance.characterManager:getPlayerData(player)
            if playerData and playerData.pillarsTouched >= 4 then
                -- 기둥 태그로 승리
                gameInstance:endGame("기둥 태그 승리: " .. player.Name)
            end
        end
    end)
    
    -- 게임 정보 요청 처리
    local getGameInfo = remoteEvents:WaitForChild("GetGameInfo")
    getGameInfo.OnServerInvoke = function(player)
        return {
            gameState = gameInstance:getGameState(),
            alivePlayers = gameInstance:getAlivePlayers(),
            aliveAI = gameInstance:getAliveAI(),
            playerData = gameInstance.characterManager:getPlayerData(player)
        }
    end
end)