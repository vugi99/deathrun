

-- script to keep track of all statistics for players
-- kills, deaths, round wins
-- if a runner dies, then that's 1 kill for everyone on the Death team.
print("Loading Statistics...")



-- calculate DAS score
-- Deathrun Aggregated Score is calculated like so:
-- { [ ( 1 - 0.5^(death_wins + runner_wins) ) / 0.5 ] -1 } * sqrt(KDR)
-- where KDR = K/D

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+='
function Base64Encode(data)
	return ((data:gsub('.', function(x) 
		local r,b='',x:byte()
		for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
		return r;
	end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if (#x < 6) then return '' end
		local c=0
		for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
		return b:sub(c+1,c+1)
	end)..({ '', '==', '=' })[#data%3+1])
end

function Base64Decode(data)
	data = string.gsub(data, '[^'..b..'=]', '')
	return (data:gsub('.', function(x)
		if (x == '=') then return '' end
		local r,f='',(b:find(x)-1)
		for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
		return r;
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if (#x ~= 8) then return '' end
		local c=0
		for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
		return string.char(c)
	end))
end


-- record timings
--sql.Query("DROP TABLE deathrun_records")
sql.Query("CREATE TABLE IF NOT EXISTS deathrun_records ( sid64 STRING, mapname STRING, seconds REAL )")

-- Cleanup duplicated records on current map :
sql.Query("DELETE FROM deathrun_records AS dr1 WHERE dr1.seconds > (SELECT MIN(seconds) FROM deathrun_records AS dr2 WHERE dr2.sid64 = dr1.sid64 AND dr2.mapname = dr1.mapname)")

hook.Add("DeathrunPlayerFinishMap", "DeathrunMapRecords", function( ply, zname, zone, place, seconds )
    local sid64 = ply:SteamID64()
    local mapname = game.GetMap()

    --sql.Query("INSERT INTO deathrun_records VALUES ('"..sid64.."', '"..mapname.."', "..tostring(seconds)..")")

    if (not ply.best_rec_seconds or ply.best_rec_seconds > seconds) then

        if (not ply.best_rec_seconds) then
            sql.Query("INSERT INTO deathrun_records VALUES ('"..sid64.."', '"..mapname.."', "..tostring(seconds)..")")
        else
            sql.Query("UPDATE deathrun_records SET seconds = " .. tostring(seconds) .. " WHERE sid64 = '" .. tostring(sid64) .. "' AND mapname = '" .. game.GetMap() .. "'")
        end

        ply.best_rec_seconds = seconds
    end
end)

local endmap = nil
local function findendmap()
    --PrintTable( ZONE.zones )
    if ZONE.zones then
        for k,v in pairs( ZONE.zones ) do
            print(v.type)
            if v.type == "end" then
                endmap = v
            end
        end
    end
end
findendmap()

hook.Add("InitPostEntity", "DeathrunFindEndZone", function()
    findendmap()
end)

hook.Add("DeathrunBeginPrep", "DeathrunSendRecords", function()

    -- deathrun_send_map_records
    --
    res = sql.Query("SELECT * FROM deathrun_records WHERE mapname = '"..game.GetMap().."' ORDER BY seconds ASC LIMIT 3")

    --PrintTable( endmap )
    if endmap ~= nil and res ~= false then
        if res == nil then 
            res = {}
        else
            for i = 1, #res do
                res[i]["nickname"] = DR:SteamToNick( res[i]["sid64"] )
            end
        end

        net.Start("deathrun_send_map_records")
        net.WriteVector( 0.5*(endmap.pos1 + endmap.pos2) )
        net.WriteString( util.TableToJSON( res ) )
        net.Broadcast()
    end

    for k,ply in ipairs(player.GetAll()) do
        res2 = sql.Query("SELECT * FROM deathrun_records WHERE mapname = '"..game.GetMap().."' AND sid64 = '"..ply:SteamID64().."' ORDER BY seconds ASC LIMIT 1")
        if endmap ~= nil and res2 ~= false then
            local seconds = -1
            if res2 ~= nil then
                if res2[1] then
                    if res2[1]["seconds"] then
                        seconds = res2[1]["seconds"]
                    end
                end
            end

            net.Start("deathrun_send_map_pb")
            net.WriteFloat( seconds )
            net.Send( ply )

            if (seconds ~= -1) then
                ply.best_rec_seconds = tonumber(seconds)
            end
        end
    end

end)

-- store a table of all the player names and associated steamid communityid when they join

sql.Query( "CREATE TABLE deathrun_ids ( sid64 STRING, sid STRING, nick STRING )" )

hook.Add("PlayerInitialSpawn", "UpdatePlayerIDs", function(ply)
    -- update player names
    local id64 = ply:SteamID64()
    local id = ply:SteamID()

    --print("Join : ", id64, id)

    local res = sql.Query( "SELECT * FROM deathrun_ids WHERE sid64 = '"..id64.."'" )
    if not res then
        res = sql.Query( "INSERT INTO deathrun_ids VALUES ( '"..id64.."', '"..id.."', '"..Base64Encode( ply:Nick() ).."' )" )
    else
        res = sql.Query( "UPDATE deathrun_ids SET nick = '"..Base64Encode( ply:Nick() ).."' WHERE sid64 = '"..id64.."' " )
    end
end)

function DR:SteamToNick( sid )
    local com = true
    if string.find( sid, "STEAM_" ) ~= nil then com = false end

    local nick = "UNKNOWN"
    local res

    if com then
        res = sql.Query( "SELECT * FROM deathrun_ids WHERE sid64 = '"..sid.."'" )
    else
        res = sql.Query( "SELECT * FROM deathrun_ids WHERE sid = '"..sid.."'" )
    end

    if res then
        nick = Base64Decode( res[1]["nick"] )
    end

    return nick

end


sql.Query( "CREATE TABLE deathrun_stats ( sid STRING, kills INTEGER, deaths INTEGER, runner_wins INTEGER, death_wins INTEGER )" )

hook.Add("PlayerAuthed", "CreateStatsRow", function( ply, steamid, uid )
    local res = sql.Query( "SELECT * FROM deathrun_stats WHERE sid = '"..steamid.."'" )
    if not res then
        res = sql.Query( "INSERT INTO deathrun_stats VALUES ( '"..steamid.."', 0, 0, 0, 0 )" )
    end

    res = sql.Query( "SELECT * FROM deathrun_stats WHERE sid = '"..steamid.."'" )

end)

hook.Add("PlayerDeath", "DeathrunStats", function( vic, inf, att )

    if ROUND:GetCurrent() == ROUND_ACTIVE then

        if att:IsPlayer() then
            if vic:Team() ~= att:Team() then
                data1 = sql.Query( "SELECT kills FROM deathrun_stats WHERE sid = '"..att:SteamID().."'")
                local kills = data1[1]["kills"]
                res = sql.Query( "UPDATE deathrun_stats SET kills = "..tostring(kills+1).." WHERE sid = '"..att:SteamID().."'" )
            end
        else
            if vic:Team() == TEAM_RUNNER then
                for _, ply in ipairs( team.GetPlayers( TEAM_DEATH ) ) do
                    if not ply:IsBot() then
                        data1 = sql.Query( "SELECT kills FROM deathrun_stats WHERE sid = '"..ply:SteamID().."'")
                        local kills = data1[1]["kills"]
                        res = sql.Query( "UPDATE deathrun_stats SET kills = "..tostring(kills+1).." WHERE sid = '"..ply:SteamID().."'" )
                    end
                end
            end
        end

        if vic:IsPlayer() and not vic:IsBot() then
            data2 = sql.Query( "SELECT deaths FROM deathrun_stats WHERE sid = '"..vic:SteamID().."'")
            local deaths = data2[1]["deaths"]
            res = sql.Query( "UPDATE deathrun_stats SET deaths = "..tostring(deaths+1).." WHERE sid = '"..vic:SteamID().."'" )
        end

    end

end)

hook.Add("DeathrunRoundWin", "stats", function( winteam )
    if winteam == TEAM_RUNNER or winteam == TEAM_DEATH then
        players = team.GetPlayers( winteam )
        if winteam == TEAM_RUNNER then
            for k,ply in ipairs( players ) do
                if not ply:IsBot() then 
                    local data1 = sql.Query("SELECT runner_wins FROM deathrun_stats WHERE sid = '"..ply:SteamID().."'")
                    local wins = data1[1]["runner_wins"]
                    sql.Query( "UPDATE deathrun_stats SET runner_wins = "..tostring( wins+1 ).." WHERE sid = '"..ply:SteamID().."'")
                end
            end
        end
        if winteam == TEAM_DEATH then
            for k,ply in ipairs( players ) do
                if not ply:IsBot() then 
                    local data1 = sql.Query("SELECT death_wins FROM deathrun_stats WHERE sid = '"..ply:SteamID().."'")
                    local wins = data1[1]["death_wins"]
                    sql.Query( "UPDATE deathrun_stats SET death_wins = "..tostring( wins+1 ).." WHERE sid = '"..ply:SteamID().."'")
                end
            end
        end
    end
end)

concommand.Add("stats_test", function( ply, cmd, args )
    PrintTable( sql.Query( "SELECT * FROM deathrun_stats WHERE sid = '"..ply:SteamID().."'" ) )
end)

function DR:DisplayStats( ply ) -- displays a player's stats in front of their face
    if IsValid( ply ) then
        local res = sql.Query( "SELECT * FROM deathrun_stats WHERE sid = '"..ply:SteamID().."'" )
        local res2 = sql.Query("SELECT sid, (runner_wins + death_wins) AS total_wins FROM deathrun_stats ORDER BY total_wins DESC LIMIT 1")

        local highscoreName = ""
        local highscore = 0

        if res2 then
            highscoreName = DR:SteamToNick( res2[1]["sid"] )
            highscore = res2[1]["total_wins"]

            --PrintTable( res2 )
        end

        if res then
            net.Start("deathrun_display_stats")
            --kills
            net.WriteInt( res[1]["kills"], 16 )
            --deaths
            net.WriteInt( res[1]["deaths"], 16 )
            --runner_wins
            net.WriteInt( res[1]["runner_wins"], 16 )
            --death_wins
            net.WriteInt( res[1]["death_wins"], 16 )

            net.WriteString( highscoreName )
            net.WriteInt( highscore, 32 )

            net.Send( ply )
        end
    end
end

hook.Add("PlayerLoadout", "DisplayStatsForPlayers", function(ply)
    if ply:Alive() and not ply:GetSpectate() then
        timer.Simple(0.5, function()
            DR:DisplayStats( ply )
        end )
    end
end)

concommand.Add("deathrun_display_stats", function( ply, cmd, args )
    DR:DisplayStats( ply )
end)


-- Avoid sql escape exploit
local Allowed_Characters = {
    "0","1","2","3","4","5","6","7","8","9",
    "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
    "_", "-"
}

local A_Chars_tab = {}
for i, v in ipairs(Allowed_Characters) do
    A_Chars_tab[v] = true
end

local function GoodMapName(mapname)
    for i = 1, #mapname do
        local c = mapname:sub(i,i)
        if not A_Chars_tab[c] then
            return false
        end
    end
    return true
end

local records_page_length = CreateConVar("deathrun_records_page_length", "25", defaultFlags, "Records page size")

local function SendRecordsOfMapForClient_Page(ply, mapname, page)
    if not GoodMapName(mapname) then
        return false
    end

    local res_recs = sql.Query("SELECT * FROM deathrun_records WHERE mapname = '"..mapname.."' ORDER BY seconds ASC LIMIT " .. tostring(records_page_length:GetInt()) .. " OFFSET " .. tostring((page-1)*records_page_length:GetInt()))

    if (res_recs and #res_recs > 0) then
        for i, v in ipairs(res_recs) do
            res_recs[i].nick = DR:SteamToNick(v["sid64"])
            res_recs[i].mapname = nil
        end

        net.Start("deathrun_send_selected_map_records")
        net.WriteString(mapname)
        net.WriteInt(page, 32)
        net.WriteTable(res_recs)
        net.Send(ply)

        return true
    end
end

local function SendRecordsOfPlayerForClient_Page(ply, sid64, page)
    --print("SendRecordsOfPlayerForClient_Page", sid64, page)
    local res_recs = sql.Query("SELECT * FROM (SELECT *, RANK() OVER (PARTITION BY mapname ORDER BY seconds ASC) AS rank FROM deathrun_records) WHERE sid64 = '"..sid64.."' ORDER BY mapname ASC LIMIT " .. tostring(records_page_length:GetInt()) .. " OFFSET " .. tostring((page-1)*records_page_length:GetInt()))

    if (res_recs and #res_recs > 0) then

        for i, v in ipairs(res_recs) do
            res_recs[i].sid64 = nil
        end

        local nick = DR:SteamToNick( sid64 )

        net.Start("deathrun_send_selected_player_records")
        net.WriteString(sid64)
        net.WriteString(nick)
        net.WriteInt(page, 32)
        net.WriteTable(res_recs)
        net.Send(ply)

        return true
    end
end

DR:AddChatCommand("records", function( ply, args )
    local mapname = game.GetMap()
	if (type(args) == "table" and #args > 0) then
        mapname = args[1]
    end

    if (not (SendRecordsOfMapForClient_Page(ply, mapname, 1))) then
        ply:ChatPrint("No records found for this map")
    end
end)
DR:AddChatCommandAlias("records", "wr")


util.AddNetworkString("deathrun_send_stats")
util.AddNetworkString("deathrun_display_stats")
util.AddNetworkString("deathrun_send_map_records")
util.AddNetworkString("deathrun_send_map_pb")

util.AddNetworkString("deathrun_send_selected_map_records")
util.AddNetworkString("deathrun_ask_selected_map_records")

util.AddNetworkString("deathrun_send_selected_player_records")
util.AddNetworkString("deathrun_ask_selected_player_records_rc")
util.AddNetworkString("deathrun_ask_selected_player_records")

util.AddNetworkString("deathrun_remove_map_record")

net.Receive( "deathrun_ask_selected_map_records", function( len, ply )
    if (IsValid(ply)) then
        local mapname = net.ReadString()
        local page = net.ReadInt(32)

        if (page and page >= 1) then
            SendRecordsOfMapForClient_Page(ply, mapname, page)
        end
    end
end)

net.Receive( "deathrun_ask_selected_player_records_rc", function( len, ply )
    if (IsValid(ply)) then
        local target_player = net.ReadEntity()
        if (IsValid(target_player)) then
            SendRecordsOfPlayerForClient_Page(ply, target_player:SteamID64(), 1)
        end
    end
end)

net.Receive( "deathrun_ask_selected_player_records", function( len, ply )
    if (IsValid(ply)) then
        local sid64 = net.ReadString()
        local page = net.ReadInt(32)
        if (page and page >= 1) then
            SendRecordsOfPlayerForClient_Page(ply, sid64, page)
        end
    end
end)



-- Avoid sql escape exploit
local Allowed_Characters_Ply_Names = {
    "0","1","2","3","4","5","6","7","8","9",
    "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
    "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    "_", "-"
}

local A_Chars_tab_2 = {}
for i, v in ipairs(Allowed_Characters_Ply_Names) do
    A_Chars_tab_2[v] = true
end

local function GoodPlyName(plyname)
    for i = 1, #plyname do
        local c = plyname:sub(i,i)
        if not A_Chars_tab_2[c] then
            return false
        end
    end
    return true
end

DR:AddChatCommand("ply_records", function( ply, args )
	if (type(args) == "table" and #args > 0) then
        local playername = args[1]

        if GoodPlyName(playername) then

            local sid64 = playername
            if (not (SendRecordsOfPlayerForClient_Page(ply, sid64, 1))) then
                local res2 = sql.Query( "SELECT * FROM deathrun_ids WHERE nick = '"..Base64Encode(playername).."'" )

                if res2 then
                    sid64 = res2[1]["sid64"]

                    if (not (SendRecordsOfPlayerForClient_Page(ply, sid64, 1))) then
                        ply:ChatPrint("No records found for this player")
                    end
                else
                    ply:ChatPrint("Player not found")
                end
            end
        else
            ply:ChatPrint("Name/ID Contains invalid characters")
        end
    else
        ply:ChatPrint("Missing player name or steamid")
    end
end)


net.Receive( "deathrun_remove_map_record", function( len, ply )
    if (IsValid(ply)) then
        if DR:CanAccessCommand(ply, "deathrun_remove_record") then
            local mapname = net.ReadString()
            local sid64 = net.ReadString()

            if (mapname and sid64 and GoodMapName(mapname)) then
                sql.Query("DELETE FROM deathrun_records WHERE mapname='" .. mapname .. "' AND sid64='" .. sid64 .. "'")

                if mapname == game.GetMap() then
                    for i, v in ipairs(player.GetAll()) do
                        if v:SteamID64() == sid64 then
                            v.ply.best_rec_seconds = nil
                            break
                        end
                    end
                end
            end
        end
    end
end)