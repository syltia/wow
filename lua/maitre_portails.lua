local NPC_ENTRY = 90003

local CLOSE = 999
local MAIN = 900
local NAXX40 = 2007

local function TP(player, map, x, y, z, o)
    player:GossipComplete()
    player:Teleport(map, x, y, z, o)
end

local function SendMenu(player, creature)
    player:GossipSendMenu(1, creature)
end

local function AddBack(player)
    player:GossipMenuAddItem(0, "Retour", 0, MAIN)
    player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, CLOSE)
end

local DEST = {
    [1] = {0, -8833.38, 628.628, 94.0066, 1.06535},
    [2] = {0, -4918.88, -940.406, 501.564, 5.42347},
    [3] = {1, 9949.56, 2284.21, 1341.4, 1.59587},
    [4] = {530, -3965.7, -11653.6, -138.844, 0.852154},
    [5] = {1, 1629.85, -4373.64, 31.5573, 3.69762},
    [6] = {0, 1584.14, 240.308, -52.1534, 0.041793},
    [7] = {1, -1277.37, 124.804, 131.287, 5.22274},
    [8] = {530, 9487.69, -7279.2, 14.2866, 6.16478},
    [20] = {571, 5807.98, 588.487, 660.94, 1.66594},
    [21] = {530, -1838.16, 5301.79, -12.428, 5.9517},
    [1001] = {389, 3.81, -14.82, -17.84, 4.39}, [1002] = {36, -16.4, -383.07, 61.78, 1.86},
    [1003] = {43, -163.49, 132.9, -73.66, 5.83}, [1004] = {33, -229.135, 2109.18, 76.8898, 1.267},
    [1005] = {48, -151.89, 106.96, -39.87, 4.53}, [1006] = {34, 54.23, 0.28, -18.34, 6.26},
    [1007] = {90, -332.22, -2.28, -150.86, 2.77}, [1008] = {47, 1943, 1544.63, 82, 1.38},
    [1009] = {129, 2592.55, 1107.5, 51.29, 4.74}, [1010] = {189, 1688.99, 1053.48, 18.6775, 0.00117},
    [1011] = {70, -226.8, 49.09, -46.03, 1.39}, [1012] = {209, 1213.52, 841.59, 8.93, 6.09},
    [1013] = {349, 1019.69, -458.31, -43.43, 0.31}, [1014] = {109, -319.24, 99.9, -131.85, 3.19},
    [1015] = {230, 456.929, 34.0923, -68.0896, 4.71239}, [1016] = {229, 78.5083, -225.044, 49.839, 5.1},
    [1017] = {429, 44.4499, -154.822, -2.71201, 0}, [1018] = {289, 196.37, 127.05, 134.91, 6.09},
    [1019] = {329, 3593.15, -3646.56, 138.5, 5.33},
    [1101] = {543, -1355.24, 1641.12, 68.2491, 0.6687}, [1102] = {542, -3.9967, 14.6363, -44.8009, 4.88748},
    [1103] = {540, -40.8716, -19.7538, -13.8065, 1.11133}, [1104] = {547, 120.101, -131.957, -0.801547, 1.47574},
    [1105] = {546, 9.71391, -16.2008, -2.75334, 5.57082}, [1106] = {545, -13.8425, 6.7542, -4.2586, 0},
    [1107] = {557, 0.0191, 0.9478, -0.9543, 3.03164}, [1108] = {558, -21.8975, 0.16, -0.1206, 0.0353412},
    [1109] = {556, -4.6811, -0.0930796, 0.0062, 0.0353424}, [1110] = {555, 0.488033, -0.215935, -1.12788, 3.15888},
    [1111] = {560, 2741.87, 1315.25, 14.0423, 2.96016}, [1112] = {554, -28.906, 0.680314, -1.81282, 0.0345509},
    [1113] = {553, 40.0395, -28.613, -1.1189, 2.35856}, [1114] = {552, -1.23165, 0.0143459, -0.204293, 0.0157123},
    [1115] = {585, 7.09, -0.45, -2.8, 0.05}, [1116] = {269, -1496.24, 7034.7, 32.5619, 1.75699},
    [1201] = {574, 153.789, -86.548, 12.551, 0.304}, [1202] = {575, 584.117, -327.974, 110.138, 3.122},
    [1203] = {576, 145.87, -10.554, -16.636, 1.528}, [1204] = {578, 1055.93, 986.85, 361.07, 5.745},
    [1205] = {601, 413.314, 795.968, 831.351, 5.5}, [1206] = {619, 333.351, -1109.94, 69.772, 0.553},
    [1207] = {600, -517.343, -487.976, 11.01, 4.831}, [1208] = {604, 1891.84, 832.169, 176.669, 2.109},
    [1209] = {599, 1153.24, 806.164, 195.937, 4.715}, [1210] = {602, 1331.47, 259.619, 53.398, 4.772},
    [1211] = {595, 1431.1, 556.92, 36.69, 5.16}, [1212] = {608, 1808.82, 803.93, 44.364, 6.282},
    [1213] = {650, 805.227, 618.038, 412.393, 3.1456}, [1214] = {632, 4922.86, 2175.63, 638.734, 2.00355},
    [1215] = {658, 435.743, 212.413, 528.709, 6.25646}, [1216] = {668, 5239.01, 1932.64, 707.695, 0.800565},
    [2001] = {249, 29.1607, -71.3372, -8.18032, 4.58}, [2002] = {309, -11916.1, -1230.53, 92.5334, 4.71867},
    [2003] = {409, 1091.89, -466.985, -105.084, 3.14159}, [2004] = {469, -7673.03, -1106.08, 396.651, 0.703353},
    [2005] = {509, -8429.74, 1512.14, 31.9074, 2.58}, [2006] = {531, -8231.33, 2010.6, 129.331, 0.929912},
    [2101] = {532, -11100, -2003.98, 49.8927, 0.577268}, [2102] = {565, 62.7842, 35.462, -3.9835, 1.41844},
    [2103] = {544, 187.843, 35.9232, 67.9252, 4.79879}, [2104] = {548, 2.5343, -0.022318, 821.727, 0.004512},
    [2105] = {550, -10.8021, -1.15045, -2.42833, 6.22821}, [2106] = {534, 5066.79, -1791.9, 1321.65, 2.35619},
    [2107] = {564, 96.4462, 1002.35, -86.9984, 6.15675}, [2108] = {568, 120.7, 1776, 43.46, 4.7713},
    [2109] = {580, 1790.65, 925.67, 15.15, 3.1}, [2201] = {615, 3228.58, 385.86, 65.549, 1.578},
    [2202] = {616, 728.055, 1329.03, 275, 5.51524}, [2203] = {603, -914.041, -148.98, 463.137, 6.28},
    [2204] = {624, -505.96, -103.353, 157, 0}, [2205] = {649, 563.61, 80.6815, 395.2, 1.59},
    [2206] = {631, 76.8638, 2211.37, 30, 3.14965}, [2207] = {724, 3274, 533.531, 87.665, 3.16},
    [2208] = {533, 3005.68, -3447.77, 293.93, 4.65},
}

local function IsNaxx40Attuned(player)
    return player:GetQuestStatus(9121) == 6 or player:GetQuestStatus(9122) == 6 or player:GetQuestStatus(9123) == 6
end

local function TeleportNaxx40(player)
    if player:GetLevel() > 70 then
        player:SendBroadcastMessage("|cffff0000[Maitre des Portails]|r Naxxramas Classic est reserve a la progression niveau 60/70.")
        return
    end
    if not IsNaxx40Attuned(player) then
        player:SendBroadcastMessage("|cffff0000[Maitre des Portails]|r Vous n'avez pas termine l'harmonisation de Naxxramas Classic.")
        return
    end
    player:SetRaidDifficulty(2)
    player:GossipComplete()
    player:Teleport(533, 3005.51, -3434.64, 304.195, 6.2831)
end

local function ShowMain(player, creature)
    player:GossipClearMenu()
    if player:IsAlliance() then
        player:GossipMenuAddItem(0, "Hurlevent", 0, 1); player:GossipMenuAddItem(0, "Forgefer", 0, 2)
        player:GossipMenuAddItem(0, "Darnassus", 0, 3); player:GossipMenuAddItem(0, "Exodar", 0, 4)
    elseif player:IsHorde() then
        player:GossipMenuAddItem(0, "Orgrimmar", 0, 5); player:GossipMenuAddItem(0, "Fossoyeuse", 0, 6)
        player:GossipMenuAddItem(0, "Pitons-du-Tonnerre", 0, 7); player:GossipMenuAddItem(0, "Lune-d'Argent", 0, 8)
    end
    player:GossipMenuAddItem(0, "Dalaran", 0, 20); player:GossipMenuAddItem(0, "Shattrath", 0, 21)
    player:GossipMenuAddItem(0, "Donjons", 0, 100); player:GossipMenuAddItem(0, "Raids", 0, 200)
    player:GossipMenuAddItem(0, "|cffff0000Fermer|r", 0, CLOSE); SendMenu(player, creature)
end

local function AddList(player, creature, list)
    player:GossipClearMenu()
    for _,v in ipairs(list) do player:GossipMenuAddItem(0, v[1], 0, v[2]) end
    AddBack(player); SendMenu(player, creature)
end

local function ShowDungeons(p,c) AddList(p,c,{{"Classic",101},{"Burning Crusade",102},{"Wrath of the Lich King",103}}) end
local function ShowRaids(p,c) AddList(p,c,{{"Classic",201},{"Burning Crusade",202},{"Wrath of the Lich King",203}}) end
local function ShowClassicDungeons(p,c) AddList(p,c,{{"Gouffre de Ragefeu",1001},{"Mortemines",1002},{"Cavernes des Lamentations",1003},{"Donjon d'Ombrecroc",1004},{"Profondeurs de Brassenoire",1005},{"Prison de Hurlevent",1006},{"Gnomeregan",1007},{"Kraal de Tranchebauge",1008},{"Souilles de Tranchebauge",1009},{"Monastere ecarlate",1010},{"Uldaman",1011},{"Zul'Farrak",1012},{"Maraudon",1013},{"Temple englouti",1014},{"Profondeurs de Rochenoire",1015},{"Pic Rochenoire",1016},{"Hache-Tripes",1017},{"Scholomance",1018},{"Stratholme",1019}}) end
local function ShowBCDungeons(p,c) AddList(p,c,{{"Remparts des Flammes infernales",1101},{"Fournaise du sang",1102},{"Salles brisees",1103},{"Enclos aux esclaves",1104},{"Basse-tourbiere",1105},{"Caveau de la vapeur",1106},{"Tombes-mana",1107},{"Cryptes Auchenai",1108},{"Salles des Sethekk",1109},{"Labyrinthe des Ombres",1110},{"Contreforts de Hautebrande",1111},{"Mechanar",1112},{"Botanica",1113},{"Arcatraz",1114},{"Terrasse des Magisteres",1115},{"Le Noir Marecage",1116}}) end
local function ShowWotLKDungeons(p,c) AddList(p,c,{{"Donjon d'Utgarde",1201},{"Cime d'Utgarde",1202},{"Le Nexus",1203},{"L'Oculus",1204},{"Azjol-Nerub",1205},{"Ahn'kahet",1206},{"Donjon de Drak'Tharon",1207},{"Gundrak",1208},{"Salles de Pierre",1209},{"Salles de Foudre",1210},{"Epuration de Stratholme",1211},{"Fort Pourpre",1212},{"Epreuve du champion",1213},{"Forge des Ames",1214},{"Fosse de Saron",1215},{"Salles des Reflets",1216}}) end
local function ShowClassicRaids(p,c) AddList(p,c,{{"Repaire d'Onyxia",2001},{"Zul'Gurub",2002},{"Coeur du Magma",2003},{"Repaire de l'Aile noire",2004},{"Ruines d'Ahn'Qiraj",2005},{"Temple d'Ahn'Qiraj",2006},{"Naxxramas 40",NAXX40}}) end
local function ShowBCRaids(p,c) AddList(p,c,{{"Karazhan",2101},{"Repaire de Gruul",2102},{"Repaire de Magtheridon",2103},{"Sanctuaire du Serpent",2104},{"Donjon de la Tempete",2105},{"Sommet d'Hyjal",2106},{"Temple noir",2107},{"Zul'Aman",2108},{"Plateau du Puits de soleil",2109}}) end
local function ShowWotLKRaids(p,c) AddList(p,c,{{"Naxxramas",2208},{"Sanctum Obsidien",2201},{"Oeil de l'Eternite",2202},{"Ulduar",2203},{"Caveau d'Archavon",2204},{"Epreuve du Croise",2205},{"Citadelle de la Couronne de glace",2206},{"Sanctum Rubis",2207}}) end

local function OnHello(event, player, creature) ShowMain(player, creature) end
local function OnSelect(event, player, creature, sender, intid, code)
    if intid == NAXX40 then TeleportNaxx40(player); return end
    local d = DEST[intid]
    if d then TP(player,d[1],d[2],d[3],d[4],d[5]); return end
    if intid == 100 then ShowDungeons(player,creature) elseif intid == 101 then ShowClassicDungeons(player,creature)
    elseif intid == 102 then ShowBCDungeons(player,creature) elseif intid == 103 then ShowWotLKDungeons(player,creature)
    elseif intid == 200 then ShowRaids(player,creature) elseif intid == 201 then ShowClassicRaids(player,creature)
    elseif intid == 202 then ShowBCRaids(player,creature) elseif intid == 203 then ShowWotLKRaids(player,creature)
    elseif intid == MAIN then ShowMain(player,creature) elseif intid == CLOSE then player:GossipComplete()
    else player:SendBroadcastMessage("|cffff0000[Maitre des Portails]|r Option inconnue : "..tostring(intid)); ShowMain(player,creature) end
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnSelect)
print("=== MAITRE DES PORTAILS V6 NAXX40 - NPC 90003 - CHARGE ===")
