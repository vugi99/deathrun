
DR.MapRecordsDrawPos = Vector(0,0,0)
DR.MapRecordsCache = {}
DR.MapPBCache = 0



net.Receive("deathrun_send_map_records", function()
    DR.MapRecordsDrawPos = net.ReadVector()
    DR.MapRecordsCache = util.JSONToTable( net.ReadString() )

    --print("Records Pos",DR.MapRecordsDrawPos)
    --PrintTable( DR.MapRecordsCache )
end)

net.Receive("deathrun_send_map_pb", function()
    DR.MapPBCache = net.ReadFloat()
end)

DR.PlayerStatsCache = {}

net.Receive( "deathrun_send_stats", function()
    --print("meme")
    local t = table.Copy( net.ReadTable() )
    DR.PlayerStatsCache[ t[1]["sid"] ] = t[1]
    --print("meme")
    local name = t[1]["sid"]
    for k,v in ipairs(player.GetAll()) do
        if name == v:SteamID() then
            name = v:Nick()
        end
    end

    local msg = [[Stats for ]]..name..[[:
Kills: ]]..tostring(t[1]["kills"])..[[

Deaths: ]]..tostring(t[1]["deaths"])..[[

Runner Wins: ]]..tostring(t[1]["runner_wins"])..[[

Death Wins: ]]..tostring(t[1]["death_wins"])..[[
]]

    DR:ChatMessage( msg )
end)

-- display stats on a player's face
local stats3d = {
    pos = Vector(0,0,0),
    ang = Angle(0,0,0),
    data = {},
    born = 0
}

local statsvis = CreateClientConVar( "deathrun_stats_visibility", 1, true, false )
local labels = {}

net.Receive( "deathrun_display_stats", function()

    if IsValid( LocalPlayer() ) then
        if statsvis:GetBool() == true then
            local kills, deaths, run_win, dea_win

            kills = net.ReadInt( 16 )
            deaths = net.ReadInt( 16 )
            run_win = net.ReadInt( 16 )
            dea_win = net.ReadInt( 16 )
            mo_wins_name = net.ReadString()
            mo_wins = net.ReadInt( 32 )

            stats3d.data = {
                kills,
                deaths,
                run_win,
                dea_win,
                mo_wins_name.." ("..tostring(mo_wins)..")",
            }

            labels = {
                "Your Kills",
                "Your Deaths",
                "Your Runner Wins",
                "Your Death Wins",
                "Most Wins",
            }

            stats3d.pos = LocalPlayer():EyePos() + LocalPlayer():EyeAngles():Forward()*36
            stats3d.ang = LocalPlayer():EyeAngles()
            stats3d.ang:RotateAroundAxis( LocalPlayer():EyeAngles():Right(), 90 )
            stats3d.ang:RotateAroundAxis( LocalPlayer():EyeAngles():Forward(), 90 )
            stats3d.born = CurTime()

            hook.Call( "DeathrunAddStatsRow", nil, labels, stats3d.data)
        end
    end


end)

local w, h = 1000, 380
local x, y = -w/2, -h/2

surface.CreateFont("deathrun_3d2d_large", {
    font = "Roboto Black",
    size = 80,
    antialias = true,
})
surface.CreateFont("deathrun_3d2d_small", {
    font = "Roboto Black",
    size = 50,
    antialias = true,
})



hook.Add( "PostDrawTranslucentRenderables", "statsdisplay", function()

    local delay = 0.45
    local lifetime = 10 + delay

    local t = CurTime()-( stats3d.born + delay )

    if t < lifetime then
        h = 80 + 75 * #labels

        cam.Start3D2D( stats3d.pos, stats3d.ang, 0.04 )

            render.ClearStencil()
            render.SetStencilEnable(true) -- i dont know how this works?!?!?!?

            render.SetStencilFailOperation(STENCILOPERATION_KEEP)
            render.SetStencilZFailOperation(STENCILOPERATION_REPLACE)
            render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
            render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
            render.SetStencilReferenceValue(1)

            surface.SetDrawColor(Color(0, 0, 0, 255))
            if t < lifetime-1 then
                surface.DrawRect(x,y,w,h*QuadLerp( math.Clamp( InverseLerp(t,0,1), 0, 1 ), 0, 1 ) )
            else
                surface.DrawRect(x,y,w, h*QuadLerp( math.Clamp( InverseLerp( t, lifetime-1, lifetime ), 0, 1 ), 1, 0 ) )
            end

            render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
            render.SetStencilPassOperation(STENCILOPERATION_REPLACE)

            -- draw
            surface.SetDrawColor( DR.Colors.Clouds )
            surface.DrawRect(x,y,w,h)

            surface.SetDrawColor( DR.Colors.Turq )
            surface.DrawRect(x,y,w,80)

            deathrunShadowTextSimple("STATS", "deathrun_3d2d_large", 0, y, DR.Colors.Clouds, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2)

            

            for i = 1, #labels do
                deathrunShadowTextSimple(labels[i], "deathrun_3d2d_small", x+20, y + 100 + 70*(i-1), DR.Colors.Text.Grey3, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 0)
            end
            for i = 1, #stats3d.data do
                deathrunShadowTextSimple(tostring(stats3d.data[i]), "deathrun_3d2d_small", x+w-20, y + 100 + 70*(i-1), DR.Colors.Text.Turq, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 0)
            end
            -- close stencil

            render.SetStencilEnable(false)


        cam.End3D2D()
    end

    if DR.MapRecordsDrawPos ~= Vector(0,0,0) and DR.MapRecordsDrawPos ~= nil then
        local dist = LocalPlayer():GetPos():Distance( DR.MapRecordsDrawPos )
        if dist < 1000 then
            -- 

            -- local recordsAng = ( (LocalPlayer():EyePos() - DR.MapRecordsDrawPos):GetNormalized() )
            -- recordsAng = recordsAng:Angle() + Angle(90,0,00)
            -- recordsAng:RotateAroundAxis( recordsAng:Up(), 90)
            -- recordsAng.roll = 90

            --recordsAng:RotateAroundAxis( LocalPlayer():EyeAngles():Right(), 90 )
            --recordsAng:RotateAroundAxis( LocalPlayer():EyeAngles():Forward(), 90 )

            --local scale = math.Clamp( InverseLerp( dist, 1000, 400 ), 0,1) * 0.12

            --if dist < 20 then
                local recordsAng = LocalPlayer():EyeAngles()
                recordsAng:RotateAroundAxis( LocalPlayer():EyeAngles():Right(), 90 )
                recordsAng:RotateAroundAxis( LocalPlayer():EyeAngles():Forward(), 90 )
                recordsAng.roll = 90
            --end

            cam.Start3D2D( DR.MapRecordsDrawPos, recordsAng, 0.10 )
                
                surface.SetDrawColor( DR.Colors.Turq )
                surface.DrawRect(-700,-300, 1400, 80 )

                deathrunShadowTextSimple("TOP 3 RECORDS", "deathrun_3d2d_large", 0, -300, DR.Colors.Clouds, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2)
                    
                if DR.MapRecordsCache[1] ~= nil then
                    for i = 1, #DR.MapRecordsCache + 2 do
                        local k = i-1
                        if i <= #DR.MapRecordsCache then
                            local v = DR.MapRecordsCache[i]

                            deathrunShadowTextSimple( tostring(i)..". "..string.sub( v["nickname"] or "", 1, 24 ), "deathrun_3d2d_large", -700, -150 + 100*k, DR.Colors.Text.Clouds, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2 )
                            deathrunShadowTextSimple( string.ToMinutesSecondsMilliseconds(v["seconds"] or "0"), "deathrun_3d2d_large", 700, -150 + 100*k, DR.Colors.Text.Turq, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 2 )

                            surface.SetDrawColor( DR.Colors.Turq )
                            surface.DrawRect(-700,-150 + 100*k + 80, 1400, 2 )
                        elseif i == #DR.MapRecordsCache + 2 and DR.MapPBCache ~= 0 then
                            deathrunShadowTextSimple( "Personal Best", "deathrun_3d2d_large", -700, -150 + 100*k, DR.Colors.Text.Clouds, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2 )
                            deathrunShadowTextSimple( string.ToMinutesSecondsMilliseconds( DR.MapPBCache or 0 ), "deathrun_3d2d_large", 700, -150 + 100*k, DR.Colors.Text.Turq, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 2 )

                            surface.SetDrawColor( DR.Colors.Turq )
                            surface.DrawRect(-700,-150 + 100*k + 80, 1400, 2 )
                        end
                    end
                else
                    deathrunShadowTextSimple( "No records yet!", "deathrun_3d2d_large", 0, -200, DR.Colors.Text.Clouds, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2 )
                end
            cam.End3D2D()
        end
    end
end)


local cur_maprecords_frame
local cur_recs_map_list
local cur_recs_map_page_text
local cur_recs_map_table

local function MRMenu_AddLines(recs)
    if cur_recs_map_list then
        for i, v in ipairs(recs) do
            cur_recs_map_list:AddLine(v.nick, tostring(v.seconds) .. "s")
        end
    end
    cur_recs_map_table = recs
end

local function OpenMapRecordsMenu(mapname, page, recs)
    if not cur_maprecords_frame then
        local frame = vgui.Create( "DFrame" )
        frame:SetSize(900, 600)
        frame:Center()
        frame:SetTitle( "Map Records" )
        frame:SetVisible( true )
        frame:ShowCloseButton( true )
        frame:MakePopup()
        frame.OnClose = function()
            cur_maprecords_frame = nil
            cur_recs_map_list = nil
            cur_recs_map_page_text = nil
            cur_recs_map_table = nil
        end
        cur_maprecords_frame = frame

        local DLabel = vgui.Create( "DLabel", frame )
        DLabel:SetPos(5, 25)
        DLabel:SetFont("CreditsText")
        DLabel:SetSize(800, 25)
        DLabel:SetText( "Map: " .. tostring(mapname) )

        local RecsList = vgui.Create( "DListView", frame )
        RecsList:Dock( FILL )
        RecsList:DockMargin( 0, 20, 0, 30 )
        RecsList:SetMultiSelect( false )
        RecsList:AddColumn( "Name" )
        RecsList:AddColumn( "Time" )
        cur_recs_map_list = RecsList

        if DR:CanAccessCommand(LocalPlayer(), "deathrun_remove_record") then
            RecsList.OnRowSelected = function( lst, index, pnl )
                local menu = vgui.Create("DMenu")

                local remove_rec = menu:AddOption( "Remove Record" )
                remove_rec:SetIcon("icon16/cross.png")
                function remove_rec:DoClick()
                    if (type(cur_recs_map_table) == "table" and #cur_recs_map_table >= index) then
                        net.Start("deathrun_remove_map_record")
                        net.WriteString(mapname)
                        net.WriteString(cur_recs_map_table[index].sid64)
                        net.SendToServer()

                        frame:Close()
                    end
                end

                menu:Open()
            end
        end

        local PrevButton = vgui.Create("DButton", frame)
        PrevButton:SetText( "Previous Page" )
        PrevButton:SetPos( 50, 567 )
        PrevButton:SetSize( 250, 30 )
        PrevButton.DoClick = function()
            local cur_page = tonumber(cur_recs_map_page_text:GetText())
            if (cur_page > 1) then
                net.Start("deathrun_ask_selected_map_records")
                net.WriteString(mapname)
                net.WriteInt(cur_page - 1, 32)
                net.SendToServer()
            end
        end

        local NextButton = vgui.Create("DButton", frame)
        NextButton:SetText( "Next Page" )
        NextButton:SetPos( 600, 567 )
        NextButton:SetSize( 250, 30 )
        NextButton.DoClick = function()
            local cur_page = tonumber(cur_recs_map_page_text:GetText())
            net.Start("deathrun_ask_selected_map_records")
            net.WriteString(mapname)
            net.WriteInt(cur_page + 1, 32)
            net.SendToServer()
        end

        local DTextPage = vgui.Create( "DLabel", frame )
        DTextPage:SetPos(425, 570)
        DTextPage:SetFont("CreditsText")
        DTextPage:SetSize(800, 25)
        DTextPage:SetText(tostring(page))
        cur_recs_map_page_text = DTextPage

        MRMenu_AddLines(recs)
    else
        cur_recs_map_list:ClearSelection()

        cur_recs_map_list:Clear()

        cur_recs_map_page_text:SetText(tostring(page))

        MRMenu_AddLines(recs)
    end
end


net.Receive( "deathrun_send_selected_map_records", function( len, ply )
    local mapname = net.ReadString()
    local page = net.ReadInt(32)
    local recs = net.ReadTable()

    if (recs and #recs > 0) then
        OpenMapRecordsMenu(mapname, page, recs)
    end
end)



local cur_playerrecords_frame
local cur_recs_player_list
local cur_recs_player_page_text
local cur_recs_player_table

local function PRMenu_AddLines(recs)
    if cur_recs_player_list then
        for i, v in ipairs(recs) do
            cur_recs_player_list:AddLine(v.mapname, tostring(v.seconds) .. "s")
        end
    end
    cur_recs_player_table = recs
end

local function OpenPlayerRecordsMenu(sid64, nick, page, recs)
    if not cur_playerrecords_frame then
        local frame = vgui.Create( "DFrame" )
        frame:SetSize(900, 600)
        frame:Center()
        frame:SetTitle( "Player Records" )
        frame:SetVisible( true )
        frame:ShowCloseButton( true )
        frame:MakePopup()
        frame.OnClose = function()
            cur_playerrecords_frame = nil
            cur_recs_player_list = nil
            cur_recs_player_page_text = nil
            cur_recs_player_table = nil
        end
        cur_playerrecords_frame = frame

        local DLabel = vgui.Create( "DLabel", frame )
        DLabel:SetPos(5, 25)
        DLabel:SetFont("CreditsText")
        DLabel:SetSize(800, 25)
        DLabel:SetText( "Player: " .. tostring(nick) )

        local RecsList = vgui.Create( "DListView", frame )
        RecsList:Dock( FILL )
        RecsList:DockMargin( 0, 20, 0, 30 )
        RecsList:SetMultiSelect( false )
        RecsList:AddColumn( "Map Name" )
        RecsList:AddColumn( "Best Time" )
        cur_recs_player_list = RecsList

        if DR:CanAccessCommand(LocalPlayer(), "deathrun_remove_record") then
            RecsList.OnRowSelected = function( lst, index, pnl )
                local menu = vgui.Create("DMenu")

                local remove_rec = menu:AddOption( "Remove Record" )
                remove_rec:SetIcon("icon16/cross.png")
                function remove_rec:DoClick()
                    if (type(cur_recs_player_table) == "table" and #cur_recs_player_table >= index) then
                        net.Start("deathrun_remove_map_record")
                        net.WriteString(cur_recs_player_table[index].mapname)
                        net.WriteString(sid64)
                        net.SendToServer()

                        frame:Close()
                    end
                end

                menu:Open()
            end
        end

        local PrevButton = vgui.Create("DButton", frame)
        PrevButton:SetText( "Previous Page" )
        PrevButton:SetPos( 50, 567 )
        PrevButton:SetSize( 250, 30 )
        PrevButton.DoClick = function()
            local cur_page = tonumber(cur_recs_player_page_text:GetText())
            if (cur_page > 1) then
                net.Start("deathrun_ask_selected_player_records")
                net.WriteString(sid64)
                net.WriteInt(cur_page - 1, 32)
                net.SendToServer()
            end
        end

        local NextButton = vgui.Create("DButton", frame)
        NextButton:SetText( "Next Page" )
        NextButton:SetPos( 600, 567 )
        NextButton:SetSize( 250, 30 )
        NextButton.DoClick = function()
            local cur_page = tonumber(cur_recs_player_page_text:GetText())
            net.Start("deathrun_ask_selected_player_records")
            net.WriteString(sid64)
            net.WriteInt(cur_page + 1, 32)
            net.SendToServer()
        end

        local DTextPage = vgui.Create( "DLabel", frame )
        DTextPage:SetPos(425, 570)
        DTextPage:SetFont("CreditsText")
        DTextPage:SetSize(800, 25)
        DTextPage:SetText(tostring(page))
        cur_recs_player_page_text = DTextPage

        PRMenu_AddLines(recs)
    else
        cur_recs_player_list:ClearSelection()

        cur_recs_player_list:Clear()

        cur_recs_player_page_text:SetText(tostring(page))

        PRMenu_AddLines(recs)
    end
end

net.Receive( "deathrun_send_selected_player_records", function( len, ply )
    local sid64 = net.ReadString()
    local nick = net.ReadString()
    local page = net.ReadInt(32)
    local recs = net.ReadTable() or {}

    OpenPlayerRecordsMenu(sid64, nick, page, recs)
end)