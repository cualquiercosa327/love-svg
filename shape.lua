local Helper = require 'svg_helper'
local Path = require 'path'

local Shape = {}
Shape.__index = Shape
function Shape.new(garbage, element)
	local self = setmetatable({}, Shape)
	self.type = element.Name
	self.pathDef = element.Attributes.d or ""
	self.transform = element.Attributes.transform or ""
	self.x = element.Attributes.x or element.Attributes.cx or 0
	self.y = element.Attributes.y or element.Attributes.cy or 0
	self.w = element.Attributes.width or element.Attributes.rx or element.Attributes.r or 0
	self.h = element.Attributes.height or element.Attributes.ry or element.Attributes.r or 0
		
	local tempFill = Helper.calcRGB(element.Attributes.fill)
	local tempStroke = Helper.calcRGB(element.Attributes.stroke)
	local tempO = element.Attributes.opacity or 1
	
	local display, tempFill2, tempStroke2, fo, so, otherStyles = Helper.parseStyle(element.Attributes.style)
	self.display = display
	self.style = otherStyles
	self.fill = tempFill or tempFill2 or {0,0,0}
	if self.fill == nil then
		self.fill = {0,0,0,0}
	else
		self.fill[4] = fo * tempO * 255
	end
	
	self.stroke = tempStroke or tempStroke2
	if self.stroke == nil then
		self.stroke = {0,0,0,0}
	else
		self.stroke[4] = so * tempO * 255
	end
	
	self._attributes = element.Attributes
	--self.canvas = love.graphics.newCanvas()
	--self.canvas:setFilter("nearest")
	self.children = {}
	for i,child in ipairs(element.ChildNodes) do
		self.children[i] = Shape(child)
	end
	
	if self.type == "path" then
		self.path = Path(self.fill, self.stroke, self._attributes, self.style["fill-rule"])
	else
		self.path = "you really need fix this at some point, logan"
	end
	
	self:repaint()
	return self
end

setmetatable(Shape, {__call=Shape.new})

function Shape:draw(scale)
	if not self.display then return end
	--local oldCanvas = love.graphics.getCanvas()
	--love.graphics.setCanvas(self.canvas)
	love.graphics.push()
		--local obm = love.graphics.getBlendMode()
		--love.graphics.setBlendMode("additive")
		love.graphics.setLineWidth(self.style["stroke-width"] or 1)
		--love.graphics.setLineStyle("smooth")
		Helper.transform(self.transform)
		if self.type == "rect" then
			love.graphics.setColor(unpack(self.fill))
			love.graphics.rectangle("fill", self.x,self.y,self.w,self.h)
			love.graphics.setColor(unpack(self.stroke))
			love.graphics.rectangle("line", self.x,self.y,self.w,self.h)
		elseif self.type == "circle" then
			love.graphics.setColor(unpack(self.fill))
			love.graphics.circle("fill", self.x, self.y, self.w)
			love.graphics.setColor(unpack(self.stroke))
			love.graphics.circle("line", self.x, self.y, self.w)
		elseif self.type == "ellipse" then
			--stuff
		elseif self.type == "path" then
			self.path:draw()
		elseif self.type == "g" then
			for i,child in ipairs(self.children) do
				child:draw()
			end
		end
		--love.graphics.setBlendMode(obm)
	love.graphics.pop()
	--love.graphics.setCanvas(oldCanvas)
end
function Shape:repaint()

end
--[[
function Shape:draw()
	local obm = love.graphics.getBlendMode()
	love.graphics.setBlendMode("alpha")
		love.graphics.draw(self.canvas)
		for i,child in ipairs(self.children) do
			child:draw()
		end
	love.graphics.setBlendMode(obm)
end
--]]
return Shape
