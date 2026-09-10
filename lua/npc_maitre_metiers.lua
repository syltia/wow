local NPC_ENTRY = 90000
local MENU_CLOSE = 999

local QUEST_TBC = 66008
local QUEST_WOTLK = 66013
local QUEST_STATUS_REWARDED = 6

local PROFESSIONS = {
    { name = "Alchimie", spell = 2259 },
    { name = "Forge", spell = 2018 },
    { name = "Enchantement", spell = 7411 },
    { name = "Ingenierie", spell = 4036 },
    { name = "Herboristerie", spell = 2366 },
    { name = "Calligraphie", spell = 45357, unlockQuest = QUEST_WOTLK, unlockText = "WotLK" },
    { name = "Joaillerie", spell = 25229, unlockQuest = QUEST_TBC, unlockText = "TBC" },
    { name = "Travail du cuir", spell = 2108 },
    { name = "Minage", spell = 2575 },
    { name = "Depecage", spell = 8613 },
    { name = "Couture", spell = 3908 },
    { name = "Cuisine", spell = 2550 },
    { name = "Secourisme", spell = 3273 },
    { name = "Peche", spell = 7620 }
}

local function IsUnlocked(player, profession)
    if not profession.unlockQuest then return true end
    return player:GetQuestStatus(profession.unlockQuest) == QUEST_STATUS_REWARDED
end

local function ShowMenu(player, creature)
    player:GossipClearMenu()
    for i, profession in ipairs(PROFESSIONS) do
        local label = profession.name
        if not IsUnlocked(player, profession) then
            label = "|cff808080" .. profession.name .. " (" .. profession.unlockText .. " requis)|r"
        end
        player:GossipMenuAddItem(0, label, 0, i)
    end
    player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, MENU_CLOSE)
    player:GossipSendMenu(1, creature)
end

local function OnHello(event, player, creature)
    ShowMenu(player, creature)
end

local function OnSelect(event, player, creature, sender, intid, code)
    if intid == MENU_CLOSE then
        player:GossipComplete()
        return
    end

    local profession = PROFESSIONS[intid]
    if not profession then
        player:GossipComplete()
        return
    end

    if not IsUnlocked(player, profession) then
        player:SendBroadcastMessage("|cffff0000[Maitre des Metiers]|r " .. profession.name .. " sera disponible a partir de " .. profession.unlockText .. ".")
        ShowMenu(player, creature)
        return
    end

    if player:HasSpell(profession.spell) then
        player:SendBroadcastMessage("|cffff9900[Maitre des Metiers]|r Vous connaissez deja : " .. profession.name .. ".")
    else
        player:LearnSpell(profession.spell)
        player:SendBroadcastMessage("|cff00ff00[Maitre des Metiers]|r Vous avez appris : " .. profession.name .. ".")
    end

    ShowMenu(player, creature)
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)

print("=== MAITRE DES METIERS V4 - PROGRESSION TBC/WOTLK - NPC 90000 - CHARGE ===")
