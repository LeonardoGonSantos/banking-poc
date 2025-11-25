# 📖 Guia de Uso

Este documento contém exemplos práticos de como usar a POC, tanto através dos MCP Servers quanto manualmente via API.

## Usando MCP Servers (Recomendado)

### Pré-requisitos

- Cursor ou Claude Desktop instalado e configurado
- MCP Servers configurados (veja [SETUP.md](SETUP.md))
- Ambiente Docker rodando

## Casos de Uso Comuns

### 1. Gerenciamento de Usuários

#### Criar Novo Usuário

**Comando em Linguagem Natural**:
```
"Crie um usuário chamado Ana Costa com email ana@example.com e saldo inicial de R$ 2000"
```

**Resultado Esperado**:
```
Usuário criado com sucesso!
- ID: 123e4567-e89b-12d3-a456-426614174000
- Nome: Ana Costa
- Email: ana@example.com
- Conta ID: 987fcdeb-51a2-43f8-b123-456789abcdef
- Saldo: R$ 2.000,00
```

#### Listar Todos os Usuários

**Comando**:
```
"Liste todos os usuários cadastrados"
```

**Resultado**:
```
Encontrados 21 usuários:
1. Ana Costa (ana@example.com) - Conta: 987fcdeb...
2. João Silva (joao@test.com) - Conta: abc123...
...
```

#### Consultar Saldo

**Comando**:
```
"Qual o saldo da conta 987fcdeb-51a2-43f8-b123-456789abcdef?"
```

**Resultado**:
```
Saldo da conta 987fcdeb-51a2-43f8-b123-456789abcdef:
R$ 2.000,00
```

### 2. Operações Bancárias

#### Realizar Transferência

**Comando**:
```
"Transfira R$ 150 da conta de Ana Costa para a conta de João Silva"
```

**Resultado**:
```
Transferência realizada com sucesso!
- ID da Transação: abc-def-123
- De: 987fcdeb... (Ana Costa)
- Para: abc123... (João Silva)
- Valor: R$ 150,00
- Data: 2025-11-24 23:45:57
- Status: Concluída
```

#### Listar Transações

**Comando**:
```
"Mostre as últimas 5 transações da conta de Ana Costa"
```

**Resultado**:
```
Últimas 5 transações da conta 987fcdeb...:

1. [2025-11-24 23:45:57] Transferência enviada
   Para: abc123... (João Silva)
   Valor: -R$ 150,00
   
2. [2025-11-24 23:40:12] Transferência recebida
   De: def456... (Maria Santos)
   Valor: +R$ 50,00
...
```

### 3. Análise de Logs

#### Buscar Logs de Erro

**Comando**:
```
"Mostre os logs de erro das últimas 2 horas"
```

**Resultado**:
```
Encontrados 15 logs de erro nas últimas 2 horas:

1. [23:45:57] ERROR - Insufficient funds
   Conta: 987fcdeb...
   Saldo: R$ 50,00
   Tentativa: R$ 200,00
   TraceId: abc123...
   
2. [23:40:12] ERROR - Account not found
   Conta solicitada: invalid-id
   TraceId: def456...
...
```

#### Buscar Logs por Texto

**Comando**:
```
"Busque logs contendo 'transfer' com severidade Warning"
```

**Resultado**:
```
Encontrados 8 logs com 'transfer' e severidade Warning:

1. [23:45:57] WARNING - Transfer amount exceeds daily limit
   Conta: 987fcdeb...
   Valor: R$ 5.000,00
   Limite: R$ 3.000,00
...
```

#### Analisar Trace Específico

**Comando**:
```
"Mostre o trace completo do ID abc123def456"
```

**Resultado**:
```
Trace abc123def456:
Duração total: 245ms

Spans:
1. POST /transactions (200ms)
   └─ 2. TransferFunds (180ms)
      ├─ 3. GetAccount (from) (40ms)
      │  └─ 4. PostgreSQL Query (35ms)
      ├─ 5. GetAccount (to) (38ms)
      │  └─ 6. PostgreSQL Query (33ms)
      └─ 7. CreateTransaction (95ms)
         └─ 8. PostgreSQL Insert (90ms)
```

### 4. Análise e Debugging

#### Identificar Problemas

**Comando**:
```
"Quais são os erros mais frequentes nas últimas 24 horas?"
```

**Resultado**:
```
Top 3 erros nas últimas 24 horas:

1. "Insufficient funds" - 450 ocorrências (60%)
2. "Account not found" - 200 ocorrências (26%)
3. "Invalid amount" - 100 ocorrências (14%)

Recomendação: Revisar validação de saldo antes de transferências
```

#### Analisar Performance

**Comando**:
```
"Quais endpoints estão mais lentos?"
```

**Resultado**:
```
Análise de performance (últimas 24h):

1. POST /transactions
   - Média: 245ms
   - P95: 450ms
   - P99: 780ms
   - Total: 1.000 requests
   
2. GET /accounts/{id}/transactions
   - Média: 120ms
   - P95: 200ms
   - P99: 350ms
   - Total: 500 requests

Recomendação: Otimizar queries do PostgreSQL em /transactions
```

#### Correlacionar Logs e Traces

**Comando**:
```
"Mostre todos os logs relacionados ao trace abc123def456"
```

**Resultado**:
```
Logs correlacionados com trace abc123def456:

1. [23:45:57.123] INFO - Transfer initiated
   Span: POST /transactions
   
2. [23:45:57.234] INFO - Account validated
   Span: GetAccount (from)
   
3. [23:45:57.345] WARNING - Balance check
   Span: TransferFunds
   Saldo: R$ 50,00, Necessário: R$ 200,00
   
4. [23:45:57.456] ERROR - Insufficient funds
   Span: TransferFunds
```

## Uso Manual via API REST

### Criar Usuário

```bash
curl -X POST http://localhost:5001/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Ana Costa",
    "email": "ana@example.com",
    "initialBalance": 2000
  }'
```

**Resposta**:
```json
{
  "userId": "123e4567-e89b-12d3-a456-426614174000",
  "accountId": "987fcdeb-51a2-43f8-b123-456789abcdef",
  "name": "Ana Costa",
  "email": "ana@example.com",
  "balance": 2000.00
}
```

### Listar Usuários

```bash
curl http://localhost:5001/users
```

### Consultar Saldo

```bash
curl http://localhost:5001/accounts/987fcdeb-51a2-43f8-b123-456789abcdef/balance
```

### Realizar Transferência

```bash
curl -X POST http://localhost:5001/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "fromAccountId": "987fcdeb-51a2-43f8-b123-456789abcdef",
    "toAccountId": "abc123-def456-789",
    "amount": 150
  }'
```

### Listar Transações

```bash
curl http://localhost:5001/accounts/987fcdeb-51a2-43f8-b123-456789abcdef/transactions?limit=5
```

## Consultas Diretas ao OpenSearch

### Buscar Logs

```bash
curl -X POST http://localhost:9200/logs-banking-api/_search \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "match": { "SeverityText": "Error" } },
          { "range": { "@timestamp": { "gte": "now-2h" } } }
        ]
      }
    },
    "size": 100,
    "sort": [{ "@timestamp": "desc" }]
  }'
```

### Buscar Traces

```bash
curl -X POST http://localhost:9200/traces-banking-api/_search \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "match": { "TraceId": "abc123def456" }
    }
  }'
```

### Agregação de Logs por Severidade

```bash
curl -X POST http://localhost:9200/logs-banking-api/_search \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "aggs": {
      "by_severity": {
        "terms": { "field": "SeverityText.keyword" }
      }
    }
  }'
```

## Fluxos de Trabalho Completos

### Fluxo 1: Onboarding de Cliente

```
1. "Crie um usuário chamado Pedro Santos com email pedro@example.com"
2. "Consulte o saldo da conta do Pedro"
3. "Mostre os logs da criação desse usuário"
4. "Há algum erro nos logs?"
```

### Fluxo 2: Transferência com Validação

```
1. "Liste os usuários disponíveis"
2. "Qual o saldo do primeiro usuário?"
3. "Transfira R$ 100 do primeiro para o segundo usuário"
4. "Mostre o trace dessa transferência"
5. "Confirme os novos saldos"
```

### Fluxo 3: Investigação de Erro

```
1. "Mostre os logs de erro das últimas 24 horas"
2. "Qual é o erro mais frequente?"
3. "Mostre detalhes do primeiro erro"
4. "Mostre o trace completo desse erro"
5. "Quais contas estão envolvidas?"
```

### Fluxo 4: Análise de Performance

```
1. "Quais endpoints estão mais lentos?"
2. "Mostre traces do endpoint mais lento"
3. "Qual span está causando a latência?"
4. "Mostre logs relacionados a esse span"
5. "Há queries SQL lentas?"
```

## Dicas e Boas Práticas

### Para Comandos MCP

1. **Seja específico**: "Transfira R$ 100 da conta X para Y" é melhor que "Faça uma transferência"
2. **Use contexto**: Referencie resultados anteriores: "Mostre o trace dessa última operação"
3. **Combine ferramentas**: Use Banking API + OpenSearch para análise completa
4. **Peça análises**: "Qual o padrão nos erros?" em vez de apenas "Mostre erros"

### Para Debugging

1. **Comece amplo**: "Mostre logs de erro" → depois filtre
2. **Use correlação**: Sempre correlacione logs com traces usando TraceId
3. **Analise timing**: Verifique timestamps para entender sequência de eventos
4. **Verifique contexto**: Attributes contêm informações valiosas

### Para Performance

1. **Use agregações**: Para análises estatísticas
2. **Limite resultados**: Especifique `limit` para evitar sobrecarga
3. **Filtre por tempo**: Sempre use range de tempo em consultas
4. **Cache local**: Assistente IA pode cachear resultados recentes

## Limitações

### MCP Servers

- Não suportam operações em lote
- Sem suporte a transações distribuídas
- Rate limiting não implementado
- Sem autenticação (ambiente local apenas)

### API

- Sem autenticação/autorização
- Sem validação de CPF/CNPJ
- Limites de transferência não implementados
- Sem suporte a agendamento

### OpenSearch

- Sem autenticação configurada
- Retenção de dados ilimitada
- Sem backup automático
- Performance não otimizada para produção

## Próximos Passos

- 📖 Veja [ARCHITECTURE.md](ARCHITECTURE.md) para entender a arquitetura
- 🔧 Consulte [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para resolver problemas
- 🚀 Leia [DEVELOPMENT.md](DEVELOPMENT.md) para contribuir com o projeto

