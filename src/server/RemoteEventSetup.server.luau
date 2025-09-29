-- RemoteEvent 생성 스크립트
-- 클라이언트와 서버 간 통신을 위한 RemoteEvent들을 생성

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvents 폴더 생성
local remoteEventsFolder = Instance.new("Folder")
remoteEventsFolder.Name = "RemoteEvents"
remoteEventsFolder.Parent = ReplicatedStorage

-- 게임 상태 관련 RemoteEvent들
local gameStateChanged = Instance.new("RemoteEvent")
gameStateChanged.Name = "GameStateChanged"
gameStateChanged.Parent = remoteEventsFolder

local playerEliminated = Instance.new("RemoteEvent")
playerEliminated.Name = "PlayerEliminated"  
playerEliminated.Parent = remoteEventsFolder

local gameEnded = Instance.new("RemoteEvent")
gameEnded.Name = "GameEnded"
gameEnded.Parent = remoteEventsFolder

-- 플레이어 액션 관련 RemoteEvent들
local playerPunch = Instance.new("RemoteEvent")
playerPunch.Name = "PlayerPunch"
playerPunch.Parent = remoteEventsFolder

local playerTagPillar = Instance.new("RemoteEvent")
playerTagPillar.Name = "PlayerTagPillar"
playerTagPillar.Parent = remoteEventsFolder

-- 게임 정보 요청 관련 RemoteFunction들
local getGameInfo = Instance.new("RemoteFunction")
getGameInfo.Name = "GetGameInfo"
getGameInfo.Parent = remoteEventsFolder

print("RemoteEvent들이 생성되었습니다.")