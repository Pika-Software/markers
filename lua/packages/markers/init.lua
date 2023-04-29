import( gpm.LuaPackageExists( "packages/http-content" ) and "packages/http-content" or "https://raw.githubusercontent.com/Pika-Software/http-content/master/package.json" )

local packageName = gpm.Package:GetIdentifier()
local logger = gpm.Logger

local maxDistance = CreateConVar( "markers_max_distance", 1024, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ), "", 0, 10000 )

if SERVER then

    util.AddNetworkString( packageName )

    concommand.Add( "marker", function( sender )
        if not sender:Alive() then return end

        local tr = sender:GetEyeTrace()
        if not tr.Hit or tr.HitSky then return end

        local result = {
            ["entity"] = tr.Entity,
            ["pos"] = tr.HitPos,
            ["sender"] = sender,
            ["lifeTime"] = 5
        }

        local players = {}
        for _, ply in ipairs( player.GetHumans() ) do
            if hook.Call( "PlayerCanSeePlayersMarker", nil, sender, ply ) == false then continue end
            players[ #players + 1 ] = ply
        end

        net.Start( packageName )
            net.WriteTable( result )
        net.Send( players )
    end )

end

if CLIENT then

    local icons = {

        ["default"] = Material( "icon16/zoom.png", "smooth mips alphatest" )

    }

    local webIcons = {
        ["way"] = "https://i.imgur.com/DcdKnfz.png",
        ["stay"] = "https://i.imgur.com/FjxV0Gw.png",
        ["walk"] = "https://i.imgur.com/7QkKB1a.png",
        ["run"] = "https://i.imgur.com/mwyO9cV.png",
        ["dance"] = "https://i.imgur.com/IYnPHTN.png",
        ["weapon"] = "https://i.imgur.com/mO7YCCp.png",
        ["ammo"] = "https://i.imgur.com/ib8f2qC.png",
        ["door"] = "https://i.imgur.com/3Mv7z4s.png",
        ["blocks"] = "https://i.imgur.com/HvLKZuZ.png",
        ["dead"] = "https://i.imgur.com/zOstlM7.png"
    }

    for name, url in pairs( webIcons ) do
        http.DownloadMaterial( url, "smooth mips" ):Then( function( material )
            icons[ name ] = material
        end, function( err )
            logger:Error( err )
        end )
    end

    local colors = {
        Color(30, 144, 255),
        Color(190, 190, 190),
        Color(12, 12, 12),
        Color(255, 115, 50),
        Color(32, 32, 32)
    }

    local markers = {}
    net.Receive( packageName, function(len)
        local data = net.ReadTable()
        if not data then return end

        data.icon = icons.way or icons.default
        data.startTime = CurTime()

        markers[ #markers + 1 ] = data
    end )

    local sW = ScrW()
    local function ScaleMarkers()

        local ply_pos = LocalPlayer():GetPos()

        if next(markers) == nil then return end
        for k, tbl in ipairs( markers ) do
            if tbl == nil then continue end
            local dist = tbl.pos:Distance(ply_pos)
            local scale = dist / sW * 40

            tbl.scale = scale
        end

    end

    hook.Add( "Think", packageName, function()
        if next(markers) == nil then return end

        for index, marker in ipairs( markers ) do
            if CurTime() - marker.startTime > marker.lifeTime then
                table.remove( markers, index )
                break
            end

            local ent = marker.entity
            if not IsValid( ent ) then return end
            marker.pos = ent:LocalToWorld(ent:OBBCenter())
        end
    end )

    hook.Add( "HUDPaint", packageName, function()

        if next(markers) == nil then return end
        for k, tbl in ipairs( markers ) do
            ScaleMarkers()

            cam.Start({})
                render.SetMaterial( tbl.icon )
                render.DrawSprite( tbl.pos, tbl.scale, tbl.scale, color_white)
            cam.End3D()
        end

    end )

    print(packageName .. "is up!")
end


