install( "packages/http-extensions.lua", "https://raw.githubusercontent.com/Pika-Software/http-extensions/main/lua/packages/http-extensions.lua" )
install( "packages/glua-extensions", "https://github.com/Pika-Software/glua-extensions" )

local render = render
local string = string
local table = table
local hook = hook
local http = http
local cam = cam
local net = net

local messageName = gpm.Package:GetIdentifier( "Networking" )
local setmetatable = setmetatable
local color_white = color_white
local ArgAssert = ArgAssert
local Material = Material
local CurTime = CurTime
local IsValid = IsValid
local EyePos = EyePos
local ScrW = ScrW
local type = type

local maxDistance = CreateConVar( "mp_markers_max_distance", "4096", FCVAR_ARCHIVE, "", 256, 12 * 1024 )
local size = CreateConVar( "mp_markers_size", "32", FCVAR_ARCHIVE, "", 16, 512 )

if type( markers ) ~= "table" then
    markers = {}
end

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

    local entity = self.Entity
    if IsValid( entity ) then
        if self.LocalOrigin and self.LocalAngles then
            local angles = entity:GetAngles()
            if entity:IsPlayer() then
                angles[ 2 ] = entity:EyeAngles()[ 2 ]
            end

            self.Origin = LocalToWorld( self.LocalOrigin, self.LocalAngles, entity:GetPos(), angles )
        else
            self.Origin = entity:LocalToWorld( entity:OBBCenter() )
        end
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
function markers.Create( data )
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
net.Receive( messageName, function()
    local data = net.ReadCompressedType()
    if not data then return end
    markers.Create( data )
end )

return markers