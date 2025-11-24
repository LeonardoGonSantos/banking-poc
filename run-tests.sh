#!/bin/bash

BASE_URL="http://localhost:5001"

# Gerar dados aleatórios para esta execução de teste
RANDOM_SFX=$((RANDOM % 9000 + 1000))
TIMESTAMP=$(date +%s)
TEST_EMAIL="test-user-${TIMESTAMP}-${RANDOM_SFX}@test.com"
TEST_CLIENT_ID="${TIMESTAMP}${RANDOM_SFX}" # Inteiro longo e único

echo "=== Configuração do Teste ==="
echo "Email gerado: $TEST_EMAIL"
echo "Client ID: $TEST_CLIENT_ID"
echo ""

echo "=== Testando Health Check ==="
curl -s "$BASE_URL/ping" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" && echo ""

echo ""
echo "=== Criando Usuário e Conta Inicial ==="
# Criar usuário via endpoint /users (que já cria conta)
CREATE_USER_RESP=$(curl -s -X POST "$BASE_URL/users" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"name\":\"Test User\",\"email\":\"$TEST_EMAIL\",\"password\":\"123456\",\"initialBalance\":1000.0}")

# Extrair IDs da resposta
USER_ID=$(echo $CREATE_USER_RESP | grep -o '"userId":"[^"]*"' | cut -d'"' -f4)
ACCOUNT1=$(echo $CREATE_USER_RESP | grep -o '"accountId":"[^"]*"' | cut -d'"' -f4)
TOKEN=$(echo $CREATE_USER_RESP | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ACCOUNT1" ]; then
  echo "Erro ao criar usuário inicial. Resposta:"
  echo $CREATE_USER_RESP
  exit 1
fi

echo "Usuário criado com sucesso!"
echo "UserID: $USER_ID"
echo "Account1: $ACCOUNT1"

echo ""
echo "=== Testando Autenticação ==="
echo "Login com sucesso:"
LOGIN_RESP=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"123456\"}")

echo "Login com senha inválida:"
curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"wrong\"}" \
  -w "\nHTTP %{http_code}\n"

echo "Login com email inexistente:"
curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d '{"email":"wrong@test.com","password":"123456"}' \
  -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Criando Contas Adicionais ==="
# Criar contas adicionais para transferências
echo "Criando Account 2..."
ACC2_RESP=$(curl -s -X POST "$BASE_URL/accounts" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d '{"initialBalance":500.0}')
ACCOUNT2=$(echo $ACC2_RESP | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "Criando Account 3..."
ACC3_RESP=$(curl -s -X POST "$BASE_URL/accounts" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d '{"initialBalance":100.0}')
ACCOUNT3=$(echo $ACC3_RESP | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "Account2: $ACCOUNT2"
echo "Account3: $ACCOUNT3"

echo ""
echo "=== Testando Consulta de Saldo ==="
echo "Saldo Account 1:"
curl -s "$BASE_URL/accounts/$ACCOUNT1/balance" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" && echo ""

echo "Saldo Account inexistente (404):"
curl -s "$BASE_URL/accounts/00000000-0000-0000-0000-000000000000/balance" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testando Transferências ==="
echo "Transferência OK:"
curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"fromAccountId\":\"$ACCOUNT1\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":100.0}" && echo ""

echo "Transferência com saldo insuficiente:"
curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"fromAccountId\":\"$ACCOUNT1\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":999999.0}" \
  -w "\nHTTP %{http_code}\n"

echo "Transferência com conta origem inexistente:"
curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"fromAccountId\":\"00000000-0000-0000-0000-000000000000\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":100.0}" \
  -w "\nHTTP %{http_code}\n"

echo "Transferência com conta destino inexistente:"
curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"fromAccountId\":\"$ACCOUNT1\",\"toAccountId\":\"00000000-0000-0000-0000-000000000000\",\"amount\":100.0}" \
  -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testando Listagem de Transações ==="
echo "Listar todas transações Account 1:"
curl -s "$BASE_URL/accounts/$ACCOUNT1/transactions" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" && echo ""

echo "Listar transações com filtro de data:"
curl -s "$BASE_URL/accounts/$ACCOUNT1/transactions?startDate=2025-01-01&endDate=2030-01-01" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" && echo ""

echo "Listar transações conta inexistente:"
curl -s "$BASE_URL/accounts/00000000-0000-0000-0000-000000000000/transactions" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testando Erros de Validação ==="
echo "JSON inválido:"
curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -d "{\"fromAccountId\":\"invalid-guid\",\"toAccountId\":\"$ACCOUNT2\",\"amount\":\"not-a-number\"}" \
  -w "\nHTTP %{http_code}\n"

echo "Método HTTP errado (POST em GET endpoint):"
curl -s -X POST "$BASE_URL/ping" \
  -H "X-Correlation-Id: $(uuidgen)" \
  -H "X-Client-Id: $TEST_CLIENT_ID" \
  -w "\nHTTP %{http_code}\n"

echo ""
echo "=== Testes de Carga ==="
echo "Executando 30 pings..."
for i in {1..30}; do
  curl -s "$BASE_URL/ping" \
    -H "X-Correlation-Id: $(uuidgen)" \
    -H "X-Client-Id: $TEST_CLIENT_ID" > /dev/null
done
echo "30 pings concluídos"

echo "Executando 20 transferências pequenas..."
for i in {1..20}; do
  curl -s -X POST "$BASE_URL/transactions" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-Id: $(uuidgen)" \
    -H "X-Client-Id: $TEST_CLIENT_ID" \
    -d "{\"fromAccountId\":\"$ACCOUNT2\",\"toAccountId\":\"$ACCOUNT3\",\"amount\":1.0}" > /dev/null
done
echo "20 transferências concluídas"

echo ""
echo "=== Todos os testes executados! ==="
