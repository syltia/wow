local NPC_ENTRY = 90000

local MENU_CLOSE = 999

-- mod-individual-progression :
-- progression 8 = PROGRESSION_PRE_TBC = Vanilla termine / debut TBC.
-- Le module enregistre cette progression via la quete cachee 66008.
local VANILLA_COMPLETE_QUEST = 66008
local QUEST_STATUS_REWARDED = 6

local RESTRICTED_PROFESSION_SPELLS = {
    -- Joaillerie : tous les rangs 1 -> 450
    [25229] = "Joaillerie",
    [25230] = "Joaillerie",
    [28894] = "Joaillerie",
    [28895] = "Joaillerie",
    [28897] = "Joaillerie",
    [51311] = "Joaillerie",

    -- Calligraphie : tous les rangs 1 -> 450
    [45357] = "Calligraphie",
    [45358] = "Calligraphie",
    [45359] = "Calligraphie",
    [45360] = "Calligraphie",
    [45361] = "Calligraphie",
    [45363] = "Calligraphie",
}

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

local function RemoveRestrictedProfession(player, spellId, professionName)
    if HasCompletedVanilla(player) then
        return false
    end

    if player:HasSpell(spellId) then
        player:RemoveSpell(spellId)
    end

    player:SendBroadcastMessage(
        "|cffff0000[Progression]|r " .. professionName ..
        " est verrouille jusqu'a la fin de la progression Vanilla."
    )

    return true
end

local function EnforceRestrictedProfessions(player, notify)
    if HasCompletedVanilla(player) then
        return
    end

    local removed = {}

    for spellId, professionName in pairs(RESTRICTED_PROFESSION_SPELLS) do
        if player:HasSpell(spellId) then
            player:RemoveSpell(spellId)
            removed[professionName] = true
        end
    end

    if notify then
        for professionName in pairs(removed) do
            player:SendBroadcastMessage(
                "|cffff0000[Progression]|r " .. professionName ..
                " a ete retire : Vanilla doit etre termine avant de pouvoir apprendre ce metier."
            )
        end
    end
end

local function ShowMenu(player, creature)

    player:GossipClearMenu()

    local vanillaComplete = HasCompletedVanilla(player)

    for i, profession in ipairs(PROFESSIONS) do
        local text = profession.name

        if profession.vanillaLocked and not vanillaComplete then
            text = "|cff888888" .. profession.name .. " - verrouille (fin Vanilla requise)|r"
        end

        player:GossipMenuAddItem(
            0,
            text,
            0,
            i
        )

    end

    player:GossipMenuAddItem(
        0,
        "|cffff0000Fermer|r",
        0,
        MENU_CLOSE
    )

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
            "|cffff9900[Maitre des Metiers]|r Vous connaissez deja : "
            .. profession.name
            .. "."
        )

    else

        player:LearnSpell(profession.spell)

        player:SendBroadcastMessage(
            "|cff00ff00[Maitre des Metiers]|r Vous avez appris : "
            .. profession.name
            .. "."
        )

    end

    ShowMenu(player, creature)
end

-- Protection globale : meme un trainer normal, un autre PNJ ou une commande
-- qui apprend l'un de ces sorts sera corrige immediatement avant la fin de Vanilla.
local function OnLearnSpell(event, player, spellId)
    local professionName = RESTRICTED_PROFESSION_SPELLS[spellId]
    if not professionName or HasCompletedVanilla(player) then
        return
    end

    RemoveRestrictedProfession(player, spellId, professionName)
end

-- Nettoie aussi un personnage qui possederait deja le metier avant le chargement du script.
local function OnLogin(event, player)
    EnforceRestrictedProfessions(player, true)
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)
RegisterPlayerEvent(3, OnLogin)       -- PLAYER_EVENT_ON_LOGIN
RegisterPlayerEvent(44, OnLearnSpell) -- PLAYER_EVENT_ON_LEARN_SPELL

print("=== MAITRE DES METIERS V2 - RESTRICTION VANILLA JOAILLERIE/CALLIGRAPHIE - NPC 90000 - CHARGE ===")
