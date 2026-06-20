local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService('HttpService')

pcall(function()
    setthreadidentity(2)
end)

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local LoadModule = Fsys.load

local ClientData = LoadModule("ClientData")
local RouterClient = LoadModule("RouterClient")
local UIManager = LoadModule("UIManager")
local InventoryDB = LoadModule("InventoryDB")
local KindDB = LoadModule("KindDB")
local DownloadClient = LoadModule("DownloadClient")
local AnimationManager = LoadModule("AnimationManager")
local PetRigs = LoadModule("new:PetRigs")
local AilmentsClient = LoadModule("new:AilmentsClient")
local AilmentsDB = LoadModule("new:AilmentsDB")
local CharWrapperClient = LoadModule("CharWrapperClient")

_G.InventoryDB = InventoryDB

local TradeHistoryApp = UIManager.apps.TradeHistoryApp
local TradeApp = UIManager.apps.TradeApp

if TradeHistoryApp._ORIGINAL_create_trade_frame then
   TradeHistoryApp._create_trade_frame = TradeHistoryApp._ORIGINAL_create_trade_frame
end
if TradeApp._ORIGINAL_change_local_trade_state then
   TradeApp._change_local_trade_state = TradeApp._ORIGINAL_change_local_trade_state
end
if TradeApp._ORIGINAL_overwrite_local_trade_state then
   TradeApp._overwrite_local_trade_state = TradeApp._ORIGINAL_overwrite_local_trade_state
end

TradeHistoryApp._ORIGINAL_create_trade_frame = TradeHistoryApp._create_trade_frame
TradeApp._ORIGINAL_change_local_trade_state = TradeApp._change_local_trade_state
TradeApp._ORIGINAL_overwrite_local_trade_state = TradeApp._overwrite_local_trade_state

local tradeCache = {}
local currentTradeItems = nil

function TradeApp._change_local_trade_state(self, changes, ...)
   local currentState = TradeApp.local_trade_state

   if currentState and currentState.trade_id then
       local isSender = currentState.sender == LocalPlayer
       local isRecipient = currentState.recipient == LocalPlayer

       if isSender and changes.sender_offer and changes.sender_offer.items then
           tradeCache[currentState.trade_id] = {
               items = table.clone(changes.sender_offer.items),
               isSender = true
           }
           currentTradeItems = changes.sender_offer.items
       elseif isRecipient and changes.recipient_offer and changes.recipient_offer.items then
           tradeCache[currentState.trade_id] = {
               items = table.clone(changes.recipient_offer.items),
               isSender = false
           }
           currentTradeItems = changes.recipient_offer.items
       end
   end

   return TradeApp._ORIGINAL_change_local_trade_state(self, changes, ...)
end

function TradeApp._overwrite_local_trade_state(self, tradeState, ...)
   if tradeState then
       local isSender = tradeState.sender == LocalPlayer
       local isRecipient = tradeState.recipient == LocalPlayer

       if isSender and tradeState.sender_offer and currentTradeItems then
           tradeState.sender_offer.items = currentTradeItems
       elseif isRecipient and tradeState.recipient_offer and currentTradeItems then
           tradeState.recipient_offer.items = currentTradeItems
       end
   else
       currentTradeItems = nil
       if TradeApp._last_trade_id then
           tradeCache[TradeApp._last_trade_id] = nil
           TradeApp._last_trade_id = nil
       end
   end

   return TradeApp._ORIGINAL_overwrite_local_trade_state(self, tradeState, ...)
end

function TradeHistoryApp._create_trade_frame(self, tradeData, ...)
   if tradeData.trade_id and tradeCache[tradeData.trade_id] then
       local cachedData = tradeCache[tradeData.trade_id]
       local modifiedData = table.clone(tradeData)

       if cachedData.isSender then
           modifiedData.sender_items = table.clone(cachedData.items)
       else
           modifiedData.recipient_items = table.clone(cachedData.items)
       end

       return TradeHistoryApp._ORIGINAL_create_trade_frame(self, modifiedData, ...)
   end

   return TradeHistoryApp._ORIGINAL_create_trade_frame(self, tradeData, ...)
end

local HighTierPets = {
    "Shadow Dragon", "Bat Dragon", "Frost Dragon", "Giraffe", "Owl", "Parrot", "Crow",
    "Evil Unicorn", "Arctic Reindeer", "Hedgehog", "Dalmatian", "Turtle", "Kangaroo",
    "Lion", "Elephant", "Blazing Lion", "African Wild Dog", "Flamingo", "Diamond Butterfly",
    "Mini Pig", "Caterpillar", "Albino Monkey", "Candyfloss Chick", "Pelican", "Blue Dog",
    "Pink Cat", "Haetae", "Peppermint Penguin", "Winged Tiger", "Sugar Glider",
    "Shark Puppy", "Goat", "Sheeeeep", "Lion Cub", "Nessie", "Frostbite Bear",
    "Balloon Unicorn", "Honey Badger", "Hot Doggo", "Crocodile", "Hare", "Ram", "Yeti",
    "Meerkat", "Jellyfish", "Happy Clown", "Orchid Butterfly", "Many Mackerel",
    "Strawberry Shortcake Bat Dragon", "Zombie Buffalo", "Fairy Bat Dragon",
    "Chocolate Chip Bat Dragon", "Cow", "Dragonfruit Fox", "Monkey King", "Cryptid",
    "Undead Jousting Horse", "Mermicorn", "Frost Unicorn", "Irish Water Spaniel",
    "Jekyll Hydra", "Papa Moose", "Strawberry Penguin", "Bush Elephant", "Cupid Dragon",
    "Black-Chested Pheasant", "Alpaca", "Field Mouse", "Pineapple Owl", "Owlbear",
    "Tio De Nadal", "Pig", "Royal Mistletroll", "Pirate Ghost Capuchin Monkey",
    "Moose Calf", "Vampire Dragon", "Shrew", "Mechapup", "Bald Eagle",
    "Ring-Tailed Lemur", "Tortuga De La Isla", "Werewolf", "Puffin", "Fallow Deer",
    "Caelum Cervi", "Diamond Amazon", "Sea Slug", "Sugar Axolotl", "Purple Butterfly",
    "Grim Dragon", "Brown Bear", "Polar Bear", "Sakura Spirit", "Platypus", "Groundhog",
    "Lava Dragon", "Glacier Moth", "Emperor Gorilla", "2D Kitty", "Hyena",
    "Arctic Dusk Dragon", "Alley Cat", "Siamese Cat", "Phantom Dragon",
    "Christmas Pudding Pup", "Glacier Kitsune", "Giant Gold Scarab", "Diamond Albatross"
}

local SpawnedPets = {}
local PetModelCache = {}
local EquippedPet = nil
local CurrentRideId = nil
local RideAnimationTrack = nil
local PetAilmentsCache = {}
local SpawnedItems = {}

local function GenerateUniquePetName()
    local prefixes = {"★", "☆", "♡", "☁️", "✨", "🍓", "🌸", "🍯", "☕", "🌙", "🌈", "❄️", "🫧", "🍬", "🍪", "🥛"}
    local names = {"Shadow", "Blaze", "Frost", "Thunder", "Moon", "Star", "Sky", "Ocean", "River", "Storm", 
                   "Ember", "Ash", "Dusk", "Dawn", "Night", "Day", "Sun", "Wind", "Rain", "Snow", "Ice", "Fire",
                   "Nova", "Cosmo", "Galaxy", "Orbit", "Comet", "Meteor", "Aurora", "Nebula", "Crystal", "Gem",
                   "Ruby", "Sapphire", "Emerald", "Diamond", "Gold", "Silver", "Mystic", "Magic", "Enchant"}
    
    local usePrefix = math.random(1, 3) == 1
    local name = names[math.random(1, #names)]
    
    if usePrefix then
        return prefixes[math.random(1, #prefixes)] .. name
    else
        return name .. " " .. prefixes[math.random(1, #prefixes)]
    end
end

local NewnessGroups = {
    mega_neon_flyable_rideable = 990000,
    mega_neon_flyable = 980000,
    mega_neon_rideable = 970000,
    mega_neon = 960000,
    neon_flyable_rideable = 950000,
    neon_flyable = 940000,
    neon_rideable = 930000,
    neon = 920000,
    flyable_rideable = 910000,
    flyable = 900000,
    rideable = 890000,
    regular = 880000
}

local function GetPropertyGroup(properties)
    local isMega = properties.mega_neon or false
    local isNeon = properties.neon or false
    local canFly = properties.flyable or false
    local canRide = properties.rideable or false

    if isMega then
        if canFly and canRide then return "mega_neon_flyable_rideable"
        elseif canFly then return "mega_neon_flyable"
        elseif canRide then return "mega_neon_rideable"
        else return "mega_neon" end
    elseif isNeon then
        if canFly and canRide then return "neon_flyable_rideable"
        elseif canFly then return "neon_flyable"
        elseif canRide then return "neon_rideable"
        else return "neon" end
    else
        if canFly and canRide then return "flyable_rideable"
        elseif canFly then return "flyable"
        elseif canRide then return "rideable"
        else return "regular" end
    end
end

local function UpdateClientData(dataPath, modifier)
    local identity = get_thread_identity and get_thread_identity() or 8
    set_thread_identity(2)
    local currentData = ClientData.get(dataPath)
    local clonedData = table.clone(currentData)
    local result = modifier(clonedData)
    ClientData.predict(dataPath, result)
    set_thread_identity(identity)
    return result
end

local function GenerateUniqueID()
    return HttpService:GenerateGUID(false)
end

local function FindInTable(array, checker)
    for index, value in pairs(array) do
        if checker(value, index) then
            return index
        end
    end
    return nil
end

local originalGetServer = ClientData.get_server

function ClientData.get_server(player, key, ...)
    local data = originalGetServer(player, key, ...)

    if key == "ailments_manager" and player == LocalPlayer then
        local ailmentsData = {}
        if data then
            for k, v in pairs(data) do
                ailmentsData[k] = type(v) == "table" and table.clone(v) or v
            end
        end
        
        ailmentsData.ailments = ailmentsData.ailments or {}
        
        for petId, _ in pairs(SpawnedPets) do
            if PetAilmentsCache[petId] then
                ailmentsData.ailments[petId] = PetAilmentsCache[petId]
            else
                local ailmentTypes = {}
                for kind, _ in pairs(AilmentsDB) do
                    if kind ~= "at_work" and kind ~= "mystery" and kind ~= "walking" then
                        table.insert(ailmentTypes, kind)
                    end
                end

                local ailmentCount = math.random(2, 4)
                local petAilments = {}
                local usedTypes = {}

                for i = 1, math.min(ailmentCount, #ailmentTypes) do
                    local ailmentKind
                    repeat
                        ailmentKind = ailmentTypes[math.random(1, #ailmentTypes)]
                    until not usedTypes[ailmentKind]
                    usedTypes[ailmentKind] = true

                    local ailmentId = GenerateUniqueID()
                    petAilments[ailmentId] = {
                        components = {},
                        created_timestamp = os.time(),
                        kind = ailmentKind,
                        progress = 0,
                        rate = 0,
                        rate_timestamp = os.time(),
                        sort_order = i * 100
                    }
                end

                PetAilmentsCache[petId] = petAilments
                ailmentsData.ailments[petId] = petAilments
            end
        end

        return ailmentsData
    end

    return data
end

local function FetchPetModel(petKind)
    if PetModelCache[petKind] then
        return PetModelCache[petKind]
    end
    local model = DownloadClient.promise_download_copy("Pets", petKind):expect()
    PetModelCache[petKind] = model
    return model
end

local function ApplyNeonVisuals(petModel, petData)
    local modelInstance = petModel:FindFirstChild("PetModel")
    if modelInstance and (petData.properties.neon or petData.properties.mega_neon) then
        local petKindData = KindDB[petData.id]
        for partName, partProps in pairs(petKindData.neon_parts) do
            local geoPart = PetRigs.get(modelInstance).get_geo_part(modelInstance, partName)
            if geoPart then
                geoPart.Material = partProps.Material
                geoPart.Color = partProps.Color
            end
        end
    end
end

local function RegisterPetWrapper(wrapperData)
    UpdateClientData("pet_char_wrappers", function(wrappers)
        wrapperData.unique = #wrappers + 1
        wrapperData.index = #wrappers + 1
        wrappers[#wrappers + 1] = wrapperData
        return wrappers
    end)
end

local function RegisterPetState(stateManager)
    UpdateClientData("pet_state_managers", function(managers)
        managers[#managers + 1] = stateManager
        return managers
    end)
end

local function RemovePetWrapper(petUniqueId)
    UpdateClientData("pet_char_wrappers", function(wrappers)
        local wrapperIndex = FindInTable(wrappers, function(w)
            return w.pet_unique == petUniqueId
        end)
        if wrapperIndex then
            table.remove(wrappers, wrapperIndex)
            for i = wrapperIndex, #wrappers do
                wrappers[i].unique = i
                wrappers[i].index = i
            end
        end
        return wrappers
    end)
end

local function RemovePetState(petUniqueId)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    UpdateClientData("pet_state_managers", function(managers)
        local managerIndex = FindInTable(managers, function(m)
            return m.char == pet.model
        end)
        if managerIndex then
            table.remove(managers, managerIndex)
        end
        return managers
    end)
end

local function ClearPetStates(petUniqueId)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    UpdateClientData("pet_state_managers", function(managers)
        local managerIndex = FindInTable(managers, function(m)
            return m.char == pet.model
        end)
        if managerIndex then
            local updated = table.clone(managers)
            updated[managerIndex] = table.clone(updated[managerIndex])
            updated[managerIndex].states = {}
            return updated
        end
        return managers
    end)
end

local function SetPetState(petUniqueId, stateId)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    UpdateClientData("pet_state_managers", function(managers)
        local managerIndex = FindInTable(managers, function(m)
            return m.char == pet.model
        end)
        if managerIndex then
            local updated = table.clone(managers)
            updated[managerIndex] = table.clone(updated[managerIndex])
            updated[managerIndex].states = {{ id = stateId }}
            return updated
        end
        return managers
    end)
end

local function ClearPlayerStates()
    UpdateClientData("state_manager", function(stateManager)
        local updated = table.clone(stateManager)
        updated.states = {}
        updated.is_sitting = false
        return updated
    end)
end

local function SetPlayerState(stateId)
    UpdateClientData("state_manager", function(stateManager)
        local updated = table.clone(stateManager)
        updated.states = {{ id = stateId }}
        updated.is_sitting = true
        return updated
    end)
end

local function AttachRideConstraint(petModel)
    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart then return false end

    local ridePos = petModel:FindFirstChild("RidePosition", true)
    if not ridePos then return false end

    local sourceAttach = Instance.new("Attachment")
    sourceAttach.Parent = ridePos
    sourceAttach.Position = Vector3.new(0, 1.237, 0)
    sourceAttach.Name = "SourceAttachment"

    local rigidConstraint = Instance.new("RigidConstraint")
    rigidConstraint.Name = "StateConnection"
    rigidConstraint.Attachment0 = sourceAttach
    rigidConstraint.Attachment1 = character.PrimaryPart.RootAttachment
    rigidConstraint.Parent = character

    return true
end

local function DismountPet()
    if not CurrentRideId then return end

    local pet = SpawnedPets[CurrentRideId]
    if pet and pet.model then
        if RideAnimationTrack then
            RideAnimationTrack:Stop()
            RideAnimationTrack:Destroy()
            RideAnimationTrack = nil
        end

        local sourceAttach = pet.model:FindFirstChild("SourceAttachment", true)
        if sourceAttach then sourceAttach:Destroy() end

        local character = LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part:GetAttribute("HaveMass") then
                    part.Massless = false
                end
            end
        end

        ClearPetStates(CurrentRideId)
        ClearPlayerStates()
        pet.model:ScaleTo(1)
    end
    CurrentRideId = nil
end

local function MountPet(petUniqueId, playerState, petState)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart or not character:FindFirstChild("Humanoid") then return end

    DismountPet()
    CurrentRideId = petUniqueId

    SetPetState(petUniqueId, petState)
    SetPlayerState(playerState)
    pet.model:ScaleTo(2)
    AttachRideConstraint(pet.model)

    RideAnimationTrack = character.Humanoid.Animator:LoadAnimation(AnimationManager.get_track("PlayerRidingPet"))
    character.Humanoid.Sit = true

    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Massless == false then
            part.Massless = true
            part:SetAttribute("HaveMass", true)
        end
    end

    RideAnimationTrack:Play()
end

local function RidePet(petUniqueId)
    MountPet(petUniqueId, "PlayerRidingPet", "PetBeingRidden")
end

local function FlyPet(petUniqueId)
    MountPet(petUniqueId, "PlayerFlyingPet", "PetBeingFlown")
end

local function UnequipPet(petData)
    local pet = SpawnedPets[petData.unique]
    if not pet or not pet.model then return end

    if CurrentRideId == petData.unique then
        DismountPet()
    end

    RemovePetWrapper(petData.unique)
    RemovePetState(petData.unique)
    pet.model:Destroy()
    pet.model = nil

    if EquippedPet and EquippedPet.unique == petData.unique then
        EquippedPet = nil
    end

    PetAilmentsCache[petData.unique] = nil
    task.wait(0.15)
    AilmentsClient.on_ailments_changed(LocalPlayer)
end

local function EquipPet(petData)
    if petData.category ~= "pets" then return end

    if EquippedPet then
        UnequipPet(EquippedPet)
    end

    for _, wrapper in pairs(ClientData.get("pet_char_wrappers")) do
        if wrapper.controller == LocalPlayer then
            RouterClient.get("ToolAPI/Unequip"):InvokeServer(wrapper.pet_unique)
        end
    end

    if not SpawnedPets[petData.unique] then
        SpawnedPets[petData.unique] = { data = petData, model = nil }
    end

    local petModel = FetchPetModel(petData.kind):Clone()
    petModel.Parent = workspace
    SpawnedPets[petData.unique].model = petModel
    ApplyNeonVisuals(petModel, petData)

    EquippedPet = petData

    task.defer(function()
        RegisterPetWrapper({
            char = petModel,
            mega_neon = petData.properties.mega_neon or false,
            neon = petData.properties.neon or false,
            player = LocalPlayer,
            entity_controller = LocalPlayer,
            controller = LocalPlayer,
            rp_name = petData.properties.rp_name or "",
            pet_trick_level = petData.properties.pet_trick_level or 0,
            pet_unique = petData.unique,
            pet_id = petData.id,
            location = {
                full_destination_id = "housing",
                destination_id = "housing",
                house_owner = LocalPlayer
            },
            pet_progression = {
                age = petData.properties.age or math.random(1, 6),
                percentage = math.random(0, 99) / 100
            },
            are_colors_sealed = false,
            is_pet = true,
        })

        RegisterPetState({
            char = petModel,
            player = LocalPlayer,
            store_key = "pet_state_managers",
            is_sitting = false,
            chars_connected_to_me = {},
            states = {}
        })
        task.wait(0.15)
        AilmentsClient.on_ailments_changed(LocalPlayer)
    end)
end

local NextToyOrder = 60000

local function CreateInventoryItem(itemId, category, properties)
    local uniqueId = GenerateUniqueID()
    local itemKindData = KindDB[itemId]

    if not itemKindData then
        warn("Item not found: " .. itemId)
        return nil
    end

    properties = properties or {}
    local newnessValue = NextToyOrder

    if category == "pets" then
        local groupKey = GetPropertyGroup(properties)
        NewnessGroups[groupKey] = NewnessGroups[groupKey] - 1
        newnessValue = NewnessGroups[groupKey]

        if not properties.ailments_completed then
            properties.ailments_completed = 0
        end

        if not properties.rp_name or properties.rp_name == "" then
            properties.rp_name = GenerateUniquePetName()
        end
    else
        NextToyOrder = NextToyOrder - 1
        newnessValue = NextToyOrder
    end

    local itemData = {
        unique = uniqueId,
        category = category,
        id = itemId,
        kind = itemKindData.kind,
        newness_order = newnessValue,
        properties = properties,
        _source = "blueprint.lua"
    }

    local identity = get_thread_identity and get_thread_identity() or 8
    set_thread_identity(2)
    local inventory = ClientData.get("inventory")
    if inventory and inventory[category] then
        inventory[category][uniqueId] = itemData
    end
    set_thread_identity(identity)

    if category == "pets" then
        SpawnedPets[uniqueId] = { data = itemData, model = nil }
    end
    
    SpawnedItems[uniqueId] = true

    task.defer(function()
        if UIManager and UIManager.apps and UIManager.apps.BackpackApp then
            UIManager.apps.BackpackApp:refresh_rendered_items()
        end
    end)

    return itemData
end

local function DeleteAllSpawnedPets()
    local identity = get_thread_identity and get_thread_identity() or 8
    set_thread_identity(2)
    
    local inventory = ClientData.get("inventory")
    local removed = 0
    
    if inventory and inventory.pets then
        for uniqueId, _ in pairs(SpawnedItems) do
            if inventory.pets[uniqueId] and inventory.pets[uniqueId]._source == "blueprint.lua" then
                inventory.pets[uniqueId] = nil
                removed = removed + 1
            end
        end
    end
    
    set_thread_identity(identity)
    
    for uniqueId, _ in pairs(SpawnedPets) do
        if SpawnedPets[uniqueId] and SpawnedPets[uniqueId].data and SpawnedPets[uniqueId].data._source == "blueprint.lua" then
            if SpawnedPets[uniqueId].model then
                SpawnedPets[uniqueId].model:Destroy()
            end
        end
    end
    
    SpawnedPets = {}
    SpawnedItems = {}
    PetAilmentsCache = {}
    EquippedPet = nil
    CurrentRideId = nil
    
    task.defer(function()
        if UIManager and UIManager.apps and UIManager.apps.BackpackApp then
            UIManager.apps.BackpackApp:refresh_rendered_items()
        end
    end)
    
    return removed
end

local function FindPetId(petName)
    for id, info in pairs(InventoryDB.pets) do
        if info.name:lower() == petName:lower() then
            return id
        end
    end
    return nil
end

local function FindToyId(toyName)
    for id, info in pairs(InventoryDB.toys) do
        if info.name:lower() == toyName:lower() then
            return id
        end
    end
    return nil
end

local function FindItemId(itemName)
    local categories = {
        {name = "pets", finder = FindPetId},
        {name = "toys", finder = FindToyId}
    }
    
    for _, cat in ipairs(categories) do
        local id = cat.finder(itemName)
        if id then return id, cat.name end
    end
    return nil, nil
end

local OriginalRouterGet = RouterClient.get

function RouterClient.get(endpoint)
    if endpoint == "ToolAPI/Equip" then
        return {
            InvokeServer = function(_, uniqueId)
                local pet = SpawnedPets[uniqueId]
                if not pet then
                    return OriginalRouterGet("ToolAPI/Equip"):InvokeServer(uniqueId)
                end
                EquipPet(pet.data)
                return true, { action = "equip", is_server = true }
            end
        }
    elseif endpoint == "ToolAPI/Unequip" then
        return {
            InvokeServer = function(_, uniqueId)
                local pet = SpawnedPets[uniqueId]
                if not pet then
                    return OriginalRouterGet("ToolAPI/Unequip"):InvokeServer(uniqueId)
                end
                UnequipPet(pet.data)
                return true, { action = "unequip", is_server = true }
            end
        }
    elseif endpoint == "AdoptAPI/RidePet" then
        return {
            InvokeServer = function(_, petData)
                local pet = SpawnedPets[petData.pet_unique]
                if not pet then
                    return OriginalRouterGet("AdoptAPI/RidePet"):InvokeServer(petData)
                end
                RidePet(petData.pet_unique)
                return true
            end
        }
    elseif endpoint == "AdoptAPI/FlyPet" then
        return {
            InvokeServer = function(_, petData)
                local pet = SpawnedPets[petData.pet_unique]
                if not pet then
                    return OriginalRouterGet("AdoptAPI/FlyPet"):InvokeServer(petData)
                end
                FlyPet(petData.pet_unique)
                return true
            end
        }
    elseif endpoint == "AdoptAPI/ExitSeatStates" then
        return {
            FireServer = function()
                if CurrentRideId then
                    DismountPet()
                    return true
                end
                return OriginalRouterGet("AdoptAPI/ExitSeatStates"):FireServer()
            end
        }
    elseif endpoint == "SettingsAPI/SetPetRoleplayName" then
        return {
            InvokeServer = function(_, petUniqueId, newName)
                local pet = SpawnedPets[petUniqueId]
                if not pet then
                    return OriginalRouterGet("SettingsAPI/SetPetRoleplayName"):InvokeServer(petUniqueId, newName)
                end
                
                local identity = get_thread_identity and get_thread_identity() or 8
                set_thread_identity(2)
                
                local inventory = ClientData.get("inventory")
                if inventory and inventory.pets and inventory.pets[petUniqueId] then
                    inventory.pets[petUniqueId].properties.rp_name = newName
                end
                
                if pet.data then
                    pet.data.properties.rp_name = newName
                end
                
                local wrappers = ClientData.get("pet_char_wrappers")
                for _, wrapper in pairs(wrappers) do
                    if wrapper.pet_unique == petUniqueId then
                        wrapper.rp_name = newName
                        break
                    end
                end
                
                set_thread_identity(identity)
                return true
            end
        }
    else
        return OriginalRouterGet(endpoint)
    end
end

for _, wrapper in pairs(ClientData.get("pet_char_wrappers")) do
    OriginalRouterGet("ToolAPI/Unequip"):InvokeServer(wrapper.pet_unique)
end

-- UI Setup Start
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZetaPreppyUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

local uiScale = Instance.new("UIScale", screenGui)
uiScale.Scale = 0.7 -- Default scale for preppy feel

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 400) -- Slightly larger for preppy elements
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(240, 248, 255) -- AliceBlue, a soft pastel
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16) -- Softer corners
mainCorner.Parent = mainFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Thickness = 2 -- Slightly thinner stroke
uiStroke.Color = Color3.fromRGB(135, 206, 250) -- SkyBlue, a clearer pastel blue
uiStroke.Parent = mainFrame

local palette = {
    Color3.fromRGB(173, 216, 230), -- Light Blue
    Color3.fromRGB(144, 238, 144), -- Light Green
    Color3.fromRGB(255, 182, 193), -- Light Pink
    Color3.fromRGB(250, 235, 215)  -- Light Tan
}
local colorIdx = 1
task.spawn(function()
    while true do
        colorIdx = colorIdx % #palette + 1
        TweenService:Create(uiStroke, TweenInfo.new(5), { Color = palette[colorIdx] }):Play() -- Slower color transition
        task.wait(5)
    end
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "✨ Zeta Scripts" -- Changed for a softer look
title.Font = Enum.Font.QuicksandBold -- A softer, rounded font
title.TextSize = 16 -- Slightly larger, friendly text
title.TextColor3 = Color3.fromRGB(70, 130, 180) -- SteelBlue, a bit more defined pastel
title.Parent = mainFrame

local tabContainer = Instance.new('Frame')
tabContainer.Size = UDim2.new(0.92, 0, 0, 24) -- Slightly larger tabs
tabContainer.Position = UDim2.new(0.04, 0, 0, 34)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabs = {
    { key = 'Spawn', label = 'Pet Spawn' }, -- More descriptive label
    { key = 'Tools', label = 'Utilities' } -- Softer label
}

local activeTab = 'Spawn'
local tabElements = {}

local function SwitchTab(tabName)
    activeTab = tabName
    for name, data in pairs(tabElements) do
        local isActive = name == tabName
        data.button.BackgroundColor3 = isActive and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(200, 200, 210) -- Softer active/inactive colors
        data.button.Font = isActive and Enum.Font.QuicksandBold or Enum.Font.Quicksand
        data.button.TextSize = isActive and 10 or 9
        data.stroke.Color = isActive and Color3.fromRGB(100, 149, 237) or Color3.fromRGB(150, 150, 150) -- CornflowerBlue for active
        data.stroke.Thickness = isActive and 1.5 or 0.8
    end
    spawnPanel.Visible = tabName == 'Spawn'
    toolsPanel.Visible = tabName == 'Tools'
end

for i, tab in ipairs(tabs) do
    local tabButton = Instance.new('TextButton')
    tabButton.Size = UDim2.new(1 / #tabs - 0.02, 0, 1, 0)
    tabButton.Position = UDim2.new((i - 1) * (1 / #tabs), (i == 1) and 0 or 4, 0, 0)
    tabButton.BackgroundColor3 = i == 1 and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(200, 200, 210)
    tabButton.BackgroundTransparency = 0
    tabButton.Text = tab.label
    tabButton.Font = i == 1 and Enum.Font.QuicksandBold or Enum.Font.Quicksand
    tabButton.TextSize = i == 1 and 10 or 9
    tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabButton.Parent = tabContainer
    
    Instance.new("UICorner", tabButton).CornerRadius = UDim.new(0, 8)
    
    local tabStroke = Instance.new('UIStroke')
    tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    tabStroke.Color = i == 1 and Color3.fromRGB(100, 149, 237) or Color3.fromRGB(150, 150, 150)
    tabStroke.Thickness = i == 1 and 1.5 or 0.8
    tabStroke.Transparency = 0.3
    tabStroke.Parent = tabButton
    
    tabElements[tab.key] = { button = tabButton, stroke = tabStroke }
    
    tabButton.MouseButton1Click:Connect(function()
        SwitchTab(tab.key)
    end)
end

local spawnPanel = Instance.new("Frame")
spawnPanel.Size = UDim2.new(0.94, 0, 1, -60) -- Adjusted size
spawnPanel.Position = UDim2.new(0.03, 0, 0, 60)
spawnPanel.BackgroundTransparency = 1
spawnPanel.Parent = mainFrame

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0, 12)
nameLabel.Position = UDim2.new(0, 0, 0, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = "Pet Name"
nameLabel.Font = Enum.Font.Quicksand
nameLabel.TextSize = 10
nameLabel.TextColor3 = Color3.fromRGB(100, 100, 120) -- Softer label color
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Parent = spawnPanel

local nameInput = Instance.new("TextBox")
nameInput.Size = UDim2.new(1, 0, 0, 28) -- Slightly taller input
nameInput.Position = UDim2.new(0, 0, 0, 14)
nameInput.BackgroundColor3 = Color3.fromRGB(230, 230, 240) -- Light pastel background
nameInput.TextColor3 = Color3.fromRGB(50, 50, 70) -- Darker text for contrast
nameInput.TextSize = 12
nameInput.Font = Enum.Font.Quicksand
nameInput.PlaceholderText = "Enter pet name..."
nameInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 170)
nameInput.ClearTextOnFocus = false
nameInput.Text = "Bat Dragon" -- Default for quick testing
nameInput.Parent = spawnPanel

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = nameInput

local glowColors = {
    neutral = Color3.fromRGB(200, 200, 210),
    valid = Color3.fromRGB(144, 238, 144), -- Light Green
    invalid = Color3.fromRGB(255, 182, 193) -- Light Pink
}

local inputGlow = Instance.new("UIStroke")
inputGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
inputGlow.Color = glowColors.neutral
inputGlow.Thickness = 2
inputGlow.Transparency = 0.4
inputGlow.Parent = nameInput

local ageLabel = Instance.new("TextLabel")
ageLabel.Size = UDim2.new(1, 0, 0, 12)
ageLabel.Position = UDim2.new(0, 0, 0, 46)
ageLabel.BackgroundTransparency = 1
ageLabel.Text = "Age"
ageLabel.Font = Enum.Font.Quicksand
ageLabel.TextSize = 10
ageLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
ageLabel.TextXAlignment = Enum.TextXAlignment.Left
ageLabel.Parent = spawnPanel

local ageGrid = Instance.new("Frame")
ageGrid.Size = UDim2.new(1, 0, 0, 28) -- Slightly larger buttons
ageGrid.Position = UDim2.new(0, 0, 0, 60)
ageGrid.BackgroundTransparency = 1
ageGrid.Parent = spawnPanel

local ageCodes = {"N", "J", "P", "T", "P", "F"}
local ageDescriptions = {"Newborn", "Junior", "Pre-Teen", "Teen", "Post-Teen", "Full Grown"}
local currentAge = 1

for i, code in ipairs(ageCodes) do
    local ageButton = Instance.new("TextButton")
    ageButton.Size = UDim2.new(1/6 - 0.01, 0, 1, 0)
    ageButton.Position = UDim2.new((i-1) * (1/6), (i > 1) and 2 or 0, 0, 0)
    ageButton.Text = code
    ageButton.BackgroundColor3 = i == 1 and Color3.fromRGB(173, 216, 230) or Color3.fromRGB(220, 220, 230) -- Light Blue for active
    ageButton.Font = Enum.Font.QuicksandBold
    ageButton.TextColor3 = Color3.fromRGB(50, 50, 70)
    ageButton.TextSize = 11
    ageButton.Parent = ageGrid
    
    local ageCorner = Instance.new("UICorner")
    ageCorner.CornerRadius = UDim.new(0, 8)
    ageCorner.Parent = ageButton
    
    local hintBox = Instance.new("TextLabel")
    hintBox.Text = ageDescriptions[i]
    hintBox.BackgroundColor3 = Color3.fromRGB(240, 248, 255) -- AliceBlue
    hintBox.TextColor3 = Color3.fromRGB(50, 50, 70)
    hintBox.TextSize = 8
    hintBox.Font = Enum.Font.Quicksand
    hintBox.Size = UDim2.new(0, 0, 0, 0)
    hintBox.Visible = false
    hintBox.Parent = ageButton
    Instance.new("UICorner", hintBox).CornerRadius = UDim.new(0, 5)
    
    ageButton.MouseEnter:Connect(function()
        hintBox.Size = UDim2.new(0, 70, 0, 18)
        hintBox.Position = UDim2.new(0, 0, -1.3, 0)
        hintBox.Visible = true
    end)
    
    ageButton.MouseLeave:Connect(function()
        hintBox.Visible = false
    end)
    
    ageButton.MouseButton1Click:Connect(function()
        currentAge = i
        for _, btn in pairs(ageGrid:GetChildren()) do
            if btn:IsA("TextButton") then
                btn.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
            end
        end
        ageButton.BackgroundColor3 = Color3.fromRGB(173, 216, 230) -- Light Blue
    end)
end

local flagLabel = Instance.new("TextLabel")
flagLabel.Size = UDim2.new(1, 0, 0, 12)
flagLabel.Position = UDim2.new(0, 0, 0, 90)
flagLabel.BackgroundTransparency = 1
flagLabel.Text = "Pet Flags"
flagLabel.Font = Enum.Font.Quicksand
flagLabel.TextSize = 10
flagLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
flagLabel.TextXAlignment = Enum.TextXAlignment.Left
flagLabel.Parent = spawnPanel

local flagGrid = Instance.new("Frame")
flagGrid.Size = UDim2.new(1, 0, 0, 30) -- Larger flag buttons
flagGrid.Position = UDim2.new(0, 0, 0, 104)
flagGrid.BackgroundTransparency = 1
flagGrid.Parent = spawnPanel

local flagColors = {
    M = Color3.fromRGB(180, 120, 255), -- Purple pastel
    N = Color3.fromRGB(144, 238, 144), -- Light Green
    F = Color3.fromRGB(173, 216, 230), -- Light Blue
    R = Color3.fromRGB(255, 182, 193)  -- Light Pink
}

local flagOrder = {"M", "N", "F", "R"}
local flagState = {M = false, N = false, F = true, R = true} -- Default flags

for i, flag in ipairs(flagOrder) do
    local flagButton = Instance.new("TextButton")
    flagButton.Size = UDim2.new(0.23, -2, 1, 0)
    flagButton.Position = UDim2.new((i-1) * 0.25, (i > 1) and 3 or 0, 0, 0)
    flagButton.Text = flag
    flagButton.BackgroundColor3 = flagState[flag] and flagColors[flag] or Color3.fromRGB(220, 220, 230)
    flagButton.Font = Enum.Font.QuicksandBold
    flagButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flagButton.TextSize = 13
    flagButton.Parent = flagGrid
    
    local flagCorner = Instance.new("UICorner")
    flagCorner.CornerRadius = UDim.new(0, 8)
    flagCorner.Parent = flagButton
    
    local flagStroke = Instance.new("UIStroke")
    flagStroke.Color = flagColors[flag]
    flagStroke.Thickness = flagState[flag] and 2.5 or 1.5
    flagStroke.Transparency = flagState[flag] and 0.2 or 0.5
    flagStroke.Parent = flagButton
    
    flagButton.MouseButton1Click:Connect(function()
        -- Prevent conflicting flags
        if flag == "M" and flagState["N"] then return end
        if flag == "N" and flagState["M"] then return end
        
        flagState[flag] = not flagState[flag]
        
        if flagState[flag] then
            flagButton.BackgroundColor3 = flagColors[flag]
            TweenService:Create(flagStroke, TweenInfo.new(0.2), {
                Thickness = 2.5,
                Transparency = 0.2
            }):Play()
        else
            flagButton.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
            TweenService:Create(flagStroke, TweenInfo.new(0.2), {
                Thickness = 1.5,
                Transparency = 0.5
            }):Play()
        end
    end)
end

local quickLabel = Instance.new("TextLabel")
quickLabel.Size = UDim2.new(1, 0, 0, 12)
quickLabel.Position = UDim2.new(0, 0, 0, 138)
quickLabel.BackgroundTransparency = 1
quickLabel.Text = "Quick Select"
quickLabel.Font = Enum.Font.Quicksand
quickLabel.TextSize = 10
quickLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
quickLabel.TextXAlignment = Enum.TextXAlignment.Left
quickLabel.Parent = spawnPanel

local quickGrid = Instance.new("Frame")
quickGrid.Size = UDim2.new(1, 0, 0, 50) -- Larger quick select buttons
quickGrid.Position = UDim2.new(0, 0, 0, 150)
quickGrid.BackgroundTransparency = 1
quickGrid.Parent = spawnPanel

local quickPets = {
    {"Shadow Dragon", Color3.fromRGB(100, 100, 150)}, -- Muted purple
    {"Frost Dragon", Color3.fromRGB(135, 206, 250)}, -- Sky Blue
    {"Bat Dragon", Color3.fromRGB(255, 105, 180)}, -- Hot Pink (slightly muted)
    {"Giraffe", Color3.fromRGB(255, 218, 185)}, -- Peach Puff
    {"Owl", Color3.fromRGB(210, 180, 140)}, -- Tan
    {"Parrot", Color3.fromRGB(255, 160, 122)} -- Light Salmon
}

for i, petData in ipairs(quickPets) do
    local row = math.floor((i-1) / 3)
    local col = (i-1) % 3
    
    local quickButton = Instance.new("TextButton")
    quickButton.Size = UDim2.new(0.32, -2, 0.45, 0)
    quickButton.Position = UDim2.new(col * 0.33, (col > 0) and 3 or 0, row * 0.5, (row > 0) and 3 or 0)
    
    if i <= 3 then
        quickButton.Text = petData[1]
    else
        quickButton.Text = petData[1]:match("^(%w+)") or petData[1]
    end
    
    quickButton.BackgroundColor3 = petData[2]
    quickButton.Font = Enum.Font.QuicksandBold
    quickButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    quickButton.TextSize = 8 -- Smaller text for quick select
    quickButton.Parent = quickGrid
    
    local quickCorner = Instance.new("UICorner")
    quickCorner.CornerRadius = UDim.new(0, 6)
    quickCorner.Parent = quickButton
    
    quickButton.MouseButton1Click:Connect(function()
        nameInput.Text = petData[1]
        -- Update glow based on the new text
        local text = nameInput.Text
        local isValid = FindPetId(text) ~= nil
        inputGlow.Color = isValid and glowColors.valid or glowColors.invalid
    end)
end

local spawnAllButton = Instance.new("TextButton")
spawnAllButton.Size = UDim2.new(1, 0, 0, 28) -- Taller button
spawnAllButton.Position = UDim2.new(0, 0, 0, 200)
spawnAllButton.Text = "🌟 Spawn All High Tiers" -- Softer icon and text
spawnAllButton.Font = Enum.Font.QuicksandBold
spawnAllButton.TextSize = 11
spawnAllButton.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Light Orange
spawnAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnAllButton.Parent = spawnPanel

local allCorner = Instance.new("UICorner")
allCorner.CornerRadius = UDim.new(0, 10)
allCorner.Parent = spawnAllButton

local allStroke = Instance.new("UIStroke")
allStroke.Color = Color3.fromRGB(255, 230, 150) -- Lighter yellow stroke
allStroke.Thickness = 2
allStroke.Transparency = 0.3
allStroke.Parent = spawnAllButton

local spawnButton = Instance.new("TextButton")
spawnButton.Size = UDim2.new(1, 0, 0, 32) -- Taller spawn button
spawnButton.Position = UDim2.new(0, 0, 1, -40)
spawnButton.Text = "Spawn Pet"
spawnButton.Font = Enum.Font.QuicksandBold
spawnButton.TextSize = 14
spawnButton.BackgroundColor3 = Color3.fromRGB(100, 149, 237) -- CornflowerBlue
spawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnButton.Parent = spawnPanel

local spawnCorner = Instance.new("UICorner")
spawnCorner.CornerRadius = UDim.new(0, 12)
spawnCorner.Parent = spawnButton

local toolsPanel = Instance.new("Frame")
toolsPanel.Size = UDim2.new(0.94, 0, 1, -60)
toolsPanel.Position = UDim2.new(0.03, 0, 0, 60)
toolsPanel.BackgroundTransparency = 1
toolsPanel.Parent = mainFrame

local toolsTitle = Instance.new("TextLabel")
toolsTitle.Size = UDim2.new(1, 0, 0, 16)
toolsTitle.Position = UDim2.new(0, 0, 0, 0)
toolsTitle.BackgroundTransparency = 1
toolsTitle.Text = "Utilities"
toolsTitle.Font = Enum.Font.QuicksandBold
toolsTitle.TextSize = 14
toolsTitle.TextColor3 = Color3.fromRGB(70, 130, 180) -- SteelBlue
toolsTitle.TextXAlignment = Enum.TextXAlignment.Left
toolsTitle.Parent = toolsPanel

local deleteButton = Instance.new("TextButton")
deleteButton.Size = UDim2.new(1, 0, 0, 28)
deleteButton.Position = UDim2.new(0, 0, 0, 25)
deleteButton.Text = "🗑️ Delete All My Pets"
deleteButton.Font = Enum.Font.QuicksandBold
deleteButton.TextSize = 11
deleteButton.BackgroundColor3 = Color3.fromRGB(255, 105, 180) -- Hot Pink
deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deleteButton.Parent = toolsPanel
Instance.new("UICorner", deleteButton).CornerRadius = UDim.new(0, 10)

deleteButton.MouseButton1Click:Connect(function()
    local count = DeleteAllSpawnedPets()
    deleteButton.Text = "✓ Deleted " .. count .. "!"
    TweenService:Create(deleteButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play()
    task.wait(1.2)
    deleteButton.Text = "🗑️ Delete All My Pets"
    TweenService:Create(deleteButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 105, 180)}):Play()
end)

local scaleLabel = Instance.new("TextLabel")
scaleLabel.Size = UDim2.new(1, 0, 0, 12)
scaleLabel.Position = UDim2.new(0, 0, 0, 60)
scaleLabel.BackgroundTransparency = 1
scaleLabel.Text = "UI Scale"
scaleLabel.Font = Enum.Font.Quicksand
scaleLabel.TextSize = 10
scaleLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
scaleLabel.TextXAlignment = Enum.TextXAlignment.Left
scaleLabel.Parent = toolsPanel

local scaleControls = Instance.new("Frame")
scaleControls.Size = UDim2.new(1, 0, 0, 30)
scaleControls.Position = UDim2.new(0, 0, 0, 73)
scaleControls.BackgroundTransparency = 1
scaleControls.Parent = toolsPanel

local scaleDown = Instance.new("TextButton")
scaleDown.Size = UDim2.new(0.2, 0, 1, 0)
scaleDown.Position = UDim2.new(0, 0, 0, 0)
scaleDown.Text = "−"
scaleDown.Font = Enum.Font.QuicksandBold
scaleDown.TextSize = 14
scaleDown.BackgroundColor3 = Color3.fromRGB(255, 105, 180) -- Hot Pink
scaleDown.TextColor3 = Color3.fromRGB(255, 255, 255)
scaleDown.Parent = scaleControls
Instance.new("UICorner", scaleDown).CornerRadius = UDim.new(0, 8)

local scaleValue = Instance.new("TextLabel")
scaleValue.Size = UDim2.new(0.5, 0, 1, 0)
scaleValue.Position = UDim2.new(0.25, 0, 0, 0)
scaleValue.BackgroundColor3 = Color3.fromRGB(230, 230, 240)
scaleValue.TextColor3 = Color3.fromRGB(50, 50, 70)
scaleValue.Text = "70%"
scaleValue.Font = Enum.Font.QuicksandBold
scaleValue.TextSize = 11
scaleValue.Parent = scaleControls
Instance.new("UICorner", scaleValue).CornerRadius = UDim.new(0, 8)

local scaleUp = Instance.new("TextButton")
scaleUp.Size = UDim2.new(0.2, 0, 1, 0)
scaleUp.Position = UDim2.new(0.8, 0, 0, 0)
scaleUp.Text = "+"
scaleUp.Font = Enum.Font.QuicksandBold
scaleUp.TextSize = 14
scaleUp.BackgroundColor3 = Color3.fromRGB(144, 238, 144) -- Light Green
scaleUp.TextColor3 = Color3.fromRGB(255, 255, 255)
scaleUp.Parent = scaleControls
Instance.new("UICorner", scaleUp).CornerRadius = UDim.new(0, 8)

local resetScale = Instance.new("TextButton")
resetScale.Size = UDim2.new(1, 0, 0, 24)
resetScale.Position = UDim2.new(0, 0, 0, 100)
resetScale.Text = "↺ Reset to 70%"
resetScale.Font = Enum.Font.QuicksandBold
resetScale.TextSize = 9
resetScale.BackgroundColor3 = Color3.fromRGB(173, 216, 230) -- Light Blue
resetScale.TextColor3 = Color3.fromRGB(255, 255, 255)
resetScale.Parent = toolsPanel
Instance.new("UICorner", resetScale).CornerRadius = UDim.new(0, 8)

local lockButton = Instance.new("TextButton")
lockButton.Size = UDim2.new(1, 0, 0, 24)
lockButton.Position = UDim2.new(0, 0, 0, 129)
lockButton.Text = "🔓 Unlocked"
lockButton.Font = Enum.Font.QuicksandBold
lockButton.TextSize = 9
lockButton.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Light Orange
lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
lockButton.Parent = toolsPanel
Instance.new("UICorner", lockButton).CornerRadius = UDim.new(0, 8)

local currentScale = 0.7

scaleDown.MouseButton1Click:Connect(function()
    currentScale = math.max(0.5, currentScale - 0.1)
    uiScale.Scale = currentScale
    scaleValue.Text = math.floor(currentScale * 100) .. "%"
    TweenService:Create(scaleDown, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 150, 150)}):Play()
    task.wait(0.2)
    TweenService:Create(scaleDown, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 105, 180)}):Play()
end)

scaleUp.MouseButton1Click:Connect(function()
    currentScale = math.min(2.0, currentScale + 0.1)
    uiScale.Scale = currentScale
    scaleValue.Text = math.floor(currentScale * 100) .. "%"
    TweenService:Create(scaleUp, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(150, 255, 150)}):Play()
    task.wait(0.2)
    TweenService:Create(scaleUp, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play()
end)

resetScale.MouseButton1Click:Connect(function()
    currentScale = 0.7
    uiScale.Scale = currentScale
    scaleValue.Text = "70%"
    TweenService:Create(resetScale, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(150, 150, 230)}):Play()
    task.wait(0.2)
    TweenService:Create(resetScale, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(173, 216, 230)}):Play()
end)

local uiLocked = false
lockButton.MouseButton1Click:Connect(function()
    uiLocked = not uiLocked
    if uiLocked then
        lockButton.Text = "🔒 Locked"
        lockButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150) -- Grey out when locked
    else
        lockButton.Text = "🔓 Unlocked"
        lockButton.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Back to original color
    end
end)

local dragging = false
local dragStart, startPos

mainFrame.InputBegan:Connect(function(input)
    if not uiLocked and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

mainFrame.InputChanged:Connect(function(input)
    if not uiLocked and dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Initial tab setup
SwitchTab(activeTab)

spawnButton.MouseButton1Click:Connect(function()
    local petName = nameInput.Text
    if petName == "" then 
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 100, 100)}):Play()
        task.wait(0.2)
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 149, 237)}):Play()
        return 
    end
    
    local petId = FindPetId(petName)
    if not petId then 
        inputGlow.Color = glowColors.invalid
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 100, 100)}):Play()
        task.wait(0.2)
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 149, 237)}):Play()
        return 
    end
    
    local ageMap = {1, 2, 3, 4, 5, 6}
    local options = {
        mega_neon = flagState["M"],
        neon = flagState["N"],
        flyable = flagState["F"],
        rideable = flagState["R"],
        age = ageMap[currentAge],
        trick_level = 5,
        ailments_completed = 0,
        rp_name = GenerateUniquePetName() -- Always generate a unique name for new spawns
    }
    
    local item = CreateInventoryItem(petId, "pets", options)
    if item then
        spawnButton.Text = "✓ Spawned!"
        TweenService:Create(spawnButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play() -- Green flash for success
        task.wait(1)
        spawnButton.Text = "Spawn Pet"
        TweenService:Create(spawnButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(100, 149, 237)}):Play() -- Back to original
    end
end)

spawnAllButton.MouseButton1Click:Connect(function()
    local ageMap = {1, 2, 3, 4, 5, 6}
    local options = {
        mega_neon = flagState["M"],
        neon = flagState["N"],
        flyable = flagState["F"],
        rideable = flagState["R"],
        age = ageMap[currentAge],
        trick_level = 5,
        ailments_completed = 0
    }
    
    local successCount = 0
    spawnAllButton.Text = "⚡ Spawning..."
    TweenService:Create(spawnAllButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 230, 150)}):Play()
    
    for _, petName in ipairs(HighTierPets) do
        local petId = FindPetId(petName)
        if petId then
            local petOptions = table.clone(options)
            petOptions.rp_name = GenerateUniquePetName() -- Ensure each pet gets a unique name
            
            local item = CreateInventoryItem(petId, "pets", petOptions)
            if item then
                successCount = successCount + 1
            end
        end
    end
    
    spawnAllButton.Text = "✓ Spawned " .. successCount .. "!"
    TweenService:Create(spawnAllButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play()
    task.wait(1.5)
    spawnAllButton.Text = "🌟 Spawn All High Tiers"
    TweenService:Create(spawnAllButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 200, 100)}):Play()
end)

nameInput:GetPropertyChangedSignal("Text"):Connect(function()
    local text = nameInput.Text
    if text == "" then
        inputGlow.Color = glowColors.neutral
        return
    end
    
    local isValid = FindPetId(text) ~= nil
    inputGlow.Color = isValid and glowColors.valid or glowColors.invalid
end)

-- UI Setup End
end
if TradeApp._ORIGINAL_change_local_trade_state then
   TradeApp._change_local_trade_state = TradeApp._ORIGINAL_change_local_trade_state
end
if TradeApp._ORIGINAL_overwrite_local_trade_state then
   TradeApp._overwrite_local_trade_state = TradeApp._ORIGINAL_overwrite_local_trade_state
end

TradeHistoryApp._ORIGINAL_create_trade_frame = TradeHistoryApp._create_trade_frame
TradeApp._ORIGINAL_change_local_trade_state = TradeApp._change_local_trade_state
TradeApp._ORIGINAL_overwrite_local_trade_state = TradeApp._overwrite_local_trade_state

local tradeCache = {}
local currentTradeItems = nil

function TradeApp._change_local_trade_state(self, changes, ...)
   local currentState = TradeApp.local_trade_state

   if currentState and currentState.trade_id then
       local isSender = currentState.sender == LocalPlayer
       local isRecipient = currentState.recipient == LocalPlayer

       if isSender and changes.sender_offer and changes.sender_offer.items then
           tradeCache[currentState.trade_id] = {
               items = table.clone(changes.sender_offer.items),
               isSender = true
           }
           currentTradeItems = changes.sender_offer.items
       elseif isRecipient and changes.recipient_offer and changes.recipient_offer.items then
           tradeCache[currentState.trade_id] = {
               items = table.clone(changes.recipient_offer.items),
               isSender = false
           }
           currentTradeItems = changes.recipient_offer.items
       end
   end

   return TradeApp._ORIGINAL_change_local_trade_state(self, changes, ...)
end

function TradeApp._overwrite_local_trade_state(self, tradeState, ...)
   if tradeState then
       local isSender = tradeState.sender == LocalPlayer
       local isRecipient = tradeState.recipient == LocalPlayer

       if isSender and tradeState.sender_offer and currentTradeItems then
           tradeState.sender_offer.items = currentTradeItems
       elseif isRecipient and tradeState.recipient_offer and currentTradeItems then
           tradeState.recipient_offer.items = currentTradeItems
       end
   else
       currentTradeItems = nil
       if TradeApp._last_trade_id then
           tradeCache[TradeApp._last_trade_id] = nil
           TradeApp._last_trade_id = nil
       end
   end

   return TradeApp._ORIGINAL_overwrite_local_trade_state(self, tradeState, ...)
end

function TradeHistoryApp._create_trade_frame(self, tradeData, ...)
   if tradeData.trade_id and tradeCache[tradeData.trade_id] then
       local cachedData = tradeCache[tradeData.trade_id]
       local modifiedData = table.clone(tradeData)

       if cachedData.isSender then
           modifiedData.sender_items = table.clone(cachedData.items)
       else
           modifiedData.recipient_items = table.clone(cachedData.items)
       end

       return TradeHistoryApp._ORIGINAL_create_trade_frame(self, modifiedData, ...)
   end

   return TradeHistoryApp._ORIGINAL_create_trade_frame(self, tradeData, ...)
end

local HighTierPets = {
    "Shadow Dragon", "Bat Dragon", "Frost Dragon", "Giraffe", "Owl", "Parrot", "Crow",
    "Evil Unicorn", "Arctic Reindeer", "Hedgehog", "Dalmatian", "Turtle", "Kangaroo",
    "Lion", "Elephant", "Blazing Lion", "African Wild Dog", "Flamingo", "Diamond Butterfly",
    "Mini Pig", "Caterpillar", "Albino Monkey", "Candyfloss Chick", "Pelican", "Blue Dog",
    "Pink Cat", "Haetae", "Peppermint Penguin", "Winged Tiger", "Sugar Glider",
    "Shark Puppy", "Goat", "Sheeeeep", "Lion Cub", "Nessie", "Frostbite Bear",
    "Balloon Unicorn", "Honey Badger", "Hot Doggo", "Crocodile", "Hare", "Ram", "Yeti",
    "Meerkat", "Jellyfish", "Happy Clown", "Orchid Butterfly", "Many Mackerel",
    "Strawberry Shortcake Bat Dragon", "Zombie Buffalo", "Fairy Bat Dragon",
    "Chocolate Chip Bat Dragon", "Cow", "Dragonfruit Fox", "Monkey King", "Cryptid",
    "Undead Jousting Horse", "Mermicorn", "Frost Unicorn", "Irish Water Spaniel",
    "Jekyll Hydra", "Papa Moose", "Strawberry Penguin", "Bush Elephant", "Cupid Dragon",
    "Black-Chested Pheasant", "Alpaca", "Field Mouse", "Pineapple Owl", "Owlbear",
    "Tio De Nadal", "Pig", "Royal Mistletroll", "Pirate Ghost Capuchin Monkey",
    "Moose Calf", "Vampire Dragon", "Shrew", "Mechapup", "Bald Eagle",
    "Ring-Tailed Lemur", "Tortuga De La Isla", "Werewolf", "Puffin", "Fallow Deer",
    "Caelum Cervi", "Diamond Amazon", "Sea Slug", "Sugar Axolotl", "Purple Butterfly",
    "Grim Dragon", "Brown Bear", "Polar Bear", "Sakura Spirit", "Platypus", "Groundhog",
    "Lava Dragon", "Glacier Moth", "Emperor Gorilla", "2D Kitty", "Hyena",
    "Arctic Dusk Dragon", "Alley Cat", "Siamese Cat", "Phantom Dragon",
    "Christmas Pudding Pup", "Glacier Kitsune", "Giant Gold Scarab", "Diamond Albatross"
}

local SpawnedPets = {}
local PetModelCache = {}
local EquippedPet = nil
local CurrentRideId = nil
local RideAnimationTrack = nil
local PetAilmentsCache = {}
local SpawnedItems = {}

local function GenerateUniquePetName()
    local prefixes = {"★", "☆", "♡", "☁️", "✨", "🍓", "🌸", "🍯", "☕", "🌙", "🌈", "❄️", "🫧", "🍬", "🍪", "🥛"}
    local names = {"Shadow", "Blaze", "Frost", "Thunder", "Moon", "Star", "Sky", "Ocean", "River", "Storm", 
                   "Ember", "Ash", "Dusk", "Dawn", "Night", "Day", "Sun", "Wind", "Rain", "Snow", "Ice", "Fire",
                   "Nova", "Cosmo", "Galaxy", "Orbit", "Comet", "Meteor", "Aurora", "Nebula", "Crystal", "Gem",
                   "Ruby", "Sapphire", "Emerald", "Diamond", "Gold", "Silver", "Mystic", "Magic", "Enchant"}
    
    local usePrefix = math.random(1, 3) == 1
    local name = names[math.random(1, #names)]
    
    if usePrefix then
        return prefixes[math.random(1, #prefixes)] .. name
    else
        return name .. " " .. prefixes[math.random(1, #prefixes)]
    end
end

local NewnessGroups = {
    mega_neon_flyable_rideable = 990000,
    mega_neon_flyable = 980000,
    mega_neon_rideable = 970000,
    mega_neon = 960000,
    neon_flyable_rideable = 950000,
    neon_flyable = 940000,
    neon_rideable = 930000,
    neon = 920000,
    flyable_rideable = 910000,
    flyable = 900000,
    rideable = 890000,
    regular = 880000
}

local function GetPropertyGroup(properties)
    local isMega = properties.mega_neon or false
    local isNeon = properties.neon or false
    local canFly = properties.flyable or false
    local canRide = properties.rideable or false

    if isMega then
        if canFly and canRide then return "mega_neon_flyable_rideable"
        elseif canFly then return "mega_neon_flyable"
        elseif canRide then return "mega_neon_rideable"
        else return "mega_neon" end
    elseif isNeon then
        if canFly and canRide then return "neon_flyable_rideable"
        elseif canFly then return "neon_flyable"
        elseif canRide then return "neon_rideable"
        else return "neon" end
    else
        if canFly and canRide then return "flyable_rideable"
        elseif canFly then return "flyable"
        elseif canRide then return "rideable"
        else return "regular" end
    end
end

local function UpdateClientData(dataPath, modifier)
    local identity = get_thread_identity and get_thread_identity() or 8
    set_thread_identity(2)
    local currentData = ClientData.get(dataPath)
    local clonedData = table.clone(currentData)
    local result = modifier(clonedData)
    ClientData.predict(dataPath, result)
    set_thread_identity(identity)
    return result
end

local function GenerateUniqueID()
    return HttpService:GenerateGUID(false)
end

local function FindInTable(array, checker)
    for index, value in pairs(array) do
        if checker(value, index) then
            return index
        end
    end
    return nil
end

local originalGetServer = ClientData.get_server

function ClientData.get_server(player, key, ...)
    local data = originalGetServer(player, key, ...)

    if key == "ailments_manager" and player == LocalPlayer then
        local ailmentsData = {}
        if data then
            for k, v in pairs(data) do
                ailmentsData[k] = type(v) == "table" and table.clone(v) or v
            end
        end
        
        ailmentsData.ailments = ailmentsData.ailments or {}
        
        for petId, _ in pairs(SpawnedPets) do
            if PetAilmentsCache[petId] then
                ailmentsData.ailments[petId] = PetAilmentsCache[petId]
            else
                local ailmentTypes = {}
                for kind, _ in pairs(AilmentsDB) do
                    if kind ~= "at_work" and kind ~= "mystery" and kind ~= "walking" then
                        table.insert(ailmentTypes, kind)
                    end
                end

                local ailmentCount = math.random(2, 4)
                local petAilments = {}
                local usedTypes = {}

                for i = 1, math.min(ailmentCount, #ailmentTypes) do
                    local ailmentKind
                    repeat
                        ailmentKind = ailmentTypes[math.random(1, #ailmentTypes)]
                    until not usedTypes[ailmentKind]
                    usedTypes[ailmentKind] = true

                    local ailmentId = GenerateUniqueID()
                    petAilments[ailmentId] = {
                        components = {},
                        created_timestamp = os.time(),
                        kind = ailmentKind,
                        progress = 0,
                        rate = 0,
                        rate_timestamp = os.time(),
                        sort_order = i * 100
                    }
                end

                PetAilmentsCache[petId] = petAilments
                ailmentsData.ailments[petId] = petAilments
            end
        end

        return ailmentsData
    end

    return data
end

local function FetchPetModel(petKind)
    if PetModelCache[petKind] then
        return PetModelCache[petKind]
    end
    local model = DownloadClient.promise_download_copy("Pets", petKind):expect()
    PetModelCache[petKind] = model
    return model
end

local function ApplyNeonVisuals(petModel, petData)
    local modelInstance = petModel:FindFirstChild("PetModel")
    if modelInstance and (petData.properties.neon or petData.properties.mega_neon) then
        local petKindData = KindDB[petData.id]
        for partName, partProps in pairs(petKindData.neon_parts) do
            local geoPart = PetRigs.get(modelInstance).get_geo_part(modelInstance, partName)
            if geoPart then
                geoPart.Material = partProps.Material
                geoPart.Color = partProps.Color
            end
        end
    end
end

local function RegisterPetWrapper(wrapperData)
    UpdateClientData("pet_char_wrappers", function(wrappers)
        wrapperData.unique = #wrappers + 1
        wrapperData.index = #wrappers + 1
        wrappers[#wrappers + 1] = wrapperData
        return wrappers
    end)
end

local function RegisterPetState(stateManager)
    UpdateClientData("pet_state_managers", function(managers)
        managers[#managers + 1] = stateManager
        return managers
    end)
end

local function RemovePetWrapper(petUniqueId)
    UpdateClientData("pet_char_wrappers", function(wrappers)
        local wrapperIndex = FindInTable(wrappers, function(w)
            return w.pet_unique == petUniqueId
        end)
        if wrapperIndex then
            table.remove(wrappers, wrapperIndex)
            for i = wrapperIndex, #wrappers do
                wrappers[i].unique = i
                wrappers[i].index = i
            end
        end
        return wrappers
    end)
end

local function RemovePetState(petUniqueId)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    UpdateClientData("pet_state_managers", function(managers)
        local managerIndex = FindInTable(managers, function(m)
            return m.char == pet.model
        end)
        if managerIndex then
            table.remove(managers, managerIndex)
        end
        return managers
    end)
end

local function ClearPetStates(petUniqueId)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    UpdateClientData("pet_state_managers", function(managers)
        local managerIndex = FindInTable(managers, function(m)
            return m.char == pet.model
        end)
        if managerIndex then
            local updated = table.clone(managers)
            updated[managerIndex] = table.clone(updated[managerIndex])
            updated[managerIndex].states = {}
            return updated
        end
        return managers
    end)
end

local function SetPetState(petUniqueId, stateId)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    UpdateClientData("pet_state_managers", function(managers)
        local managerIndex = FindInTable(managers, function(m)
            return m.char == pet.model
        end)
        if managerIndex then
            local updated = table.clone(managers)
            updated[managerIndex] = table.clone(updated[managerIndex])
            updated[managerIndex].states = {{ id = stateId }}
            return updated
        end
        return managers
    end)
end

local function ClearPlayerStates()
    UpdateClientData("state_manager", function(stateManager)
        local updated = table.clone(stateManager)
        updated.states = {}
        updated.is_sitting = false
        return updated
    end)
end

local function SetPlayerState(stateId)
    UpdateClientData("state_manager", function(stateManager)
        local updated = table.clone(stateManager)
        updated.states = {{ id = stateId }}
        updated.is_sitting = true
        return updated
    end)
end

local function AttachRideConstraint(petModel)
    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart then return false end

    local ridePos = petModel:FindFirstChild("RidePosition", true)
    if not ridePos then return false end

    local sourceAttach = Instance.new("Attachment")
    sourceAttach.Parent = ridePos
    sourceAttach.Position = Vector3.new(0, 1.237, 0)
    sourceAttach.Name = "SourceAttachment"

    local rigidConstraint = Instance.new("RigidConstraint")
    rigidConstraint.Name = "StateConnection"
    rigidConstraint.Attachment0 = sourceAttach
    rigidConstraint.Attachment1 = character.PrimaryPart.RootAttachment
    rigidConstraint.Parent = character

    return true
end

local function DismountPet()
    if not CurrentRideId then return end

    local pet = SpawnedPets[CurrentRideId]
    if pet and pet.model then
        if RideAnimationTrack then
            RideAnimationTrack:Stop()
            RideAnimationTrack:Destroy()
            RideAnimationTrack = nil
        end

        local sourceAttach = pet.model:FindFirstChild("SourceAttachment", true)
        if sourceAttach then sourceAttach:Destroy() end

        local character = LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part:GetAttribute("HaveMass") then
                    part.Massless = false
                end
            end
        end

        ClearPetStates(CurrentRideId)
        ClearPlayerStates()
        pet.model:ScaleTo(1)
    end
    CurrentRideId = nil
end

local function MountPet(petUniqueId, playerState, petState)
    local pet = SpawnedPets[petUniqueId]
    if not pet or not pet.model then return end

    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart or not character:FindFirstChild("Humanoid") then return end

    DismountPet()
    CurrentRideId = petUniqueId

    SetPetState(petUniqueId, petState)
    SetPlayerState(playerState)
    pet.model:ScaleTo(2)
    AttachRideConstraint(pet.model)

    RideAnimationTrack = character.Humanoid.Animator:LoadAnimation(AnimationManager.get_track("PlayerRidingPet"))
    character.Humanoid.Sit = true

    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Massless == false then
            part.Massless = true
            part:SetAttribute("HaveMass", true)
        end
    end

    RideAnimationTrack:Play()
end

local function RidePet(petUniqueId)
    MountPet(petUniqueId, "PlayerRidingPet", "PetBeingRidden")
end

local function FlyPet(petUniqueId)
    MountPet(petUniqueId, "PlayerFlyingPet", "PetBeingFlown")
end

local function UnequipPet(petData)
    local pet = SpawnedPets[petData.unique]
    if not pet or not pet.model then return end

    if CurrentRideId == petData.unique then
        DismountPet()
    end

    RemovePetWrapper(petData.unique)
    RemovePetState(petData.unique)
    pet.model:Destroy()
    pet.model = nil

    if EquippedPet and EquippedPet.unique == petData.unique then
        EquippedPet = nil
    end

    PetAilmentsCache[petData.unique] = nil
    task.wait(0.15)
    AilmentsClient.on_ailments_changed(LocalPlayer)
end

local function EquipPet(petData)
    if petData.category ~= "pets" then return end

    if EquippedPet then
        UnequipPet(EquippedPet)
    end

    for _, wrapper in pairs(ClientData.get("pet_char_wrappers")) do
        if wrapper.controller == LocalPlayer then
            RouterClient.get("ToolAPI/Unequip"):InvokeServer(wrapper.pet_unique)
        end
    end

    if not SpawnedPets[petData.unique] then
        SpawnedPets[petData.unique] = { data = petData, model = nil }
    end

    local petModel = FetchPetModel(petData.kind):Clone()
    petModel.Parent = workspace
    SpawnedPets[petData.unique].model = petModel
    ApplyNeonVisuals(petModel, petData)

    EquippedPet = petData

    task.defer(function()
        RegisterPetWrapper({
            char = petModel,
            mega_neon = petData.properties.mega_neon or false,
            neon = petData.properties.neon or false,
            player = LocalPlayer,
            entity_controller = LocalPlayer,
            controller = LocalPlayer,
            rp_name = petData.properties.rp_name or "",
            pet_trick_level = petData.properties.pet_trick_level or 0,
            pet_unique = petData.unique,
            pet_id = petData.id,
            location = {
                full_destination_id = "housing",
                destination_id = "housing",
                house_owner = LocalPlayer
            },
            pet_progression = {
                age = petData.properties.age or math.random(1, 6),
                percentage = math.random(0, 99) / 100
            },
            are_colors_sealed = false,
            is_pet = true,
        })

        RegisterPetState({
            char = petModel,
            player = LocalPlayer,
            store_key = "pet_state_managers",
            is_sitting = false,
            chars_connected_to_me = {},
            states = {}
        })
        task.wait(0.15)
        AilmentsClient.on_ailments_changed(LocalPlayer)
    end)
end

local NextToyOrder = 60000

local function CreateInventoryItem(itemId, category, properties)
    local uniqueId = GenerateUniqueID()
    local itemKindData = KindDB[itemId]

    if not itemKindData then
        warn("Item not found: " .. itemId)
        return nil
    end

    properties = properties or {}
    local newnessValue = NextToyOrder

    if category == "pets" then
        local groupKey = GetPropertyGroup(properties)
        NewnessGroups[groupKey] = NewnessGroups[groupKey] - 1
        newnessValue = NewnessGroups[groupKey]

        if not properties.ailments_completed then
            properties.ailments_completed = 0
        end

        if not properties.rp_name or properties.rp_name == "" then
            properties.rp_name = GenerateUniquePetName()
        end
    else
        NextToyOrder = NextToyOrder - 1
        newnessValue = NextToyOrder
    end

    local itemData = {
        unique = uniqueId,
        category = category,
        id = itemId,
        kind = itemKindData.kind,
        newness_order = newnessValue,
        properties = properties,
        _source = "blueprint.lua"
    }

    local identity = get_thread_identity and get_thread_identity() or 8
    set_thread_identity(2)
    local inventory = ClientData.get("inventory")
    if inventory and inventory[category] then
        inventory[category][uniqueId] = itemData
    end
    set_thread_identity(identity)

    if category == "pets" then
        SpawnedPets[uniqueId] = { data = itemData, model = nil }
    end
    
    SpawnedItems[uniqueId] = true

    task.defer(function()
        if UIManager and UIManager.apps and UIManager.apps.BackpackApp then
            UIManager.apps.BackpackApp:refresh_rendered_items()
        end
    end)

    return itemData
end

local function DeleteAllSpawnedPets()
    local identity = get_thread_identity and get_thread_identity() or 8
    set_thread_identity(2)
    
    local inventory = ClientData.get("inventory")
    local removed = 0
    
    if inventory and inventory.pets then
        for uniqueId, _ in pairs(SpawnedItems) do
            if inventory.pets[uniqueId] and inventory.pets[uniqueId]._source == "blueprint.lua" then
                inventory.pets[uniqueId] = nil
                removed = removed + 1
            end
        end
    end
    
    set_thread_identity(identity)
    
    for uniqueId, _ in pairs(SpawnedPets) do
        if SpawnedPets[uniqueId] and SpawnedPets[uniqueId].data and SpawnedPets[uniqueId].data._source == "blueprint.lua" then
            if SpawnedPets[uniqueId].model then
                SpawnedPets[uniqueId].model:Destroy()
            end
        end
    end
    
    SpawnedPets = {}
    SpawnedItems = {}
    PetAilmentsCache = {}
    EquippedPet = nil
    CurrentRideId = nil
    
    task.defer(function()
        if UIManager and UIManager.apps and UIManager.apps.BackpackApp then
            UIManager.apps.BackpackApp:refresh_rendered_items()
        end
    end)
    
    return removed
end

local function FindPetId(petName)
    for id, info in pairs(InventoryDB.pets) do
        if info.name:lower() == petName:lower() then
            return id
        end
    end
    return nil
end

local function FindToyId(toyName)
    for id, info in pairs(InventoryDB.toys) do
        if info.name:lower() == toyName:lower() then
            return id
        end
    end
    return nil
end

local function FindItemId(itemName)
    local categories = {
        {name = "pets", finder = FindPetId},
        {name = "toys", finder = FindToyId}
    }
    
    for _, cat in ipairs(categories) do
        local id = cat.finder(itemName)
        if id then return id, cat.name end
    end
    return nil, nil
end

local OriginalRouterGet = RouterClient.get

function RouterClient.get(endpoint)
    if endpoint == "ToolAPI/Equip" then
        return {
            InvokeServer = function(_, uniqueId)
                local pet = SpawnedPets[uniqueId]
                if not pet then
                    return OriginalRouterGet("ToolAPI/Equip"):InvokeServer(uniqueId)
                end
                EquipPet(pet.data)
                return true, { action = "equip", is_server = true }
            end
        }
    elseif endpoint == "ToolAPI/Unequip" then
        return {
            InvokeServer = function(_, uniqueId)
                local pet = SpawnedPets[uniqueId]
                if not pet then
                    return OriginalRouterGet("ToolAPI/Unequip"):InvokeServer(uniqueId)
                end
                UnequipPet(pet.data)
                return true, { action = "unequip", is_server = true }
            end
        }
    elseif endpoint == "AdoptAPI/RidePet" then
        return {
            InvokeServer = function(_, petData)
                local pet = SpawnedPets[petData.pet_unique]
                if not pet then
                    return OriginalRouterGet("AdoptAPI/RidePet"):InvokeServer(petData)
                end
                RidePet(petData.pet_unique)
                return true
            end
        }
    elseif endpoint == "AdoptAPI/FlyPet" then
        return {
            InvokeServer = function(_, petData)
                local pet = SpawnedPets[petData.pet_unique]
                if not pet then
                    return OriginalRouterGet("AdoptAPI/FlyPet"):InvokeServer(petData)
                end
                FlyPet(petData.pet_unique)
                return true
            end
        }
    elseif endpoint == "AdoptAPI/ExitSeatStates" then
        return {
            FireServer = function()
                if CurrentRideId then
                    DismountPet()
                    return true
                end
                return OriginalRouterGet("AdoptAPI/ExitSeatStates"):FireServer()
            end
        }
    elseif endpoint == "SettingsAPI/SetPetRoleplayName" then
        return {
            InvokeServer = function(_, petUniqueId, newName)
                local pet = SpawnedPets[petUniqueId]
                if not pet then
                    return OriginalRouterGet("SettingsAPI/SetPetRoleplayName"):InvokeServer(petUniqueId, newName)
                end
                
                local identity = get_thread_identity and get_thread_identity() or 8
                set_thread_identity(2)
                
                local inventory = ClientData.get("inventory")
                if inventory and inventory.pets and inventory.pets[petUniqueId] then
                    inventory.pets[petUniqueId].properties.rp_name = newName
                end
                
                if pet.data then
                    pet.data.properties.rp_name = newName
                end
                
                local wrappers = ClientData.get("pet_char_wrappers")
                for _, wrapper in pairs(wrappers) do
                    if wrapper.pet_unique == petUniqueId then
                        wrapper.rp_name = newName
                        break
                    end
                end
                
                set_thread_identity(identity)
                return true
            end
        }
    else
        return OriginalRouterGet(endpoint)
    end
end

for _, wrapper in pairs(ClientData.get("pet_char_wrappers")) do
    OriginalRouterGet("ToolAPI/Unequip"):InvokeServer(wrapper.pet_unique)
end

-- UI Setup Start
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZetaPreppyUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

local uiScale = Instance.new("UIScale", screenGui)
uiScale.Scale = 0.7 -- Default scale for preppy feel

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 400) -- Slightly larger for preppy elements
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(240, 248, 255) -- AliceBlue, a soft pastel
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16) -- Softer corners
mainCorner.Parent = mainFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Thickness = 2 -- Slightly thinner stroke
uiStroke.Color = Color3.fromRGB(135, 206, 235) -- SkyBlue, another pastel
uiStroke.Parent = mainFrame

local palette = {
    Color3.fromRGB(173, 216, 230), -- Light Blue
    Color3.fromRGB(144, 238, 144), -- Light Green
    Color3.fromRGB(255, 182, 193), -- Light Pink
    Color3.fromRGB(250, 235, 215)  -- Light Tan
}
local colorIdx = 1
task.spawn(function()
    while true do
        colorIdx = colorIdx % #palette + 1
        TweenService:Create(uiStroke, TweenInfo.new(5), { Color = palette[colorIdx] }):Play() -- Slower color transition
        task.wait(5)
    end
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "✨ Zeta Scripts" -- Changed for a softer look
title.Font = Enum.Font.QuicksandBold -- A softer, rounded font
title.TextSize = 16 -- Slightly larger, friendly text
title.TextColor3 = Color3.fromRGB(65, 105, 225) -- RoyalBlue, a bit more vibrant but still elegant
title.Parent = mainFrame

local tabContainer = Instance.new('Frame')
tabContainer.Size = UDim2.new(0.92, 0, 0, 24) -- Slightly larger tabs
tabContainer.Position = UDim2.new(0.04, 0, 0, 34)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabs = {
    { key = 'Spawn', label = 'Pet Spawn' }, -- More descriptive label
    { key = 'Tools', label = 'Utilities' } -- Softer label
}

local activeTab = 'Spawn'
local tabElements = {}

local function SwitchTab(tabName)
    activeTab = tabName
    for name, data in pairs(tabElements) do
        local isActive = name == tabName
        data.button.BackgroundColor3 = isActive and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(200, 200, 210) -- Softer active/inactive colors
        data.button.Font = isActive and Enum.Font.QuicksandBold or Enum.Font.Quicksand
        data.button.TextSize = isActive and 10 or 9
        data.stroke.Color = isActive and Color3.fromRGB(100, 149, 237) or Color3.fromRGB(150, 150, 150) -- CornflowerBlue for active
        data.stroke.Thickness = isActive and 1.5 or 0.8
    end
    spawnPanel.Visible = tabName == 'Spawn'
    toolsPanel.Visible = tabName == 'Tools'
end

for i, tab in ipairs(tabs) do
    local tabButton = Instance.new('TextButton')
    tabButton.Size = UDim2.new(1 / #tabs - 0.02, 0, 1, 0)
    tabButton.Position = UDim2.new((i - 1) * (1 / #tabs), (i == 1) and 0 or 4, 0, 0)
    tabButton.BackgroundColor3 = i == 1 and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(200, 200, 210)
    tabButton.BackgroundTransparency = 0
    tabButton.Text = tab.label
    tabButton.Font = i == 1 and Enum.Font.QuicksandBold or Enum.Font.Quicksand
    tabButton.TextSize = i == 1 and 10 or 9
    tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabButton.Parent = tabContainer
    
    Instance.new("UICorner", tabButton).CornerRadius = UDim.new(0, 8)
    
    local tabStroke = Instance.new('UIStroke')
    tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    tabStroke.Color = i == 1 and Color3.fromRGB(100, 149, 237) or Color3.fromRGB(150, 150, 150)
    tabStroke.Thickness = i == 1 and 1.5 or 0.8
    tabStroke.Transparency = 0.3
    tabStroke.Parent = tabButton
    
    tabElements[tab.key] = { button = tabButton, stroke = tabStroke }
    
    tabButton.MouseButton1Click:Connect(function()
        SwitchTab(tab.key)
    end)
end

local spawnPanel = Instance.new("Frame")
spawnPanel.Size = UDim2.new(0.94, 0, 1, -60) -- Adjusted size
spawnPanel.Position = UDim2.new(0.03, 0, 0, 60)
spawnPanel.BackgroundTransparency = 1
spawnPanel.Parent = mainFrame

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0, 12)
nameLabel.Position = UDim2.new(0, 0, 0, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = "Pet Name"
nameLabel.Font = Enum.Font.Quicksand
nameLabel.TextSize = 10
nameLabel.TextColor3 = Color3.fromRGB(100, 100, 120) -- Softer label color
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Parent = spawnPanel

local nameInput = Instance.new("TextBox")
nameInput.Size = UDim2.new(1, 0, 0, 28) -- Slightly taller input
nameInput.Position = UDim2.new(0, 0, 0, 14)
nameInput.BackgroundColor3 = Color3.fromRGB(230, 230, 240) -- Light pastel background
nameInput.TextColor3 = Color3.fromRGB(50, 50, 70) -- Darker text for contrast
nameInput.TextSize = 12
nameInput.Font = Enum.Font.Quicksand
nameInput.PlaceholderText = "Enter pet name..."
nameInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 170)
nameInput.ClearTextOnFocus = false
nameInput.Text = "Bat Dragon" -- Default for quick testing
nameInput.Parent = spawnPanel

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = nameInput

local glowColors = {
    neutral = Color3.fromRGB(200, 200, 210),
    valid = Color3.fromRGB(144, 238, 144), -- Light Green
    invalid = Color3.fromRGB(255, 182, 193) -- Light Pink
}

local inputGlow = Instance.new("UIStroke")
inputGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
inputGlow.Color = glowColors.neutral
inputGlow.Thickness = 2
inputGlow.Transparency = 0.4
inputGlow.Parent = nameInput

local ageLabel = Instance.new("TextLabel")
ageLabel.Size = UDim2.new(1, 0, 0, 12)
ageLabel.Position = UDim2.new(0, 0, 0, 46)
ageLabel.BackgroundTransparency = 1
ageLabel.Text = "Age"
ageLabel.Font = Enum.Font.Quicksand
ageLabel.TextSize = 10
ageLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
ageLabel.TextXAlignment = Enum.TextXAlignment.Left
ageLabel.Parent = spawnPanel

local ageGrid = Instance.new("Frame")
ageGrid.Size = UDim2.new(1, 0, 0, 28) -- Slightly larger buttons
ageGrid.Position = UDim2.new(0, 0, 0, 60)
ageGrid.BackgroundTransparency = 1
ageGrid.Parent = spawnPanel

local ageCodes = {"N", "J", "P", "T", "P", "F"}
local ageDescriptions = {"Newborn", "Junior", "Pre-Teen", "Teen", "Post-Teen", "Full Grown"}
local currentAge = 1

for i, code in ipairs(ageCodes) do
    local ageButton = Instance.new("TextButton")
    ageButton.Size = UDim2.new(1/6 - 0.01, 0, 1, 0)
    ageButton.Position = UDim2.new((i-1) * (1/6), (i > 1) and 2 or 0, 0, 0)
    ageButton.Text = code
    ageButton.BackgroundColor3 = i == 1 and Color3.fromRGB(173, 216, 230) or Color3.fromRGB(220, 220, 230) -- Light Blue for active
    ageButton.Font = Enum.Font.QuicksandBold
    ageButton.TextColor3 = Color3.fromRGB(50, 50, 70)
    ageButton.TextSize = 11
    ageButton.Parent = ageGrid
    
    local ageCorner = Instance.new("UICorner")
    ageCorner.CornerRadius = UDim.new(0, 8)
    ageCorner.Parent = ageButton
    
    local hintBox = Instance.new("TextLabel")
    hintBox.Text = ageDescriptions[i]
    hintBox.BackgroundColor3 = Color3.fromRGB(240, 248, 255) -- AliceBlue
    hintBox.TextColor3 = Color3.fromRGB(50, 50, 70)
    hintBox.TextSize = 8
    hintBox.Font = Enum.Font.Quicksand
    hintBox.Size = UDim2.new(0, 0, 0, 0)
    hintBox.Visible = false
    hintBox.Parent = ageButton
    Instance.new("UICorner", hintBox).CornerRadius = UDim.new(0, 5)
    
    ageButton.MouseEnter:Connect(function()
        hintBox.Size = UDim2.new(0, 70, 0, 18)
        hintBox.Position = UDim2.new(0, 0, -1.3, 0)
        hintBox.Visible = true
    end)
    
    ageButton.MouseLeave:Connect(function()
        hintBox.Visible = false
    end)
    
    ageButton.MouseButton1Click:Connect(function()
        currentAge = i
        for _, btn in pairs(ageGrid:GetChildren()) do
            if btn:IsA("TextButton") then
                btn.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
            end
        end
        ageButton.BackgroundColor3 = Color3.fromRGB(173, 216, 230) -- Light Blue
    end)
end

local flagLabel = Instance.new("TextLabel")
flagLabel.Size = UDim2.new(1, 0, 0, 12)
flagLabel.Position = UDim2.new(0, 0, 0, 90)
flagLabel.BackgroundTransparency = 1
flagLabel.Text = "Pet Flags"
flagLabel.Font = Enum.Font.Quicksand
flagLabel.TextSize = 10
flagLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
flagLabel.TextXAlignment = Enum.TextXAlignment.Left
flagLabel.Parent = spawnPanel

local flagGrid = Instance.new("Frame")
flagGrid.Size = UDim2.new(1, 0, 0, 30) -- Larger flag buttons
flagGrid.Position = UDim2.new(0, 0, 0, 104)
flagGrid.BackgroundTransparency = 1
flagGrid.Parent = spawnPanel

local flagColors = {
    M = Color3.fromRGB(180, 120, 255), -- Purple pastel
    N = Color3.fromRGB(144, 238, 144), -- Light Green
    F = Color3.fromRGB(173, 216, 230), -- Light Blue
    R = Color3.fromRGB(255, 182, 193)  -- Light Pink
}

local flagOrder = {"M", "N", "F", "R"}
local flagState = {M = false, N = false, F = true, R = true} -- Default flags

for i, flag in ipairs(flagOrder) do
    local flagButton = Instance.new("TextButton")
    flagButton.Size = UDim2.new(0.23, -2, 1, 0)
    flagButton.Position = UDim2.new((i-1) * 0.25, (i > 1) and 3 or 0, 0, 0)
    flagButton.Text = flag
    flagButton.BackgroundColor3 = flagState[flag] and flagColors[flag] or Color3.fromRGB(220, 220, 230)
    flagButton.Font = Enum.Font.QuicksandBold
    flagButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flagButton.TextSize = 13
    flagButton.Parent = flagGrid
    
    local flagCorner = Instance.new("UICorner")
    flagCorner.CornerRadius = UDim.new(0, 8)
    flagCorner.Parent = flagButton
    
    local flagStroke = Instance.new("UIStroke")
    flagStroke.Color = flagColors[flag]
    flagStroke.Thickness = flagState[flag] and 2.5 or 1.5
    flagStroke.Transparency = flagState[flag] and 0.2 or 0.5
    flagStroke.Parent = flagButton
    
    flagButton.MouseButton1Click:Connect(function()
        -- Prevent conflicting flags
        if flag == "M" and flagState["N"] then return end
        if flag == "N" and flagState["M"] then return end
        
        flagState[flag] = not flagState[flag]
        
        if flagState[flag] then
            flagButton.BackgroundColor3 = flagColors[flag]
            TweenService:Create(flagStroke, TweenInfo.new(0.2), {
                Thickness = 2.5,
                Transparency = 0.2
            }):Play()
        else
            flagButton.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
            TweenService:Create(flagStroke, TweenInfo.new(0.2), {
                Thickness = 1.5,
                Transparency = 0.5
            }):Play()
        end
    end)
end

local quickLabel = Instance.new("TextLabel")
quickLabel.Size = UDim2.new(1, 0, 0, 12)
quickLabel.Position = UDim2.new(0, 0, 0, 138)
quickLabel.BackgroundTransparency = 1
quickLabel.Text = "Quick Select"
quickLabel.Font = Enum.Font.Quicksand
quickLabel.TextSize = 10
quickLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
quickLabel.TextXAlignment = Enum.TextXAlignment.Left
quickLabel.Parent = spawnPanel

local quickGrid = Instance.new("Frame")
quickGrid.Size = UDim2.new(1, 0, 0, 50) -- Larger quick select buttons
quickGrid.Position = UDim2.new(0, 0, 0, 150)
quickGrid.BackgroundTransparency = 1
quickGrid.Parent = spawnPanel

local quickPets = {
    {"Shadow Dragon", Color3.fromRGB(100, 100, 150)}, -- Muted purple
    {"Frost Dragon", Color3.fromRGB(135, 206, 250)}, -- Sky Blue
    {"Bat Dragon", Color3.fromRGB(255, 105, 180)}, -- Hot Pink (slightly muted)
    {"Giraffe", Color3.fromRGB(255, 218, 185)}, -- Peach Puff
    {"Owl", Color3.fromRGB(210, 180, 140)}, -- Tan
    {"Parrot", Color3.fromRGB(255, 160, 122)} -- Light Salmon
}

for i, petData in ipairs(quickPets) do
    local row = math.floor((i-1) / 3)
    local col = (i-1) % 3
    
    local quickButton = Instance.new("TextButton")
    quickButton.Size = UDim2.new(0.32, -2, 0.45, 0)
    quickButton.Position = UDim2.new(col * 0.33, (col > 0) and 3 or 0, row * 0.5, (row > 0) and 3 or 0)
    
    if i <= 3 then
        quickButton.Text = petData[1]
    else
        quickButton.Text = petData[1]:match("^(%w+)") or petData[1]
    end
    
    quickButton.BackgroundColor3 = petData[2]
    quickButton.Font = Enum.Font.QuicksandBold
    quickButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    quickButton.TextSize = 8 -- Smaller text for quick select
    quickButton.Parent = quickGrid
    
    local quickCorner = Instance.new("UICorner")
    quickCorner.CornerRadius = UDim.new(0, 6)
    quickCorner.Parent = quickButton
    
    quickButton.MouseButton1Click:Connect(function()
        nameInput.Text = petData[1]
        -- Update glow based on the new text
        local text = nameInput.Text
        local isValid = FindPetId(text) ~= nil
        inputGlow.Color = isValid and glowColors.valid or glowColors.invalid
    end)
end

local spawnAllButton = Instance.new("TextButton")
spawnAllButton.Size = UDim2.new(1, 0, 0, 28) -- Taller button
spawnAllButton.Position = UDim2.new(0, 0, 0, 200)
spawnAllButton.Text = "🌟 Spawn All High Tiers" -- Softer icon and text
spawnAllButton.Font = Enum.Font.QuicksandBold
spawnAllButton.TextSize = 11
spawnAllButton.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Light Orange
spawnAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnAllButton.Parent = spawnPanel

local allCorner = Instance.new("UICorner")
allCorner.CornerRadius = UDim.new(0, 10)
allCorner.Parent = spawnAllButton

local allStroke = Instance.new("UIStroke")
allStroke.Color = Color3.fromRGB(255, 230, 150) -- Lighter yellow stroke
allStroke.Thickness = 2
allStroke.Transparency = 0.3
allStroke.Parent = spawnAllButton

local spawnButton = Instance.new("TextButton")
spawnButton.Size = UDim2.new(1, 0, 0, 32) -- Taller spawn button
spawnButton.Position = UDim2.new(0, 0, 1, -40)
spawnButton.Text = "Spawn Pet"
spawnButton.Font = Enum.Font.QuicksandBold
spawnButton.TextSize = 14
spawnButton.BackgroundColor3 = Color3.fromRGB(100, 149, 237) -- CornflowerBlue
spawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnButton.Parent = spawnPanel

local spawnCorner = Instance.new("UICorner")
spawnCorner.CornerRadius = UDim.new(0, 12)
spawnCorner.Parent = spawnButton

local toolsPanel = Instance.new("Frame")
toolsPanel.Size = UDim2.new(0.94, 0, 1, -60)
toolsPanel.Position = UDim2.new(0.03, 0, 0, 60)
toolsPanel.BackgroundTransparency = 1
toolsPanel.Parent = mainFrame

local toolsTitle = Instance.new("TextLabel")
toolsTitle.Size = UDim2.new(1, 0, 0, 16)
toolsTitle.Position = UDim2.new(0, 0, 0, 0)
toolsTitle.BackgroundTransparency = 1
toolsTitle.Text = "Utilities"
toolsTitle.Font = Enum.Font.QuicksandBold
toolsTitle.TextSize = 14
toolsTitle.TextColor3 = Color3.fromRGB(65, 105, 225)
toolsTitle.TextXAlignment = Enum.TextXAlignment.Left
toolsTitle.Parent = toolsPanel

local deleteButton = Instance.new("TextButton")
deleteButton.Size = UDim2.new(1, 0, 0, 28)
deleteButton.Position = UDim2.new(0, 0, 0, 25)
deleteButton.Text = "🗑️ Delete All My Pets"
deleteButton.Font = Enum.Font.QuicksandBold
deleteButton.TextSize = 11
deleteButton.BackgroundColor3 = Color3.fromRGB(255, 105, 180) -- Hot Pink
deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deleteButton.Parent = toolsPanel
Instance.new("UICorner", deleteButton).CornerRadius = UDim.new(0, 10)

deleteButton.MouseButton1Click:Connect(function()
    local count = DeleteAllSpawnedPets()
    deleteButton.Text = "✓ Deleted " .. count .. "!"
    TweenService:Create(deleteButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play()
    task.wait(1.2)
    deleteButton.Text = "🗑️ Delete All My Pets"
    TweenService:Create(deleteButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 105, 180)}):Play()
end)

local scaleLabel = Instance.new("TextLabel")
scaleLabel.Size = UDim2.new(1, 0, 0, 12)
scaleLabel.Position = UDim2.new(0, 0, 0, 60)
scaleLabel.BackgroundTransparency = 1
scaleLabel.Text = "UI Scale"
scaleLabel.Font = Enum.Font.Quicksand
scaleLabel.TextSize = 10
scaleLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
scaleLabel.TextXAlignment = Enum.TextXAlignment.Left
scaleLabel.Parent = toolsPanel

local scaleControls = Instance.new("Frame")
scaleControls.Size = UDim2.new(1, 0, 0, 30)
scaleControls.Position = UDim2.new(0, 0, 0, 73)
scaleControls.BackgroundTransparency = 1
scaleControls.Parent = toolsPanel

local scaleDown = Instance.new("TextButton")
scaleDown.Size = UDim2.new(0.2, 0, 1, 0)
scaleDown.Position = UDim2.new(0, 0, 0, 0)
scaleDown.Text = "−"
scaleDown.Font = Enum.Font.QuicksandBold
scaleDown.TextSize = 14
scaleDown.BackgroundColor3 = Color3.fromRGB(255, 105, 180) -- Hot Pink
scaleDown.TextColor3 = Color3.fromRGB(255, 255, 255)
scaleDown.Parent = scaleControls
Instance.new("UICorner", scaleDown).CornerRadius = UDim.new(0, 8)

local scaleValue = Instance.new("TextLabel")
scaleValue.Size = UDim2.new(0.5, 0, 1, 0)
scaleValue.Position = UDim2.new(0.25, 0, 0, 0)
scaleValue.BackgroundColor3 = Color3.fromRGB(230, 230, 240)
scaleValue.TextColor3 = Color3.fromRGB(50, 50, 70)
scaleValue.Text = "70%"
scaleValue.Font = Enum.Font.QuicksandBold
scaleValue.TextSize = 11
scaleValue.Parent = scaleControls
Instance.new("UICorner", scaleValue).CornerRadius = UDim.new(0, 8)

local scaleUp = Instance.new("TextButton")
scaleUp.Size = UDim2.new(0.2, 0, 1, 0)
scaleUp.Position = UDim2.new(0.8, 0, 0, 0)
scaleUp.Text = "+"
scaleUp.Font = Enum.Font.QuicksandBold
scaleUp.TextSize = 14
scaleUp.BackgroundColor3 = Color3.fromRGB(144, 238, 144) -- Light Green
scaleUp.TextColor3 = Color3.fromRGB(255, 255, 255)
scaleUp.Parent = scaleControls
Instance.new("UICorner", scaleUp).CornerRadius = UDim.new(0, 8)

local resetScale = Instance.new("TextButton")
resetScale.Size = UDim2.new(1, 0, 0, 24)
resetScale.Position = UDim2.new(0, 0, 0, 100)
resetScale.Text = "↺ Reset to 70%"
resetScale.Font = Enum.Font.QuicksandBold
resetScale.TextSize = 9
resetScale.BackgroundColor3 = Color3.fromRGB(173, 216, 230) -- Light Blue
resetScale.TextColor3 = Color3.fromRGB(255, 255, 255)
resetScale.Parent = toolsPanel
Instance.new("UICorner", resetScale).CornerRadius = UDim.new(0, 8)

local lockButton = Instance.new("TextButton")
lockButton.Size = UDim2.new(1, 0, 0, 24)
lockButton.Position = UDim2.new(0, 0, 0, 129)
lockButton.Text = "🔓 Unlocked"
lockButton.Font = Enum.Font.QuicksandBold
lockButton.TextSize = 9
lockButton.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Light Orange
lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
lockButton.Parent = toolsPanel
Instance.new("UICorner", lockButton).CornerRadius = UDim.new(0, 8)

local currentScale = 0.7

scaleDown.MouseButton1Click:Connect(function()
    currentScale = math.max(0.5, currentScale - 0.1)
    uiScale.Scale = currentScale
    scaleValue.Text = math.floor(currentScale * 100) .. "%"
    TweenService:Create(scaleDown, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 150, 150)}):Play()
    task.wait(0.2)
    TweenService:Create(scaleDown, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 105, 180)}):Play()
end)

scaleUp.MouseButton1Click:Connect(function()
    currentScale = math.min(2.0, currentScale + 0.1)
    uiScale.Scale = currentScale
    scaleValue.Text = math.floor(currentScale * 100) .. "%"
    TweenService:Create(scaleUp, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(150, 255, 150)}):Play()
    task.wait(0.2)
    TweenService:Create(scaleUp, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play()
end)

resetScale.MouseButton1Click:Connect(function()
    currentScale = 0.7
    uiScale.Scale = currentScale
    scaleValue.Text = "70%"
    TweenService:Create(resetScale, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(150, 150, 230)}):Play()
    task.wait(0.2)
    TweenService:Create(resetScale, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(173, 216, 230)}):Play()
end)

local uiLocked = false
lockButton.MouseButton1Click:Connect(function()
    uiLocked = not uiLocked
    if uiLocked then
        lockButton.Text = "🔒 Locked"
        lockButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150) -- Grey out when locked
    else
        lockButton.Text = "🔓 Unlocked"
        lockButton.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Back to original color
    end
end)

local dragging = false
local dragStart, startPos

mainFrame.InputBegan:Connect(function(input)
    if not uiLocked and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

mainFrame.InputChanged:Connect(function(input)
    if not uiLocked and dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Initial tab setup
SwitchTab(activeTab)

spawnButton.MouseButton1Click:Connect(function()
    local petName = nameInput.Text
    if petName == "" then 
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 100, 100)}):Play()
        task.wait(0.2)
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 149, 237)}):Play()
        return 
    end
    
    local petId = FindPetId(petName)
    if not petId then 
        inputGlow.Color = glowColors.invalid
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 100, 100)}):Play()
        task.wait(0.2)
        TweenService:Create(spawnButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 149, 237)}):Play()
        return 
    end
    
    local ageMap = {1, 2, 3, 4, 5, 6}
    local options = {
        mega_neon = flagState["M"],
        neon = flagState["N"],
        flyable = flagState["F"],
        rideable = flagState["R"],
        age = ageMap[currentAge],
        trick_level = 5,
        ailments_completed = 0,
        rp_name = GenerateUniquePetName() -- Always generate a unique name for new spawns
    }
    
    local item = CreateInventoryItem(petId, "pets", options)
    if item then
        spawnButton.Text = "✓ Spawned!"
        TweenService:Create(spawnButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play() -- Green flash for success
        task.wait(1)
        spawnButton.Text = "Spawn Pet"
        TweenService:Create(spawnButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(100, 149, 237)}):Play() -- Back to original
    end
end)

spawnAllButton.MouseButton1Click:Connect(function()
    local ageMap = {1, 2, 3, 4, 5, 6}
    local options = {
        mega_neon = flagState["M"],
        neon = flagState["N"],
        flyable = flagState["F"],
        rideable = flagState["R"],
        age = ageMap[currentAge],
        trick_level = 5,
        ailments_completed = 0
    }
    
    local successCount = 0
    spawnAllButton.Text = "⚡ Spawning..."
    TweenService:Create(spawnAllButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 230, 150)}):Play()
    
    for _, petName in ipairs(HighTierPets) do
        local petId = FindPetId(petName)
        if petId then
            local petOptions = table.clone(options)
            petOptions.rp_name = GenerateUniquePetName() -- Ensure each pet gets a unique name
            
            local item = CreateInventoryItem(petId, "pets", petOptions)
            if item then
                successCount = successCount + 1
            end
        end
    end
    
    spawnAllButton.Text = "✓ Spawned " .. successCount .. "!"
    TweenService:Create(spawnAllButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(144, 238, 144)}):Play()
    task.wait(1.5)
    spawnAllButton.Text = "🌟 Spawn All High Tiers"
    TweenService:Create(spawnAllButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 200, 100)}):Play()
end)

nameInput:GetPropertyChangedSignal("Text"):Connect(function()
    local text = nameInput.Text
    if text == "" then
        inputGlow.Color = glowColors.neutral
        return
    end
    
    local isValid = FindPetId(text) ~= nil
    inputGlow.Color = isValid and glowColors.valid or glowColors.invalid
end)


