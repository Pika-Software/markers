install( "packages/glua-extensions", "https://github.com/Pika-Software/glua-extensions" )

local player_GetHumans = player.GetHumans
local angle_zero = angle_zero
local IsValid = IsValid
local ipairs = ipairs
local hook = hook
local net = net

if type( markers ) ~= "table" then
    markers = {}
end

local messageName = gpm.Package:GetIdentifier( "Networking" )
util.AddNetworkString( messageName )

function markers.Create( creator, traceResult )
    local data = {
        ["LifeTime"] = 5
    }

    data.Origin = traceResult.HitPos

    local entity = traceResult.Entity
    if IsValid( entity ) then
        local angles = entity:GetAngles()
        if entity:IsPlayer() then
            angles[ 2 ] = entity:EyeAngles()[ 2 ]
        end

        data.LocalOrigin, data.LocalAngles = WorldToLocal( data.Origin, angle_zero, entity:GetPos(), angles )
        data.Entity = entity
    end

    local creatorIsValid = false
    if IsValid( creator ) and creator:IsPlayer() then
        data.Creator = creator
        creatorIsValid = true
    end

    local players = {}
    for _, ply in ipairs( player_GetHumans() ) do
        if creatorIsValid and hook.Run( "PlayerCanSeePlayerMarker", creator, ply ) == false then continue end
        players[ #players + 1 ] = ply
    end

    if hook.Run( "MarkerSend", data, players, traceResult ) then return end

    net.Start( messageName )
        net.WriteCompressedType( data )
    net.Send( players )
end

concommand.Add( "marker", function( ply )
    if hook.Run( "CanCreateMarker", ply ) == false then return end

    local startOrigin = ply:GetShootPos()
    local traceResult = util.TraceLine( {
        ["endpos"] = startOrigin + ply:GetAimVector() * 32768,
        ["start"] = startOrigin,
        ["filter"] = ply
    } )

    if hook.Run( "MarkerCreate", ply, traceResult ) == false then return end
    markers.Create( ply, traceResult )
end )

return markers