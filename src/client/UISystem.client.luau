-- UI 시스템: 게임 정보 표시 및 인터페이스 관리
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UISystem = {}
UISystem.__index = UISystem

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI 설정
local UI_CONFIG = {
    -- 색상 설정
    COLORS = {
        PRIMARY = Color3.fromRGB(45, 45, 45),
        SECONDARY = Color3.fromRGB(65, 65, 65),
        SUCCESS = Color3.fromRGB(0, 200, 0),
        WARNING = Color3.fromRGB(255, 165, 0),
        DANGER = Color3.fromRGB(255, 0, 0),
        TEXT = Color3.fromRGB(255, 255, 255)
    },
    
    -- 폰트
    FONT = Enum.Font.GothamBold,
    
    -- 애니메이션 시간
    TWEEN_TIME = 0.3
}

function UISystem.new()
    local self = setmetatable({}, UISystem)
    
    -- UI 요소들
    self.mainGui = nil
    self.gameInfoFrame = nil
    self.statusFrame = nil
    self.notificationFrame = nil
    
    -- 데이터
    self.currentGameState = "WAITING"
    self.alivePlayers = {}
    self.aliveAI = 0
    self.playerData = {}
    
    -- UI 생성
    self:createMainUI()
    
    return self
end

function UISystem:createMainUI()
    -- 메인 ScreenGui 생성
    self.mainGui = Instance.new("ScreenGui")
    self.mainGui.Name = "LastManStandingUI"
    self.mainGui.ResetOnSpawn = false
    self.mainGui.Parent = playerGui
    
    -- 게임 정보 프레임
    self:createGameInfoFrame()
    
    -- 상태 프레임 (플레이어 개인 정보)
    self:createStatusFrame()
    
    -- 알림 프레임
    self:createNotificationFrame()
    
    -- 게임 상태 프레임 (중앙 메시지)
    self:createGameStateFrame()
    
    print("UI 시스템 생성 완료")
end

function UISystem:createGameInfoFrame()
    -- 상단 게임 정보 프레임
    self.gameInfoFrame = Instance.new("Frame")
    self.gameInfoFrame.Name = "GameInfo"
    self.gameInfoFrame.Size = UDim2.new(0, 300, 0, 80)
    self.gameInfoFrame.Position = UDim2.new(0, 20, 0, 20)
    self.gameInfoFrame.BackgroundColor3 = UI_CONFIG.COLORS.PRIMARY
    self.gameInfoFrame.BorderSizePixel = 0
    self.gameInfoFrame.Parent = self.mainGui
    
    -- 둥근 모서리
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = self.gameInfoFrame
    
    -- 생존자 수 라벨
    local surviversLabel = Instance.new("TextLabel")
    surviversLabel.Name = "SurviversLabel"
    surviversLabel.Size = UDim2.new(1, 0, 0.5, 0)
    surviversLabel.Position = UDim2.new(0, 0, 0, 0)
    surviversLabel.BackgroundTransparency = 1
    surviversLabel.Text = "생존자: 0"
    surviversLabel.TextColor3 = UI_CONFIG.COLORS.TEXT
    surviversLabel.TextScaled = true
    surviversLabel.Font = UI_CONFIG.FONT
    surviversLabel.Parent = self.gameInfoFrame
    
    -- 게임 상태 라벨
    local gameStateLabel = Instance.new("TextLabel")
    gameStateLabel.Name = "GameStateLabel"
    gameStateLabel.Size = UDim2.new(1, 0, 0.5, 0)
    gameStateLabel.Position = UDim2.new(0, 0, 0.5, 0)
    gameStateLabel.BackgroundTransparency = 1
    gameStateLabel.Text = "대기 중..."
    gameStateLabel.TextColor3 = UI_CONFIG.COLORS.WARNING
    gameStateLabel.TextScaled = true
    gameStateLabel.Font = UI_CONFIG.FONT
    gameStateLabel.Parent = self.gameInfoFrame
end

function UISystem:createStatusFrame()
    -- 플레이어 개인 상태 프레임 (우측 상단)
    self.statusFrame = Instance.new("Frame")
    self.statusFrame.Name = "PlayerStatus"
    self.statusFrame.Size = UDim2.new(0, 250, 0, 100)
    self.statusFrame.Position = UDim2.new(1, -270, 0, 20)
    self.statusFrame.BackgroundColor3 = UI_CONFIG.COLORS.PRIMARY
    self.statusFrame.BorderSizePixel = 0
    self.statusFrame.Parent = self.mainGui
    
    -- 둥근 모서리
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = self.statusFrame
    
    -- 태그한 기둥 수
    local pillarsLabel = Instance.new("TextLabel")
    pillarsLabel.Name = "PillarsLabel"
    pillarsLabel.Size = UDim2.new(1, 0, 0.33, 0)
    pillarsLabel.Position = UDim2.new(0, 0, 0, 0)
    pillarsLabel.BackgroundTransparency = 1
    pillarsLabel.Text = "태그한 기둥: 0/4"
    pillarsLabel.TextColor3 = UI_CONFIG.COLORS.TEXT
    pillarsLabel.TextScaled = true
    pillarsLabel.Font = UI_CONFIG.FONT
    pillarsLabel.Parent = self.statusFrame
    
    -- 이동 속도
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "SpeedLabel"
    speedLabel.Size = UDim2.new(1, 0, 0.33, 0)
    speedLabel.Position = UDim2.new(0, 0, 0.33, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "속도: 100%"
    speedLabel.TextColor3 = UI_CONFIG.COLORS.SUCCESS
    speedLabel.TextScaled = true
    speedLabel.Font = UI_CONFIG.FONT
    speedLabel.Parent = self.statusFrame
    
    -- 조작법 안내
    local controlsLabel = Instance.new("TextLabel")
    controlsLabel.Name = "ControlsLabel"
    controlsLabel.Size = UDim2.new(1, 0, 0.33, 0)
    controlsLabel.Position = UDim2.new(0, 0, 0.67, 0)
    controlsLabel.BackgroundTransparency = 1
    controlsLabel.Text = "Shift: 달리기 | Ctrl: 앉기 | 클릭: 공격"
    controlsLabel.TextColor3 = UI_CONFIG.COLORS.TEXT
    controlsLabel.TextScaled = true
    controlsLabel.Font = Enum.Font.Gotham
    controlsLabel.TextSize = 12
    controlsLabel.Parent = self.statusFrame
end

function UISystem:createNotificationFrame()
    -- 알림 프레임 (중앙 하단)
    self.notificationFrame = Instance.new("Frame")
    self.notificationFrame.Name = "Notifications"
    self.notificationFrame.Size = UDim2.new(0, 400, 0, 60)
    self.notificationFrame.Position = UDim2.new(0.5, -200, 1, -100)
    self.notificationFrame.BackgroundTransparency = 1
    self.notificationFrame.Parent = self.mainGui
    
    -- 알림 텍스트
    local notificationText = Instance.new("TextLabel")
    notificationText.Name = "NotificationText"
    notificationText.Size = UDim2.new(1, 0, 1, 0)
    notificationText.Position = UDim2.new(0, 0, 0, 0)
    notificationText.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    notificationText.BackgroundTransparency = 0.3
    notificationText.BorderSizePixel = 0
    notificationText.Text = ""
    notificationText.TextColor3 = UI_CONFIG.COLORS.TEXT
    notificationText.TextScaled = true
    notificationText.Font = UI_CONFIG.FONT
    notificationText.Visible = false
    notificationText.Parent = self.notificationFrame
    
    -- 둥근 모서리
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = notificationText
end

function UISystem:createGameStateFrame()
    -- 게임 상태 메시지 프레임 (화면 중앙)
    self.gameStateFrame = Instance.new("Frame")
    self.gameStateFrame.Name = "GameStateMessage"
    self.gameStateFrame.Size = UDim2.new(0, 600, 0, 200)
    self.gameStateFrame.Position = UDim2.new(0.5, -300, 0.5, -100)
    self.gameStateFrame.BackgroundTransparency = 1
    self.gameStateFrame.Parent = self.mainGui
    
    -- 큰 메시지 텍스트
    local messageText = Instance.new("TextLabel")
    messageText.Name = "MessageText"
    messageText.Size = UDim2.new(1, 0, 0.6, 0)
    messageText.Position = UDim2.new(0, 0, 0, 0)
    messageText.BackgroundTransparency = 1
    messageText.Text = ""
    messageText.TextColor3 = UI_CONFIG.COLORS.TEXT
    messageText.TextScaled = true
    messageText.Font = UI_CONFIG.FONT
    messageText.TextStrokeTransparency = 0
    messageText.TextStrokeColor3 = Color3.new(0, 0, 0)
    messageText.Visible = false
    messageText.Parent = self.gameStateFrame
    
    -- 서브 메시지 텍스트
    local subText = Instance.new("TextLabel")
    subText.Name = "SubText"
    subText.Size = UDim2.new(1, 0, 0.4, 0)
    subText.Position = UDim2.new(0, 0, 0.6, 0)
    subText.BackgroundTransparency = 1
    subText.Text = ""
    subText.TextColor3 = UI_CONFIG.COLORS.TEXT
    subText.TextScaled = true
    subText.Font = Enum.Font.Gotham
    subText.TextStrokeTransparency = 0
    subText.TextStrokeColor3 = Color3.new(0, 0, 0)
    subText.Visible = false
    subText.Parent = self.gameStateFrame
end

function UISystem:updateGameInfo(gameState, alivePlayers, aliveAI)
    self.currentGameState = gameState
    self.alivePlayers = alivePlayers or {}
    self.aliveAI = aliveAI or 0
    
    local gameInfoFrame = self.gameInfoFrame
    if not gameInfoFrame then return end
    
    -- 생존자 수 업데이트
    local surviversLabel = gameInfoFrame:FindFirstChild("SurviversLabel")
    if surviversLabel then
        local totalSurvivors = #self.alivePlayers + self.aliveAI
        surviversLabel.Text = "생존자: " .. totalSurvivors
        
        -- 색상 변경
        if totalSurvivors <= 3 then
            surviversLabel.TextColor3 = UI_CONFIG.COLORS.DANGER
        elseif totalSurvivors <= 6 then
            surviversLabel.TextColor3 = UI_CONFIG.COLORS.WARNING
        else
            surviversLabel.TextColor3 = UI_CONFIG.COLORS.SUCCESS
        end
    end
    
    -- 게임 상태 업데이트
    local gameStateLabel = gameInfoFrame:FindFirstChild("GameStateLabel")
    if gameStateLabel then
        local stateText = ""
        local stateColor = UI_CONFIG.COLORS.TEXT
        
        if gameState == "WAITING" then
            stateText = "플레이어 대기 중..."
            stateColor = UI_CONFIG.COLORS.WARNING
        elseif gameState == "STARTING" then
            stateText = "게임 시작 중..."
            stateColor = UI_CONFIG.COLORS.SUCCESS
        elseif gameState == "PLAYING" then
            stateText = "게임 진행 중"
            stateColor = UI_CONFIG.COLORS.SUCCESS
        elseif gameState == "ENDING" then
            stateText = "게임 종료"
            stateColor = UI_CONFIG.COLORS.DANGER
        end
        
        gameStateLabel.Text = stateText
        gameStateLabel.TextColor3 = stateColor
    end
end

function UISystem:updatePlayerStatus(playerData)
    self.playerData = playerData or {}
    
    local statusFrame = self.statusFrame
    if not statusFrame then return end
    
    -- 태그한 기둥 수 업데이트
    local pillarsLabel = statusFrame:FindFirstChild("PillarsLabel")
    if pillarsLabel then
        local pillarCount = playerData.pillarsTouched or 0
        pillarsLabel.Text = "태그한 기둥: " .. pillarCount .. "/4"
        
        -- 색상 변경
        if pillarCount >= 4 then
            pillarsLabel.TextColor3 = UI_CONFIG.COLORS.SUCCESS
        elseif pillarCount >= 2 then
            pillarsLabel.TextColor3 = UI_CONFIG.COLORS.WARNING
        else
            pillarsLabel.TextColor3 = UI_CONFIG.COLORS.TEXT
        end
    end
    
    -- 속도 정보 업데이트
    local speedLabel = statusFrame:FindFirstChild("SpeedLabel")
    if speedLabel then
        local pillarCount = playerData.pillarsTouched or 0
        local speedPercent = math.floor((1 - pillarCount * 0.3) * 100)
        speedPercent = math.max(speedPercent, 20) -- 최소 20%
        
        speedLabel.Text = "속도: " .. speedPercent .. "%"
        
        -- 색상 변경
        if speedPercent >= 70 then
            speedLabel.TextColor3 = UI_CONFIG.COLORS.SUCCESS
        elseif speedPercent >= 40 then
            speedLabel.TextColor3 = UI_CONFIG.COLORS.WARNING
        else
            speedLabel.TextColor3 = UI_CONFIG.COLORS.DANGER
        end
    end
end

function UISystem:showNotification(message, duration, color)
    duration = duration or 3
    color = color or UI_CONFIG.COLORS.SUCCESS
    
    local notificationText = self.notificationFrame:FindFirstChild("NotificationText")
    if not notificationText then return end
    
    -- 메시지 설정
    notificationText.Text = message
    notificationText.BackgroundColor3 = color
    notificationText.Visible = true
    
    -- 페이드 인 애니메이션
    notificationText.BackgroundTransparency = 1
    local fadeIn = TweenService:Create(
        notificationText,
        TweenInfo.new(UI_CONFIG.TWEEN_TIME, Enum.EasingStyle.Quad),
        {BackgroundTransparency = 0.3}
    )
    fadeIn:Play()
    
    -- 일정 시간 후 페이드 아웃
    wait(duration)
    
    local fadeOut = TweenService:Create(
        notificationText,
        TweenInfo.new(UI_CONFIG.TWEEN_TIME, Enum.EasingStyle.Quad),
        {BackgroundTransparency = 1}
    )
    fadeOut:Play()
    
    fadeOut.Completed:Connect(function()
        notificationText.Visible = false
    end)
end

function UISystem:showGameStateMessage(mainMessage, subMessage, duration)
    duration = duration or 3
    
    local messageText = self.gameStateFrame:FindFirstChild("MessageText")
    local subText = self.gameStateFrame:FindFirstChild("SubText")
    
    if not messageText or not subText then return end
    
    -- 메시지 설정
    messageText.Text = mainMessage or ""
    subText.Text = subMessage or ""
    
    -- 표시
    messageText.Visible = true
    subText.Visible = subMessage and true or false
    
    -- 스케일 애니메이션
    messageText.Size = UDim2.new(0, 0, 0.6, 0)
    local scaleIn = TweenService:Create(
        messageText,
        TweenInfo.new(UI_CONFIG.TWEEN_TIME, Enum.EasingStyle.Back),
        {Size = UDim2.new(1, 0, 0.6, 0)}
    )
    scaleIn:Play()
    
    -- 일정 시간 후 사라짐
    if duration > 0 then
        wait(duration)
        
        local scaleOut = TweenService:Create(
            messageText,
            TweenInfo.new(UI_CONFIG.TWEEN_TIME, Enum.EasingStyle.Quad),
            {Size = UDim2.new(0, 0, 0.6, 0)}
        )
        scaleOut:Play()
        
        scaleOut.Completed:Connect(function()
            messageText.Visible = false
            subText.Visible = false
        end)
    end
end

function UISystem:hideGameStateMessage()
    local messageText = self.gameStateFrame:FindFirstChild("MessageText")
    local subText = self.gameStateFrame:FindFirstChild("SubText")
    
    if messageText then messageText.Visible = false end
    if subText then subText.Visible = false end
end

function UISystem:destroy()
    if self.mainGui then
        self.mainGui:Destroy()
    end
end

return UISystem