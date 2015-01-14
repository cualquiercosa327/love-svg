# VIAGrA
Vector Illustration And Graphics API (for the Löve framework)

Disclaimer: This library is a work in progress. It lacks support for many SVG features and may not work in all cases.

#Usage:
```
local SVG = require "VIAGrA"
local exampleSVG = SVG("test.svg")
--whatever else
function love.draw()
	exampleSVG:draw(0, 0)
end
```
