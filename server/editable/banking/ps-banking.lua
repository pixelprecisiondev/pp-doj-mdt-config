return {
    accounts = {
        database = {
            table = 'ps_banking_accounts',
            account_id = "id",
            account_number = 'cardNumber',
            account_name = 'holder',
            account_balance = 'balance',
            account_owner = 'owner',
        },

        getAccounts = function(data)
            local query = [=[
                SELECT
                    acc.id AS id,
                    acc.cardNumber AS number,
                    acc.holder AS name,
                    acc.balance AS balance,
                    CASE
                        WHEN JSON_UNQUOTE(JSON_EXTRACT(acc.owner, '$.firstname')) IS NULL
                        THEN acc.holder
                        ELSE CONCAT(
                            JSON_UNQUOTE(JSON_EXTRACT(acc.owner, '$.firstname')), ' ',
                            JSON_UNQUOTE(JSON_EXTRACT(acc.owner, '$.lastname'))
                        )
                    END AS owner
                FROM ps_banking_accounts acc
                WHERE 1 = 1
            ]=]

            local totalQuery = [=[
                SELECT COUNT(*) AS total
                FROM ps_banking_accounts acc
                WHERE 1 = 1
            ]=]

            if data.value and data.value ~= "" then
                local searchCondition = ([=[
                    AND (acc.cardNumber LIKE @value OR
                    acc.holder LIKE @value OR
                    CONCAT(JSON_UNQUOTE(JSON_EXTRACT(acc.owner, '$.firstname')), ' ',
                    JSON_UNQUOTE(JSON_EXTRACT(acc.owner, '$.lastname'))) LIKE @value)
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
                UPDATE ps_banking_transactions SET doj_note = ? WHERE id = ?
            ]], {
                data.content, data.id
            })
        end,

        getTransactions = function(data)
            local query = [=[
                SELECT
                    t.identifier AS id,
                    t.description AS title,
                    t.amount AS amount,
                    t.date AS date,
                    t.type AS transaction_type,
                    t.isIncome AS is_income
                FROM ps_banking_transactions t
                WHERE 1 = 1
            ]=]

            local totalQuery = [=[
                SELECT COUNT(*) AS total
                FROM ps_banking_transactions t
                WHERE 1 = 1
            ]=]

            if data.value and data.value ~= "" then
                local searchCondition = " AND (t.description LIKE @value OR t.identifier LIKE @value)"
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
    
            if data.sort == "date-asc" then
                query = query .. " ORDER BY t.date ASC"
            elseif data.sort == "date-desc" then
                query = query .. " ORDER BY t.date DESC"
            elseif data.sort == "amount-asc" then
                query = query .. " ORDER BY t.amount ASC"
            elseif data.sort == "amount-desc" then
                query = query .. " ORDER BY t.amount DESC"
            else
                query = query .. " ORDER BY t.identifier DESC"
            end
    
            return query, totalQuery
        end,

        getTransaction = function()
            local query = [[
                SELECT
                    t.identifier AS id,
                    t.description AS title,
                    t.amount AS amount,
                    t.date AS date,
                    t.type AS transaction_type,
                    t.isIncome AS is_income
                FROM ps_banking_transactions t
                WHERE t.identifier = @id
            ]]
    
            local historyQuery = [[
                SELECT
                    t.date AS date,
                    t.description AS title,
                    t.identifier AS id,
                    t.amount AS amount
                FROM ps_banking_transactions t
                WHERE t.identifier = @id
                ORDER BY t.date DESC
                LIMIT 20
            ]]

            return query, historyQuery
        end,

        exportTransactions = function(data)
            local result = MySQL.query.await([[
                SELECT
                    t.identifier AS id,
                    t.description AS title,
                    t.amount AS amount,
                    t.date AS date,
                    t.type AS transaction_type,
                    t.isIncome AS is_income
                FROM ps_banking_transactions t
                WHERE (t.identifier = @account)
                AND t.date BETWEEN @startDate AND @endDate
                ORDER BY t.identifier DESC
            ]], {
                ['@account'] = data.account,
                ['@startDate'] = data.date[1],
                ['@endDate'] = data.date[2]
            })

            if result and #result > 0 then
                for i, transaction in ipairs(result) do
                    result[i] = {
                        from = transaction.transaction_type == 'From account' and transaction.title or 'Unknown',
                        to = transaction.transaction_type == 'To account' and transaction.title or 'Unknown',
                        amount = transaction.amount,
                        message = transaction.title,
                        ['created at'] = os.date('%Y-%m-%d %H:%M:%S', math.floor(transaction.date / 1000))
                    }
                end
            end

            return result, 'amount'
        end
    }
}