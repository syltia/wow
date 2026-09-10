local NPC_ENTRY = 90000

local MENU_CLOSE = 999

-- mod-individual-progression :
-- progression 8 = PROGRESSION_PRE_TBC = Vanilla termine / debut TBC.
-- Le module enregistre cette progression via la quete cachee 66008.
local VANILLA_COMPLETE_QUEST = 66008
local QUEST_STATUS_REWARDED = 6

-- Verification periodique : les trainers natifs n'activent pas toujours
-- PLAYER_EVENT_ON_LEARN_SPELL dans le chemin attendu, donc on controle aussi
-- directement les skill lines tant que Vanilla n'est pas termine.
local ENFORCE_DELAY_MS = 500

local RESTRICTED_PROFESSIONS = {
    {
        name = "Joaillerie",
        skill = 755,
        spells = {25229, 25230, 28894, 28895, 28897, 51311}
    },
    {
        name = "Calligraphie",
        skill = 773,
        spells = {45357, 45358, 45359, 45360, 45361, 45363}
    }
}

local RESTRICTED_PROFESSION_SPELLS = {}
for _, profession in ipairs(RESTRICTED_PROFESSIONS) do
    for _, spellId in ipairs(profession.spells) do
        RESTRICTED_PROFESSION_SPELLS[spellId] = profession.name
    end
end

local PROFESSIONS = {
    { name = "Alchimie",        spell = 2259 },
    { name = "Forge",           spell = 2018 },
    { name = "Enchantement",    spell = 7411 },
    { name = "Ingenierie",      spell = 4036 },
    { name = "Herboristerie",   spell = 2366 },
    { name = "Calligraphie",    spell = 45357, vanillaLocked = true },
    { name = "Joaillerie",      spell = 25229, vanillaLocked = true },
    { name = "Travail du cuir", spell = 2108 },
    { name = "Minage",          spell = 2575 },
    { name = "Depecage",        spell = 8613 },
    { name = "Couture",         spell = 3908 },

    { name = "Cuisine",         spell = 2550 },
    { name = "Secourisme",      spell = 3273 },
    { name = "Peche",           spell = 7620 }
}

local function HasCompletedVanilla(player)
    return player:GetQuestStatus(VANILLA_COMPLETE_QUEST) == QUEST_STATUS_REWARDED
end

local function FindRestrictedProfessionByName(name)
    for _, profession in ipairs(RESTRICTED_PROFESSIONS) do
        if profession.name == name then
            return profession
        end
    end
    return nil
end

local function PlayerHasRestrictedProfession(player, profession)
    if player:HasSkill(profession.skill) or player:GetSkillValue(profession.skill) > 0 then
        return true
    end

    for _, spellId in ipairs(profession.spells) do
        if player:HasSpell(spellId) then
            return true
        end
    end

    return false
end

local function RemoveRestrictedProfession(player, profession, notify)
    if HasCompletedVanilla(player) then
        return false
    end

    if not PlayerHasRestrictedProfession(player, profession) then
        return false
    end

    -- Retire tous les rangs connus de la profession.
    for _, spellId in ipairs(profession.spells) do
        if player:HasSpell(spellId) then
            player:RemoveSpell(spellId)
        end
    end

    -- Securite supplementaire : retire directement la skill line.
    -- Cela couvre le cas d'un trainer natif qui ajoute la profession sans que
    -- PLAYER_EVENT_ON_LEARN_SPELL soit exploitable au bon moment.
    if player:HasSkill(profession.skill) or player:GetSkillValue(profession.skill) > 0 then
        player:SetSkill(profession.skill, 0, 0, 0)
    end

    if notify then
        player:SendBroadcastMessage(
            "|cffff0000[Progression]|r " .. profession.name ..
            " a ete retire : Vanilla doit etre termine avant de pouvoir apprendre ce metier."
        )
    end

    return true
end

local function EnforceRestrictedProfessions(player, notify)
    if HasCompletedVanilla(player) then
        return false
    end

    local removedAny = false

    for _, profession in ipairs(RESTRICTED_PROFESSIONS) do
        if RemoveRestrictedProfession(player, profession, notify) then
            removedAny = true
        end
    end

    return removedAny
end

local function ShowMenu(player, creature)
    player:GossipClearMenu()

    local vanillaComplete = HasCompletedVanilla(player)

    for i, profession in ipairs(PROFESSIONS) do
        local text = profession.name

        if profession.vanillaLocked and not vanillaComplete then
            text = "|cff888888" .. profession.name .. " - verrouille (fin Vanilla requise)|r"
        end

        player:GossipMenuAddItem(0, text, 0, i)
    end

    player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, MENU_CLOSE)
    player:GossipSendMenu(1, creature)
end

local function OnHello(event, player, creature)
    EnforceRestrictedProfessions(player, false)
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

    if profession.vanillaLocked and not HasCompletedVanilla(player) then
        player:SendBroadcastMessage(
            "|cffff0000[Maitre des Metiers]|r " .. profession.name ..
            " est disponible uniquement apres avoir termine Vanilla."
        )
        ShowMenu(player, creature)
        return
    end

    if player:HasSpell(profession.spell) then
        player:SendBroadcastMessage(
            "|cffff9900[Maitre des Metiers]|r Vous connaissez deja : " ..
            profession.name .. "."
        )
    else
        player:LearnSpell(profession.spell)
        player:SendBroadcastMessage(
            "|cff00ff00[Maitre des Metiers]|r Vous avez appris : " ..
            profession.name .. "."
        )
    end

    ShowMenu(player, creature)
end

-- Garde le hook ALE lorsqu'il est emis : il permet une correction immediate
-- pour certains chemins d'apprentissage.
local function OnLearnSpell(event, player, spellId)
    local professionName = RESTRICTED_PROFESSION_SPELLS[spellId]
    if not professionName or HasCompletedVanilla(player) then
        return
    end

    local profession = FindRestrictedProfessionByName(professionName)
    if profession then
        RemoveRestrictedProfession(player, profession, true)
    end
end

-- Filet de securite global. Les events du Player disparaissent a la deconnexion.
local function PeriodicEnforce(eventId, delay, repeats, player)
    if HasCompletedVanilla(player) then
        return
    end

    EnforceRestrictedProfessions(player, true)
end

local function OnLogin(event, player)
    -- Nettoyage immediat d'un personnage qui possederait deja le metier.
    EnforceRestrictedProfessions(player, true)

    -- Controle continu tant que le personnage reste connecte.
    player:RegisterEvent(PeriodicEnforce, ENFORCE_DELAY_MS, 0)
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)
RegisterPlayerEvent(3, OnLogin)       -- PLAYER_EVENT_ON_LOGIN
RegisterPlayerEvent(44, OnLearnSpell) -- PLAYER_EVENT_ON_LEARN_SPELL

print("=== MAITRE DES METIERS V3 - VERROU GLOBAL VANILLA SKILL LINE - NPC 90000 - CHARGE ===")
