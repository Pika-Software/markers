local player_GetHumans = player.GetHumans
local concommand_Add = concommand.Add
local hook_Run = hook.Run
local CurTime = CurTime
local ipairs = ipairs
local net = net

local packageName = gpm.Package:GetIdentifier()
util.AddNetworkString( packageName )

local delay = 1 / CreateConVar( "mp_markers_per_second", "10", FCVAR_ARCHIVE, "", 1, 100 ):GetFloat()
cvars.AddChangeCallback( "mp_markers_per_second", function( _, __, value )
    delay = 1 / ( tonumber( value ) or 1 )
end, packageName )

module( "markers" )

function Create( creator, pos, entity, tr )
    local result = {
        ["Creator"] = creator,
        ["Entity"] = entity,
        ["Origin"] = pos,
        ["LifeTime"] = 5
    }

    local players = {}
    for _, ply in ipairs( player_GetHumans() ) do
        if hook_Run( "PlayerCanSeePlayerMarker", nil, creator, ply ) == false then continue end
        players[ #players + 1 ] = ply
    end

    if hook_Run( "MarkerCreated", nil, result, players, tr ) then return end

    net.Start( packageName )
        net.WriteTable( result )
    net.Send( players )
end

local delays = {}

concommand_Add( "marker", function( ply )
    if not ply:Alive() then return end

    local time = CurTime()
    if ( delays[ ply:SteamID() ] or 0 ) > time then return end
    delays[ ply:SteamID() ] = time + delay

    local tr = ply:GetEyeTrace()
    if not tr.Hit or tr.HitSky then return end

    Create( ply, tr.HitPos, tr.Entity, tr )
end )