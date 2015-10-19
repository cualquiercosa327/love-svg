--path.lua
local Path = {}
Path.__index = Path
setmetatable(Path, {
  __call = function (...)
	return Path.new(...)
  end,
})

local expectedArgs = {
	A = 7,
	a = 7,
	Q = 4,
	q = 4,
	T = 2,
	t = 2,
	C = 6,
	c = 6,
	S = 4,
	s = 4,
	L = 2,
	l = 2,
	H = 1,
	h = 1,
	V = 1,
	v = 1,
	Z = 0,
	z = 0,
	M = 2,
	m = 2
}
function isLeft(P0, P1, P2 )
	return ( (P1[1] - P0[1]) * (P2[2] - P0[2]) - (P2[1] -  P0[1]) * (P1[2] - P0[2]) )
end

function wn_PnPoly( P, points )
	local wn = 0
	for i=1,#points-3,2 do
		if (points[i+1] <= P[2]) then
			if (points[i+3]  > P[2]) and (isLeft( {points[i],points[i+1]}, {points[i+2],points[i+3]}, P) > 0) then
				 wn = wn + 1
			end
		elseif (points[i+3]  <= P[2]) then
			if (isLeft( {points[i], points[i+1]}, {points[i+2], points[i+3]}, P) < 0) then
				wn = wn - 1
			end
		end
	end
	return wn
end

function evenOdd(wn) return wn%2 ~= 0 end
function nonZero(wn) return wn ~= 0 end
local fillRule = evenOdd

function makeArc(x0, y0, rx, ry, phi, large_arc, sweep, x, y)
	--compute 1/2 distance between current and final point
	local dx2 = (x0 - x) / 2
	local dy2 = (y0 - y) / 2

	--compute x1, y1
	local x1 = math.cos(phi) * dx2 + math.sin(phi) * dy2
	local y1 = -math.sin(phi) * dx2 + math.cos(phi) * dy2
	--make sure radii are large enough
	rx = math.abs(rx)
	ry = math.abs(ry)
	local rx_sq = rx * rx
	local ry_sq = ry * ry
	local x1_sq = x1 * x1
	local y1_sq = y1 * y1
	
	local radius_check = (x1_sq / rx_sq) + (y1_sq / ry_sq)
	if (radius_check > 1) then
		rx = rx * math.sqrt(radius_check)
		ry = rx * math.sqrt(radius_check)
		rx_sq = rx * rx
		ry_sq = ry * ry
	end
	
	--compute (cx1, cy1)

	local sign = (large_arc == sweep) and -1 or 1
	local sq = ((rx_sq * ry_sq) - (rx_sq * y1_sq) - (ry_sq * x1_sq)) /
		((rx_sq * y1_sq) + (ry_sq * x1_sq))
	sq = (sq < 0) and 0 or sq
	local coef = sign * math.sqrt(sq)
	local cx1 = coef * ((rx * y1) / ry)
	local cy1 = coef * -((ry * x1) / rx)

	--compute (cx, cy) from (cx1, cy1)

	local sx2 = (x0 + x) / 2
	local sy2 = (y0 + y) / 2

	local cx = sx2 + (math.cos(phi) * cx1 - math.sin(phi) * cy1)
	local cy = sy2 + (math.sin(phi) * cx1 + math.cos(phi) * cy1)

	local ux = (x1 - cx1) / rx
	local uy = (y1 - cy1) / ry
	local vx = (-x1 - cx1) / rx
	local vy = (-y1 - cy1) / ry
	local n = math.sqrt( (ux * ux) + (uy * uy) )
	local p = ux -- 1 * ux + 0 * uy
	sign = (uy < 0) and -1 or 1

	local theta = sign * math.acos( p / n )

	n = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
	p = ux * vx + uy * vy
	sign = ((ux * vy - uy * vx) < 0) and -1 or 1
	local delta = sign * math.acos( p / n )

	if (sweep == 0  and  delta > 0) then
		delta = delta - 2*math.pi
	elseif (sweep == 1  and  delta < 0) then
		delta = delta + 2*math.pi
	end
	return makeEllipse(cx, cy, rx, ry, phi, theta, delta)
end

function makeEllipse(x, y, a, b, phi, theta, deltaTheta)
  phi = phi or 0
  segments = segments or 20
  if segments <= 0 then segments = 1 end

  local two_pi = math.pi*2
  local angle_shift = deltaTheta/(segments-2)
  local sin_phi = math.sin(phi)
  local cos_phi = math.cos(phi)

  local coords = {}
  for i = 1, segments do
	local theta = theta + angle_shift * (i-2)
	coords[2*i-1] = x + a * math.cos(theta) * cos_phi
					  - b * math.sin(theta) * sin_phi
	coords[2*i] = y + a * math.cos(theta) * sin_phi
					+ b * math.sin(theta) * cos_phi
  end
  return coords
end

function Path.new(garbage, fill, stroke, attr)
	local parsed = {}
	local instructions = {}
	local str = attr.d
	str = str:gsub("[A-Za-z]", " %1 ")
	for c in str:gmatch('[-]-[0-9a-zA-Z.]+') do table.insert(parsed, c) end

	local lastAction
	local argumentNumber = 1
	local current = 1

	for i,v in ipairs(parsed) do
		if v:match('[A-z]') then --is letter
			if instructions[current] == nil then
				instructions[current] = {}
			end
			if v == "m" then
				lastAction = "l"
			elseif v == "M" then
				lastAction = "L"
			else
				lastAction = v
			end
			instructions[current].action = v
			argumentNumber = 1
		else --is number
			if argumentNumber == 1 then
				if instructions[current] == nil then
					instructions[current] = {}
				end
				if instructions[current].action == nil then
					instructions[current].action = lastAction
				end
			end
			if argumentNumber <= expectedArgs[lastAction] then
				instructions[current][argumentNumber] = tonumber(v)
				
				if argumentNumber == expectedArgs[lastAction] then
					argumentNumber = 1
					current = current + 1
				else
					argumentNumber = argumentNumber + 1
				end
			end
		end
	end
	local subShapes = eval(instructions,x,y)	
	local thing = {stroke = stroke, fill = fill, x = 0, y = 0, subShapes = subShapes, Attributes=attr}
	return setmetatable(thing, Path)
end

function eval(instructions, x, y)
	local localX, localY = x, y
	local fillCoords = {}
	local currentClosedShape = 0
	for i,v in ipairs(instructions) do
		if fillCoords[currentClosedShape] == nil then
			fillCoords[currentClosedShape] = {}
		end
		
		local currentLength = #fillCoords[currentClosedShape]
		
		if	 v.action == "M" or (v.action == "m" and i == 1) then
			localX = v[1]
			localY = v[2]
			currentClosedShape = currentClosedShape + 1
			fillCoords[currentClosedShape] = {localX, localY}
			--table.insert(fillCoords[currentClosedShape], localX)
			--table.insert(fillCoords[currentClosedShape], localY)
		elseif v.action == "m" then
			localX = v[1] + localX
			localY = v[2] + localY
			currentClosedShape = currentClosedShape + 1
			fillCoords[currentClosedShape] = {localX, localY}
			--table.insert(fillCoords[currentClosedShape], localX)
			--table.insert(fillCoords[currentClosedShape], localY)
		elseif v.action == "L" then
			localX = v[1]
			localY = v[2]
		elseif v.action == "l" then
			localX = v[1] + localX
			localY = v[2] + localY
			--table.insert(fillCoords[currentClosedShape], localX)
			--table.insert(fillCoords[currentClosedShape], localY)
						
			fillCoords[currentClosedShape][currentLength+1] = localX
			fillCoords[currentClosedShape][currentLength+2] = localY
		elseif v.action == "A" then

			local points = makeArc(localX, localY, unpack(v))

			localX = v[6]
			localY = v[7]
			for j,k in ipairs(points) do
			
				--table.insert(fillCoords[currentClosedShape], k)
				fillCoords[currentClosedShape][currentLength+j] = k
			end
		elseif v.action == "a" then

			local points = makeArc(localX, localY, v[1],v[2],v[3],v[4],v[5],v[6]+localX,v[7]+localY)

			localX = localX + v[6]
			localY = localY + v[7]
			for j,k in ipairs(points) do
				--table.insert(fillCoords[currentClosedShape], k)
				fillCoords[currentClosedShape][currentLength+j] = k
			end
		elseif v.action == "H" then
			localX = v[1]
			--table.insert(fillCoords[currentClosedShape], localX)
			--table.insert(fillCoords[currentClosedShape], localY)
			fillCoords[currentClosedShape][currentLength+1] = localX
			fillCoords[currentClosedShape][currentLength+2] = localY
		elseif v.action == "h" then

			localX = v[1] + localX
			--table.insert(fillCoords[currentClosedShape], localX)
			--table.insert(fillCoords[currentClosedShape], localY)
			fillCoords[currentClosedShape][currentLength+1] = localX
			fillCoords[currentClosedShape][currentLength+2] = localY
		elseif v.action == "V" then

			localY = v[1]
			--table.insert(fillCoords[currentClosedShape], localX)
			--table.insert(fillCoords[currentClosedShape], localY)
			fillCoords[currentClosedShape][currentLength+1] = localX
			fillCoords[currentClosedShape][currentLength+2] = localY
		elseif v.action == "v" then

			localY = v[1]
			--table.insert(fillCoords[currentClosedShape], localX)
			--table.insert(fillCoords[currentClosedShape], localY)
			fillCoords[currentClosedShape][currentLength+1] = localX
			fillCoords[currentClosedShape][currentLength+2] = localY
		elseif v.action == "Q" then
		elseif v.action == "q" then
		elseif v.action == "C" then

			local curve = love.math.newBezierCurve()
			curve:insertControlPoint(localX, localY)
			curve:insertControlPoint(v[1], v[2])
			curve:insertControlPoint(v[3], v[4])
			curve:insertControlPoint(v[5], v[6])
			local points = curve:render(5)
			localX = v[5]
			localY = v[6]
			for j,k in ipairs(points) do
				--table.insert(fillCoords[currentClosedShape], k)
				fillCoords[currentClosedShape][currentLength+j] = k
			end
		elseif v.action == "c" then
			local curve = love.math.newBezierCurve()
			curve:insertControlPoint(localX, localY)
			curve:insertControlPoint(localX+v[1], localY+v[2])
			curve:insertControlPoint(localX+v[3], localY+v[4])
			curve:insertControlPoint(localX+v[5], localY+v[6])
			local points = curve:render(5)
			localX = v[5] + localX
			localY = v[6] + localY
			for j,k in ipairs(points) do
				--table.insert(fillCoords[currentClosedShape], k)
				fillCoords[currentClosedShape][currentLength+j] = k
			end
		elseif v.action == "S" then
		elseif v.action == "s" then
		elseif v.action == "T" then
		elseif v.action == "t" then
		elseif v.action:match("Zz") then
			--nothing
		end
		
	end
	
	local subShapes = {}
	for i,v in ipairs(fillCoords) do
		local points = {}
		local bbox = {x1}
		--print("new shape")
		for j=1,#v,2 do
			if j == 1 or not (math.floor(v[j]) == math.floor(v[j-2]) and math.floor(v[j+1]) == math.floor(v[j-1])) then
				if bbox.x1 == nil or v[j] < bbox.x1 then
					bbox.x1 = v[j]
				end
				if bbox.y1 == nil or v[j+1] < bbox.y1 then
					bbox.y1 = v[j+1]
				end
				if bbox.x2 == nil or v[j] > bbox.x2 then
					bbox.x2 = v[j]
				end
				if bbox.y2 == nil or v[j+1] > bbox.y2 then
					bbox.y2 = v[j+1]
				end
				table.insert(points, v[j])
				table.insert(points, v[j+1])
				--print(v[j]..", "..v[j+1])
			end
		end
		
		local fillPoints = {}
		for x=bbox.x1,bbox.x2,1 do
			for y=bbox.y1,bbox.y2,1 do
				if fillRule(wn_PnPoly({x,y}, points)) then
					fillPoints[#fillPoints+1] = {x,y}
				end
			end
		end
		subShapes[i] = {points = points, bbox = bbox, fillPoints = fillPoints}
	end
	return subShapes
end

function Path:draw()
	for i,v in ipairs(self.subShapes) do
		love.graphics.setColor(unpack(self.fill))
		
		for j,point in ipairs(v.fillPoints)do
			love.graphics.point(point[1],point[2])
		end
		
		love.graphics.setColor(unpack(self.stroke))
		love.graphics.setLineWidth(love.graphics.getLineWidth()/2)
		--for j=1,#v.points-2,2 do
		--	love.graphics.line(v.points[j], v.points[j+1], v.points[j+2], v.points[j+3])
		--end
		love.graphics.line(v.points)
		love.graphics.setLineWidth(love.graphics.getLineWidth()*2)
		--love.graphics.line(unpack(v.points))
	end
end

return Path
