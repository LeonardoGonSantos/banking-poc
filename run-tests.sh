#!/bin/bash

BASE_URL="http://localhost:5001"
ACCOUNT1="f17b1112-2856-407c-9eb4-1f4f14900f60"
ACCOUNT2="32ff97cd-05d4-42fb-8fee-721582413b07"
ACCOUNT3="a8e85add-5d2e-4fd7-9e9f-28756d0ae5bd"

echo "=== Testando Consulta de Saldo ==="
echo "Saldo Account 1:"
curl -s "$BASE_URL/accounts/$ACCOUNT1/balance" -H "X-Correlation-Id: get-balance-valid" -H "X-Client-Id: test-client" && echo ""

echo "Saldo Account inexistente (404):"
curl -s "$BASE_URL/accounts/00000000-0000-0000-0000-000000000000/balance" -H "X-Correlation-Id: get-balance-invalid" -H "X-Client-Id: test-client" -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testando Transferências ==="
echo "Transferência OK:"
curl -s -X POST "$BASE_URL/transactions" -H "Content-Type: application/json" -H "X-Correlation-Id: transfer-ok-1" -H "X-Client-Id: test-client" -d "{\"fromAccountId\":\"$ACCOUNT1\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":100.0}" && echo ""

echo "Transferência com saldo insuficiente:"
curl -s -X POST "$BASE_URL/transactions" -H "Content-Type: application/json" -H "X-Correlation-Id: transfer-insufficient" -H "X-Client-Id: test-client" -d "{\"fromAccountId\":\"$ACCOUNT1\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":999999.0}" -w "\nHTTP %{http_code}\n"

echo "Transferência com conta origem inexistente:"
curl -s -X POST "$BASE_URL/transactions" -H "Content-Type: application/json" -H "X-Correlation-Id: transfer-invalid-origin" -H "X-Client-Id: test-client" -d "{\"fromAccountId\":\"00000000-0000-0000-0000-000000000000\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":100.0}" -w "\nHTTP %{http_code}\n"

echo "Transferência com conta destino inexistente:"
curl -s -X POST "$BASE_URL/transactions" -H "Content-Type: application/json" -H "X-Correlation-Id: transfer-invalid-destination" -H "X-Client-Id: test-client" -d "{\"fromAccountId\":\"$ACCOUNT1\",\"toAccountId\":\"00000000-0000-0000-0000-000000000000\",\"amount\":100.0}" -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testando Listagem de Transações ==="
echo "Listar todas transações Account 1:"
curl -s "$BASE_URL/accounts/$ACCOUNT1/transactions" -H "X-Correlation-Id: list-transactions-all" -H "X-Client-Id: test-client" && echo ""

echo "Listar transações com filtro de data:"
curl -s "$BASE_URL/accounts/$ACCOUNT1/transactions?startDate=2025-01-01&endDate=2030-01-01" -H "X-Correlation-Id: list-transactions-filtered" -H "X-Client-Id: test-client" && echo ""

echo "Listar transações conta inexistente:"
curl -s "$BASE_URL/accounts/00000000-0000-0000-0000-000000000000/transactions" -H "X-Correlation-Id: list-transactions-invalid" -H "X-Client-Id: test-client" -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testando Erros de Validação ==="
echo "JSON inválido:"
curl -s -X POST "$BASE_URL/transactions" -H "Content-Type: application/json" -H "X-Correlation-Id: transfer-invalid-json" -H "X-Client-Id: test-client" -d "{\"fromAccountId\":\"invalid-guid\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":\"not-a-number\"}" -w "\nHTTP %{http_code}\n"

echo "Método HTTP errado (POST em GET endpoint):"
curl -s -X POST "$BASE_URL/ping" -H "X-Correlation-Id: ping-wrong-method" -H "X-Client-Id: test-client" -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testes de Carga ==="
echo "Executando 30 pings..."
for i in {1..30}; do
  curl -s "$BASE_URL/ping" -H "X-Correlation-Id: spam-ping-$i" -H "X-Client-Id: load-tester" > /dev/null
done
echo "30 pings concluídos"

echo "Executando 20 transferências pequenas..."
for i in {1..20}; do
  curl -s -X POST "$BASE_URL/transactions" -H "Content-Type: application/json" -H "X-Correlation-Id: spam-transfer-$i" -H "X-Client-Id: load-tester" -d "{\"fromAccountId\":\"$ACCOUNT2\",\"toAccountId\":\"$ACCOUNT3\",\"amount\":1.0}" > /dev/null
done
echo "20 transferências concluídas"

echo ""
echo "=== Todos os testes executados! ==="

