return {
    accounts = {
        database = {
            table = 'users',
            account_id = "identifier",
            account_number = 'identifier',
            account_name = "CONCAT(firstname, ' ', lastname)",
            account_balance = "bank",
            account_owner = 'identifier',
            account_note = 'doj_note',
            account_created_at = 'created_at',
        },

        getAccounts = function(data)
            local query = [[
                SELECT
                    u.identifier AS id,
                    u.identifier AS number,
                    CONCAT(u.firstname, ' ', u.lastname, ' (', u.identifier, ')') AS name,
                    u.bank AS balance,
                    CONCAT(u.firstname, ' ', u.lastname) AS owner
                FROM users u
                WHERE 1 = 1
            ]]

            local totalQuery = [[
                SELECT COUNT(*) AS total
                FROM users u
                WHERE 1 = 1
            ]]

            if data.value and data.value ~= "" then
                local searchCondition = " AND (u.identifier LIKE @value OR " ..
                    "CONCAT(u.firstname, ' ', u.lastname, ' (', u.identifier, ')') LIKE @value) "
                query = query .. searchCondition
                totalQuery = totalQuery .. searchCondition
            end
    
            if data.filter == "balance-positive" then
                query = query .. " AND u.bank > 0"
                totalQuery = totalQuery .. " AND u.bank > 0"
            elseif data.filter == "balance-negative" then
                query = query .. " AND u.bank < 0"
                totalQuery = totalQuery .. " AND u.bank < 0"
            end

            if data.sort == "name-asc" then
                query = query .. " ORDER BY name ASC"
            elseif data.sort == "name-desc" then
                query = query .. " ORDER BY name DESC"
            elseif data.sort == "balance-asc" then
                query = query .. " ORDER BY balance ASC"
            elseif data.sort == "balance-desc" then
                query = query .. " ORDER BY balance DESC"
            else
                query = query .. " ORDER BY id DESC"
            end

            return query, totalQuery
        end
    },
    transactions = {
        setDojNote = function(data)
            return MySQL.update.await([[
                UPDATE user_transactions
                SET transactions = JSON_SET(
                    transactions,
                    CONCAT('$.transactions[',
                        JSON_SEARCH(transactions, 'one', ?, NULL, '$.transactions[*].trans_id'),
                    '].doj_note'),
                    ?
                )
                WHERE JSON_CONTAINS(transactions, JSON_OBJECT('trans_id', ?), '$.transactions')
            ]], {
                data.id, data.content, data.id
            })
        end,
        getTransactions = function(data)
            local query = [[
                SELECT id, transactions FROM player_transactions WHERE 1 = 1
            ]]

            if data.account then
                query = query .. " AND id = @account"
            end

            local results = MySQL.query.await(query, {
                ['@account'] = data.account
            })

            local transactionsList = {}
            if results and #results > 0 then
                for _, row in ipairs(results) do
                    local transactions = json.decode(row.transactions) or {}
                    for _, transaction in ipairs(transactions) do
                        table.insert(transactionsList, transaction)
                    end
                end
            end

            if data.filter then
                local filterRanges = {
                    ["amount-1"] = {0, 1000},
                    ["amount-2"] = {1000, 10000},
                    ["amount-3"] = {10000, 100000},
                    ["amount-4"] = {100000, 500000},
                    ["amount-5"] = {500000, 1000000},
                    ["amount-6"] = {1000000, math.huge}
                }

                local range = filterRanges[data.filter]
                if range then
                    local filteredTransactions = {}
                    for _, transaction in ipairs(transactionsList) do
                        if transaction.amount >= range[1] and transaction.amount < range[2] then
                            table.insert(filteredTransactions, transaction)
                        end
                    end
                    transactionsList = filteredTransactions
                end
            end

            if data.sort then
                table.sort(transactionsList, function(a, b)
                    if data.sort == "date-asc" then
                        return a.date < b.date
                    elseif data.sort == "date-desc" then
                        return a.date > b.date
                    elseif data.sort == "amount-asc" then
                        return a.amount < b.amount
                    elseif data.sort == "amount-desc" then
                        return a.amount > b.amount
                    else
                        return a.id > b.id
                    end
                end)
            end

            return transactionsList
        end,

        getTransaction = function()
            local query = [[
                SELECT
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.trans_id')) AS id,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.message')) AS title,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.amount')) AS amount,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.time')) AS date,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.issuer')) AS from_id,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.receiver')) AS to_id,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.doj_note')) AS note,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.issuer_name')) AS from_name,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.receiver_name')) AS to_name,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.issuer_number')) AS from_number,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.receiver_number')) AS to_number
                FROM player_transactions p,
                JSON_TABLE(p.transactions, '$.transactions[*]' COLUMNS (
                    value JSON PATH '$'
                )) t
                WHERE p.id = @id AND JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.trans_id')) = @trans_id
            ]]

            local historyQuery = [[
                SELECT
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.time')) AS date,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.message')) AS title,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.trans_id')) AS id,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.amount')) AS amount,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.issuer_number')) AS `from`,
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.receiver_number')) AS `to`
                FROM player_transactions p,
                JSON_TABLE(p.transactions, '$.transactions[*]' COLUMNS (
                    value JSON PATH '$'
                )) t
                WHERE p.id = @id AND (
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.issuer')) = @from AND 
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.receiver')) = @to
                ) OR (
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.issuer')) = @to AND 
                    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.receiver')) = @from
                )
                ORDER BY JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.time')) DESC
                LIMIT 20
            ]]

            return query, historyQuery
        end,

        exportTransactions = function(data)
            local query = [[
                SELECT transactions FROM player_transactions WHERE id = @account
            ]]
            local result = MySQL.query.await(query, {['@account'] = data.account})

            local exported = {}
            if result and #result > 0 then
                local transactions = json.decode(result[1].transactions) or {}
                for _, transaction in ipairs(transactions) do
                    if transaction.time >= data.date[1] and transaction.time <= data.date[2] then
                        table.insert(exported, {
                            from = transaction.issuer,
                            to = transaction.receiver,
                            amount = transaction.amount,
                            message = transaction.message,
                            ['created at'] = transaction.time
                        })
                    end
                end
            end

            return exported, 'amount'
        end
    }
}