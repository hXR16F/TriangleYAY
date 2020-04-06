--[[
	Programmed by hXR16F
	hXR16F.ar@gmail.com / https://github.com/hXR16F
]]

-- Setting window sizes
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 600

font = love.graphics.setNewFont("DisposableDroidBB.ttf", 30)
font_height = tonumber(font:getHeight())

-- Player settings
local player = {}
player.position_x = WINDOW_WIDTH / 2
player.position_y = WINDOW_HEIGHT / 2
player.radius = 12
player.speed = 300

-- Creating triangle (circle)
local circles = {}
function create_circle(x, y, r, s)
	local circle = {
		x = x,
		y = y,

		r = r,
		s = 3
	}
	-- Drawing triangle
	function circle.draw()
		love.graphics.setShader(shader_objects)
		love.graphics.circle("line", circle.x, circle.y, circle.r, circle.s)
	end
	-- Adding triangle to array
	circles[#circles + 1] = circle
	return circle
end

-- RGB function
function rgb(r, g, b)
	return r/255, g/255, b/255
end

-- Shake function
local t, shakeDuration, shakeMagnitude = 0, -1, 0
function startShake(duration, magnitude)
	t, shakeDuration, shakeMagnitude = 0, duration or 1, magnitude or 5
end

local tt = 0
function love.load()
	-- Window parameters
	love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, {
		fullscreen = false,
		resizable = false,
		vsync = true
	})
	love.window.setTitle("TriangleYAY")

	circles_num = 0
	points = 0
	points_per_second = 0
	game_over = 0
	first = 0
	gameplay_time = 60

	-- GLSL shaders
	shader_objects = love.graphics.newShader [[
		extern number time;
			vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
		{
			return vec4((1.0 + sin(time)) / 2.0, abs(cos(time)), abs(sin(time)), 1.0);
		}
	]]
	shader_game = love.graphics.newShader [[
		extern number time;
		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			vec4 pixel = Texel(texture, texture_coords);
		  
			number noise = 0.005 * sin((2 * 3.14159) * (time * 8) * texture_coords.y);
			number height = floor(texture_coords.y * 600);
		  
			if (mod(height, 2) != 0) {
				texture_coords.x += noise;
				return Texel(texture, texture_coords);
			} else {
				return pixel;
			}
		}
	]]
	shader_game_over = love.graphics.newShader [[
		extern number time;
		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			vec4 pixel = Texel(texture, texture_coords);
		  
			number noise = 0.006 * sin((2 * 3.14) * (time));
			number height = floor(texture_coords.y * 600);
		  
			if (mod(height, 2) != 0){
				texture_coords.x += noise;
				return Texel(texture, texture_coords);
			} else {
				return pixel;
			}
		}
	]]

	-- Audio
	src1 = love.audio.newSource("collect.wav", "static")
	src2 = love.audio.newSource("music.ogg", "stream")
	src3 = love.audio.newSource("game_over.wav", "static")
	src4 = love.audio.newSource("win.wav", "static")
	src1:setVolume(1)
	src2:setVolume(0.5)
	src3:setVolume(1)
	src4:setVolume(1)
	src2:play()

	start_time = os.time()
end

function love.update(dt)
	fps = love.timer.getFPS()

	-- Controls: WASD or arrow keys, ESC to quit
	if love.keyboard.isDown("escape") then love.event.push("quit") end
	if game_over == 0 then
		if love.keyboard.isDown("s") or love.keyboard.isDown("down") then player.position_y = player.position_y + (player.speed * dt) end
		if love.keyboard.isDown("w") or love.keyboard.isDown("up") then player.position_y = player.position_y - (player.speed * dt) end
		if love.keyboard.isDown("d") or love.keyboard.isDown("right") then player.position_x = player.position_x + (player.speed * dt) end
		if love.keyboard.isDown("a") or love.keyboard.isDown("left") then player.position_x = player.position_x - (player.speed * dt) end

		-- Generating new triangle if player catched one
		if circles_num < 3 then
			for i=1, (3 - circles_num) do
				create_circle(love.math.random(30, WINDOW_WIDTH - 30), love.math.random(30, WINDOW_HEIGHT - 30), 18, 3)
			end
			circles_num = 3
		end

		-- Detecting collision between player and triangle
		for i = #circles, 1, -1 do
			if player.position_x >= circles[i].x - (circles[i].r + 1) and
			player.position_x <= circles[i].x + (circles[i].r + 1) and
			player.position_y >= circles[i].y - (circles[i].r + 1) and
			player.position_y <= circles[i].y + (circles[i].r + 1) then
				-- Effects
				src1:play()
				startShake(0.05, 12)
				points = points + 1
				circles_num = circles_num - 1
				table.remove(circles, i)
			end
		end

		-- Player can't run outside window
		if player.position_x <= 0 then player.position_x = player.position_x + (player.speed * dt) end
		if player.position_x >= WINDOW_WIDTH then player.position_x = player.position_x - (player.speed * dt) end
		if player.position_y <= 0 then player.position_y = player.position_y + (player.speed * dt) end
		if player.position_y >= WINDOW_HEIGHT then player.position_y = player.position_y - (player.speed * dt) end

		-- Increasing speed, more points = more speed
		player.speed = 300 * (1 + (points / 100))

		end_time = os.time()
		elapsed_time = os.difftime(end_time - start_time)
		time_remaining = gameplay_time - elapsed_time
		points_per_second = math.ceil((points / elapsed_time * 1000)) * 0.001
		
		tt = tt + dt * 1.5
		shader_objects:send("time", tt)
	end

	-- Shake effect
	if t < shakeDuration then
		t = t + dt
	end
	
	-- End round
	if elapsed_time == gameplay_time then
		if first ~= 1 then
			startShake(0.8, 6)
			src3:play()
			src2:stop()
			first = 1
			score = math.ceil((((points_per_second + 1) * 1000) * points) / 10)
			game_over = 1
			src4:play()
		end
	end
end

function love.draw()
	dt = love.timer.getTime() % 8
	if game_over == 0 then
		love.graphics.setShader()
		drawShake()

		love.graphics.setColor(rgb(255, 255, 255))
		love.graphics.print(fps .. " fps", 4, 2)

		shader_game:send("time", dt)
		love.graphics.setShader(shader_game)

		love.graphics.printf(points .. " points\nAvg. " .. points_per_second .. " p/s", 0, (WINDOW_HEIGHT / 2) - (font_height * 1.5), WINDOW_WIDTH, "center")
		love.graphics.printf("Time remaining: " .. time_remaining .. "s", 0, (font_height * 1.5), WINDOW_WIDTH, "center")

		love.graphics.setShader(shader_objects)
		love.graphics.circle("fill", player.position_x, player.position_y, player.radius, player.segments)

		for i = 1, #circles do
			circles[i].draw()
		end
	else
		-- Game over screen
		love.graphics.setShader()
		drawShake()

		love.graphics.setColor(rgb(255, 255, 255))
		font = love.graphics.setNewFont("DisposableDroidBB.ttf", 28)
		love.graphics.print(fps .. " fps", 4, 2)

		shader_game_over:send("time", dt)
		love.graphics.setShader(shader_game_over)

		font = love.graphics.setNewFont("DisposableDroidBB.ttf", 64)
		love.graphics.printf("Score - " .. score, 0, (WINDOW_HEIGHT / 2) - (font_height * 1.5), WINDOW_WIDTH, "center")
	end
end

-- Drawing shake function
function drawShake()
	if t < shakeDuration then
		local dx = love.math.random(-shakeMagnitude, shakeMagnitude)
		local dy = love.math.random(-shakeMagnitude, shakeMagnitude)
		love.graphics.translate(dx, dy)
	end
end