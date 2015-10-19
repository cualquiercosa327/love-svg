# love-svg (working name)
An SVG library for Love
Disclaimer: This library is a work in progress. It lacks support for many SVG features and may not work in all cases.

#Usage:
```
local SVG = require "svg"
local exampleSVG = SVG("test.svg")
--whatever else
function love.draw()
	exampleSVG:draw(0, 0)
end
```
