#!/bin/bash

# Script de Validação da Simulação no PostgreSQL

echo "=========================================="
echo "Validação da Simulação no PostgreSQL"
echo "=========================================="
echo ""

# Executar queries no PostgreSQL via Docker
PSQL_CMD="docker compose exec -T postgres psql -U banking -d bankingdb"

echo "1. Total de Usuários:"
$PSQL_CMD -c "SELECT COUNT(*) as total_users FROM \"Users\";"

echo ""
echo "2. Total de Contas:"
$PSQL_CMD -c "SELECT COUNT(*) as total_accounts FROM \"Accounts\";"

echo ""
echo "3. Total de Transações:"
$PSQL_CMD -c "SELECT COUNT(*) as total_transactions FROM \"Transactions\";"

echo ""
echo "4. Estatísticas de Saldos:"
$PSQL_CMD -c "SELECT 
    COUNT(*) as total_accounts,
    MIN(\"Balance\") as min_balance,
    MAX(\"Balance\") as max_balance,
    AVG(\"Balance\")::numeric(18,2) as avg_balance,
    SUM(\"Balance\")::numeric(18,2) as total_balance
FROM \"Accounts\";"

echo ""
echo "5. Top 10 Contas por Saldo:"
$PSQL_CMD -c "SELECT 
    a.\"Id\" as account_id,
    u.\"Email\" as user_email,
    a.\"Balance\"
FROM \"Accounts\" a
JOIN \"Users\" u ON a.\"UserId\" = u.\"Id\"
ORDER BY a.\"Balance\" DESC
LIMIT 10;"

echo ""
echo "6. Estatísticas de Transações:"
$PSQL_CMD -c "SELECT 
    COUNT(*) as total_transactions,
    COUNT(DISTINCT \"FromAccountId\") as unique_from_accounts,
    COUNT(DISTINCT \"ToAccountId\") as unique_to_accounts,
    SUM(\"Amount\")::numeric(18,2) as total_amount,
    AVG(\"Amount\")::numeric(18,2) as avg_amount,
    MIN(\"Amount\") as min_amount,
    MAX(\"Amount\") as max_amount
FROM \"Transactions\";"

echo ""
echo "7. Transações por Tipo:"
$PSQL_CMD -c "SELECT 
    \"Type\",
    COUNT(*) as count
FROM \"Transactions\"
GROUP BY \"Type\"
ORDER BY count DESC;"

echo ""
echo "8. Contas com Mais Transações (Top 10):"
$PSQL_CMD -c "SELECT 
    a.\"Id\" as account_id,
    u.\"Email\" as user_email,
    COUNT(t.\"Id\") as transaction_count
FROM \"Accounts\" a
LEFT JOIN \"Transactions\" t ON (t.\"FromAccountId\" = a.\"Id\" OR t.\"ToAccountId\" = a.\"Id\")
JOIN \"Users\" u ON a.\"UserId\" = u.\"Id\"
GROUP BY a.\"Id\", u.\"Email\"
ORDER BY transaction_count DESC
LIMIT 10;"

echo ""
echo "9. Verificação de Integridade (saldos negativos):"
$PSQL_CMD -c "SELECT 
    COUNT(*) as accounts_with_negative_balance
FROM \"Accounts\"
WHERE \"Balance\" < 0;"

echo ""
echo "10. Distribuição de Saldos por Faixa:"
$PSQL_CMD -c "SELECT 
    CASE 
        WHEN \"Balance\" < 0 THEN 'Negativo'
        WHEN \"Balance\" = 0 THEN 'Zero'
        WHEN \"Balance\" > 0 AND \"Balance\" <= 100 THEN '0-100'
        WHEN \"Balance\" > 100 AND \"Balance\" <= 500 THEN '100-500'
        WHEN \"Balance\" > 500 AND \"Balance\" <= 1000 THEN '500-1000'
        WHEN \"Balance\" > 1000 AND \"Balance\" <= 5000 THEN '1000-5000'
        ELSE 'Acima de 5000'
    END as balance_range,
    COUNT(*) as count
FROM \"Accounts\"
GROUP BY balance_range
ORDER BY 
    CASE balance_range
        WHEN 'Negativo' THEN 1
        WHEN 'Zero' THEN 2
        WHEN '0-100' THEN 3
        WHEN '100-500' THEN 4
        WHEN '500-1000' THEN 5
        WHEN '1000-5000' THEN 6
        ELSE 7
    END;"

echo ""
echo "11. Últimas 10 Transações Criadas:"
$PSQL_CMD -c "SELECT 
    t.\"Id\",
    t.\"Type\",
    t.\"Amount\",
    t.\"CreatedAt\",
    u1.\"Email\" as from_user,
    u2.\"Email\" as to_user
FROM \"Transactions\" t
JOIN \"Accounts\" a1 ON t.\"FromAccountId\" = a1.\"Id\"
JOIN \"Users\" u1 ON a1.\"UserId\" = u1.\"Id\"
JOIN \"Accounts\" a2 ON t.\"ToAccountId\" = a2.\"Id\"
JOIN \"Users\" u2 ON a2.\"UserId\" = u2.\"Id\"
ORDER BY t.\"CreatedAt\" DESC
LIMIT 10;"

echo ""
echo "=========================================="
echo "Validação Concluída!"
echo "=========================================="

