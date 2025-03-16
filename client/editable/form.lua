-- ox_inventory
exports('openInventoryForm', function(_, data)
    openDocument(data.metadata)
end)

-- qb-inventory
RegisterNetEvent('pp-doj-mdt:openInventoryForm', function(data)
    openDocument(data)
end)