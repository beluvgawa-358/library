--// Cosmetic Changer GUI
--// Matches reference layout; themed from Library; data + icons fetched from game

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local getgenv = getgenv
local InstanceNew = Instance.new
local FromRGB = Color3.fromRGB
local UDim2New = UDim2.new
local UDimNew = UDim.new
local Vector2New = Vector2.new
local MathClamp = math.clamp
local TableInsert = table.insert
local TableFind = table.find
local StringLower = string.lower
local StringFormat = string.format

-- wait for library (optional — falls back to preset theme)
local Library = getgenv().Library
local Theme = (Library and Library.Theme) or {
    Background = FromRGB(13, 15, 18),
    Inline = FromRGB(22, 25, 30),
    Outline = FromRGB(26, 30, 36),
    Text = FromRGB(200, 200, 200),
    ["Dark Text"] = FromRGB(100, 100, 100),
    Element = FromRGB(28, 32, 38),
    Accent = FromRGB(184, 212, 255),
}
local Font = (Library and Library.Font) or Font.fromEnum(Enum.Font.GothamMedium)

if getgenv().CosmeticChanger then
    pcall(function() getgenv().CosmeticChanger:Destroy() end)
end

local CosmeticChanger = {}

-- ============================================================
-- helpers
-- ============================================================

local function create(class, props)
    local inst = InstanceNew(class)
    for k, v in props do
        pcall(function() inst[k] = v end)
    end
    return inst
end

local function corner(parent, r)
    return create("UICorner", { Parent = parent, CornerRadius = UDimNew(0, r or 5) })
end

local function stroke(parent, color, thickness)
    return create("UIStroke", {
        Parent = parent,
        Color = color or Theme.Outline,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function tween(inst, info, goal)
    local t = TweenService:Create(inst, info or TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    t:Play()
    return t
end

-- ============================================================
-- icon fetching from game
-- ============================================================

local ICON_ATTR_KEYS = {
    "Icon", "Image", "ImageId", "Thumbnail", "ThumbnailId",
    "EmoteIcon", "EmoteImage", "Sprite", "SpriteId", "AssetIcon",
}

local function extractAssetId(value)
    if type(value) == "number" then return tostring(value) end
    if type(value) ~= "string" then return nil end
    return value:match("rbxassetid://(%d+)") or value:match("(%d+)")
end

local function getAttrIcon(obj)
    for _, key in ICON_ATTR_KEYS do
        local ok, val = pcall(function() return obj:GetAttribute(key) end)
        if ok and val ~= nil then
            local id = extractAssetId(val)
            if id then return "rbxassetid://" .. id end
        end
    end
    -- scan string children for icon refs
    for _, child in obj:GetDescendants() do
        if child:IsA("StringValue") then
            local id = extractAssetId(child.Value)
            if id and (child.Name:lower():find("icon") or child.Name:lower():find("image") or child.Name:lower():find("thumb")) then
                return "rbxassetid://" .. id
            end
        end
    end
    return nil
end

local function getToolImage(obj)
    if not obj then return nil end
    local ok, icon = pcall(function()
        if obj:IsA("Tool") then return obj.TextureId end
        if obj:IsA("Decal") then return obj.Texture end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then return obj.Image end
        if obj:IsA("SpecialMesh") then return obj.TextureId end
        if obj:IsA("DataModelMesh") then return obj.TextureId end
        return nil
    end)
    if ok and icon and icon ~= "" then
        local id = extractAssetId(icon)
        if id then return "rbxassetid://" .. id end
    end
    return nil
end

local function getMeshTexture(obj)
    if not obj then return nil end
    for _, d in obj:GetDescendants() do
        if d:IsA("SpecialMesh") or d:IsA("FileMesh") then
            local id = extractAssetId(d.TextureId or "")
            if id then return "rbxassetid://" .. id end
        end
        if d:IsA("Decal") or d:IsA("Texture") then
            local id = extractAssetId(d.Texture or "")
            if id then return "rbxassetid://" .. id end
        end
    end
    return nil
end

-- ViewportFrame snapshot: render 3D model → ImageLabel-compatible texture
local function renderModelToImage(model, size)
    size = size or 128
    if not model then return nil end

    local vp = create("ViewportFrame", {
        BackgroundColor3 = FromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Size = UDim2New(0, size, 0, size),
        Ambient = FromRGB(120, 120, 120),
        LightColor = FromRGB(255, 255, 255),
        LightDirection = Vector3.new(-1, -1, -1),
        Parent = create("ScreenGui", {
            Parent = (gethui and gethui()) or game:GetService("CoreGui"),
            Enabled = true,
            DisplayOrder = -99999,
            ResetOnSpawn = false,
        }),
    })

    local world = create("WorldModel", { Parent = vp })
    local clone = model:Clone()
    clone.Parent = world

    -- frame the model
    task.wait(0.1)
    local cf, size3 = nil, nil
    pcall(function()
        if clone:IsA("Model") then
            cf, size3 = clone:GetBoundingBox()
        elseif clone:IsA("BasePart") then
            cf = clone.CFrame
            size3 = clone.Size
        elseif clone:IsA("Folder") or clone:IsA("Attachment") then
            local minV, maxV
            for _, d in clone:GetDescendants() do
                if d:IsA("BasePart") then
                    local cfD, sizeD = d:GetBoundingBox()
                    local half = sizeD / 2
                    local corners = {
                        cfD.Position + Vector3.new(-half.X, -half.Y, -half.Z),
                        cfD.Position + Vector3.new(half.X, half.Y, half.Z),
                    }
                    for _, p in corners do
                        minV = minV and Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z)) or p
                        maxV = maxV and Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z)) or p
                    end
                end
            end
            if minV and maxV then
                size3 = maxV - minV
                cf = CFrame.new((minV + maxV) / 2)
            end
        end
    end)
    if not cf then
        local gui = vp.Parent
        vp:Destroy()
        if gui then gui:Destroy() end
        return nil
    end

    local maxDim = math.max(size3.X, size3.Y, size3.Z)
    local dist = maxDim * 1.8 + 1
    local camPos = cf.Position + Vector3.new(dist * 0.55, dist * 0.35, -dist * 0.75)
    local lookAt = cf.Position

    vp.Camera = create("Camera", {
        CFrame = CFrame.lookAt(camPos, lookAt),
        FieldOfView = 45,
        Parent = vp,
    })

    task.wait(0.15)

    -- capture via ViewportFrame.CurrentCamera isn't directly to texture without CaptureScreenshot;
    -- instead return the viewport itself for embedding, or try contentProvider preloaded decal
    -- For ImageLabel we extract texture from mesh; for viewport we embed the frame directly.
    local result = { Viewport = vp, Gui = vp.Parent }
    return result
end

local function resolveIcon(obj)
    if not obj then return nil end

    local ok, icon = pcall(function()
        local found = getAttrIcon(obj)
        if found then return found end
        found = getToolImage(obj)
        if found then return found end
        found = getMeshTexture(obj)
        if found then return found end

        for _, child in obj:GetChildren() do
            if child:IsA("ObjectValue") and child.Value then
                local v = child.Value
                if v:IsA("Decal") or v:IsA("ImageLabel") then
                    local id = extractAssetId(v.Texture or v.Image or "")
                    if id then return "rbxassetid://" .. id end
                end
            end
        end

        local id = extractAssetId(obj.Name)
        if id then
            return "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150"
        end
        return nil
    end)
    if ok then return icon end
    return nil
end

-- ============================================================
-- data fetching from game
-- ============================================================

local function safeRequire(path)
    local ok, result = pcall(function()
        local node = ReplicatedStorage
        for segment in path:gmatch("[^%.]+") do
            node = node:WaitForChild(segment, 5)
            if not node then return nil end
        end
        return require(node)
    end)
    return ok and result or nil
end

local function listChildren(folder)
    local items = {}
    if not folder then return items end
    for _, child in folder:GetChildren() do
        TableInsert(items, child)
    end
    return items
end

-- Weapons: swords module + folder listing + any tool/weapon folders
local function fetchWeapons()
    local weapons = {}
    local seen = {}

    local function add(name, instance, category)
        if not name or name == "" or seen[name] then return end
        seen[name] = true
        TableInsert(weapons, {
            Name = name,
            Instance = instance,
            Category = category or "weapon",
        })
    end

    -- Swords (primary weapons from source)
    local swordsModule = safeRequire("Shared.ReplicatedInstances.Swords")
    if type(swordsModule) == "table" then
        for key, value in swordsModule do
            if type(key) == "string" and key ~= "" and (type(value) == "table" or typeof(value) == "Instance") then
                add(key, typeof(value) == "Instance" and value or nil, "sword")
            end
        end
    end

    local swordsFolder = ReplicatedStorage:FindFirstChild("Shared")
        and ReplicatedStorage.Shared:FindFirstChild("ReplicatedInstances")
        and ReplicatedStorage.Shared.ReplicatedInstances:FindFirstChild("Swords")
    if swordsFolder then
        for _, child in swordsFolder:GetChildren() do
            add(child.Name, child, "sword")
        end
    end

    -- Explosions as weapon-adjacent cosmetics categories
    local expFolders = {
        ReplicatedStorage:FindFirstChild("Shared")
            and ReplicatedStorage.Shared:FindFirstChild("ReplicatedInstances")
            and ReplicatedStorage.Shared.ReplicatedInstances:FindFirstChild("Explosions"),
        ReplicatedStorage:FindFirstChild("Misc")
            and ReplicatedStorage.Misc:FindFirstChild("DataExplosions"),
        ReplicatedStorage:FindFirstChild("ExplosionEffects"),
    }
    for _, folder in expFolders do
        if folder then
            for _, child in folder:GetChildren() do
                add(child.Name, child, "explosion")
            end
        end
    end

    -- Emotes as selectable cosmetics
    local emoteFolders = {}
    local misc = ReplicatedStorage:FindFirstChild("Misc")
    if misc and misc:FindFirstChild("Emotes") then TableInsert(emoteFolders, misc.Emotes) end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local ri = shared and shared:FindFirstChild("ReplicatedInstances")
    if ri and ri:FindFirstChild("Emotes") then TableInsert(emoteFolders, ri.Emotes) end
    for _, folder in ReplicatedStorage:GetDescendants() do
        if folder:IsA("Folder") and folder.Name == "Emotes" and not TableFind(emoteFolders, folder) then
            TableInsert(emoteFolders, folder)
        end
    end
    for _, folder in emoteFolders do
        for _, desc in folder:GetDescendants() do
            if desc:IsA("Animation") then
                local name = desc:GetAttribute("EmoteName") or desc.Name
                add(name, desc, "emote")
            end
        end
    end

    -- Generic weapon/tool scan
    for _, containerName in {"Weapons", "GunKit", "ToolKit", "Items"} do
        local container = ReplicatedStorage:FindFirstChild(containerName) or workspace:FindFirstChild(containerName)
        if container then
            for _, child in container:GetChildren() do
                add(child.Name, child, "weapon")
            end
        end
    end

    table.sort(weapons, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return weapons
end

-- Cosmetics/skins for a given weapon
local function fetchCosmetics(weapon)
    local cosmetics = {}
    if not weapon then return cosmetics end

    local seen = {}
    local function add(name, instance)
        if not name or name == "" or seen[name] then return end
        seen[name] = true
        TableInsert(cosmetics, { Name = name, Instance = instance })
    end

    local obj = weapon.Instance
    local category = weapon.Category

    -- skin/variant folders near the weapon
    if obj then
        local parent = obj.Parent
        if parent then
            for _, sibling in parent:GetChildren() do
                if sibling ~= obj then
                    local n = sibling.Name:lower()
                    if n:find("skin") or n:find("variant") or n:find("camo") or n:find("paint") then
                        if sibling:IsA("Folder") or sibling:IsA("Configuration") then
                            for _, sub in sibling:GetChildren() do
                                add(sub.Name, sub)
                            end
                        else
                            add(sibling.Name, sibling)
                        end
                    end
                end
            end
        end

        -- children marked as skins
        for _, child in obj:GetChildren() do
            local n = child.Name:lower()
            if n:find("skin") or n:find("variant") or n:find("alternate") or n:find("alt") then
                add(child.Name, child)
            end
        end

        -- attributes listing skin names
        for _, attrName in {"Skins", "Variants", "Cosmetics", "Paints"} do
            local ok, val = pcall(function() return obj:GetAttribute(attrName) end)
            if ok and type(val) == "string" then
                for skinName in val:gmatch("[^,]+") do
                    add(skinName:match("^%s*(.-)%s*$"), nil)
                end
            elseif ok and type(val) == "table" then
                for _, skinName in val do
                    add(tostring(skinName), nil)
                end
            end
        end
    end

    -- category-specific fallbacks
    if category == "sword" then
        -- all other swords as alternate looks if no explicit skins found
        if #cosmetics == 0 then
            local swordsFolder = ReplicatedStorage:FindFirstChild("Shared")
                and ReplicatedStorage.Shared:FindFirstChild("ReplicatedInstances")
                and ReplicatedStorage.Shared.ReplicatedInstances:FindFirstChild("Swords")
            if swordsFolder then
                for _, s in swordsFolder:GetChildren() do
                    if not obj or s ~= obj then
                        add(s.Name, s)
                    end
                end
            end
        end
    elseif category == "explosion" then
        local effects = ReplicatedStorage:FindFirstChild("ExplosionEffects")
        if effects then
            for _, e in effects:GetDescendants() do
                add(e.Name, e)
            end
        end
    elseif category == "emote" then
        -- all emotes as alternate picks
        local misc = ReplicatedStorage:FindFirstChild("Misc")
        local folder = misc and misc:FindFirstChild("Emotes")
        if folder then
            for _, desc in folder:GetDescendants() do
                if desc:IsA("Animation") then
                    local name = desc:GetAttribute("EmoteName") or desc.Name
                    if not obj or desc ~= obj then add(name, desc) end
                end
            end
        end
    end

    -- if still empty, pull from a global Skins/Cosmetics catalog and fuzzy-match
    if #cosmetics == 0 then
        for _, rootName in {"Skins", "Cosmetics", "PaintJobs", "Liveries"} do
            local root = ReplicatedStorage:FindFirstChild(rootName)
            if root then
                for _, child in root:GetDescendants() do
                    local cn, wn = child.Name:lower(), weapon.Name:lower()
                    if (cn:find(wn, 1, true)) or (child.Parent and wn:find(child.Parent.Name:lower(), 1, true)) then
                        add(child.Name, child)
                    end
                end
            end
        end
    end

    table.sort(cosmetics, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return cosmetics
end

-- ============================================================
-- window UI — matches reference image
-- ============================================================

local holder = create("ScreenGui", {
    Parent = (gethui and gethui()) or game:GetService("CoreGui"),
    Name = "\0",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 5,
    ResetOnSpawn = false,
})

local main = create("Frame", {
    Parent = holder,
    Name = "\0",
    AnchorPoint = Vector2New(0.5, 0.5),
    Position = UDim2New(0.5, 0, 0.5, 0),
    Size = UDim2New(0, 520, 0, 620),
    BackgroundColor3 = Theme.Background,
    BorderColor3 = FromRGB(0, 0, 0),
    BorderSizePixel = 0,
})
corner(main, 6)
stroke(main, Theme.Accent, 1.5)

-- outer glow
create("ImageLabel", {
    Parent = main,
    Name = "\0",
    ImageColor3 = Theme.Accent,
    ImageTransparency = 0.6,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(Vector2New(21, 21), Vector2New(79, 79)),
    Image = "http://www.roblox.com/asset/?id=18245826428",
    BackgroundTransparency = 1,
    Size = UDim2New(1, 30, 1, 30),
    AnchorPoint = Vector2New(0.5, 0.5),
    Position = UDim2New(0.5, 0, 0.5, 0),
    ZIndex = -1,
})

-- title
create("TextLabel", {
    Parent = main,
    Name = "\0",
    FontFace = Font,
    Text = "Cosmetic Changer",
    TextColor3 = Theme.Text,
    TextSize = 14,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2New(1, 0, 0, 28),
    Position = UDim2New(0, 0, 0, 6),
})

-- content scroll
local content = create("ScrollingFrame", {
    Parent = main,
    Name = "\0",
    Position = UDim2New(0, 10, 0, 34),
    Size = UDim2New(1, -20, 1, -110),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2New(0, 0, 0, 0),
    ClipsDescendants = false,
})
create("UIListLayout", {
    Parent = content,
    Name = "\0",
    Padding = UDimNew(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

-- section builder: label + filter box + grid
local function buildSection(order, labelText, placeholder)
    local section = create("Frame", {
        Parent = content,
        Name = "\0",
        LayoutOrder = order,
        Size = UDim2New(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        BorderColor3 = FromRGB(0, 0, 0),
        BorderSizePixel = 0,
    })
    corner(section, 5)
    stroke(section, Theme.Outline)

    create("TextLabel", {
        Parent = section,
        Name = "\0",
        FontFace = Font,
        Text = labelText,
        TextColor3 = Theme["Dark Text"],
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2New(0, 8, 0, 6),
        Size = UDim2New(1, -16, 0, 14),
    })

    local filterBox = create("Frame", {
        Parent = section,
        Name = "\0",
        Position = UDim2New(0, 8, 0, 22),
        Size = UDim2New(1, -16, 0, 22),
        BackgroundColor3 = Theme.Element,
        BorderColor3 = FromRGB(0, 0, 0),
        BorderSizePixel = 0,
    })
    corner(filterBox, 4)

    local filterInput = create("TextBox", {
        Parent = filterBox,
        Name = "\0",
        FontFace = Font,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = Theme["Dark Text"],
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2New(1, -16, 1, 0),
        Position = UDim2New(0, 8, 0, 0),
        ClearTextOnFocus = false,
    })

    local gridHolder = create("ScrollingFrame", {
        Parent = section,
        Name = "\0",
        Position = UDim2New(0, 8, 0, 50),
        Size = UDim2New(1, -16, 0, 168),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2New(0, 0, 0, 0),
        ClipsDescendants = true,
    })
    local grid = create("UIGridLayout", {
        Parent = gridHolder,
        Name = "\0",
        CellSize = UDim2New(0, 74, 0, 84),
        CellPadding = UDim2New(0, 8, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    })

    -- section bottom padding via automatic size on parent
    create("UIPadding", {
        Parent = section,
        Name = "\0",
        PaddingBottom = UDimNew(0, 8),
    })

    return {
        Section = section,
        FilterInput = filterInput,
        GridHolder = gridHolder,
        Grid = grid,
        Cards = {},
    }
end

local weaponSection = buildSection(1, "weapon filter", "search weapons...")
local cosmeticSection = buildSection(2, "cosmetic filter", "search cosmetics...")

-- skin dropdown row
local skinRow = create("Frame", {
    Parent = content,
    Name = "\0",
    LayoutOrder = 3,
    Size = UDim2New(1, 0, 0, 44),
    BackgroundTransparency = 1,
})

create("TextLabel", {
    Parent = skinRow,
    Name = "\0",
    FontFace = Font,
    Text = "skin",
    TextColor3 = Theme["Dark Text"],
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2New(0, 0, 0, 0),
    Size = UDim2New(1, 0, 0, 14),
})

local skinDropdownBtn = create("TextButton", {
    Parent = skinRow,
    Name = "\0",
    FontFace = Font,
    Text = "",
    AutoButtonColor = false,
    BackgroundColor3 = Theme.Element,
    BorderColor3 = FromRGB(0, 0, 0),
    BorderSizePixel = 0,
    Position = UDim2New(0, 0, 0, 18),
    Size = UDim2New(1, 0, 0, 24),
})
corner(skinDropdownBtn, 4)

local skinDropdownLabel = create("TextLabel", {
    Parent = skinDropdownBtn,
    Name = "\0",
    FontFace = Font,
    Text = "none",
    TextColor3 = Theme["Dark Text"],
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2New(0, 10, 0, 0),
    Size = UDim2New(1, -40, 1, 0),
})

local chevronId = "6031094678"
if Library and Library.GetIcon then
    local ok, id = pcall(function() return Library:GetIcon("chevron-down") end)
    if ok and id then chevronId = tostring(id) end
end

create("ImageLabel", {
    Parent = skinDropdownBtn,
    Name = "\0",
    Image = "rbxassetid://" .. chevronId,
    ImageColor3 = Theme.Text,
    ImageTransparency = 0.5,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2New(1, 0.5),
    Position = UDim2New(1, -6, 0.5, 0),
    Size = UDim2New(0, 14, 0, 14),
})

-- dropdown options popup
local optionsHolder = create("TextButton", {
    Parent = holder,
    Name = "\0",
    Visible = false,
    Text = "",
    AutoButtonColor = false,
    BackgroundColor3 = Theme.Background,
    BorderColor3 = FromRGB(0, 0, 0),
    BorderSizePixel = 0,
    ZIndex = 500,
    Size = UDim2New(0, 200, 0, 0),
})
corner(optionsHolder, 5)
stroke(optionsHolder, Theme.Outline)

local optionsList = create("ScrollingFrame", {
    Parent = optionsHolder,
    Name = "\0",
    Position = UDim2New(0, 4, 0, 4),
    Size = UDim2New(1, -8, 1, -8),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2New(0, 0, 0, 0),
    ZIndex = 501,
})
create("UIListLayout", {
    Parent = optionsList,
    Name = "\0",
    Padding = UDimNew(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
    ZIndex = 501,
})

-- buttons row
local buttonsRow = create("Frame", {
    Parent = main,
    Name = "\0",
    AnchorPoint = Vector2New(0, 1),
    Position = UDim2New(0, 10, 1, -28),
    Size = UDim2New(1, -20, 0, 22),
    BackgroundTransparency = 1,
})

local function makeButton(parent, text, order, callback)
    local btn = create("TextButton", {
        Parent = parent,
        Name = "\0",
        FontFace = Font,
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Element,
        BorderColor3 = FromRGB(0, 0, 0),
        BorderSizePixel = 0,
        LayoutOrder = order,
        Size = UDim2New(0.33, -6, 1, 0),
    })
    corner(btn, 4)

    local lbl = create("TextLabel", {
        Parent = btn,
        Name = "\0",
        FontFace = Font,
        Text = text,
        TextColor3 = Theme["Dark Text"],
        TextSize = 12,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2New(1, 0, 1, 0),
    })

    btn.MouseEnter:Connect(function()
        tween(lbl, nil, { TextColor3 = Theme.Text })
    end)
    btn.MouseLeave:Connect(function()
        tween(lbl, nil, { TextColor3 = Theme["Dark Text"] })
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

create("UIListLayout", {
    Parent = buttonsRow,
    Name = "\0",
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDimNew(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

-- hint
create("TextLabel", {
    Parent = main,
    Name = "\0",
    FontFace = Font,
    Text = "right click a weapon to toggle the skin changer for it",
    TextColor3 = Theme["Dark Text"],
    TextTransparency = 0.3,
    TextSize = 11,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2New(0, 1),
    Position = UDim2New(0, 0, 1, -8),
    Size = UDim2New(1, 0, 0, 14),
})

-- ============================================================
-- state + card rendering
-- ============================================================

local State = {
    Weapons = {},
    Cosmetics = {},
    SelectedWeapon = nil,
    SelectedCosmetic = nil,
    WeaponFilter = "",
    CosmeticFilter = "",
    EnabledWeapons = {},
}

local function destroyCards(section)
    for _, card in section.Cards do
        pcall(function() card:Destroy() end)
    end
    table.clear(section.Cards)
end

local function buildCard(parent, item, layoutOrder, isSelected, onLeft, onRight)
    local card = create("TextButton", {
        Parent = parent,
        Name = "\0",
        FontFace = Font,
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Element,
        BorderColor3 = FromRGB(0, 0, 0),
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        Size = UDim2New(0, 74, 0, 84),
        ZIndex = 2,
    })
    corner(card, 5)

    local cardStroke = stroke(card, isSelected and Theme.Accent or Theme.Outline, isSelected and 1.5 or 1)

    -- icon area
    local iconHolder = create("Frame", {
        Parent = card,
        Name = "\0",
        Position = UDim2New(0.5, 0, 0, 6),
        AnchorPoint = Vector2New(0.5, 0),
        Size = UDim2New(0, 56, 0, 50),
        BackgroundColor3 = Theme.Background,
        BorderColor3 = FromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(iconHolder, 4)

    -- label
    create("TextLabel", {
        Parent = card,
        Name = "\0",
        FontFace = Font,
        Text = item.Name,
        TextColor3 = isSelected and Theme.Text or Theme["Dark Text"],
        TextSize = 10,
        TextWrapped = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2New(0, 2, 1, -26),
        Size = UDim2New(1, -4, 0, 24),
        ZIndex = 3,
    })

    -- resolve icon async
    task.spawn(function()
        local icon = resolveIcon(item.Instance)
        if icon and card.Parent then
            create("ImageLabel", {
                Parent = iconHolder,
                Name = "\0",
                Image = icon,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2New(1, -8, 1, -8),
                AnchorPoint = Vector2New(0.5, 0.5),
                Position = UDim2New(0.5, 0, 0.5, 0),
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 4,
            })
        elseif item.Instance and (item.Instance:IsA("Model") or item.Instance:IsA("BasePart") or item.Instance:IsA("Folder")) and card.Parent then
            -- embed viewport for 3D
            local rendered = renderModelToImage(item.Instance, 56)
            if rendered and rendered.Viewport and card.Parent then
                rendered.Viewport.Name = "\0"
                rendered.Viewport.Size = UDim2New(1, -4, 1, -4)
                rendered.Viewport.AnchorPoint = Vector2New(0.5, 0.5)
                rendered.Viewport.Position = UDim2New(0.5, 0, 0.5, 0)
                rendered.Viewport.ZIndex = 4
                rendered.Viewport.Parent = iconHolder
                pcall(function()
                    if rendered.Gui then rendered.Gui:Destroy() end
                end)
            else
                -- fallback glyph
                create("TextLabel", {
                    Parent = iconHolder,
                    Name = "\0",
                    FontFace = Font,
                    Text = item.Name:sub(1, 1):upper(),
                    TextColor3 = Theme.Accent,
                    TextSize = 20,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Size = UDim2New(1, 0, 1, 0),
                    ZIndex = 4,
                })
            end
        else
            create("TextLabel", {
                Parent = iconHolder,
                Name = "\0",
                FontFace = Font,
                Text = item.Name:sub(1, 1):upper(),
                TextColor3 = Theme.Accent,
                TextSize = 20,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2New(1, 0, 1, 0),
                ZIndex = 4,
            })
        end
    end)

    card.MouseButton1Click:Connect(function()
        onLeft()
    end)
    card.MouseButton2Click:Connect(function()
        onRight()
    end)
    card.MouseEnter:Connect(function()
        if not isSelected then
            tween(cardStroke, nil, { Color = Theme.Accent })
        end
    end)
    card.MouseLeave:Connect(function()
        if not isSelected then
            tween(cardStroke, nil, { Color = Theme.Outline })
        end
    end)

    return card
end

local function refreshWeaponGrid()
    destroyCards(weaponSection)
    local filter = StringLower(State.WeaponFilter)
    local order = 0
    for _, weapon in State.Weapons do
        if filter == "" or StringLower(weapon.Name):find(filter, 1, true) then
            order += 1
            local isSelected = State.SelectedWeapon and State.SelectedWeapon.Name == weapon.Name
            local card = buildCard(
                weaponSection.GridHolder, weapon, order, isSelected,
                function()
                    State.SelectedWeapon = weapon
                    State.SelectedCosmetic = nil
                    skinDropdownLabel.Text = "none"
                    State.Cosmetics = fetchCosmetics(weapon)
                    refreshWeaponGrid()
                    refreshCosmeticGrid()
                end,
                function()
                    -- right click: toggle skin changer for this weapon
                    State.EnabledWeapons[weapon.Name] = not State.EnabledWeapons[weapon.Name]
                    if State.EnabledWeapons[weapon.Name] then
                        -- apply this weapon's skin changer
                        getgenv().skinChanger = true
                        if State.SelectedCosmetic then
                            getgenv().swordModel = State.SelectedCosmetic.Name
                            getgenv().swordAnimations = State.SelectedCosmetic.Name
                            getgenv().swordFX = State.SelectedCosmetic.Name
                        else
                            getgenv().swordModel = weapon.Name
                        end
                        if getgenv().updateSword then getgenv().updateSword() end
                        if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(true) end
                        if Library and Library.Notification then
                            Library:Notification("Skinchanger ON: " .. weapon.Name, "check", 3)
                        end
                    else
                        getgenv().skinChanger = false
                        if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(false) end
                        if Library and Library.Notification then
                            Library:Notification("Skinchanger OFF: " .. weapon.Name, "x", 3)
                        end
                    end
                    refreshWeaponGrid()
                end
            )
            TableInsert(weaponSection.Cards, card)
        end
    end
    weaponSection.GridHolder.Size = UDim2New(1, -16, 0, math.max(168, math.ceil(order / 6) * 92 + 8))
end

function refreshCosmeticGrid()
    destroyCards(cosmeticSection)
    local filter = StringLower(State.CosmeticFilter)
    local order = 0
    for _, cos in State.Cosmetics do
        if filter == "" or StringLower(cos.Name):find(filter, 1, true) then
            order += 1
            local isSelected = State.SelectedCosmetic and State.SelectedCosmetic.Name == cos.Name
            local card = buildCard(
                cosmeticSection.GridHolder, cos, order, isSelected,
                function()
                    State.SelectedCosmetic = cos
                    skinDropdownLabel.Text = cos.Name
                    closeOptions()
                    refreshCosmeticGrid()
                end,
                function()
                    -- right click cosmetic: equip immediately
                    applyCosmetic(cos)
                end
            )
            TableInsert(cosmeticSection.Cards, card)
        end
    end
    cosmeticSection.GridHolder.Size = UDim2New(1, -16, 0, math.max(168, math.ceil(order / 6) * 92 + 8))
end

-- ============================================================
-- apply logic (wires to UnlockSuite backend from source)
-- ============================================================

function applyCosmetic(cos)
    if not cos then return end
    local weapon = State.SelectedWeapon
    local name = cos.Name

    if weapon and weapon.Category == "explosion" then
        getgenv().explosionChanger = true
        getgenv().explosionFX = name
        if getgenv().updateExplosion then getgenv().updateExplosion() end
        if getgenv().setExplosionChanger then getgenv().setExplosionChanger(name) end
    elseif weapon and weapon.Category == "emote" then
        getgenv().selectedEmote = name
        if getgenv().playEmote then getgenv().playEmote(name) end
    else
        -- sword / weapon skin
        getgenv().skinChanger = true
        getgenv().swordModel = name
        getgenv().swordAnimations = name
        getgenv().swordFX = name
        if getgenv().updateSword then getgenv().updateSword() end
        if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(true) end
    end

    if weapon then State.EnabledWeapons[weapon.Name] = true end
    State.SelectedCosmetic = cos
    skinDropdownLabel.Text = name

    if Library and Library.Notification then
        Library:Notification("Applied: " .. name, "check", 3)
    end

    refreshWeaponGrid()
    refreshCosmeticGrid()
end

local function applyToAll()
    if not State.SelectedCosmetic then
        if Library and Library.Notification then
            Library:Notification("Select a skin first", "alert-triangle", 3)
        end
        return
    end
    local cos = State.SelectedCosmetic
    getgenv().skinChanger = true
    getgenv().swordModel = cos.Name
    getgenv().swordAnimations = cos.Name
    getgenv().swordFX = cos.Name
    getgenv().explosionFX = cos.Name
    if getgenv().updateSword then getgenv().updateSword() end
    if getgenv().updateExplosion then getgenv().updateExplosion() end

    for _, w in State.Weapons do
        State.EnabledWeapons[w.Name] = true
    end

    if Library and Library.Notification then
        Library:Notification("Applied to all: " .. cos.Name, "check", 3)
    end
    refreshWeaponGrid()
end

local function resetDefaults()
    State.EnabledWeapons = {}
    State.SelectedCosmetic = nil
    skinDropdownLabel.Text = "none"
    getgenv().skinChanger = false
    getgenv().explosionChanger = false
    getgenv().swordModel = ""
    getgenv().swordAnimations = ""
    getgenv().swordFX = ""
    getgenv().explosionFX = ""
    if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(false) end
    if getgenv().setExplosionChangerToggleUI then getgenv().setExplosionChangerToggleUI(false) end
    if Library and Library.Notification then
        Library:Notification("Reset to defaults", "rotate-ccw", 3)
    end
    refreshWeaponGrid()
    refreshCosmeticGrid()
end

-- ============================================================
-- dropdown options
-- ============================================================

local optionsOpen = false

function closeOptions()
    if not optionsOpen then return end
    optionsOpen = false
    local t = tween(optionsHolder, TweenInfo.new(0.15), { Size = UDim2New(0, optionsHolder.AbsoluteSize.X, 0, 0) })
    t.Completed:Connect(function()
        optionsHolder.Visible = false
    end)
end

local function openOptions()
    if optionsOpen then
        closeOptions()
        return
    end
    optionsOpen = true

    -- rebuild options
    for _, child in optionsList:GetChildren() do
        if child:IsA("TextButton") then child:Destroy() end
    end

    for i, cos in State.Cosmetics do
        local opt = create("TextButton", {
            Parent = optionsList,
            Name = "\0",
            FontFace = Font,
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = Theme.Element,
            BorderColor3 = FromRGB(0, 0, 0),
            BorderSizePixel = 0,
            LayoutOrder = i,
            Size = UDim2New(1, 0, 0, 22),
            ZIndex = 502,
        })
        corner(opt, 4)
        create("TextLabel", {
            Parent = opt,
            Name = "\0",
            FontFace = Font,
            Text = cos.Name,
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2New(0, 8, 0, 0),
            Size = UDim2New(1, -16, 1, 0),
            ZIndex = 503,
        })
        opt.MouseButton1Click:Connect(function()
            State.SelectedCosmetic = cos
            skinDropdownLabel.Text = cos.Name
            closeOptions()
            refreshCosmeticGrid()
        end)
    end

    optionsHolder.Visible = true
    optionsHolder.Position = UDim2New(0, skinDropdownBtn.AbsolutePosition.X, 0, skinDropdownBtn.AbsolutePosition.Y + skinDropdownBtn.AbsoluteSize.Y + 4)
    optionsHolder.Size = UDim2New(0, skinDropdownBtn.AbsoluteSize.X, 0, 0)
    optionsHolder.ZIndex = 500
    local maxH = math.min(#State.Cosmetics * 26 + 8, 180)
    tween(optionsHolder, TweenInfo.new(0.15), { Size = UDim2New(0, skinDropdownBtn.AbsoluteSize.X, 0, maxH) })
end

skinDropdownBtn.MouseButton1Click:Connect(openOptions)

UserInputService.InputBegan:Connect(function(input)
    if optionsOpen and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local pos = input.Position
        local inDropdown = pos.X >= optionsHolder.AbsolutePosition.X
            and pos.X <= optionsHolder.AbsolutePosition.X + optionsHolder.AbsoluteSize.X
            and pos.Y >= optionsHolder.AbsolutePosition.Y
            and pos.Y <= optionsHolder.AbsolutePosition.Y + optionsHolder.AbsoluteSize.Y
        local inBtn = pos.X >= skinDropdownBtn.AbsolutePosition.X
            and pos.X <= skinDropdownBtn.AbsolutePosition.X + skinDropdownBtn.AbsoluteSize.X
            and pos.Y >= skinDropdownBtn.AbsolutePosition.Y
            and pos.Y <= skinDropdownBtn.AbsolutePosition.Y + skinDropdownBtn.AbsoluteSize.Y
        if not inDropdown and not inBtn then
            closeOptions()
        end
    end
end)

-- ============================================================
-- filter inputs
-- ============================================================

weaponSection.FilterInput:GetPropertyChangedSignal("Text"):Connect(function()
    State.WeaponFilter = weaponSection.FilterInput.Text
    refreshWeaponGrid()
end)

cosmeticSection.FilterInput:GetPropertyChangedSignal("Text"):Connect(function()
    State.CosmeticFilter = cosmeticSection.FilterInput.Text
    refreshCosmeticGrid()
end)

-- ============================================================
-- buttons
-- ============================================================

makeButton(buttonsRow, "apply selected to all", 1, applyToAll)
makeButton(buttonsRow, "reset to defaults", 2, resetDefaults)
makeButton(buttonsRow, "close", 3, function()
    CosmeticChanger:Destroy()
end)

-- ============================================================
-- drag
-- ============================================================

do
    local dragging, dragStart, startPos
    local titleHit = create("TextButton", {
        Parent = main,
        Name = "\0",
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2New(0, 0, 0, 0),
        Size = UDim2New(1, 0, 0, 28),
        ZIndex = 10,
    })
    -- send clicks through except drag
    titleHit.Active = true

    titleHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local pos = UDim2New(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            main.Position = pos
        end
    end)
end

-- ============================================================
-- API
-- ============================================================

function CosmeticChanger:Destroy()
    holder:Destroy()
    getgenv().CosmeticChanger = nil
end

function CosmeticChanger:SetOpen(visible)
    holder.Enabled = visible
end

function CosmeticChanger:Refresh()
    State.Weapons = fetchWeapons()
    if State.SelectedWeapon then
        State.Cosmetics = fetchCosmetics(State.SelectedWeapon)
    else
        State.Cosmetics = {}
    end
    refreshWeaponGrid()
    refreshCosmeticGrid()
end

getgenv().CosmeticChanger = CosmeticChanger

-- initial load
task.spawn(function()
    State.Weapons = fetchWeapons()
    refreshWeaponGrid()
    refreshCosmeticGrid()

    -- auto-select first weapon so cosmetics populate
    if #State.Weapons > 0 and not State.SelectedWeapon then
        State.SelectedWeapon = State.Weapons[1]
        State.Cosmetics = fetchCosmetics(State.SelectedWeapon)
        refreshWeaponGrid()
        refreshCosmeticGrid()
    end
end)

-- periodic refresh to pick up newly loaded assets
task.spawn(function()
    while task.wait(8) and getgenv().CosmeticChanger do
        local weapons = fetchWeapons()
        if #weapons ~= #State.Weapons then
            State.Weapons = weapons
            refreshWeaponGrid()
            if State.SelectedWeapon then
                State.Cosmetics = fetchCosmetics(State.SelectedWeapon)
                refreshCosmeticGrid()
            end
        end
    end
end)

return CosmeticChanger
