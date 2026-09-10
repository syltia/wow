local NPC_ENTRY = 90001

local MENU_LEARN = 101
local MENU_REMAINING = 102
local MENU_RESET = 103
local MENU_CONFIRM = 201
local MENU_BACK = 202
local MENU_CLOSE = 999


local function FormatMoney(copper)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100

    local text = ""

    if gold > 0 then
        text = text .. gold .. "g "
    end

    if silver > 0 then
        text = text .. silver .. "s "
    end

    if bronze > 0 then
        text = text .. bronze .. "c"
    end

    if text == "" then
        return "Gratuit"
    end

    return text
end


local function GetSpells(player, maxLevel)

    local classId = player:GetClass()

    local sql =
        "SELECT DISTINCT " ..
        "ts.SpellId, " ..
        "ts.MoneyCost, " ..
        "ts.ReqLevel, " ..
        "ts.ReqSkillLine, " ..
        "ts.ReqSkillRank, " ..
        "ts.ReqAbility1, " ..
        "ts.ReqAbility2, " ..
        "ts.ReqAbility3 " ..
        "FROM trainer t " ..
        "JOIN trainer_spell ts ON ts.TrainerId = t.Id " ..
        "WHERE t.Type = 0 " ..
        "AND t.Requirement = " .. classId .. " " ..
        "AND ts.ReqLevel <= " .. maxLevel .. " " ..
        "ORDER BY ts.ReqLevel, ts.SpellId"

    local query = WorldDBQuery(sql)

    if not query then
        return {}
    end

    local spells = {}

    repeat

        table.insert(spells, {
            id = query:GetUInt32(0),
            cost = query:GetUInt32(1),
            level = query:GetUInt32(2),
            skill = query:GetUInt32(3),
            skillRank = query:GetUInt32(4),
            req1 = query:GetUInt32(5),
            req2 = query:GetUInt32(6),
            req3 = query:GetUInt32(7)
        })

    until not query:NextRow()

    return spells
end


local function HasRequirements(player, spell, planned)

    if spell.skill ~= 0 then

        if not player:HasSkill(spell.skill) then
            return false
        end

        if player:GetSkillValue(spell.skill) < spell.skillRank then
            return false
        end

    end


    if spell.req1 ~= 0 then
        if not player:HasSpell(spell.req1) and not planned[spell.req1] then
            return false
        end
    end

    if spell.req2 ~= 0 then
        if not player:HasSpell(spell.req2) and not planned[spell.req2] then
            return false
        end
    end

    if spell.req3 ~= 0 then
        if not player:HasSpell(spell.req3) and not planned[spell.req3] then
            return false
        end
    end

    return true
end


local function GetLearningPlan(player)

    local spells = GetSpells(player, player:GetLevel())

    local plan = {}
    local planned = {}

    local changed = true

    while changed do

        changed = false

        for _, spell in ipairs(spells) do

            if not player:HasSpell(spell.id)
                and not planned[spell.id]
                and HasRequirements(player, spell, planned) then

                planned[spell.id] = true
                table.insert(plan, spell)
                changed = true

            end
        end
    end

    return plan
end


local function GetTotalCost(plan)

    local total = 0

    for _, spell in ipairs(plan) do
        total = total + spell.cost
    end

    return total
end


local function ShowMainMenu(player, creature)

    player:GossipClearMenu()

    player:GossipMenuAddItem(
        0,
        "Apprendre mes sorts disponibles",
        0,
        MENU_LEARN
    )

    player:GossipMenuAddItem(
        0,
        "Voir le cout restant jusqu'au niveau 80",
        0,
        MENU_REMAINING
    )

    player:GossipMenuAddItem(
        0,
        "Reinitialiser mes talents",
        0,
        MENU_RESET
    )

    player:GossipMenuAddItem(
        0,
        "|cffff0000Fermer|r",
        0,
        MENU_CLOSE
    )

    player:GossipSendMenu(1, creature)
end


local function ShowLearnMenu(player, creature)

    local plan = GetLearningPlan(player)

    if #plan == 0 then

        player:SendBroadcastMessage(
            "|cffff9900[Maitre de Classe]|r Vous connaissez deja tous les sorts disponibles pour votre niveau."
        )

        player:GossipComplete()
        return
    end

    local cost = GetTotalCost(plan)

    player:SendBroadcastMessage(
        "|cff00ccff[Maitre de Classe]|r "
        .. #plan
        .. " sort(s) disponible(s)."
    )

    player:SendBroadcastMessage(
        "|cffffff00Cout total : "
        .. FormatMoney(cost)
        .. "|r"
    )


    player:GossipClearMenu()

    player:GossipMenuAddItem(
        0,
        "|cff00ff00Confirmer - "
        .. FormatMoney(cost)
        .. "|r",
        0,
        MENU_CONFIRM
    )

    player:GossipMenuAddItem(
        0,
        "Retour",
        0,
        MENU_BACK
    )

    player:GossipSendMenu(1, creature)
end


local function LearnSpells(player)

    local plan = GetLearningPlan(player)

    if #plan == 0 then
        player:GossipComplete()
        return
    end

    local cost = GetTotalCost(plan)
    local money = player:GetCoinage()


    if money < cost then

        local missing = cost - money

        player:SendBroadcastMessage(
            "|cffff0000[Maitre de Classe]|r Vous n'avez pas assez d'argent."
        )

        player:SendBroadcastMessage(
            "|cffff6600Il vous manque : "
            .. FormatMoney(missing)
            .. "|r"
        )

        player:GossipComplete()
        return
    end


    local learned = 0
    local paid = 0


    for _, spell in ipairs(plan) do

        if not player:HasSpell(spell.id) then

            player:LearnSpell(spell.id)

            if player:HasSpell(spell.id) then
                learned = learned + 1
                paid = paid + spell.cost
            end

        end
    end


    if paid > 0 then
        player:ModifyMoney(-paid)
    end


    player:SendBroadcastMessage(
        "|cff00ff00[Maitre de Classe]|r "
        .. learned
        .. " sort(s) appris."
    )

    player:SendBroadcastMessage(
        "|cffffff00Montant paye : "
        .. FormatMoney(paid)
        .. "|r"
    )

    player:GossipComplete()
end


local function ShowRemaining(player)

    local spells = GetSpells(player, 80)

    local count = 0
    local cost = 0


    for _, spell in ipairs(spells) do

        if not player:HasSpell(spell.id) then

            count = count + 1
            cost = cost + spell.cost

        end
    end


    if count == 0 then

        player:SendBroadcastMessage(
            "|cff00ff00[Maitre de Classe]|r Tous les sorts jusqu'au niveau 80 sont connus."
        )

    else

        player:SendBroadcastMessage(
            "|cff00ccff[Maitre de Classe]|r "
            .. count
            .. " sort(s) restant(s) jusqu'au niveau 80."
        )

        player:SendBroadcastMessage(
            "|cffffff00Cout restant : "
            .. FormatMoney(cost)
            .. "|r"
        )

    end

    player:GossipComplete()
end


local function OnHello(event, player, creature)

    ShowMainMenu(player, creature)
end


local function OnSelect(event, player, creature, sender, intid, code)

    if intid == MENU_LEARN then

        ShowLearnMenu(player, creature)

    elseif intid == MENU_REMAINING then

        ShowRemaining(player)

    elseif intid == MENU_CONFIRM then

        LearnSpells(player)

    elseif intid == MENU_RESET then

        player:ResetTalents()

        player:SendBroadcastMessage(
            "|cff00ff00[Maitre de Classe]|r Vos talents ont ete reinitialises."
        )

        player:GossipComplete()

    elseif intid == MENU_BACK then

        ShowMainMenu(player, creature)

    elseif intid == MENU_CLOSE then

        player:GossipComplete()

    end
end


RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)

print("=== MAITRE DE CLASSE V5 SIMPLE - NPC 90001 - CHARGE ===")
