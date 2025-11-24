#!/bin/bash

# Script de Simulação de 50 Clientes
# Cada cliente cria conta, faz login e executa 30 operações

BASE_URL="http://localhost:5001"
TOTAL_CLIENTS=50
OPERATIONS_PER_CLIENT=30

# Arquivos temporários para armazenar dados
ACCOUNTS_FILE="/tmp/simulation_accounts.txt"
STATS_FILE="/tmp/simulation_stats.txt"

# Inicializar arquivos
rm -f "$ACCOUNTS_FILE" "$STATS_FILE"
touch "$ACCOUNTS_FILE" "$STATS_FILE"

# Função para gerar nome aleatório
generate_random_name() {
    local names=("João" "Maria" "Pedro" "Ana" "Carlos" "Julia" "Paulo" "Fernanda" "Ricardo" "Mariana" 
                 "Lucas" "Beatriz" "Gabriel" "Isabela" "Rafael" "Camila" "Bruno" "Larissa" "Felipe" "Amanda"
                 "Thiago" "Patricia" "Rodrigo" "Renata" "Marcelo" "Vanessa" "Andre" "Cristina" "Diego" "Tatiana")
    echo "${names[$RANDOM % ${#names[@]}]} $(date +%s)$RANDOM"
}

# Função para gerar email único
generate_random_email() {
    echo "user-$(date +%s)-$RANDOM@test.com"
}

# Função para gerar senha aleatória
generate_random_password() {
    echo "pass-$RANDOM-$RANDOM"
}

# Função para gerar saldo inicial aleatório (500-5000)
generate_random_balance() {
    echo $((500 + RANDOM % 4501))
}

# Função para simular um cliente
simulate_client() {
    local client_num=$1
    local correlation_id=$(uuidgen)
    local client_id=$((RANDOM % 90000 + 10000)) # Inteiro randômico de 5 dígitos
    
    # Gerar dados aleatórios
    local name=$(generate_random_name)
    local email=$(generate_random_email)
    local password=$(generate_random_password)
    local initial_balance=$(generate_random_balance)
    
    echo "[Cliente $client_num] Iniciando simulação - Email: $email"
    
    # 1. Criar usuário e conta
    local create_response=$(curl -s -X POST "$BASE_URL/users" \
        -H "Content-Type: application/json" \
        -H "X-Correlation-Id: $correlation_id-create" \
        -H "X-Client-Id: $client_id" \
        -d "{\"name\":\"$name\",\"email\":\"$email\",\"password\":\"$password\",\"initialBalance\":$initial_balance}")
    
    local account_id=$(echo "$create_response" | grep -o '"accountId":"[^"]*"' | cut -d'"' -f4)
    local user_id=$(echo "$create_response" | grep -o '"userId":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$account_id" ] || [ -z "$user_id" ]; then
        echo "[Cliente $client_num] ERRO: Falha ao criar usuário"
        return 1
    fi
    
    # Salvar account_id no arquivo compartilhado
    echo "$account_id" >> "$ACCOUNTS_FILE"
    
    echo "[Cliente $client_num] Usuário criado - AccountId: $account_id"
    
    # 2. Fazer login
    local login_response=$(curl -s -X POST "$BASE_URL/auth/login" \
        -H "Content-Type: application/json" \
        -H "X-Correlation-Id: $correlation_id-login" \
        -H "X-Client-Id: $client_id" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}")
    
    local token=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$token" ]; then
        echo "[Cliente $client_num] ERRO: Falha no login"
        return 1
    fi
    
    echo "[Cliente $client_num] Login realizado com sucesso"
    
    # 3. Executar 30 operações
    local client_success=0
    local client_failed=0
    
    # Aguardar um pouco para outros clientes criarem contas
    sleep 2
    
    for ((op=1; op<=OPERATIONS_PER_CLIENT; op++)); do
        local op_correlation_id=$(uuidgen)
        
        # Ler contas disponíveis do arquivo
        local available_accounts=$(cat "$ACCOUNTS_FILE" 2>/dev/null | grep -v "^$" | sort -u)
        local total_available=$(echo "$available_accounts" | wc -l | tr -d ' ')
        
        # Escolher destino aleatório
        local dest_account_id=""
        
        # 30% de chance de usar conta inexistente (para gerar erro)
        if [ $((RANDOM % 100)) -lt 30 ] && [ "$total_available" -gt 1 ]; then
            dest_account_id="00000000-0000-0000-0000-000000000000"
        else
            # Escolher uma conta aleatória (não pode ser a própria)
            if [ "$total_available" -gt 1 ]; then
                # Filtrar contas diferentes da própria
                local other_accounts=$(echo "$available_accounts" | grep -v "^${account_id}$")
                local other_count=$(echo "$other_accounts" | wc -l | tr -d ' ')
                if [ "$other_count" -gt 0 ]; then
                    local random_line=$((1 + RANDOM % other_count))
                    dest_account_id=$(echo "$other_accounts" | sed -n "${random_line}p")
                else
                    # Se não tem outras contas, usar conta seed
                    dest_account_id="00000000-0000-0000-0000-000000000001"
                fi
            else
                # Se só tem uma conta, usar conta seed ou inexistente
                dest_account_id="00000000-0000-0000-0000-000000000001"
            fi
        fi
        
        # Gerar valor aleatório (1-500)
        local amount=$((1 + RANDOM % 500))
        
        # 70% transferências válidas, 30% que podem falhar
        local should_fail=false
        if [ $((RANDOM % 100)) -lt 30 ]; then
            # Tentar transferir valor muito alto (vai falhar por saldo insuficiente)
            amount=$((5000 + RANDOM % 10000))
            should_fail=true
        fi
        
        # Executar transferência
        local transfer_response=$(curl -s -X POST "$BASE_URL/transactions" \
            -H "Content-Type: application/json" \
            -H "X-Correlation-Id: $op_correlation_id" \
            -H "X-Client-Id: $client_id" \
            -d "{\"fromAccountId\":\"$account_id\",\"toAccountId\":\"$dest_account_id\",\"amount\":$amount}" \
            -w "\nHTTP %{http_code}")
        
        local http_code=$(echo "$transfer_response" | grep -o "HTTP [0-9]*" | cut -d' ' -f2)
        
        if [ "$http_code" = "200" ]; then
            ((client_success++))
            echo "SUCCESS" >> "$STATS_FILE"
        else
            ((client_failed++))
            echo "FAILED" >> "$STATS_FILE"
        fi
        
        # Pequeno delay para não sobrecarregar
        sleep 0.1
    done
    
    echo "[Cliente $client_num] Concluído - Sucessos: $client_success, Falhas: $client_failed"
    
    # Salvar dados do cliente em arquivo temporário
    echo "$client_num|$user_id|$account_id|$email|$password" >> /tmp/clients_data.txt
}

# Limpar arquivos de dados anteriores
rm -f /tmp/clients_data.txt "$ACCOUNTS_FILE" "$STATS_FILE"

echo "=========================================="
echo "Simulação de $TOTAL_CLIENTS Clientes"
echo "Cada cliente executará $OPERATIONS_PER_CLIENT operações"
echo "=========================================="
echo ""

START_TIME=$(date +%s)

# Executar simulação em paralelo (10 clientes por vez para não sobrecarregar)
for ((i=1; i<=TOTAL_CLIENTS; i++)); do
    simulate_client $i &
    
    # Controlar paralelismo: executar 10 clientes por vez
    if [ $((i % 10)) -eq 0 ]; then
        wait  # Aguardar lote atual terminar
        echo "Lote de 10 clientes concluído..."
    fi
done

# Aguardar todos os processos restantes
wait

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Ler estatísticas finais
SUCCESSFUL_TRANSFERS=$(grep -c "SUCCESS" "$STATS_FILE" 2>/dev/null || echo "0")
FAILED_TRANSFERS=$(grep -c "FAILED" "$STATS_FILE" 2>/dev/null || echo "0")
TOTAL_OPERATIONS=$((SUCCESSFUL_TRANSFERS + FAILED_TRANSFERS))

echo ""
echo "=========================================="
echo "Simulação Concluída!"
echo "=========================================="
echo "Tempo total: ${DURATION}s"
echo "Total de operações: $TOTAL_OPERATIONS"
echo "Transferências bem-sucedidas: $SUCCESSFUL_TRANSFERS"
echo "Transferências com falha: $FAILED_TRANSFERS"
echo ""
echo "Total de contas criadas: $(wc -l < "$ACCOUNTS_FILE")"
echo "Dados dos clientes salvos em: /tmp/clients_data.txt"
echo ""

