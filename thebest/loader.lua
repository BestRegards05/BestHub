-- TheBest: public installer. Only runtime files are updated; settings are preserved.
local base="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/"
local env=type(getgenv)=="function" and getgenv() or _G
local function notice(message)
 print("[TheBest] "..message)
 if not env.__TheBestLoadingUI then pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title="TheBest",Text=message,Duration=6}) end) end
end
if env.__TheBestPublicInstallBusy then notice("Loading is already in progress."); return end
env.__TheBestPublicInstallBusy=true
-- The loader and the runtime share one loading card; it never impersonates completed work.
local makeLoadingUI=(function(options)
 options = options or {}
 local palettes = {
  Inferno = {{14,7,2},{28,13,4},{255,121,21},{255,241,220},{214,165,105}},
  Matrix = {{3,10,5},{7,20,10},{0,255,90},{215,255,225},{95,185,115}},
  Orbit = {{12,23,31},{19,33,42},{170,218,211},{229,239,237},{139,162,170}},
  Pearl = {{248,250,253},{255,255,255},{99,102,241},{30,41,59},{100,116,139}},
  Emerald = {{255,255,255},{255,255,255},{0,204,153},{30,30,30},{51,51,51}},
  Violet = {{18,18,22},{18,18,22},{160,80,220},{220,220,225},{140,140,150}},
  Astolfo = {{24,12,23},{40,21,36},{242,136,196},{255,239,249},{210,160,190}},
  Billy = {{31,22,15},{45,31,21},{236,172,88},{255,244,222},{210,184,147}},
  YBA = {{22,11,27},{35,19,43},{235,71,167},{250,234,248},{195,153,191}},
  DIO = {{18,12,5},{29,20,8},{230,177,61},{255,241,200},{190,157,91}},
 }
 local function themeFor(name, custom)
  if custom then return custom end
  local p = palettes[name] or palettes.Inferno
  local function color(rgb) return Color3.fromRGB(rgb[1],rgb[2],rgb[3]) end
  return {background=color(p[1]),surface=color(p[2]),accent=color(p[3]),text=color(p[4]),textDim=color(p[5])}
 end
 local theme = themeFor(options.ThemeName, options.Theme)
 local function make(kind, properties, parent)
  local object = Instance.new(kind)
  for key,value in pairs(properties) do object[key] = value end
  object.Parent = parent
  return object
 end
 local gui = make("ScreenGui", {Name="TheBestLoadingV7",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=2147483000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local card = make("Frame", {Name="LoadingCard",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(420,164),BackgroundColor3=theme.background,BorderSizePixel=0}, gui)
 make("UICorner",{CornerRadius=UDim.new(0,14)},card)
 local stroke = make("UIStroke",{Color=theme.accent,Thickness=1,Transparency=.38},card)
 local mark = make("Frame",{Position=UDim2.fromOffset(22,24),Size=UDim2.fromOffset(3,22),BackgroundColor3=theme.accent,BorderSizePixel=0},card)
 local title = make("TextLabel",{Position=UDim2.fromOffset(36,20),Size=UDim2.new(1,-100,0,30),BackgroundTransparency=1,Font=Enum.Font.GothamBold,Text="T H E B E S T",TextSize=18,TextColor3=theme.text,TextXAlignment=Enum.TextXAlignment.Left},card)
 local percent = make("TextLabel",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-24,0,25),Size=UDim2.fromOffset(58,22),BackgroundTransparency=1,Font=Enum.Font.GothamMedium,Text="0%",TextSize=15,TextColor3=theme.accent,TextXAlignment=Enum.TextXAlignment.Right},card)
 local stage = make("TextLabel",{Position=UDim2.fromOffset(24,65),Size=UDim2.new(1,-48,0,37),BackgroundTransparency=1,Font=Enum.Font.Gotham,Text="Preparing interface…",TextSize=13,TextColor3=theme.textDim,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},card)
 local rail = make("Frame",{Position=UDim2.fromOffset(24,117),Size=UDim2.new(1,-48,0,5),BackgroundColor3=theme.surface,BorderSizePixel=0,ClipsDescendants=true},card)
 make("UICorner",{CornerRadius=UDim.new(1,0)},rail)
 local fill = make("Frame",{Name="Progress",Size=UDim2.fromScale(0,1),BackgroundColor3=theme.accent,BorderSizePixel=0},rail)
 make("UICorner",{CornerRadius=UDim.new(1,0)},fill)
 local foot = make("TextLabel",{Position=UDim2.fromOffset(24,132),Size=UDim2.new(1,-48,0,16),BackgroundTransparency=1,Font=Enum.Font.Gotham,Text="Loading your saved setup",TextSize=10,TextColor3=theme.textDim,TextXAlignment=Enum.TextXAlignment.Left},card)
 local parent = options.Parent
 if not parent then
  local ok,hui = pcall(function() return type(gethui)=="function" and gethui() or game:GetService("CoreGui") end)
  if ok then parent=hui end
 end
 local attached = parent and pcall(function() gui.Parent=parent end)
 if not attached then gui.Parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui",10) end
 local alive, progress, tween = true, 0, nil
 local api = {}
 function api.Set(value, label)
  if not alive then return end
  value=tonumber(value) or progress
  if value~=value then value=progress end
  progress=math.max(progress,math.clamp(value,0,100))
  percent.Text=tostring(math.floor(progress)).."%"
  if label then stage.Text=tostring(label) end
  if tween then pcall(function() tween:Cancel() end) end
  tween=game:GetService("TweenService"):Create(fill,TweenInfo.new(.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(progress/100,1)})
  tween:Play()
 end
 function api.SetTheme(name, custom)
  if not alive then return end
  theme=themeFor(name,custom)
  card.BackgroundColor3=theme.background
  rail.BackgroundColor3=theme.surface
  stroke.Color=theme.accent
  mark.BackgroundColor3=theme.accent
  fill.BackgroundColor3=theme.accent
  percent.TextColor3=theme.accent
  title.TextColor3=theme.text
  stage.TextColor3=theme.textDim
  foot.TextColor3=theme.textDim
 end
 function api.Destroy()
  if not alive then return end
  alive=false
  if tween then pcall(function() tween:Cancel() end) end
  gui:Destroy()
 end
 function api.Fail(message)
  if not alive then return end
  if tween then pcall(function() tween:Cancel() end) end
  stage.Text="Loading stopped: "..tostring(message)
  stage.TextSize=11
  foot.Text="Close this message and run the loader again."
  percent.Text="!"
  local close=make("TextButton",{Position=UDim2.new(1,-64,1,-30),Size=UDim2.fromOffset(48,20),BackgroundColor3=theme.surface,Text="Close",TextColor3=theme.text,TextSize=11,Font=Enum.Font.Gotham,BorderSizePixel=0},card)
  make("UICorner",{CornerRadius=UDim.new(0,4)},close)
  close.MouseButton1Click:Connect(api.Destroy)
 end
 return api
end)
pcall(function()
 local old=env.__TheBestLoadingUI
 if type(old)=="table" and type(old.Destroy)=="function" then old.Destroy() end
 local themeName="Inferno"
 if type(readfile)=="function" then
  local ok,raw=pcall(readfile,"thebest/config.json")
  if ok then
   local decodedOk,config=pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
   if decodedOk and type(config)=="table" and type(config.uiTheme)=="string" then themeName=config.uiTheme end
  end
 end
 env.__TheBestLoadingUI=makeLoadingUI({ThemeName=themeName})
end)
local function progress(value,label)
 local ui=env.__TheBestLoadingUI
 if type(ui)=="table" and type(ui.Set)=="function" then pcall(ui.Set,value,label) end
end
progress(1,"Checking the latest version…")
local succeeded,problem=xpcall(function()
 assert(type(readfile)=="function" and type(writefile)=="function" and type(makefolder)=="function" and type(loadstring)=="function","Your executor needs readfile, writefile, makefolder and loadstring.")
 local http=game:GetService("HttpService")
 local function fetch(url)
  local lastError="download failed"
  for attempt=1,3 do
   local done,ok,result=false,false,nil
   task.spawn(function()
    ok,result=pcall(function() return game:HttpGet(url,true) end)
    done=true
   end)
   local deadline=os.clock()+20
   while not done and os.clock()<deadline do task.wait(.05) end
   if done and ok and type(result)=="string" and #result>0 then return result end
   lastError=done and tostring(result) or "request timed out after 20 seconds"
   if attempt<3 then task.wait(.25*attempt) end
  end
  error("Download failed after 3 attempts: "..lastError)
 end
 local hashFunction=(type(crypt)=="table" and crypt.hash) or (type(syn)=="table" and type(syn.crypt)=="table" and syn.crypt.hash)
 local function valid(contents,descriptor)
  if type(contents)~="string" or type(descriptor)~="table" or #contents~=descriptor.bytes then return false end
  if type(hashFunction)=="function" then
   local ok,value=pcall(hashFunction,contents,"sha256")
   if ok and type(value)=="string" and #value==64 then return value:lower()==descriptor.sha256 end
  end
  return true
 end
 local function readValid(file,descriptor)
  local ok,contents=pcall(readfile,file)
  return ok and valid(contents,descriptor)
 end
 local function decode(raw,label)
  local ok,value=pcall(function() return http:JSONDecode(raw) end)
  assert(ok and type(value)=="table","Invalid "..label.." response.")
  return value
 end
 local function descriptor(value)
  return type(value)=="table" and type(value.bytes)=="number" and value.bytes>0 and type(value.sha256)=="string" and #value.sha256==64 and value.sha256:match("^[a-f0-9]+$")
 end
 notice("Checking the latest version...")
 local latest=decode(fetch(base.."manifest.json?cb="..tostring(os.time()).."-"..tostring(math.random(100000,999999))),"update manifest")
 assert(latest.schema==1 and type(latest.release)=="string" and latest.release:match("^[%w_-]+$") and descriptor(latest.manifest),"Invalid update manifest.")
 progress(5,"Reading release information…")
 local releaseBase=base.."releases/"..latest.release.."/"
 local releaseRaw=fetch(releaseBase.."release.json")
 assert(valid(releaseRaw,latest.manifest),"Release manifest failed validation.")
 local release=decode(releaseRaw,"release manifest")
 assert(release.schema==1 and release.release==latest.release and type(release.resources)=="table" and type(release.chunks)=="table","Invalid release.")
 assert(descriptor(release.main) and descriptor(release.boot) and descriptor(release.runtimeManifest),"Invalid runtime descriptors.")
 assert(release.main.bytes<32*1024*1024,"Main source exceeds the execution limit.")
 for _,folder in ipairs({"thebest","thebest/runtime-v016","thebest/runtime-v016/resources"}) do pcall(makefolder,folder) end
 local root="thebest/runtime-v016/"
 progress(8,"Checking saved assets…")
 local seen,resourceCount={},0
 for index,chunk in ipairs(release.chunks) do
  assert(descriptor(chunk) and type(chunk.file)=="string" and chunk.file:match("^resources%-%d%d%.json$") and type(chunk.ids)=="table","Invalid resource bundle.")
  progress(8+62*(index-1)/math.max(1,#release.chunks),"Checking assets "..index.."/"..#release.chunks.."…")
  local needed=false
  for _,id in ipairs(chunk.ids) do
   assert(type(id)=="string" and #id==64 and id:match("^[a-f0-9]+$") and descriptor(release.resources[id]) and not seen[id],"Invalid resource identifier.")
   seen[id]=true
   resourceCount+=1
   if not readValid(root.."resources/"..id..".b64",release.resources[id]) then needed=true end
  end
  if needed then
   progress(8+62*(index-1)/math.max(1,#release.chunks),"Downloading assets "..index.."/"..#release.chunks.."…")
   local raw=fetch(releaseBase..chunk.file)
   assert(valid(raw,chunk),"Resource bundle failed validation: "..chunk.file)
   local contents=decode(raw,"resource bundle")
   assert(contents.schema==1 and type(contents.files)=="table","Invalid resource bundle contents.")
   -- Validate the entire bundle before changing any local runtime files.
   for _,id in ipairs(chunk.ids) do
    local encoded=contents.files[id]
    assert(valid(encoded,release.resources[id]) and encoded:match("^[A-Za-z0-9+/=]+$"),"Invalid asset in "..chunk.file)
   end
   for _,id in ipairs(chunk.ids) do writefile(root.."resources/"..id..".b64",contents.files[id]) end
  end
 end
 assert(resourceCount==release.resourceCount,"Incomplete release resources.")
 local resourceTotal=0
 for id in pairs(release.resources) do assert(seen[id],"Unlisted release resource.");resourceTotal+=1 end
 assert(resourceTotal==resourceCount,"Invalid release resource count.")
 progress(70,"Checking script files…")
 local staged={}
 for _,record in ipairs({{name="main.lua",remote="runtime/main.lua",info=release.main},{name="boot.lua",remote="runtime/boot.lua",info=release.boot},{name="manifest.json",remote="runtime/manifest.json",info=release.runtimeManifest}}) do
  if not readValid(root..record.name,record.info) then
   local contents=fetch(releaseBase..record.remote)
   assert(valid(contents,record.info),"Runtime file failed validation: "..record.name)
   staged[record.name]=contents
  end
 end
 for _,name in ipairs({"main.lua","boot.lua","manifest.json"}) do
  if staged[name] then writefile(root..name,staged[name]) end
 end
 progress(80,"Starting interface…")
 local boot=readfile(root.."boot.lua")
 assert(valid(boot,release.boot),"Boot cache failed validation.")
 local compiled,compileError=loadstring(boot,"@TheBest_public_boot")
 assert(type(compiled)=="function",tostring(compileError))
 local result=compiled()
 local diagnostic=_G.TheBestDiagnostics
 if type(diagnostic)=="table" and type(diagnostic.Status)=="string" and diagnostic.Status:find("failed",1,true) then error("Interface startup failed; see the executor console.") end
 progress(100,"Ready")
 local ui=env.__TheBestLoadingUI
 if type(ui)=="table" and type(ui.Destroy)=="function" then pcall(ui.Destroy) end
 env.__TheBestLoadingUI=nil
 return result
end,function(message) return tostring(message) end)
env.__TheBestPublicInstallBusy=nil
if not succeeded then
 local ui=env.__TheBestLoadingUI
 if type(ui)=="table" and type(ui.Fail)=="function" then pcall(ui.Fail,problem) end
 notice("Loading stopped: "..tostring(problem)); warn("[TheBest] "..tostring(problem))
end
