local tabletEntity = nil -- DO NOT CHANGE
local tabletModel = "pp_doj_tablet"
local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
local tabletAnim = "base"
local availableGrades = {}

CreateThread(function()
    while not Bridge do Wait(300) end

    local jobs = Bridge.getJobs()
    while not jobs do
        Wait(1000)
        jobs = Bridge.getJobs()
    end
    for _, jobData in pairs(jobs) do
        if jobData.name == 'doj' then
            for _, grade in pairs(jobData.grades) do
                print(json.encode(grade))
                availableGrades[grade.grade] = grade.name
            end
        end
    end
end)

return {
    locale = 'en', -- EN | PL
    keybind = true,

    startTabletAnimation = function()
        lib.requestAnimDict(tabletDict)
        if tabletEntity then
            stopTabletAnimation()
        end
        lib.requestModel(tabletModel)
        tabletEntity = CreateObject(GetHashKey(tabletModel), 1.0, 1.0, 1.0, true, true, false)
        AttachEntityToEntity(tabletEntity, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.10, -0.13, 25.0, 170.0, 160.0, true, true, false, true, 1, true)
        TaskPlayAnim(cache.ped, tabletDict, tabletAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
    end,

    stopTabletAnimation = function()
        if tabletEntity then
            StopAnimTask(cache.ped, tabletDict, tabletAnim ,8.0, -8.0, -1, 50, 0, false, false, false)
            DeleteEntity(tabletEntity)
            tabletEntity = nil
        end
    end,

    printer = {
        minDistance = 10.0, -- The maximum distance from which a player can interact with a printer

        --- Sets up a printer interaction zone for targeting systems (ox_target or qb-target)
        --- @param printer table A table containing printer details such as ID, coordinates, size, rotation, and debug settings
        --- @param openMenu function The function to execute when the printer is interacted with (opens printer menu)
        setupPrinter = function(printer, openMenu)
            local targetOptions = {
                {
                    label = 'Open printer menu',
                    icon = 'fas fa-print',
                    action = function()
                        openMenu(printer)
                    end,
                    onSelect = function()
                        openMenu(printer)
                    end,
                    distance = 2.0,
                }
            }
            if GetResourceState('ox_target') ~= 'missing' then
                exports.ox_target:addBoxZone({
                    name = 'printer_' .. printer.id,
                    coords = printer.coords,
                    size = printer.size,
                    rotation = printer.rotation,
                    debug = false,
                    options = targetOptions
                })
            elseif GetResourceState('qb-target') ~= 'missing' then
                exports['qb-target']:AddBoxZone(
                    'printer_' .. printer.id,
                    printer.coords,
                    printer.size.x or 1.0,
                    printer.size.y or 1.0,
                    {
                        name = 'printer_' .. printer.id,
                        heading = printer.rotation or 0,
                        debugPoly = printer.debug or false,
                        minZ = printer.coords.z - 1.0,
                        maxZ = printer.coords.z + 1.5
                    },
                    {
                        options = targetOptions,
                        distance = 2.0
                    }
                )
            else
                print('^1[ERROR] ^0No compatible interaction system found. Printing functionality will not work properly!! Check ^5@pp-doj-mdt/config/config_c.lua^0')
            end
        end,
        --- @param printer table The printer being used
        --- @param onFinish function The function to call when printing is completed
        printDocument = function(printer, onFinish)
            if GetResourceState('xsound') == 'started' then
                local soundname = 'printer_' .. printer.id
                exports.xsound:PlayUrlPos(soundname, 'https://www.youtube.com/watch?v=ZQTvcZH76Fk', 0.2, printer.coords)

                SetTimeout(12000, onFinish)
            else
                print('^1[ERROR] ^0xsound not found. Print sound will not play!! Check ^5@pp-doj-mdt/config/config_c.lua^0')
                onFinish()
            end
        end,
        printers = {
            -- Example printer configuration
            -- {
            --     label = 'Test Printer', -- Name displayed in UI
            --     id = 'test_printer', -- Unique printer ID
            --     coords = vec3(12.3, 45.6, 78.9), -- Position in the game world
            --     size = vec3(0.5, 0.5, 1), -- Interaction zone size
            --     rotation = 0.0, -- Rotation of the printer object
            --     debug = false, -- Enables debug mode (shows interaction area)
            --     drawSprite = false -- Enables sprite visualization for interaction
            -- }
        }
    },

    management = {
        availableGrades = availableGrades
    }
}