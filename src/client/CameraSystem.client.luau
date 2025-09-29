-- 카메라 시스템: 3인칭 시점과 마우스 시야 회전 구현
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraSystem = {}
CameraSystem.__index = CameraSystem

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- 카메라 설정
local CAMERA_CONFIG = {
    -- 3인칭 카메라 거리
    DISTANCE = 12,
    MIN_DISTANCE = 5,
    MAX_DISTANCE = 25,
    
    -- 카메라 각도 제한
    MIN_Y_ANGLE = math.rad(-80),  -- 위쪽 제한
    MAX_Y_ANGLE = math.rad(80),   -- 아래쪽 제한
    
    -- 마우스 감도
    MOUSE_SENSITIVITY = 0.3,
    
    -- 카메라 스무딩
    SMOOTHING_FACTOR = 0.1,
    
    -- 벽 통과 방지
    WALL_COLLISION = true,
    RAY_DISTANCE = 25
}

function CameraSystem.new()
    local self = setmetatable({}, CameraSystem)
    
    -- 카메라 상태
    self.camera = workspace.CurrentCamera
    self.enabled = false
    
    -- 회전 각도
    self.rotX = 0  -- 좌우 회전 (Y축 기준)
    self.rotY = 0  -- 상하 회전 (X축 기준)
    
    -- 카메라 거리
    self.currentDistance = CAMERA_CONFIG.DISTANCE
    
    -- 연결들
    self.connections = {}
    
    return self
end

function CameraSystem:enable()
    if self.enabled then return end
    
    self.enabled = true
    
    -- 카메라 타입을 Scriptable로 설정
    self.camera.CameraType = Enum.CameraType.Scriptable
    
    -- 마우스 잠금
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    
    -- 업데이트 루프 시작
    self.connections.heartbeat = RunService.Heartbeat:Connect(function()
        self:updateCamera()
    end)
    
    -- 입력 처리
    self.connections.inputChanged = UserInputService.InputChanged:Connect(function(input)
        self:handleInput(input)
    end)
    
    -- 마우스 휠로 줌 조절
    self.connections.wheelMoved = player:GetMouse().WheelForward:Connect(function()
        self:zoomIn()
    end)
    
    self.connections.wheelBack = player:GetMouse().WheelBackward:Connect(function()
        self:zoomOut()
    end)
    
    print("카메라 시스템 활성화")
end

function CameraSystem:disable()
    if not self.enabled then return end
    
    self.enabled = false
    
    -- 카메라 타입 복구
    self.camera.CameraType = Enum.CameraType.Custom
    
    -- 마우스 해제
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    
    -- 연결 해제
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    print("카메라 시스템 비활성화")
end

function CameraSystem:handleInput(input)
    if not self.enabled then return end
    
    -- 마우스 움직임 처리
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Delta
        
        -- 마우스 감도 적용
        self.rotX = self.rotX - delta.X * CAMERA_CONFIG.MOUSE_SENSITIVITY * 0.01
        self.rotY = self.rotY - delta.Y * CAMERA_CONFIG.MOUSE_SENSITIVITY * 0.01
        
        -- Y축 회전 제한 (위아래 제한)
        self.rotY = math.clamp(self.rotY, CAMERA_CONFIG.MIN_Y_ANGLE, CAMERA_CONFIG.MAX_Y_ANGLE)
    end
end

function CameraSystem:updateCamera()
    if not self.enabled then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- 캐릭터 위치
    local characterPosition = humanoidRootPart.Position
    
    -- 카메라 회전 계산
    local rotationCFrame = CFrame.Angles(self.rotY, self.rotX, 0)
    
    -- 카메라 목표 위치 계산 (캐릭터 뒤쪽)
    local offset = Vector3.new(0, 2, self.currentDistance)  -- Y 오프셋으로 어깨 높이
    local targetCameraPosition = characterPosition + rotationCFrame:VectorToWorldSpace(offset)
    
    -- 벽 충돌 검사
    if CAMERA_CONFIG.WALL_COLLISION then
        targetCameraPosition = self:checkWallCollision(characterPosition, targetCameraPosition)
    end
    
    -- 카메라 CFrame 설정
    local lookDirection = (characterPosition + Vector3.new(0, 2, 0) - targetCameraPosition).Unit
    local cameraCFrame = CFrame.lookAt(targetCameraPosition, characterPosition + Vector3.new(0, 2, 0))
    
    -- 스무딩 적용
    if CAMERA_CONFIG.SMOOTHING_FACTOR > 0 then
        self.camera.CFrame = self.camera.CFrame:Lerp(cameraCFrame, CAMERA_CONFIG.SMOOTHING_FACTOR)
    else
        self.camera.CFrame = cameraCFrame
    end
end

function CameraSystem:checkWallCollision(characterPosition, targetCameraPosition)
    -- 캐릭터에서 카메라 위치까지 레이캐스팅
    local direction = (targetCameraPosition - characterPosition)
    local distance = direction.Magnitude
    
    if distance <= 0 then
        return targetCameraPosition
    end
    
    local rayDirection = direction.Unit * distance
    
    -- 레이캐스트 설정
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}
    
    local raycastResult = workspace:Raycast(characterPosition, rayDirection, raycastParams)
    
    if raycastResult then
        -- 벽에 충돌했으면 카메라를 벽 앞으로 이동
        local hitPoint = raycastResult.Position
        local normal = raycastResult.Normal
        
        -- 벽에서 약간 떨어진 위치로 조정
        local adjustedPosition = hitPoint + normal * 0.5
        
        return adjustedPosition
    end
    
    return targetCameraPosition
end

function CameraSystem:zoomIn()
    if not self.enabled then return end
    
    self.currentDistance = math.max(
        self.currentDistance - 2, 
        CAMERA_CONFIG.MIN_DISTANCE
    )
    
    print("줌 인:", self.currentDistance)
end

function CameraSystem:zoomOut()
    if not self.enabled then return end
    
    self.currentDistance = math.min(
        self.currentDistance + 2, 
        CAMERA_CONFIG.MAX_DISTANCE
    )
    
    print("줌 아웃:", self.currentDistance)
end

function CameraSystem:setDistance(distance)
    self.currentDistance = math.clamp(
        distance,
        CAMERA_CONFIG.MIN_DISTANCE,
        CAMERA_CONFIG.MAX_DISTANCE
    )
end

function CameraSystem:resetRotation()
    -- 카메라 회전 초기화
    self.rotX = 0
    self.rotY = 0
end

function CameraSystem:setRotation(rotX, rotY)
    -- 카메라 회전 설정
    self.rotX = rotX
    self.rotY = math.clamp(rotY, CAMERA_CONFIG.MIN_Y_ANGLE, CAMERA_CONFIG.MAX_Y_ANGLE)
end

function CameraSystem:lookAt(targetPosition)
    -- 특정 위치를 바라보도록 카메라 설정
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local characterPosition = humanoidRootPart.Position + Vector3.new(0, 2, 0)
    local direction = (targetPosition - characterPosition)
    
    -- 회전 각도 계산
    self.rotX = math.atan2(direction.X, direction.Z)
    self.rotY = math.asin(-direction.Y / direction.Magnitude)
    
    -- 제한 적용
    self.rotY = math.clamp(self.rotY, CAMERA_CONFIG.MIN_Y_ANGLE, CAMERA_CONFIG.MAX_Y_ANGLE)
end

function CameraSystem:shakCamera(intensity, duration)
    -- 카메라 흔들림 효과
    if not self.enabled then return end
    
    intensity = intensity or 1
    duration = duration or 0.5
    
    local startTime = tick()
    local originalRotX = self.rotX
    local originalRotY = self.rotY
    
    local shakeConnection
    shakeConnection = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        
        if elapsed >= duration then
            -- 원래 위치로 복구
            self.rotX = originalRotX
            self.rotY = originalRotY
            shakeConnection:Disconnect()
            return
        end
        
        -- 감쇠하는 흔들림 계산
        local progress = elapsed / duration
        local currentIntensity = intensity * (1 - progress)
        
        -- 랜덤 흔들림 적용
        local shakeX = (math.random() - 0.5) * currentIntensity * 0.1
        local shakeY = (math.random() - 0.5) * currentIntensity * 0.1
        
        self.rotX = originalRotX + shakeX
        self.rotY = math.clamp(
            originalRotY + shakeY,
            CAMERA_CONFIG.MIN_Y_ANGLE,
            CAMERA_CONFIG.MAX_Y_ANGLE
        )
    end)
end

function CameraSystem:isEnabled()
    return self.enabled
end

function CameraSystem:getRotation()
    return self.rotX, self.rotY
end

function CameraSystem:getDistance()
    return self.currentDistance
end

return CameraSystem