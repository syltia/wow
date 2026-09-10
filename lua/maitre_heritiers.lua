-- =========================================================
-- MAITRE DES HERITIERS - NPC 90004 - V1
-- Boost rerolls 60 / 70 / 80
-- =========================================================

local NPC_ENTRY = 90004
local CLOSE = 999
local BOOST60 = 60
local BOOST70 = 70
local BOOST80 = 80
local CONFIRM60 = 260
local CONFIRM70 = 270
local CONFIRM80 = 280

-- Sacs confortables, sans donner les meilleurs sacs du jeu.
local BAGS = {
    [60] = {14046, 14046, 14046, 14046}, -- Runecloth Bag, 14 slots
    [70] = {21841, 21841, 21841, 21841}, -- Netherweave Bag, 16 slots
    [80] = {41599, 41599, 41599, 41599}, -- Frostweave Bag, 20 slots
}

-- T0 Vanilla complet par classe (bleu donjons / pre-raid).
local T0 = {
    [1]  = {16730,16731,16732,16733,16734,16735,16736,16737}, -- Guerrier: Vaillance
    [2]  = {16722,16723,16724,16725,16726,16727,16728,16729}, -- Paladin: Sancteforge
    [3]  = {16674,16675,16676,16677,16678,16679,16680,16681}, -- Chasseur: Bestiaire
    [4]  = {16707,16708,16709,16710,16711,16712,16713,16721}, -- Voleur: Sombreruse
    [5]  = {16690,16691,16692,16693,16694,16695,16696,16697}, -- Pretre: Devot
    [7]  = {16666,16667,16668,16669,16670,16671,16672,16673}, -- Chaman: Elements
    [8]  = {16682,16683,16684,16685,16686,16687,16688,16689}, -- Mage: Magistere
    [9]  = {16698,16699,16700,16701,16702,16703,16704,16705}, -- Demoniste: Brume-funeste
    [11] = {16706,16714,16715,16716,16717,16718,16719,16720}, -- Druide: Coeur-sauvage
}

local function AddItems(player, list)
    if not list then return end
    for _, item in ipairs(list) do
        player:AddItem(item, 1)
    end
end

-- Equipe directement les 4 sacs supplementaires (slots inventaire 19 a 22).
local function GiveBags(player, level)
    local bags = BAGS[level]
    if not bags then return end

    for i = 1, 4 do
        local bagSlot = 18 + i -- 19,20,21,22
        local current = player:GetEquippedItemBySlot(bagSlot)
        if current then
            player:RemoveItem(current, 1)
        end
        player:EquipItem(bags[i], bagSlot)
    end
end

-- =========================================================
-- METIERS
-- On ne cree aucun metier. On augmente uniquement les skills
-- que le reroll possede deja.
-- 60 = 300, 70 = 375, 80 = 450.
-- =========================================================

local PROFESSION_SKILLS = {
    129, -- First Aid
    164, -- Blacksmithing
    165, -- Leatherworking
    171, -- Alchemy
    182, -- Herbalism
    185, -- Cooking
    186, -- Mining
    197, -- Tailoring
    202, -- Engineering
    333, -- Enchanting
    356, -- Fishing
    393, -- Skinning
    755, -- Jewelcrafting
    773, -- Inscription
}


local function BoostExistingSkills(player, level)
    local cap = 300
    local step = 3

    if level >= 70 then
        cap = 375
        step = 4
    end

    if level >= 80 then
        cap = 450
        step = 5
    end

    for _, skillId in ipairs(PROFESSION_SKILLS) do
        local current = player:GetSkillValue(skillId)
        if current and current > 0 then
            player:SetSkill(skillId, step, cap, cap)
        end
    end
end

-- =========================================================
-- REPUTATIONS DU COMPTE
-- Pour chaque faction, on prend le meilleur standing atteint
-- par n'importe quel personnage du compte.
-- On ne baisse jamais une reputation deja superieure sur le reroll.
-- =========================================================

local function CopyBestAccountReputations(player)
    local account = player:GetAccountId()
    local guid = player:GetGUIDLow()

    local q = CharDBQuery(string.format([[
        SELECT cr.faction, MAX(cr.standing)
        FROM character_reputation cr
        INNER JOIN characters c ON c.guid = cr.guid
        WHERE c.account = %u
          AND cr.guid <> %u
        GROUP BY cr.faction
    ]], account, guid))

    if not q then
        return
    end

    repeat
        local faction = q:GetUInt32(0)
        local standing = q:GetInt32(1)

        if faction and faction > 0 and standing then
            local current = player:GetReputation(faction)
            if not current or standing > current then
                player:SetReputation(faction, standing)
            end
        end
    until not q:NextRow()
end

local function MaxOtherCharacterLevel(player)
    local account = player:GetAccountId()
    local guid = player:GetGUIDLow()
    local q = CharDBQuery(string.format(
        "SELECT MAX(level) FROM characters WHERE account=%u AND guid<>%u",
        account, guid
    ))
    if not q or q:IsNull(0) then return 0 end
    return q:GetUInt8(0)
end

local CLASS_TRAINER_IDS = {
    [1]  = 1,   -- Guerrier
    [2]  = 3,   -- Paladin
    [3]  = 7,   -- Chasseur
    [4]  = 9,   -- Voleur
    [5]  = 11,  -- Pretre
    [6]  = 13,  -- Chevalier de la mort
    [7]  = 14,  -- Chaman
    [8]  = 16,  -- Mage
    [9]  = 31,  -- Demoniste
    [11] = 33,  -- Druide
}

local function LearnClassSpells(player, targetLevel)
    local trainerId = CLASS_TRAINER_IDS[player:GetClass()]

    if not trainerId then
        player:SendBroadcastMessage("|cffff0000[Maitre des Heritiers]|r Classe non supportee pour l'apprentissage automatique des sorts.")
        return
    end

    -- trainer.Id correspond aux vrais trainers de classe AzerothCore.
    -- On ne cherche donc PAS de ClassMask (absent de ton schema).
    local q = WorldDBQuery(string.format([[
        SELECT SpellId
        FROM trainer_spell
        WHERE TrainerId = %u
          AND ReqLevel <= %u
          AND (ReqAbility1 = 0 OR ReqAbility1 IS NULL)
          AND (ReqAbility2 = 0 OR ReqAbility2 IS NULL)
          AND (ReqAbility3 = 0 OR ReqAbility3 IS NULL)
        ORDER BY ReqLevel, SpellId
    ]], trainerId, targetLevel))

    if not q then
        player:SendBroadcastMessage("|cffff0000[Maitre des Heritiers]|r Aucun sort de classe trouve pour ce palier.")
        return
    end

    repeat
        local spell = q:GetUInt32(0)
        if spell and spell > 0 then
            player:LearnSpell(spell)
        end
    until not q:NextRow()
end

-- =========================================================
-- COMPETENCES D'ARMES
-- Monte uniquement les armes autorisees par la classe.
-- Le boost met les competences a 290 (pas 300).
-- 60 / 70 / 80 : meme principe, avec le cap de la classe.
-- =========================================================

local WEAPON_SKILLS = {
    AXES = 44,
    SWORDS = 43,
    MACES = 54,
    TWO_HANDED_SWORDS = 55,
    TWO_HANDED_MACES = 160,
    TWO_HANDED_AXES = 172,
    DAGGERS = 173,
    THROWN = 176,
    POLEARMS = 228,
    FIST = 473,
    BOWS = 45,
    GUNS = 46,
    CROSSBOWS = 226,
    STAVES = 136,
    WANDS = 228 + 1, -- 229
    DEFENSE = 95,
    UNARMED = 162,
}

local CLASS_WEAPON_SKILLS = {
    -- Guerrier : quasiment toutes les armes Vanilla.
    [1] = {
        43, 44, 45, 46, 54, 55, 95, 136, 160, 162, 172, 173, 176, 226, 228, 473
    },

    -- Paladin
    [2] = {
        43, 44, 54, 55, 160, 172, 228, 162, 95
    },

    -- Chasseur
    [3] = {
        43, 44, 45, 46, 55, 136, 162, 172, 173, 176, 226, 228, 473, 95
    },

    -- Voleur
    [4] = {
        43, 54, 173, 176, 45, 46, 226, 473, 162, 95
    },

    -- Pretre
    [5] = {
        54, 136, 173, 229, 162, 95
    },

    -- Chevalier de la mort (utile surtout pour les boosts 70/80)
    [6] = {
        43, 44, 54, 55, 160, 172, 173, 226, 228, 473, 162, 95
    },

    -- Chaman
    [7] = {
        44, 54, 160, 172, 173, 136, 473, 162, 95
    },

    -- Mage
    [8] = {
        43, 136, 173, 229, 162, 95
    },

    -- Demoniste
    [9] = {
        43, 136, 173, 229, 162, 95
    },

    -- Druide
    [11] = {
        54, 136, 173, 228, 473, 162, 95
    },
}

local function BoostClassWeaponSkills(player)
    local skills = CLASS_WEAPON_SKILLS[player:GetClass()]
    if not skills then
        return
    end

    for _, skillId in ipairs(skills) do
        player:SetSkill(skillId, 1, 290, 290)
    end
end

local function LearnRiding(player, level)
    player:LearnSpell(33388) -- Apprenti
    player:LearnSpell(33391) -- Compagnon

    if level >= 60 then
        player:LearnSpell(34090) -- Expert 225 / vol 150%
        player:SetSkill(762, 3, 225, 225)
    end
    if level >= 70 then
        player:LearnSpell(34091) -- Artisan 300 / vol 280%
        player:SetSkill(762, 4, 300, 300)
    end
    if level >= 80 then
        player:LearnSpell(54197) -- Vol par temps froid
    end
end

local EQUIPMENT_SLOTS = {
    HEAD = 0, NECK = 1, SHOULDERS = 2, BODY = 3, CHEST = 4,
    WAIST = 5, LEGS = 6, FEET = 7, WRISTS = 8, HANDS = 9,
    FINGER1 = 10, FINGER2 = 11, TRINKET1 = 12, TRINKET2 = 13,
    BACK = 14, MAINHAND = 15, OFFHAND = 16, RANGED = 17,
}

-- =========================================================
-- EQUIPEMENT
-- On vide d'abord les 19 slots d'equipement : l'avertissement
-- du menu previent deja le joueur que son gear sera detruit.
-- =========================================================

local function RemoveEquippedGear(player)
    for slot = 0, 18 do
        local item = player:GetEquippedItemBySlot(slot)
        if item then
            player:RemoveItem(item, 1)
        end
    end
end

local function RemoveEquipped(player, slot)
    local item = player:GetEquippedItemBySlot(slot)
    if item then
        player:RemoveItem(item, 1)
    end
end

local function EquipBestItem(player, level, invTypes, slot, mask, excludeEntries, extraWhere)
    local types = table.concat(invTypes, ",")
    local exclude = ""

    if excludeEntries and #excludeEntries > 0 then
        local parts = {}
        for _, entry in ipairs(excludeEntries) do
            parts[#parts + 1] = tostring(entry)
        end
        exclude = " AND entry NOT IN (" .. table.concat(parts, ",") .. ")"
    end

    extraWhere = extraWhere or ""

    local q = WorldDBQuery(string.format([[
        SELECT entry
        FROM item_template
        WHERE Quality = 3
          AND RequiredLevel BETWEEN %u AND %u
          AND InventoryType IN (%s)
          AND (AllowableClass = -1 OR (AllowableClass & %u) <> 0)
          %s
          %s
        ORDER BY ItemLevel DESC, entry ASC
        LIMIT 1
    ]], math.max(1, level - 5), level, types, mask, exclude, extraWhere))

    if q then
        local entry = q:GetUInt32(0)
        if player:CanEquipItem(entry, slot) then
            local item = player:EquipItem(entry, slot)
            if item then
                return entry
            end
        end
    end

    return nil
end

local function NoAttackPowerFilter()
    -- Exclut strictement PA, PA a distance et PA feral.
    return [[
      AND stat_type1 NOT IN (38,39,40)
      AND stat_type2 NOT IN (38,39,40)
      AND stat_type3 NOT IN (38,39,40)
      AND stat_type4 NOT IN (38,39,40)
      AND stat_type5 NOT IN (38,39,40)
      AND stat_type6 NOT IN (38,39,40)
      AND stat_type7 NOT IN (38,39,40)
      AND stat_type8 NOT IN (38,39,40)
      AND stat_type9 NOT IN (38,39,40)
      AND stat_type10 NOT IN (38,39,40)
    ]]
end

local function CasterStatFilter(class)
    if class == 5 or class == 8 or class == 9 then
        return [[
          AND stat_type1 NOT IN (38,39,40)
          AND stat_type2 NOT IN (38,39,40)
          AND stat_type3 NOT IN (38,39,40)
          AND stat_type4 NOT IN (38,39,40)
          AND stat_type5 NOT IN (38,39,40)
          AND stat_type6 NOT IN (38,39,40)
          AND stat_type7 NOT IN (38,39,40)
          AND stat_type8 NOT IN (38,39,40)
          AND stat_type9 NOT IN (38,39,40)
          AND stat_type10 NOT IN (38,39,40)
          AND (
              stat_type1 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type2 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type3 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type4 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type5 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type6 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type7 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type8 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type9 IN (5,6,18,19,20,21,25,26,29,30)
           OR stat_type10 IN (5,6,18,19,20,21,25,26,29,30)
          )
        ]]
    end
    return ""
end


local function EquipT0(player, level)
    if level ~= 60 then
        return {}
    end

    local class = player:GetClass()
    local list = T0[class]
    if not list then
        return {}
    end

    local equipped = {}

    for _, entry in ipairs(list) do
        local q = WorldDBQuery(string.format(
            "SELECT InventoryType FROM item_template WHERE entry=%u LIMIT 1",
            entry
        ))

        if q then
            local invType = q:GetUInt32(0)
            local slot = nil

            if invType == 1 then
                slot = EQUIPMENT_SLOTS.HEAD
            elseif invType == 3 then
                slot = EQUIPMENT_SLOTS.SHOULDERS
            elseif invType == 5 or invType == 20 then
                -- 5 = Chest, 20 = Robe
                slot = EQUIPMENT_SLOTS.CHEST
            elseif invType == 6 then
                slot = EQUIPMENT_SLOTS.WAIST
            elseif invType == 7 then
                slot = EQUIPMENT_SLOTS.LEGS
            elseif invType == 8 then
                slot = EQUIPMENT_SLOTS.FEET
            elseif invType == 9 then
                slot = EQUIPMENT_SLOTS.WRISTS
            elseif invType == 10 then
                slot = EQUIPMENT_SLOTS.HANDS
            end

            if slot and player:CanEquipItem(entry, slot) then
                local item = player:EquipItem(entry, slot)
                if item then
                    equipped[slot] = entry
                end
            end
        end
    end

    return equipped
end

local function GiveBlueGear(player, level)
    local class = player:GetClass()
    local mask = 2 ^ (class - 1)

    -- Niveau 60 : T0 prioritaire.
    local t0 = EquipT0(player, level)

    local caster = (class == 5 or class == 7 or class == 8 or class == 9)
    local casterFilter = caster and CasterStatFilter(class) or ""

    -- Cou : pour les casters, on exige un profil caster et aucune PA.
    -- Chaman niveau 60 : collier fixe avec spell power confirme.
    if class == 7 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.NECK)
        player:EquipItem(24096, EQUIPMENT_SLOTS.NECK) -- Heartblood Prayer Beads
    else
        local neckFilter = casterFilter
        EquipBestItem(player, level, {2}, EQUIPMENT_SLOTS.NECK, mask, nil, neckFilter)
    end

    -- Armure manquante : pour les casters, aucun objet contenant de la PA.
    local armorSlots = {
        {1, EQUIPMENT_SLOTS.HEAD},
        {3, EQUIPMENT_SLOTS.SHOULDERS},
        {5, EQUIPMENT_SLOTS.CHEST},
        {6, EQUIPMENT_SLOTS.WAIST},
        {7, EQUIPMENT_SLOTS.LEGS},
        {8, EQUIPMENT_SLOTS.FEET},
        {9, EQUIPMENT_SLOTS.WRISTS},
        {10, EQUIPMENT_SLOTS.HANDS},
        {16, EQUIPMENT_SLOTS.BACK},
    }

    for _, data in ipairs(armorSlots) do
        local invType = data[1]
        local slot = data[2]
        if not t0[slot] then
            EquipBestItem(player, level, {invType}, slot, mask, nil, casterFilter)
        end
    end

    -- Anneaux : deux objets differents, sans PA pour les casters.
    local ring1 = EquipBestItem(
        player, level, {11}, EQUIPMENT_SLOTS.FINGER1, mask, nil,
        caster and casterFilter or ""
    )
    EquipBestItem(
        player, level, {11}, EQUIPMENT_SLOTS.FINGER2, mask,
        ring1 and {ring1} or nil,
        caster and casterFilter or ""
    )

    -- Bijoux : on privilegie le bleu, mais on accepte un objet de qualite
    -- inferieure si la base n'a pas de bijou bleu compatible.
    local trinketFilter = caster and NoAttackPowerFilter() or ""
    local trinket1 = EquipBestItem(
        player, level, {12}, EQUIPMENT_SLOTS.TRINKET1, mask, nil, trinketFilter
    )
    local trinket2 = EquipBestItem(
        player, level, {12}, EQUIPMENT_SLOTS.TRINKET2, mask,
        trinket1 and {trinket1} or nil, trinketFilter
    )

    -- Si aucun bijou bleu n'existe pour la classe, chercher un bijou de
    -- qualite 2+ sans PA. Cette seconde passe evite de laisser les deux
    -- slots vides.
    if caster and (not trinket1 or not trinket2) then
        local function EquipTrinketFallback(slot, exclude)
            local excludeSql = ""
            if exclude then
                excludeSql = string.format(" AND entry <> %u", exclude)
            end

            local q = WorldDBQuery(string.format([[
                SELECT entry
                FROM item_template
                WHERE Quality >= 2
                  AND RequiredLevel BETWEEN %u AND %u
                  AND InventoryType = 12
                  AND (AllowableClass = -1 OR (AllowableClass & %u) <> 0)
                  AND stat_type1 NOT IN (38,39,40)
                  AND stat_type2 NOT IN (38,39,40)
                  AND stat_type3 NOT IN (38,39,40)
                  AND stat_type4 NOT IN (38,39,40)
                  AND stat_type5 NOT IN (38,39,40)
                  AND stat_type6 NOT IN (38,39,40)
                  AND stat_type7 NOT IN (38,39,40)
                  AND stat_type8 NOT IN (38,39,40)
                  AND stat_type9 NOT IN (38,39,40)
                  AND stat_type10 NOT IN (38,39,40)
                  %s
                ORDER BY Quality DESC, ItemLevel DESC, entry ASC
                LIMIT 1
            ]], math.max(1, level - 5), level, mask, excludeSql))

            if q then
                local entry = q:GetUInt32(0)
                if player:CanEquipItem(entry, slot) and player:EquipItem(entry, slot) then
                    return entry
                end
            end
            return nil
        end

        if not trinket1 then
            trinket1 = EquipTrinketFallback(EQUIPMENT_SLOTS.TRINKET1, trinket2)
        end
        if not trinket2 then
            trinket2 = EquipTrinketFallback(EQUIPMENT_SLOTS.TRINKET2, trinket1)
        end
    end

    -- Hunter 60 : bijoux physiques bleus uniquement, pas de bijou caster.
    if class == 3 and level == 60 then
        local hunterTrinket = [[
          AND Quality = 3
          AND (
               stat_type1 IN (3,4,7,19,20,31,32,36,38,39)
            OR stat_type2 IN (3,4,7,19,20,31,32,36,38,39)
            OR stat_type3 IN (3,4,7,19,20,31,32,36,38,39)
            OR stat_type4 IN (3,4,7,19,20,31,32,36,38,39)
          )
        ]]
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET1)
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET2)

        -- Deux vrais bijoux Hunter niveau 60.
        player:EquipItem(13965, EQUIPMENT_SLOTS.TRINKET1) -- Blackhand's Breadth
        player:EquipItem(18473, EQUIPMENT_SLOTS.TRINKET2) -- Royal Seal of Eldre'Thalas (Hunter)
    end

    -- Druide Feral Tank 60 : bijoux physiques fixes, aucun caster/heal.
    if class == 11 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET1)
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET2)

        player:EquipItem(11815, EQUIPMENT_SLOTS.TRINKET1) -- Hand of Justice
        player:EquipItem(13966, EQUIPMENT_SLOTS.TRINKET2) -- Mark of Tyranny
    end

    -- Paladin niveau 60 : Tank/Protection, Vanilla bleu/pre-raid.
    -- On garde Lightforge comme base et on force les accessoires tank/physiques.
    if class == 2 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.NECK)
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET1)
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET2)

        player:EquipItem(13091, EQUIPMENT_SLOTS.NECK)      -- Medallion of Grand Marshal Morris

        RemoveEquipped(player, EQUIPMENT_SLOTS.FINGER1)
        RemoveEquipped(player, EQUIPMENT_SLOTS.FINGER2)
        player:EquipItem(13098, EQUIPMENT_SLOTS.FINGER1)   -- Painweaver Band
        player:EquipItem(18500, EQUIPMENT_SLOTS.FINGER2)   -- Tarnished Elven Ring

        player:EquipItem(11810, EQUIPMENT_SLOTS.TRINKET1) -- Force of Will
        player:EquipItem(13966, EQUIPMENT_SLOTS.TRINKET2) -- Mark of Tyranny
    end

    -- Pretre Heal 60 : set fixe VANILLA uniquement.
    -- On evite la selection dynamique pour ne jamais recuperer une piece BC.
    if class == 5 and level == 60 then
        -- Valides : jambes + cape.
        -- Le reste est laisse au set/equipement precedent en attendant
        -- de choisir de vraies pieces Vanilla Heal.
        local priestHealArmor = {
            {EQUIPMENT_SLOTS.WAIST, 13956}, -- Clutch of Andros : ceinture caster Vanilla
            {EQUIPMENT_SLOTS.LEGS, 18386},  -- Padre's Trousers
            {EQUIPMENT_SLOTS.BACK, 13386},  -- Archivist Cape
        }

        for _, data in ipairs(priestHealArmor) do
            RemoveEquipped(player, data[1])
            player:EquipItem(data[2], data[1])
        end
    end

    -- Pretre niveau 60 : Heal, bleu/pre-raid.
    -- Pas besoin de conserver le T0 complet : on remplace par des pieces heal/caster coherentes.
    if class == 5 and level == 60 then
        -- Accessoires heal/caster fixes.
        RemoveEquipped(player, EQUIPMENT_SLOTS.NECK)
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET1)
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET2)

        player:EquipItem(12103, EQUIPMENT_SLOTS.NECK)     -- Star of Mystaria
        player:EquipItem(12930, EQUIPMENT_SLOTS.TRINKET1) -- Briarwood Reed
        player:EquipItem(18469, EQUIPMENT_SLOTS.TRINKET2) -- Royal Seal of Eldre'Thalas (Priest)
    end

    -- Voleur 60 : anneaux physiques fixes, pas d'Int/Spell Power.
    if class == 4 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.FINGER1)
        RemoveEquipped(player, EQUIPMENT_SLOTS.FINGER2)
        player:EquipItem(18500, EQUIPMENT_SLOTS.FINGER1) -- Tarnished Elven Ring
        player:EquipItem(13098, EQUIPMENT_SLOTS.FINGER2) -- Painweaver Band
    end

    -- Voleur 60 : deux bijoux physiques, jamais de bijou caster.
    if class == 4 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET1)
        RemoveEquipped(player, EQUIPMENT_SLOTS.TRINKET2)
        player:EquipItem(13965, EQUIPMENT_SLOTS.TRINKET1) -- Blackhand's Breadth
        player:EquipItem(18465, EQUIPMENT_SLOTS.TRINKET2) -- Royal Seal of Eldre'Thalas (Rogue)
    end

    -- CASters : choix stricts pour eviter les armes PA.
    if caster then
        local staffFilter = CasterStatFilter(class) .. " AND class = 2 AND subclass = 10"
        local offFilter = CasterStatFilter(class) .. " AND class = 4"

        -- Mage / Pretre / Demoniste : baton + main gauche caster + baguette.
        if class == 5 or class == 8 or class == 9 then
            EquipBestItem(
                player, level, {17}, EQUIPMENT_SLOTS.MAINHAND, mask, nil, staffFilter
            )
            EquipBestItem(
                player, level, {23}, EQUIPMENT_SLOTS.OFFHAND, mask, nil, offFilter
            )
            local wandFilter = CasterStatFilter(class) .. " AND class = 2 AND subclass = 19"
            EquipBestItem(
                player, level, {26}, EQUIPMENT_SLOTS.RANGED, mask, nil, wandFilter
            )
            return
        end

        -- Chaman Elementaire : equipement fixe niveau 60, confirme present dans la DB.
        if class == 7 then
            if level == 60 then
                -- Masse 1M caster: Sceptre of Smiting
                RemoveEquipped(player, EQUIPMENT_SLOTS.MAINHAND)
                player:EquipItem(19908, EQUIPMENT_SLOTS.MAINHAND)

                -- Bouclier caster: Zulian Defender (+Endu/+Int/+Esprit)
                RemoveEquipped(player, EQUIPMENT_SLOTS.OFFHAND)
                player:EquipItem(19915, EQUIPMENT_SLOTS.OFFHAND)

                -- Relique chaman: Totem of the Storm
                RemoveEquipped(player, EQUIPMENT_SLOTS.RANGED)
                player:EquipItem(23199, EQUIPMENT_SLOTS.RANGED)
            else
                -- 70/80 : garde la selection dynamique sans PA.
                local shamanFilter = [[
                  AND stat_type1 NOT IN (38,39,40)
                  AND stat_type2 NOT IN (38,39,40)
                  AND stat_type3 NOT IN (38,39,40)
                  AND stat_type4 NOT IN (38,39,40)
                  AND stat_type5 NOT IN (38,39,40)
                  AND stat_type6 NOT IN (38,39,40)
                  AND stat_type7 NOT IN (38,39,40)
                  AND stat_type8 NOT IN (38,39,40)
                  AND stat_type9 NOT IN (38,39,40)
                  AND stat_type10 NOT IN (38,39,40)
                ]]
                EquipBestItem(player, level, {13}, EQUIPMENT_SLOTS.MAINHAND, mask, nil,
                    shamanFilter .. " AND class = 2 AND subclass = 4")
                EquipBestItem(player, level, {14}, EQUIPMENT_SLOTS.OFFHAND, mask, nil,
                    shamanFilter .. " AND class = 4 AND subclass = 6")
                EquipBestItem(player, level, {28}, EQUIPMENT_SLOTS.RANGED, mask, nil,
                    shamanFilter .. " AND class = 4 AND subclass = 9")
            end
            return
        end
    end

    -- Guerrier Fury niveau 60 : duo Dal'Rend d'UBRS.
    if class == 1 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.MAINHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.OFFHAND)

        player:EquipItem(12940, EQUIPMENT_SLOTS.MAINHAND) -- Dal'Rend's Sacred Charge
        player:EquipItem(12939, EQUIPMENT_SLOTS.OFFHAND)  -- Dal'Rend's Tribal Guardian

        -- Arme a distance dynamique.
        EquipBestItem(player, level, {15,18,19,26}, EQUIPMENT_SLOTS.RANGED, mask)
        return
    end

    -- Chasseur niveau 60 : gear bleu/pre-raid uniquement.
    if class == 3 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.MAINHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.OFFHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.RANGED)

        -- S'assure que le Hunter peut vraiment utiliser le duo d'epees.
        player:LearnSpell(201) -- Epées 1 main
        player:LearnSpell(674) -- Ambidextrie

        -- Melee : duo Dal'Rend, bleu UBRS.
        player:EquipItem(12940, EQUIPMENT_SLOTS.MAINHAND) -- Dal'Rend's Sacred Charge
        player:EquipItem(12939, EQUIPMENT_SLOTS.OFFHAND)  -- Dal'Rend's Tribal Guardian

        -- Distance : vrai arc bleu pre-raid, non deprecated.
        player:LearnSpell(264) -- Arcs
        player:EquipItem(18680, EQUIPMENT_SLOTS.RANGED) -- Ancient Bone Bow

        return
    end

    -- Voleur niveau 60 : Combat epees, bleu/pre-raid.
    if class == 4 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.MAINHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.OFFHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.RANGED)

        player:LearnSpell(201) -- Epees 1 main
        player:LearnSpell(674) -- Ambidextrie
        player:LearnSpell(2567) -- Armes de jet
        player:SetSkill(43, 1, 290, 290)
        player:SetSkill(176, 1, 290, 290)

        -- Combat Sword : Mirah's Song en MH + Thrash Blade en OH.
        -- Deux vraies epees bleues adaptees au leveling/pre-raid, sans reprendre le duo du War/Hunter.
        player:EquipItem(15806, EQUIPMENT_SLOTS.MAINHAND) -- Mirah's Song
        player:EquipItem(17705, EQUIPMENT_SLOTS.OFFHAND)  -- Thrash Blade

        -- Arme de jet bleue/pre-raid.
        local roguePhysical = [[
          AND Quality = 3
          AND name NOT LIKE '%DEPRECATED%'
          AND name NOT LIKE '%TEST%'
          AND name NOT LIKE '%QA%'
        ]]
        EquipBestItem(
            player, level, {25}, EQUIPMENT_SLOTS.RANGED, mask, nil,
            roguePhysical .. " AND class = 2 AND subclass = 16"
        )
        return
    end

    -- Paladin niveau 60 : Protection, 1H + bouclier.
    if class == 2 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.MAINHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.OFFHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.RANGED)

        player:LearnSpell(201) -- Epees 1 main
        player:LearnSpell(107) -- Boucliers
        player:SetSkill(43, 1, 290, 290)

        -- Vanilla pre-raid : epee 1M + bouclier.
        player:EquipItem(12940, EQUIPMENT_SLOTS.MAINHAND) -- Dal'Rend's Sacred Charge (bleue Vanilla)
        player:EquipItem(12602, EQUIPMENT_SLOTS.OFFHAND)  -- Draconian Deflector

        -- Libram Paladin.
        player:EquipItem(22400, EQUIPMENT_SLOTS.RANGED)   -- Libram of Truth (Protection : Aura de devotion)
        return
    end

    -- Pretre niveau 60 : Heal/caster.
    if class == 5 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.MAINHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.OFFHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.RANGED)

        player:LearnSpell(227) -- Batons
        player:LearnSpell(5009) -- Baguettes
        player:SetSkill(136, 1, 290, 290)
        player:SetSkill(228, 1, 290, 290)

        -- Staff heal/caster bleu pre-raid, puis baguette.
        local priestHeal = NoAttackPowerFilter() .. [[
          AND Quality = 3
          AND name NOT LIKE '%DEPRECATED%'
          AND name NOT LIKE '%TEST%'
          AND name NOT LIKE '%QA%'
          AND (
               stat_type1 IN (5,6,7,18,21,30,31,32,36,43,45)
            OR stat_type2 IN (5,6,7,18,21,30,31,32,36,43,45)
            OR stat_type3 IN (5,6,7,18,21,30,31,32,36,43,45)
            OR stat_type4 IN (5,6,7,18,21,30,31,32,36,43,45)
          )
        ]]
        EquipBestItem(
            player, level, {17}, EQUIPMENT_SLOTS.MAINHAND, mask, nil,
            priestHeal .. " AND class = 2 AND subclass = 10"
        )
        EquipBestItem(
            player, level, {26}, EQUIPMENT_SLOTS.RANGED, mask, nil,
            priestHeal .. " AND class = 2 AND subclass = 19"
        )
        return
    end

    -- Druide niveau 60 : Feral Tank, bleu/pre-raid.
    if class == 11 and level == 60 then
        RemoveEquipped(player, EQUIPMENT_SLOTS.MAINHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.OFFHAND)
        RemoveEquipped(player, EQUIPMENT_SLOTS.RANGED)

        player:LearnSpell(227) -- Batons
        player:SetSkill(136, 1, 290, 290)

        -- Arme 2M physique/tank : Agi/Endu/Force, pas de spell power.
        local feralTank = [[
          AND Quality = 3
          AND name NOT LIKE '%DEPRECATED%'
          AND name NOT LIKE '%TEST%'
          AND name NOT LIKE '%QA%'
          AND (
               stat_type1 IN (3,4,7,12,13,14,15,35)
            OR stat_type2 IN (3,4,7,12,13,14,15,35)
            OR stat_type3 IN (3,4,7,12,13,14,15,35)
            OR stat_type4 IN (3,4,7,12,13,14,15,35)
          )
        ]]
        EquipBestItem(
            player, level, {17}, EQUIPMENT_SLOTS.MAINHAND, mask, nil,
            feralTank .. " AND class = 2 AND subclass IN (5,10)"
        )

        -- Idole Druide Feral/Tank fixe : Idol of Brutality.
        -- Bonus a Maul/Swipe, donc bien plus logique pour l'ours que l'idole caster.
        player:EquipItem(23198, EQUIPMENT_SLOTS.RANGED) -- Idol of Brutality
        return
    end

    -- Autres classes : armes selon les capacites generales.
    local main = EquipBestItem(
        player, level, {17,13,21}, EQUIPMENT_SLOTS.MAINHAND, mask
    )
    EquipBestItem(
        player, level, {14,22,23,13}, EQUIPMENT_SLOTS.OFFHAND, mask,
        main and {main} or nil
    )

    local rangedTypes
    if class == 3 then
        rangedTypes = {15,18,19,26}
    elseif class == 4 then
        rangedTypes = {25}
    elseif class == 2 or class == 6 or class == 7 or class == 11 then
        rangedTypes = {28}
    else
        rangedTypes = {15,18,19,26}
    end

    EquipBestItem(player, level, rangedTypes, EQUIPMENT_SLOTS.RANGED, mask)
end


local function LearnDruidForms60(player)
    if player:GetClass() ~= 11 then return end

    player:LearnSpell(5487) -- Forme d'ours
    player:LearnSpell(1066) -- Forme aquatique
    player:LearnSpell(768)  -- Forme de felin
    player:LearnSpell(783)  -- Forme de voyage
    player:LearnSpell(9634) -- Forme d'ours redoutable

    -- Pas de forme de vol au boost 60.
end

local function DoBoost(player, level)
    local unlocked = MaxOtherCharacterLevel(player)

    if unlocked < level then
        player:SendBroadcastMessage(string.format(
            "|cffff0000[Maitre des Heritiers]|r Il faut deja posseder un autre personnage niveau %u sur ce compte.",
            level
        ))
        return
    end

    if player:GetLevel() >= level then
        player:SendBroadcastMessage("|cffff0000[Maitre des Heritiers]|r Ce personnage a deja atteint ce niveau.")
        return
    end

    -- Le joueur a confirme : son ancien equipement equipe est detruit.
    RemoveEquippedGear(player)

    player:SetLevel(level)
    LearnClassSpells(player, level)
    BoostClassWeaponSkills(player)
    LearnRiding(player, level)
    if level >= 60 then
        LearnDruidForms60(player)
    end
    BoostExistingSkills(player, level)
    CopyBestAccountReputations(player)
    GiveBlueGear(player, level)
    GiveBags(player, level)

    -- Les talents sont laisses libres.
    -- Aucune quete, harmonisation ou progression Individual Progression
    -- n'est accordee. Les reputations sont copiees depuis le meilleur
    -- standing disponible sur le compte.
    player:ResetTalents(true)
    player:SaveToDB()

    player:SendBroadcastMessage(string.format(
        "|cff00ff00[Maitre des Heritiers]|r Boost niveau %u termine : sorts, monte, sacs et equipement bleu accordes.",
        level
    ))
end

local function ShowMenu(player, creature)
    player:GossipClearMenu()

    local unlocked = MaxOtherCharacterLevel(player)

    if unlocked >= 60 then
        player:GossipMenuAddItem(0, "|cff00ff00Boost niveau 60|r - T0 + sacs + sorts + monte", 0, BOOST60)
    else
        player:GossipMenuAddItem(0, "|cff888888Boost niveau 60 - verrouille (autre perso 60 requis)|r", 0, 160)
    end

    if unlocked >= 70 then
        player:GossipMenuAddItem(0, "|cff00ff00Boost niveau 70|r - bleu pre-raid + sacs + sorts + monte", 0, BOOST70)
    else
        player:GossipMenuAddItem(0, "|cff888888Boost niveau 70 - verrouille (autre perso 70 requis)|r", 0, 170)
    end

    if unlocked >= 80 then
        player:GossipMenuAddItem(0, "|cff00ff00Boost niveau 80|r - bleu pre-raid + sacs + sorts + monte", 0, BOOST80)
    else
        player:GossipMenuAddItem(0, "|cff888888Boost niveau 80 - verrouille (autre perso 80 requis)|r", 0, 180)
    end

    player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, CLOSE)
    player:GossipSendMenu(1, creature)
end

local function OnHello(event, player, creature)
    ShowMenu(player, creature)
end

local function OnSelect(event, player, creature, sender, intid, code)
    if intid == CLOSE then
        player:GossipComplete()
        return
    end

    if intid == 160 or intid == 170 or intid == 180 then
        local req = intid - 100
        player:SendBroadcastMessage(string.format(
            "|cffff0000[Maitre des Heritiers]|r Monte d'abord un autre personnage niveau %u sur ce compte.",
            req
        ))
        ShowMenu(player, creature)
        return
    end

    if intid == BOOST60 or intid == BOOST70 or intid == BOOST80 then
        local confirmId = intid + 200
        player:GossipClearMenu()
        player:GossipMenuAddItem(0,
            "|cffff0000ATTENTION !|r\n\nLe boost va remplacer et DETRUIRE l'equipement actuellement equipe.\n\nSi ce personnage a du stuff que tu veux conserver, annule maintenant.\n\nContinuer ?", 
            0, confirmId)
        player:GossipMenuAddItem(0, "|cff00ff00Oui, continuer|r", 0, confirmId + 1)
        player:GossipMenuAddItem(0, "|cffff0000Annuler|r", 0, CLOSE)
        player:GossipSendMenu(1, creature)
        return
    end

    if intid == CONFIRM60 + 1 or intid == CONFIRM70 + 1 or intid == CONFIRM80 + 1 then
        local level = intid - 200 - 1
        player:GossipComplete()
        DoBoost(player, level)
        return
    end
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)

print("=== MAITRE DES HERITIERS V43 - NPC 90004 - CHARGE ===")
