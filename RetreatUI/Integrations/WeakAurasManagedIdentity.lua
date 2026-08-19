local RUI = RetreatUI
if not RUI then return end

local function EnsureDB()
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.weakAurasManaged = RetreatUIDB.weakAurasManaged or {}
  return RetreatUIDB.weakAurasManaged
end

local function SafePart(value)
  value = tostring(value or "Unknown")
  value = value:gsub("[%c]", " "):gsub("%s+", " ")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then value = "Unknown" end
  return value
end

function RUI:GetManagedWeakAuraID(entry)
  if type(entry) ~= "table" then return nil end
  local className = SafePart(entry.className or (self.GetDetectedClass and self:GetDetectedClass()) or "Class")
  local spellName = SafePart(entry.name or "Tracker")
  local spellID = tonumber(entry.spellID)
  if spellID and spellID > 0 then
    return "RetreatUI - " .. className .. " - " .. spellName .. " [" .. tostring(spellID) .. "]"
  end
  return "RetreatUI - " .. className .. " - " .. spellName
end

function RUI:ResolveManagedWeakAuraIdentity(entry, wa)
  if type(entry) ~= "table" or type(entry.key) ~= "string" or entry.key == "" then
    return nil, nil, false, "tracker has no stable key"
  end
  if type(wa) ~= "table" or type(wa.GenerateUniqueID) ~= "function" then
    return nil, nil, false, "WeakAuras identity API is unavailable"
  end

  local id = self:GetManagedWeakAuraID(entry)
  if not id then return nil, nil, false, "managed aura id could not be built" end

  local existing
  if type(wa.GetData) == "function" then
    local ok, value = pcall(wa.GetData, id)
    if ok and type(value) == "table" then existing = value end
  end

  local db = EnsureDB()
  local className = tostring(entry.className or (self.GetDetectedClass and self:GetDetectedClass()) or "Unknown")
  db[className] = db[className] or {}
  local record = db[className][entry.key]

  local uid = existing and existing.uid
  if type(uid) ~= "string" or uid == "" then uid = record and record.uid end
  if type(uid) ~= "string" or uid == "" then
    local ok, value = pcall(wa.GenerateUniqueID)
    if not ok or type(value) ~= "string" or value == "" then
      return nil, nil, false, "WeakAuras could not generate a managed aura UID"
    end
    uid = value
  end

  db[className][entry.key] = {
    id = id,
    uid = uid,
    spellID = tonumber(entry.spellID),
    name = entry.name,
  }

  return id, uid, existing ~= nil
end

RUI._weakAurasManagedIdentity = true
