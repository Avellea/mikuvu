pcall(Network.term)

-- Initialize network
Network.init()

-- Seed random number generator
local rh,rm,rs = System.getTime()
math.randomseed(rh .. rm .. rs)

-- Load JSON parser
local json = dofile("app0:/deps/lua/json.lua")

-- Load font and set font size
local fnt0 = Font.load("app0:/deps/font/ShinGo.ttf")
Font.setPixelSizes(fnt0, 25)

-- Define colors
local white, translucentBlack = Color.new(255,255,255), Color.new(0,0,0,160)

-- Init constants
local dataFolder = "ux0:/data/MikuVU"
local saveFolder = dataFolder .. "/SAVED"

-- Init values
local currentId = nil		-- ID of the currently loaded image, used when saving images
local autoNext = 0			-- Auto next variable
local seconds = 5			-- Delay in seconds
local fadeImages = false	-- Fade in and out images?
local response = nil		-- Response of function ID (used in main loop)
local message = ""			-- Callback Message (used in main loop)
local status = nil			-- Callback Status	(used in main loop)
local fullRes = false		-- Is the loaded image a sample or full-size?
local fullUrl = ""			-- Hold URL of full-size image for downloading
local tmr = Timer.new()		-- Set timer for auto next
Timer.pause(tmr)			-- Pause timer at 0 (would run otherwise)
local tmr2 = Timer.new()	-- Set timer for delays in main loop
Timer.pause(tmr2)			-- Pause timer at 0
local buttonDown = false	-- Ensures no input lag and no unpredicted calls to functions every loop
local menu = false			-- If menu is open
local jsonValid = true		-- Valid JSON Response (Default true)
local drawMode = false		-- The space in between Graphics.initBlend and Graphics.termBlend where anything can happen.
local imageDrawn = false	-- Is the image fully shown?
local imgData = {}			-- Arguments for the last rendered image
local offlineMode = false	-- If the user has no internet, just show a slideshow of saved images
local offlineImgIndex = 0	-- Currently displayed image # in folder
local offlineImgList = {}	-- List of all saved images for offline use

-- Functions

-- Sets bool when drawMode is active
local old_init = Graphics.initBlend
local old_term = Graphics.termBlend

function Graphics.initBlend()
	drawMode = true
	old_init()
end

function Graphics.termBlend()
	drawMode = false
	old_term()
end

-- Increases auto next delay
function timerIncrease()
	local id = 1
	if menu then
		if seconds >= 5 and seconds < 60 then
			seconds = seconds + 5
		end
	end
	return id
end

-- Decreases auto next delay
function timerDecrease()
	local id = 2
	if menu then
		if seconds > 5 and seconds <= 60 then
			seconds = seconds - 5
		end
	end
	return id
end

-- Toggles auto next
function toggleAutoNext()
	local id = 3
	if menu then
		if autoNext == 0 then
			if not Timer.isPlaying(tmr) then
				Timer.resume(tmr)
			end
			Timer.setTime(tmr, seconds * 1000)	-- Set time in milliseconds
			autoNext = 1
		else
			if Timer.isPlaying(tmr) then
				Timer.pause(tmr)
			end
			autoNext = 0
		end
	end
	return id
end

-- Saves image with the ID as name
function saveImage()
	local id = 4
	local fullExt = string.lower(string.match(fullUrl,"%.[%a%d]+$"))
	if offlineMode then
		return id, "Error | Offline Mode", 2
	end
	if System.doesFileExist(saveFolder .. "/" .. currentId .. fullExt) then
    return id, "Error | Already Saved", 0
	elseif img ~= nil then
		if fullRes then
			local new = System.openFile(saveFolder .. "/" .. currentId .. fullExt, FCREATE)
			System.writeFile(new, image, size2)		-- Image data and Size Loaded in getmiku()
			System.closeFile(new)
		else
			Network.downloadFile(fullUrl, saveFolder .. "/" .. currentId .. fullExt)
		end
		return id, "Saved | " .. currentId .. fullExt, 1
	else	
		return id, "Error | Save Failed", 2
	end
end

--Copy Function
function copyFile(src, dst)
    local s = System.openFile(src, FREAD)
    local d = System.openFile(dst, FCREATE)
    local size = System.sizeFile(s)
    local buf = System.readFile(s, size)
    System.closeFile(s)
    System.writeFile(d, buf, size)
    System.closeFile(d)
end

-- Toggles fade
function toggleFade()
	local id = 5
	fadeImages = not(fadeImages)
	
	if fadeImages then
		return id, "Transition | On"
	else
		return id, "Transition | Off"
	end
end

-- If the network is ever disconnected and reconnected for whatever reason
-- press select to re-initialize the system network (lua Network.init doesn't seem to work?)
function connectNetwork()
	local id = 6
	result = Network.requestString("https://captive.apple.com/")
	if Network.isWifiEnabled() then offlineMode = false
	end
	return id, "Network | Reset"
end

-- Fades in an image at the specified scale in a certain amount of time.
-- 4x fadeSpeed is approximately 1 second on my Vita.
function fadeInImageScale(x, y, img, x_scale, y_scale, fadeSpeed)
	local prevDrawMode = drawMode

	if drawMode then
		Graphics.termBlend()
		Screen.flip()
		Screen.waitVblankStart()
	end
	
	for i=1,255,fadeSpeed do
		Graphics.initBlend()
		--Screen.clear()
		Graphics.fillRect(0,960,0,544,Color.new(0,0,0,tonumber(i/4)))
		Graphics.drawScaleImage(x, y, img, x_scale, y_scale, Color.new(255,255,255,i))
		Graphics.termBlend()
		Screen.flip()
		Screen.waitVblankStart()
	end
	
	if prevDrawMode then
		Graphics.initBlend()
	end
end

-- Gets and loads pictures from decoded JSON
function getmiku()

	::getmiku::
	-- Clear last loaded image from memory
	if img ~= nil then
		Graphics.freeImage(img)
		img = nil
	end
		
	if Network.isWifiEnabled() then
		Network.downloadFile("https://safebooru.org/index.php?limit=1&page=dapi&s=post&q=index&json=1&tags=hatsune_miku+sort:random", dataFolder.."/post.json") 
		local file1 = System.openFile(dataFolder.."/post.json", FREAD)
		local size1 = System.sizeFile(file1)
		local jsonEncoded = System.readFile(file1, size1)					-- Encoded JSON file data
		local pcallStat, jsonDecoded = pcall(json.decode, jsonEncoded)		-- Decoded JSON to table
		System.closeFile(file1)
		System.deleteFile(dataFolder.."/post.json")
		if not pcallStat then
			jsonValid = pcallStat
			return
		end
		jsonValid = pcallStat
		
		url = jsonDecoded[1]["sample_url"]
		fullUrl = jsonDecoded[1]["file_url"]
		fullRes = false
		if url == "" then 
			url = fullUrl
			fullRes = true
		end
		
		fileExt = string.lower(string.sub(url, -4, -1)) 
		if fileExt ~= ".jpeg" and fileExt ~= ".jpg" and fileExt ~= ".png" then
			goto getmiku
		end
		
		currentId = jsonDecoded[1]["id"]
		
		Network.downloadFile(url, dataFolder.."/Miku")
		local file2 = System.openFile(dataFolder.."/Miku", FREAD)
		size2 = System.sizeFile(file2)
		print("[MikuVU]		ID: "..jsonDecoded[1]["id"]..", SIZE: "..size2)
		if size2 == 0 then
			System.closeFile(file2)
			goto getmiku
		end
		image = System.readFile(file2, size2)
		System.closeFile(file2)
		img = Graphics.loadImage(dataFolder.."/Miku")
		System.deleteFile(dataFolder.."/Miku")
	else
		-- if no internet, load images in /saved/
		if System.doesDirExist(saveFolder) and not(offlineMode) then
			local savedFiles = System.listDirectory(saveFolder)
			local fullExt = ""
			for _, image in ipairs(savedFiles) do
				fullExt = string.lower(string.match(image["name"],"%.[%a%d]+$"))
				if fullExt == ".jpg" or fullExt == ".jpeg" or fullExt == ".png" or fullExt == ".bmp" and not size== 0 then
					offlineImgList[#offlineImgList+1] = image["name"]
				end
			end
			offlineMode = true
		end
		
		-- if images already loaded, display the next one
		if #offlineImgList > 0 then
			local lastIndex = offlineImgIndex
			::randomize::
			offlineImgIndex = math.random(1,#offlineImgList-1)
			if offlineImgIndex == lastIndex then goto randomize end
			
			img = Graphics.loadImage(saveFolder.."/"..offlineImgList[offlineImgIndex])
		end
	end
	
	-- if no wifi and no images, then something is wrong and image should NOT be loaded
	if #offlineImgList == 0 and not(Network.isWifiEnabled()) then
		img = nil
	else
		width = Graphics.getImageWidth(img)
		height = Graphics.getImageHeight(img)
		drawWidth = 480 - (width * 544 / height / 2)
		drawHeight = 272 - (height * 960 / width / 2)
		if (autoNext == 1) then 
			Timer.setTime(tmr, seconds * 1000) -- Set time in seconds
		end
		imageDrawn = false
	end
end

-- Check if ux0:/data/MikuVU exists
if not System.doesDirExist(dataFolder) then
    System.createDirectory(dataFolder)
end
-- Check if SAVED folder exists
if not System.doesDirExist(saveFolder) then
    System.createDirectory(saveFolder)
end
-- Check sample 
if not System.doesFileExist("ux0:/data/MikuVU/SAVED/SAMPLE1.png") then
    copyFile("app0:/deps/sample/SAMPLE.png", "ux0:data/MikuVU/SAVED/SAMPLE1.png")
end
if not System.doesFileExist("ux0:/data/MikuVU/SAVED/SAMPLE2.png") then
    copyFile("app0:/deps/sample/SAMPLE.png", "ux0:data/MikuVU/SAVED/SAMPLE2.png")
end
if not System.doesFileExist("ux0:/data/MikuVU/SAVED/SAMPLE3.png") then
    copyFile("app0:/deps/sample/SAMPLE.png", "ux0:data/MikuVU/SAVED/SAMPLE3.png")
end

getmiku()

-- Main loop
while true do
	-- Local init values
	local time = Timer.getTime(tmr)			            -- Auto next timer value
	local timeSec = math.floor(-time / 1000) + 1		-- Auto next timer value in seconds for user
	local pad = Controls.read()                         -- Reading controls
	local delay = Timer.getTime(tmr2)		            -- Timer used for informational display delays
	local delaySec = 4000					            -- Value used for the delay timer

	-- Controls
	if jsonValid and img ~= nil then
		if Controls.check(pad, SCE_CTRL_CROSS) or Controls.check(pad, SCE_CTRL_DOWN) or (autoNext == 1 and time > 0) then
			getmiku()
		elseif Controls.check(pad, SCE_CTRL_CIRCLE) or Controls.check(pad, SCE_CTRL_RIGHT) then
			if not buttonDown then
				response = timerIncrease()
			end
			buttonDown = true
		elseif Controls.check(pad, SCE_CTRL_SQUARE) or Controls.check(pad, SCE_CTRL_LEFT) then
			if not buttonDown then
				response = timerDecrease()
			end
			buttonDown = true
		elseif (Controls.check(pad, SCE_CTRL_TRIANGLE) or Controls.check(pad, SCE_CTRL_UP)) then
			if not buttonDown then
				response = toggleAutoNext()
			end
			buttonDown = true
		elseif (Controls.check(pad, SCE_CTRL_LTRIGGER) or Controls.check(pad, SCE_CTRL_RTRIGGER)) then
			if not buttonDown then
				response, message, status = saveImage()
			end
			buttonDown = true
		elseif (Controls.check(pad, SCE_CTRL_START)) then
			if not buttonDown then
				response, message = toggleFade()
			end
			buttonDown = true
		elseif (Controls.check(pad, SCE_CTRL_SELECT)) then
			if not buttonDown then
				response, message = connectNetwork()
			end
			buttonDown = true
		else
			buttonDown = false
		end
	end

	-- "Menu" delay
	if buttonDown then		-- Button was pressed, show information
		if Timer.isPlaying(tmr2) then
			Timer.pause(tmr2)
		end
		Timer.resume(tmr2)
		Timer.setTime(tmr2, delaySec)	-- Set delay in milliseconds
	else								-- Handle the informational display delay timer
		if delay > 0 then
			Timer.pause(tmr2)
		end
	end

	-- Start drawing
	Graphics.initBlend()
	if not jsonValid then
		getmiku()
	elseif img == nil then
		getmiku()
	else
		if height >= width then
			imgData = {drawWidth, 0, img, 544 / height, 544 / height, 4}
		elseif width > height then
			imgData = {0, drawHeight, img, 960 / width, 960 / width, 4}
		end
		
		if fadeImages and not(imageDrawn) then
			fadeInImageScale(imgData[1], imgData[2], imgData[3], imgData[4], imgData[5], imgData[6])
			imageDrawn = true
		end
		
		Screen.clear()
		Graphics.drawScaleImage(imgData[1], imgData[2], imgData[3], imgData[4], imgData[5])
	end

	-- "Menu"
	if delay < 0 then		-- Informational display delay timer is set, print info by function ID
		menu = true			-- Set menu visibility to true
		if response == 1 or response == 2 then 								-- timerIncrease()/timerDecrease()
			Graphics.fillRect(15, 175, 30, 80, translucentBlack)
			Font.print(fnt0, 20, 40, string.format("Delay | %02ds", seconds), white)
		elseif response == 3 then											-- toggleAutoNext()
			Graphics.fillRect(15, 175, 30, 80, translucentBlack)								
			if Timer.isPlaying(tmr) then
				Font.print(fnt0, 20, 40, string.format("Timer | %02ds", timeSec), white)
			else
				Font.print(fnt0, 20, 40, "Timer | Off", white)
			end
		elseif response == 4 then
			menu = false
			if status == 0 then
				Graphics.fillRect(15, 295, 30, 80, translucentBlack)
			elseif status == 1 then
				Graphics.fillRect(15, 340, 30, 80, translucentBlack)
			else
				Graphics.fillRect(15, 270, 30, 80, translucentBlack)
			end
			Font.print(fnt0, 20, 40, message, white)
		elseif response == 5 then
			Graphics.fillRect(15, 220, 30, 80, translucentBlack) 
			Font.print(fnt0, 20, 40, message, white) 
		elseif repsonse == 6 then
			Graphics.fillRect(15, 235, 30, 80, translucentBlack) 
			Font.print(fnt0, 20, 40, message, white) 
		else
			menu = false
			Graphics.fillRect(15, 235, 30, 80, translucentBlack) 
			Font.print(fnt0, 20, 40, message, white) 
		end
	else
		menu = false		-- Set menu visibility to false
	end
	
	-- Finish drawing
	Graphics.termBlend()
	Screen.flip()
	Screen.waitVblankStart()
end
