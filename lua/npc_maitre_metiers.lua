local NPC_ENTRY = 90000

local MENU_CLOSE = 999

local PROFESSIONS = {
    { name = "Alchimie",        spell = 2259 },
    { name = "Forge",           spell = 2018 },
    { name = "Enchantement",    spell = 7411 },
    { name = "Ingenierie",      spell = 4036 },
    { name = "Herboristerie",   spell = 2366 },
    { name = "Calligraphie",    spell = 45357 },
    { name = "Joaillerie",      spell = 25229 },
    { name = "Travail du cuir", spell = 2108 },
    { name = "Minage",          spell = 2575 },
    { name = "Depecage",        spell = 8613 },
    { name = "Couture",         spell = 3908 },

    { name = "Cuisine",         spell = 2550 },
    { name = "Secourisme",      spell = 3273 },
    { name = "Peche",           spell = 7620 }
}


local function ShowMenu(player, creature)

    player:GossipClearMenu()

    for i, profession in ipairs(PROFESSIONS) do

        player:GossipMenuAddItem(
            0,
            profession.name,
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


RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)

print("=== MAITRE DES METIERS - NPC 90000 - CHARGE ===")
