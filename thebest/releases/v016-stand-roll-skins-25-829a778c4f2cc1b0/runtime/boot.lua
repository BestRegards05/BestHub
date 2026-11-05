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
assert(#main<32*1024*1024,"TheBest: main source exceeds execution limit")
startTheBest(main)
