-- TheBest Skin Capture: local visual capture for your own, authorized place.
-- Keeps asset references; it does not copy private Roblox asset files.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local environment = type(getgenv) == "function" and getgenv() or _G
local SESSION_KEY = "TheBestSkinCaptureSession14"
local INDEX = "thebest/captured-skins/index.json"
local R6_ALIASES = {Torso = "UpperTorso", ["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm", ["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg"}
local function referenceFrame(object)
    if object:IsA("Model") then return object:GetPivot() end
    if object:IsA("Attachment") then return object.WorldCFrame end
    return object.CFrame
end
-- Custom-looking names are intentional capture content, not exclusions.
local function isExistingCustomStandObject() return false end

local allSaveParts = {
	"Head",
	"LeftFoot",
	"LeftHand",
	"LeftLowerArm",
	"LeftLowerLeg",
	"LeftUpperArm",
	"LeftUpperLeg",
	"LowerTorso",
	"RightFoot",
	"RightHand",
	"RightLowerArm",
	"RightLowerLeg",
	"RightUpperArm",
	"RightUpperLeg",
	"UpperTorso",
	"HumanoidRootPart",
	"Horse",
}

local visualClasses = {
	UnionOperation = true,
	MeshPart = true,
	Part = true,
	SpecialMesh = true,
	Decal = true,
	SurfaceAppearance = true,
	Beam = true,
	ParticleEmitter = true,
	Bone = true,
	Model = true,
	Attachment = true,
	Trail = true,
	PointLight = true,
	Texture = true,
	Highlight = true,
	Weld = true,
	WeldConstraint = true,
}

local function generateKey()
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local key = {}
	for i = 1, 32 do
		local pos = math.random(1, #chars)
		key[i] = chars:sub(pos, pos)
	end
	return table.concat(key)
end
local function xorCipher(data, key)
	local result = {}
	for i = 1, #data do
		local dataByte = string.byte(data, i)
		local keyByte = string.byte(key, ((i - 1) % #key) + 1)
		result[i] = string.char(bit32.bxor(dataByte, keyByte))
	end
	return table.concat(result)
end
local function encodeData(json)
	local key = generateKey()
	local encrypted = xorCipher(json, key)
	return key .. encrypted
end
local function decodeData(raw)
	local key = raw:sub(1, 32)
	local encrypted = raw:sub(33)
	local json = xorCipher(encrypted, key)
	return json
end

local function saveProp(value)
	local t = typeof(value)
	if t == "Vector3" then
		return { __t = "Vector3", v = { value.X, value.Y, value.Z } }
	elseif t == "Vector2" then
		return { __t = "Vector2", v = { value.X, value.Y } }
	elseif t == "Color3" then
		return { __t = "Color3", v = { value.R, value.G, value.B } }
	elseif t == "CFrame" then
		return { __t = "CFrame", v = { value:GetComponents() } }
	elseif t == "NumberRange" then
		return { __t = "NumberRange", v = { value.Min, value.Max } }
	elseif t == "NumberSequence" then
		local points = {}
		for _, p in ipairs(value.Keypoints) do
			table.insert(points, { Time = p.Time, Value = p.Value, Envelope = p.Envelope })
		end
		return { __t = "NumberSequence", v = points }
	elseif t == "ColorSequence" then
		local points = {}
		for _, p in ipairs(value.Keypoints) do
			table.insert(points, { Time = p.Time, Color = { p.Value.R, p.Value.G, p.Value.B } })
		end
		return { __t = "ColorSequence", v = points }
	elseif t == "BrickColor" then
		return { __t = "BrickColor", v = value.Number }
	elseif t == "EnumItem" then
		return { __t = "Enum", v = tostring(value) }
	elseif t == "string" or t == "number" or t == "boolean" then
		return value
	end
	return nil
end
local function hasParticleEmitterInside(attachment)
	for _, child in ipairs(attachment:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			return true
		end
	end
	return false
end
local capturedAttachmentIDs = setmetatable({}, { __mode = "k" })
local function ensureAttachmentID(attachment)
    local id = capturedAttachmentIDs[attachment]
    if not id then
        id = HttpService:GenerateGUID(false)
        capturedAttachmentIDs[attachment] = id
    end
    return id
end
-- Native serialization retains UnionOperation CSG, including private mesh data.
-- The API can be denied outside Studio/Open Cloud; never replace a failed union with a blank part.
local function nativeStandUnionService()
 local ok, service = pcall(function() return game:GetService("SerializationService") end)
 if not ok or not service then error("UnionOperation needs SerializationService access; this executor/client does not provide it. Nothing was saved or replaced.") end
 return service
end
local function validNativeStandUnion(part)
 if typeof(part) ~= "Instance" or part.ClassName ~= "UnionOperation" then return false end
 local size = part.Size
 return size.X > 0 and size.Y > 0 and size.Z > 0
  and size.X < math.huge and size.Y < math.huge and size.Z < math.huge
end
local function destroyNativeStandUnionList(instances)
 if type(instances) == "table" then
  for _, instance in pairs(instances) do
   if typeof(instance) == "Instance" then instance:Destroy() end
  end
 end
end
local function decodeNativeStandUnion(payload)
 if type(payload) ~= "table" or payload.format ~= "roblox-native-union-v1"
  or type(payload.hex) ~= "string" or #payload.hex == 0 or #payload.hex % 2 ~= 0
  or #payload.hex > 134217728 or payload.hex:find("[^0-9a-f]") then
  error("Captured UnionOperation has invalid native geometry data")
 end
 local bytes = payload.hex:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end)
 local service = nativeStandUnionService()
 local ok, instances = pcall(function() return service:DeserializeInstancesAsync(buffer.fromstring(bytes)) end)
 if not ok then error("Cannot restore UnionOperation native geometry; SerializationService denied or incompatible: " .. tostring(instances)) end
 if type(instances) ~= "table" or #instances ~= 1 or not validNativeStandUnion(instances[1]) then
  destroyNativeStandUnionList(instances)
  error("Native geometry did not restore exactly one valid UnionOperation")
 end
 local result = instances[1]
 result.Parent = nil
 if #result:GetChildren() ~= 0 then
  result:Destroy()
  error("Captured native union unexpectedly contains children")
 end
 return result
end
local function serializeNativeStandUnion(inst)
 local clone = inst:Clone()
 if not clone then error("Cannot clone UnionOperation native geometry: " .. tostring(inst.Name)) end
 clone.Parent = nil
 for _, child in ipairs(clone:GetChildren()) do child:Destroy() end
 local ok, result = pcall(function()
  local service = nativeStandUnionService()
  local bytes = service:SerializeInstancesAsync({clone})
  if typeof(bytes) ~= "buffer" or buffer.len(bytes) == 0 or buffer.len(bytes) > 67108864 then
   error("SerializationService returned invalid UnionOperation geometry")
  end
  local payload = {format = "roblox-native-union-v1", hex = (buffer.tostring(bytes):gsub(".", function(char) return string.format("%02x", string.byte(char)) end))}
  local restored = decodeNativeStandUnion(payload)
  local a, b = clone.Size, restored.Size
  local sameSize = math.abs(a.X-b.X) < 0.00001 and math.abs(a.Y-b.Y) < 0.00001 and math.abs(a.Z-b.Z) < 0.00001
  restored:Destroy()
  if not sameSize then error("UnionOperation native round-trip changed its saved size") end
  return payload
 end)
 clone:Destroy()
 if not ok then error("Cannot capture UnionOperation " .. tostring(inst.Name) .. ": " .. tostring(result)) end
 return result
end
local function saveInstance(inst, parentPart)
	local data = { ClassName = inst.ClassName, Name = inst.Name, Properties = {}, Children = {} }
	if inst:IsA("MeshPart") or inst:IsA("Part") or inst:IsA("UnionOperation") then
		local props = {
			"MeshId",
			"TextureID",
			"Material",
			"BrickColor",
			"Color",
			"Transparency",
			"Reflectance",
			"CastShadow",
			"Visible",
			"Locked",
			"Anchored",
			"CanCollide",
			"Massless",
			"PivotOffset",
			"CollisionFidelity",
			"RenderFidelity",
			"DoubleSided",
			"Shape",
			"TopSurface",
			"BottomSurface",
		}
		pcall(function()
			if parentPart then
				local relativeCF = referenceFrame(parentPart):Inverse() * inst.CFrame
				data.Properties["RelativeCFrame"] = { __t = "CFrame", v = { relativeCF:GetComponents() } }
			end
		end)
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
		data.Properties.SizeOrig = saveProp(inst.Size)
		if inst:IsA("UnionOperation") then
			data.UnionGeometry = serializeNativeStandUnion(inst)
			data.Properties.UsePartColor = inst.UsePartColor
		end
		for _, child in ipairs(inst:GetChildren()) do
			if visualClasses[child.ClassName] then
				table.insert(data.Children, saveInstance(child, inst))
			end
		end
	elseif inst:IsA("SpecialMesh") then
		for _, prop in ipairs({ "MeshId", "TextureId", "MeshType", "Scale", "Offset", "VertexColor" }) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local saved = saveProp(val)
				if saved ~= nil then
					data.Properties[prop] = saved
				end
			end
		end
	elseif inst:IsA("Model") then
		if parentPart then
			local relativeCF = referenceFrame(parentPart):Inverse() * inst:GetPivot()
			data.Properties["RelativeCFrame"] = { __t = "CFrame", v = { relativeCF:GetComponents() } }
		end
		for _, child in ipairs(inst:GetChildren()) do
			if visualClasses[child.ClassName] then
				table.insert(data.Children, saveInstance(child, inst))
			end
		end
	elseif inst:IsA("Attachment") then
		local id = ensureAttachmentID(inst)
		data.Properties.AttachmentID = id
		if parentPart then
			local parentCF = referenceFrame(parentPart)
			local relativeCF = parentCF:Inverse() * inst.WorldCFrame
			data.Properties["RelativeCFrame"] = { __t = "CFrame", v = { relativeCF:GetComponents() } }
		end
		data.Properties.Position = saveProp(inst.Position)
		data.Properties.Orientation = saveProp(inst.Orientation)
		if inst:IsA("Bone") then data.Properties.Transform = saveProp(inst.Transform) end
		for _, child in ipairs(inst:GetChildren()) do
			if visualClasses[child.ClassName] then
				table.insert(data.Children, saveInstance(child, inst))
			end
		end
	elseif inst:IsA("Decal") then
		local props = { "Texture", "Face", "Transparency", "Color3", "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV" }
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
		if parentPart and parentPart:IsA("BasePart") then
			local relativeCF = referenceFrame(parentPart):Inverse() * inst.Parent.CFrame
			data.Properties["RelativeCFrame"] = { __t = "CFrame", v = { relativeCF:GetComponents() } }
		end
	elseif inst:IsA("Texture") then
		local props = { "Texture", "Face", "Transparency", "Color3", "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV" }
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
	elseif inst:IsA("SurfaceAppearance") then
		local props = { "AlphaMode", "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap", "TexturePack" }
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
	elseif inst:IsA("Highlight") then
		local props =
			{ "FillColor", "FillTransparency", "OutlineColor", "OutlineTransparency", "DepthMode", "Enabled" }
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
	elseif inst:IsA("PointLight") then
		local props = { "Brightness", "Color", "Enabled", "Range", "Shadows", "Transparency", "Visible" }
		pcall(function()
			if parentPart then
				local relativeCF = referenceFrame(parentPart):Inverse() * inst.CFrame
				data.Properties["RelativeCFrame"] = { __t = "CFrame", v = { relativeCF:GetComponents() } }
			end
		end)
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
	elseif inst:IsA("Weld") or inst:IsA("WeldConstraint") then
		if inst.Part0 then
			data.Properties.Part0Name = inst.Part0.Name
		end
		if inst.Part1 then
			data.Properties.Part1Name = inst.Part1.Name
		end
		pcall(function()
			data.Properties.C0 = saveProp(inst.C0)
		end)
		pcall(function()
			data.Properties.C1 = saveProp(inst.C1)
		end)
		pcall(function()
			data.Properties.Enabled = inst.Enabled
		end)
	elseif inst:IsA("Beam") then
		if inst.Attachment0 then
			data.Properties.Attachment0ID = ensureAttachmentID(inst.Attachment0)
			local parentCF = parentPart
					and (referenceFrame(parentPart))
				or CFrame.new()
			data.Properties.Attachment0CF = saveProp(parentCF:ToObjectSpace(inst.Attachment0.WorldCFrame))
		end
		if inst.Attachment1 then
			data.Properties.Attachment1ID = ensureAttachmentID(inst.Attachment1)
			local parentCF = parentPart
					and (referenceFrame(parentPart))
				or CFrame.new()
			data.Properties.Attachment1CF = saveProp(parentCF:ToObjectSpace(inst.Attachment1.WorldCFrame))
		end
		local props = {
			"Color",
			"Transparency",
			"Width0",
			"Width1",
			"FaceCamera",
			"LightEmission",
			"LightInfluence",
			"Texture",
			"TextureSpeed",
			"TextureLength",
			"CurveSize0",
			"CurveSize1",
			"Enabled",
		}
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
	elseif inst:IsA("Trail") then
		if inst.Attachment0 then
			data.Properties.Attachment0ID = ensureAttachmentID(inst.Attachment0)
			local parentCF = parentPart
					and (referenceFrame(parentPart))
				or CFrame.new()
			data.Properties.Attachment0CF = saveProp(parentCF:ToObjectSpace(inst.Attachment0.WorldCFrame))
		end
		if inst.Attachment1 then
			data.Properties.Attachment1ID = ensureAttachmentID(inst.Attachment1)
			local parentCF = parentPart
					and (referenceFrame(parentPart))
				or CFrame.new()
			data.Properties.Attachment1CF = saveProp(parentCF:ToObjectSpace(inst.Attachment1.WorldCFrame))
		end
		local props = {
			"Brightness",
			"Color",
			"FaceCamera",
			"LightEmission",
			"LightInfluence",
			"Texture",
			"TextureLength",
			"TextureMode",
			"Transparency",
			"Enabled",
			"Lifetime",
			"WidthScale",
		}
		pcall(function()
			data.Properties.MaxLength = saveProp(inst.MaxLength)
		end)
		pcall(function()
			data.Properties.MinLength = saveProp(inst.MinLength)
		end)
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
	elseif inst:IsA("ParticleEmitter") then
		local props = {
			"Brightness",
			"Color",
			"LightEmission",
			"LightInfluence",
			"Orientation",
			"EmissionDirection",
			"Size",
			"Squash",
			"Texture",
			"Transparency",
			"ZOffset",
			"Lifetime",
			"Rate",
			"Rotation",
			"RotSpeed",
			"Speed",
			"SpreadAngle",
			"FlipbookFramerate",
			"FlipbookIncompatible",
			"FlipbookLayout",
			"FlipbookMode",
			"Shape",
			"ShapeInOut",
			"ShapePartial",
			"ShapeStyle",
			"Drag",
			"LockedToPart",
			"TimeScale",
			"VelocityInheritance",
			"WindAffectsDrag",
			"Acceleration",
			"Enabled",
		}
		for _, prop in ipairs(props) do
			local ok, val = pcall(function()
				return inst[prop]
			end)
			if ok and val ~= nil then
				local s = saveProp(val)
				if s ~= nil then
					data.Properties[prop] = s
				end
			end
		end
		if inst.Parent and inst.Parent:IsA("Attachment") then
			local parentAtt = inst.Parent
			data.Properties.ParentAttachmentName = parentAtt.Name
			if parentPart then
				local parentCF = referenceFrame(parentPart)
				local relativeCF = parentCF:Inverse() * parentAtt.WorldCFrame
				data.Properties["AttachmentCFrame"] = { __t = "CFrame", v = { relativeCF:GetComponents() } }
			end
		end
	elseif inst:IsA("Bone") then
		if parentPart then
			local parentCF = referenceFrame(parentPart)
			local relativeToParent = parentCF:Inverse() * inst.CFrame
			data.Properties["RelativeCFrame"] = { __t = "CFrame", v = { relativeToParent:GetComponents() } }
		end
		pcall(function()
			data.Properties["Transform"] = saveProp(inst.Transform)
		end)
		for _, child in ipairs(inst:GetChildren()) do
			if visualClasses[child.ClassName] then
				table.insert(data.Children, saveInstance(child, inst))
			end
		end
	end
	return data
end

local function markBaseStandPartData(data)
	if type(data) ~= "table" then
		return
	end
	if data.ClassName == "MeshPart" or data.ClassName == "Part" or data.ClassName == "UnionOperation" then
		data.Properties = data.Properties or {}
		data.Properties.PreserveSize = true
	end
	for _, childData in ipairs(data.Children or {}) do
		markBaseStandPartData(childData)
	end
end
local function isVisibleTemplatePart(part)
	if part.Transparency < 0.999 then
		return true
	end
	if part:IsA("MeshPart") and tostring(part.MeshId or "") ~= "" then
		return true
	end
	for _, object in ipairs(part:GetDescendants()) do
		if
			object:IsA("SpecialMesh")
			or object:IsA("Decal")
			or object:IsA("Texture")
			or object:IsA("SurfaceAppearance")
			or object:IsA("ParticleEmitter")
			or object:IsA("Beam")
			or object:IsA("Trail")
		then
			return true
		end
	end
	return false
end
local function buildBaseStandModelData(standTemplate)
	local usedAttachments = {}
	for _, object in ipairs(standTemplate:GetDescendants()) do
		if object:IsA("Beam") or object:IsA("Trail") then
			if object.Attachment0 then
				usedAttachments[object.Attachment0] = true
			end
			if object.Attachment1 then
				usedAttachments[object.Attachment1] = true
			end
		end
	end
	local modelData = {}
	local directBodyParts = {}
	for _, partName in ipairs(allSaveParts) do
		local part = standTemplate:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			directBodyParts[part] = partName
			local partData = { Children = {} }
			if partName ~= "HumanoidRootPart" and isVisibleTemplatePart(part) then
				local bodyData = saveInstance(part, part)
				bodyData.Children = {}
				markBaseStandPartData(bodyData)
				for _, child in ipairs(part:GetChildren()) do
					if
						visualClasses[child.ClassName]
						and not child:IsA("BasePart")
						and not child:IsA("Model")
						and not child:IsA("Weld")
						and not child:IsA("WeldConstraint")
						and not isExistingCustomStandObject(child)
					then
						if not child:IsA("Attachment")
							or hasParticleEmitterInside(child)
							or usedAttachments[child]
						then
							table.insert(bodyData.Children, saveInstance(child, part))
						end
					end
				end
				table.insert(partData.Children, bodyData)
			end
			for _, descendant in ipairs(part:GetDescendants()) do
				if descendant:IsA("BasePart") and not isExistingCustomStandObject(descendant) then
					local nearestBasePart = descendant.Parent
					while nearestBasePart and nearestBasePart ~= part and not nearestBasePart:IsA("BasePart") do
						nearestBasePart = nearestBasePart.Parent
					end
					if nearestBasePart == part and isVisibleTemplatePart(descendant) then
						local extraData = saveInstance(descendant, part)
						markBaseStandPartData(extraData)
						table.insert(partData.Children, extraData)
					end
				end
			end
			modelData[partName] = partData
		end
	end
	local bodyPartList = {}
	for bodyPart in pairs(directBodyParts) do
		table.insert(bodyPartList, bodyPart)
	end
	for _, descendant in ipairs(standTemplate:GetDescendants()) do
		if
			descendant:IsA("BasePart")
			and not directBodyParts[descendant]
			and not isExistingCustomStandObject(descendant)
			and isVisibleTemplatePart(descendant)
		then
			local insideKnownBody = false
			for bodyPart in pairs(directBodyParts) do
				if descendant:IsDescendantOf(bodyPart) then
					insideKnownBody = true
					break
				end
			end
			local parentBasePart = descendant.Parent
			while parentBasePart and parentBasePart ~= standTemplate and not parentBasePart:IsA("BasePart") do
				parentBasePart = parentBasePart.Parent
			end
			if not insideKnownBody and (not parentBasePart or parentBasePart == standTemplate) then
				local closestPart = nil
				local closestDistance = math.huge
				for _, bodyPart in ipairs(bodyPartList) do
					local distance = (bodyPart.Position - descendant.Position).Magnitude
					if distance < closestDistance then
						closestPart = bodyPart
						closestDistance = distance
					end
				end
				if closestPart then
					local targetName = directBodyParts[closestPart]
					modelData[targetName] = modelData[targetName] or { Children = {} }
					local extraData = saveInstance(descendant, closestPart)
					markBaseStandPartData(extraData)
					table.insert(modelData[targetName].Children, extraData)
				end
			end
		end
	end
	local highlightsData = {}
	for _, object in ipairs(standTemplate:GetDescendants()) do
		if object:IsA("Highlight") and not isExistingCustomStandObject(object) then
			table.insert(highlightsData, saveInstance(object, standTemplate))
		end
	end
	if #highlightsData > 0 then
		modelData._Highlights = { Children = highlightsData }
	end
	return modelData
end
for _, name in ipairs({"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do table.insert(allSaveParts, name) end


local function safeID(value)
    return type(value) == "string" and #value >= 8 and #value <= 80 and value:match("^[A-Za-z0-9_-]+$") ~= nil
end
local function trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
local function validateIndex(index)
    if type(index) ~= "table" or index.schema ~= 1 or type(index.entries) ~= "table" then
        error("Index format is invalid; the original index was preserved.")
    end
    local length = #index.entries
    local seen = {}
    for key, entry in pairs(index.entries) do
        if type(key) ~= "number" or key < 1 or key > length or key % 1 ~= 0 then error("Index entries are not an array.") end
        if type(entry) ~= "table" or not safeID(entry.id) or seen[entry.id]
            or type(entry.name) ~= "string" or trim(entry.name) == ""
            or type(entry.stand) ~= "string" or trim(entry.stand) == ""
            or entry.file ~= "ssoc_skins/captured-" .. entry.id .. ".ssoc"
            or type(entry.sourceModel) ~= "string" or type(entry.sourcePlaceId) ~= "number"
            or type(entry.capturedAt) ~= "string" then error("Invalid entry in index; original preserved.") end
        seen[entry.id] = true
    end
    return index
end
local function checkFilesystem()
    for _, name in ipairs({"readfile", "writefile", "makefolder", "isfolder", "isfile"}) do
        local value = environment[name]
        if type(value) ~= "function" then error("Missing executor function: " .. name .. ". No files changed.") end
    end
end
local function ensureDirectories()
    for _, folder in ipairs({"ssoc_skins", "thebest", "thebest/captured-skins"}) do
        if not environment.isfolder(folder) then environment.makefolder(folder) end
        if not environment.isfolder(folder) then error("Could not create folder: " .. folder) end
    end
end
local function readIndex()
    if not environment.isfile(INDEX) then return {schema = 1, entries = {}} end
    local ok, raw = pcall(environment.readfile, INDEX)
    if not ok or type(raw) ~= "string" then error("Cannot read existing index; it was preserved.") end
    local decodedOK, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if not decodedOK then error("Index JSON is damaged; it was preserved. Restore it before saving.") end
    return validateIndex(decoded), raw
end
local function isRig(model)
    if not model or not model:IsA("Model") then return false end
    local head = model:FindFirstChild("Head")
    local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
    if not head or not head:IsA("BasePart") or not torso or not torso:IsA("BasePart") then return false end
    local count = 0
    for _, name in ipairs(allSaveParts) do
        local part = model:FindFirstChild(name)
        if name ~= "HumanoidRootPart" and part and part:IsA("BasePart") then count = count + 1 end
    end
    return count >= 6
end
local function cloneVisualSource(source)
    if not isRig(source) then error("Unsupported rig: need Head, Torso/UpperTorso and at least six body parts.") end
    if not source.Archivable then error("Source Archivable is false. Enable it in your own place and retry.") end
    for _, item in ipairs(source:GetDescendants()) do
        if item:IsA("BasePart") and item.ClassName ~= "Part" and item.ClassName ~= "MeshPart" and item.ClassName ~= "UnionOperation" then
            error("Unsupported visual part class: " .. item.ClassName .. " (" .. item.Name .. "). Convert it to a MeshPart in your own place.")
        end
        if (visualClasses[item.ClassName] or item:IsA("Folder")) and not item.Archivable then
            error("Visual object cannot be cloned (Archivable=false): " .. item.Name)
        end
    end
    local clone = source:Clone()
    if not clone then error("Could not clone the source. Nothing was saved.") end
    clone.Parent = nil
    -- These objects are never run or written to the output; the clone stays unparented.
    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("LuaSourceContainer") or item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then item:Destroy() end
        if item:IsA("Attachment") then item:SetAttribute("SaveID", nil) end
    end
    return clone
end
local function normalizeBodyKeys(data)
    for from, to in pairs(R6_ALIASES) do
        if data[from] then
            data[to] = data[to] or {Children = {}}
            for _, child in ipairs(data[from].Children or {}) do table.insert(data[to].Children, child) end
            data[from] = nil
        end
    end
    return data
end
local function collectPlayerAuras(character)
    if not character then return nil end
    local auras = {}
    -- Player characters are commonly non-archivable; clone each aura's body part.
    for _, originalPart in ipairs(character:GetChildren()) do
        if originalPart:IsA("BasePart") then
            local hasAura = false
            for _, child in ipairs(originalPart:GetChildren()) do
                if (child:IsA("Attachment") or child:IsA("ParticleEmitter")) and child.Name:lower():find("aura", 1, true) then hasAura = true end
            end
            if hasAura then
                if not originalPart.Archivable then error("Aura body part has Archivable=false: " .. originalPart.Name) end
                for _, item in ipairs(originalPart:GetDescendants()) do
                    if (visualClasses[item.ClassName] or item:IsA("Folder")) and not item.Archivable then error("Aura visual has Archivable=false: " .. item.Name) end
                end
                local part = originalPart:Clone()
                if not part then error("Could not clone aura body part: " .. originalPart.Name) end
                part.Parent = nil
                local ok, result = pcall(function()
                    for _, item in ipairs(part:GetDescendants()) do
                        if visualClasses[item.ClassName] and not item.Archivable then error("Aura visual has Archivable=false: " .. item.Name) end
                        if item:IsA("Attachment") then item:SetAttribute("SaveID", nil) end
                    end
                    for _, child in ipairs(part:GetChildren()) do
                        if (child:IsA("Attachment") or child:IsA("ParticleEmitter")) and child.Name:lower():find("aura", 1, true) then
                            local aura = saveInstance(child, part)
                            aura.Properties.ParentPartName = R6_ALIASES[part.Name] or part.Name
                            table.insert(auras, aura)
                        end
                    end
                end)
                part:Destroy()
                if not ok then error(result) end
            end
        end
    end
    return #auras > 0 and {Children = auras} or nil
end
local function captureData(source, auraCharacter)
    local clone = cloneVisualSource(source)
    local ok, data = pcall(buildBaseStandModelData, clone)
    clone:Destroy()
    if not ok then error("Visual serialization failed: " .. tostring(data)) end
    normalizeBodyKeys(data)
    local geometry = 0
    local function count(part)
        if part.ClassName == "MeshPart" or part.ClassName == "Part" or part.ClassName == "UnionOperation" then geometry = geometry + 1 end
        for _, child in ipairs(part.Children or {}) do count(child) end
    end
    for _, slot in pairs(data) do count(slot) end
    if geometry < 1 then error("No supported visible geometry found. Nothing was saved.") end
    if auraCharacter then data._PlayerAuras = collectPlayerAuras(auraCharacter) end
    return data, geometry
end
local function saveCapture(source, name, stand, auraCharacter)
    checkFilesystem()
    name, stand = trim(name), trim(stand)
    if name == "" or #name > 160 then error("Enter a skin name (1-160 bytes).") end
    if stand == "" or #stand > 120 then error("Enter the base Stand name (1-120 bytes).") end
    ensureDirectories()
    local index, previousIndex = readIndex()
    local data, geometry = captureData(source, auraCharacter)
    local json = HttpService:JSONEncode(data)
    local encoded = encodeData(json)
    if decodeData(encoded) ~= json then error("SSOC codec verification failed.") end
    local id, file
    for _ = 1, 8 do
        id = HttpService:GenerateGUID(false)
        if not safeID(id) then error("GUID returned an invalid filename.") end
        file = "ssoc_skins/captured-" .. id .. ".ssoc"
        if not environment.isfile(file) then break end
        file = nil
    end
    if not file then error("Could not reserve a unique filename. No captures overwritten.") end
    environment.writefile(file, encoded)
    if environment.readfile(file) ~= encoded then error("Model readback failed; index was not changed: " .. file) end
    local entry = {id = id, name = name, stand = stand, file = file,
        sourcePlaceId = game.PlaceId, sourceModel = source:GetFullName(), capturedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")}
    table.insert(index.entries, entry)
    validateIndex(index)
    local newJSON = HttpService:JSONEncode(index)
    local temporary = "thebest/captured-skins/index-" .. id .. ".tmp"
    environment.writefile(temporary, newJSON)
    if environment.readfile(temporary) ~= newJSON then error("Temporary index verification failed; original preserved.") end
    validateIndex(HttpService:JSONDecode(environment.readfile(temporary)))
    -- Refuse a stale update if another capture window changed the index meanwhile.
    local currentExists = environment.isfile(INDEX)
    if (previousIndex == nil and currentExists) or (previousIndex ~= nil and (not currentExists or environment.readfile(INDEX) ~= previousIndex)) then
        error("Index changed during capture. Model file kept; refresh and retry.")
    end
    if previousIndex then
        local backup = "thebest/captured-skins/index-before-" .. id .. ".json"
        environment.writefile(backup, previousIndex)
        if environment.readfile(backup) ~= previousIndex then error("Index backup failed; original preserved.") end
    end
    local commitOK, commitError = pcall(function()
        environment.writefile(INDEX, newJSON)
        if environment.readfile(INDEX) ~= newJSON then error("Index readback mismatch") end
        validateIndex(HttpService:JSONDecode(environment.readfile(INDEX)))
    end)
    if not commitOK then
        local restored = false
        if previousIndex then
            restored = pcall(function()
                environment.writefile(INDEX, previousIndex)
                assert(environment.readfile(INDEX) == previousIndex, "Index restore readback failed")
            end)
        end
        error("Index commit failed: " .. tostring(commitError) .. (restored and "; previous index restored." or "; verified model and temporary index retained."))
    end
    return entry, #index.entries, geometry
end
local function detectedStand(model)
    local named = model and model:FindFirstChild("Stand Name")
    if named then
        local ok, value = pcall(function() return named.Value end)
        if ok and type(value) == "string" and trim(value) ~= "" then return value end
    end
    local stats = LocalPlayer:FindFirstChild("PlayerStats")
    local stand = stats and stats:FindFirstChild("Stand")
    if stand then
        local ok, value = pcall(function() return stand.Value end)
        if ok and type(value) == "string" then return value end
    end
    return ""
end
local API = {saveCapture = saveCapture, captureData = captureData, validateIndex = validateIndex,
    encodeData = encodeData, decodeData = decodeData, isRig = isRig, detectedStand = detectedStand}
if environment.__THEBEST_CAPTURE_TEST then return API end

local previous = environment[SESSION_KEY]
if type(previous) == "table" and type(previous.cleanup) == "function" then pcall(previous.cleanup) end
local session = {connections = {}, closed = false}
environment[SESSION_KEY] = session
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior = "TheBestSkinCapture14", false, Enum.ZIndexBehavior.Sibling
local parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
if not parent then error("PlayerGui is not available. Join your place fully, then retry.") end
gui.Parent = parent
session.gui = gui
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(session.connections, connection)
    return connection
end
function session.cleanup()
    if session.closed then return end
    session.closed = true
    for _, connection in ipairs(session.connections) do connection:Disconnect() end
    table.clear(session.connections)
    if gui then gui:Destroy() end
    if environment[SESSION_KEY] == session then environment[SESSION_KEY] = nil end
end
local function create(class, props, target)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = target
    return object
end
local orange = Color3.fromRGB(239, 132, 36)
local panel = create("Frame", {Name="Panel", Size=UDim2.fromOffset(410, 374), Position=UDim2.new(0.5,-205,0.5,-187), BackgroundColor3=Color3.fromRGB(25,26,29), BorderSizePixel=0}, gui)
create("UICorner", {CornerRadius=UDim.new(0,10)}, panel)
create("UIStroke", {Color=orange, Thickness=1}, panel)
local title = create("TextLabel", {Size=UDim2.new(1,-52,0,40), Position=UDim2.fromOffset(12,0), BackgroundTransparency=1, Text="TheBest Skin Capture", TextColor3=orange, TextSize=19, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, Active=true}, panel)
local function button(text, x, y, width)
    local item = create("TextButton", {Size=UDim2.fromOffset(width,34), Position=UDim2.fromOffset(x,y), BackgroundColor3=orange, BorderSizePixel=0, Text=text, TextColor3=Color3.fromRGB(22,22,22), TextSize=14, Font=Enum.Font.GothamBold}, panel)
    create("UICorner", {CornerRadius=UDim.new(0,6)}, item)
    return item
end
local close = button("×", 368, 7, 30)
close.Size = UDim2.fromOffset(30,28)
local refresh = button("Обновить модели", 12, 48, 186)
local cycle = button("Следующая →", 212, 48, 186)
local selectedLabel = create("TextLabel", {Size=UDim2.fromOffset(386,44), Position=UDim2.fromOffset(12,86), BackgroundTransparency=1, Text="", TextColor3=Color3.fromRGB(232,232,232), TextWrapped=true, TextSize=13, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left}, panel)
local function input(placeholder, y)
    local box = create("TextBox", {Size=UDim2.fromOffset(386,36), Position=UDim2.fromOffset(12,y), BackgroundColor3=Color3.fromRGB(40,41,45), BorderSizePixel=0, PlaceholderText=placeholder, Text="", ClearTextOnFocus=false, TextColor3=Color3.fromRGB(245,245,245), PlaceholderColor3=Color3.fromRGB(153,153,153), TextSize=14, Font=Enum.Font.Gotham}, panel)
    create("UICorner", {CornerRadius=UDim.new(0,6)}, box)
    return box
end
local nameBox = input("Название твоего скина", 136)
local standBox = input("Базовый Stand (например, Star Platinum)", 182)
local auraButton = button("Аура игрока: ВКЛ", 12, 228, 186)
local save = button("Сохранить скин", 212, 228, 186)
local status = create("TextLabel", {Size=UDim2.fromOffset(386,88), Position=UDim2.fromOffset(12,272), BackgroundTransparency=1, Text="", TextColor3=Color3.fromRGB(204,204,204), TextWrapped=true, TextSize=13, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top}, panel)
local candidates, selected, busy, includeAura = {}, 1, false, true
local function say(message, failed)
    if session.closed then return end
    status.Text = message
    status.TextColor3 = failed and Color3.fromRGB(255,141,120) or Color3.fromRGB(204,204,204)
end
local function ownCharacter()
    local living = workspace:FindFirstChild("Living")
    return (living and living:FindFirstChild(LocalPlayer.Name)) or LocalPlayer.Character
end
local function showSelected()
    local model = candidates[selected]
    selectedLabel.Text = model and (tostring(selected) .. "/" .. #candidates .. "  " .. model:GetFullName()) or "Модель не найдена: призови Stand и нажми «Обновить»."
    if model then
        standBox.Text = detectedStand(model)
        if trim(nameBox.Text) == "" then nameBox.Text = model.Name == "StandMorph" and standBox.Text or model.Name end
    end
end
local function refreshCandidates()
    if busy then return end
    candidates, selected = {}, 1
    local character = ownCharacter()
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
    local seen, scores = {}, {}
    local function add(model, priority)
        if not model or seen[model] or not isRig(model) then return end
        seen[model] = true
        local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
        local distance = root and (torso.Position - root.Position).Magnitude or math.huge
        if priority == nil and distance > 100 then return end
        scores[model] = priority or (1000 + distance)
        table.insert(candidates, model)
    end
    if character then
        add(character:FindFirstChild("StandMorph"), 0)
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Model") then add(child, child:FindFirstChild("Stand Name") and 1 or 50) end
        end
    end
    -- Explicit refresh only. No heartbeat scanning or remote calls.
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Model") and object ~= character and object.Name ~= "Camera" then add(object) end
    end
    table.sort(candidates, function(a,b)
        if scores[a] == scores[b] then return a:GetFullName() < b:GetFullName() end
        return scores[a] < scores[b]
    end)
    showSelected()
    say("Моделей рядом: " .. #candidates .. ". Выбери свою, проверь базовый Stand и сохрани.")
end
connect(close.MouseButton1Click, session.cleanup)
connect(refresh.MouseButton1Click, refreshCandidates)
connect(cycle.MouseButton1Click, function()
    if busy or #candidates == 0 then return end
    selected = selected % #candidates + 1
    showSelected()
end)
connect(auraButton.MouseButton1Click, function()
    includeAura = not includeAura
    auraButton.Text = includeAura and "Аура игрока: ВКЛ" or "Аура игрока: ВЫКЛ"
end)
connect(save.MouseButton1Click, function()
    if busy then return end
    local model = candidates[selected]
    if not model or not model.Parent then say("Сначала призови Stand и обнови модели.", true); return end
    busy = true
    save.Text = "Сохраняю…"
    local character = ownCharacter()
    local auraSource = includeAura and character and model:IsDescendantOf(character) and character or nil
    local ok, entry, count, geometry = pcall(saveCapture, model, nameBox.Text, standBox.Text, auraSource)
    busy = false
    if session.closed then return end
    save.Text = "Сохранить скин"
    if ok then say("Сохранено: " .. entry.name .. "\nВсего скинов: " .. count .. "; деталей: " .. geometry .. ".\n" .. entry.file)
    else say(tostring(entry), true) end
end)
local dragging, dragStart, panelStart
connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, panelStart = true, input.Position, panel.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset+delta.X, panelStart.Y.Scale, panelStart.Y.Offset+delta.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
refreshCandidates()
local filesOK, filesError = pcall(checkFilesystem)
if not filesOK then say(tostring(filesError), true) end
return API
