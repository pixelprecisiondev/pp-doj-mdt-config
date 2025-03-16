local config = require 'config/config_s'

AddEventHandler('esx:setJob', function(player, newJob, prevJob)
    if lib.table.contains(config.jobsWithAccess, newJob.name) then
        startDuty(player)
    elseif lib.table.contains(config.jobsWithAccess, prevJob.name) then
        endDuty(player)
    end
end)

RegisterNetEvent('esx:playerLoaded', function(player, xPlayer)
    local job = xPlayer.getJob().name

    if lib.table.contains(config.jobsWithAccess, job) then
        startDuty(player)
    elseif lib.table.contains(config.jobsWithAccess, job) then
        endDuty(player)
    end
end)

AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not lib.table.contains(config.jobsWithAccess, Player.PlayerData.job.name) then return end

    if onDuty then
        startDuty(source)
    else
        endDuty(source)
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() 
    local Player = Bridge.getPlayerFromId(source)
    if not Player then return end

    if lib.table.contains(config.jobsWithAccess, Player.PlayerData.job.name) then
        startDuty(source)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local Player = Bridge.getPlayerFromId(src)
    if not Player then return end
    local PlayerJob = Bridge.getJob(Player).name

    if lib.table.contains(config.jobsWithAccess, PlayerJob) then
        endDuty(src)
    end
end)