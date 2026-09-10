-- hub_commands.lua
-- Commandes joueur :
--   .hub     -> sauvegarde la position et teleporte au hub
--   .retour  -> retourne a la position sauvegardee (uniquement depuis le hub)
--
-- AzerothCore 3.3.5a + ALE/Eluna

local PLAYER_EVENT_ON_LOGIN   = 3
local PLAYER_EVENT_ON_COMMAND = 42

local HUB_MAP = 1
local HUB_X   = -10739.447
local HUB_Y   = 2430.9812
local HUB_Z   = 6.812052
local HUB_O   = 5.6199646

-- Rayon dans lequel .retour est autorise autour du hub.
local HUB_RETURN_RADIUS = 120.0

-- Table persistante : le retour reste disponible meme apres une reconnexion.
CharDBExecute([[
CREATE TABLE IF NOT EXISTS `custom_hub_return` (
    `guid` INT UNSIGNED NOT NULL,
    `map` SMALLINT UNSIGNED NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `o` FLOAT NOT NULL,
    PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

local function Msg(player, text)
    player:SendBroadcastMessage("|cff00ff00[Serveur]|r " .. text)
end

local function NormalizeCommand(command)
    command = string.lower(command or "")
    command = command:gsub("^%s+", ""):gsub("%s+$", "")
    command = command:gsub("^%.", "")
    return command
end

local function IsRestrictedPlace(player)
    local map = player:GetMap()
    if not map then
        return true
    end

    if player:IsInCombat() then
        Msg(player, "Impossible d'utiliser cette commande en combat.")
        return true
    end

    if player:InBattleground() or player:InArena()
        or map:IsBattleground() or map:IsArena()
        or map:IsDungeon() or map:IsRaid() then
        Msg(player, "Impossible d'utiliser cette commande en instance, raid, champ de bataille ou arene.")
        return true
    end

    return false
end

local function IsAtHub(player)
    if player:GetMapId() ~= HUB_MAP then
        return false
    end
    return player:GetExactDistance2d(HUB_X, HUB_Y) <= HUB_RETURN_RADIUS
end

local function SaveReturnPosition(player)
    CharDBExecute(string.format([[
        REPLACE INTO `custom_hub_return`
            (`guid`,`map`,`x`,`y`,`z`,`o`)
        VALUES
            (%u,%u,%.6f,%.6f,%.6f,%.6f)
    ]],
        player:GetGUIDLow(),
        player:GetMapId(),
        player:GetX(),
        player:GetY(),
        player:GetZ(),
        player:GetO()
    ))
end

local function GoHub(player)
    if IsRestrictedPlace(player) then
        return
    end

    if IsAtHub(player) then
        Msg(player, "Tu es deja au hub. Tape |cffffff00.retour|r pour revenir a ta position precedente.")
        return
    end

    SaveReturnPosition(player)
    player:Teleport(HUB_MAP, HUB_X, HUB_Y, HUB_Z, HUB_O)
    Msg(player, "Bienvenue au hub ! Tape |cffffff00.retour|r pour revenir a ta position precedente.")
end

local function GoBack(player)
    if player:IsInCombat() then
        Msg(player, "Impossible d'utiliser .retour en combat.")
        return
    end

    -- .retour sert uniquement a quitter le hub.
    -- Cela evite d'en faire une commande de teleportation exploitable ailleurs.
    if not IsAtHub(player) then
        Msg(player, ".retour est utilisable uniquement depuis le hub.")
        return
    end

    local q = CharDBQuery(string.format(
        "SELECT `map`,`x`,`y`,`z`,`o` FROM `custom_hub_return` WHERE `guid`=%u LIMIT 1",
        player:GetGUIDLow()
    ))

    if not q then
        Msg(player, "Aucune position de retour enregistree. Utilise d'abord .hub.")
        return
    end

    local map = q:GetUInt32(0)
    local x   = q:GetFloat(1)
    local y   = q:GetFloat(2)
    local z   = q:GetFloat(3)
    local o   = q:GetFloat(4)

    -- Le retour est consomme une seule fois.
    CharDBExecute(string.format(
        "DELETE FROM `custom_hub_return` WHERE `guid`=%u",
        player:GetGUIDLow()
    ))

    player:Teleport(map, x, y, z, o)
    Msg(player, "Retour a ta position precedente.")
end

local LOGIN_NOTICE = "Commandes : .hub pour rejoindre le hub des services - .retour pour revenir a ta position precedente."
local loginNoticePending = {}

local function ShowLoginNotice(player)
    -- Deux affichages differents pour etre difficile a rater.
    player:SendNotification(LOGIN_NOTICE)
    player:SendAreaTriggerMessage(LOGIN_NOTICE)
    loginNoticePending[player:GetGUIDLow()] = nil
end

local function OnLogin(event, player)
    -- On marque le joueur, puis on tente tout de suite.
    loginNoticePending[player:GetGUIDLow()] = true
    ShowLoginNotice(player)
end

local function OnMapReady(event, player)
    -- Fallback : si le client vient juste d'entrer dans le monde,
    -- on renvoie le message au premier changement de map.
    if loginNoticePending[player:GetGUIDLow()] then
        ShowLoginNotice(player)
    end
end

local function OnCommand(event, player, command)
    if not player then
        return
    end

    local cmd = NormalizeCommand(command)

    if cmd == "hub" then
        GoHub(player)
        return false
    end

    if cmd == "retour" then
        GoBack(player)
        return false
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(28, OnMapReady) -- PLAYER_EVENT_ON_MAP_CHANGE
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)

PrintInfo("=== HUB COMMANDS V6 - LOGIN NOTIFICATION - .hub / .retour - CHARGE ===")
