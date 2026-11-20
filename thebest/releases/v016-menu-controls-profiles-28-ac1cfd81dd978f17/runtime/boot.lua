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
assert(#main<32*1024*1024,"TheBest: main source exceeds execution limit")
startTheBest(main)
