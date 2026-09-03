local songList = {}
local selected = 1
local difficulties = {}
local curDiff = 1

function onCreate()
	songList = getFreeplaySongList()

	for i, song in ipairs(songList) do
		local tag = 'song' .. i
		makeLuaText(tag, song.songName, 400, 40, 40 + (i * 42))
		setTextSize(tag, 28)
		addLuaText(tag)
	end

	makeLuaText('diffText', '', 200, 40, 660)
	setTextSize('diffText', 24)
	addLuaText('diffText')

	if #songList > 0 then
		selectSong()
	end
end

function selectSong()
	difficulties = selectFreeplaySong(songList[selected].week, songList[selected].folder)
	if curDiff > #difficulties then curDiff = #difficulties end
	if curDiff < 1 then curDiff = 1 end

	for i, song in ipairs(songList) do
		setProperty('song' .. i .. '.alpha', (i == selected) and 1 or 0.5)
	end

	local score = getFreeplayScore(songList[selected].songName, curDiff - 1)
	setTextString('diffText', difficulties[curDiff] .. '  |  Score: ' .. score)
end

function onUpdate(elapsed)
	if keyJustPressed('up') then
		selected = selected - 1
		if selected < 1 then selected = #songList end
		selectSong()
	elseif keyJustPressed('down') then
		selected = selected + 1
		if selected > #songList then selected = 1 end
		selectSong()
	elseif keyJustPressed('left') then
		curDiff = curDiff - 1
		if curDiff < 1 then curDiff = #difficulties end
		selectSong()
	elseif keyJustPressed('right') then
		curDiff = curDiff + 1
		if curDiff > #difficulties then curDiff = 1 end
		selectSong()
	elseif keyJustPressed('accept') then
		playFreeplaySong(songList[selected].songName, curDiff - 1)
	elseif keyJustPressed('back') then
		exitCustomState()
	end
end
