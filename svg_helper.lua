

--credit to http://love2d.org/wiki/User:Pekka for this one.
function love.graphics.affine(xx, xy, yx, yy, ox, oy)
	--a,b,c,d,e,f
	local ex, ey, fx,fy = xx-ox, xy-oy, yx-ox, yy-oy
	if ex*fy<ey*fx then ex,ey,fx,fy=fx,fy,ex,ey end
	local e,f = math.sqrt(ex*ex+ey*ey), math.sqrt(fx*fx+fy*fy)

	ex,ey = ex/e, ey/e
	fx,fy = fx/f, fy/f

	local desiredOrientation=math.atan2(ey+fy,ex+fx)
	local desiredAngle=math.acos(ex*fx+ey*fy)/2
	local z=math.tan(desiredAngle)
	local distortion=math.sqrt((1+z*z)/2)

	love.graphics.translate(ox, oy)
	love.graphics.rotate(desiredOrientation)
	love.graphics.scale(1, z)
	love.graphics.rotate(-math.pi/4)
	love.graphics.scale(e/distortion,f/distortion)
end

local helper = {}


function helper.transform(transformString)
	
	if transformString == nil then return end
	
	for transform in transformString:gmatch('[A-z]+%([0-9%.%,%- ]*%)') do
		local operation = transform:match('[A-z]+')
		--print(operation)
		local args = {}
		local index = 1
		for arg in transform:gmatch('[0-9%.%-]+') do
			args[index] = arg
			index = index + 1
			--print(arg)
		end
		
		if operation == "rotate" then
			if #args > 1 then
				love.graphics.translate(args[2], args[3])
				love.graphics.rotate(math.deg(args[1]))
				love.graphics.translate(-args[2], -args[3])
			else
				love.graphics.rotate(math.deg(args[1]))
			end
		elseif operation == "scale" then
			if #args > 1 then
				love.graphics.scale(args[1], args[2])
			else
				love.graphics.scale(args[1])
			end
		elseif operation == "translate" then
			if #args > 1 then
				love.graphics.translate(args[1], args[2])
			else
				love.graphics.translate(args[1])
			end
		--DO NOT USE love.graphics.shear !!!!
		elseif operation == "skewX" then
			love.graphics.affine(1, 0, math.tan(math.rad(args[1])), 1, 0, 0)
		elseif operation == "skewY" then
			love.graphics.affine(1, math.tan(math.rad(args[1])), 0, 1, 0, 0)
		elseif operation == "matrix" then
			love.graphics.affine(unpack(args))
		else
			print("Ignoring unrecognized transform: "..operation)
		end
	end
end

function helper.calcRGB(colorString)
	if colorString == nil then return end
	local hex = colorString:sub(2)
	--local alpha = 1
	--ignore alpha for now?
	local subLength = #hex/3
	local color = {}
	for i=1,3 do
		color[i] = tonumber("0x"..hex:sub((i-1)*subLength+1, i*subLength)) * (subLength%2 * 0x10 + 1)
	end
	--color[4] = math.floor(alpha*255)
	return color
end

function helper.parseStyle(styleString)
	if styleString == nil then return true,nil,nil,1,1,{} end
	--local style = {}
	local fill,stroke
	local fo,so,o = 1,1,1
	local display = true
	local styles = {}
	for prop,val in styleString:gmatch('([a-z-]+)%s*:%s*([^;]+)') do
		--style[prop] = val
		if prop == "fill" then
			fill = helper.calcRGB(val:match("#%x%x%x%x%x%x"))
		elseif prop == "fill-opacity" then
			fo = tonumber(val)
		elseif prop == "stroke" then
			stroke = helper.calcRGB(val:match("#%x%x%x%x%x%x"))
		elseif prop == "stroke-opacity" then
			so = tonumber(val)
		elseif prop == "opacity" then
			o = tonumber(val)
		elseif prop == "display" then
			
			display = (val:match('none') == nil)
		else
			--wip
			styles[prop] = parseStyleVal(val)
		end
	end
	return display, fill, stroke, fo*o, so*o, styles
		
end
function parseStyleVal(str)
	local values = {}
	
	for val in str:gmatch('([^%s]+)') do
		print(val)
		values[#values+1] = val
	end
	if #values > 1 then
		return values --for now
	end
	local val = values[1]
	--number
	local num,unit = val:match('([0-9%.%-]+)([a-z]*)')
	if num ~= nil then
		return num --for now
	end
	--number
	local str = val:match('%s*([^%s]+)%s*')
	if str ~= nil then
		return str --for now
	end
	return values
end

return helper
