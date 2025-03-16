local Framework = nil
if GetResourceState('es_extended') ~= 'missing' then
    Framework = 'ESX'
    ESX = exports.es_extended:getSharedObject()
elseif GetResourceState('qb-core') ~= 'missing' then
    Framework = 'QBCore'
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('qbx_core') ~= 'missing' then
    Framework = 'QBOX'
    qbox = exports.qbx_core
elseif GetResourceState('your_custom_framework') ~= 'missing' then -- fill it when you are using other framework
    Framework = 'your_custom_framework'
end

local jobsWithAccess = { -- names of jobs that will have access to use MDT
    'doj'
}

return {
    debug = false, --[[
        Set this to 'true' only when you need to troubleshoot issues within the resource.
        Enabling debug mode activates extra logging to help identify and resolve problems.
        This setting should always remain 'false' in production environments to avoid performance impacts.

        When debug mode is enabled, the following commands are also available for testing:
        - /dojdutystart - for entering duty
        - /dojdutystop  - for leaving duty
    ]]
    locales = 'en', -- EN | PL

    jobsWithAccess = jobsWithAccess,

    homePage = {
        profile = {
            --- Retrieves the total duty time for a player
            --- @param Player table The player object
            --- @return number The total duty time in seconds
            getTotalDuty = function(Player)
                if Framework == 'ESX' then
                    return Player.getMeta('doj_duty_time') or 0
                elseif Framework == 'QBOX' or Framework == 'QBCore' then
                    return Player.PlayerData.metadata.doj_duty_time or 0
                end

                return 0
            end,

            --- Updates the total duty time for a player
            --- @param Player table The player object
            --- @param time number The additional time to add to the total duty time
            updateTotalDuty = function(Player, time)
                if Framework == 'ESX' then
                    local currentTime = player.getMeta('doj_duty_time') or 0
                    return player.setMeta('doj_duty_time', currentTime + time) or 0
                elseif Framework == 'QBOX' or Framework == 'QBCore' then
                    local currentTime = Player.PlayerData.metadata.doj_duty_time or 0
                    Player.Functions.SetMetaData('doj_duty_time', currentTime + time)
                end
            end,
            -- Default status for players when they start duty
            defaultStatus = 'Available',

            -- List of available statuses and their corresponding CSS colors
            availableStatuses = {
                ['Available'] = 'green',
                ['In Court'] = 'blue',
                ['In a Meeting'] = 'yellow',
                ['Reviewing Case'] = 'red',
                ['Preparing Documents'] = 'orange',
                ['On Break'] = 'brown',
                ['Researching'] = 'purple',
                ['En Route'] = 'pink'
            },
        },

        --- Retrieves clerk-related data for a player
        --- @param player table The player object
        --- @return table The clerk data containing badge
        getClerkData = function(player)
            local badge = nil
            if Framework == 'ESX' then
                badge = player.getMeta('badge') or 0
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                badge = player.PlayerData.metadata.callsign
            end

            return {
                badge = badge
            }
        end,

        --- Retrieves a player's profile picture
        --- @param identifier string The unique player identifier
        --- @return string|nil The image URL or nil if not found
        getPhoto = function(identifier)
            local image = nil
            if Framework == 'ESX' then
                local player = ESX.GetPlayerFromIdentifier(identifier)
                if player then
                    image = player.getMeta('mdt_image')
                else
                    local response = MySQL.query.await("SELECT JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image')) AS mdt_image, FROM `users` WHERE `identifier` = ?", {
                        identifier
                    })
                    if response and response[1] then
                        image = response[1].mdt_image
                    end
                end
            elseif Framework == 'QBOX' then
                local player = qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier)
                if player then
                    image = player.PlayerData.metadata.mdt_image
                end
            elseif Framework == 'QBCore' then
                local player = QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)
                if player then
                    image = player.PlayerData.metadata.mdt_image
                end
            end

            return image
        end
    },

    management = {
        employees = {
            ---@param job string The name of the job whose employees should be retrieved
            ---@return table A table of employees with details such as name, grade, and duty time
            getEmployees = function(job)
                local employees = {}

                if Framework == 'ESX' then
                    local jobs = Bridge.getJobs()
                    local gradeLabels = {}
                    for _, jobData in pairs(jobs) do
                        if jobData.name == job then
                            for _, grade in pairs(jobData.grades) do
                                gradeLabels[grade.grade] = grade.label
                            end
                        end
                    end

                    local dbdata = MySQL.query.await([[
                        SELECT
                            identifier,
                            grade,
                            JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.doj_duty_time')) AS total_duty,
                            firstname,
                            lastname
                        FROM
                            users
                        WHERE
                            job = ?
                    ]], {job})

                    for _, entry in ipairs(dbdata) do
                        employees[entry.identifier] = {
                            identifier = entry.identifier,
                            ssn = entry.identifier,  -- Delete if you dont want to display SSN/CitizenID
                            grade = {
                                value = entry.grade,
                                label = gradeLabels[entry.grade] or "Unknown"
                            },
                            name = entry.firstname .. ' ' .. entry.lastname,
                            created_at = entry.created_at,
                            updated_at = entry.updated_at,
                            total_duty = tonumber(entry.total_duty) or 0
                        }
                    end
                elseif Framework == 'QBCore' or Framework == 'QBOX' then
                    local dbdata = MySQL.query.await([[
                        SELECT
                            citizenid AS identifier,
                            JSON_UNQUOTE(JSON_EXTRACT(job, '$.grade.level')) AS grade,
                            JSON_UNQUOTE(JSON_EXTRACT(job, '$.grade.name')) AS gradeName,
                            JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.doj_duty_time')) AS total_duty,
                            JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                            JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
                        FROM
                            players
                        WHERE
                            JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?
                    ]], {job})

                    for _, entry in ipairs(dbdata) do
                        employees[entry.identifier] = {
                            identifier = entry.identifier,
                            ssn = entry.identifier,  -- Delete if you dont want to display SSN/CitizenID
                            grade = {
                                value = entry.grade,
                                label = entry.gradeName or "Unknown"
                            },
                            name = entry.firstname .. ' ' .. entry.lastname,
                            created_at = entry.created_at,
                            updated_at = entry.updated_at,
                            total_duty = tonumber(entry.total_duty) or 0
                        }
                    end
                end

                return employees
            end,

            ---@param identifier string The identifier of the employee to be fired
            ---@param Player table The player initiating the action
            ---@param reason string|nil The reason for firing the employee
            ---@return boolean, string|nil Success status and an optional error message
            fireEmployee = function(identifier, Player, reason)
                local playerJob = Bridge.getJob(Player)
                if GetResourceState('pp-bossmenu') ~= 'missing' then
                    local targetEmployee = MySQL.single.await('SELECT grade FROM `player_jobs` WHERE `identifier` = ? AND `job` = ? LIMIT 1', { identifier, jobsWithAccess[1] })
                    if not targetEmployee or playerJob.grade <= targetEmployee.grade then
                        return false, "You don't have permission to fire this employee!"
                    end

                    local deleteData = MySQL.query.await('DELETE FROM `player_jobs` WHERE `identifier` = ? AND `job` = ?', { identifier, jobsWithAccess[1] })
                    if deleteData and deleteData.affectedRows > 0 then
                        return true
                    else
                        return false
                    end
                elseif Framework == 'ESX' then
                    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
                    if not xPlayer then
                        local jobData = MySQL.single.await('SELECT job, grade FROM users WHERE identifier = ?', { identifier })
                        if not jobData or jobData.job ~= jobsWithAccess[1] or playerJob.grade <= jobData.grade then
                            return false, "You don't have permission to fire this employee!"
                        end
                        return MySQL.update.await('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', { 'unemployed', 0, identifier }) > 0
                    end
                    local targetJob = xPlayer.getJob()
                    if targetJob.name ~= jobsWithAccess[1] then
                        return false, "Employee does not belong to this job!"
                    end
                    if targetJob.grade >= playerJob.grade then
                        return false, "You don't have permission to fire this employee!"
                    end
                    xPlayer.setJob('unemployed', 0)
                    return true
                elseif Framework == 'QBCore' then
                    local PlayerData = Framework == 'QBCore' and (QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)) or Framework == 'QBOX' and (qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier))
                    if not PlayerData then return false end
                    if PlayerData.PlayerData.job.name ~= jobsWithAccess[1] then
                        return false, "Employee does not belong to this job!"
                    end
                    if playerJob.grade <= PlayerData.PlayerData.job.grade.level then
                        return false, "You don't have permission to fire this employee!"
                    end
                    PlayerData.Functions.SetJob('unemployed', 0)
                    return true
                end

                return false
            end,

            ---@param identifier string The identifier of the employee whose grade is being changed
            ---@param newGrade number The new grade level to assign
            ---@param sourceGrade number The grade level of the person initiating the action
            ---@param source number The player initiating the grade change
            ---@param reason string|nil The reason for changing the grade
            ---@return boolean, string|nil Success status and an optional error message
            changeGrade = function(identifier, newGrade, sourceGrade, source, reason)
                if GetResourceState('pp-bossmenu') ~= 'missing' then
                    local targetEmployee = MySQL.single.await('SELECT grade FROM `player_jobs` WHERE `identifier` = ? AND `job` = ? LIMIT 1', { identifier, jobsWithAccess[1] })
                    if not targetEmployee or sourceGrade <= targetEmployee.grade then
                        return false, "You don't have permission to change the rank of this employee!"
                    end
                    local affectedRows = MySQL.update.await('UPDATE `player_jobs` SET `grade` = ? WHERE `identifier` = ? AND `job` = ?', {
                        newGrade, identifier, jobsWithAccess[1]
                    })

                    return affectedRows > 0
                elseif Framework == 'ESX' then
                    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
                    if not xPlayer then
                        local jobData = MySQL.single.await('SELECT job, grade FROM users WHERE identifier = ?', { identifier })
                        if not jobData or jobData.job ~= jobsWithAccess[1] or playerJob.grade <= jobData.grade then
                            return false, "You don't have permission to fire this employee!"
                        end
                        return MySQL.update.await('UPDATE users SET job_grade = ? WHERE identifier = ?', { newGrade, identifier }) > 0
                    end
                    local targetJob = xPlayer.getJob()
                    if targetJob.name ~= jobsWithAccess[1] then
                        return false, "Employee does not belong to this job!"
                    end
                    if targetJob.grade >= playerJob.grade then
                        return false, "You don't have permission to manage this employee!"
                    end
                    xPlayer.setJob(jobsWithAccess[1], newGrade)
                    return true
                elseif Framework == 'QBCore' or Framework == 'QBOX' then
                    local PlayerData = Framework == 'QBCore' and (QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)) or Framework == 'QBOX' and (qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier))
                    if not PlayerData then return false end
                    if PlayerData.PlayerData.job.name ~= jobsWithAccess[1] then
                        return false, "Employee does not belong to this job!"
                    end
                    if sourceGrade <= PlayerData.PlayerData.job.grade.level then
                        return false, "You don't have permission to change the rank of this employee!"
                    end
                    PlayerData.Functions.SetJob(PlayerData.PlayerData.job.name, newGrade)
                    return true
                end

                return false
            end,

            ---@param Target table The player being hired
            ---@param Player table The player initiating the hiring process
            ---@return boolean, string|nil Success status and an optional error message
            hireEmployee = function(Target, Player)
                if #(Bridge.getCoords(Target) - Bridge.getCoords(Player)) > 10.0 then
                    return false, t('management.employees.hire.errors.too_far')
                end

                local lowestGrade = math.huge
                for _, job in pairs(Bridge.getJobs()) do
                    if job.name == jobsWithAccess[1] then
                        for _, grade in pairs(job.grades) do
                            if grade.grade < lowestGrade then
                                lowestGrade = grade.grade
                            end
                        end
                        break
                    end
                end

                if GetResourceState('pp-bossmenu') ~= 'missing' then
                    local hired = MySQL.single.await('SELECT 1 FROM `player_jobs` WHERE `identifier` = ? AND `job` = ?', { Target.identifier, jobsWithAccess[1] })
                    if hired then return false, t('management.employees.hire.errors.already_hired') end

                    local id = MySQL.insert.await('INSERT INTO `player_jobs` (identifier, job, grade) VALUES (?, ?, ?)', { Target.identifier, jobsWithAccess[1], lowestGrade })
                    if id > 0 then
                        Bridge.setJob(Target, jobsWithAccess[1], lowestGrade)
                        return true
                    end
                    return false
                else
                    if Bridge.getJob(Target).name == jobsWithAccess[1] then return false, t('management.employees.hire.errors.already_hired') end
                    Bridge.setJob(Target, jobsWithAccess[1], lowestGrade)
                    return true
                end
            end,
        },
        society = {
            ---@return number The society's current balance
            getBalance = function()
                local p = promise.new()
                if GetResourceState('Renewed-Banking') == 'started' then
                    return exports['Renewed-Banking']:getAccountMoney(jobsWithAccess[1])
                elseif GetResourceState('esx_society') == 'started' then
                    TriggerEvent('esx_addonaccount:getSharedAccount', jobsWithAccess[1], function(account)
                        p:resolve(account.money or 0)
                    end)

                    return Citizen.Await(p)
                elseif GetResourceState('qb-banking') == 'started' then
                    return exports['qb-banking']:GetAccountBalance(jobsWithAccess[1])
                else
                    print("^1[ERROR] ^0No supported society resource found!")
                    return 0
                end
            end,

            ---@param Player table The player initiating the transaction
            ---@param amount number The amount of money to be added to the society account
            ---@param message string A message describing the transaction
            ---@return boolean, string|nil Success status and an optional error message
            addMoney = function(Player, amount, message)
                local source = Bridge.getSource(Player)
                local money = Bridge.getItemCount(source, 'money')
                if money < amount then
                    return false, "You don't have enough money!"
                end

                if GetResourceState('Renewed-Banking') == 'started' then
                    exports['Renewed-Banking']:addAccountMoney(jobsWithAccess[1], amount)
                elseif GetResourceState('esx_society') == 'started' then
                    TriggerEvent('esx_addonaccount:getSharedAccount', jobsWithAccess[1], function(account)
                        account.addMoney(amount)
                    end)
                elseif GetResourceState('qb-banking') == 'started' then
                    exports['qb-banking']:AddMoney(jobsWithAccess[1], amount, message)
                else
                    print("^1[ERROR] ^0No supported society resource found!")
                    return false
                end

                Bridge.removeItem(source, 'money', amount)
                return true
            end,

            ---@param Player table The player initiating the withdrawal
            ---@param amount number The amount of money to remove from the society account
            ---@param message string A message describing the transaction
            ---@return boolean, string|nil Success status and an optional error message
            removeMoney = function(Player, amount, message)
                if GetResourceState('Renewed-Banking') == 'started' then
                    exports['Renewed-Banking']:removeAccountMoney(jobsWithAccess[1], amount)
                elseif GetResourceState('esx_society') == 'started' then
                    TriggerEvent('esx_addonaccount:getSharedAccount', jobsWithAccess[1], function(account)
                        account.removeMoney(amount)
                    end)
                elseif GetResourceState('qb-banking') == 'started' then
                    exports['qb-banking']:RemoveMoney(jobsWithAccess[1], amount, message)
                else
                    print("^1[ERROR] ^0No supported society resource found!")
                    return false
                end

                Bridge.addItem(Bridge.getSource(Player), 'money', amount)
                return true
            end,
        }
    },

    finances = {
        ---@return string|nil Name of the file in server/editable/banking to use banking functions
        getBankingResource = function()
            if GetResourceState('pefcl') ~= 'missing' then
                return 'pefcl'
            elseif GetResourceState('Renewed-Banking') ~= 'missing' then
                return 'renewed-' .. Framework == 'ESX' and 'esx' or 'qb'
            elseif GetResourceState('ps-banking') ~= 'missing' then
                return 'ps-banking'
            end
        end
    },

    citizen = {
        ---@param identifier string The identifier of the citizen
        ---@return table A table containing citizen details such as name, DOB, nationality, licenses, and records
        getCitizenDetails = function(identifier)
            local data, licenses, accounts, records = {}, {}, {}, {}

            if Framework == 'ESX' then
                local player = ESX.GetPlayerFromIdentifier(identifier)
                if player then
                    data.firstname = player.get('firstName')
                    data.lastname = player.get('lastName')
                    data.birthdate = player.get('dob')
                    data.nationality = player.get('nationality')
                    data.mdt_image = player.getMeta('mdt_image')
                    data.badge = player.getMeta('badge')
                    data.gender = player.getMeta('sex') == 1 and 'Female' or 'Male'
                else
                    local response = MySQL.query.await("SELECT `firstname`, `lastname`, `dateofbirth` AS `dob`, `nationality`, JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image')) AS mdt_image, JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.badge')) AS badge, `sex` AS gender FROM `users` WHERE `identifier` = ?", {
                        identifier
                    })
                    if response and response[1] then
                        data = response[1]
                    end
                end
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                local player = Framework == 'QBCore' and (QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)) or Framework == 'QBOX' and (qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier))
                if player then
                    local playerData = player.PlayerData
                    data.firstname = playerData.charinfo.firstname
                    data.lastname = playerData.charinfo.lastname
                    data.birthdate = playerData.charinfo.birthdate
                    data.nationality = playerData.charinfo.nationality
                    data.mdt_image = playerData.metadata.mdt_image
                    data.badge = playerData.metadata.callsign
                    data.gender = playerData.charinfo.gender == 1 and 'Female' or 'Male'
                end
            end

            if not data.firstname then return {} end

            if Framework == 'ESX' then
                local userLicenses = MySQL.query.await("SELECT `type` FROM `user_licenses` WHERE `owner` = ?", { identifier })
                if userLicenses then
                    for _, userLicense in pairs(userLicenses) do
                        local licenseType = userLicense.type
                        local licenseLabel = MySQL.query.await("SELECT `label`, `name` FROM `licenses` WHERE `type` = ?", { licenseType })
                        if licenseLabel and licenseLabel[1] then
                            table.insert(licenses, {
                                name = licenseLabel[1].name,
                                label = licenseLabel[1].label,
                                owns = true
                            })
                        end
                    end
                end
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                local player = Framework == 'QBCore' and (QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)) or Framework == 'QBOX' and (qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier))

                if player then
                    if player.PlayerData.metadata.licences then
                        for name, value in pairs(player.PlayerData.metadata.licences) do
                            table.insert(licenses, {
                                name = name,
                                label = name,
                                owns = value
                            })
                        end
                    end

                end
            end

            if GetResourceState('pefcl') ~= 'missing' then
                local license
                if Framework == 'ESX' then
                    license = identifier

                    if not license:match("^license:") then
                        license = license:gsub("^char%d+:", "license:")
                    end
                else
                    local licenseRecord = MySQL.single.await('SELECT `license` FROM `players` WHERE `citizenid` = ?', {
                        identifier
                    })
                    license = licenseRecord and licenseRecord.license

                    if not license:match("^license:") then
                        if license:match("^license2:") then
                            license = license:gsub("^license2:", "license:")
                        else
                            license = "license:" .. license
                        end
                    end
                end

                if license then
                    accounts = MySQL.query.await('SELECT `number`, `accountName` AS `name`, `balance` FROM `pefcl_accounts` WHERE `ownerIdentifier` = ? OR `ownerIdentifier` = ?', {
                        license, identifier
                    })
                end
            elseif GetResourceState('Renewed-Banking') ~= 'missing' then
                accounts = MySQL.query.await('SELECT `number`, `accountName` AS `name`, `balance` FROM `pefcl_accounts` WHERE `ownerIdentifier` = ? OR `ownerIdentifier` = ?', {
                    license, identifier
                })
            elseif GetResourceState('ps-banking') ~= 'missing' then
                accounts = MySQL.query.await('SELECT `id` AS `number`, `amount` AS `balance` FROM `bank_accounts_new` WHERE `creator` = ?', {
                    identifier
                })

                for _, account in pairs(accounts) do
                    account.name = data.firstname .. ' ' .. data.lastname
                end
            end

            local wanted = false
            if GetResourceState('pp-mdt') ~= 'missing' then
                records = MySQL.query.await('SELECT `title`, `type`, `created_at` as `date` FROM `mdt_cases` WHERE JSON_CONTAINS(citizens, @identifier)', {
                    ['@identifier'] = '"' .. identifier .. '"'
                })
                wanted = exports['pp-mdt']:isWanted('citizen', identifier)
            end

            return {
                name = data.firstname .. ' ' .. data.lastname,
                dob = data.birthdate,
                img = data.mdt_image,
                ssn = identifier,
                nationality = data.nationality,
                licenses = licenses,
                badge = data.badge,
                gender = data.gender,
                accounts = accounts,
                wanted = wanted,
                records = records
            }
        end,

        ---@param identifier string The identifier of the citizen
        ---@param license string The name of the license to add or remove
        ---@return boolean, string|nil Success status and an optional error message if an operation fails
        changeLicense = function(identifier, license)
            if Framework == 'ESX' then
                local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
                if not xPlayer then
                    return false, "Player not found"
                end

                local result = MySQL.query.await("SELECT type FROM user_licenses WHERE owner = ?", { identifier })

                if result and #result > 0 then
                    local rowsChanged = MySQL.query.await("DELETE FROM user_licenses WHERE owner = ? AND type = ?", { identifier, license })
                    if rowsChanged and rowsChanged.affectedRows > 0 then
                        return true
                    else
                        return false, "Failed to remove license"
                    end
                else
                    local id = MySQL.insert.await("INSERT INTO user_licenses (owner, type) VALUES (?, ?)", { identifier, license })
                    if id and id > 0 then
                        return true
                    else
                        return false, "Failed to add license"
                    end
                end
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                local player = Framework == 'QBCore' and
                    (QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)) or
                    (exports.qbx_core:GetPlayerByCitizenId(identifier) or exports.qbx_core:GetOfflinePlayer(identifier))

                if not player then
                    return false, "Player not found"
                end

                local currentLicenses = player.PlayerData.metadata.licences
                currentLicenses[license] = not currentLicenses[license]
                player.Functions.SetMetaData('licences', currentLicenses)

                return true
            end

            return false
        end
    },

    vehicle = {
        ---@param plate string The license plate of the vehicle
        ---@return table A table containing vehicle details such as owner information, history, and wanted status
        getVehicleDetails = function(plate)
            local dbdata = {}

            if Framework == 'ESX' then
                dbdata = MySQL.query.await([[
                    SELECT
                        uv.owner AS identifier,
                        JSON_UNQUOTE(JSON_EXTRACT(uv.vehicle, '$.model')) AS hash,
                        uv.mdt_image AS img,
                        uv.owners_history AS owners_history,
                        p.firstname AS firstname,
                        p.lastname AS lastname
                    FROM
                        `owned_vehicles` uv
                    LEFT JOIN
                        `users` p ON uv.owner = p.identifier
                    WHERE
                        uv.plate = ?
                ]], { plate })

            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                dbdata = MySQL.query.await([[
                    SELECT
                        pv.citizenid AS identifier,
                        pv.hash,
                        pv.owners_history AS owners_history,
                        pv.mdt_image AS img,
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname
                    FROM
                        `player_vehicles` pv
                    LEFT JOIN
                        `players` p ON pv.citizenid = p.citizenid
                    WHERE
                        pv.plate = ?
                ]], { plate })
            end

            if dbdata and #dbdata > 0 then
                local vehicleData = dbdata[1]
                vehicleData.name = vehicleData.firstname .. " " .. vehicleData.lastname

                if GetResourceState('pp-mdt') == 'started' then
                    vehicleData.wanted = exports['pp-mdt']:isWanted('vehicle', vehicleData.plate)
                    local cases = MySQL.query.await('SELECT type, title, description, id, created_at FROM mdt_cases WHERE JSON_CONTAINS(vehicles, ?)', {json.encode({plate})})
                    for _, case in pairs(cases or {}) do
                        case.wanted = case.type == "warrant"
                    end
                    vehicleData.cases = cases

                    local notes = MySQL.query.await('SELECT title, description, id, created_at FROM mdt_notes WHERE JSON_CONTAINS(vehicles, ?)', {json.encode({plate})})
                    vehicleData.notes = notes
                end

                return vehicleData
            else
                return {}
            end
        end,

        ---@param plate string The license plate of the vehicle
        ---@return table A table containing the minimum and maximum possible sell price for the vehicle
        getVehicleSellPrice = function(plate)
            local originalPrice = nil
            if Framework == 'ESX' then
                originalPrice = MySQL.query.await('SELECT `price` FROM `vehicles` WHERE `model` = ?', {
                    plate
                })[1]
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                local hash = MySQL.query.await('SELECT `hash` FROM `player_vehicles` WHERE `plate` = ?', {
                    plate
                })[1]?.hash

                local vehicles = exports.qbx_core:GetVehiclesByHash()
                originalPrice = vehicles[tonumber(hash)]?.price or nil
            end

            return originalPrice and {
                min_price = math.floor(originalPrice * 0.3), -- 30% as minimum price
                max_price = math.floor(originalPrice * 1.3) -- 130% as maximum price
            } or {
                min_price = 0,
                max_price = 1000000
            }
        end,

        ---@param currentOwner table The current owner of the vehicle
        ---@param newOwner table The new owner of the vehicle
        ---@param price number The selling price of the vehicle
        ---@param plate string The license plate of the vehicle
        ---@param newOwnersHistory string The updated owner history to update in database
        ---@return boolean Success status of the ownership transfer
        changeOwner = function(currentOwner, newOwner, price, plate, newOwnersHistory)
            if Framework == 'ESX' then
                if newOwner.getAccount('bank').money < price then
                    return false
                end

                newOwner.removeAccountMoney('bank', price)
                currentOwner.addAccountMoney('bank', price)

                local updateResult = MySQL.update.await("UPDATE `owned_vehicles` SET `owner` = @newOwner, `owners_history` = @newHistory WHERE `plate` = @plate", {
                    ['@newOwner'] = newOwner.PlayerData.license,
                    ['@newHistory'] = newOwnersHistory,
                    ["@plate"] = plate
                })

                return updateResult > 0
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                if newOwner.PlayerData.money.bank < price then
                    return false
                end

                newOwner.Functions.RemoveMoney('bank', price)
                currentOwner.Functions.AddMoney('bank', price)

                local updateResult = MySQL.update.await("UPDATE `player_vehicles` SET `license` = @license, `citizenid` = @citizenid, `owners_history` = @newHistory WHERE `plate` = @plate", {
                    ['@license'] = newOwner,
                    ["@citizenid"] = newOwner,
                    ['@newHistory'] = newOwnersHistory,
                    ["@plate"] = plate
                })

                return updateResult > 0
            end

            return true
        end,

        ---@param plate string The license plate of the vehicle
        ---@return boolean Whether the vehicle is wanted or not
        getWanted = function(plate)
            if GetResourceState('pp-mdt') == 'started' then
                return exports['pp-mdt']:isWanted('vehicle', plate)
            end

            return false
        end
    },

    forms = {
        ---@param source number Source of Player to receive document
        ---@param document table Document data table
        addForm = function(source, document)
            Bridge.addItem(source, 'doj_form', 1, {
                description = ('%s - page %d'):format(document.title, document.page),
                file_name = document.file_name,
                data = document.formData,
                page = document.page,
                id = document.id
            })
        end
    },

    permissions = {
        [0] = {
            announcements = {'view'},
            citizens = {'view'},
            citizen = {'view'},
            vehicles = {'view'},
            vehicle = {'view'},
            weapons = {'view'},
            weapon = {'view'},
            cases = {'view'},
            case = {'view'},
            notes = {'view'},
            note = {'view'},
            settings = {'view'},
            forms = {'view'},
            management = {'view'}
        },
        [1] = {
            homepage = {'chat', 'search'},
            announcements = {'create'},
            announcement = {'edit', 'remove'},
            patrols = {'create'},
            citizen = {'photo', 'viewcases', 'viewnotes', 'viewvehicles', 'viewaccounts', 'license'},
            vehicle = {'photo', 'viewcases', 'viewnotes'},
            weapon = {'viewcases', 'viewnotes'},
            forms = {'viewAll'},
            cases = {'listview', 'create'},
            case = {'edit', 'delete_warrant'},
            notes = {'listview', 'create'},
            note = {'edit', 'remove'},
            management = {'finances', 'hire'}
        }
    },

    queries = (Framework == 'QBCore' or Framework == 'QBOX') and {
        citizens = {
            table = "players",
            fields = {
                firstname = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))",
                lastname = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))",
                birthdate = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.birthdate'))",
                ssn = "citizenid",
                identifier = "citizenid",
                mdt_image = "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image'))",
                gender = [[
                    CASE
                        WHEN JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '0' THEN 'Male'
                        WHEN JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '1' THEN 'Female'
                        ELSE 'Unknown'
                    END
                ]]
            },
            filters = {
                gender_male = " AND JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '0'",
                gender_female = " AND JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '1'",
                birthdate_format = "%Y-%m-%d",
                wanted = [[
                    SELECT 1 FROM mdt_cases
                    WHERE JSON_CONTAINS(citizens, CONCAT('"', p.citizenid, '"'))
                    AND type = 'warrant'
                ]],
            }
        },
        vehicles = {
            table = "player_vehicles pv",
            join = "LEFT JOIN players p ON pv.citizenid = p.citizenid",
            fields = {
                plate = "pv.plate",
                identifier = "p.citizenid",
                vehicle = "pv.vehicle",
                hash = "pv.hash",
                mdt_image = "pv.mdt_image",
                owners_history = "pv.owners_history"
            },
            wanted = [[
                SELECT 1 FROM mdt_cases
                WHERE JSON_CONTAINS(vehicles, CONCAT('"', pv.plate, '"')) 
                AND type = 'warrant'
            ]]
        },
        ['getCitizenVehicles'] = 'SELECT `hash`, `plate` FROM `player_vehicles` WHERE `citizenid` = ?',
        ['getAuthor'] = [[
            SELECT
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
            FROM
                players
            WHERE
                citizenid = ?
        ]],
        search = {
            ['citizens'] = [[
                SELECT
                    citizenid AS identifier,
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
                FROM
                    players
                WHERE
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE @query
                    OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE @query
                    OR CONCAT(
                        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ',
                        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))
                    ) LIKE @query
                LIMIT 20
            ]],
            ['vehicles'] = [[
                SELECT
                    plate, hash
                FROM
                    player_vehicles
                WHERE
                    plate LIKE @query
                LIMIT 20
            ]],
            ['clerks'] = [[
                SELECT
                    p.citizenid AS identifier,
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname
                FROM
                    players p
                WHERE
                    JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.name')) IN (@jobs)
                    AND (
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) LIKE @query
                        OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) LIKE @query
                        OR CONCAT(
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                        ) LIKE @query
                    )
                LIMIT 20
            ]]
        }
    } or {
        citizens = {
            table = "users",
            fields = {
                firstname = "firstname",
                lastname = "lastname",
                birthdate = "birthdate",
                ssn = "identifier",
                identifier = "identifier",
                mdt_image = "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image'))",
                gender = [[
                    CASE
                        WHEN sex = '0' THEN 'Male'
                        WHEN sex = '1' THEN 'Female'
                        ELSE 'Unknown'
                    END
                ]]
            },
            filters = {
                gender_male = " AND sex = '0'",
                gender_female = " AND sex = '1'",
                birthdate_format = "%Y-%m-%d",
                wanted = [[
                    SELECT 1 FROM mdt_cases
                    WHERE JSON_CONTAINS(citizens, CONCAT('"', players.citizenid, '"'))
                    AND type = 'warrant'
                ]]
            }
        },
        vehicles = {
            table = "owned_vehicles uv",
            join = "LEFT JOIN users u ON uv.owner = u.identifier",
            fields = {
                plate = "uv.plate",
                identifier = "u.identifier",
                vehicle = "uv.vehicle",
                hash = "JSON_UNQUOTE(JSON_EXTRACT(uv.vehicle, '$.model'))",
                mdt_image = "uv.mdt_image"
            }
        },
        ['getCitizenVehicles'] = 'SELECT JSON_UNQUOTE(JSON_EXTRACT(vehicle, "$.model")) AS hash, `plate` FROM `owned_vehicles` WHERE `owner` = ?',
        ['getAuthor'] = [[
            SELECT
                firstname,
                lastname
            FROM
                users
            WHERE
                identifier = ?
        ]],
        search = {
            ['citizens'] = [[
                SELECT
                    identifier AS identifier,
                    firstname,
                    lastname
                FROM
                    users
                WHERE
                    firstname LIKE @query
                    OR lastname LIKE @query
                    OR CONCAT(firstname, ' ', lastname) LIKE @query
                LIMIT 20
            ]],
            ['vehicles'] = [[
                SELECT
                    plate, JSON_UNQUOTE(JSON_EXTRACT(vehicle, "$.model")) AS hash
                FROM
                    owned_vehicles
                WHERE
                    plate LIKE @query
                LIMIT 20
            ]],
            ['clerks'] = [[
                SELECT
                    identifier,
                    lastname,
                    firstname
                FROM
                    users
                WHERE
                    job IN (@jobs)
                    AND (
                        firstname LIKE @query
                        OR lastname LIKE @query
                        OR CONCAT(firstname, ' ', lastname) LIKE @query
                    )
                LIMIT 20
            ]]
        }
    }
}