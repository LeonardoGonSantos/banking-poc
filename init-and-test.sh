#!/bin/sh

# =============================================================================
# Script de Inicialização Completa e Testes
# Este script:
# 1. Aguarda todos os serviços ficarem healthy
# 2. Configura index patterns no OpenSearch Dashboards
# 3. Executa simulação de clientes para gerar dados de teste
# =============================================================================

OPENSEARCH_URL="http://opensearch:9200"
DASHBOARDS_URL="http://opensearch-dashboards:5601"
API_URL="http://banking-api:80"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[OK]${NC} $1"; }
log_warn() { echo "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# FASE 1: Aguardar serviços
# =============================================================================
log_info "=========================================="
log_info "FASE 1: Aguardando serviços ficarem prontos"
log_info "=========================================="

# Aguardar OpenSearch
log_info "Aguardando OpenSearch..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -sf "$OPENSEARCH_URL/_cluster/health" > /dev/null 2>&1; then
    log_success "OpenSearch está disponível!"
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  log_error "OpenSearch não ficou disponível a tempo"
  exit 1
fi

# Aguardar OpenSearch Dashboards
log_info "Aguardando OpenSearch Dashboards..."
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -sf "$DASHBOARDS_URL/api/status" > /dev/null 2>&1; then
    log_success "OpenSearch Dashboards está disponível!"
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  log_error "OpenSearch Dashboards não ficou disponível a tempo"
  exit 1
fi

# Aguardar Banking API
log_info "Aguardando Banking API..."
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -sf "$API_URL/ping" > /dev/null 2>&1; then
    log_success "Banking API está disponível!"
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  log_error "Banking API não ficou disponível a tempo"
  exit 1
fi

# =============================================================================
# FASE 2: Configurar Index Patterns
# =============================================================================
log_info "=========================================="
log_info "FASE 2: Configurando Index Patterns"
log_info "=========================================="

# Criar index pattern para logs
log_info "Criando index pattern para logs..."
response=$(curl -s -X POST "$DASHBOARDS_URL/api/saved_objects/index-pattern/logs-banking-api" \
  -H "Content-Type: application/json" \
  -H "osd-xsrf: true" \
  -d '{
    "attributes": {
      "title": "logs-banking-api",
      "timeFieldName": "@timestamp"
    }
  }')

if echo "$response" | grep -q '"id"'; then
  log_success "Index pattern 'logs-banking-api' criado"
elif echo "$response" | grep -q "already exists"; then
  log_warn "Index pattern 'logs-banking-api' já existe"
else
  log_warn "Resposta do index pattern logs: $response"
fi

# Criar index pattern para traces
log_info "Criando index pattern para traces..."
response=$(curl -s -X POST "$DASHBOARDS_URL/api/saved_objects/index-pattern/traces-banking-api" \
  -H "Content-Type: application/json" \
  -H "osd-xsrf: true" \
  -d '{
    "attributes": {
      "title": "traces-banking-api",
      "timeFieldName": "@timestamp"
    }
  }')

if echo "$response" | grep -q '"id"'; then
  log_success "Index pattern 'traces-banking-api' criado"
elif echo "$response" | grep -q "already exists"; then
  log_warn "Index pattern 'traces-banking-api' já existe"
else
  log_warn "Resposta do index pattern traces: $response"
fi

# Definir logs como index pattern padrão
log_info "Definindo logs-banking-api como index pattern padrão..."
curl -s -X POST "$DASHBOARDS_URL/api/opensearch-dashboards/settings/defaultIndex" \
  -H "Content-Type: application/json" \
  -H "osd-xsrf: true" \
  -d '{"value": "logs-banking-api"}' > /dev/null 2>&1

log_success "Index patterns configurados!"

# =============================================================================
# FASE 3: Executar Simulação de Testes
# =============================================================================
log_info "=========================================="
log_info "FASE 3: Executando Simulação de Testes"
log_info "=========================================="

# Configurações da simulação
TOTAL_CLIENTS=10
OPERATIONS_PER_CLIENT=10

# Arquivos temporários
ACCOUNTS_FILE="/tmp/simulation_accounts.txt"
STATS_FILE="/tmp/simulation_stats.txt"
rm -f "$ACCOUNTS_FILE" "$STATS_FILE"
touch "$ACCOUNTS_FILE" "$STATS_FILE"

# Contador global para garantir unicidade
RANDOM_COUNTER=0

# Gerar número aleatório usando /dev/urandom
get_random() {
    RANDOM_COUNTER=$((RANDOM_COUNTER + 1))
    # Combina urandom com contador para garantir unicidade
    base=$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')
    echo $((base + RANDOM_COUNTER))
}

generate_random_balance() {
    echo $((500 + $(get_random) % 4501))
}

log_info "Iniciando simulação com $TOTAL_CLIENTS clientes..."
log_info "Cada cliente executará $OPERATIONS_PER_CLIENT operações"

# Criar clientes sequencialmente (sh não suporta bem paralelismo)
client_num=1
while [ $client_num -le $TOTAL_CLIENTS ]; do
    rand=$(get_random)
    client_id=$((rand % 90000 + 10000))
    timestamp=$(date +%s)
    
    email="user-${timestamp}-${rand}@test.com"
    name="User-${rand}"
    password="pass-${rand}"
    initial_balance=$(generate_random_balance)
    
    log_info "[Cliente $client_num] Criando usuário: $email"
    
    # Criar usuário
    create_response=$(curl -s -X POST "$API_URL/users" \
        -H "Content-Type: application/json" \
        -H "X-Correlation-Id: init-$client_num-create" \
        -H "X-Client-Id: $client_id" \
        -d "{\"name\":\"$name\",\"email\":\"$email\",\"password\":\"$password\",\"initialBalance\":$initial_balance}")
    
    account_id=$(echo "$create_response" | grep -o '"accountId":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$account_id" ]; then
        log_error "[Cliente $client_num] Falha ao criar usuário"
        client_num=$((client_num + 1))
        continue
    fi
    
    echo "$account_id" >> "$ACCOUNTS_FILE"
    log_success "[Cliente $client_num] Conta criada: $account_id"
    
    # Login
    curl -s -X POST "$API_URL/auth/login" \
        -H "Content-Type: application/json" \
        -H "X-Correlation-Id: init-$client_num-login" \
        -H "X-Client-Id: $client_id" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}" > /dev/null
    
    # Executar operações
    success=0
    failed=0
    op=1
    
    while [ $op -le $OPERATIONS_PER_CLIENT ]; do
        available_accounts=$(cat "$ACCOUNTS_FILE" 2>/dev/null | grep -v "^$" | sort -u)
        total_available=$(echo "$available_accounts" | wc -l | tr -d ' ')
        
        dest_account_id=""
        rand_check=$(get_random)
        
        # 20% chance de usar conta inexistente
        if [ $((rand_check % 100)) -lt 20 ]; then
            dest_account_id="00000000-0000-0000-0000-000000000000"
        else
            if [ "$total_available" -gt 1 ]; then
                other_accounts=$(echo "$available_accounts" | grep -v "^${account_id}$")
                other_count=$(echo "$other_accounts" | wc -l | tr -d ' ')
                if [ "$other_count" -gt 0 ]; then
                    random_line=$((1 + $(get_random) % other_count))
                    dest_account_id=$(echo "$other_accounts" | sed -n "${random_line}p")
                fi
            fi
        fi
        
        [ -z "$dest_account_id" ] && dest_account_id="00000000-0000-0000-0000-000000000000"
        
        amount=$((1 + $(get_random) % 200))
        
        # 20% chance de valor muito alto (saldo insuficiente)
        rand_amount=$(get_random)
        if [ $((rand_amount % 100)) -lt 20 ]; then
            amount=$((5000 + $(get_random) % 5000))
        fi
        
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/transactions" \
            -H "Content-Type: application/json" \
            -H "X-Correlation-Id: init-$client_num-op-$op" \
            -H "X-Client-Id: $client_id" \
            -d "{\"fromAccountId\":\"$account_id\",\"toAccountId\":\"$dest_account_id\",\"amount\":$amount}")
        
        if [ "$http_code" = "200" ]; then
            success=$((success + 1))
            echo "SUCCESS" >> "$STATS_FILE"
        else
            failed=$((failed + 1))
            echo "FAILED" >> "$STATS_FILE"
        fi
        
        op=$((op + 1))
    done
    
    log_info "[Cliente $client_num] Concluído - Sucessos: $success, Falhas: $failed"
    client_num=$((client_num + 1))
done

# Estatísticas finais
SUCCESSFUL=$(grep -c "SUCCESS" "$STATS_FILE" 2>/dev/null || echo "0")
FAILED=$(grep -c "FAILED" "$STATS_FILE" 2>/dev/null || echo "0")
TOTAL=$((SUCCESSFUL + FAILED))
ACCOUNTS_CREATED=$(wc -l < "$ACCOUNTS_FILE" 2>/dev/null | tr -d ' ')

log_info "=========================================="
log_success "SIMULAÇÃO CONCLUÍDA!"
log_info "=========================================="
log_info "Contas criadas: $ACCOUNTS_CREATED"
log_info "Total de operações: $TOTAL"
log_info "Transferências OK: $SUCCESSFUL"
log_info "Transferências com erro: $FAILED"

# =============================================================================
# FASE 4: Verificar dados no OpenSearch
# =============================================================================
log_info "=========================================="
log_info "FASE 4: Verificando dados no OpenSearch"
log_info "=========================================="

sleep 5 # Aguardar flush do OTEL

logs_count=$(curl -s "$OPENSEARCH_URL/logs-banking-api/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo "0")
traces_count=$(curl -s "$OPENSEARCH_URL/traces-banking-api/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo "0")

log_success "Logs indexados: $logs_count"
log_success "Traces indexados: $traces_count"

log_info "=========================================="
log_success "AMBIENTE 100% CONFIGURADO E PRONTO!"
log_info "=========================================="
log_info "Acesse o OpenSearch Dashboards em: http://localhost:5601"
log_info "API disponível em: http://localhost:5001"
log_info "=========================================="

