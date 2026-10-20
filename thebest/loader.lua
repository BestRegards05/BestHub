-- TheBest: public installer. Only runtime files are updated; settings are preserved.
local base="https://raw.githubusercontent.com/BestRegards05/BestHub/main/thebest/"
local env=type(getgenv)=="function" and getgenv() or _G
local function notice(message)
 print("[TheBest] "..message)
 pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title="TheBest",Text=message,Duration=6}) end)
end
if env.__TheBestPublicInstallBusy then notice("Loading is already in progress."); return end
env.__TheBestPublicInstallBusy=true
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
 local releaseBase=base.."releases/"..latest.release.."/"
 local releaseRaw=fetch(releaseBase.."release.json")
 assert(valid(releaseRaw,latest.manifest),"Release manifest failed validation.")
 local release=decode(releaseRaw,"release manifest")
 assert(release.schema==1 and release.release==latest.release and type(release.resources)=="table" and type(release.chunks)=="table","Invalid release.")
 assert(descriptor(release.main) and descriptor(release.boot) and descriptor(release.runtimeManifest),"Invalid runtime descriptors.")
 assert(release.main.bytes<32*1024*1024,"Main source exceeds the execution limit.")
 for _,folder in ipairs({"thebest","thebest/runtime-v016","thebest/runtime-v016/resources"}) do pcall(makefolder,folder) end
 local root="thebest/runtime-v016/"
 local seen,resourceCount={},0
 for index,chunk in ipairs(release.chunks) do
  assert(descriptor(chunk) and type(chunk.file)=="string" and chunk.file:match("^resources%-%d%d%.json$") and type(chunk.ids)=="table","Invalid resource bundle.")
  local needed=false
  for _,id in ipairs(chunk.ids) do
   assert(type(id)=="string" and #id==64 and id:match("^[a-f0-9]+$") and descriptor(release.resources[id]) and not seen[id],"Invalid resource identifier.")
   seen[id]=true
   resourceCount+=1
   if not readValid(root.."resources/"..id..".b64",release.resources[id]) then needed=true end
  end
  if needed then
   notice("Downloading assets "..index.."/"..#release.chunks.."...")
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
 notice("Starting TheBest...")
 local boot=readfile(root.."boot.lua")
 assert(valid(boot,release.boot),"Boot cache failed validation.")
 local compiled,compileError=loadstring(boot,"@TheBest_public_boot")
 assert(type(compiled)=="function",tostring(compileError))
 return compiled()
end,function(message) return tostring(message) end)
env.__TheBestPublicInstallBusy=nil
if not succeeded then notice("Loading stopped: "..tostring(problem)); warn("[TheBest] "..tostring(problem)) end
