install( "packages/http-content", "https://github.com/Pika-Software/http-content" )

local render = render
local string = string
local hook = hook
local http = http
local cam = cam
local net = net

local packageName = gpm.Package:GetIdentifier()
local setmetatable = setmetatable
local LocalPlayer = LocalPlayer
local color_white = color_white
local ArgAssert = ArgAssert
local Material = Material
local CurTime = CurTime
local IsValid = IsValid
local EyePos = EyePos
local ScrW = ScrW
local type = type

local IN_ATTACK = IN_ATTACK
local IN_WALK = IN_WALK

local maxDistance = CreateConVar( "mp_markers_max_distance", "4096", FCVAR_ARCHIVE, "", 256, 12 * 1024 )
local size = CreateConVar( "mp_markers_size", "32", FCVAR_ARCHIVE, "", 16, 512 )

module( "markers" )

-- Markers metatable
local meta = {}
meta.__index = meta

-- IsValid
function meta:IsValid()
    return self.__alive
end

-- Icon
local materials = {}
function meta:GetMaterial()
    return materials[ self.Icon ]
end

function meta:SetMaterial( materialPath )
    ArgAssert( materialPath, 1, "string" )

    if string.IsURL( materialPath ) then
        http.DownloadImage( materialPath ):Then( function( filePath )
            materials[ filePath ] = Material( filePath, "smooth mips" )
            self.Icon = filePath
        end )

        return
    end

    if not materials[ materialPath ] then
        materials[ materialPath ] = Material( materialPath, "smooth mips" )
    end

    self.Icon = materialPath
end

-- Color
function meta:GetColor()
    return self.Color or color_white
end

function meta:SetColor( color )
    ArgAssert( color, 1, "Color" )
    self.Color = color
end

-- Position
function meta:GetPos()
    return self.Origin
end

function meta:SetPos( origin )
    ArgAssert( origin, 1, "Vector" )
    self.Origin = origin
end

function meta:Think()
    if ( CurTime() - self.Created ) > self.LifeTime then
        self.__alive = false
        return
    end

    local ent = self.Entity
    if IsValid( ent ) then
        self.Origin = ent:LocalToWorld( ent:OBBCenter() )
    end

    local dist = self.Origin:Distance( EyePos() )
    if dist > maxDistance:GetInt() then
        self.__hidden = true
        return
    end

    self.Scale = dist / ScrW() * size:GetInt()
    self.__hidden = hook.Run( "CanSeePlayerMarker", nil, self ) == false
end

function meta:Draw()
    if self.__hidden then return end
    if not hook.Run( "PreMarkerDraw", nil, self ) then
        cam.IgnoreZ( true )
            render.SetMaterial( self:GetMaterial() )
            render.DrawSprite( self.Origin, self.Scale, self.Scale, self.Color )
        cam.IgnoreZ( false )
    end

    hook.Run( "PostMarkerDraw", nil, self )
end

-- Creating a new one
function Create( data )
    ArgAssert( data, 1, "table" )

    local marker = setmetatable( table.Merge( {
        ["Created"] = CurTime(),
        ["__alive"] = true
    }, data ), meta )

    marker:SetMaterial( "icon16/zoom.png" )

    local icon = data.Icon
    if type( icon ) == "string" then
        marker:SetMaterial( icon )
    end

    marker:Think()

    hook.Add( "Think", marker, meta.Think )
    hook.Add( "PostDrawTranslucentRenderables", marker, meta.Draw )
end

-- Getting info from server
net.Receive( packageName, function()
    local data = net.ReadTable()
    if not data then return end
    Create( data )
end )

local lastClick = 0

hook.Add( "CreateMove", packageName, function( cmd )
    if cmd:KeyDown( IN_WALK ) and cmd:KeyDown( IN_ATTACK ) then
        cmd:RemoveKey( IN_ATTACK )

        local time = CurTime()
        local isBlocked = time - lastClick < 0.025
        lastClick = time

        local ply = LocalPlayer()
        if not ply:Alive() then return end
        if isBlocked then return end

        ply:ConCommand( "marker" )
    end
end )