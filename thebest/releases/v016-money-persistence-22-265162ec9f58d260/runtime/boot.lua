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
assert(#main<32*1024*1024,"TheBest: main source exceeds execution limit")
startTheBest(main)
