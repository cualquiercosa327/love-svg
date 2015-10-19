--SVG.lua
local XmlParser = require "XmlParser" 
local Shape = require "shape"


local SVG = {}
SVG.__index = SVG
setmetatable(SVG, {
  __call = function (...)
	return SVG.new(...)
  end,
})

function SVG.new(garbage, path)
	local file = love.filesystem.read(path)
	local xml = XmlParser:ParseXmlText(file)
	local self = setmetatable({}, SVG)
	self.width = tonumber(xml.Attributes.width)
	self.height = tonumber(xml.Attributes.height)
	self.shapes = {}
	for i,node in pairs(xml.ChildNodes) do
		self.shapes[i] = Shape(node)
	end
	self.canvas = love.graphics.newCanvas()
	self.canvas:setFilter("nearest")
	self:repaint()
	return self
end

function SVG:repaint()
	local oldCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(self.canvas)
	for i,v in ipairs(self.shapes) do
		--v:repaint()
  	end
	love.graphics.setCanvas(oldCanvas)
end
function SVG:draw(px, py, s)
	love.graphics.push()
	love.graphics.translate(px,py)
	love.graphics.scale(s)
	love.graphics.setColor(255,255,255,255)
	for i,shape in ipairs(self.shapes) do
		shape:draw()
	end
	love.graphics.pop()
end
return SVG