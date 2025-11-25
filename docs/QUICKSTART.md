# ⚡ Início Rápido

## TL;DR

```bash
docker compose up -d --build
```

**Pronto!** Em 5-10 minutos você terá:
- ✅ API bancária rodando
- ✅ OpenSearch com logs e traces
- ✅ 20 usuários de teste criados
- ✅ 1.000 requests reais executados
- ✅ MCP Servers prontos para uso

## O que acontece automaticamente?

Quando você executa `docker compose up -d --build`, o sistema:

### 1. Sobe a Infraestrutura (2-3 min)
- **PostgreSQL**: Banco de dados relacional
- **OpenSearch**: Armazenamento de logs e traces
- **OpenSearch Dashboards**: Interface de visualização
- **OTEL Collector**: Processador de telemetria

### 2. Sobe a Aplicação (1-2 min)
- **Banking API**: API REST em .NET 8
- **MCP Banking Server**: Interface MCP para a API
- **MCP OpenSearch Server**: Interface MCP para logs/traces

### 3. Executa Inicialização Automática (2-5 min)

O container `environment-init` executa automaticamente:

#### 3.1. Aguarda Serviços
Espera todos os serviços ficarem saudáveis antes de prosseguir.

#### 3.2. Configura OpenSearch Dashboards
- Cria index pattern `logs-banking-api*`
- Cria index pattern `traces-banking-api*`
- Configura timestamp field `@timestamp`

#### 3.3. Gera Massa de Dados Realista

**20 Usuários Criados**:
```
user-1764038725-53123@test.com
user-1764038726-12642@test.com
user-1764038727-60099@test.com
...
(20 usuários no total)
```

Cada usuário recebe:
- Nome único gerado
- Email único com timestamp
- Conta bancária com ID UUID
- Saldo inicial: R$ 1.000,00

**1.000 Operações Executadas**:
- 20 clientes × 50 operações cada = **1.000 requests**
- Tipos de operação:
  - ✅ Transferências bem-sucedidas (~40%)
  - ❌ Saldo insuficiente (~40%)
  - ❌ Conta não encontrada (~20%)

**Por que incluir erros?**
Para gerar logs e traces variados, simulando um ambiente real com:
- Logs de sucesso (Information)
- Logs de aviso (Warning)
- Logs de erro (Error)
- Traces completos com diferentes durações
- Cenários de edge cases

### 4. Resultado Final

Após a inicialização, você terá:

**No OpenSearch**:
- ~1.200 logs indexados
- ~3.500 traces/spans indexados
- Dados prontos para análise

**Na API**:
- 20 usuários ativos
- Centenas de transações registradas
- Histórico completo de operações

**Nos MCP Servers**:
- Ferramentas prontas para uso
- Conexão com API e OpenSearch
- Aguardando comandos da IA

## Verificação Rápida

### 1. Containers Rodando

```bash
docker compose ps
```

**Esperado**:
```
NAME                    STATUS
banking-api             Up (healthy)
postgres                Up (healthy)
opensearch              Up (healthy)
opensearch-dashboards   Up
otel-collector          Up (healthy)
mcp-banking-api         Up
mcp-opensearch          Up
environment-init        Exited (0)  ← Normal! Executa e finaliza
```

### 2. API Funcionando

```bash
curl http://localhost:5001/ping
```

**Esperado**: `{"status":"healthy"}`

### 3. Dados Gerados

```bash
# Contar logs
curl -s http://localhost:9200/logs-banking-api/_count | grep count

# Contar traces
curl -s http://localhost:9200/traces-banking-api/_count | grep count
```

**Esperado**: Mais de 1.000 logs e 3.000 traces

### 4. Visualizar no Dashboard

Abra: http://localhost:5601

1. Vá em **Discover** (menu lateral)
2. Selecione index pattern `logs-banking-api*`
3. Veja os logs em tempo real!

## Primeiros Comandos

### Via MCP (Recomendado)

Após configurar o MCP no Cursor/Claude Desktop:

```
"Liste todos os usuários cadastrados"
"Mostre os logs de erro das últimas 24 horas"
"Qual o saldo do primeiro usuário?"
"Faça uma transferência de R$ 50 entre dois usuários"
```

### Via API REST

```bash
# Listar usuários
curl http://localhost:5001/users

# Consultar saldo
curl http://localhost:5001/accounts/{account-id}/balance

# Fazer transferência
curl -X POST http://localhost:5001/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "fromAccountId": "uuid-1",
    "toAccountId": "uuid-2",
    "amount": 50
  }'
```

## Entendendo os Logs Gerados

### Exemplo de Log de Sucesso

```json
{
  "@timestamp": "2025-11-24T23:45:57.227Z",
  "SeverityText": "Information",
  "Body": "Transfer completed: Amount: 12",
  "TraceId": "b5e21bf030469228f94f471c5cc0e77b",
  "SpanId": "6b0bfb3c5ed7b903",
  "Attributes": {
    "FromAccountId": "414451fb-c8a5-42a7-896e-8829a4cca42d",
    "ToAccountId": "88c813b4-efe1-4fb6-95d3-a026db5e97cf",
    "Amount": 12,
    "TransactionId": "98ff5c6f-8a4a-46ac-b2c0-859fc60353d5",
    "correlationId": "init-20-op-28"
  }
}
```

### Exemplo de Log de Erro

```json
{
  "@timestamp": "2025-11-24T23:45:57.499Z",
  "SeverityText": "Warning",
  "Body": "Insufficient funds: Balance: 22.00, Amount: 8327",
  "TraceId": "0fa7e5bd5520b6bd21162a3b3bb1316e",
  "SpanId": "c4d7a1ce7a7188cf",
  "Attributes": {
    "FromAccountId": "414451fb-c8a5-42a7-896e-8829a4cca42d",
    "Balance": 22,
    "Amount": 8327,
    "correlationId": "init-20-op-50"
  }
}
```

## Estatísticas da Simulação

Após a inicialização, você pode ver o resumo:

```bash
docker logs environment-init --tail 20
```

**Saída esperada**:
```
[INFO] ==========================================
[OK] SIMULAÇÃO CONCLUÍDA!
[INFO] ==========================================
[INFO] Contas criadas: 20
[INFO] Total de operações: 1000
[INFO] Transferências OK: 404
[INFO] Transferências com erro: 596
[INFO] ==========================================
[INFO] FASE 4: Verificando dados no OpenSearch
[INFO] ==========================================
[OK] Logs indexados: 1171
[OK] Traces indexados: 3440
[INFO] ==========================================
[OK] AMBIENTE 100% CONFIGURADO E PRONTO!
```

## Ajustar Quantidade de Dados

Se quiser gerar mais ou menos dados, edite `init-and-test.sh`:

```bash
# Configurações da simulação
TOTAL_CLIENTS=20        # Número de usuários
OPERATIONS_PER_CLIENT=50  # Operações por usuário
```

**Exemplos**:
- `TOTAL_CLIENTS=10, OPERATIONS_PER_CLIENT=10` = 100 requests
- `TOTAL_CLIENTS=50, OPERATIONS_PER_CLIENT=20` = 1.000 requests
- `TOTAL_CLIENTS=100, OPERATIONS_PER_CLIENT=50` = 5.000 requests

Após editar, reinicie:
```bash
docker compose restart environment-init
```

## Re-executar Simulação

Para gerar novos dados sem recriar tudo:

```bash
docker compose restart environment-init
```

Isso irá:
- Criar 20 novos usuários
- Executar mais 1.000 operações
- Adicionar mais logs e traces

## Limpar e Recomeçar

Para começar do zero:

```bash
# Para e remove tudo (incluindo dados)
docker compose down -v

# Sobe novamente
docker compose up -d --build
```

**⚠️ Atenção**: Isso apaga todos os dados (usuários, transações, logs, traces)

## Próximos Passos

Agora que o ambiente está rodando:

1. **Configure os MCP Servers**
   - Veja [SETUP.md](SETUP.md) para instruções detalhadas
   - Configure Cursor ou Claude Desktop
   - Teste com comandos em linguagem natural

2. **Explore os Dados**
   - Acesse OpenSearch Dashboards: http://localhost:5601
   - Navegue pelos logs e traces
   - Crie visualizações customizadas

3. **Teste a API**
   - Acesse Swagger: http://localhost:5001/swagger
   - Teste os endpoints manualmente
   - Veja a documentação interativa

4. **Use com IA**
   - Peça para a IA criar novos usuários
   - Analise logs de erro
   - Investigue traces de performance
   - Automatize testes

## Troubleshooting Rápido

### "Container não inicia"
```bash
docker compose logs <service-name>
```

### "Porta já em uso"
Edite `docker-compose.yml` e altere a porta:
```yaml
ports:
  - "8080:80"  # Altere 5001 para 8080
```

### "Simulação não executou"
```bash
# Ver logs da simulação
docker logs environment-init

# Re-executar
docker compose restart environment-init
```

### "Sem dados no OpenSearch"
```bash
# Verificar OTEL Collector
docker logs otel-collector

# Verificar índices
curl http://localhost:9200/_cat/indices?v
```

## Recursos

- **API Swagger**: http://localhost:5001/swagger
- **OpenSearch Dashboards**: http://localhost:5601
- **OpenSearch API**: http://localhost:9200
- **Health Check**: http://localhost:5001/ping

## Documentação Completa

- 📖 [SETUP.md](SETUP.md) - Instalação detalhada
- 🏗️ [ARCHITECTURE.md](ARCHITECTURE.md) - Arquitetura do sistema
- 🤖 [MCP_SERVERS.md](MCP_SERVERS.md) - Guia dos MCP Servers
- 📚 [USAGE.md](USAGE.md) - Exemplos de uso
- 🐛 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Resolução de problemas

---

**Dica**: Mantenha o terminal aberto durante o primeiro `docker compose up` para acompanhar o progresso da inicialização!

