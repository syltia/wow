-- =========================================================
-- MAITRE DE CLASSE - NPC 90001 - V5 SIMPLE
-- AzerothCore 3.3.5a + ALE/Eluna
-- Apprend les sorts du trainer de classe jusqu'au niveau du joueur,
-- facture MoneyCost, affiche le coût restant jusqu'au niveau 80,
-- et permet de réinitialiser les talents.
-- =========================================================

local NPC_ENTRY = 90001
local LEARN = 1
local RESET_TALENTS = 2
local CLOSE = 999

local TRAINER_BY_CLASS = {
    [1]  = 1,  -- Warrior
    [2]  = 3,  -- Paladin
    [3]  = 7,  -- Hunter
    [4]  = 9,  -- Rogue
    [5]  = 11, -- Priest
    [6]  = 13, -- Death Knight
    [7]  = 14, -- Shaman
    [8]  = 16, -- Mage
    [9]  = 31, -- Warlock
    [11] = 33, -- Druid
}

local function MoneyText(copper)
    copper = math.max(0, tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    local parts = {}
    if gold > 0 then table.insert(parts, gold .. "o") end
    if silver > 0 then table.insert(parts, silver .. "a") end
    if cop > 0 or #parts == 0 then table.insert(parts, cop .. "c") end
    return table.concat(parts, " ")
end

local function QueryTrainerSpells(trainerId, maxLevel)
    return WorldDBQuery(string.format([[
        SELECT SpellId, MoneyCost, ReqLevel
        FROM trainer_spell
        WHERE TrainerId = %u
          AND ReqLevel <= %u
          AND (ReqAbility1 = 0 OR ReqAbility1 IS NULL)
          AND (ReqAbility2 = 0 OR ReqAbility2 IS NULL)
          AND (ReqAbility3 = 0 OR ReqAbility3 IS NULL)
        ORDER BY ReqLevel, SpellId
    ]], trainerId, maxLevel))
end

local function CostForMissing(player, trainerId, maxLevel)
    local q = QueryTrainerSpells(trainerId, maxLevel)
    if not q then return 0 end
    local total = 0
    repeat
        local spell = q:GetUInt32(0)
        local cost = q:GetUInt32(1)
        if spell > 0 and not player:HasSpell(spell) then
            total = total + cost
        end
    until not q:NextRow()
    return total
end

local function LearnAvailable(player, trainerId)
    local q = QueryTrainerSpells(trainerId, player:GetLevel())
    if not q then
        player:SendBroadcastMessage("Aucun sort disponible.")
        return
    end

    local learned, spent = 0, 0
    repeat
        local spell = q:GetUInt32(0)
        local cost = q:GetUInt32(1)
        if spell > 0 and not player:HasSpell(spell) then
            if player:GetCoinage() >= cost then
                player:ModifyMoney(-cost)
                player:LearnSpell(spell)
                learned = learned + 1
                spent = spent + cost
            else
                player:SendBroadcastMessage("Pas assez d'argent pour apprendre tous les sorts disponibles.")
                break
            end
        end
    until not q:NextRow()

    if learned > 0 then
        player:SendBroadcastMessage(string.format("%u sort(s) appris pour %s.", learned, MoneyText(spent)))
    else
        player:SendBroadcastMessage("Tu connais déjà tous les sorts disponibles à ton niveau.")
    end
end

local function OnHello(event, player, creature)
    player:GossipClearMenu()

    local trainerId = TRAINER_BY_CLASS[player:GetClass()]
    if not trainerId then
        player:GossipMenuAddItem(0, "Classe non prise en charge.", 0, CLOSE)
        player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, CLOSE)
        player:GossipSendMenu(1, creature)
        return
    end

    local currentCost = CostForMissing(player, trainerId, player:GetLevel())
    local remaining80 = CostForMissing(player, trainerId, 80)

    player:GossipMenuAddItem(0, "Apprendre les sorts disponibles (" .. MoneyText(currentCost) .. ")", 0, LEARN)
    player:GossipMenuAddItem(0, "Coût restant jusqu'au niveau 80 : " .. MoneyText(remaining80), 0, CLOSE)
    player:GossipMenuAddItem(0, "Réinitialiser mes talents", 0, RESET_TALENTS)
    player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, CLOSE)
    player:GossipSendMenu(1, creature)
end

local function OnSelect(event, player, creature, sender, intid, code)
    local trainerId = TRAINER_BY_CLASS[player:GetClass()]

    if intid == CLOSE then
        player:GossipComplete()
        return
    elseif intid == LEARN and trainerId then
        LearnAvailable(player, trainerId)
        OnHello(event, player, creature)
        return
    elseif intid == RESET_TALENTS then
        player:ResetTalents(true)
        player:SendBroadcastMessage("Talents réinitialisés.")
        OnHello(event, player, creature)
        return
    end

    player:GossipComplete()
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)

print("=== MAITRE DE CLASSE V5 SIMPLE - NPC 90001 - CHARGE ===")
