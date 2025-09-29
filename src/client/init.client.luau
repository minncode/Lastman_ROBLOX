-- Last Man Standing 클라이언트
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- 매니저들 로드
local CharacterManager = require(ReplicatedStorage.Shared.CharacterManager)
local CameraSystem = require(script.Parent.CameraSystem)
local UISystem = require(script.Parent.UISystem)

-- 매니저 인스턴스 생성
local characterManager = CharacterManager.new()
local cameraSystem = CameraSystem.new()
local uiSystem = UISystem.new()

print("Last Man Standing 클라이언트가 시작되었습니다!")

-- 플레이어 캐릭터 설정
characterManager:setupPlayer(player)

-- 캐릭터 스폰 시 카메라 시스템 활성화
player.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid")
    wait(0.5) -- 캐릭터 로드 대기
    cameraSystem:enable()
end)

-- 이미 캐릭터가 있다면 바로 활성화
if player.Character and player.Character:FindFirstChild("Humanoid") then
    cameraSystem:enable()
end

-- 입력 처리
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    characterManager:handleInput(player, input)
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    characterManager:handleInput(player, input)
end)

-- RemoteEvent 연결 대기
spawn(function()
    local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
    
    -- 게임 상태 변경 이벤트
    local gameStateChanged = remoteEvents:WaitForChild("GameStateChanged")
    gameStateChanged.OnClientEvent:Connect(function(newState, data)
        print("게임 상태:", newState)
        
        -- 게임 상태에 따른 카메라 처리
        if newState == "PLAYING" then
            if not cameraSystem:isEnabled() then
                cameraSystem:enable()
            end
            uiSystem:showGameStateMessage("게임 시작!", "마지막까지 살아남으세요!", 3)
        elseif newState == "STARTING" then
            uiSystem:showGameStateMessage("게임 시작 준비 중...", "잠시 후 게임이 시작됩니다", 0)
        elseif newState == "WAITING" then
            uiSystem:hideGameStateMessage()
        elseif newState == "ENDING" then
            -- 게임 종료 시 카메라 흔들림 효과
            cameraSystem:shakCamera(2, 1)
        end
        
        -- UI 업데이트 (게임 정보 갱신)
        spawn(function()
            local gameInfo = getGameInfo:InvokeServer()
            if gameInfo then
                uiSystem:updateGameInfo(newState, gameInfo.alivePlayers, #gameInfo.aliveAI)
                uiSystem:updatePlayerStatus(gameInfo.playerData)
            end
        end)
    end)
    
    -- 플레이어 탈락 이벤트
    local playerEliminated = remoteEvents:WaitForChild("PlayerEliminated")
    playerEliminated.OnClientEvent:Connect(function(eliminatedPlayer, reason)
        print("플레이어 탈락:", eliminatedPlayer.Name, "-", reason)
        
        -- 탈락 알림 표시
        if eliminatedPlayer == player then
            uiSystem:showNotification("당신이 탈락했습니다: " .. reason, 5, uiSystem.UI_CONFIG.COLORS.DANGER)
            uiSystem:showGameStateMessage("탈락!", reason, 3)
        else
            uiSystem:showNotification(eliminatedPlayer.Name .. " 탈락: " .. reason, 3, uiSystem.UI_CONFIG.COLORS.WARNING)
        end
        
        -- UI 정보 업데이트
        spawn(function()
            local gameInfo = getGameInfo:InvokeServer()
            if gameInfo then
                uiSystem:updateGameInfo(gameInfo.gameState, gameInfo.alivePlayers, #gameInfo.aliveAI)
            end
        end)
    end)
    
    -- 게임 종료 이벤트
    local gameEnded = remoteEvents:WaitForChild("GameEnded")
    gameEnded.OnClientEvent:Connect(function(reason, winner)
        print("게임 종료:", reason)
        
        -- 게임 결과 표시
        if reason:find("승리") then
            local winnerName = reason:match("승리: (.+)") or "알 수 없음"
            if winnerName == player.Name then
                uiSystem:showGameStateMessage("승리!", "축하합니다!", 5)
                uiSystem:showNotification("🎉 승리했습니다! 🎉", 5, uiSystem.UI_CONFIG.COLORS.SUCCESS)
            else
                uiSystem:showGameStateMessage("게임 종료", winnerName .. " 승리", 5)
                uiSystem:showNotification("게임 종료: " .. reason, 5, uiSystem.UI_CONFIG.COLORS.WARNING)
            end
        else
            uiSystem:showGameStateMessage("게임 종료", reason, 5)
            uiSystem:showNotification("게임 종료: " .. reason, 5, uiSystem.UI_CONFIG.COLORS.WARNING)
        end
    end)
    
    -- 게임 정보 요청 함수 (다른 이벤트에서 사용)
    local getGameInfo = remoteEvents:WaitForChild("GetGameInfo")
    
    -- 주기적으로 UI 업데이트
    spawn(function()
        while true do
            wait(1) -- 1초마다 업데이트
            
            local success, gameInfo = pcall(function()
                return getGameInfo:InvokeServer()
            end)
            
            if success and gameInfo then
                uiSystem:updateGameInfo(gameInfo.gameState, gameInfo.alivePlayers, #gameInfo.aliveAI)
                uiSystem:updatePlayerStatus(gameInfo.playerData)
            end
        end
    end)
end)