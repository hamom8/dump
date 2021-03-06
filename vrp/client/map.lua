-- BLIPS: see https://wiki.gtanet.work/index.php?title=Blips for blip id/color

-- TUNNEL CLIENT API

-- BLIP

RegisterNetEvent('vrp:client:registerBlip')
AddEventHandler('vrp:client:registerBlip', function(coords, name, type, color)
  tvRP.addBlip(coords.x, coords.y, coords.z, type, color, name)
end)

-- create new blip, return native id
function tvRP.addBlip(x,y,z,idtype,idcolor,text)
  if x ~= nil and y ~= nil and z ~= nil then
    local blip = AddBlipForCoord(x+0.001,y+0.001,z+0.001) -- solve strange gta5 madness with integer -> double
    SetBlipSprite(blip, idtype)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip,idcolor)
    SetBlipScale(blip, 0.7)
    if text ~= nil then
      BeginTextCommandSetBlipName("STRING")
      AddTextComponentString(text)
      EndTextCommandSetBlipName(blip)
    end

    return blip
  end
  return false
end

-- remove blip by native id
function tvRP.removeBlip(id)
  RemoveBlip(id)
end

function tvRP.toggleBlackout(blackout)
	SetBlackout(blackout)
end


local named_blips = {}

-- set a named blip (same as addBlip but for a unique name, add or update)
-- return native id
function tvRP.setNamedBlip(name,x,y,z,idtype,idcolor,text)
  tvRP.removeNamedBlip(name) -- remove old one

  named_blips[name] = tvRP.addBlip(x,y,z,idtype,idcolor,text)
  return named_blips[name]
end

-- remove a named blip
function tvRP.removeNamedBlip(name)
  if named_blips[name] ~= nil then
    tvRP.removeBlip(named_blips[name])
    named_blips[name] = nil
  end
end

-- GPS

-- set the GPS destination marker coordinates
function tvRP.setGPS(x,y)
  SetNewWaypoint(x+0.0001,y+0.0001)
end

-- set route to native blip id
function tvRP.setBlipRoute(id)
  SetBlipRoute(id,true)
end

-- MARKER

local markers = {}
local marker_ids = Tools.newIDGenerator()
local named_markers = {}

-- add a circular marker to the game map
-- return marker id
function tvRP.addMarker(x,y,z,sx,sy,sz,r,g,b,a,visible_distance,markerType)
  local marker = {x=x,y=y,z=z,sx=sx,sy=sy,sz=sz,r=r,g=g,b=b,a=a,visible_distance=visible_distance}
  if markerType == nil then
    markerType = 1
  end
  marker.type = markerType
  -- default values
  if marker.sx == nil then marker.sx = 2.0 end
  if marker.sy == nil then marker.sy = 2.0 end
  if marker.sz == nil then marker.sz = 0.7 end

  if marker.r == nil then marker.r = 0 end
  if marker.g == nil then marker.g = 155 end
  if marker.b == nil then marker.b = 255 end
  if marker.a == nil then marker.a = 200 end

  -- fix gta5 integer -> double issue
  marker.x = marker.x+0.001
  marker.y = marker.y+0.001
  marker.z = marker.z+0.001
  marker.sx = marker.sx+0.001
  marker.sy = marker.sy+0.001
  marker.sz = marker.sz+0.001

  if marker.visible_distance == nil then marker.visible_distance = 150 end

  local id = marker_ids:gen()
  markers[id] = marker

  return id
end

-- remove marker
function tvRP.removeMarker(id)
  if markers[id] ~= nil then
    markers[id] = nil
    marker_ids:free(id)
  end
end

-- set a named marker (same as addMarker but for a unique name, add or update)
-- return id
function tvRP.setNamedMarker(name,x,y,z,sx,sy,sz,r,g,b,a,visible_distance)
  tvRP.removeNamedMarker(name) -- remove old marker

  named_markers[name] = tvRP.addMarker(x,y,z,sx,sy,sz,r,g,b,a,visible_distance,23)
  return named_markers[name]
end

function tvRP.removeNamedMarker(name)
  if named_markers[name] ~= nil then
    tvRP.removeMarker(named_markers[name])
    named_markers[name] = nil
  end
end

local render_markers = {  }

-- precache marker information
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(2000)
    render_markers = {  }
    for _,v in ipairs(markers) do
      if #(vector3(v.x, v.y, v.z) - GetEntityCoords(PlayerPedId())) < v.visible_distance + 0.001 then
        table.insert(render_markers, v)
      end
    end
  end
end)

-- markers draw loop
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1)
    for _,v in ipairs(render_markers) do
      -- check visibility
        DrawMarker(v.type,v.x,v.y,v.z,0,0,0,0,0,0,v.sx,v.sy,v.sz,v.r,v.g,v.b,v.a,0,0,0,0)
    end
  end
end)

-- AREA

local areas = {}

-- create/update a cylinder area
function tvRP.setArea(name,x,y,z,radius,height)
  local area = {x=x+0.001,y=y+0.001,z=z+0.001,radius=radius,height=height}

  -- default values
  if area.height == nil then area.height = 6 end

  areas[name] = area
end

-- remove area
function tvRP.removeArea(name)
  if areas[name] ~= nil then
    areas[name] = nil
  end
end

function tvRP.isPlayerNearArea(radius)
    for k,v in pairs(areas) do
      if IsEntityAtCoord(PlayerPedId(), v.x, v.y, v.z, radius+0.01, radius+0.01, radius+0.01, 0, 1, 0) then
        return true
      end
    end

    return false
end

local delay = 0
Citizen.CreateThread(function() -- delay decrease thread
  while true do
    Citizen.Wait(1000)
    if delay > 0 then
      delay = delay-1
    end
  end
end)

local current_transformer = nil

function tvRP.getCurrentTransformer()
  return current_transformer
end

-- areas triggers detections
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(250)
    for k,v in pairs(areas) do
      -- detect enter/leave
      local player_in = IsEntityAtCoord(PlayerPedId(), v.x, v.y, v.z, v.radius+0.001, v.radius+0.001, v.height+0.001, 0, 1, 0)

      if v.player_in and not player_in then -- was in: leave
        vRPserver.leaveArea({k})
        current_transformer = nil
      elseif not v.player_in and player_in then -- wasn't in: enter
        if delay < 1 then
          vRPserver.enterArea({k})
          current_transformer = k
          delay = 3
        else
          tvRP.notify("Come back in "..delay.." seconds")
          vRPserver.leaveArea({k})
          current_transformer = nil
        end
      end

      v.player_in = player_in -- update area player_in
    end
  end
end)

-- DOOR

-- set the closest door state
-- doordef: .model or .modelhash
-- locked: boolean
-- doorswing: -1 to 1
function tvRP.setStateOfClosestDoor(doordef, locked, doorswing)
  local x,y,z = tvRP.getPosition()
  local hash = doordef.modelhash
  if hash == nil then
    hash = GetHashKey(doordef.model)
  end

  SetStateOfClosestDoorOfType(hash,x,y,z,locked,doorswing+0.0001)
end

function tvRP.openClosestDoor(doordef)
  tvRP.setStateOfClosestDoor(doordef, false, 0)
end

function tvRP.closeClosestDoor(doordef)
  tvRP.setStateOfClosestDoor(doordef, true, 0)
end

function tvRP.DrawText3d(x,y,z,text,scale,r,g,b)
  local r = r or 255
  local g = g or 255
  local b = b or 255
  local onScreen,_x,_y=World3dToScreen2d(x,y,z)
  local px,py,pz=table.unpack(GetGameplayCamCoords())

  if onScreen then
    SetTextScale(scale, scale)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextColour(r,g,b,255)
    SetTextDropshadow(0, 0, 0, 0, 55)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
  end
end
