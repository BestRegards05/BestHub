-- TheBest v016 diagnostics starts before the main source is compiled.
local diagnostics = (function()
	local old = _G.TheBestDiagnostics
	if type(old) == "table" and type(old.Close) == "function" then pcall(old.Close) end
	local state = { Version = "v016", Status = "starting", Events = {}, Connections = {}, Closed = false, Signatures = {}, SignatureOrder = {}, DuplicateCount = 0 }
	local busy, scheduled = false, false
	local filename = "TheBest_v016_error-report.txt"
	local absolute = "D:/MyProfile10/Desktop/Игры/Roblox/TheBest Versions/" .. filename
	local function timestamp()
		local ok, value = pcall(os.date, "!%Y-%m-%d %H:%M:%S UTC")
		return ok and value or tostring(os.clock())
	end
	local function folderExists(path)
		if type(isfolder) ~= "function" then return false end
		local ok, exists = pcall(isfolder, path)
		return ok and exists == true
	end
	local function render()
		local rows = {
			"TheBest v016 error report", "Updated: " .. timestamp(),
			"Status: " .. tostring(state.Status), "Report: " .. tostring(state.Path or absolute),
			"Main source: @TheBest_v016", "Console entries can also originate from the game.",
			"Repeated entries suppressed: " .. tostring(state.DuplicateCount), "",
		}
		for _, event in ipairs(state.Events) do rows[#rows + 1] = event end
		return table.concat(rows, "\n") .. "\n"
	end
	function state.Flush()
		if busy or state.Closed or type(writefile) ~= "function" then return false end
		busy = true
		local paths = {}
		if state.Path then paths[#paths + 1] = state.Path end
		if folderExists("TheBest_Reports") then paths[#paths + 1] = "TheBest_Reports/" .. filename end
		paths[#paths + 1] = absolute
		if type(makefolder) == "function" then
			if not folderExists("thebest") then pcall(makefolder, "thebest") end
			if not folderExists("thebest/error-reports") then pcall(makefolder, "thebest/error-reports") end
		end
		paths[#paths + 1] = "thebest/error-reports/" .. filename
		for _, path in ipairs(paths) do
			state.Path = path
			local contents = render()
			local ok = pcall(writefile, path, contents)
			if ok and type(readfile) == "function" then
				local readOk, saved = pcall(readfile, path)
				ok = readOk and saved == contents
			end
			if ok then busy = false; return true end
		end
		state.Path = nil
		busy = false
		return false
	end
	function state.Record(kind, message, trace)
		if state.Closed or busy then return end
		local details = tostring(message or "")
		if trace and trace ~= "" then details = details .. "\n" .. tostring(trace) end
		details = details:sub(1, 16000)
		local signature = tostring(kind) .. details
		if state.Signatures[signature] then
			state.DuplicateCount += 1
			return
		end
		state.Signatures[signature] = true
		state.SignatureOrder[#state.SignatureOrder + 1] = signature
		state.Events[#state.Events + 1] = "[" .. timestamp() .. "] " .. tostring(kind) .. "\n" .. details .. "\n"
		if #state.Events > 120 then
			table.remove(state.Events, 1)
			local oldest = table.remove(state.SignatureOrder, 1)
			state.Signatures[oldest] = nil
		end
		if not scheduled then
			scheduled = true
			task.delay(0.25, function() scheduled = false; state.Flush() end)
		end
	end
	function state.Close()
		if state.Closed then return end
		state.Flush()
		state.Closed = true
		for _, connection in ipairs(state.Connections) do pcall(function() connection:Disconnect() end) end
		table.clear(state.Connections)
	end
	_G.TheBestDiagnostics = state
	pcall(function()
		local signal = game:GetService("LogService").MessageOut
		table.insert(state.Connections, signal:Connect(function(message, kind)
			if kind == Enum.MessageType.MessageError then state.Record("CONSOLE ERROR", message)
			elseif kind == Enum.MessageType.MessageWarning and tostring(message):find("THEBEST", 1, true) then
				state.Record("THEBEST WARNING", message)
			end
		end))
	end)
	pcall(function()
		table.insert(state.Connections, game:GetService("ScriptContext").Error:Connect(function(message, trace)
			state.Record("SCRIPT ERROR", message, trace)
		end))
	end)
	state.Record("START", "Compiling main source.")
	state.Flush()
	return state
end)()

local function startTheBest(source)
	if type(loadstring) ~= "function" then
		diagnostics.Status = "failed: loadstring unavailable"
		diagnostics.Record("BOOT ERROR", diagnostics.Status)
		diagnostics.Flush()
		warn("[THEBEST] loadstring is unavailable; report: " .. tostring(diagnostics.Path))
		return
	end
	local ok, chunk, compileError = pcall(loadstring, source, "@TheBest_v016")
	if not ok or type(chunk) ~= "function" then
		diagnostics.Status = "compile failed"
		diagnostics.Record("COMPILE ERROR", ok and compileError or chunk)
		diagnostics.Flush()
		warn("[THEBEST] Compile failed; report: " .. tostring(diagnostics.Path))
		return
	end
	if type(setfenv) == "function" and type(getfenv) == "function" then pcall(setfenv, chunk, getfenv()) end
	diagnostics.Status = "running"
	diagnostics.Flush()
	local ran, failure = xpcall(chunk, function(problem)
		local trace = tostring(problem)
		if debug and type(debug.traceback) == "function" then trace = debug.traceback(trace, 2) end
		diagnostics.Status = "startup failed"
		diagnostics.Record("UNHANDLED ERROR", trace)
		diagnostics.Flush()
		return trace
	end)
	if ran then
		diagnostics.Status = "startup finished"
		diagnostics.Record("READY", "Main startup returned. Runtime error listeners remain active.")
	else
 pcall(function()
  local roots={game:GetService("CoreGui")}
  local player=game:GetService("Players").LocalPlayer
  local gui=player and player:FindFirstChildOfClass("PlayerGui")
  if gui then roots[#roots+1]=gui end
  for _,root in ipairs(roots) do
   local menu=root:FindFirstChild("MainFrameGUI")
   local status=menu and menu:FindFirstChild("BuildStatus",true)
   if status and status:IsA("TextLabel") then
    status.Text="Startup failed\nSee v016 error report"
    status.TextWrapped=true
   end
  end
 end)
 warn("[THEBEST] " .. tostring(failure))
end
	diagnostics.Flush()
	print("[THEBEST] Error report: " .. tostring(diagnostics.Path or "file writing unavailable"))
end

local main=readfile("thebest/runtime-v016/main.lua")
local function applyStandReportPatch(source)
 if #source==3004497 and source:find("local rollReporter=(",1,true) and source:find("local buildEquipmentList=(",1,true) then return source end
 assert(#source==3000017,"TheBest source patch: unexpected base size")
 local edits={{At=466681,Old=[===[					return "None"
]===],New=[===[					return "None",false
]===]},
{At=466832,Old=[===[				return succeeded and tostring(result or "None") or "None"
]===],New=[===[				return succeeded and tostring(result or "None") or "None", succeeded and result~=nil
]===]},
{At=470643,Old=[===[]===],New=[===[ local rollReporter=(function(deps)
 local stopped,inFlight,sequence=false,false,0
 local function standName()
  local value=deps.Stand()
  return type(value)=="string" and value~="" and value~="None" and value or nil
 end
 return {Report=function(mode,active)
  if stopped or not active() then return end
  local deadline=deps.Clock()+4
  local stand=standName()
  while not stand and not stopped and active() and deps.Clock()<deadline do
   deps.Wait(.05);stand=standName()
  end
  if not stand or stopped or not active() then return end
  sequence+=1
  local number,character=sequence,deps.Character()
  local complete,skin=false,nil
  if not inFlight then
   inFlight=true
   deps.Spawn(function()
    local ok,name,confirmed=pcall(deps.Shiny)
    inFlight=false
    if not stopped and sequence==number and deps.Character()==character and standName()==stand then
     if ok and confirmed~=false and type(name)=="string" and name~="" and name~="nil" then skin=name end
     complete=true
    end
   end)
   local untilTime=deps.Clock()+1.5
   while not complete and not stopped and active() and deps.Character()==character and deps.Clock()<untilTime do deps.Wait(.05) end
  end
  if stopped or not active() or deps.Character()~=character or standName()~=stand then return end
  local title=(mode=="RibFarm" or mode=="RibShinyFarm") and "Rib Farm" or "Stand Farm"
  deps.Notify(title.." #"..tostring(number),stand.."\nSkin: "..(skin or "unavailable"),5)
 end,Cleanup=function()stopped=true end}
end)({Stand=deps.Stand,Shiny=deps.Shiny,
  Character=function()return deps.Player.Character end,Clock=deps.Clock,Wait=deps.Wait,Spawn=deps.Spawn,Notify=deps.Notify})
]===]},
{At=481527,Old=[===[]===],New=[===[   local hadStand=deps.Stand()~="None"
]===]},
{At=481933,Old=[===[]===],New=[===[   if ok and not hadStand and state.Mode and (name=="Arrow" or name=="Rib") then
    local consumed=deps.CountItem(name=="Arrow" and arrowName or "Rib Cage of The Saint's Corpse")<before
    if consumed or deps.Stand()~="None" then rollReporter.Report(state.Mode,function()return current(state)end) end
   end
]===]},
{At=498264,Old=[===[]===],New=[===[  rollReporter.Cleanup()
]===]},
{At=1011522,Old=[===[			local optimizer=_G.TheBestOptimization
			if optimizer and not optimizer.Take("Visuals",deltaTime) then return end
			if Lighting.ClockTime~=_G.Config.clocktime then Lighting.ClockTime = _G.Config.clocktime end
]===],New=[===[			local clock=tonumber(_G.Config.clocktime) or 12
			if clock~=clock or math.abs(clock)==math.huge then clock=12 end
			clock=_G.Config.xenonAlwaysNight and 0 or (_G.Config.xenonAlwaysDay and 12 or clock%24)
			if Lighting.ClockTime~=clock then Lighting.ClockTime=clock end
]===]},
{At=1012025,Old=[===[]===],New=[===[			local optimizer=_G.TheBestOptimization
			if optimizer and not optimizer.Take("Visuals",deltaTime) then return end
]===]},
{At=1022227,Old=[===[			local function buildEquipmentList(playerStats, equippedStatName, styleSlots)
				local equippedValue = getPlayerStatText(playerStats, equippedStatName)
				local equippedLabel = equippedValue .. " (equipped)"
				local list = { equippedLabel }
				local seen = { [string.lower(equippedValue)] = true }
				local slots = {}
				for _, item in ipairs(playerStats:GetChildren()) do
					local isStyleSlot = item.Name:match("StyleSlot") ~= nil
					if item.Name:match("Slot") and isStyleSlot == styleSlots then
						local succeeded, rawValue = pcall(function()
							return item.Value
						end)
						local value = succeeded and tostring(rawValue or "") or ""
						local normalized = string.lower(value)
						if value ~= "" and normalized ~= "none" and not seen[normalized] then
							seen[normalized] = true
							table.insert(slots, { Name = item.Name, Value = value })
						end
					end
				end
				table.sort(slots, function(left, right)
					return left.Name < right.Name
				end)
				for _, slot in ipairs(slots) do
					table.insert(list, slot.Value)
				end
				return list, equippedLabel
			end
]===],New=[===[			local buildEquipmentList=(function(deps)
 local function text(value)
  return type(value)=="string" and value:match("^%s*(.-)%s*$") or nil
 end
 local function key(value)
  return string.lower(text(value) or "")
 end
 local function stringChild(object,name)
  local child=object and object:FindFirstChild(name)
  return child and child:IsA("StringValue") and text(child.Value) or nil
 end
 local function skinMetadata(object)
  if not object then return nil,false end
  local skin,identity
  local conflict=false
  local function accept(value)
   value=text(value)
   if not value or value=="" then return end
   local normalized=key(value)
   if identity and identity~=normalized then conflict=true end
   skin,identity=value,normalized
  end
  -- Only explicit metadata on this exact slot/model identifies its skin.
  for _,name in ipairs({"StandSkin","Skin"}) do
   accept(stringChild(object,name))
   accept(object:GetAttribute(name))
  end
  return not conflict and skin or nil,conflict
 end
 local function equippedSkin(player,standStat,standName)
  local skin,conflict=skinMetadata(standStat)
  if skin or conflict or not player then return skin end
  local character=player.Character
  if not character and deps.Living then
   local living=deps.Living()
   character=living and living:FindFirstChild(player.Name)
  end
  local stand=character and character:FindFirstChild("StandMorph")
  if not stand or not stand:IsA("Model") or stand:GetAttribute("TheBestSkinCustom") then return nil end
  -- A stale rig during a stand switch must not label the newly equipped stand.
  if key(stringChild(stand,"Stand Name"))~=key(standName) then return nil end
  return skinMetadata(stand)
 end
 local function standLabel(stand,skin)
  if key(stand)=="none" or stand=="" then return stand end
  local suffix=skin and (key(skin)=="none" and "no skin" or skin) or "skin unavailable"
  return stand.." — "..suffix
 end
 return function(playerStats,equippedStatName,styleSlots,player)
  local stat=playerStats:FindFirstChild(equippedStatName)
  local equippedValue=deps.StatText(playerStats,equippedStatName)
  local equippedLabel=equippedValue
  if not styleSlots then equippedLabel=standLabel(equippedValue,equippedSkin(player,stat,equippedValue)) end
  equippedLabel=equippedLabel.." (equipped)"
  local list={equippedLabel}
  local seen={[string.lower(equippedValue)]=true}
  local slots={}
  for _,item in ipairs(playerStats:GetChildren()) do
   local isStyleSlot=item.Name:match("StyleSlot")~=nil
   if item.Name:match("Slot") and isStyleSlot==styleSlots then
    local succeeded,rawValue=pcall(function() return item.Value end)
    local value=succeeded and tostring(rawValue or "") or ""
    local normalized=string.lower(value)
    if value~="" and normalized~="none" and (not styleSlots or not seen[normalized]) then
     seen[normalized]=true
     local label=value
     if not styleSlots then
      label=standLabel(value,skinMetadata(item)).." ("..item.Name..")"
     end
     table.insert(slots,{Name=item.Name,Value=label})
    end
   end
  end
  table.sort(slots,function(left,right) return left.Name<right.Name end)
  for _,slot in ipairs(slots) do table.insert(list,slot.Value) end
  return list,equippedLabel
 end
end)({
 StatText=getPlayerStatText,
 Living=function() return workspace:FindFirstChild("Living") end,
})
]===]},
{At=1024299,Old=[===[							playerStandsList, equippedStandLabel = buildEquipmentList(playerStats, "Stand", false)
]===],New=[===[							playerStandsList, equippedStandLabel = buildEquipmentList(playerStats, "Stand", false, player)
]===]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest source patch: base mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyStandReportPatch(main)
local function applyEspKeybindPatch(source)
 local edits={{Old=[===[	OpenMenu = "Delete",]===],New=[===[	OpenMenu = "Delete",
	esp = "Unknown",]===]},
{Old=[===[		Library:CreateToggle(basicSettingsSection, "Enable ESP", _G.Config.mhud, function(v)
			_G.Config.mhud = v
			SaveConfig()
		end)]===],New=[===[		do
			local espToggleControl = Library:CreateToggle(basicSettingsSection, "Enable ESP", _G.Config.mhud, function(v)
				_G.Config.mhud = v
				SaveConfig()
			end)
			table.insert(Library.RuntimeConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or _G.TheBestBuildingUI or _G.TheBestCapturingKeybind
					or UserInputService:GetFocusedTextBox()
					or input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				local binding = getKey("esp")
				if binding == Enum.KeyCode.Unknown or input.KeyCode ~= binding then
					return
				end
				local enabled = not (_G.Config.mhud == true)
				espToggleControl.SetState(enabled, true)
				if Library.SbrEspToggle then
					Library.SbrEspToggle.SetState(enabled, false)
				end
			end))
		end]===]},
{Old=[===[				Library:CreateToggle(sbrSettingsSection, "Player ESP",]===],New=[===[				Library.SbrEspToggle = Library:CreateToggle(sbrSettingsSection, "Player ESP",]===]},
{Old=[===[					OpenMenu = "Open Menu Bind",]===],New=[===[					OpenMenu = "Open Menu Bind",
					esp = "ESP Bind",]===]},
{Old=[===[					"OpenMenu",]===],New=[===[					"OpenMenu",
					"esp",]===]},
{Old=[===[					["Enable ESP"] = ]===],New=[===[					["ESP Bind"] = "Клавиша ESP",
					["Enable ESP"] = ]===]}}
 for _,edit in ipairs(edits) do
  local start,finish=source:find(edit.Old,1,true)
  assert(start and not source:find(edit.Old,finish+1,true),"TheBest ESP keybind: source mismatch")
  source=source:sub(1,start-1)..edit.New..source:sub(finish+1)
 end
 return source
end
main=applyEspKeybindPatch(main)
local function applyMenuControlsPatch(source)
 assert(#source==3005291,"TheBest controls patch: unexpected source size")
 local edits={{At=42480,Old=[====[]====],New=[====[	aimbotDuration = 2,
]====]},
{At=45439,Old=[====[]====],New=[====[	autoParry = "Unknown",
]====]},
{At=47449,Old=[====[]====],New=[====[	if keyName == "Unknown" then return nil end
]====]},
{At=54433,Old=[====[local TheBestPendingEnabledRestore=loadJsonFile("thebest/restore-enabled-v016.json")
]====],New=[====[local TheBestPendingEnabledRestore
if not _G.TheBestProfileLoadInProgress then TheBestPendingEnabledRestore=loadJsonFile("thebest/restore-enabled-v016.json") end
]====]},
{At=55217,Old=[====[_G.Config.aimbotActivation = _G.Config.aimbotActivation == "Toggle" and "Toggle" or "Hold"
]====],New=[====[_G.Config.aimbotActivation = (_G.Config.aimbotActivation == "Toggle" or _G.Config.aimbotActivation == "Custom") and _G.Config.aimbotActivation or "Hold"
do
 local duration=tonumber(_G.Config.aimbotDuration)
 _G.Config.aimbotDuration=duration and duration==duration and duration>0 and duration<math.huge and duration or 2
end
]====]},
{At=110538,Old=[====[]====],New=[====[		local aimbotCustomSession = nil
]====]},
{At=124129,Old=[====[]====],New=[====[			aimbotCustomSession = nil
]====]},
{At=124327,Old=[====[]====],New=[====[			if aimbotCustomSession then
				local session = aimbotCustomSession
				local character = getTargetCharacter(getAimbotTarget())
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local ownCharacter = LocalPlayer.Character
				local ownHumanoid = ownCharacter and ownCharacter:FindFirstChildOfClass("Humanoid")
				if _G.Config.aimbotActivation ~= "Custom" or os.clock() >= session.ExpiresAt
					or getAimbotTarget() ~= session.Target or character ~= session.TargetCharacter
					or ownCharacter ~= session.Character or not humanoid or humanoid.Health <= 0
					or not ownHumanoid or ownHumanoid.Health <= 0 then
					resetAimbotInput()
					return
				end
			end
]====]},
{At=198007,Old=[====[]====],New=[====[					elseif _G.Config.aimbotActivation == "Custom" then
						local target = getAimbotTarget()
						local character = getTargetCharacter(target)
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						if not targetHead(target) or not humanoid or humanoid.Health <= 0 then
							resetAimbotInput()
							return
						end
						local duration = tonumber(_G.Config.aimbotDuration)
						if not duration or duration ~= duration or duration <= 0 or duration == math.huge then
							duration = 2
						end
						aimbotCustomSession = {
							ExpiresAt = os.clock() + duration,
							Target = target,
							TargetCharacter = character,
							Character = LocalPlayer.Character,
						}
						holdingAimbot = true
]====]},
{At=198984,Old=[====[				if _G.Config.aimbotActivation ~= "Toggle" then
]====],New=[====[				if _G.Config.aimbotActivation == "Hold" then
]====]},
{At=199214,Old=[====[]====],New=[====[			resetAimbotInput()
]====]},
{At=199494,Old=[====[				holdingAimbot = false
]====],New=[====[				resetAimbotInput()
]====]},
{At=225986,Old=[====[]====],New=[====[					["Config Profiles"] = "Профили настроек",
					["Saved Profiles"] = "Сохранённые профили",
					["Profile Name"] = "Название профиля",
					["Enter profile name"] = "Введи название",
					["Save Profile"] = "Сохранить профиль",
					["Load Profile"] = "Загрузить профиль",
					["Delete Profile"] = "Удалить профиль",
					["Auto Parry Bind"] = "Клавиша автопарирования",
					["Clear"] = "Сбросить",
]====]},
{At=240576,Old=[====[]====],New=[====[					["Custom"] = "По времени",
					["Custom Duration (Seconds)"] = "Время захвата (секунды)",
]====]},
{At=398008,Old=[====[			label.Size = UDim2.new(0.48, -4, 1, 0)
]====],New=[====[			label.Size = UDim2.new(0.4, -4, 1, 0)
]====]},
{At=398449,Old=[====[			input.Size = UDim2.new(0.31, -4, 0, 24)
			input.Position = UDim2.new(0.48, 0, 0.5, -12)
]====],New=[====[			input.Size = UDim2.new(0.29, -4, 0, 24)
			input.Position = UDim2.new(0.4, 0, 0.5, -12)
]====]},
{At=398645,Old=[====[			input.Text = tostring(_G.Keybinds and _G.Keybinds[action] or "")
]====],New=[====[			local function keyText()
				local key = _G.Keybinds and _G.Keybinds[action]
				return key == "Unknown" and "None" or tostring(key or "None")
			end
			input.Text = keyText()
]====]},
{At=399051,Old=[====[			setButton.Size = UDim2.new(0.21, -4, 0, 24)
			setButton.Position = UDim2.new(0.79, 0, 0.5, -12)
]====],New=[====[			setButton.Size = UDim2.new(0.14, -4, 0, 24)
			setButton.Position = UDim2.new(0.7, 0, 0.5, -12)
]====]},
{At=399543,Old=[====[]====],New=[====[			local clearButton = Instance.new("TextButton")
			clearButton.Size = UDim2.new(0.15, -4, 0, 24)
			clearButton.Position = UDim2.new(0.85, 0, 0.5, -12)
			clearButton.BackgroundColor3 = T.dropdownBg
			clearButton.BorderSizePixel = 0
			Library.Localization.SetText(clearButton, "Clear")
			clearButton.TextColor3 = T.text
			clearButton.TextSize = 12
			clearButton.Font = Enum.Font.SourceSansBold
			clearButton.Parent = frame
			local clearCorner = Instance.new("UICorner")
			clearCorner.CornerRadius = UDim.new(0, 4)
			clearCorner.Parent = clearButton
]====]},
{At=399570,Old=[====[]====],New=[====[			local function cancelCapture()
				if captureConn then captureConn:Disconnect(); captureConn = nil end
				if Library.CancelKeybindCapture == cancelCapture then
					Library.CancelKeybindCapture = nil
					_G.TheBestCapturingKeybind = nil
				end
				Library.Localization.SetText(setButton, "Set")
			end
]====]},
{At=399606,Old=[====[				if not keyName or keyName == "" or not Enum.KeyCode[keyName] then
					input.Text = tostring(_G.Keybinds and _G.Keybinds[action] or "")
]====],New=[====[				keyName = type(keyName) == "string" and keyName:match("^%s*(.-)%s*$") or ""
				if keyName == "" or keyName == "None" then keyName = "Unknown" end
				local valid, value = pcall(function() return Enum.KeyCode[keyName] end)
				if not valid or not value then
					input.Text = keyText()
]====]},
{At=399940,Old=[====[				input.Text = keyName
]====],New=[====[				input.Text = keyText()
]====]},
{At=400112,Old=[====[]====],New=[====[			clearButton.MouseButton1Click:Connect(function()
				cancelCapture()
				applyKey("Unknown")
			end)
]====]},
{At=400162,Old=[====[]====],New=[====[				if Library.CancelKeybindCapture then Library.CancelKeybindCapture() end
				Library.CancelKeybindCapture = cancelCapture
]====]},
{At=400200,Old=[====[					Library.Localization.SetText(setButton, "...")
				if captureConn then
					captureConn:Disconnect()
				end
]====],New=[====[				Library.Localization.SetText(setButton, "...")
]====]},
{At=400405,Old=[====[					if gameProcessed or inputObject.UserInputType ~= Enum.UserInputType.Keyboard then
						return
					end
]====],New=[====[					if gameProcessed or inputObject.UserInputType ~= Enum.UserInputType.Keyboard then return end
]====]},
{At=400554,Old=[====[					_G.TheBestCapturingKeybind = nil
						Library.Localization.SetText(setButton, "Set")
					captureConn:Disconnect()
					captureConn = nil
]====],New=[====[					cancelCapture()
]====]},
{At=400707,Old=[====[]====],New=[====[				table.insert(Library.RuntimeConnections, captureConn)
]====]},
{At=400715,Old=[====[]====],New=[====[			frame.Destroying:Connect(cancelCapture)
]====]},
{At=401042,Old=[====[]====],New=[====[				clearButton.BackgroundColor3 = theme.dropdownBg
				clearButton.TextColor3 = theme.text
]====]},
{At=413303,Old=[====[			local openMenuKey = getKey and getKey("OpenMenu") or Enum.KeyCode.Delete
]====],New=[====[			local openMenuKey = getKey("OpenMenu")
]====]},
{At=606233,Old=[====[	local runtime = { Players = {}, Connections = {}, Enabled = false, Stopped = false, Phase = "waiting" }
]====],New=[====[	local runtime = { Players = {}, Connections = {}, Enabled = false, Stopped = false, Phase = "waiting",
		MatchSize = options.PlaceId == 5818061503 and 2 or 1 }
	local function isOpponent(player)
		if player == players.LocalPlayer then return false end
		if runtime.MatchSize ~= 2 then return true end
		local localPlayer = players.LocalPlayer
		local localTeam, remoteTeam = localPlayer and localPlayer.Team, player.Team
		if not localTeam or not remoteTeam or localPlayer.Neutral == true or player.Neutral == true then return true, true end
		return localTeam ~= remoteTeam
	end
]====]},
{At=608405,Old=[====[		return tonumber(text:match("the 1v1 is beginning in%s+(%d+)"))
]====],New=[====[		local first, second, count = text:match("the ([12])%s*v%s*([12]) is beginning in%s+(%d+)")
		if first ~= second then return nil end
		return tonumber(count), tonumber(first)
]====]},
{At=609394,Old=[====[			local result
]====],New=[====[			local result, matchSize
]====]},
{At=609502,Old=[====[					local count = parseCountdown(object.Text)
]====],New=[====[					local count, size = parseCountdown(object.Text)
]====]},
{At=609863,Old=[====[						if shown then result = result and math.min(result, count) or count end
]====],New=[====[						if shown and (not result or count < result) then result, matchSize = count, size end
]====]},
{At=609964,Old=[====[			return result
]====],New=[====[			return result, matchSize
]====]},
{At=611888,Old=[====[		local known, pending = 0, 0
]====],New=[====[		local known, pending, unresolved = 0, 0, 0
]====]},
{At=611960,Old=[====[			if record.SpawnCFrame then known += 1 else pending += 1 end
			if self.Enabled and record.SpawnCFrame then
]====],New=[====[			local opponent, unknownTeam = isOpponent(record.Player)
			if unknownTeam then unresolved += 1 end
			if opponent then
				if record.SpawnCFrame then known += 1 else pending += 1 end
			end
			if self.Enabled and opponent and record.SpawnCFrame then
]====]},
{At=612632,Old=[====[]====],New=[====[			elseif self.MatchSize == 2 and unresolved > 0 then text = "2v2 teams unavailable; named markers include other participants."
]====]},
{At=612964,Old=[====[		local countdown = readCountdown()
]====],New=[====[		local countdown, matchSize = readCountdown()
]====]},
{At=613027,Old=[====[]====],New=[====[			self.MatchSize = matchSize or self.MatchSize
]====]},
{At=615885,Old=[====[	local initial = readCountdown()
	if initial ~= nil then runtime.Phase, runtime.Countdown = "prefight", initial end
]====],New=[====[	local initial, matchSize = readCountdown()
	if initial ~= nil then runtime.Phase, runtime.Countdown = "prefight", initial; runtime.MatchSize = matchSize or runtime.MatchSize end
]====]},
{At=616725,Old=[====[]====],New=[====[					PlaceId = game.PlaceId,
]====]},
{At=638529,Old=[====[		Library:CreateToggle(autoParrySection, "Enable Auto Parry", _G.Config.autoParryEnabled, function(state)
]====],New=[====[		do
		local parryToggleControl = Library:CreateToggle(autoParrySection, "Enable Auto Parry", _G.Config.autoParryEnabled, function(state)
]====]},
{At=638777,Old=[====[]====],New=[====[			table.insert(Library.RuntimeConnections, UserInputService.InputBegan:Connect(function(input, processed)
				if processed or _G.TheBestBuildingUI or _G.TheBestCapturingKeybind
					or UserInputService:GetFocusedTextBox()
					or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				local binding = getKey("autoParry")
				if binding == Enum.KeyCode.Unknown or input.KeyCode ~= binding then return end
				parryToggleControl.SetState(not (_G.Config.autoParryEnabled == true), true)
			end))
		end
]====]},
{At=645038,Old=[====[			firesignal(Event2.OnClientEvent, "AddCD", { Name = "ULTIMATE ABILITY COOLDOWN", Cooldown = 3 })
]====],New=[====[]====]},
{At=645659,Old=[====[			if gp then
]====],New=[====[			if gp or _G.TheBestCapturingKeybind or UserInputService:GetFocusedTextBox()
				or inp.UserInputType ~= Enum.UserInputType.Keyboard then
]====]},
{At=645897,Old=[====[				events()
]====],New=[====[				local succeeded, shuffleError = pcall(events)
				if not succeeded then
					_G.crackeSandwichCD = true
					warn("[THEBEST] Boxing Shuffle: " .. tostring(shuffleError))
					return
				end
]====]},
{At=656454,Old=[====[		Library:CreateDropdown(
			miscSection,
			"Aimbot Activation",
			{ "Hold", "Toggle" },
			_G.Config.aimbotActivation,
			false,
			function(v)
]====],New=[====[		do
			local customDurationInput
			Library:CreateDropdown(
				miscSection,
				"Aimbot Activation",
				{ "Hold", "Toggle", "Custom" },
				_G.Config.aimbotActivation,
				false,
				function(v)
					resetAimbotInput()
					_G.Config.aimbotActivation = (v == "Toggle" or v == "Custom") and v or "Hold"
					if customDurationInput then customDurationInput.SetVisible(_G.Config.aimbotActivation == "Custom") end
					SaveConfig()
				end,
				true
			)
			customDurationInput = Library:CreateTextInput(miscSection, "Custom Duration (Seconds)", _G.Config.aimbotDuration, "2.5", function(value)
				local duration = tonumber((tostring(value):gsub(",", ".")))
				if not duration or duration ~= duration or duration <= 0 or duration == math.huge then
					if customDurationInput then customDurationInput.SetValue(tostring(_G.Config.aimbotDuration), false) end
					return
				end
]====]},
{At=656624,Old=[====[				_G.Config.aimbotActivation = v == "Toggle" and "Toggle" or "Hold"
]====],New=[====[				_G.Config.aimbotDuration = duration
]====]},
{At=656711,Old=[====[			end,
			true
		)
]====],New=[====[			end)
			if customDurationInput then customDurationInput.SetVisible(_G.Config.aimbotActivation == "Custom") end
		end
]====]},
{At=1032261,Old=[====[]====],New=[====[					autoParry = "Auto Parry Bind",
]====]},
{At=1032673,Old=[====[]====],New=[====[					"autoParry",
]====]},
{At=1033619,Old=[====[]====],New=[====[do
	local profileSection = Library:CreateFunctionTab(tabKeybinds, "Config Profiles")
	local function validJson(value, depth)
		if depth > 16 then return false end
		local kind = type(value)
		if kind == "boolean" or kind == "string" then return true end
		if kind == "number" then return value == value and math.abs(value) < math.huge end
		if kind ~= "table" then return false end
		for key, entry in pairs(value) do
			if type(key) ~= "string" and type(key) ~= "number" then return false end
			if not validJson(entry, depth + 1) then return false end
		end
		return true
	end
	local function validate(snapshot)
		if type(snapshot) ~= "table" or snapshot.schema ~= 1
			or type(snapshot.config) ~= "table" or type(snapshot.keybinds) ~= "table"
			or not validJson(snapshot, 0) then return false end
		for key, value in pairs(snapshot.config) do
			local default = DEFAULT_CONFIG[key]
			if default ~= nil and type(value) ~= type(default) then return false end
		end
		for action, name in pairs(snapshot.keybinds) do
			if type(action) ~= "string" or type(name) ~= "string" then return false end
			local ok, key = pcall(function() return Enum.KeyCode[name] end)
			if not ok or not key then return false end
		end
		return true
	end
	local function read(path)
		if type(readfile) ~= "function" or (type(isfile) == "function" and not isfile(path)) then return nil end
		return readfile(path)
	end
	local function restart(snapshot)
		assert(not _G.TheBestProfileLoadInProgress, "Профиль уже загружается.")
		local bootSource = assert(read("thebest/runtime-v016/boot.lua"), "Не найден boot.lua.")
		local boot, compileError = loadstring(bootSource, "@TheBestProfileLoader")
		assert(boot, compileError)
		local configRaw, keybindsRaw = HttpService:JSONEncode(snapshot.config), HttpService:JSONEncode(snapshot.keybinds)
		local previousConfig, previousKeybinds = read(CONFIG_FILE), read(KEYBINDS_FILE)
		_G.TheBestProfileLoadInProgress = true
		local ok, errorMessage = pcall(function()
			local shutdown = _G.TheBestEmergencyShutdown
			assert(type(shutdown) == "function" and shutdown(), "Не удалось остановить текущее меню.")
			writefile(CONFIG_FILE, configRaw)
			writefile(KEYBINDS_FILE, keybindsRaw)
			assert(read(CONFIG_FILE) == configRaw and read(KEYBINDS_FILE) == keybindsRaw, "Не удалось записать настройки.")
			boot()
			local diagnostics = _G.TheBestDiagnostics
			assert(not diagnostics or diagnostics.Status == "startup finished", "Ошибка загрузки профиля. См. журнал v016.")
		end)
		if not ok then
			local shutdown = _G.TheBestEmergencyShutdown
			if type(shutdown) == "function" then pcall(shutdown) end
			if previousConfig and previousKeybinds then
				pcall(writefile, CONFIG_FILE, previousConfig)
				pcall(writefile, KEYBINDS_FILE, previousKeybinds)
				pcall(boot)
			end
			_G.TheBestProfileLoadInProgress = nil
			error(errorMessage)
		end
		_G.TheBestProfileLoadInProgress = nil
	end
	local createProfiles = (function(deps)
	local profileFile = "thebest/profiles.json"
	local backupFile = profileFile .. ".backup"
	local profiles = {}
	local loadError
	local function validName(value)
		return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
	end
	local function copy(value)
		return deps.Decode(deps.Encode(value))
	end
	local function decodeStore(raw)
		if not raw then return nil end
		local ok, value = pcall(deps.Decode, raw)
		if ok and type(value) == "table" and value.schema == 1 and type(value.profiles) == "table" then
			return value.profiles
		end
		return nil
	end
	local function read(path)
		local ok, raw = pcall(deps.Read, path)
		return ok and type(raw) == "string" and raw or nil
	end
	local function write(path, raw)
		local ok = pcall(deps.Write, path, raw)
		return ok and read(path) == raw
	end
	local function persist(nextProfiles)
		local raw = deps.Encode({ schema = 1, profiles = nextProfiles })
		local previous = read(profileFile)
		if previous and decodeStore(previous) and not write(backupFile, previous) then
			return false, "Не удалось сохранить резервную копию профилей."
		end
		if not write(profileFile, raw) then
			if previous then write(profileFile, previous) end
			return false, "Не удалось записать профили."
		end
		profiles = nextProfiles
		return true
	end
	local current = read(profileFile)
	local backup = read(backupFile)
	if current or backup then
		profiles = decodeStore(current) or decodeStore(backup)
		if not profiles then
			profiles = {}
			loadError = "Файл профилей повреждён."
		end
	end
	local api = {}
	function api.List()
		local names = {}
		for name in pairs(profiles) do
			if type(name) == "string" then table.insert(names, name) end
		end
		table.sort(names)
		return names
	end
	function api.Save(name)
		if loadError then return false, loadError end
		name = validName(name)
		if name == "" then return false, "Введи название профиля." end
		local ok, snapshot = pcall(function()
			local value = deps.Snapshot()
			assert(deps.Validate(value), "Invalid settings")
			return copy(value)
		end)
		if not ok then return false, "Не удалось сохранить текущие настройки." end
		local nextProfiles = table.clone(profiles)
		nextProfiles[name] = snapshot
		return persist(nextProfiles)
	end
	function api.Delete(name)
		if loadError then return false, loadError end
		if not profiles[name] then return false, "Выбери профиль." end
		local nextProfiles = table.clone(profiles)
		nextProfiles[name] = nil
		return persist(nextProfiles)
	end
	function api.Load(name)
		local snapshot = profiles[name]
		if not snapshot then return false, "Выбери профиль." end
		local ok, accepted = pcall(deps.Validate, snapshot)
		if not ok or not accepted then return false, "Профиль содержит некорректные настройки." end
		local loaded, reason = pcall(deps.Restart, copy(snapshot))
		if not loaded then return false, tostring(reason) end
		return true
	end
	function api.Status()
		return loadError
	end
	if not current and not backup then
		local ok, reason = api.Save("Исходные настройки")
		if not ok then loadError = reason end
	end
	return api
end
)
	local profiles = createProfiles({
		Read = read, Write = function(path, value)
			assert(type(writefile) == "function", "Файлы недоступны.")
			ensureConfigFolder()
			writefile(path, value)
		end,
		Encode = function(value) return HttpService:JSONEncode(value) end,
		Decode = function(value) return HttpService:JSONDecode(value) end,
		Snapshot = function() return { schema = 1, config = _G.Config, keybinds = _G.Keybinds } end,
		Validate = validate, Restart = restart,
	})
	local selectedName
	local names = profiles.List()
	selectedName = names[1]
	local dropdown = Library:CreateDropdown(profileSection, "Saved Profiles", names, selectedName, false, function(value)
		selectedName = value
	end)
	local input = Library:CreateTextInput(profileSection, "Profile Name", "", "Enter profile name")
	local status = Library:CreateStatusLabel(profileSection, profiles.Status() or "")
	local function refresh()
		local updated = profiles.List()
		dropdown.Update(updated)
		if selectedName and table.find(updated, selectedName) then
			dropdown.SetValue(selectedName)
		else
			selectedName = updated[1]
			if selectedName then dropdown.SetValue(selectedName) end
		end
	end
	Library:CreateButton(profileSection, "Save Profile", function()
		local name = input.GetValue():match("^%s*(.-)%s*$")
		local ok, reason = profiles.Save(name)
		if ok then selectedName = name; refresh() end
		status.SetText(ok and "Профиль сохранён." or reason)
	end)
	Library:CreateButton(profileSection, "Load Profile", function()
		status.SetText("Применяю профиль…")
		task.defer(function()
			local ok, reason = profiles.Load(selectedName)
			if not ok then warn("[THEBEST] " .. tostring(reason)); pcall(status.SetText, tostring(reason)) end
		end)
	end)
	Library:CreateButton(profileSection, "Delete Profile", function()
		local ok, reason = profiles.Delete(selectedName)
		if ok then selectedName = nil; refresh() end
		status.SetText(ok and "Профиль удалён." or reason)
	end)
end

]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest controls patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyMenuControlsPatch(main)
local function applyShuffleForwardingPatch(source)
 assert(#source==3020276,"TheBest shuffle patch: unexpected source size")
 local edits={{At=62890,Old=[====[		for _, object in ipairs(character:GetChildren()) do
]====],New=[====[		for _, object in ipairs(character.GetChildren(character)) do
]====]},
{At=63229,Old=[====[			and deps.Typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction"))
]====],New=[====[			and deps.Typeof(self) == "Instance" and (self.ClassName == "RemoteEvent" or self.ClassName == "RemoteFunction")
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest shuffle patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyShuffleForwardingPatch(main)
local function applyToolsHealthPatch(source)
 assert(#source==3020301,"TheBest shuffle patch: unexpected source size")
 local edits={{At=60913,Old=[====[  if observer and (not observerVisible or observerVisible()) then
]====],New=[====[  local shown=observer and (not observerVisible or observerVisible())
  if _G.TheBestTools then _G.TheBestTools.SetMeasuring(shown==true) end
  if shown then
]====]},
{At=62364,Old=[====[]====],New=[====[do
 if type(_G.TheBestToolsCleanup)=="function" then pcall(_G.TheBestToolsCleanup) end
 _G.TheBestSessionEntries=_G.TheBestSessionEntries or {}
 local tools=(function(deps)
 local runtime={Build="v016.30 · 24.11.2026",Measuring=false,Stopped=false,JournalVersion=0}
 local entries=deps.Entries or {}
 local profiles,started={},deps.Clock()
 local sequence=0
 for _,entry in ipairs(entries) do sequence=math.max(sequence,entry.id or 0) end
 function runtime.Log(kind,text)
  if runtime.Stopped then return end
  text=tostring(text or ""):gsub("\r","")
  if #text>400 then local ok,index=pcall(utf8.offset,text,0,401);text=text:sub(1,(ok and index or 401)-1) end
  local previous=entries[#entries]
  if previous and previous.kind==kind and previous.text==text and deps.Clock()-(previous.clock or 0)<2 then
   previous.count=(previous.count or 1)+1;previous.clock=deps.Clock()
  else
   sequence+=1
   table.insert(entries,{id=sequence,kind=kind,text=text,time=deps.Timestamp(),clock=deps.Clock(),count=1})
   if #entries>300 then table.remove(entries,1) end
  end
  runtime.JournalVersion+=1
  if runtime.OnJournal then runtime.OnJournal() end
 end
 function runtime.Journal(kind)
  local lines={}
  for i=#entries,1,-1 do
   local e=entries[i]
   if not kind or kind=="all" or e.kind==kind then
    table.insert(lines,string.format("%s [%s] %s%s",e.time,e.kind,e.text,e.count>1 and " ×"..e.count or ""))
   end
  end
  return table.concat(lines,"\n\n"),#lines
 end
 function runtime.ClearJournal() table.clear(entries);runtime.JournalVersion+=1;if runtime.OnJournal then runtime.OnJournal() end end
 function runtime.FormatHealth(health,maximum)
  if health==nil then return "— HP" end
  local function text(value)return string.format("%.1f",value):gsub("%.0$","")end
  return text(health)..(maximum and " / "..text(maximum) or "").." HP"
 end
 function runtime.SetMeasuring(value)
  value=value==true and not runtime.Stopped
  if value~=runtime.Measuring then table.clear(profiles);started=deps.Clock() end
  runtime.Measuring=value
 end
 function runtime.Run(name,callback,...)
  if not runtime.Measuring or runtime.Stopped then return callback(...) end
  local before=deps.Clock()
  local result=table.pack(callback(...))
  local elapsed=math.max(0,deps.Clock()-before)*1000
  local p=profiles[name] or {Total=0,Count=0,Peak=0}
  p.Total+=elapsed;p.Count+=1;p.Peak=math.max(p.Peak,elapsed);profiles[name]=p
  return table.unpack(result,1,result.n)
 end
 function runtime.Wrap(name,callback) return function(...) return runtime.Run(name,callback,...) end end
 function runtime.ProfileText()
  local elapsed=math.max(deps.Clock()-started,.001)
  local rows={}
  for name,p in pairs(profiles) do table.insert(rows,{Name=name,Time=p.Total/elapsed,Count=p.Count/elapsed,Peak=p.Peak}) end
  table.sort(rows,function(a,b)return a.Time>b.Time end)
  local text={"Обработчики: мс/с · вызовов/с · пик, мс"}
  for _,row in ipairs(rows) do table.insert(text,string.format("%s: %.2f · %.0f · %.2f",row.Name,row.Time,row.Count,row.Peak)) end
  if #rows==0 then table.insert(text,"Ожидание измерений активных функций…") end
  table.clear(profiles);started=deps.Clock()
  return table.concat(text,"\n")
 end
 function runtime.Conflicts(bindings,labels)
  local keys,lines={},{}
  for action,key in pairs(bindings or {}) do
   if type(key)=="string" and key~="" and key~="Unknown" and key~="None" then
    keys[key]=keys[key] or {};table.insert(keys[key],labels and labels[action] or action)
   end
  end
  for key,actions in pairs(keys) do
   if #actions>1 then table.sort(actions);table.insert(lines,key..": "..table.concat(actions,", ")) end
  end
  table.sort(lines)
  return #lines==0 and "Совпадений клавиш нет." or "Совпадают бинды:\n"..table.concat(lines,"\n"),#lines
 end
 function runtime.Visible(object)
  if not object or not object.Parent then return false end
  while object do
   if object:IsA("GuiObject") and not object.Visible then return false end
   if object:IsA("LayerCollector") and not object.Enabled then return false end
   object=object.Parent
  end
  return true
 end
 function runtime.Cleanup()
  runtime.Stopped=true;runtime.Measuring=false;runtime.OnJournal=nil;table.clear(profiles)
 end
 return runtime
end
)({Clock=os.clock,Timestamp=function()return os.date("%H:%M:%S")end,Entries=_G.TheBestSessionEntries})
 tools.Health=(function(deps)
 local cache=setmetatable({},{__mode="k"})
 local currentNames={"CurrentHealth","Health","CurrentHP","HP"}
 local maximumNames={"MaxHealth","MaximumHealth","MaxHP"}
 local function number(value)
  return type(value)=="number" and value==value and value>=0 and value<math.huge and value or nil
 end
 local function named(object,names)
  if not object then return nil end
  for _,name in ipairs(names) do
   local attribute=number(object:GetAttribute(name))
   if attribute~=nil then return attribute end
   local child=object:FindFirstChild(name)
   if child then
    if child:IsA("NumberValue") or child:IsA("IntValue") then
     local value=number(child.Value);if value~=nil then return value end
    elseif child:IsA("Folder") or child:IsA("Configuration") then
     local value=child:FindFirstChild("Current") or child:FindFirstChild("Value")
     if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
      local result=number(value.Value);if result~=nil then return result end
     end
    end
   end
  end
  return nil
 end
 return function(player,fallbackCharacter,fallbackHumanoid)
  local living=deps.Living()
  local character=(living and player and living:FindFirstChild(player.Name)) or (player and player.Character) or fallbackCharacter
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  if not humanoid and fallbackHumanoid and fallbackHumanoid.Parent==character then humanoid=fallbackHumanoid end
  local now=deps.Clock()
  local previous=player and cache[player]
  if previous and previous.Character==character and previous.Humanoid==humanoid and now-previous.Time<.1 then
   return previous.Health,previous.Maximum
  end
  local health,maximum
  local stats=player and player:FindFirstChild("PlayerStats")
  local sources={character,stats,player,humanoid}
  for i=1,4 do
   local source=sources[i]
   if health==nil then health=named(source,currentNames) end
   if maximum==nil then maximum=named(source,maximumNames) end
  end
  if health==nil and humanoid then health=number(humanoid.Health) end
  if maximum==nil and humanoid then maximum=number(humanoid.MaxHealth) end
  if maximum and (maximum<=0 or (health and maximum<health)) then maximum=nil end
  if player then cache[player]={Character=character,Humanoid=humanoid,Health=health,Maximum=maximum,Time=now} end
  return health,maximum
 end
end
)({Clock=os.clock,Living=function()return workspace:FindFirstChild("Living")end})
 _G.TheBestTools=tools
 local errorConnection
 pcall(function()
  errorConnection=game:GetService("ScriptContext").Error:Connect(function(message,stack)
   if tostring(message):find("TheBest",1,true) or tostring(stack):find("TheBest",1,true) then tools.Log("error",message) end
  end)
 end)
 _G.TheBestToolsCleanup=function()
  tools.Cleanup();if errorConnection then errorConnection:Disconnect() end
  if _G.TheBestTools==tools then _G.TheBestTools=nil;_G.TheBestToolsCleanup=nil end
 end
 tools.Log("system","Запущена сборка "..tools.Build)
 print("[TheBest] "..tools.Build)
end
]====]},
{At=94999,Old=[====[			if _G.Config.showHealthBar then
				local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
]====],New=[====[			local actualHealth,actualMaximum=_G.TheBestTools.Health(player,player.Character,humanoid)
			if (_G.Config.showHealthBar or _G.Config.showHealthText) and actualHealth~=nil then
				local ratio = actualMaximum and math.clamp(actualHealth / actualMaximum, 0, 1) or 1
]====]},
{At=95381,Old=[====[				v.healthBack.Visible = true
]====],New=[====[				v.healthBack.Visible = _G.Config.showHealthBar and actualMaximum~=nil
]====]},
{At=95802,Old=[====[				v.healthFill.Visible = true
]====],New=[====[				v.healthFill.Visible = _G.Config.showHealthBar and actualMaximum~=nil
]====]},
{At=95871,Old=[====[					v.healthText.Text = string.format("%d HP", math.floor(humanoid.Health + 0.5))
					v.healthText.Position = Vector2.new(minX - 22, maxY - fillHeight - 6)
]====],New=[====[					v.healthText.Text = _G.TheBestTools.FormatHealth(actualHealth,actualMaximum)
					v.healthText.Position = Vector2.new(minX - 10 - #v.healthText.Text*3, maxY - fillHeight - 6)
]====]},
{At=98432,Old=[====[				or cfg.showName or cfg.showDistance or cfg.showSkeleton or cfg.showHealthBar or cfg.showTracers
]====],New=[====[				or cfg.showName or cfg.showDistance or cfg.showSkeleton or cfg.showHealthBar or cfg.showHealthText or cfg.showTracers
]====]},
{At=108532,Old=[====[		RunService:BindToRenderStep("DrawingESP_Update", Enum.RenderPriority.Camera.Value + 1, updateEsp)
]====],New=[====[		RunService:BindToRenderStep("DrawingESP_Update", Enum.RenderPriority.Camera.Value + 1, _G.TheBestTools.Wrap("ESP игроков",updateEsp))
]====]},
{At=323816,Old=[====[			local backgroundAnimationConnection = RunService.RenderStepped:Connect(function(deltaTime)
]====],New=[====[			local backgroundAnimationConnection = RunService.RenderStepped:Connect(_G.TheBestTools.Wrap("Фон меню",function(deltaTime)
]====]},
{At=324699,Old=[====[			end)
]====],New=[====[			end))
]====]},
{At=400111,Old=[====[]====],New=[====[					Frame = frame, Label = label,
]====]},
{At=403674,Old=[====[]====],New=[====[					if Library.RefreshKeybindWarnings then Library.RefreshKeybindWarnings() end
]====]},
{At=424631,Old=[====[]====],New=[====[				local kind=(tostring(title):find("Stand Farm",1,true) or tostring(title):find("Rib Farm",1,true)) and "roll" or "notice"
				_G.TheBestTools.Log(kind,tostring(title)..": "..tostring(message))
]====]},
{At=509716,Old=[====[]====],New=[====[                if state=="confirmed" or state=="unconfirmed" or state=="error" then _G.TheBestTools.Log(state=="error" and "error" or "sale",tostring(state)..": "..tostring(detail)) end
]====]},
{At=569282,Old=[====[				updateItemEspDistances()
]====],New=[====[				_G.TheBestTools.Run("ESP предметов",updateItemEspDistances)
]====]},
{At=740656,Old=[====[]====],New=[====[		 status.Frame.Size=UDim2.new(1,0,0,100)
		 local profileStatus=Library:CreateStatusLabel(section,"Измерение активных обработчиков…")
		 profileStatus.Frame.Size=UDim2.new(1,0,0,140)
		 Library:CreateStatusLabel(section,"Измеряются локальные обработчики, пока открыт этот раздел.")
]====]},
{At=740756,Old=[====[]====],New=[====[		   profileStatus.SetText(_G.TheBestTools.ProfileText())
]====]},
{At=741629,Old=[====[]====],New=[====[do
 local tools=_G.TheBestTools
 local section=Library:CreateFunctionTab(tab_misc,"Журнал сессии")
 local kinds={all="Все",roll="Стенды и скины",sale="Продажи",error="Ошибки",skin="Библиотека скинов",notice="Уведомления",system="Система"}
 local kind="all"
 local pane=Instance.new("ScrollingFrame")
 pane.Name="SessionJournal";pane.Size=UDim2.new(1,0,0,240)
 pane.BackgroundColor3=T.dropdownBg;pane.BorderSizePixel=0;pane.ScrollBarThickness=4
 pane.AutomaticCanvasSize=Enum.AutomaticSize.Y;pane.CanvasSize=UDim2.new()
 local text=Instance.new("TextLabel")
 text.Position=UDim2.fromOffset(6,6);text.Size=UDim2.new(1,-18,0,0);text.AutomaticSize=Enum.AutomaticSize.Y
 text.BackgroundTransparency=1;text.TextColor3=T.text;text.TextSize=12;text.Font=Enum.Font.SourceSans
 text.TextWrapped=true;text.TextXAlignment=Enum.TextXAlignment.Left;text.TextYAlignment=Enum.TextYAlignment.Top
 text.Parent=pane
 local status=Library:CreateStatusLabel(section,"")
 local lastVersion,lastKind
 local function refresh()
  if not tools.Visible(section.frame) then return end
  if lastVersion==tools.JournalVersion and lastKind==kind then return end
  lastVersion,lastKind=tools.JournalVersion,kind
  local value,count=tools.Journal(kind)
  text.Text=count>0 and value or "Событий пока нет."
  status.SetText("Событий: "..count.." · последние сверху")
 end
 Library:CreateDropdown(section,"Показывать",{"Все","Стенды и скины","Продажи","Ошибки","Библиотека скинов","Уведомления","Система"},"Все",false,function(value)
  for key,label in pairs(kinds) do if label==value then kind=key;break end end
  refresh()
 end)
 Library:CreateButton(section,"Обновить журнал",refresh)
 Library:CreateButton(section,"Очистить журнал",function() tools.ClearJournal();refresh() end)
 pane.Parent=section.elementContainer;table.insert(section.elements,pane)
 tools.OnJournal=refresh
 local elapsed=0
 table.insert(Library.RuntimeConnections,game:GetService("RunService").Heartbeat:Connect(function(delta)
  elapsed+=delta;if elapsed<1 then return end;elapsed=0
  if tools.Visible(section.frame) then refresh() end
 end))
 registerThemeListener(function(theme) pane.BackgroundColor3=theme.dropdownBg;text.TextColor3=theme.text;pane.ScrollBarImageColor3=theme.accent end)
end

]====]},
{At=1020834,Old=[====[		_G.miscVisualConn = RunService.RenderStepped:Connect(function(deltaTime)
]====],New=[====[		_G.miscVisualConn = RunService.RenderStepped:Connect(_G.TheBestTools.Wrap("Освещение и эффекты",function(deltaTime)
]====]},
{At=1021611,Old=[====[		end)
]====],New=[====[		end))
]====]},
{At=1031598,Old=[====[]====],New=[====[		infoSection.HealthStatus=Library:CreateStatusLabel(infoSection,"— HP")
]====]},
{At=1036412,Old=[====[]====],New=[====[					local health,maximum=_G.TheBestTools.Health(plr)
					infoSection.HealthStatus.SetText(_G.TheBestTools.FormatHealth(health,maximum))
]====]},
{At=1039815,Old=[====[]====],New=[====[                local conflictStatus=Library:CreateStatusLabel(keybindSection,"")
                Library.RefreshKeybindWarnings=function()
                 local text,count=_G.TheBestTools.Conflicts(_G.Keybinds,keybindLabels)
                 conflictStatus.SetText(text);conflictStatus.Frame.Size=UDim2.new(1,0,0,24+count*36)
                 Library:LayoutFunctionTabs(tabKeybinds)
                end
                Library.RefreshKeybindWarnings()
]====]},
{At=2279569,Old=[====[		local auraConnection=game:GetService("RunService").Heartbeat:Connect(updateSkinAura)
]====],New=[====[		local auraConnection=game:GetService("RunService").Heartbeat:Connect(_G.TheBestTools.Wrap("Ауры скинов",updateSkinAura))
]====]},
{At=2848066,Old=[====[		createStandTab(tab_stands, "Stand Skins", standSkinEntries, function(stand, skin)
]====],New=[====[		do
		local standCards=createStandTab(tab_stands, "Stand Skins", standSkinEntries, function(stand, skin)
]====]},
{At=2849630,Old=[====[]====],New=[====[do
 local tools=_G.TheBestTools
 local section=Library:CreateFunctionTab(tab_misc,"Локальные скины")
 local rows,selected,previewFile,previewBusy={},nil,nil,false
 local generation=0
 local store,dropdown,nameInput,standDropdown
 local status=Library:CreateStatusLabel(section,"Выбери сохранённый скин. Предпросмотр не меняет персонажа.")
 status.Frame.Size=UDim2.new(1,0,0,40)
 local preview=Instance.new("ViewportFrame")
 preview.Name="CapturedSkinPreview";preview.Size=UDim2.new(1,0,0,220)
 preview.BackgroundColor3=T.dropdownBg;preview.BorderSizePixel=0
 preview.Ambient=Color3.fromRGB(195,195,210);preview.LightColor=Color3.fromRGB(255,244,225)
 local world=Instance.new("WorldModel");world.Parent=preview
 local camera=Instance.new("Camera");camera.FieldOfView=32;camera.Parent=preview;preview.CurrentCamera=camera
 local function clearPreview()
  generation+=1;previewFile=nil;world:ClearAllChildren()
 end
 local function rebuild(index)
  local entries,groups={},{}
  local info=_G.TheBestCapturedSkinInfo
  for file in pairs(info) do if store.File({file=file}) then info[file]=nil end end
  for _,entry in ipairs(_G.TheBestStandCatalogEntries or {}) do
   local copy={Name=entry.Name,Skins={}}
   for _,skin in ipairs(entry.Skins or {}) do
    local file=type(skin)=="table" and skin.Value or skin
    if not store.File({file=file}) then table.insert(copy.Skins,skin) end
   end
   groups[entry.Name]=copy;table.insert(entries,copy)
  end
  local count=0
  for _,record in ipairs(index.entries) do
   local file=store.File(record)
   if file and type(record.name)=="string" and type(record.stand)=="string" and _G.TheBestCatalogIsAvailableFile(file) then
    local group=groups[record.stand]
    if not group then group={Name=record.stand,Skins={"None"}};groups[record.stand]=group;table.insert(entries,group) end
    table.insert(group.Skins,{Name=record.name.." [Local]",Value=file})
    info[file]={file=file,name=record.name,stand=record.stand};count+=1
   end
  end
  _G.TheBestStandCatalogEntries=entries;_G.TheBestCapturedSkinCount=count
  local visible={}
  for _,entry in ipairs(entries) do if #entry.Skins>1 then table.insert(visible,entry) end end
  if standCards then standCards.SetItems(visible) end
 end
 store=(function(deps)
 local function fileOf(record)
  local file=type(record)=="table" and type(record.file)=="string" and record.file:gsub("\\","/"):gsub("^ssoc_skins/","")
  return file and file:match("^captured%-[%w%-]+%.ssoc$") and file or nil
 end
 local function read()
  local raw=deps.Read()
  if not raw then return {schema=1,entries={}},nil end
  local index=deps.Decode(raw)
  assert(type(index)=="table" and index.schema==1 and type(index.entries)=="table","Каталог скинов повреждён.")
  return index,raw
 end
 local function key(text) return tostring(text or ""):lower():gsub("%s+","") end
 local api={File=fileOf}
 function api.List()
  local ok,index=pcall(read)
  if not ok then return {},tostring(index) end
  local rows={}
  for n,record in ipairs(index.entries) do
   if fileOf(record) and type(record.name)=="string" and type(record.stand)=="string" then
    table.insert(rows,{Index=n,File=fileOf(record),Name=record.name,Stand=record.stand,
     Label=tostring(n)..". "..record.name.." — "..record.stand})
   end
  end
  return rows
 end
 function api.Change(row,name,stand,remove)
  local ok,result=pcall(function()
   assert(type(row)=="table","Выбери локальный скин.")
   local index,raw=read()
   local record=index.entries[row.Index]
   assert(fileOf(record)==row.File and record.name==row.Name and record.stand==row.Stand,"Каталог изменился. Обнови список.")
   if remove then table.remove(index.entries,row.Index)
   else
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    stand=type(stand)=="string" and stand:match("^%s*(.-)%s*$") or ""
    assert(#name>0 and #name<=160 and not name:find("[%c]"),"Введи название скина.")
    assert(#stand>0 and #stand<=120 and not stand:find("[%c]"),"Выбери стенд.")
    for i,other in ipairs(index.entries) do
     assert(i==row.Index or type(other)~="table" or key(other.stand)~=key(stand) or key(other.name)~=key(name),"В этой категории уже есть скин с таким названием.")
    end
    record.name,record.stand=name,stand
   end
   local nextRaw=deps.Encode(index)
   if raw then deps.Backup(raw) end
   local written,why=pcall(function()deps.Write(nextRaw);assert(deps.Read()==nextRaw,"Запись каталога не подтверждена.")end)
   if not written then
    if raw then pcall(deps.Write,raw) end
    error(why,0)
   end
   return index
  end)
  if not ok then return false,tostring(result) end
  local refreshed,why=pcall(deps.Changed,result,row,remove)
  return true,not refreshed and ("Сохранено. Обновление меню не завершено: "..tostring(why)) or nil
 end
 return api
end
)({
  Read=function() local p="thebest/captured-skins/index.json";return isfile(p) and readfile(p) or nil end,
  Decode=function(raw)return HttpService:JSONDecode(raw)end,Encode=function(value)return HttpService:JSONEncode(value)end,
  Backup=function(raw)
   local p="thebest/captured-skins/index.json.backup";writefile(p,raw);assert(readfile(p)==raw,"Не удалось сохранить резервную копию.")
  end,
  Write=function(raw)writefile("thebest/captured-skins/index.json",raw)end,
  Changed=function(index,row,removed)
   if removed then
    for name,file in pairs(_G.skinChanger_stands) do if file==row.File then _G.skinChanger_stands[name]="" end end
    if _G.Config.playerStandOutfitSkin==row.File then disablePlayerOutfit() end
    SaveSkinDB();SaveConfig()
    if type(_G.TheBestClearSelectedSkinAura)=="function" then _G.TheBestClearSelectedSkinAura() end
    if type(_G.TheBestApplyStandSkinFromMorph)=="function" and getStandMorph2() then _G.TheBestApplyStandSkinFromMorph(getStandMorph2()) end
   end
   rebuild(index)
   tools.Log("skin",(removed and "Убрано из библиотеки: " or "Обновлено: ")..row.Name.." / "..row.Stand)
  end,
 })
 local labels={}
 local function refresh()
  local wanted=selected and selected.File
  clearPreview();selected=nil
  local why;rows,why=store.List();table.clear(labels)
  local nextLabel
  for _,row in ipairs(rows) do table.insert(labels,row.Label) end
  for _,row in ipairs(rows) do if row.File==wanted then nextLabel=row.Label;break end end
  if #labels==0 then labels[1]="None" end
  if dropdown then dropdown.Update(labels);dropdown.SetValue(nextLabel or labels[1]) end
  if why then status.SetText(why) end
 end
 refresh()
 dropdown=Library:CreateDropdown(section,"Сохранённый скин",labels,"None",false,function(label)
  clearPreview();selected=nil
  for _,row in ipairs(rows) do if row.Label==label then selected=row;break end end
  if selected and nameInput and standDropdown then
   nameInput.SetValue(selected.Name);standDropdown.SetValue(selected.Stand)
   status.SetText(selected.Name.." / "..selected.Stand)
  end
 end)
 nameInput=Library:CreateTextInput(section,"Название скина","","Новое название")
 local standNames={};for _,entry in ipairs(_G.TheBestStandCatalogEntries or {}) do table.insert(standNames,entry.Name) end;table.sort(standNames)
 standDropdown=Library:CreateDropdown(section,"Категория стенда",standNames,standNames[1],false,function()end)
 dropdown.SetValue(labels[1])
 Library:CreateButton(section,"Обновить список",refresh)
 Library:CreateButton(section,"Сохранить название и категорию",function()
  local ok,why=store.Change(selected,nameInput.GetValue(),standDropdown.GetValue(),false)
  if ok then refresh();status.SetText(why or "Сохранено. Каталог обновлён.") else status.SetText(why) end
 end)
 Library:CreateButton(section,"Предпросмотр скина",function()
  if previewBusy then status.SetText("Предпросмотр ещё загружается…");return end
  if not selected then status.SetText("Выбери локальный скин.");return end
  clearPreview();local token,row=generation,selected;previewBusy=true
  status.SetText("Подготовка предпросмотра…")
  task.spawn(function()
   local model
   local ok,why=pcall(function()
    local template=findBaseStandTemplate(row.Stand)
    assert(template,"Базовая модель стенда не найдена.")
    model=template:Clone();assert(model,"Не удалось скопировать базовую модель.")
    for _,object in ipairs(model:GetDescendants()) do
     if object:IsA("BaseScript") or object:IsA("ModuleScript") then object:Destroy() end
    end
    assert(LoadModel(row.File,row.Stand,model,true)~=false,"Не удалось построить модель скина.")
    for _,object in ipairs(model:GetDescendants()) do
     if object:IsA("BasePart") then object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false end
    end
    assert(token==generation and preview.Parent,"Предпросмотр отменён.")
    model.Parent=world
    local box,size=model:GetBoundingBox();local distance=math.max(size.X,size.Y,size.Z,1)*1.9
    camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(distance*.28,size.Y*.08,-distance),box.Position)
    previewFile=row.File
   end)
   previewBusy=false
   if token~=generation or not preview.Parent then if model then model:Destroy() end;return end
   if ok then status.SetText("Предпросмотр готов: "..row.Name) else if model then model:Destroy() end;status.SetText(tostring(why));tools.Log("error",tostring(why)) end
  end)
 end)
 Library:CreateButton(section,"Применить просмотренный скин",function()
  if not selected or previewFile~=selected.File then status.SetText("Сначала открой предпросмотр выбранного скина.");return end
  _G.skinChanger_stands[ANY_STAND_SKIN_DB_KEY]=selected.File
  _G.skinChanger_stands[selected.Stand]=selected.File;_G.skinChanger_stands[BASE_STAND_DB_KEY]=""
  SaveSkinDB()
  local morph=getStandMorph2()
  if morph and _G.TheBestApplyStandSkinFromMorph then _G.TheBestApplyStandSkinFromMorph(morph) end
  status.SetText("Скин выбран: "..selected.Name)
 end)
 local removeCandidate,removeTime
 Library:CreateButton(section,"Убрать выбранный скин из библиотеки",function()
  if not selected then status.SetText("Выбери локальный скин.");return end
  if removeCandidate~=selected or os.clock()-(removeTime or 0)>7 then
   removeCandidate,removeTime=selected,os.clock();status.SetText("Нажми ещё раз, чтобы убрать: "..selected.Name);return
  end
  local ok,why=store.Change(selected,nil,nil,true)
  removeCandidate=nil
  if ok then refresh();status.SetText(why or "Запись убрана. Модель и резервная копия сохранены.") else status.SetText(why) end
 end)
 preview.Parent=section.elementContainer;table.insert(section.elements,preview)
 preview.Destroying:Connect(function()generation+=1 end)
 registerThemeListener(function(theme)preview.BackgroundColor3=theme.dropdownBg end)
end

		end
]====]},
{At=2903374,Old=[====[						"TheBestPlayerListIdentityCleanup", "TheBestXenonIntegrationCleanup", "TheBestOptimizationCleanup",
]====],New=[====[						"TheBestPlayerListIdentityCleanup", "TheBestXenonIntegrationCleanup", "TheBestOptimizationCleanup", "TheBestToolsCleanup",
]====]},
{At=2978481,Old=[====[			renderConnection = runService.RenderStepped:Connect(step)
]====],New=[====[			renderConnection = runService.RenderStepped:Connect(_G.TheBestTools.Wrap("Эффекты меню",step))
]====]},
{At=2995336,Old=[====[]====],New=[====[	local buildLabel=label(frame,_G.TheBestTools.Build,620,664,245,24,11)
]====]},
{At=3008904,Old=[====[]====],New=[====[  position(context.BuildLabel,classic and 614 or 620,footerY,classic and 100 or 210,24)
  if context.BuildLabel then context.BuildLabel.Text=classic and context.BuildShort or context.BuildText end
]====]},
{At=3009824,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.30",BuildText=_G.TheBestTools.Build,
]====]},
{At=3013760,Old=[====[]====],New=[====[		buildLabel.TextColor3=theme.textDim
]====]},
{At=3017391,Old=[====[]====],New=[====[			_G.TheBestTools.Log("notice",tostring(title)..": "..tostring(text))
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest shuffle patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyToolsHealthPatch(main)
local function applyEnvironmentHealthPatch(source)
 assert(#source==3044443,"TheBest shuffle patch: unexpected source size")
 local edits={{At=44563,Old=[====[]====],New=[====[	clockTimeEnabled = true,
	antiVampBurnEnabled = false,
	blueWaterEnabled = false,
	keybindNotificationsEnabled = true,
]====]},
{At=62629,Old=[====[ local runtime={Build="v016.30 · 24.11.2026",Measuring=false,Stopped=false,JournalVersion=0}
]====],New=[====[ local runtime={Build="v016.31 · 24.11.2026",Measuring=false,Stopped=false,JournalVersion=0,Translate=function(text)return tostring(text or "")end}
]====]},
{At=63751,Old=[====[    table.insert(lines,string.format("%s [%s] %s%s",e.time,e.kind,e.text,e.count>1 and " ×"..e.count or ""))
]====],New=[====[    table.insert(lines,string.format("%s [%s] %s%s",e.time,runtime.Translate(({roll="Stand Rolls",sale="Sales",error="Errors",skin="Skin Library",notice="Notifications",system="System"})[e.kind] or e.kind),runtime.Translate(e.kind=="system" and e.text:gsub("^Запущена сборка ","Loaded build ") or e.text),e.count>1 and " ×"..e.count or ""))
]====]},
{At=65302,Old=[====[  local text={"Обработчики: мс/с · вызовов/с · пик, мс"}
  for _,row in ipairs(rows) do table.insert(text,string.format("%s: %.2f · %.0f · %.2f",row.Name,row.Time,row.Count,row.Peak)) end
  if #rows==0 then table.insert(text,"Ожидание измерений активных функций…") end
]====],New=[====[  local text={runtime.Translate("Handlers: ms/s · calls/s · peak, ms")}
  for _,row in ipairs(rows) do table.insert(text,string.format("%s: %.2f · %.0f · %.2f",runtime.Translate(row.Name),row.Time,row.Count,row.Peak)) end
  if #rows==0 then table.insert(text,runtime.Translate("Waiting for active handler measurements...")) end
]====]},
{At=65912,Old=[====[    keys[key]=keys[key] or {};table.insert(keys[key],labels and labels[action] or action)
]====],New=[====[    keys[key]=keys[key] or {};table.insert(keys[key],runtime.Translate(labels and labels[action] or action))
]====]},
{At=66181,Old=[====[  return #lines==0 and "Совпадений клавиш нет." or "Совпадают бинды:\n"..table.concat(lines,"\n"),#lines
]====],New=[====[  return #lines==0 and runtime.Translate("No keybind conflicts.") or runtime.Translate("Conflicting keybinds:").."\n"..table.concat(lines,"\n"),#lines
]====]},
{At=68370,Old=[====[]====],New=[====[  local gameHealth=character and character:FindFirstChild("Health")
  if gameHealth and (gameHealth:IsA("DoubleConstrainedValue") or gameHealth:IsA("IntConstrainedValue")) then
   local current,maximum=number(gameHealth.Value),number(gameHealth.MaxValue)
   if maximum and (maximum<=0 or (current and maximum<current)) then maximum=nil end
   return current,maximum
  end
]====]},
{At=68903,Old=[====[  if health==nil and humanoid then health=number(humanoid.Health) end
]====],New=[====[  if health==nil and humanoid and not deps.RequireGameHealth then health=number(humanoid.Health) end
]====]},
{At=69277,Old=[====[)({Clock=os.clock,Living=function()return workspace:FindFirstChild("Living")end})
]====],New=[====[)({Clock=os.clock,RequireGameHealth=true,Living=function()return workspace:FindFirstChild("Living")end})
]====]},
{At=69849,Old=[====[ tools.Log("system","Запущена сборка "..tools.Build)
]====],New=[====[ tools.Log("system","Loaded build "..tools.Build)
]====]},
{At=69954,Old=[====[]====],New=[====[do
 if type(_G.TheBestClockCleanup)=="function" then pcall(_G.TheBestClockCleanup) end
 local lighting=game:GetService("Lighting")
 local night=(function(previous,deps)
 if type(previous)=="table" and previous.Version==1 then return previous end
 local state={Version=1,Enabled=false,Installed=false,ReportedHour=0}
 function state.SetEnabled(value)
  if not value then state.Enabled=false;return true end
  if not state.Installed then
   if type(deps.Hook)~="function" or type(deps.CheckCaller)~="function" then
    return false,"This executor does not support separate game and visual time."
   end
   local original
   local function index(object,key)
    if state.Enabled and object==deps.Lighting and not deps.CheckCaller() then
     if key=="ClockTime" then return state.ReportedHour end
     if key=="TimeOfDay" then return "00:00:00" end
    end
    return original(object,key)
   end
   local ok,result=pcall(deps.Hook,deps.Game,"__index",deps.Closure(index))
   if not ok or type(result)~="function" then return false,"Could not install separate night-time reads." end
   original=result;state.Installed=true
  end
  state.ReportedHour=0;state.Enabled=true
  return true
 end
 function state.Refresh() state.ReportedHour=0 end
 return state
end
)(rawget(_G,"TheBestNightClockReadRuntime"),{
  Game=game,Lighting=lighting,Hook=hookmetamethod,CheckCaller=checkcaller,Closure=type(newcclosure)=="function" and newcclosure or function(callback)return callback end,
 })
 _G.TheBestNightClockReadRuntime=night
 local runtime=(function(deps)
 local stopped,controlled=false,false
 local original=deps.Lighting.ClockTime
 local nextNight=0
 local lastCharacter
 local runtime={LastError=nil}
 local function number(value)return type(value)=="number" and value==value and math.abs(value)<math.huge and value%24 or nil end
 local function serverTime()
  local source=deps.ServerClock()
  return source and number(source.Value) or nil
 end
 local function update(force)
  if stopped then return end
  local config=deps.Config()
  local desired
  if config.clockTimeEnabled then
   desired=config.xenonAlwaysNight and 0 or (config.xenonAlwaysDay and 12 or number(config.clocktime))
   desired=desired or 12
  elseif deps.Night.Enabled then
   desired=serverTime()
  elseif force or controlled then desired=serverTime() or original end
  if desired~=nil and deps.Lighting.ClockTime~=desired then deps.Lighting.ClockTime=desired end
  controlled=config.clockTimeEnabled==true or deps.Night.Enabled
 end
 function runtime.SetClockEnabled(value)
  local config=deps.Config();config.clockTimeEnabled=value==true
  if not value then config.xenonAlwaysNight=false;config.xenonAlwaysDay=false end
  if runtime.OnClockChanged then runtime.OnClockChanged(config.clockTimeEnabled) end
  update(true)
 end
 function runtime.SetAntiBurn(value)
  local config=deps.Config()
  local ok,reason=deps.Night.SetEnabled(value==true)
  config.antiVampBurnEnabled=ok and value==true
  runtime.LastError=not ok and reason or nil
  lastCharacter=nil;nextNight=0
  runtime.Step()
  update(true)
  return ok,reason
 end
 function runtime.Step()
  if stopped then return end
  local now=deps.Clock()
  if deps.Night.Enabled and now>=nextNight then
   nextNight=now+5;deps.Night.Refresh()
   local character=deps.Character()
   if character and character~=lastCharacter then
    lastCharacter=character
    pcall(deps.ClearBurn,character)
   end
  end
  update(false)
 end
 function runtime.Cleanup()
  if stopped then return end
  stopped=true;runtime.OnClockChanged=nil;deps.Night.SetEnabled(false)
  deps.Lighting.ClockTime=serverTime() or original
 end
 runtime.SetAntiBurn(deps.Config().antiVampBurnEnabled==true)
 return runtime
end
)({Lighting=lighting,Night=night,Clock=os.clock,Config=function()return _G.Config end,
  ServerClock=function()return game:GetService("ReplicatedStorage"):FindFirstChild("ClockTime")end,
  Character=function()return game:GetService("Players").LocalPlayer.Character end,
  ClearBurn=function(character)
   local remote=character:FindFirstChild("RemoteEvent")
   if remote and remote:IsA("RemoteEvent") then remote:FireServer("VampireBurnOff") end
  end,
 })
 _G.TheBestClock=runtime
 _G.TheBestClockCleanup=function()
  runtime.Cleanup()
  if _G.TheBestClock==runtime then _G.TheBestClock=nil;_G.TheBestClockCleanup=nil end
 end
end
]====]},
{At=116397,Old=[====[		RunService:BindToRenderStep("DrawingESP_Update", Enum.RenderPriority.Camera.Value + 1, _G.TheBestTools.Wrap("ESP игроков",updateEsp))
]====],New=[====[		RunService:BindToRenderStep("DrawingESP_Update", Enum.RenderPriority.Camera.Value + 1, _G.TheBestTools.Wrap("Player ESP",updateEsp))
]====]},
{At=149232,Old=[====[]====],New=[====[do
 if type(_G.TheBestWaterCleanup)=="function" then pcall(_G.TheBestWaterCleanup) end
 local runtime=(function(deps)
 local records=setmetatable({},{__mode="k"})
 local stopped,nextScan=false,0
 local function capture(ocean)
  local record=records[ocean]
  if record then return record end
  record={Color=ocean.Color,Blue=false,OldTexture=false}
  records[ocean]=record
  record.Connection=ocean:GetPropertyChangedSignal("Color"):Connect(function()
   if stopped or not ocean.Parent or ocean.Color==record.AppliedColor then return end
   record.Color=ocean.Color
   if record.Blue then record.AppliedColor=deps.Blue;ocean.Color=deps.Blue end
  end)
  return record
 end
 local function blue(ocean,record,enabled)
  if enabled then
   record.Blue=true;record.AppliedColor=deps.Blue
   if ocean.Color~=deps.Blue then ocean.Color=deps.Blue end
  elseif record.Blue then
   record.Blue=false;record.AppliedColor=nil;ocean.Color=record.Color
  end
 end
 local function texture(ocean,record,enabled)
  if enabled and not record.OldTexture then
   local original=ocean:FindFirstChild("WaterTextMaterial")
   if original then
    local saved=original:Clone()
    if not saved then return end
    record.Texture=saved;original:Destroy()
   end
   record.OldTexture=true
  elseif not enabled and record.OldTexture then
   if record.Texture and not ocean:FindFirstChild("WaterTextMaterial") then record.Texture.Parent=ocean;record.Texture=nil end
   record.OldTexture=false
  end
 end
 local runtime={}
 function runtime.Apply()
  if stopped then return end
  local ocean=deps.Ocean()
  if not ocean or not ocean:IsA("BasePart") then return end
  local record=capture(ocean)
  local config=deps.Config()
  blue(ocean,record,config.blueWaterEnabled==true)
  texture(ocean,record,config.OldWaterTexture==true)
 end
 function runtime.Step()
  if stopped or deps.Clock()<nextScan then return end
  nextScan=deps.Clock()+1
  local config=deps.Config()
  if config.blueWaterEnabled or config.OldWaterTexture then runtime.Apply() end
 end
 function runtime.Cleanup()
  if stopped then return end
  stopped=true
  for ocean,record in pairs(records) do
   record.Connection:Disconnect()
   if ocean.Parent then blue(ocean,record,false);texture(ocean,record,false) end
   if record.Texture then record.Texture:Destroy() end
  end
  table.clear(records)
 end
 runtime.Apply()
 return runtime
end
)({Ocean=getOcean,Config=function()return _G.Config end,Clock=os.clock,Blue=BrickColor.new("Royal blue").Color})
 _G.TheBestWater=runtime
 _G.TheBestWaterCleanup=function()
  runtime.Cleanup()
  if _G.TheBestWater==runtime then _G.TheBestWater=nil;_G.TheBestWaterCleanup=nil end
 end
end

]====]},
{At=206486,Old=[====[]====],New=[====[  local ownedBindState=function(action)
   if action=="aimbot" then return _G.Config.enableAimbot==true and holdingAimbot end
   if action=="speedhack" then return speedhackState.IsRunning() end
   if action=="fly" then return flyActive end
   if action=="standPilot" then if _G.Config.pilotMode=="Stand Only" then return nil end;return standPilotActive end
   local field=({esp="mhud",autoParry="autoParryEnabled",invisibility="invisibilityEnabled",classicPilot="classicPilotEnabled"})[action]
   if field then return _G.Config[field]==true end
  end
  _G.TheBestGetBindState=ownedBindState
]====]},
{At=209959,Old=[====[]====],New=[====[			if _G.TheBestGetBindState==ownedBindState then _G.TheBestGetBindState=nil end
]====]},
{At=211206,Old=[====[]====],New=[====[["Handlers: ms/s · calls/s · peak, ms"]="Обработчики: мс/с · вызовов/с · пик, мс",
["Waiting for active handler measurements..."]="Ожидание измерений активных функций…",
["No keybind conflicts."]="Совпадений клавиш нет.",
["Conflicting keybinds:"]="Совпадают бинды:",
["Player ESP"]="ESP игроков",
["Skin Auras"]="Ауры скинов",
["Menu Effects"]="Эффекты меню",
["Item ESP"]="ESP предметов",
["Menu Background"]="Фон меню",
["Lighting and Effects"]="Освещение и эффекты",
["Measuring active handlers..."]="Измерение активных обработчиков…",
["Local handlers are measured while this section is open."]="Измеряются локальные обработчики, пока открыт этот раздел.",
["Session Journal"]="Журнал сессии",
["Stand Rolls"]="Стенды и скины",
["Sales"]="Продажи",
["Errors"]="Ошибки",
["Skin Library"]="Библиотека скинов",
["Notifications"]="Уведомления",
["System"]="Система",
["All"]="Все",
["Show"]="Показывать",
["No events yet."]="Событий пока нет.",
["Events:"]="Событий:",
["newest first"]="последние сверху",
["Refresh Journal"]="Обновить журнал",
["Clear Journal"]="Очистить журнал",
["Enable Clock Time"]="Изменять время суток",
["Anti Vamp Burn"]="Защита вампира от солнца",
["Blue Water"]="Синяя вода",
["Game time flows normally when Clock Time is off."]="Когда изменение времени выключено, используется текущее время игры.",
["Anti Vamp Burn keeps game clock reads at midnight; visible time stays separate."]="Проверки игры видят полночь; видимое время настраивается отдельно.",
["This executor does not support separate game and visual time."]="Этот исполнитель не поддерживает раздельное игровое и видимое время.",
["Could not install separate night-time reads."]="Не удалось включить ночное время для проверок игры.",
["A profile is already loading."]="Профиль уже загружается.",
["boot.lua was not found."]="Не найден boot.lua.",
["Could not stop the current menu."]="Не удалось остановить текущее меню.",
["Could not write settings."]="Не удалось записать настройки.",
["Profile loading failed. See the v016 log."]="Ошибка загрузки профиля. См. журнал v016.",
["Could not back up profiles."]="Не удалось сохранить резервную копию профилей.",
["Could not write profiles."]="Не удалось записать профили.",
["The profiles file is damaged."]="Файл профилей повреждён.",
["Enter a profile name."]="Введи название профиля.",
["Could not save current settings."]="Не удалось сохранить текущие настройки.",
["Select a profile."]="Выбери профиль.",
["The profile contains invalid settings."]="Профиль содержит некорректные настройки.",
["Files are unavailable."]="Файлы недоступны.",
["Profile saved."]="Профиль сохранён.",
["Applying profile..."]="Применяю профиль…",
["Profile deleted."]="Профиль удалён.",
["Initial settings"]="Исходные настройки",
["Unlimited"]="Без ограничения",
[" Hz"]=" Гц",
[" ms"]=" мс",
[" KB/s"]=" КБ/с",
["Keybind Notifications"]="Уведомления биндов",
["Pressed"]="Нажата",
["Fly"]="Полёт",
["Speedhack"]="Ускорение",
["Menu"]="Меню",
["Select Target"]="Выбор цели",
["Stand Pilot"]="Управление стендом",
["Invisibility"]="Невидимость",
["Classic Pilot"]="Классическое управление",
["TP To Target"]="Телепорт к цели",
["TP To Dio OH"]="Телепорт к Dio OH",
["Safe Zone"]="Безопасная зона",
["FPS: %.0f | Frame: %.1f ms\nNetwork ping: %s | Data ping: %s\nSend: %s | Receive: %s\nESP: %s | Adaptive load reduction: %s"]="FPS: %.0f | Кадр: %.1f мс\nСетевой пинг: %s | Пинг данных: %s\nОтправка: %s | Приём: %s\nESP: %s | Адаптивное снижение нагрузки: %s",
]====]},
{At=300834,Old=[====[]====],New=[====[ {"Loaded build ","Запущена сборка "},
]====]},
{At=304530,Old=[====[]====],New=[====[					if text=="Исходные настройки" then text="Initial settings" end
]====]},
{At=307714,Old=[====[]====],New=[====[			_G.TheBestTools.Translate=Library.Localization.Translate
]====]},
{At=331724,Old=[====[			local backgroundAnimationConnection = RunService.RenderStepped:Connect(_G.TheBestTools.Wrap("Фон меню",function(deltaTime)
]====],New=[====[			local backgroundAnimationConnection = RunService.RenderStepped:Connect(_G.TheBestTools.Wrap("Menu Background",function(deltaTime)
]====]},
{At=411079,Old=[====[]====],New=[====[					_G.TheBestKeybindCaptureEndedAt=os.clock()
]====]},
{At=527230,Old=[====[]====],New=[====[					_G.Config.clockTimeEnabled=true
					if _G.TheBestClock then _G.TheBestClock.SetClockEnabled(true) end
]====]},
{At=527435,Old=[====[]====],New=[====[					_G.Config.clockTimeEnabled=true
					if _G.TheBestClock then _G.TheBestClock.SetClockEnabled(true) end
]====]},
{At=577729,Old=[====[				_G.TheBestTools.Run("ESP предметов",updateItemEspDistances)
]====],New=[====[				_G.TheBestTools.Run("Item ESP",updateItemEspDistances)
]====]},
{At=577909,Old=[====[				if not lightingGuard then
]====],New=[====[				if _G.Config.clockTimeEnabled and not lightingGuard then
]====]},
{At=749189,Old=[====[		 local profileStatus=Library:CreateStatusLabel(section,"Измерение активных обработчиков…")
]====],New=[====[		 local profileStatus=Library:CreateStatusLabel(section,"Measuring active handlers...")
]====]},
{At=749362,Old=[====[		 Library:CreateStatusLabel(section,"Измеряются локальные обработчики, пока открыт этот раздел.")
]====],New=[====[		 Library:CreateStatusLabel(section,"Local handlers are measured while this section is open.")
		 Library.Localization.Register(function()profileStatus.SetText(_G.TheBestTools.ProfileText())end)
]====]},
{At=749669,Old=[====[		   local function metric(value,unit)return value and string.format("%.0f%s",value,unit) or "--"end
		   status.SetText(string.format("FPS: %.0f | Frame: %.1f ms\nNetwork ping: %s | Data ping: %s\nSend: %s | Receive: %s\nESP: %s | Adaptive load reduction: %s",
		    data.FPS,data.FrameMs,metric(data.NetworkPing," ms"),metric(data.DataPing," ms"),metric(data.Send," KB/s"),metric(data.Receive," KB/s"),data.EspRate==0 and "Unlimited" or tostring(data.EspRate).." Hz",data.Pressure and "ON" or "OFF"))
]====],New=[====[		   local function metric(value,unit)return value and string.format("%.0f%s",value,Library.Localization.Translate(unit)) or "--"end
		   status.SetText(string.format(Library.Localization.Translate("FPS: %.0f | Frame: %.1f ms\nNetwork ping: %s | Data ping: %s\nSend: %s | Receive: %s\nESP: %s | Adaptive load reduction: %s"),
		    data.FPS,data.FrameMs,metric(data.NetworkPing," ms"),metric(data.DataPing," ms"),metric(data.Send," KB/s"),metric(data.Receive," KB/s"),data.EspRate==0 and Library.Localization.Translate("Unlimited") or tostring(data.EspRate)..Library.Localization.Translate(" Hz"),data.Pressure and "ON" or "OFF"))
]====]},
{At=750574,Old=[====[ local section=Library:CreateFunctionTab(tab_misc,"Журнал сессии")
 local kinds={all="Все",roll="Стенды и скины",sale="Продажи",error="Ошибки",skin="Библиотека скинов",notice="Уведомления",system="Система"}
]====],New=[====[ local section=Library:CreateFunctionTab(tab_misc,"Session Journal")
 local kinds={all="All",roll="Stand Rolls",sale="Sales",error="Errors",skin="Skin Library",notice="Notifications",system="System"}
]====]},
{At=751836,Old=[====[  text.Text=count>0 and value or "Событий пока нет."
  status.SetText("Событий: "..count.." · последние сверху")
]====],New=[====[  text.Text=count>0 and value or Library.Localization.Translate("No events yet.")
  status.SetText(string.format("%s %d · %s",Library.Localization.Translate("Events:"),count,Library.Localization.Translate("newest first")))
]====]},
{At=751991,Old=[====[ Library:CreateDropdown(section,"Показывать",{"Все","Стенды и скины","Продажи","Ошибки","Библиотека скинов","Уведомления","Система"},"Все",false,function(value)
]====],New=[====[ Library:CreateDropdown(section,"Show",{"All","Stand Rolls","Sales","Errors","Skin Library","Notifications","System"},"All",false,function(value)
]====]},
{At=752324,Old=[====[ Library:CreateButton(section,"Обновить журнал",refresh)
 Library:CreateButton(section,"Очистить журнал",function() tools.ClearJournal();refresh() end)
]====],New=[====[ Library:CreateButton(section,"Refresh Journal",refresh)
 Library:CreateButton(section,"Clear Journal",function() tools.ClearJournal();refresh() end)
]====]},
{At=752603,Old=[====[]====],New=[====[ Library.Localization.Register(function()lastKind=nil;refresh()end)
]====]},
{At=752841,Old=[====[ registerThemeListener(function(theme) pane.BackgroundColor3=theme.dropdownBg;text.TextColor3=theme.text;pane.ScrollBarImageColor3=theme.accent end)
]====],New=[====[ registerThemeListener(function(theme)pane.BackgroundColor3=theme.dropdownBg;text.TextColor3=theme.text;pane.ScrollBarImageColor3=theme.accent end)
]====]},
{At=826424,Old=[====[]====],New=[====[		do
   local control=Library:CreateToggle(visualsSection,"Enable Clock Time",_G.Config.clockTimeEnabled,function(value)
    _G.TheBestClock.SetClockEnabled(value);SaveConfig()
   end)
   _G.TheBestClock.OnClockChanged=function(value)control.SetState(value,false)end
   Library:CreateStatusLabel(visualsSection,"Game time flows normally when Clock Time is off.")
   local status=Library:CreateStatusLabel(visualsSection,"Anti Vamp Burn keeps game clock reads at midnight; visible time stays separate.")
   status.Frame.Size=UDim2.new(1,0,0,40)
   local antiControl
   antiControl=Library:CreateToggle(visualsSection,"Anti Vamp Burn",_G.Config.antiVampBurnEnabled,function(value)
    local ok,reason=_G.TheBestClock.SetAntiBurn(value)
    status.SetText(reason or "Anti Vamp Burn keeps game clock reads at midnight; visible time stays separate.")
    if not ok and antiControl then antiControl.SetState(false,false) end
    SaveConfig()
   end)
   antiControl.SetState(_G.Config.antiVampBurnEnabled,false)
  end
]====]},
{At=826548,Old=[====[]====],New=[====[			if _G.TheBestClock then _G.TheBestClock.Step() end
]====]},
{At=827957,Old=[====[		Library:CreateToggle(visualsSection, "Old Water Texture", _G.Config.OldWaterTexture, function(val)
			_G.Config.OldWaterTexture = val
			local succ, err = pcall(function()
				local ocean = getOcean()
				if not ocean then
					return
				end
				local hasTexture = ocean:FindFirstChild("WaterTextMaterial") ~= nil
				if val then
					ocean.BrickColor = BrickColor.new("Bright blue")
					if hasTexture then
						ocean:FindFirstChild("WaterTextMaterial"):Destroy()
					end
				else
					ocean.BrickColor = BrickColor.new("Royal blue")
					if not hasTexture then
						createWaterTexture()
					end
				end
			end)
			if not succ then
				warn("[OLD WATER TEXTURE] " .. err)
			end
			SaveConfig()
		end)
]====],New=[====[  Library:CreateToggle(visualsSection,"Blue Water",_G.Config.blueWaterEnabled,function(value)
   _G.Config.blueWaterEnabled=value==true;_G.TheBestWater.Apply();SaveConfig()
  end)
  Library:CreateToggle(visualsSection,"Old Water Texture",_G.Config.OldWaterTexture,function(value)
   _G.Config.OldWaterTexture=value==true;_G.TheBestWater.Apply();SaveConfig()
  end)
]====]},
{At=1032200,Old=[====[		_G.miscVisualConn = RunService.RenderStepped:Connect(_G.TheBestTools.Wrap("Освещение и эффекты",function(deltaTime)
			local clock=tonumber(_G.Config.clocktime) or 12
			if clock~=clock or math.abs(clock)==math.huge then clock=12 end
			clock=_G.Config.xenonAlwaysNight and 0 or (_G.Config.xenonAlwaysDay and 12 or clock%24)
			if Lighting.ClockTime~=clock then Lighting.ClockTime=clock end
]====],New=[====[		_G.miscVisualConn = RunService.RenderStepped:Connect(_G.TheBestTools.Wrap("Lighting and Effects",function(deltaTime)
			if _G.TheBestClock then _G.TheBestClock.Step() end
]====]},
{At=1033037,Old=[====[]====],New=[====[			if _G.TheBestWater then _G.TheBestWater.Step() end
]====]},
{At=1051909,Old=[====[]====],New=[====[                Library.Localization.Register(Library.RefreshKeybindWarnings)
                Library:CreateToggle(keybindSection,"Keybind Notifications",_G.Config.keybindNotificationsEnabled,function(value)
                 _G.Config.keybindNotificationsEnabled=value==true;SaveConfig()
                end)
]====]},
{At=1053757,Old=[====[		assert(not _G.TheBestProfileLoadInProgress, "Профиль уже загружается.")
		local bootSource = assert(read("thebest/runtime-v016/boot.lua"), "Не найден boot.lua.")
]====],New=[====[		assert(not _G.TheBestProfileLoadInProgress, "A profile is already loading.")
		local bootSource = assert(read("thebest/runtime-v016/boot.lua"), "boot.lua was not found.")
]====]},
{At=1054387,Old=[====[			assert(type(shutdown) == "function" and shutdown(), "Не удалось остановить текущее меню.")
]====],New=[====[			assert(type(shutdown) == "function" and shutdown(), "Could not stop the current menu.")
]====]},
{At=1054589,Old=[====[			assert(read(CONFIG_FILE) == configRaw and read(KEYBINDS_FILE) == keybindsRaw, "Не удалось записать настройки.")
]====],New=[====[			assert(read(CONFIG_FILE) == configRaw and read(KEYBINDS_FILE) == keybindsRaw, "Could not write settings.")
]====]},
{At=1054785,Old=[====[			assert(not diagnostics or diagnostics.Status == "startup finished", "Ошибка загрузки профиля. См. журнал v016.")
]====],New=[====[			assert(not diagnostics or diagnostics.Status == "startup finished", "Profile loading failed. See the v016 log.")
]====]},
{At=1056422,Old=[====[			return false, "Не удалось сохранить резервную копию профилей."
]====],New=[====[			return false, "Could not back up profiles."
]====]},
{At=1056625,Old=[====[			return false, "Не удалось записать профили."
]====],New=[====[			return false, "Could not write profiles."
]====]},
{At=1056940,Old=[====[			loadError = "Файл профилей повреждён."
]====],New=[====[			loadError = "The profiles file is damaged."
]====]},
{At=1057311,Old=[====[		if name == "" then return false, "Введи название профиля." end
]====],New=[====[		if name == "" then return false, "Enter a profile name." end
]====]},
{At=1057550,Old=[====[		if not ok then return false, "Не удалось сохранить текущие настройки." end
]====],New=[====[		if not ok then return false, "Could not save current settings." end
]====]},
{At=1057849,Old=[====[		if not profiles[name] then return false, "Выбери профиль." end
]====],New=[====[		if not profiles[name] then return false, "Select a profile." end
]====]},
{At=1058094,Old=[====[		if not snapshot then return false, "Выбери профиль." end
]====],New=[====[		if not snapshot then return false, "Select a profile." end
]====]},
{At=1058220,Old=[====[		if not ok or not accepted then return false, "Профиль содержит некорректные настройки." end
]====],New=[====[		if not ok or not accepted then return false, "The profile contains invalid settings." end
]====]},
{At=1058569,Old=[====[		local ok, reason = api.Save("Исходные настройки")
]====],New=[====[		local ok, reason = api.Save("Initial settings")
]====]},
{At=1058781,Old=[====[			assert(type(writefile) == "function", "Файлы недоступны.")
]====],New=[====[			assert(type(writefile) == "function", "Files are unavailable.")
]====]},
{At=1060096,Old=[====[		status.SetText(ok and "Профиль сохранён." or reason)
]====],New=[====[		status.SetText(ok and "Profile saved." or reason)
]====]},
{At=1060237,Old=[====[		status.SetText("Применяю профиль…")
]====],New=[====[		status.SetText("Applying profile...")
]====]},
{At=1060646,Old=[====[		status.SetText(ok and "Профиль удалён." or reason)
]====],New=[====[		status.SetText(ok and "Profile deleted." or reason)
]====]},
{At=2291663,Old=[====[		local auraConnection=game:GetService("RunService").Heartbeat:Connect(_G.TheBestTools.Wrap("Ауры скинов",updateSkinAura))
]====],New=[====[		local auraConnection=game:GetService("RunService").Heartbeat:Connect(_G.TheBestTools.Wrap("Skin Auras",updateSkinAura))
]====]},
{At=2861792,Old=[====[do
 local tools=_G.TheBestTools
 local section=Library:CreateFunctionTab(tab_misc,"Локальные скины")
 local rows,selected,previewFile,previewBusy={},nil,nil,false
 local generation=0
 local store,dropdown,nameInput,standDropdown
 local status=Library:CreateStatusLabel(section,"Выбери сохранённый скин. Предпросмотр не меняет персонажа.")
 status.Frame.Size=UDim2.new(1,0,0,40)
 local preview=Instance.new("ViewportFrame")
 preview.Name="CapturedSkinPreview";preview.Size=UDim2.new(1,0,0,220)
 preview.BackgroundColor3=T.dropdownBg;preview.BorderSizePixel=0
 preview.Ambient=Color3.fromRGB(195,195,210);preview.LightColor=Color3.fromRGB(255,244,225)
 local world=Instance.new("WorldModel");world.Parent=preview
 local camera=Instance.new("Camera");camera.FieldOfView=32;camera.Parent=preview;preview.CurrentCamera=camera
 local function clearPreview()
  generation+=1;previewFile=nil;world:ClearAllChildren()
 end
 local function rebuild(index)
  local entries,groups={},{}
  local info=_G.TheBestCapturedSkinInfo
  for file in pairs(info) do if store.File({file=file}) then info[file]=nil end end
  for _,entry in ipairs(_G.TheBestStandCatalogEntries or {}) do
   local copy={Name=entry.Name,Skins={}}
   for _,skin in ipairs(entry.Skins or {}) do
    local file=type(skin)=="table" and skin.Value or skin
    if not store.File({file=file}) then table.insert(copy.Skins,skin) end
   end
   groups[entry.Name]=copy;table.insert(entries,copy)
  end
  local count=0
  for _,record in ipairs(index.entries) do
   local file=store.File(record)
   if file and type(record.name)=="string" and type(record.stand)=="string" and _G.TheBestCatalogIsAvailableFile(file) then
    local group=groups[record.stand]
    if not group then group={Name=record.stand,Skins={"None"}};groups[record.stand]=group;table.insert(entries,group) end
    table.insert(group.Skins,{Name=record.name.." [Local]",Value=file})
    info[file]={file=file,name=record.name,stand=record.stand};count+=1
   end
  end
  _G.TheBestStandCatalogEntries=entries;_G.TheBestCapturedSkinCount=count
  local visible={}
  for _,entry in ipairs(entries) do if #entry.Skins>1 then table.insert(visible,entry) end end
  if standCards then standCards.SetItems(visible) end
 end
 store=(function(deps)
 local function fileOf(record)
  local file=type(record)=="table" and type(record.file)=="string" and record.file:gsub("\\","/"):gsub("^ssoc_skins/","")
  return file and file:match("^captured%-[%w%-]+%.ssoc$") and file or nil
 end
 local function read()
  local raw=deps.Read()
  if not raw then return {schema=1,entries={}},nil end
  local index=deps.Decode(raw)
  assert(type(index)=="table" and index.schema==1 and type(index.entries)=="table","Каталог скинов повреждён.")
  return index,raw
 end
 local function key(text) return tostring(text or ""):lower():gsub("%s+","") end
 local api={File=fileOf}
 function api.List()
  local ok,index=pcall(read)
  if not ok then return {},tostring(index) end
  local rows={}
  for n,record in ipairs(index.entries) do
   if fileOf(record) and type(record.name)=="string" and type(record.stand)=="string" then
    table.insert(rows,{Index=n,File=fileOf(record),Name=record.name,Stand=record.stand,
     Label=tostring(n)..". "..record.name.." — "..record.stand})
   end
  end
  return rows
 end
 function api.Change(row,name,stand,remove)
  local ok,result=pcall(function()
   assert(type(row)=="table","Выбери локальный скин.")
   local index,raw=read()
   local record=index.entries[row.Index]
   assert(fileOf(record)==row.File and record.name==row.Name and record.stand==row.Stand,"Каталог изменился. Обнови список.")
   if remove then table.remove(index.entries,row.Index)
   else
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    stand=type(stand)=="string" and stand:match("^%s*(.-)%s*$") or ""
    assert(#name>0 and #name<=160 and not name:find("[%c]"),"Введи название скина.")
    assert(#stand>0 and #stand<=120 and not stand:find("[%c]"),"Выбери стенд.")
    for i,other in ipairs(index.entries) do
     assert(i==row.Index or type(other)~="table" or key(other.stand)~=key(stand) or key(other.name)~=key(name),"В этой категории уже есть скин с таким названием.")
    end
    record.name,record.stand=name,stand
   end
   local nextRaw=deps.Encode(index)
   if raw then deps.Backup(raw) end
   local written,why=pcall(function()deps.Write(nextRaw);assert(deps.Read()==nextRaw,"Запись каталога не подтверждена.")end)
   if not written then
    if raw then pcall(deps.Write,raw) end
    error(why,0)
   end
   return index
  end)
  if not ok then return false,tostring(result) end
  local refreshed,why=pcall(deps.Changed,result,row,remove)
  return true,not refreshed and ("Сохранено. Обновление меню не завершено: "..tostring(why)) or nil
 end
 return api
end
)({
  Read=function() local p="thebest/captured-skins/index.json";return isfile(p) and readfile(p) or nil end,
  Decode=function(raw)return HttpService:JSONDecode(raw)end,Encode=function(value)return HttpService:JSONEncode(value)end,
  Backup=function(raw)
   local p="thebest/captured-skins/index.json.backup";writefile(p,raw);assert(readfile(p)==raw,"Не удалось сохранить резервную копию.")
  end,
  Write=function(raw)writefile("thebest/captured-skins/index.json",raw)end,
  Changed=function(index,row,removed)
   if removed then
    for name,file in pairs(_G.skinChanger_stands) do if file==row.File then _G.skinChanger_stands[name]="" end end
    if _G.Config.playerStandOutfitSkin==row.File then disablePlayerOutfit() end
    SaveSkinDB();SaveConfig()
    if type(_G.TheBestClearSelectedSkinAura)=="function" then _G.TheBestClearSelectedSkinAura() end
    if type(_G.TheBestApplyStandSkinFromMorph)=="function" and getStandMorph2() then _G.TheBestApplyStandSkinFromMorph(getStandMorph2()) end
   end
   rebuild(index)
   tools.Log("skin",(removed and "Убрано из библиотеки: " or "Обновлено: ")..row.Name.." / "..row.Stand)
  end,
 })
 local labels={}
 local function refresh()
  local wanted=selected and selected.File
  clearPreview();selected=nil
  local why;rows,why=store.List();table.clear(labels)
  local nextLabel
  for _,row in ipairs(rows) do table.insert(labels,row.Label) end
  for _,row in ipairs(rows) do if row.File==wanted then nextLabel=row.Label;break end end
  if #labels==0 then labels[1]="None" end
  if dropdown then dropdown.Update(labels);dropdown.SetValue(nextLabel or labels[1]) end
  if why then status.SetText(why) end
 end
 refresh()
 dropdown=Library:CreateDropdown(section,"Сохранённый скин",labels,"None",false,function(label)
  clearPreview();selected=nil
  for _,row in ipairs(rows) do if row.Label==label then selected=row;break end end
  if selected and nameInput and standDropdown then
   nameInput.SetValue(selected.Name);standDropdown.SetValue(selected.Stand)
   status.SetText(selected.Name.." / "..selected.Stand)
  end
 end)
 nameInput=Library:CreateTextInput(section,"Название скина","","Новое название")
 local standNames={};for _,entry in ipairs(_G.TheBestStandCatalogEntries or {}) do table.insert(standNames,entry.Name) end;table.sort(standNames)
 standDropdown=Library:CreateDropdown(section,"Категория стенда",standNames,standNames[1],false,function()end)
 dropdown.SetValue(labels[1])
 Library:CreateButton(section,"Обновить список",refresh)
 Library:CreateButton(section,"Сохранить название и категорию",function()
  local ok,why=store.Change(selected,nameInput.GetValue(),standDropdown.GetValue(),false)
  if ok then refresh();status.SetText(why or "Сохранено. Каталог обновлён.") else status.SetText(why) end
 end)
 Library:CreateButton(section,"Предпросмотр скина",function()
  if previewBusy then status.SetText("Предпросмотр ещё загружается…");return end
  if not selected then status.SetText("Выбери локальный скин.");return end
  clearPreview();local token,row=generation,selected;previewBusy=true
  status.SetText("Подготовка предпросмотра…")
  task.spawn(function()
   local model
   local ok,why=pcall(function()
    local template=findBaseStandTemplate(row.Stand)
    assert(template,"Базовая модель стенда не найдена.")
    model=template:Clone();assert(model,"Не удалось скопировать базовую модель.")
    for _,object in ipairs(model:GetDescendants()) do
     if object:IsA("BaseScript") or object:IsA("ModuleScript") then object:Destroy() end
    end
    assert(LoadModel(row.File,row.Stand,model,true)~=false,"Не удалось построить модель скина.")
    for _,object in ipairs(model:GetDescendants()) do
     if object:IsA("BasePart") then object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false end
    end
    assert(token==generation and preview.Parent,"Предпросмотр отменён.")
    model.Parent=world
    local box,size=model:GetBoundingBox();local distance=math.max(size.X,size.Y,size.Z,1)*1.9
    camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(distance*.28,size.Y*.08,-distance),box.Position)
    previewFile=row.File
   end)
   previewBusy=false
   if token~=generation or not preview.Parent then if model then model:Destroy() end;return end
   if ok then status.SetText("Предпросмотр готов: "..row.Name) else if model then model:Destroy() end;status.SetText(tostring(why));tools.Log("error",tostring(why)) end
  end)
 end)
 Library:CreateButton(section,"Применить просмотренный скин",function()
  if not selected or previewFile~=selected.File then status.SetText("Сначала открой предпросмотр выбранного скина.");return end
  _G.skinChanger_stands[ANY_STAND_SKIN_DB_KEY]=selected.File
  _G.skinChanger_stands[selected.Stand]=selected.File;_G.skinChanger_stands[BASE_STAND_DB_KEY]=""
  SaveSkinDB()
  local morph=getStandMorph2()
  if morph and _G.TheBestApplyStandSkinFromMorph then _G.TheBestApplyStandSkinFromMorph(morph) end
  status.SetText("Скин выбран: "..selected.Name)
 end)
 local removeCandidate,removeTime
 Library:CreateButton(section,"Убрать выбранный скин из библиотеки",function()
  if not selected then status.SetText("Выбери локальный скин.");return end
  if removeCandidate~=selected or os.clock()-(removeTime or 0)>7 then
   removeCandidate,removeTime=selected,os.clock();status.SetText("Нажми ещё раз, чтобы убрать: "..selected.Name);return
  end
  local ok,why=store.Change(selected,nil,nil,true)
  removeCandidate=nil
  if ok then refresh();status.SetText(why or "Запись убрана. Модель и резервная копия сохранены.") else status.SetText(why) end
 end)
 preview.Parent=section.elementContainer;table.insert(section.elements,preview)
 preview.Destroying:Connect(function()generation+=1 end)
 registerThemeListener(function(theme)preview.BackgroundColor3=theme.dropdownBg end)
end
]====],New=[====[]====]},
{At=2924097,Old=[====[						"mhud", "showHitbox", "showCoordinates", "hitboxEnabled", "hitboxAdaptive",
]====],New=[====[						"clockTimeEnabled", "antiVampBurnEnabled", "blueWaterEnabled", "mhud", "showHitbox", "showCoordinates", "hitboxEnabled", "hitboxAdaptive",
]====]},
{At=2926993,Old=[====[						"TheBestPlayerListIdentityCleanup", "TheBestXenonIntegrationCleanup", "TheBestOptimizationCleanup", "TheBestToolsCleanup",
]====],New=[====[						"TheBestPlayerListIdentityCleanup", "TheBestXenonIntegrationCleanup", "TheBestOptimizationCleanup", "TheBestToolsCleanup", "TheBestClockCleanup", "TheBestWaterCleanup",
]====]},
{At=3002123,Old=[====[			renderConnection = runService.RenderStepped:Connect(_G.TheBestTools.Wrap("Эффекты меню",step))
]====],New=[====[			renderConnection = runService.RenderStepped:Connect(_G.TheBestTools.Wrap("Menu Effects",step))
]====]},
{At=3033782,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.30",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.31",BuildText=_G.TheBestTools.Build,
]====]},
{At=3035316,Old=[====[		wantedVisible=visible;menuGeneration+=1
]====],New=[====[		wantedVisible=visible;Library.MenuWantedVisible=visible;menuGeneration+=1
]====]},
{At=3039474,Old=[====[]====],New=[====[do
 local tools=_G.TheBestTools
 local ui=activeMainUI
 local userInput=game:GetService("UserInputService")
 local notices=(function(deps)
 local stopped=false
 local lastPress={}
 local runtime={}
 function runtime.Input(key,processed)
  if stopped or not deps.Enabled() or deps.Focused() or deps.Capturing() then return end
  if type(key)~="string" or key=="Unknown" then return end
  local now=deps.Clock()
  if lastPress[key] and now-lastPress[key]<.08 then return end
  local actions={}
  for action,binding in pairs(deps.Bindings() or {}) do
   if binding==key and binding~="Unknown" and binding~="None" and binding~=""
    and (not processed or (key=="Tab" and action=="aimbot")) then table.insert(actions,action) end
  end
  if #actions==0 then return end
  lastPress[key]=now;table.sort(actions)
  deps.Delay(.04,function()
   if stopped or not deps.Alive() or not deps.Enabled() or deps.Capturing() then return end
   local lines={}
   for _,action in ipairs(actions) do
    local state=deps.State(action)
    local word=state==true and "ON" or (state==false and "OFF" or "Pressed")
    table.insert(lines,deps.Translate(deps.Labels[action] or action)..": "..deps.Translate(word))
   end
   deps.Notify(deps.Translate("Keybinds"),table.concat(lines,"\n"))
  end)
 end
 function runtime.Stop() stopped=true;table.clear(lastPress) end
 return runtime
end
)({Clock=os.clock,Delay=task.delay,
  Enabled=function()return _G.Config.keybindNotificationsEnabled~=false end,
  Focused=function()return userInput:GetFocusedTextBox()~=nil end,
  Capturing=function()return _G.TheBestCapturingKeybind==true or os.clock()-(_G.TheBestKeybindCaptureEndedAt or -math.huge)<.15 end,
  Bindings=function()return _G.Keybinds end,
  Alive=function()return _G.TheBestTools==tools and ui and ui.ScreenGui and ui.ScreenGui.Parent~=nil and not _G.TheBestBuildingUI end,
  Translate=Library.Localization.Translate,
  Labels={esp="ESP",autoParry="Auto Parry",aimbot="Aimbot",speedhack="Speedhack",fly="Fly",standPilot="Stand Pilot",invisibility="Invisibility",classicPilot="Classic Pilot",OpenMenu="Menu",safeZone="Safe Zone",selectTarget="Select Target",tpToTrgt="TP To Target",tpToDioOverHeaven="TP To Dio OH"},
  State=function(action)
   if action=="OpenMenu" then return Library.MenuWantedVisible~=false end
   if type(_G.TheBestGetBindState)=="function" then return _G.TheBestGetBindState(action) end
  end,
  Notify=function(title,text)
   pcall(function()game:GetService("StarterGui"):SetCore("SendNotification",{Title=title,Text=text,Duration=2})end)
   tools.Log("notice",text)
  end,
 })
 table.insert(Library.RuntimeConnections,userInput.InputBegan:Connect(function(input,processed)
  if input.UserInputType==Enum.UserInputType.Keyboard then notices.Input(input.KeyCode.Name,processed) end
 end))
 table.insert(Library.RuntimeConnections,ui.ScreenGui.Destroying:Connect(notices.Stop))
end

]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest shuffle patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyEnvironmentHealthPatch(main)
local function applyKeybindNotificationOptionsPatch(source)
 assert(#source==3050261,"TheBest keybind notification patch: unexpected source size")
 local edits={{At=44683,Old=[====[]====],New=[====[	keybindNotificationActions = {OpenMenu=false},
]====]},
{At=54548,Old=[====[]====],New=[====[do
 local actions=_G.Config.keybindNotificationActions
 actions=type(actions)=="table" and table.clone(actions) or {}
 if actions.OpenMenu==nil then actions.OpenMenu=false end
 _G.Config.keybindNotificationActions=actions
end

]====]},
{At=219737,Old=[====[]====],New=[====[["Keybind Notification Settings"]="Настройки уведомлений биндов",
["Choose which keybinds show notifications."]="Выбери, какие бинды показывают уведомления.",
["Open Menu"]="Открытие и закрытие меню",
]====]},
{At=1066582,Old=[====[]====],New=[====[                local notificationSection=Library:CreateFunctionTab(tabKeybinds,"Keybind Notification Settings")
                Library:CreateStatusLabel(notificationSection,"Choose which keybinds show notifications.")
                local function addNotificationToggle(actionName)
                 local label=(keybindLabels[actionName] or actionName):gsub(" Bind$","")
                 Library:CreateToggle(notificationSection,label,_G.Config.keybindNotificationActions[actionName]~=false,function(value)
                  _G.Config.keybindNotificationActions[actionName]=value==true;SaveConfig()
                 end)
                end
]====]},
{At=1066772,Old=[====[]====],New=[====[                        addNotificationToggle(actionName)
]====]},
{At=1066981,Old=[====[]====],New=[====[                        addNotificationToggle(actionName)
]====]},
{At=3036680,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.31",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.32",BuildText=_G.TheBestTools.Build,
]====]},
{At=3043032,Old=[====[]====],New=[====[    and deps.ActionEnabled(action)
]====]},
{At=3043387,Old=[====[    local state=deps.State(action)
    local word=state==true and "ON" or (state==false and "OFF" or "Pressed")
    table.insert(lines,deps.Translate(deps.Labels[action] or action)..": "..deps.Translate(word))
]====],New=[====[    if deps.ActionEnabled(action) then
     local state=deps.State(action)
     local word=state==true and "ON" or (state==false and "OFF" or "Pressed")
     table.insert(lines,deps.Translate(deps.Labels[action] or action)..": "..deps.Translate(word))
    end
]====]},
{At=3043604,Old=[====[   deps.Notify(deps.Translate("Keybinds"),table.concat(lines,"\n"))
]====],New=[====[   if #lines>0 then deps.Notify(deps.Translate("Keybinds"),table.concat(lines,"\n")) end
]====]},
{At=3043882,Old=[====[]====],New=[====[  ActionEnabled=function(action)return _G.Config.keybindNotificationActions[action]~=false end,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest keybind notification patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyKeybindNotificationOptionsPatch(main)
local function applyCoreHonkPatch(source)
 assert(#source==3051783,"TheBest core honk patch: unexpected source size")
 local edits={{At=3019493,Old=[====[]====],New=[====[	do
		local hit=make("TextButton",{Name="OrbitCoreHitArea",Text="",BackgroundTransparency=1,
			BorderSizePixel=0,Position=UDim2.fromOffset(0,32),Size=UDim2.fromOffset(176,70),
			AutoButtonColor=false,Selectable=false,Active=true,ZIndex=5},core)
		local sound
		connect(hit.Activated,function()
			if stopped then return end
			if not sound then
				local loader=getcustomasset or getsynasset
				if type(loader)~="function" or type(writefile)~="function" then return end
				local ok,asset=pcall(function()
					local file="thebest/freddy-honk-098a50138504.mp3"
					if not (isfile and isfile(file)) then
						ensureConfigFolder()
						writefile(file,decodeBase64("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VlQgSGViAkSJVILEg8amsSahMmfEzaRZl7CFCZRKaGCJ5wQAws+hQ2GV//uSxPaCGMGXDG3hEcrQtF9dx6QIRqMB2ZaBLNks9ivMUT25kCJLYYwLCHGCQ+khYUlhUgZQ8gOeCwieSL8+mORRMFD8ZFVIISpAhViql1KRITxzG2SCRFRYozI6UU5isbaY740mTGsQB8KUUKVABazGlBXIBGEYIcakMkqiKpk0RWJW13HmXKOiCCJ2RRCK4ekoriKmSFoqrFRJWKiSvCQYmEnHhJxQUCkAoFQSBVonHhJx4ScYFGoJGoJAtonJkSrItAUbCQKpISsicmRKsJKgKLUSNVRq5OTIlWRKgkWokapISsiKWRKWRMgkWgSLRJFpGlLIlJkTIBj1Ei0aLSk5ZExZGFA1qJFjSQGFEShxExYKYoBHqBjwk48KNKHETEgVBEGWKooxIJEikSxUGjVFZQREsNJRqioEKkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/7ksT/gxlpnuxOMS3LNjRdyZYZoaqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqggQABJSbkM8BFERILZgbAc9ejQ2zO68TvyaXWeGBAxApUZUWGsNWp6xyFBYnKhiQwN5Y5CgoKWWD0Kyc4XCbKJVJKcJwaQrJpwnCbKJU4kupNhpCRHU1F2G2URCcSXUbc0hIjqai7D2URCcSXUbc0hIjp0ojQHzIqEI0cLoEZ4mFIiGTpRGwfJRUIRo4XQNniYUiIZOlEbB8lFQhGjhdA2eJhSRDJ0ojYPkoqIRo4XgslK1DlgmiIslK1DkoTREWCStQ5KVkkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+5DEnIPYuaSrTA0tyAAANIAAAASqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo="))
					end
					return loader(file)
				end)
				if not ok then return end
				sound=make("Sound",{Name="OrbitCoreHonk",SoundId=asset,Volume=.7,Looped=false},core)
			end
			sound.TimePosition=0
			sound:Play()
		end)
	end
]====]},
{At=3038000,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.32",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.33",BuildText=_G.TheBestTools.Build,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest core honk patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyCoreHonkPatch(main)
local function applyCosmeticCatalogPatch(source)
 assert(#source==3082005,"TheBest cosmetic catalog patch: unexpected source size")
 local edits={{At=262097,Old=[====[					["Misc"] = "\208\160\208\176\208\183\208\189\208\190\208\181",
]====],New=[====[					["Aurora Night"] = "Северное сияние",
                    ["Custom Stands"] = "Кастомные стенды",
                    ["CUSTOM STANDS"] = "КАСТОМНЫЕ СТЕНДЫ",
                    ["Misc"] = "\208\160\208\176\208\183\208\189\208\190\208\181",
]====]},
{At=428823,Old=[====[ local captured=_G.TheBestCapturedSkinInfo and _G.TheBestCapturedSkinInfo[skinName]
 if captured then
]====],New=[====[ local captured=(_G.TheBestCustomStandFiles and _G.TheBestCustomStandFiles[skinName]) or (_G.TheBestCapturedSkinInfo and _G.TheBestCapturedSkinInfo[skinName])
 if captured or standName=="Custom Stands" then
]====]},
{At=429101,Old=[====[  badge.Text="LOCAL MODEL";badge.TextColor3=T.textDim;badge.TextSize=15
]====],New=[====[  Library.Localization.SetText(badge,standName=="Custom Stands" and not captured and "CUSTOM STANDS" or "LOCAL MODEL");badge.TextColor3=T.textDim;badge.TextSize=15
]====]},
{At=836080,Old=[====[]====],New=[====[SKYBOX_PRESETS["Aurora Night"]={SkyboxLf={hash="54b0db86c2405a711d409cfa534db6611d399c94d8997b23e31d3e3adae66471",bytes=227304,url="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/skyboxes/aurora-night/54b0db86c2405a711d409cfa534db6611d399c94d8997b23e31d3e3adae66471.b64"},SkyboxBk={hash="bc0573ff239868271cd006243d114b6f8bd45001e2807438e26d0ad363766619",bytes=224280,url="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/skyboxes/aurora-night/bc0573ff239868271cd006243d114b6f8bd45001e2807438e26d0ad363766619.b64"},SkyboxRt={hash="f0f1bd556b537a6565be38a8a269975de6875d44c88dbab539d0b7a45bf67c66",bytes=225439,url="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/skyboxes/aurora-night/f0f1bd556b537a6565be38a8a269975de6875d44c88dbab539d0b7a45bf67c66.b64"},SkyboxFt={hash="a772da01e9ff0b9167fc96053d85bf67b20afc2b7cb809e95902a39feeb14297",bytes=224958,url="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/skyboxes/aurora-night/a772da01e9ff0b9167fc96053d85bf67b20afc2b7cb809e95902a39feeb14297.b64"},SkyboxUp={hash="45fde7e3dc28f9c6d9e3154704df6c352b5e76752a5fe12243cd5b0ff869132d",bytes=318842,url="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/skyboxes/aurora-night/45fde7e3dc28f9c6d9e3154704df6c352b5e76752a5fe12243cd5b0ff869132d.b64"},SkyboxDn={hash="8c2efae9a16ac4d9f29333c7aaac5e398b9f42e919f6a6931f7028c164d13727",bytes=159473,url="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/skyboxes/aurora-night/8c2efae9a16ac4d9f29333c7aaac5e398b9f42e919f6a6931f7028c164d13727.b64"}}
]====]},
{At=836726,Old=[====[  if not isfile(file) then writefile(file,decodeBase64(record.data)) end
]====],New=[====[  if not isfile(file) then
    local encoded=record.data or game:HttpGet(record.url)
    local decoded=decodeBase64(encoded)
    assert(not record.bytes or #decoded==record.bytes,"Skybox image download is incomplete")
    writefile(file,decoded)
   end
]====]},
{At=839798,Old=[====[			{"Default","Alien Horizon","Cloud Sea","Peach Dawn","Moonlit Clouds","Deep Stars","Milky Way","Silent Cosmos","Violet Orbit","Spiral Galaxy","Amber Nebula","Black Hole","Sunset Clouds HD"},
]====],New=[====[			{"Default","Alien Horizon","Cloud Sea","Peach Dawn","Moonlit Clouds","Deep Stars","Milky Way","Silent Cosmos","Violet Orbit","Spiral Galaxy","Amber Nebula","Black Hole","Sunset Clouds HD","Aurora Night"},
]====]},
{At=2875407,Old=[====[		local standSkinEntries = {}
for _, entry in ipairs(_G.TheBestStandCatalogEntries or {}) do
 local hasSkin=false
]====],New=[====[-- Keep imported cosmetics together without changing their original stand mapping.
local customStandFiles=table.clone(_G.TheBestCapturedSkinInfo or {})
local eclipseFile="captured-eclipse-f29557b10817e577773c3e5bfd7f82fcd87f7bbd995a8fa254a050633351ad78.ssoc"
customStandFiles[eclipseFile]={name="Eclipse",stand="Star Platinum"}
_G.TheBestCustomStandFiles=customStandFiles
local customSkins={"None"}
local seenCustom={}
local standSkinEntries={}
for _,entry in ipairs(_G.TheBestStandCatalogEntries or {}) do
 local regular=table.clone(entry)
 regular.Skins={"None"}
]====]},
{At=2875622,Old=[====[  if type(value)=="string" and value~="" and value~="None" then hasSkin=true;break end
]====],New=[====[  if customStandFiles[value] then
   if not seenCustom[value] then
    seenCustom[value]=true
    table.insert(customSkins,{Name=customStandFiles[value].name,Value=value})
   end
  elseif type(value)=="string" and value~="" and value~="None" then
   table.insert(regular.Skins,skin)
  end
 end
 if #regular.Skins>1 then table.insert(standSkinEntries,regular) end
end
table.insert(customSkins,{Name="Eclipse",Value=eclipseFile})
table.insert(standSkinEntries,{Name="Custom Stands",Skins=customSkins})
do
 local resolve=_G.TheBestResolveCatalogSkin
 local available=_G.TheBestCatalogIsAvailableFile
 local unconfirmed=_G.TheBestCatalogSkinUnconfirmed
 _G.TheBestCatalogIsAvailableFile=function(file)
  return file==eclipseFile or available(file)
 end
 _G.TheBestCatalogSkinUnconfirmed=function(stand,skin)
  if customStandFiles[skin] then return false end
  return unconfirmed(stand,skin)
 end
 _G.TheBestResolveCatalogSkin=function(stand,skin)
  local custom=customStandFiles[skin]
  if custom then stand=custom.stand end
  if skin~=eclipseFile then return resolve(stand,skin) end
  local ok,err=pcall(function()
   if _G.TheBestStandModelDataCache[skin] then return end
   local path="ssoc_skins/"..skin
   local data
   if isfile(path) then data=HttpService:JSONDecode(decodeData(readfile(path))) end
   if type(data)~="table" or not data.Head or not data.UpperTorso then
    local raw=game:HttpGet("https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/models/eclipse/f29557b10817e577773c3e5bfd7f82fcd87f7bbd995a8fa254a050633351ad78.json")
    assert(#raw==285016,"Eclipse download is incomplete")
    data=HttpService:JSONDecode(raw)
    assert(type(data)=="table" and data.Head and data.UpperTorso,"Invalid Eclipse model")
    writefile(path,encodeData(raw))
   end
   _G.TheBestStandModelDataCache[skin]=data
  end)
  if not ok then return nil,tostring(err) end
  return skin
]====]},
{At=2875714,Old=[====[ if hasSkin then table.insert(standSkinEntries,entry) end
]====],New=[====[]====]},
{At=2875882,Old=[====[			print("[DEBUG.2924] st: " .. stand .. " | sk: " .. skin)
]====],New=[====[			local custom=_G.TheBestCustomStandFiles and _G.TheBestCustomStandFiles[skin]
            if custom then stand=custom.stand end
]====]},
{At=3068222,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.33",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.34",BuildText=_G.TheBestTools.Build,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  assert(source:sub(start,start+#edit.Old-1)==edit.Old,"TheBest cosmetic catalog patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+#edit.Old
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyCosmeticCatalogPatch(main)
local function applyRollbackHonkPatch(source)
 assert(#source==3086496,"TheBest rollback honk patch: unexpected source size")
 local edits={{At=262097,Old=[====[					["Aurora Night"] = "Северное сияние",
                    ["Custom Stands"] = "Кастомные стенды",
]====],New=[====[					["Custom Stands"] = "Кастомные стенды",
]====]},
{At=836499,OldBytes=1605,Prefix=[====[SKYBOX_PRESETS["Aurora Night"]={SkyboxLf={hash="54b0db86c2405a71]====],Suffix=[====[a16ac4d9f29333c7aaac5e398b9f42e919f6a6931f7028c164d13727.b64"}}
]====],New=[====[]====]},
{At=838750,Old=[====[  if not isfile(file) then
    local encoded=record.data or game:HttpGet(record.url)
    local decoded=decodeBase64(encoded)
    assert(not record.bytes or #decoded==record.bytes,"Skybox image download is incomplete")
    writefile(file,decoded)
   end
]====],New=[====[  if not isfile(file) then writefile(file,decodeBase64(record.data)) end
]====]},
{At=842002,Old=[====[			{"Default","Alien Horizon","Cloud Sea","Peach Dawn","Moonlit Clouds","Deep Stars","Milky Way","Silent Cosmos","Violet Orbit","Spiral Galaxy","Amber Nebula","Black Hole","Sunset Clouds HD","Aurora Night"},
]====],New=[====[			{"Default","Alien Horizon","Cloud Sea","Peach Dawn","Moonlit Clouds","Deep Stars","Milky Way","Silent Cosmos","Violet Orbit","Spiral Galaxy","Amber Nebula","Black Hole","Sunset Clouds HD"},
]====]},
{At=3024493,Old=[====[					local file="thebest/freddy-honk-098a50138504.mp3"
]====],New=[====[					local file="thebest/freddy-honk-9d7a1e5e579d.mp3"
]====]},
{At=3024618,OldBytes=29367,Prefix=[====[						writefile(file,decodeBase64("SUQzAwAAAAAIQFRZRVIAAAAGAAAAM]====],Suffix=[====[qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo="))
]====],New=[====[						writefile(file,decodeBase64("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qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqN6+iQy+J/TM2fkpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+5LEPoPBUAYAD3gAIAAANIAAAASqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"))
]====]},
{At=3072713,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.34",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.34-r1",BuildText=_G.TheBestTools.Build,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  local oldBytes=edit.OldBytes or #edit.Old
  local previous=source:sub(start,start+oldBytes-1)
  assert(edit.Old and previous==edit.Old or not edit.Old and previous:sub(1,#edit.Prefix)==edit.Prefix and previous:sub(-#edit.Suffix)==edit.Suffix,"TheBest rollback honk patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+oldBytes
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyRollbackHonkPatch(main)
local function applyCapturedHUDPatch(source)
 assert(#source==3067059,"TheBest captured HUD patch: unexpected source size")
 local edits={{At=43510,Old=[====[]====],New=[====[	classicGameHUDEnabled = false,
]====]},
{At=262232,Old=[====[]====],New=[====[                    ["Classic Game HUD"] = "Старый HUD игры",
                    ["Classic HUD is off."] = "Старый HUD выключен.",
                    ["Original captured HUD enabled."] = "Включён оригинальный сохранённый HUD.",
                    ["Classic HUD could not be loaded."] = "Не удалось загрузить старый HUD.",
]====]},
{At=763150,Old=[====[]====],New="\n"..[====[
do
local function createCapturedHUD(deps)
 local root,widgets,heartbeat,changed,hidden,rows=nil,nil,nil,{}, {},{}
 local generation,elapsed,rowElapsed,sourceElapsed=0,0,0,0
 local stopped=false
 local classes={ScreenGui=true,Frame=true,ScrollingFrame=true,ImageLabel=true,TextLabel=true,UITextSizeConstraint=true,UIGradient=true}
 local function enum(value)
  local group,item=tostring(value):match('^Enum%.([^%.]+)%.(.+)$')
  assert(group and Enum[group][item],"Invalid captured HUD enum")
  return Enum[group][item]
 end
 local function unpackValue(value)
  if type(value)~="table" or not value.__t then return value end
  local kind,v=value.__t,value.v
  if kind=="Enum" then return enum(v)
  elseif kind=="Vector2" then return Vector2.new(v[1],v[2])
  elseif kind=="Color3" then return Color3.new(v[1],v[2],v[3])
  elseif kind=="UDim" then return UDim.new(v[1],v[2])
  elseif kind=="UDim2" then return UDim2.new(v[1],v[2],v[3],v[4])
  elseif kind=="Rect" then return Rect.new(v[1],v[2],v[3],v[4])
  elseif kind=="Font" then return Font.new(v.Family,enum(v.Weight),enum(v.Style))
  elseif kind=="NumberSequence" then
   local points={};for _,p in ipairs(v) do table.insert(points,NumberSequenceKeypoint.new(p.Time,p.Value,p.Envelope or 0)) end
   return NumberSequence.new(points)
  elseif kind=="ColorSequence" then
   local points={};for _,p in ipairs(v) do table.insert(points,ColorSequenceKeypoint.new(p.Time,Color3.new(p.Color[1],p.Color[2],p.Color[3]))) end
   return ColorSequence.new(points)
  end
  error("Unsupported captured HUD value: "..tostring(kind))
 end
 local function build(data)
  assert(type(data)=="table" and data.schema==1 and type(data.nodes)=="table" and #data.nodes<=100,"Invalid captured HUD template")
  local objects={}
  local ok,result=pcall(function()
   for _,node in ipairs(data.nodes) do
    assert(classes[node.class] and type(node.id)=="number" and not objects[node.id],"Invalid captured HUD object")
    local object=Instance.new(node.class);objects[node.id]=object;object.Name=node.name
    for property,value in pairs(node.properties or {}) do
     if property~="Parent" and property~="Name" and not (property=="Font" and node.properties.FontFace) then
      local assigned,why=pcall(function()object[property]=unpackValue(value)end)
      if not assigned then error(node.name.."."..property..": "..tostring(why)) end
     end
    end
   end
   for _,node in ipairs(data.nodes) do if node.parent then objects[node.id].Parent=assert(objects[node.parent],"Missing HUD parent") end end
   local gui=assert(objects[data.root]);assert(gui:IsA("ScreenGui"))
   gui.Name="TheBestCapturedClassicHUD";gui.ResetOnSpawn=false;gui.Enabled=true;gui.DisplayOrder=4
   gui:SetAttribute("TheBestCapturedClassicHUD",true)
   local indicators=assert(objects[data.targets.indicators])
   local list=assert(objects[data.targets.playerlist])
   local template=assert(objects[data.targets.template]);template.Visible=false
   local bars=assert(indicators:FindFirstChild("Bars"))
   return {Root=gui,Indicators=indicators,List=list,Template=template,Header=list:FindFirstChild("Indicators"),
    Health=assert(bars:FindFirstChild("Health")),HealthLost=bars:FindFirstChild("HealthLost"),
    Experience=assert(bars:FindFirstChild("Experience")),HealthLabel=bars:FindFirstChild("HealthLabel"),Level=indicators:FindFirstChild("Level"),
    Timer=indicators:FindFirstChild("MultiTimer"),FullWidth=data.fullBarWidth,RowStep=data.rowStep or .085}
  end)
  if not ok then for _,object in pairs(objects) do object:Destroy() end;error(result) end
  return result
 end
 local function restoreNative()
  for object,state in pairs(hidden) do
   state.Connection:Disconnect()
   if object.Parent then object.Visible=state.Visible end
  end
  hidden={}
 end
 local function stop()
  if heartbeat then heartbeat:Disconnect();heartbeat=nil end
  for _,connection in ipairs(changed) do connection:Disconnect() end;changed={}
  restoreNative()
  if root then root:Destroy() end
  root=nil;widgets=nil;rows={}
 end
 local function nativePanels()
  local gui=deps.Gui();local hud=gui and (gui:FindFirstChild("HUD") or gui:FindFirstChild("MainHUD"))
  if not hud then return end
  local main=hud:FindFirstChild("Main")
  local indicators=main and (main:FindFirstChild("Indicators") or main:FindFirstChild("Indicators",true))
  local list=hud:FindFirstChild("Playerlist") or hud:FindFirstChild("PlayerList") or hud:FindFirstChild("Leaderboard",true)
  if indicators and list and indicators:IsA("GuiObject") and list:IsA("GuiObject") then return hud,indicators,list end
 end
 local function hideNative(object)
  if hidden[object] then return end
  local state={Visible=object.Visible,Writing=false};hidden[object]=state
  state.Connection=object:GetPropertyChangedSignal("Visible"):Connect(function()
   if state.Writing then return end
   if root and object.Visible then state.Visible=true;state.Writing=true;object.Visible=false;state.Writing=false end
  end)
  state.Writing=true;object.Visible=false;state.Writing=false
 end
 local function bindNative()
  local hud,indicators,list=nativePanels()
  if not hud then return false end
  for object,state in pairs(hidden) do
   if object~=indicators and object~=list then
    state.Connection:Disconnect();if object.Parent then object.Visible=state.Visible end;hidden[object]=nil
   end
  end
  hideNative(indicators);hideNative(list)
  widgets.Source=hud;widgets.SourceIndicators=indicators
  root.Enabled=not hud:IsA("ScreenGui") or hud.Enabled
  return true
 end
 local function stat(subject,name,fallback)
  local stats=subject:FindFirstChild("PlayerStats")
  local value=stats and stats:FindFirstChild(name)
  return value and value.Value or fallback
 end
 local function setText(label,value)if label and label.Text~=value then label.Text=value end end
 local function setBar(bar,ratio)
  if not bar then return end
  local size=bar.Size;local width=widgets.FullWidth*math.clamp(ratio,0,1)
  if math.abs(size.X.Scale-width)>.000001 or size.X.Offset~=0 then bar.Size=UDim2.new(width,0,size.Y.Scale,size.Y.Offset) end
 end
 local function format(value)
  return math.abs(value-math.floor(value+.5))<.001 and tostring(math.floor(value+.5)) or string.format("%.1f",value)
 end
 local function updateBars()
  local hp,maxHP=deps.Health(deps.Player)
  if type(hp)=="number" and type(maxHP)=="number" and maxHP>0 then
   setBar(widgets.Health,hp/maxHP);setBar(widgets.HealthLost,hp/maxHP)
   setText(widgets.HealthLabel,"H E A L T H - "..format(hp).."/"..format(maxHP))
  end
  local level=tonumber(stat(deps.Player,"Level",1)) or 1
  setText(widgets.Level,tostring(level))
  local xp=tonumber(stat(deps.Player,"Experience",0)) or 0
  local maximum=tonumber(stat(deps.Player,"MaxExperience",level*50)) or level*50
  setBar(widgets.Experience,maximum>0 and xp/maximum or 0)
  if widgets.Timer then
   local timer=widgets.SourceIndicators and widgets.SourceIndicators:FindFirstChild("MultiTimer")
   widgets.Timer.Visible=timer~=nil and timer.Visible
   if timer then setText(widgets.Timer,timer.Text) end
  end
 end
 local playersDirty=true;local players={};local layoutHeight
 local function updateRows()
  if playersDirty then
   players=deps.Players:GetPlayers();table.sort(players,function(a,b)return a.Name:lower()<b.Name:lower()end);playersDirty=false
  end
  local present={};local list=widgets.List;local template=widgets.Template
  local height=list.AbsoluteSize.Y
  if height<=0 then height=math.max(1,deps.ViewportHeight()*list.Size.Y.Scale+list.Size.Y.Offset) end
  local rowSize=template.Size;local rowPosition=template.Position
  local rowHeight=height*rowSize.Y.Scale+rowSize.Y.Offset
  local start=height*rowPosition.Y.Scale+rowPosition.Y.Offset
  local step=height*widgets.RowStep
  if layoutHeight~=height and widgets.Header then
   local header=widgets.Header;local size=header.Size
   local original=widgets.HeaderHeight or size.Y;widgets.HeaderHeight=original
   header.Size=UDim2.new(size.X.Scale,size.X.Offset,0,height*original.Scale+original.Offset)
  end
  layoutHeight=height
  for index,subject in ipairs(players) do
   present[subject]=true
   local record=rows[subject]
   if not record then
    local row=template:Clone();row.Name=subject.Name;row.Visible=true;row.Parent=list
    record={Frame=row,Name=row:FindFirstChild("PlayerName"),Gang=row:FindFirstChild("GangName"),Prestige=row:FindFirstChild("Prestige")};rows[subject]=record
    for _,name in ipairs({"PlayerNameRanked","PlayerRank"}) do local label=row:FindFirstChild(name);if label then label.Visible=false end end
   end
   record.Frame.Size=UDim2.new(rowSize.X.Scale,rowSize.X.Offset,0,rowHeight)
   record.Frame.Position=UDim2.new(rowPosition.X.Scale,rowPosition.X.Offset,0,start+(index-1)*step)
   local config=deps.Config();local localOverride=subject==deps.Player and config.playerListIdentityEnabled
   local name=localOverride and tostring(config.playerListCustomName or "") or ""
   local gang=localOverride and tostring(config.playerListCustomGang or "") or ""
   if name=="" then name=subject.Name end
   if gang=="" then gang=tostring(stat(subject,"Gang","Gang-less")) end
   if gang=="" or gang=="None" then gang="Gang-less" end
   setText(record.Name,name);setText(record.Gang,gang)
   local prestige=tonumber(stat(subject,"Prestige",0)) or 0
   setText(record.Prestige and record.Prestige:FindFirstChild("TextLabel"),({[0]="0","I","II","III"})[prestige] or tostring(prestige))
  end
  for subject,record in pairs(rows) do if not present[subject] then record.Frame:Destroy();rows[subject]=nil end end
  local canvas=math.max(height,start+#players*step+rowHeight)
  list.CanvasSize=UDim2.new(0,0,0,canvas)
 end
 local function enable(value)
  generation+=1;local operation=generation
  if not value then stop();return true end
  if stopped then return false,"HUD controller stopped" end
  if root then return true end
  local ok,result=pcall(function()
   local data=deps.Template()
   if generation~=operation or stopped then return "cancelled" end
   local loaded=build(data)
   if generation~=operation or stopped then loaded.Root:Destroy();return "cancelled" end
   widgets=loaded;root=loaded.Root
   if not nativePanels() then error("Current HUD panels were not found") end
   root.Parent=assert(deps.Gui(),"PlayerGui is not ready")
   bindNative();playersDirty=true;layoutHeight=nil;elapsed=0;rowElapsed=0;sourceElapsed=0
   updateBars();updateRows()
   table.insert(changed,deps.Players.PlayerAdded:Connect(function()playersDirty=true end))
   table.insert(changed,deps.Players.PlayerRemoving:Connect(function()playersDirty=true end))
   heartbeat=deps.Heartbeat:Connect(function(dt)
    if not root then return end
    elapsed+=dt;if elapsed<.25 then return end
    local delta=elapsed;elapsed=0;rowElapsed+=delta;sourceElapsed+=delta
    if sourceElapsed>=1 then sourceElapsed=0;root.Enabled=bindNative() end
    updateBars()
    if rowElapsed>=1 then rowElapsed=0;updateRows() end
   end)
   return true
  end)
  if not ok then stop();return false,tostring(result) end
  if result=="cancelled" then return false,"cancelled" end
  return true
 end
 return {SetEnabled=enable,Cleanup=function()if stopped then return end;generation+=1;stopped=true;stop()end}
end

 if type(_G.TheBestCapturedHUDCleanup)=="function" then pcall(_G.TheBestCapturedHUDCleanup) end
 local template
 local function loadTemplate()
  if template then return template end
  local file="thebest/classic-hud-c9cf4befa6eaf819773be5a3518bb95051105cd4d2919df662838a8b705f14ee.json"
  local function parse(raw)
   assert(type(raw)=="string" and #raw==43049,"Captured HUD download is incomplete")
   local data=game:GetService("HttpService"):JSONDecode(raw)
   assert(data.schema==1 and #data.nodes==38,"Invalid captured HUD data")
   return data
  end
  if type(isfile)=="function" and isfile(file) then local ok,data=pcall(function()return parse(readfile(file))end);if ok then template=data;return data end end
  local raw=game:HttpGet("https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/hud/classic/c9cf4befa6eaf819773be5a3518bb95051105cd4d2919df662838a8b705f14ee.json")
  template=parse(raw)
  if type(writefile)=="function" then pcall(function()ensureConfigFolder();writefile(file,raw)end) end
  return template
 end
 local runtime=createCapturedHUD({
  Gui=function()return game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")end,
  Player=game:GetService("Players").LocalPlayer,Players=game:GetService("Players"),
  Heartbeat=game:GetService("RunService").Heartbeat,Template=loadTemplate,Config=function()return _G.Config end,
  ViewportHeight=function()return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080 end,
  Health=function(player)
   local character=player.Character
   local health=character and character:FindFirstChild("Health")
   if health then local ok,hp,maximum=pcall(function()return health.Value,health.MaxValue end);if ok and type(hp)=="number" and type(maximum)=="number" and maximum>0 then return hp,maximum end end
   if _G.TheBestTools and type(_G.TheBestTools.Health)=="function" then return _G.TheBestTools.Health(player) end
   local hum=character and character:FindFirstChildOfClass("Humanoid");return hum and hum.Health or 0,hum and hum.MaxHealth or 100
  end})
 _G.TheBestCapturedHUDCleanup=runtime.Cleanup
 local control,status
 local function setEnabled(value)
  _G.Config.classicGameHUDEnabled=value==true;SaveConfig()
  task.spawn(function()
   local ok,reason=runtime.SetEnabled(value==true)
   if not ok and reason~="cancelled" then
    _G.Config.classicGameHUDEnabled=false;SaveConfig()
    if control then control.SetValue(false,false) end
    if status then status.SetText("Classic HUD could not be loaded.") end
    warn("[Classic HUD] "..tostring(reason))
   elseif ok and status then status.SetText(value and "Original captured HUD enabled." or "Classic HUD is off.") end
  end)
 end
 control=Library:CreateToggle(visualsSection,"Classic Game HUD",_G.Config.classicGameHUDEnabled==true,setEnabled)
 status=Library:CreateStatusLabel(visualsSection,"Classic HUD is off.")
 if _G.Config.classicGameHUDEnabled==true then task.defer(function()setEnabled(true)end) end
end
]====]},
{At=2933795,Old=[====[						"TheBestPlayerListIdentityCleanup", "TheBestXenonIntegrationCleanup", "TheBestOptimizationCleanup", "TheBestToolsCleanup", "TheBestClockCleanup", "TheBestWaterCleanup",
]====],New=[====[						"TheBestPlayerListIdentityCleanup", "TheBestCapturedHUDCleanup", "TheBestXenonIntegrationCleanup", "TheBestOptimizationCleanup", "TheBestToolsCleanup", "TheBestClockCleanup", "TheBestWaterCleanup",
]====]},
{At=3053273,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.34-r1",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.37",BuildText=_G.TheBestTools.Build,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  local oldBytes=edit.OldBytes or #edit.Old
  local previous=source:sub(start,start+oldBytes-1)
  assert(edit.Old and previous==edit.Old or not edit.Old and previous:sub(1,#edit.Prefix)==edit.Prefix and previous:sub(-#edit.Suffix)==edit.Suffix,"TheBest captured HUD patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+oldBytes
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyCapturedHUDPatch(main)
local function applyHUDActivationFixPatch(source)
 assert(#source==3081728,"TheBest captured HUD patch: unexpected source size")
 local edits={{At=262336,Old=[====[]====],New=[====[                    ["Loading classic HUD..."] = "Загрузка старого HUD...",
]====]},
{At=767603,Old=[====[]====],New=[====[ local nativeCache
]====]},
{At=767736,Old=[====[  if not hud then return end
  local main=hud:FindFirstChild("Main")
]====],New=[====[  if not gui then return end
  if nativeCache and nativeCache[2]:IsDescendantOf(gui) and nativeCache[3]:IsDescendantOf(gui) then return table.unpack(nativeCache) end
  local main=hud and hud:FindFirstChild("Main")
]====]},
{At=767911,Old=[====[  local list=hud:FindFirstChild("Playerlist") or hud:FindFirstChild("PlayerList") or hud:FindFirstChild("Leaderboard",true)
  if indicators and list and indicators:IsA("GuiObject") and list:IsA("GuiObject") then return hud,indicators,list end
]====],New=[====[  local list=hud and (hud:FindFirstChild("Playerlist") or hud:FindFirstChild("PlayerList") or hud:FindFirstChild("Leaderboard",true))
  if indicators and list and indicators:IsA("GuiObject") and list:IsA("GuiObject") then nativeCache={hud,indicators,list};return table.unpack(nativeCache) end
  local function key(name)return name:lower():gsub("[^%w]","")end
  local function hasBars(object)
   local health=object:FindFirstChild("Health",true) or object:FindFirstChild("HealthBar",true)
   local xp=object:FindFirstChild("Experience",true) or object:FindFirstChild("ExperienceBar",true) or object:FindFirstChild("XP",true)
   return health and xp
  end
  -- Scan on enable/respawn only; valid panel references are reused between updates.
  for _,screen in ipairs(gui:GetChildren()) do
   if screen:IsA("ScreenGui") and screen~=root and not screen.Name:lower():find("thebest",1,true) then
    for _,object in ipairs(screen:GetDescendants()) do
     if object:IsA("GuiObject") then
      local name=key(object.Name)
      if not indicators and (name=="indicators" or name=="stats" or name=="healthandexperience" or name=="healthbar") and hasBars(object) then indicators=object;hud=screen end
      if not indicators and name=="bars" and hasBars(object) then indicators=object.Parent;hud=screen end
      if not list and (name=="playerlist" or name=="playerslist" or name=="leaderboard") then list=object end
     end
    end
   end
  end
  if indicators and list and indicators:IsA("GuiObject") and list:IsA("GuiObject") then nativeCache={hud or indicators:FindFirstAncestorOfClass("ScreenGui"),indicators,list};return table.unpack(nativeCache) end
]====]},
{At=774951,OldBytes=877,Prefix=[====[  if template then return template end
  local file="thebest/cla]====],Suffix=[====[call(function()ensureConfigFolder();writefile(file,raw)end) end
]====],New=[=====[  if not template then template=game:GetService("HttpService"):JSONDecode([====[{"schema":1,"root":1,"nodes":[{"name":"HUD","id":1,"class":"ScreenGui","attributes":[],"properties":{"Enabled":true,"SafeAreaCompatibility":{"__t":"Enum","v":"Enum.SafeAreaCompatibility.FullscreenExtension"},"ScreenInsets":{"__t":"Enum","v":"Enum.ScreenInsets.DeviceSafeInsets"},"ZIndexBehavior":{"__t":"Enum","v":"Enum.ZIndexBehavior.Global"},"ResetOnSpawn":true,"IgnoreGuiInset":true,"ClipToDeviceSafeArea":true,"DisplayOrder":0}},{"name":"Playerlist","parent":1,"id":50,"class":"ScrollingFrame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.17900000512599945,0,0.3199999928474426,0]}},"properties":{"LayoutOrder":0,"Active":false,"Visible":true,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":true,"VerticalScrollBarPosition":{"__t":"Enum","v":"Enum.VerticalScrollBarPosition.Right"},"TopImage":"rbxasset://textures/ui/Scroll/scroll-top.png","HorizontalScrollBarInset":{"__t":"Enum","v":"Enum.ScrollBarInset.None"},"AnchorPoint":{"__t":"Vector2","v":[0,0]},"VerticalScrollBarInset":{"__t":"Enum","v":"Enum.ScrollBarInset.None"},"ElasticBehavior":{"__t":"Enum","v":"Enum.ElasticBehavior.WhenScrollable"},"ScrollingDirection":{"__t":"Enum","v":"Enum.ScrollingDirection.XY"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.17900000512599945,0,0.3199999928474426,0]},"ScrollBarImageColor3":{"__t":"Color3","v":[1,1,1]},"MidImage":"rbxasset://textures/ui/Scroll/scroll-middle.png","ScrollBarImageTransparency":0,"ClipsDescendants":true,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"CanvasPosition":{"__t":"Vector2","v":[0,0]},"ScrollBarThickness":5,"AutomaticCanvasSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Rotation":0,"CanvasSize":{"__t":"UDim2","v":[0,0,0.5,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.8059999942779541,0,0.033439937978982925,0]},"ScrollingEnabled":true,"BottomImage":"rbxasset://textures/ui/Scroll/scroll-bottom.png","BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"Indicators","parent":50,"id":51,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,0.15000000596046448,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928446618","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,0.15000000596046448,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[3.9774766946720774e-7,0,-1.4063044062595509e-8,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Prestige","parent":51,"id":52,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.30000001192092896,0,0.4467891454696655,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,0.988235354423523,0.6352941393852234]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.30000001192092896,0,0.4467891454696655,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":17,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"PRESTIGE","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0.2652035653591156,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"UITextSizeConstraint","parent":52,"id":53,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":17,"MinTextSize":1}},{"name":"Players","parent":51,"id":54,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.2871089577674866,0,0.4467891454696655,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[0.8117647767066956,0.9686275124549866,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.2871089577674866,0,0.4467891454696655,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":17,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"PLAYER","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.3000001013278961,0,0.2652035653591156,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"UITextSizeConstraint","parent":54,"id":55,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":17,"MinTextSize":1}},{"name":"Gang","parent":51,"id":56,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.2958586812019348,0,0.4467891454696655,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[0.8392157554626465,0.8235294818878174,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.2958586812019348,0,0.4467891454696655,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":17,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"GANG","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.6999999284744263,0,0.2652035653591156,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"UITextSizeConstraint","parent":56,"id":57,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":17,"MinTextSize":1}},{"name":"Template","parent":50,"id":58,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.75,0,0.05999999865889549,0]},"BackgroundTransparency":1},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.75,0,0.05999999865889549,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.20000000298023224,0,0.125,0]},"Visible":false,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"PlayerNameRanked","parent":58,"id":59,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.38232120871543884,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Inconsolata.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.38232120871543884,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Left"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Code"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.1826787143945694,0,0.11737081408500671,0]},"Visible":false,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"GangName","parent":58,"id":60,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.42500001192092896,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Jura.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.42500001192092896,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":14,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Jura"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.574999988079071,0,0.11737089604139328,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"UITextSizeConstraint","parent":60,"id":61,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":14,"MinTextSize":1}},{"name":"ImageLabel","parent":58,"id":62,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1.0499999523162842,0,1.7999999523162842,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928446618","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1.0499999523162842,0,1.7999999523162842,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,-0.2826291024684906,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Prestige","parent":58,"id":63,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[0.1531263291835785,0,1.3171268701553345,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928443068","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.1531263291835785,0,1.3171268701553345,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[-0.16358837485313416,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"TextLabel","parent":63,"id":64,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":14,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"PlayerRank","parent":58,"id":65,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.1597849577665329,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/GothamSSm.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Heavy"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.1597849577665329,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.GothamBlack"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[-0.0044240341521799564,0,0.11700011789798737,0]},"Visible":false,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"UITextSizeConstraint","parent":65,"id":66,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":16,"MinTextSize":1}},{"name":"PlayerName","parent":58,"id":67,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.514917254447937,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Inconsolata.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.514917254447937,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Code"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.0500827357172966,0,0.11737081408500671,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"UITextSizeConstraint","parent":67,"id":68,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":16,"MinTextSize":1}},{"name":"Main","parent":1,"id":117,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"BackgroundTransparency":1},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"Visible":true,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Indicators","parent":117,"id":1681,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.13300000131130219,0,0.20200000703334808,0]},"BackgroundTransparency":1},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.13300000131130219,0,0.20200000703334808,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"Visible":true,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"ImageLabel","parent":1681,"id":1682,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5927656531","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":-90,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Sparkle","parent":1682,"id":1683,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=669133414","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":false,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Level","parent":1681,"id":1684,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.257188618183136,0,0.2802548110485077,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":false,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":4,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.257188618183136,0,0.2802548110485077,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Left"},"RichText":false,"TextSize":24,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"1","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.5976441502571106,0,0.35668784379959106,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"MultiTimer","parent":1681,"id":1685,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.9649310111999512,0,0.1092032790184021,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[0.7803922295570374,1,0.7568628191947937]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Inconsolata.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.9649310111999512,0,0.1092032790184021,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":60,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"1.5X EXP: 3600","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Code"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[1.5147780179977417,0,0.26417747139930725,0]},"Visible":false,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"TextLabel","parent":1681,"id":1686,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.1645231693983078,0,0.2802548110485077,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":false,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":4,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.1645231693983078,0,0.2802548110485077,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"Lv.","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.433120995759964,0,0.35668784379959106,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Bars","parent":1681,"id":1687,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[2.992000102996826,0,0.2290000021457672,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[2.992000102996826,0,0.2290000021457672,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.3619999587535858,0,0.4008922874927521,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"HealthLost","parent":1687,"id":1688,"class":"ImageLabel","attributes":{"BackgroundTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.6385301947593689,0,0.4759387969970703,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":-1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.6385301947593689,0,0.4759387969970703,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0,0,0]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":0,"Position":{"__t":"UDim2","v":[0.041423212736845016,0,-1.0302601083367335e-7,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,0.20392157137393951,0.20392157137393951]}}},{"name":"Gradient","parent":1688,"id":1689,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=43479241","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":0,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Health","parent":1687,"id":1690,"class":"ImageLabel","attributes":{"BackgroundTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.6385302543640137,0,0.4759387969970703,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.6385302543640137,0,0.4759387969970703,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0,0,0]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":0,"Position":{"__t":"UDim2","v":[0.04142327234148979,0,-1.0302601083367335e-7,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[0,1,0.49803924560546875]}}},{"name":"Gradient","parent":1690,"id":1691,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=43479241","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Experience","parent":1687,"id":1692,"class":"ImageLabel","attributes":{"BackgroundTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.6385301947593689,0,0.3958333134651184,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0,0,0.3958333134651184,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0,0,0]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":0,"Position":{"__t":"UDim2","v":[0.041423212736845016,0,0.47593873739242554,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,0.49803924560546875]}}},{"name":"ProgressSample","parent":1692,"id":1693,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.035999998450279236,0,1,0]},"BackgroundTransparency":0.5},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.035999998450279236,0,1,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":0.5,"Position":{"__t":"UDim2","v":[1,0,0,0]},"Visible":false,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,0.49803924560546875]}}},{"name":"Gradient","parent":1692,"id":1694,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=43479241","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"ImageLabel","parent":1687,"id":1695,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[0.6957212090492249,0,0.9601515531539917,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928935333","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.6957212090492249,0,0.9601515531539917,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,-0.08775780349969864,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Label","parent":1687,"id":1696,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.5218323469161987,0,0,8]},"BackgroundTransparency":1,"TextStrokeTransparency":0.5},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0.5,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.5218323469161987,0,0,8]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":10,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"E X P E R I E N C E","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.13405321538448334,0,0.5217245817184448,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"HealthLabel","parent":1687,"id":1697,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.5218324661254883,0,0,8]},"BackgroundTransparency":1,"TextStrokeTransparency":0.5},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0.5,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.5218324661254883,0,0,8]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":10,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"H E A L T H - 100/100","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.13405320048332214,0,0.10172459483146667,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}}],"targets":{"indicators":1681,"playerlist":50,"template":58},"fullBarWidth":0.6385302543640137,"rowStep":0.085,"source":"Captured original YBA HUD panels"}]====]) end
]=====]},
{At=776943,Old=[====[]====],New=[====[ local request=0
]====]},
{At=776977,Old=[====[  _G.Config.classicGameHUDEnabled=value==true;SaveConfig()
]====],New=[====[  value=value==true;request+=1;local operation=request
  _G.Config.classicGameHUDEnabled=value;pcall(SaveConfig)
  if status then status.SetText(value and "Loading classic HUD..." or "Classic HUD is off.") end
]====]},
{At=777060,Old=[====[   local ok,reason=runtime.SetEnabled(value==true)
]====],New=[====[   local called,ok,reason=pcall(runtime.SetEnabled,value)
   if not called then reason=ok;ok=false end
   if request~=operation then return end
]====]},
{At=777153,Old=[====[    _G.Config.classicGameHUDEnabled=false;SaveConfig()
    if control then control.SetValue(false,false) end
    if status then status.SetText("Classic HUD could not be loaded.") end
]====],New=[====[]====]},
{At=777381,Old=[====[]====],New=[====[    _G.Config.classicGameHUDEnabled=false;pcall(SaveConfig)
    if control then control.SetState(false,false) end
    if status then status.SetText("Classic HUD could not be loaded.");status.Label.Text ..= " "..tostring(reason) end
]====]},
{At=777510,Old=[====[ control=Library:CreateToggle(visualsSection,"Classic Game HUD",_G.Config.classicGameHUDEnabled==true,setEnabled)
]====],New=[====[ local initial=_G.Config.classicGameHUDEnabled==true
 local ready=false
 control=Library:CreateToggle(visualsSection,"Classic Game HUD",initial,function(value)if ready then setEnabled(value)end end)
]====]},
{At=777696,Old=[====[ if _G.Config.classicGameHUDEnabled==true then task.defer(function()setEnabled(true)end) end
]====],New=[====[ ready=true
 if initial then task.defer(function()setEnabled(true)end) end
]====]},
{At=3067945,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.37",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.38",BuildText=_G.TheBestTools.Build,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  local oldBytes=edit.OldBytes or #edit.Old
  local previous=source:sub(start,start+oldBytes-1)
  assert(edit.Old and previous==edit.Old or not edit.Old and previous:sub(1,#edit.Prefix)==edit.Prefix and previous:sub(-#edit.Suffix)==edit.Suffix,"TheBest captured HUD patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+oldBytes
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyHUDActivationFixPatch(main)
local function applySemanticHUDPatch(source)
 assert(#source==3126029,"TheBest captured HUD patch: unexpected source size")
 local edits={{At=767361,Old=[====[   if object.Parent then object.Visible=state.Visible end
]====],New=[====[   if object.Parent then object[state.Property]=state.Visible end
]====]},
{At=767713,Old=[====[]====],New=[====[ local discoveryError="Current HUD panels were not found"
]====]},
{At=768300,Old=[====[]====],New=[====[  if nativeCache then
   if nativeCache[2]:IsDescendantOf(gui) then indicators=nativeCache[2];hud=nativeCache[1] end
   if nativeCache[3]:IsDescendantOf(gui) then list=nativeCache[3] end
  end
]====]},
{At=768459,OldBytes=355,Prefix=[====[  local function key(name)return name:lower():gsub("[^%w]","")en]====],Suffix=[====[ue) or object:FindFirstChild("XP",true)
   return health and xp
]====],New=[====[  local function key(name)return tostring(name):gsub("<[^>]*>",""):lower():gsub("[^%w]","")end
  local function own(object)
   while object and object~=gui do
    if object==root or object.Name:lower():find("thebest",1,true) or object.Name:lower():find("loadingscreen",1,true) then return true end
    object=object.Parent
   end
   return false
]====]},
{At=768820,OldBytes=762,Prefix=[====[  -- Scan on enable/respawn only; valid panel references are reu]====],Suffix=[====[yerslist" or name=="leaderboard") then list=object end
     end
]====],New=[====[  local function common(a,b)
   if not a or not b then return end
   local parents={};while a and a~=gui do parents[a]=true;a=a.Parent end
   while b and b~=gui do if parents[b] then return b end;b=b.Parent end
  end
  local function contains(container,object)return container and object and (container==object or object:IsDescendantOf(container))end
  local function visible(object)
   while object and object~=gui do
    if object:IsA("GuiObject") and not object.Visible or object:IsA("ScreenGui") and not object.Enabled then return false end
    object=object.Parent
   end
   return true
  end
  -- Anonymous React containers are discovered once by content, then cached.
  local healthLabel,xpLabel,playersHeader,namedIndicators,namedList,healthByName,xpByName
  local memberLabels={};local memberNames={}
  for _,player in ipairs(deps.Players:GetPlayers()) do memberNames[key(player.Name)]=true end
  local objects=gui:GetDescendants()
  for _,object in ipairs(objects) do
   if not own(object) and object:IsA("GuiObject") then
    local name=key(object.Name)
    if name=="playerlist" or name=="playerslist" or name=="leaderboard" or name=="playerboard" or name=="scoreboard" then namedList=namedList or object end
    if name=="indicators" or name=="healthandexperience" or name=="stats" then namedIndicators=namedIndicators or object end
    if name=="health" or name=="healthbar" then healthByName=healthByName or object end
    if name=="experience" or name=="experiencebar" then xpByName=xpByName or object end
    if (object:IsA("TextLabel") or object:IsA("TextButton")) and visible(object) then
     local text=key(object.Text)
     if text=="health" or text:match("^health%d") then healthLabel=healthLabel or object end
     if text=="experience" or text:match("^experience%d") then xpLabel=xpLabel or object end
     if text=="players" or text=="prestigeplayergang" then playersHeader=playersHeader or object end
     if memberNames[text] or text=="gangless" then table.insert(memberLabels,object) end
]====]},
{At=769603,Old=[====[  if indicators and list and indicators:IsA("GuiObject") and list:IsA("GuiObject") then nativeCache={hud or indicators:FindFirstAncestorOfClass("ScreenGui"),indicators,list};return table.unpack(nativeCache) end
]====],New=[====[  healthLabel=healthLabel or healthByName;xpLabel=xpLabel or xpByName
  indicators=indicators or common(healthLabel,xpLabel)
  if namedIndicators and contains(namedIndicators,healthLabel) and contains(namedIndicators,xpLabel) then indicators=namedIndicators end
  list=list or namedList
  if not list and playersHeader then
   for _,label in ipairs(memberLabels) do
    local candidate=common(playersHeader,label)
    if candidate and not contains(candidate,healthLabel) and not contains(candidate,xpLabel) then
     if not list or candidate:IsDescendantOf(list) then list=candidate end
    end
   end
   if not list then list=playersHeader.Parent end
  end
  local function panel(object)
   while object and not object:IsA("GuiObject") and not object:IsA("ScreenGui") do object=object.Parent end
   return object
  end
  indicators=panel(indicators);list=panel(list)
  if indicators and list and indicators~=list and not contains(indicators,list) and not contains(list,indicators) then
   hud=indicators:IsA("ScreenGui") and indicators or indicators:FindFirstAncestorOfClass("ScreenGui")
   if hud then nativeCache={hud,indicators,list};return table.unpack(nativeCache) end
  end
  discoveryError="HUD discovery: Health="..tostring(healthLabel~=nil)..", Experience="..tostring(xpLabel~=nil)..", Players="..tostring(playersHeader~=nil)
  if deps.ReportMissing then deps.ReportMissing(gui,objects,discoveryError) end
]====]},
{At=769890,Old=[====[  local state={Visible=object.Visible,Writing=false};hidden[object]=state
  state.Connection=object:GetPropertyChangedSignal("Visible"):Connect(function()
]====],New=[====[  local property=object:IsA("ScreenGui") and "Enabled" or "Visible"
  local state={Property=property,Visible=object[property],Writing=false};hidden[object]=state
  state.Connection=object:GetPropertyChangedSignal(property):Connect(function()
]====]},
{At=770081,Old=[====[   if root and object.Visible then state.Visible=true;state.Writing=true;object.Visible=false;state.Writing=false end
]====],New=[====[   if root and object[property] then state.Visible=true;state.Writing=true;object[property]=false;state.Writing=false end
]====]},
{At=770206,Old=[====[  state.Writing=true;object.Visible=false;state.Writing=false
]====],New=[====[  state.Writing=true;object[property]=false;state.Writing=false
]====]},
{At=770466,Old=[====[    state.Connection:Disconnect();if object.Parent then object.Visible=state.Visible end;hidden[object]=nil
]====],New=[====[    state.Connection:Disconnect();if object.Parent then object[state.Property]=state.Visible end;hidden[object]=nil
]====]},
{At=770686,Old=[====[  root.Enabled=not hud:IsA("ScreenGui") or hud.Enabled
]====],New=[====[  local state=hidden[hud]
  root.Enabled=not hud:IsA("ScreenGui") or state and state.Visible or not state and hud.Enabled
]====]},
{At=775398,Old=[====[   if not nativePanels() then error("Current HUD panels were not found") end
]====],New=[====[   if not nativePanels() then error(discoveryError) end
]====]},
{At=820222,Old=[====[]====],New=[====[  ReportMissing=function(gui,objects,reason)
   if type(writefile)~="function" then return end
   pcall(function()
    local report={reason=reason,build="v016.39",nodes={}}
    for _,object in ipairs(objects) do
     if object:IsA("GuiObject") or object:IsA("ScreenGui") then
      local node={path=object:GetFullName(),class=object.ClassName}
      if object:IsA("GuiObject") then node.x=object.AbsolutePosition.X;node.y=object.AbsolutePosition.Y;node.w=object.AbsoluteSize.X;node.h=object.AbsoluteSize.Y;node.visible=object.Visible end
      table.insert(report.nodes,node)
     end
    end
    ensureConfigFolder();writefile("thebest/classic-hud-diagnostic.json",game:GetService("HttpService"):JSONEncode(report))
   end)
  end,
]====]},
{At=3112246,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.38",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.39",BuildText=_G.TheBestTools.Build,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  local oldBytes=edit.OldBytes or #edit.Old
  local previous=source:sub(start,start+oldBytes-1)
  assert(edit.Old and previous==edit.Old or not edit.Old and previous:sub(1,#edit.Prefix)==edit.Prefix and previous:sub(-#edit.Suffix)==edit.Suffix,"TheBest captured HUD patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+oldBytes
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applySemanticHUDPatch(main)
local function applyCompleteHUDPatch(source)
 assert(#source==3129618,"TheBest captured HUD patch: unexpected source size")
 local edits={{At=763871,Old=[====[ local classes={ScreenGui=true,Frame=true,ScrollingFrame=true,ImageLabel=true,TextLabel=true,UITextSizeConstraint=true,UIGradient=true}
]====],New=[====[ local classes={ScreenGui=true,Frame=true,ScrollingFrame=true,ImageLabel=true,TextLabel=true,UITextSizeConstraint=true,UIGradient=true,UIAspectRatioConstraint=true}
]====]},
{At=766678,Old=[====[]====],New=[====[   local blood=Instance.new("Frame");blood.Name="ClassicBlood";blood.BackgroundTransparency=1;blood.Position=UDim2.fromScale(.058,.255);blood.Size=UDim2.fromScale(.23,.03);blood.Visible=false;blood.Parent=gui
   local bloodText=Instance.new("TextLabel");bloodText.Name="Label";bloodText.Text="BLOOD";bloodText.Font=Enum.Font.Arcade;bloodText.TextSize=14;bloodText.TextColor3=Color3.new(0,0,0);bloodText.TextXAlignment=Enum.TextXAlignment.Left;bloodText.BackgroundTransparency=1;bloodText.Position=UDim2.new(0,2,0,-20);bloodText.Size=UDim2.new(1,0,0,20);bloodText.Parent=blood
   local track=Instance.new("Frame");track.Name="Track";track.BackgroundColor3=Color3.fromRGB(40,40,40);track.BorderSizePixel=2;track.BorderColor3=Color3.fromRGB(105,105,105);track.Size=UDim2.new(1,0,0,12);track.Parent=blood
   local fill=Instance.new("Frame");fill.Name="Fill";fill.BackgroundColor3=Color3.fromRGB(218,32,10);fill.BorderSizePixel=0;fill.Position=UDim2.fromOffset(3,3);fill.Size=UDim2.new(1,-6,1,-6);fill.Parent=track
   local money=data.targets.money and objects[data.targets.money]
]====]},
{At=767031,Old=[====[    Timer=indicators:FindFirstChild("MultiTimer"),FullWidth=data.fullBarWidth,RowStep=data.rowStep or .085}
]====],New=[====[    Timer=indicators:FindFirstChild("MultiTimer"),FullWidth=data.fullBarWidth,RowStep=data.rowStep or .085,
    RowReference=data.rowReferenceHeight or {0,0,.5,0},Gold=Color3.new(table.unpack(data.prestigeGold or {.937255,.721569,.219608})),
    Money=money and money:FindFirstChild("Money"),Blood=blood,BloodFill=fill}
]====]},
{At=767721,Old=[====[]====],New=[====[ local nativeExtras,nativeBloodFill,nativeMoney={}
 local function viewport()
  if deps.ViewportSize then return deps.ViewportSize() end
  local height=deps.ViewportHeight();return Vector2.new(height*16/9,height)
 end
 local function bounds(object)
  if deps.Bounds then return deps.Bounds(object) end
  return object.AbsolutePosition,object.AbsoluteSize
 end
 local function expandPanel(object,side)
  local view=viewport();local current=object;local selected=object
  while current and current:IsA("GuiObject") do
   local p,s=bounds(current)
   if s.X<=0 or s.Y<=0 then
    local minimum,maximum
    for _,child in ipairs(current:GetDescendants()) do
     if child:IsA("GuiObject") and child.AbsoluteSize.X>0 and child.AbsoluteSize.Y>0 then
      local a,b=child.AbsolutePosition,child.AbsolutePosition+child.AbsoluteSize
      minimum=minimum and Vector2.new(math.min(minimum.X,a.X),math.min(minimum.Y,a.Y)) or a
      maximum=maximum and Vector2.new(math.max(maximum.X,b.X),math.max(maximum.Y,b.Y)) or b
     end
    end
    if minimum then p,s=minimum,maximum-minimum end
   end
   local fits=s.X>0 and s.Y>0 and s.X<=view.X*(side=="left" and .55 or .42) and s.Y<=view.Y*(side=="left" and .58 or .95)
   local placed=side=="left" and p.X<view.X*.1 and p.Y<view.Y*.58 or side=="right" and p.X>view.X*.5
   if fits and placed then selected=current elseif current~=object and s.X>0 and s.Y>0 then break end
   current=current.Parent
  end
  return selected
 end
]====]},
{At=767941,Old=[====[  if nativeCache and nativeCache[2]:IsDescendantOf(gui) and nativeCache[3]:IsDescendantOf(gui) then return table.unpack(nativeCache) end
]====],New=[====[  local extrasValid=true;for object in pairs(nativeExtras) do if not object:IsDescendantOf(gui) then extrasValid=false;break end end
  if nativeCache and extrasValid and nativeCache[2]:IsDescendantOf(gui) and nativeCache[3]:IsDescendantOf(gui) then return table.unpack(nativeCache) end
]====]},
{At=768559,Old=[====[  if indicators and list and indicators:IsA("GuiObject") and list:IsA("GuiObject") then nativeCache={hud,indicators,list};return table.unpack(nativeCache) end
]====],New=[====[]====]},
{At=769745,Old=[====[  local healthLabel,xpLabel,playersHeader,namedIndicators,namedList,healthByName,xpByName
]====],New=[====[  local healthLabel,xpLabel,playersHeader,namedIndicators,namedList,healthByName,xpByName,bloodLabel
  nativeExtras={};nativeBloodFill=nil;nativeMoney=nil
]====]},
{At=770592,Old=[====[]====],New=[====[    if name=="gems" or name=="gemdisplay" or name=="diamonds" or name=="currencydisplay" or name=="currencies" or name=="dropmoney" then nativeExtras[expandPanel(object,"left")]=true end
    if name=="bloodbar" or name=="bloodframe" then bloodLabel=bloodLabel or object end
]====]},
{At=770897,Old=[====[]====],New=[====[     if text=="blood" or text:match("^blood%d") then bloodLabel=object end
]====]},
{At=771087,Old=[====[]====],New=[====[     local number=object.Text:gsub("[,%s]","")
     if number:match("^%$%d+") then nativeMoney=object;nativeExtras[expandPanel(object,"left")]=true
     elseif number:match("^%d+$") then
      local parent=object.Parent;local p,s=bounds(object);local view=viewport()
      if parent and p.X<view.X*.08 and p.Y>view.Y*.15 and p.Y<view.Y*.6 and s.X<view.X*.25 and (parent:FindFirstChildWhichIsA("ImageLabel",true) or parent:FindFirstChildWhichIsA("ImageButton",true)) then nativeExtras[expandPanel(parent,"left")]=true end
     end
]====]},
{At=771976,Old=[====[]====],New=[====[  if bloodLabel then
   local blood=expandPanel(bloodLabel.Parent,"left");nativeExtras[blood]=true
   local bestScore=-math.huge;local origin=bounds(bloodLabel)
   for _,object in ipairs(blood:GetDescendants()) do
    if object:IsA("GuiObject") then
     local color=object.BackgroundColor3;local name=key(object.Name)
     if object:IsA("ImageLabel") then color=object.ImageColor3 end
     local red=color.R>.5 and color.G<.35 and color.B<.35 and (object:IsA("ImageLabel") or object.BackgroundTransparency<1)
     if name=="fill" or red then
      local position=bounds(object);local score=(red and 100000 or 0)+(name=="fill" and 1000 or 0)-(position-origin).Magnitude
      if score>bestScore then nativeBloodFill=object;bestScore=score end
     end
    end
   end
  end
  if indicators then indicators=expandPanel(indicators,"left") end
  if list then list=expandPanel(list,"right") end
  for object in pairs(nativeExtras) do if object==hud or contains(object,list) then nativeExtras[object]=nil end end
]====]},
{At=773222,Old=[====[   if object~=indicators and object~=list then
]====],New=[====[   if object~=indicators and object~=list and not nativeExtras[object] then
]====]},
{At=773440,Old=[====[]====],New=[====[  for object in pairs(nativeExtras) do hideNative(object) end
]====]},
{At=774943,Old=[====[]====],New=[====[  if widgets.Money then
   local amount=stat(deps.Player,"Money",nil) or stat(deps.Player,"Cash",nil)
   if amount~=nil then setText(widgets.Money,tostring(amount))
   elseif nativeMoney then setText(widgets.Money,nativeMoney.Text:gsub("[^%d]","")) end
  end
  local blood,maximumBlood
  for _,container in ipairs({deps.Player.Character or false,deps.Player:FindFirstChild("PlayerStats") or false}) do
   local value=container and container:FindFirstChild("Blood")
   if value then local ok,v,m=pcall(function()return value.Value,value.MaxValue end);if ok and type(v)=="number" and type(m)=="number" and m>0 then blood,maximumBlood=v,m;break end end
  end
  local ratio=blood and blood/maximumBlood or nativeBloodFill and nativeBloodFill.Size.X.Scale
  widgets.Blood.Visible=ratio~=nil
  if ratio then widgets.BloodFill.Size=UDim2.new(math.clamp(ratio,0,1),-6,1,-6) end
]====]},
{At=775711,Old=[====[  local rowHeight=height*rowSize.Y.Scale+rowSize.Y.Offset
  local start=height*rowPosition.Y.Scale+rowPosition.Y.Offset
  local step=height*widgets.RowStep
]====],New=[====[  local reference=math.max(height,deps.ViewportHeight()*widgets.RowReference[3]+widgets.RowReference[4])
  local rowHeight=reference*rowSize.Y.Scale+rowSize.Y.Offset
  local start=reference*rowPosition.Y.Scale+rowPosition.Y.Offset
  local step=reference*widgets.RowStep
]====]},
{At=776050,Old=[====[   header.Size=UDim2.new(size.X.Scale,size.X.Offset,0,height*original.Scale+original.Offset)
]====],New=[====[   header.Size=UDim2.new(size.X.Scale,size.X.Offset,0,reference*original.Scale+original.Offset)
]====]},
{At=777418,Old=[====[   setText(record.Prestige and record.Prestige:FindFirstChild("TextLabel"),({[0]="0","I","II","III"})[prestige] or tostring(prestige))
]====],New=[====[   local prestigeText=record.Prestige and record.Prestige:FindFirstChild("TextLabel")
   setText(prestigeText,({[0]="0","I","II","III"})[prestige] or tostring(prestige))
   local color=prestige==3 and widgets.Gold or template.PlayerName.TextColor3
   if record.Name then record.Name.TextColor3=color end
   if prestigeText then prestigeText.TextColor3=color end
]====]},
{At=779468,OldBytes=43141,Prefix=[====[  if not template then template=game:GetService("HttpService"):J]====],Suffix=[=====[":0.085,"source":"Captured original YBA HUD panels"}]====]) end
]=====],New=[=====[  if not template then template=game:GetService("HttpService"):JSONDecode([====[{"schema":1,"root":1,"nodes":[{"name":"HUD","id":1,"class":"ScreenGui","attributes":[],"properties":{"Enabled":true,"SafeAreaCompatibility":{"__t":"Enum","v":"Enum.SafeAreaCompatibility.FullscreenExtension"},"ScreenInsets":{"__t":"Enum","v":"Enum.ScreenInsets.DeviceSafeInsets"},"ZIndexBehavior":{"__t":"Enum","v":"Enum.ZIndexBehavior.Global"},"ResetOnSpawn":true,"IgnoreGuiInset":true,"ClipToDeviceSafeArea":true,"DisplayOrder":0}},{"name":"Playerlist","parent":1,"id":50,"class":"ScrollingFrame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.17900000512599945,0,0.3199999928474426,0]}},"properties":{"LayoutOrder":0,"Active":false,"Visible":true,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":true,"VerticalScrollBarPosition":{"__t":"Enum","v":"Enum.VerticalScrollBarPosition.Right"},"TopImage":"rbxasset://textures/ui/Scroll/scroll-top.png","HorizontalScrollBarInset":{"__t":"Enum","v":"Enum.ScrollBarInset.None"},"AnchorPoint":{"__t":"Vector2","v":[0,0]},"VerticalScrollBarInset":{"__t":"Enum","v":"Enum.ScrollBarInset.None"},"ElasticBehavior":{"__t":"Enum","v":"Enum.ElasticBehavior.WhenScrollable"},"ScrollingDirection":{"__t":"Enum","v":"Enum.ScrollingDirection.XY"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.17900000512599945,0,0.3199999928474426,0]},"ScrollBarImageColor3":{"__t":"Color3","v":[1,1,1]},"MidImage":"rbxasset://textures/ui/Scroll/scroll-middle.png","ScrollBarImageTransparency":0,"ClipsDescendants":true,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"CanvasPosition":{"__t":"Vector2","v":[0,0]},"ScrollBarThickness":5,"AutomaticCanvasSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Rotation":0,"CanvasSize":{"__t":"UDim2","v":[0,0,0.5,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.8059999942779541,0,0.033439937978982925,0]},"ScrollingEnabled":true,"BottomImage":"rbxasset://textures/ui/Scroll/scroll-bottom.png","BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"Indicators","parent":50,"id":51,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,0.15000000596046448,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928446618","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,0.15000000596046448,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[3.9774766946720774e-7,0,-1.4063044062595509e-8,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Prestige","parent":51,"id":52,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.30000001192092896,0,0.4467891454696655,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,0.988235354423523,0.6352941393852234]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.30000001192092896,0,0.4467891454696655,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":17,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"PRESTIGE","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0.2652035653591156,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"UITextSizeConstraint","parent":52,"id":53,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":17,"MinTextSize":1}},{"name":"Players","parent":51,"id":54,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.2871089577674866,0,0.4467891454696655,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[0.8117647767066956,0.9686275124549866,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.2871089577674866,0,0.4467891454696655,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":17,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"PLAYER","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.3000001013278961,0,0.2652035653591156,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"UITextSizeConstraint","parent":54,"id":55,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":17,"MinTextSize":1}},{"name":"Gang","parent":51,"id":56,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.2958586812019348,0,0.4467891454696655,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[0.8392157554626465,0.8235294818878174,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.2958586812019348,0,0.4467891454696655,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":17,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"GANG","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.6999999284744263,0,0.2652035653591156,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"UITextSizeConstraint","parent":56,"id":57,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":17,"MinTextSize":1}},{"name":"Template","parent":50,"id":58,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.75,0,0.05999999865889549,0]},"BackgroundTransparency":1},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.75,0,0.05999999865889549,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.20000000298023224,0,0.125,0]},"Visible":false,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"PlayerNameRanked","parent":58,"id":59,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.38232120871543884,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Inconsolata.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.38232120871543884,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Left"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Code"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.1826787143945694,0,0.11737081408500671,0]},"Visible":false,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"GangName","parent":58,"id":60,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.42500001192092896,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Jura.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.42500001192092896,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":14,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Jura"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.574999988079071,0,0.11737089604139328,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"UITextSizeConstraint","parent":60,"id":61,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":14,"MinTextSize":1}},{"name":"ImageLabel","parent":58,"id":62,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1.0499999523162842,0,1.7999999523162842,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928446618","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1.0499999523162842,0,1.7999999523162842,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,-0.2826291024684906,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Prestige","parent":58,"id":63,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[0.1531263291835785,0,1.3171268701553345,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928443068","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.1531263291835785,0,1.3171268701553345,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[-0.16358837485313416,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"TextLabel","parent":63,"id":64,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":14,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"PlayerRank","parent":58,"id":65,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.1597849577665329,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/GothamSSm.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Heavy"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.1597849577665329,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.GothamBlack"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[-0.0044240341521799564,0,0.11700011789798737,0]},"Visible":false,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"UITextSizeConstraint","parent":65,"id":66,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":16,"MinTextSize":1}},{"name":"PlayerName","parent":58,"id":67,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.514917254447937,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Inconsolata.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":0,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.514917254447937,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Center"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Code"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.0500827357172966,0,0.11737081408500671,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"UITextSizeConstraint","parent":67,"id":68,"class":"UITextSizeConstraint","attributes":[],"properties":{"MaxTextSize":16,"MinTextSize":1}},{"name":"Main","parent":1,"id":117,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"BackgroundTransparency":1},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"Visible":true,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Indicators","parent":117,"id":1681,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.13300000131130219,0,0.20200000703334808,0]},"BackgroundTransparency":1},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.13300000131130219,0,0.20200000703334808,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"Visible":true,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"ImageLabel","parent":1681,"id":1682,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5927656531","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":-90,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Sparkle","parent":1682,"id":1683,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=669133414","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":false,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Level","parent":1681,"id":1684,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.257188618183136,0,0.2802548110485077,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":false,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":4,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.257188618183136,0,0.2802548110485077,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Left"},"RichText":false,"TextSize":24,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"1","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.5976441502571106,0,0.35668784379959106,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"MultiTimer","parent":1681,"id":1685,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.9649310111999512,0,0.1092032790184021,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[0.7803922295570374,1,0.7568628191947937]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/Inconsolata.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.9649310111999512,0,0.1092032790184021,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":60,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"1.5X EXP: 3600","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Code"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[1.5147780179977417,0,0.26417747139930725,0]},"Visible":false,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"TextLabel","parent":1681,"id":1686,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.1645231693983078,0,0.2802548110485077,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":false,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":4,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.1645231693983078,0,0.2802548110485077,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":16,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"Lv.","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.433120995759964,0,0.35668784379959106,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Bars","parent":1681,"id":1687,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[2.992000102996826,0,0.2290000021457672,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[2.992000102996826,0,0.2290000021457672,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.3619999587535858,0,0.4008922874927521,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"HealthLost","parent":1687,"id":1688,"class":"ImageLabel","attributes":{"BackgroundTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.6385301947593689,0,0.4759387969970703,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":-1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.6385301947593689,0,0.4759387969970703,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0,0,0]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":0,"Position":{"__t":"UDim2","v":[0.041423212736845016,0,-1.0302601083367335e-7,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,0.20392157137393951,0.20392157137393951]}}},{"name":"Gradient","parent":1688,"id":1689,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=43479241","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":0,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Health","parent":1687,"id":1690,"class":"ImageLabel","attributes":{"BackgroundTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.6385302543640137,0,0.4759387969970703,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.6385302543640137,0,0.4759387969970703,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0,0,0]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":0,"Position":{"__t":"UDim2","v":[0.04142327234148979,0,-1.0302601083367335e-7,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[0,1,0.49803924560546875]}}},{"name":"Gradient","parent":1690,"id":1691,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=43479241","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Experience","parent":1687,"id":1692,"class":"ImageLabel","attributes":{"BackgroundTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.6385301947593689,0,0.3958333134651184,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0,0,0.3958333134651184,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0,0,0]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":0,"Position":{"__t":"UDim2","v":[0.041423212736845016,0,0.47593873739242554,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,0.49803924560546875]}}},{"name":"ProgressSample","parent":1692,"id":1693,"class":"Frame","attributes":{"OriginalSize":{"__t":"UDim2","v":[0.035999998450279236,0,1,0]},"BackgroundTransparency":0.5},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.035999998450279236,0,1,0]},"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Rotation":0,"Style":{"__t":"Enum","v":"Enum.FrameStyle.Custom"},"BackgroundTransparency":0.5,"Position":{"__t":"UDim2","v":[1,0,0,0]},"Visible":false,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,0.49803924560546875]}}},{"name":"Gradient","parent":1692,"id":1694,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"http://www.roblox.com/asset/?id=43479241","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1,0,1,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,0,0]},"SliceScale":1,"Active":false,"BorderSizePixel":0,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"ImageLabel","parent":1687,"id":1695,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[0.6957212090492249,0,0.9601515531539917,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"Image":"rbxassetid://5928935333","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":2,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.6957212090492249,0,0.9601515531539917,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Stretch"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0,0,-0.08775780349969864,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Label","parent":1687,"id":1696,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.5218323469161987,0,0,8]},"BackgroundTransparency":1,"TextStrokeTransparency":0.5},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0.5,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.5218323469161987,0,0,8]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":10,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"E X P E R I E N C E","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.13405321538448334,0,0.5217245817184448,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"HealthLabel","parent":1687,"id":1697,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[0.5218324661254883,0,0,8]},"BackgroundTransparency":1,"TextStrokeTransparency":0.5},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/PressStart2P.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0.5,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.5218324661254883,0,0,8]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Right"},"RichText":false,"TextSize":10,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"H E A L T H - 100/100","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Arcade"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.13405320048332214,0,0.10172459483146667,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":false,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"DropMoney","parent":117,"id":1674,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[0.02814599871635437,0,0.060219358652830124,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"ImageTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0.5]},"Image":"rbxassetid://10469475410","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.02814599871635437,0,0.060219358652830124,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.019999999552965164,0,0.5,0]},"SliceScale":1,"Active":false,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[0,0,0]}}},{"name":"Money","parent":1674,"id":1675,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[1.5233380794525146,0,0.7142857313156128,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/ComicNeueAngular.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[1.5233380794525146,0,0.7142857313156128,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Left"},"RichText":false,"TextSize":14,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"0","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Cartoon"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[1.2000000476837158,0,0.14300000667572021,0]},"Visible":true,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"Template","parent":1675,"id":1676,"class":"TextLabel","attributes":{"TextTransparency":0,"OriginalSize":{"__t":"UDim2","v":[6.354641437530518,0,1,0]},"BackgroundTransparency":1,"TextStrokeTransparency":0},"properties":{"LayoutOrder":0,"TextWrapped":true,"LineHeight":1,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":false,"TextColor3":{"__t":"Color3","v":[1,1,1]},"FontFace":{"__t":"Font","v":{"Family":"rbxasset://fonts/families/ComicNeueAngular.json","Style":"Enum.FontStyle.Normal","Weight":"Enum.FontWeight.Regular"}},"TextStrokeTransparency":0,"AnchorPoint":{"__t":"Vector2","v":[0,0]},"BorderSizePixel":1,"Active":false,"TextTruncate":{"__t":"Enum","v":"Enum.TextTruncate.None"},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":1,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[6.354641437530518,0,1,0]},"TextXAlignment":{"__t":"Enum","v":"Enum.TextXAlignment.Left"},"RichText":false,"TextSize":14,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"Text":"+100","TextStrokeColor3":{"__t":"Color3","v":[0,0,0]},"TextTransparency":0,"Rotation":0,"Font":{"__t":"Enum","v":"Enum.Font.Cartoon"},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[1.1999996900558472,0,0,0]},"Visible":false,"TextYAlignment":{"__t":"Enum","v":"Enum.TextYAlignment.Center"},"TextScaled":true,"BackgroundColor3":{"__t":"Color3","v":[1,1,1]}}},{"name":"UIAspectRatioConstraint","parent":1674,"id":1679,"class":"UIAspectRatioConstraint","attributes":[],"properties":{"AspectRatio":1,"DominantAxis":{"__t":"Enum","v":"Enum.DominantAxis.Width"},"AspectType":{"__t":"Enum","v":"Enum.AspectType.FitWithinMaxSize"}}},{"name":"ButtonIcon","parent":1674,"id":1680,"class":"ImageLabel","attributes":{"BackgroundTransparency":1,"OriginalSize":{"__t":"UDim2","v":[0.75,0,0.75,0]},"ImageTransparency":0},"properties":{"LayoutOrder":0,"BorderMode":{"__t":"Enum","v":"Enum.BorderMode.Outline"},"Selectable":true,"AnchorPoint":{"__t":"Vector2","v":[0.5,0.5]},"Image":"rbxassetid://10469473291","TileSize":{"__t":"UDim2","v":[1,0,1,0]},"ImageRectSize":{"__t":"Vector2","v":[0,0]},"SizeConstraint":{"__t":"Enum","v":"Enum.SizeConstraint.RelativeXY"},"ZIndex":3,"AutomaticSize":{"__t":"Enum","v":"Enum.AutomaticSize.None"},"Size":{"__t":"UDim2","v":[0.75,0,0.75,0]},"ResampleMode":{"__t":"Enum","v":"Enum.ResamplerMode.Default"},"ScaleType":{"__t":"Enum","v":"Enum.ScaleType.Fit"},"Visible":true,"ClipsDescendants":false,"BorderColor3":{"__t":"Color3","v":[0.10588236153125763,0.16470588743686676,0.20784315466880798]},"SliceCenter":{"__t":"Rect","v":[0,0,0,0]},"ImageColor3":{"__t":"Color3","v":[1,1,1]},"ImageTransparency":0,"Rotation":0,"ImageRectOffset":{"__t":"Vector2","v":[0,0]},"BackgroundTransparency":1,"Position":{"__t":"UDim2","v":[0.5,0,0.5,0]},"SliceScale":1,"Active":true,"BorderSizePixel":1,"BackgroundColor3":{"__t":"Color3","v":[0.9725490808486938,0.9725490808486938,0.9725490808486938]}}}],"targets":{"indicators":1681,"playerlist":50,"template":58,"money":1674},"fullBarWidth":0.6385302543640137,"rowStep":0.085,"source":"Captured original YBA HUD panels","rowReferenceHeight":[0,0,0.5,0],"prestigeGold":[0.9372549653053284,0.7215686440467834,0.2196078598499298]}]====]) end
]=====]},
{At=823079,Old=[====[]====],New=[====[  ViewportSize=function()return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)end,
]====]},
{At=823194,Old=[====[    local report={reason=reason,build="v016.39",nodes={}}
]====],New=[====[    local report={reason=reason,build="v016.40",nodes={}}
]====]},
{At=3115835,Old=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.39",BuildText=_G.TheBestTools.Build,
]====],New=[====[		Animation=animationButton,AnimationMenu=animationMenu,LayoutButton=layoutButton,FooterKey=footerKey,BuildLabel=buildLabel,BuildShort="v016.40",BuildText=_G.TheBestTools.Build,
]====]}}
 local pieces,cursor={},1
 for _,edit in ipairs(edits) do
  local start=edit.At+1
  local oldBytes=edit.OldBytes or #edit.Old
  local previous=source:sub(start,start+oldBytes-1)
  assert(edit.Old and previous==edit.Old or not edit.Old and previous:sub(1,#edit.Prefix)==edit.Prefix and previous:sub(-#edit.Suffix)==edit.Suffix,"TheBest captured HUD patch: source mismatch")
  table.insert(pieces,source:sub(cursor,edit.At));table.insert(pieces,edit.New)
  cursor=start+oldBytes
 end
 table.insert(pieces,source:sub(cursor))
 return table.concat(pieces)
end
main=applyCompleteHUDPatch(main)

if type(_G.TheBestGameUICleanup)=="function" then pcall(_G.TheBestGameUICleanup);_G.TheBestGameUICleanup=nil;_G.TheBestGameUIController=nil;_G.TheBestPlayerListIdentityCleanup=nil end
assert(#main<32*1024*1024,"TheBest: main source exceeds execution limit")
startTheBest(main)
