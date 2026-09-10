-- =========================================================
-- MAITRE DES METIERS - NPC 90000
-- AzerothCore 3.3.5a + ALE/Eluna
-- Apprend uniquement le sort de base du métier choisi.
-- Ne force pas 450 et ne limite pas à deux métiers primaires.
-- =========================================================

local NPC_ENTRY = 90000
local CLOSE = 999

local PROFESSIONS = {
    { name = "Alchimie",        spell = 2259  },
    { name = "Forge",           spell = 2018  },
    { name = "Enchantement",    spell = 7411  },
    { name = "Ingénierie",      spell = 4036  },
    { name = "Herboristerie",   spell = 2366  },
    { name = "Joaillerie",      spell = 25229 },
    { name = "Travail du cuir", spell = 2108  },
    { name = "Minage",          spell = 2575  },
    { name = "Dépeçage",        spell = 8613  },
    { name = "Couture",         spell = 3908  },
    { name = "Calligraphie",    spell = 45357 },
    { name = "Cuisine",         spell = 2550  },
    { name = "Secourisme",      spell = 3273  },
    { name = "Pêche",           spell = 7620  },
}

local function OnHello(event, player, creature)
    player:GossipClearMenu()

    for i, prof in ipairs(PROFESSIONS) do
        local prefix = player:HasSpell(prof.spell) and "|cff808080" or "|cffffffff"
        player:GossipMenuAddItem(0, prefix .. prof.name .. "|r", 0, i)
    end

    player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, CLOSE)
    player:GossipSendMenu(1, creature)
end

local function OnSelect(event, player, creature, sender, intid, code)
    if intid == CLOSE then
        player:GossipComplete()
        return
    end

    local prof = PROFESSIONS[intid]
    if not prof then
        player:GossipComplete()
        return
    end

    if not player:HasSpell(prof.spell) then
        player:LearnSpell(prof.spell)
        player:SendBroadcastMessage("Métier appris : " .. prof.name .. ".")
    else
        player:SendBroadcastMessage("Tu connais déjà : " .. prof.name .. ".")
    end

    OnHello(event, player, creature)
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)

print("=== MAITRE DES METIERS - NPC 90000 - CHARGE ===")
