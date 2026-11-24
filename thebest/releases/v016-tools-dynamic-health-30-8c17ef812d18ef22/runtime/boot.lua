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
assert(#main<32*1024*1024,"TheBest: main source exceeds execution limit")
startTheBest(main)
