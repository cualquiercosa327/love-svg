--VIAGrA.lua

local Path = require "path"

local XmlParser = {}

function XmlParser:FromXmlString(value)
	value = string.gsub(value, "&#x([%x]+)%;",
		function(h) 
			return string.char(tonumber(h,16)) 
		end)
	value = string.gsub(value, "&#([0-9]+)%;",
		function(h) 
			return string.char(tonumber(h,10)) 
		end)
	value = string.gsub (value, "&quot;", "\"")
	value = string.gsub (value, "&apos;", "'")
	value = string.gsub (value, "&gt;", ">")
	value = string.gsub (value, "&lt;", "<")
	value = string.gsub (value, "&amp;", "&")
	return value
end

function XmlParser:ParseArgs(s)
  local arg = {}
  string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
		arg[w] = self:FromXmlString(a)
	end)
  return arg
end

function XmlParser:ParseXmlText(xmlText)
  local stack = {}
  local top = {Name=nil,Value=nil,Attributes={},ChildNodes={}}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i, j = 1, 1
  while true do
	ni,j,c,label,xarg, empty = string.find(xmlText, "<(%/?)([%w:]+)(.-)(%/?)>", i)
	if not ni then break end
	local text = string.sub(xmlText, i, ni-1)
	if not string.find(text, "^%s*$") then
		top.Value=(top.Value or "")..self:FromXmlString(text)
	end
	if empty == "/" then  -- empty element tag
		table.insert(top.ChildNodes, {Name=label,Value=nil,Attributes=self:ParseArgs(xarg),ChildNodes={}})
	elseif c == "" then   -- start tag
		top = {Name=label, Value=nil, Attributes=self:ParseArgs(xarg), ChildNodes={}}
		table.insert(stack, top)   -- new level
		--log("openTag ="..top.Name)
	else  -- end tag
		local toclose = table.remove(stack)  -- remove top
		--log("closeTag="..toclose.Name)
		top = stack[#stack]
		if #stack < 1 then
		error("XmlParser: nothing to close with "..label)
		end
		if toclose.Name ~= label then
		error("XmlParser: trying to close "..toclose.Name.." with "..label)
		end
		table.insert(top.ChildNodes, toclose)
	end
	i = j+1
  end
  local text = string.sub(xmlText, i)
  if not string.find(text, "^%s*$") then
		stack[#stack].Value=(stack[#stack].Value or "")..self:FromXmlString(text)
  end
  if #stack > 1 then
	error("XmlParser: unclosed "..stack[stack.n].Name)
  end
  return stack[1].ChildNodes[1]
end


--return 

local VIAGrA = {}
VIAGrA.__index = VIAGrA
setmetatable(VIAGrA, {
  __call = function (...)
	return VIAGrA.new(...)
  end,
})
function multiplyMatrices( m1, m2 )
	if #m1[1] ~= #m2 then	   -- inner matrix-dimensions must agree
		return nil	  
	end 
	local res = {}
	for i = 1, #m1 do
		res[i] = {}
		for j = 1, #m2[1] do
			res[i][j] = 0
			for k = 1, #m2 do
				res[i][j] = res[i][j] + m1[i][k] * m2[k][j]
			end
		end
	end
	return res
end
function matrix(x,y,matrix)
	return (matrix[1]*x + matrix[3]*y + matrix[5]), (matrix[2]*x + matrix[4]*y + matrix[6])
	--[[local mat = {
		{matrix[1], matrix[3], matrix[5]},
		{matrix[2], matrix[4], matrix[6]},
		{0,0,1}
	}
	local result = multiplyMatrices(mat, {{x}, {y}, {1}})
	return result[1][1], result[2][1]--]]
end

function transform(x,y,str)
	if str == nil then return x,y end
	local x1, y1
	local args = {}
	for c in string.gmatch(str, '[0-9.-]+') do args[#args+1] = c end
	if str:find("translate") then
		if args[2] == nil then args[2] = 0 end
		x1 = x + args[1]
		y1 = y + args[2]
	elseif str:find("scale") then
		if args[2] == nil then args[2] = args[1] end
		x1,y1 = matrix(x,y, {args[1], 0, 0, args[2], 0, 0})
	elseif str:find("rotate") then
		--implement rotation around point
		local a = math.deg(args[1])
		if #args>1 then
			x1 = x + args[2]
			y1 = y + args[3]
		end
		x1,y1 = matrix(x,y, {math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 0, 0})
		if #args>1 then
			x1 = x - args[2]
			y1 = y - args[3]
		end
	elseif str:find("matrix") then
		x1, y1 = matrix(x,y, args)
	elseif str:find("skewX") then
		local a = math.deg(args[1])
		x1, y1 = matrix(x,y, {1, 0, math.tan(a), 1, 0, 0})
	elseif str:find("skewY") then
		local a = math.deg(args[1])
		x1, y1 = matrix(x,y, {1, math.tan(a), 0, 1, 0, 0})
	end
	return x1, y1
end


function VIAGrA.new(garbage, path)
	local file = love.filesystem.read(path)
	local xml = XmlParser:ParseXmlText(file)
	local self = setmetatable({}, VIAGrA)
	self.width = tonumber(xml.Attributes.width)
	self.height = tonumber(xml.Attributes.height)
	self.layers = {}
	for i,v in pairs(xml.ChildNodes) do
		if v.Name == "g" then
		self.layers[#self.layers+1] = {}
		local currentLayer = self.layers[#self.layers]
		currentLayer.label = v.Attributes.label
		--[[local off = {}
		if v.Attributes.transform ~= nil then
			for c in string.gmatch(v.Attributes.transform, '[0-9.-]+') do off[#off+1] = c end
			 --make this bit work with other transforms
		else
			off = {0,0}
		end]]--
		currentLayer.rectsAndCircles = {}
		currentLayer.paths = {}
		for j,k in ipairs(v.ChildNodes) do
				--[[local off2 = {}
				if k.Attributes.transform ~= nil then
					for c in string.gmatch(v.Attributes.transform, '[0-9.-]+') do off2[#off2+1] = c end
					 --make this bit work with other transforms
				else
					off2 = {0,0}
				end--]]

				if k.Name == "rect" or k.Name == "circle" then

					local fill = {0,0,0,0}
					local stroke = {0,0,0,0}
					if k.Attributes.style ~= nil then
						local hexFill = k.Attributes.style:match("fill:#%x%x%x%x%x%x")

						if hexFill ~= nil then
							local alpha = (k.Attributes.style:match("fill%-opacity:[0-9.]+") or "fill-opacity:1"):sub(14)
							hexFill = hexFill:sub(7)
							fill = {tonumber("0x"..hexFill:sub(1,2)), tonumber("0x"..hexFill:sub(3,4)), tonumber("0x"..hexFill:sub(5,6)), math.floor(tonumber(alpha)*255)}
						end
						local hexStroke = k.Attributes.style:match("stroke:#%x%x%x%x%x%x")
						
						if hexStroke ~= nil then
							
							local alpha = (k.Attributes.style:match("stroke%-opacity:[0-9.]+") or "stroke-opacity:1"):sub(16)
							hexStroke = hexStroke:sub(9)
							if #hexStroke == 6 then
								stroke = {tonumber("0x"..hexStroke:sub(1,2)), tonumber("0x"..hexStroke:sub(3,4)), tonumber("0x"..hexStroke:sub(5,6)), math.floor(tonumber(alpha)*255)}
							else
								stroke = {tonumber("0x"..hexStroke:sub(1,1)), tonumber("0x"..hexStroke:sub(2,2)), tonumber("0x"..hexStroke:sub(3,3)), math.floor(tonumber(alpha)*255)}
							end
						end
					end
					if k.Attributes.fill ~= nil then
						local hexFill = k.Attributes.fill:sub(2)
						alpha = k.Attributes.opacity or 1
						if #hexFill == 6 then
							fill = {tonumber("0x"..hexFill:sub(1,2)), tonumber("0x"..hexFill:sub(3,4)), tonumber("0x"..hexFill:sub(5,6)), math.floor(tonumber(alpha)*255)}
						elseif #hexFill == 3 then
							fill = {tonumber("0x"..hexFill:sub(1,1):rep(2)), tonumber("0x"..hexFill:sub(2,2):rep(2)), tonumber("0x"..hexFill:sub(3,3):rep(2)), math.floor(tonumber(alpha)*255)}
						end
					end
					if k.Attributes.stroke ~= nil then
						local hexStroke = k.Attributes.stroke:sub(2)
						alpha = k.Attributes.opacity or 1
						if #hexStroke == 6 then
							stroke = {tonumber("0x"..hexStroke:sub(1,2)), tonumber("0x"..hexStroke:sub(3,4)), tonumber("0x"..hexStroke:sub(5,6)), math.floor(tonumber(alpha)*255)}
						elseif #hexStroke == 3 then
							stroke = {tonumber("0x"..hexStroke:sub(1,1):rep(2)), tonumber("0x"..hexStroke:sub(2,2):rep(2)), tonumber("0x"..hexStroke:sub(3,3):rep(2)), math.floor(tonumber(alpha)*255)}
						end
					end
					currentLayer.rectsAndCircles[#currentLayer.rectsAndCircles+1] = {
						fill = fill,
						stroke = stroke,
						x = k.Attributes.x or k.Attributes.cx,
						y = k.Attributes.y or k.Attributes.cy,
						w = k.Attributes.width or k.Attributes.r,
						h = k.Attributes.height,
						transform = k.Attributes.transform,
						rectOrCircle = k.Name
					}

					currentLayer.rectsAndCircles[#currentLayer.rectsAndCircles].id = k.Attributes.id
				elseif k.Name == "path" then
					local fill = {0,0,0,0}
					local stroke = {0,0,0,0}
					if k.Attributes.style ~= nil then
						local hexFill = k.Attributes.style:match("fill:#%x%x%x%x%x%x")

						if hexFill ~= nil then
							local alpha = (k.Attributes.style:match("fill%-opacity:[0-9.]+") or "fill-opacity:1"):sub(14)
							hexFill = hexFill:sub(7)
							fill = {tonumber("0x"..hexFill:sub(1,2)), tonumber("0x"..hexFill:sub(3,4)), tonumber("0x"..hexFill:sub(5,6)), math.floor(tonumber(alpha)*255)}
						end
						local hexStroke = k.Attributes.style:match("stroke:#%x%x%x%x%x%x")
						
						if hexStroke ~= nil then
							
							local alpha = (k.Attributes.style:match("stroke%-opacity:[0-9.]+") or "stroke-opacity:1"):sub(16)
							hexStroke = hexStroke:sub(9)
							if #hexStroke == 6 then
								stroke = {tonumber("0x"..hexStroke:sub(1,2)), tonumber("0x"..hexStroke:sub(3,4)), tonumber("0x"..hexStroke:sub(5,6)), math.floor(tonumber(alpha)*255)}
							else
								stroke = {tonumber("0x"..hexStroke:sub(1,1)), tonumber("0x"..hexStroke:sub(2,2)), tonumber("0x"..hexStroke:sub(3,3)), math.floor(tonumber(alpha)*255)}
							end
						end
					end
					if k.Attributes.fill ~= nil then
						local hexFill = k.Attributes.fill:sub(2)
						alpha = k.Attributes.opacity or 1
						if #hexFill == 6 then
							fill = {tonumber("0x"..hexFill:sub(1,2)), tonumber("0x"..hexFill:sub(3,4)), tonumber("0x"..hexFill:sub(5,6)), math.floor(tonumber(alpha)*255)}
						elseif #hexFill == 3 then
							fill = {tonumber("0x"..hexFill:sub(1,1):rep(2)), tonumber("0x"..hexFill:sub(2,2):rep(2)), tonumber("0x"..hexFill:sub(3,3):rep(2)), math.floor(tonumber(alpha)*255)}
						end
					end
					if k.Attributes.stroke ~= nil then
						local hexStroke = k.Attributes.stroke:sub(2)
						alpha = k.Attributes.opacity or 1
						if #hexStroke == 6 then
							stroke = {tonumber("0x"..hexStroke:sub(1,2)), tonumber("0x"..hexStroke:sub(3,4)), tonumber("0x"..hexStroke:sub(5,6)), math.floor(tonumber(alpha)*255)}
						elseif #hexStroke == 3 then
							stroke = {tonumber("0x"..hexStroke:sub(1,1):rep(2)), tonumber("0x"..hexStroke:sub(2,2):rep(2)), tonumber("0x"..hexStroke:sub(3,3):rep(2)), math.floor(tonumber(alpha)*255)}
						end
					end
					currentLayer.paths[#currentLayer.paths+1] = Path(fill, stroke, k.Attributes.d)
				end
			end
		end
	end
	self.canvas = love.graphics.newCanvas()
	love.graphics.setCanvas(self.canvas)
	for i,v in ipairs(self.layers) do
		for j,k in ipairs(v.rectsAndCircles) do
			love.graphics.push()
				if k.transform ~= nil and k.transform:find("matrix") then
					local args = {}
					for c in string.gmatch(k.transform, '[0-9.-]+') do args[#args+1] = c end
					local a,b,c,d,e,f = unpack(args)
					local scale = {math.sqrt(a^2+b^2),math.sqrt(c^2+d^2)}					
					love.graphics.translate(e,f)
					love.graphics.shear(c,b)
					
					love.graphics.scale(unpack(scale))

				end
				love.graphics.setColor(unpack(k.fill))
				if k.rectOrCircle == "rect" then
					love.graphics.rectangle("fill", k.x, k.y, k.w, k.h)
				elseif k.rectOrCircle == "circle" then
					love.graphics.circle("fill", k.x, k.y, k.w)
				end

				love.graphics.setColor(unpack(k.stroke))
				if k.rectOrCircle == "rect" then
					love.graphics.rectangle("line", k.x, k.y, k.w, k.h)
				elseif k.rectOrCircle == "circle" then
					love.graphics.circle("line", k.x, k.y, k.w)
				end
			love.graphics.pop()
		end
  		for j,k in ipairs(v.paths) do
			k:draw()
  		end
  	end
	love.graphics.setCanvas()
	return self
end

function VIAGrA:draw(px, py)
	love.graphics.push()
	love.graphics.translate(px,py)
	love.graphics.setColor(255,255,255,255)
	love.graphics.draw(self.canvas)
	love.graphics.pop()
end
return VIAGrA
