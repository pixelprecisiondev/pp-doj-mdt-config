return {
    accounts = {
        database = {
            table = 'pefcl_accounts',
            account_id = "id",
            account_number = 'number',
            account_name = 'accountName',
            account_balance = 'balance',
            account_owner = 'ownerIdentifier',
            account_note = 'doj_note',
            account_created_at = 'createdAt',
        },
        getAccounts = function(data)
            local query = [=[
                SELECT
                    acc.id AS id,
                    acc.number AS number,
                    CASE
                        WHEN JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) IS NULL
                        THEN acc.accountName
                        ELSE CONCAT(
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')), ' (', acc.accountName, ')'
                        )
                    END AS name,
                    acc.balance AS balance,
                    CASE
                        WHEN JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) IS NULL
                        THEN acc.accountName
                        ELSE CONCAT(
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                        )
                    END AS owner
                FROM pefcl_accounts acc
                LEFT JOIN players p ON acc.ownerIdentifier = p.citizenid
                WHERE 1 = 1
            ]=]

            local totalQuery = [=[
                SELECT COUNT(*) AS total
                FROM pefcl_accounts acc
                LEFT JOIN players p ON acc.ownerIdentifier = p.citizenid
                WHERE 1 = 1
            ]=]

            if data.value and data.value ~= "" then
                local searchCondition = ([=[
                    AND (acc.number LIKE @value OR 
                    CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')), ' (', acc.accountName, ')') LIKE @value)
                ]=])
                query = query .. searchCondition
                totalQuery = totalQuery .. searchCondition
            end

            if data.filter == "balance-positive" then
                query = query .. " AND acc.balance > 0"
                totalQuery = totalQuery .. " AND acc.balance > 0"
            elseif data.filter == "balance-negative" then
                query = query .. " AND acc.balance < 0"
                totalQuery = totalQuery .. " AND acc.balance < 0"
            end

            if data.sort == "name-asc" then
                query = query .. " ORDER BY name ASC"
            elseif data.sort == "name-desc" then
                query = query .. " ORDER BY name DESC"
            elseif data.sort == "balance-asc" then
                query = query .. " ORDER BY acc.balance ASC"
            elseif data.sort == "balance-desc" then
                query = query .. " ORDER BY acc.balance DESC"
            else
                query = query .. " ORDER BY acc.id DESC"
            end
            return query, totalQuery
        end
    },
    transactions = {

        setDojNote = function(data)
            return MySQL.update.await([[
                UPDATE pefcl_transactions SET doj_note = ? WHERE id = ?
            ]], {
                data.content, data.id
            })
        end,
        getTransactions = function(data)
            local query = [=[
                SELECT
                    t.id AS id,
                    t.message AS title,
                    t.amount AS amount,
                    t.createdAt AS date,
                    t.toAccountId AS to_id,
                    t.fromAccountId AS from_id,
                    t.doj_note AS note,
                    IFNULL(CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p_from.charinfo, '$.firstname')), ' ',
                                  JSON_UNQUOTE(JSON_EXTRACT(p_from.charinfo, '$.lastname'))), 'Unknown') AS from_name,
                    IFNULL(CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p_to.charinfo, '$.firstname')), ' ',
                                  JSON_UNQUOTE(JSON_EXTRACT(p_to.charinfo, '$.lastname'))), 'Unknown') AS to_name,
                    a_from.number AS from_number,
                    a_to.number AS to_number
                FROM pefcl_transactions t
                LEFT JOIN pefcl_accounts a_from ON t.fromAccountId = a_from.id
                LEFT JOIN pefcl_accounts a_to ON t.toAccountId = a_to.id
                LEFT JOIN players p_from ON a_from.ownerIdentifier = p_from.citizenid
                LEFT JOIN players p_to ON a_to.ownerIdentifier = p_to.citizenid
                WHERE 1 = 1
            ]=]
            local totalQuery = [=[
                SELECT COUNT(*) AS total
                FROM pefcl_transactions t
                LEFT JOIN pefcl_accounts a_from ON t.fromAccountId = a_from.id
                LEFT JOIN pefcl_accounts a_to ON t.toAccountId = a_to.id
                LEFT JOIN players p_from ON a_from.ownerIdentifier = p_from.citizenid
                LEFT JOIN players p_to ON a_to.ownerIdentifier = p_to.citizenid
                WHERE 1 = 1
            ]=]
            if data.value and data.value ~= "" then
                local searchCondition = ([=[
                    AND (
                        a_from.number LIKE @value OR
                        a_to.number LIKE @value OR
                        IFNULL(CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p_from.charinfo, '$.firstname')), ' ', 
                                      JSON_UNQUOTE(JSON_EXTRACT(p_from.charinfo, '$.lastname'))), 'Unknown') LIKE @value OR
                        IFNULL(CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p_to.charinfo, '$.firstname')), ' ', 
                                      JSON_UNQUOTE(JSON_EXTRACT(p_to.charinfo, '$.lastname'))), 'Unknown') LIKE @value
                    )
                ]=])
                query = query .. searchCondition
                totalQuery = totalQuery .. searchCondition
            end
            if data.filter == "amount-1" then
                query = query .. " AND t.amount BETWEEN 0 AND 1000"
                totalQuery = totalQuery .. " AND t.amount BETWEEN 0 AND 1000"
            elseif data.filter == "amount-2" then
                query = query .. " AND t.amount BETWEEN 1000 AND 10000"
                totalQuery = totalQuery .. " AND t.amount BETWEEN 1000 AND 10000"
            elseif data.filter == "amount-3" then
                query = query .. " AND t.amount BETWEEN 10000 AND 100000"
                totalQuery = totalQuery .. " AND t.amount BETWEEN 10000 AND 100000"
            elseif data.filter == "amount-4" then
                query = query .. " AND t.amount BETWEEN 100000 AND 500000"
                totalQuery = totalQuery .. " AND t.amount BETWEEN 100000 AND 500000"
            elseif data.filter == "amount-5" then
                query = query .. " AND t.amount BETWEEN 500000 AND 1000000"
                totalQuery = totalQuery .. " AND t.amount BETWEEN 500000 AND 1000000"
            elseif data.filter == "amount-6" then
                query = query .. " AND t.amount > 1000000"
                totalQuery = totalQuery .. " AND t.amount > 1000000"
            end

            if data.account then
                query = query .. " AND (t.fromAccountId = @account OR t.toAccountId = @account)"
                totalQuery = totalQuery .. " AND (t.fromAccountId = @account OR t.toAccountId = @account)"
            end

            if data.sort == "from-asc" then
                query = query .. " ORDER BY a_from.number ASC"
            elseif data.sort == "from-desc" then
                query = query .. " ORDER BY a_from.number DESC"
            elseif data.sort == "to-asc" then
                query = query .. " ORDER BY a_to.number ASC"
            elseif data.sort == "to-desc" then
                query = query .. " ORDER BY a_to.number DESC"
            elseif data.sort == "balance-asc" then
                query = query .. " ORDER BY t.amount ASC"
            elseif data.sort == "balance-desc" then
                query = query .. " ORDER BY t.amount DESC"
            elseif data.sort == "date-asc" then
                query = query .. " ORDER BY t.createdAt ASC"
            elseif data.sort == "date-desc" then
                query = query .. " ORDER BY t.createdAt DESC"
            else
                query = query .. " ORDER BY t.id DESC"
            end

            return query, totalQuery
        end,
        getTransaction = function()
            local query = [[
                SELECT
                    t.id AS id,
                    t.message AS title,
                    t.amount AS amount,
                    t.createdAt AS date,
                    t.toAccountId AS to_id,
                    t.fromAccountId AS from_id,
                    t.doj_note AS note,
                    IFNULL(CONCAT(
                        JSON_UNQUOTE(JSON_EXTRACT(p_from.charinfo, '$.firstname')), ' ',
                        JSON_UNQUOTE(JSON_EXTRACT(p_from.charinfo, '$.lastname'))
                    ), 'Unknown') AS from_name,
                    IFNULL(CONCAT(
                        JSON_UNQUOTE(JSON_EXTRACT(p_to.charinfo, '$.firstname')), ' ',
                        JSON_UNQUOTE(JSON_EXTRACT(p_to.charinfo, '$.lastname'))
                    ), 'Unknown') AS to_name,
                    a_from.number AS from_number,
                    a_to.number AS to_number
                FROM pefcl_transactions t
                LEFT JOIN pefcl_accounts a_from ON t.fromAccountId = a_from.id
                LEFT JOIN pefcl_accounts a_to ON t.toAccountId = a_to.id
                LEFT JOIN players p_from ON a_from.ownerIdentifier = p_from.citizenid
                LEFT JOIN players p_to ON a_to.ownerIdentifier = p_to.citizenid
                WHERE t.id = @id
            ]]

            local historyQuery = [[
                SELECT
                    t.createdAt AS date,
                    t.message AS title,
                    t.id AS id,
                    t.amount AS amount,
                    a_from.number AS `from`,
                    a_to.number AS `to`
                FROM pefcl_transactions t
                LEFT JOIN pefcl_accounts a_from ON t.fromAccountId = a_from.id
                LEFT JOIN pefcl_accounts a_to ON t.toAccountId = a_to.id
                WHERE (t.fromAccountId = @from AND t.toAccountId = @to)
                    OR (t.fromAccountId = @to AND t.toAccountId = @from)
                ORDER BY t.createdAt DESC
                LIMIT 20
            ]]

            return query, historyQuery
        end,
        exportTransactions = function(data)
            local result = MySQL.query.await([[
                SELECT
                    CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p1.charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(p1.charinfo, '$.lastname'))) AS fromAccountOwner,
                    CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p2.charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(p2.charinfo, '$.lastname'))) AS toAccountOwner,
                    a1.number AS fromAccountNumber,
                    a2.number AS toAccountNumber,
                    t.message,
                    t.createdAt,
                    t.amount
                FROM `pefcl_transactions` t
                LEFT JOIN `pefcl_accounts` a1 ON t.fromAccountId = a1.id
                LEFT JOIN `pefcl_accounts` a2 ON t.toAccountId = a2.id
                LEFT JOIN `players` p1 ON a1.ownerIdentifier = p1.citizenid
                LEFT JOIN `players` p2 ON a2.ownerIdentifier = p2.citizenid
                WHERE (t.toAccountId = @account OR t.fromAccountId = @account)
                AND t.createdAt BETWEEN @startDate AND @endDate
                ORDER BY t.id DESC
            ]], {
                ['@account'] = data.account,
                ['@startDate'] = data.date[1],
                ['@endDate'] = data.date[2]
            })

            if result and #result > 0 then
                for i, transaction in ipairs(result) do
                    result[i] = {
                        from = transaction.fromAccountOwner and transaction.fromAccountOwner .. ' (' .. transaction.fromAccountNumber .. ')' or transaction.fromAccountNumber,
                        to = transaction.toAccountOwner and transaction.toAccountOwner or 'Unknown' .. ' (' .. transaction.toAccountNumber .. ')' or transaction.toAccountNumber,
                        amount = transaction.amount,
                        message = transaction.message,
                        ['created at'] = os.date('%Y-%m-%d %H:%M:%S', math.floor(transaction.createdAt / 1000))
                    }
                end
            end

            return result, 'amount'
        end
    }
}