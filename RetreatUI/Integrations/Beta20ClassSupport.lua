local RUI = RetreatUI
if not RUI then return end

-- beta.20 classes are data packages, not native HUD renderers. A supported CoA
-- class therefore requires a ready Definition.lua and a registered Data.lua;
-- classModules/HUD.lua are deliberately not part of the support contract.

function RUI:GetSupportedClassNames()
  local result = {}
  for className, definition in pairs(self.classRegistry or {}) do
    if type(definition) == "table"
      and definition.ready == true
      and self.spellDatabase
      and self.spellDatabase[className] then
      result[#result + 1] = className
    end
  end
  table.sort(result)
  return result
end

function RUI:IsSupportedCharacter()
  local compatible = self:IsClassPackageCompatible()
  if not compatible then return false end
  local className = self:GetDetectedClass()
  local definition = self.classRegistry and self.classRegistry[className]
  local database = self.spellDatabase and self.spellDatabase[className]
  return definition ~= nil and definition.ready == true and database ~= nil
end

function RUI:GetUnsupportedMessage()
  local compatible, packageMessage = self:IsClassPackageCompatible()
  if not compatible then
    return tostring(packageMessage) .. ". Enable both bundled addon folders and reload the UI."
  end
  local className = self:GetDetectedClass()
  if self.classRegistry and self.classRegistry[className] then
    return "RetreatUI does not have beta.20 CoA data for " .. tostring(className) .. "."
  end
  return "RetreatUI could not identify a supported Conquest of Azeroth class on this character."
end

RUI._beta20ClassSupportLoaded = true
RUI._beta20ClassSupportRevision = 20
