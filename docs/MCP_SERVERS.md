# 🤖 MCP Servers - Guia Completo

## O que é MCP?

**Model Context Protocol (MCP)** é um protocolo aberto que permite que assistentes de IA (como Claude, Cursor, etc.) se conectem a ferramentas e fontes de dados externas de forma padronizada.

## Arquitetura MCP

```mermaid
graph LR
    AI[Assistente IA] <-->|stdio| MCP[MCP Server]
    MCP <-->|HTTP/REST| Service[Serviço Externo]
```

### Componentes

1. **Cliente MCP**: Assistente de IA (Cursor, Claude Desktop)
2. **Servidor MCP**: Aplicação que expõe ferramentas
3. **Transporte**: stdio (stdin/stdout)
4. **Protocolo**: JSON-RPC 2.0

## MCP Banking API Server

### Visão Geral

Expõe as operações da Banking API como ferramentas MCP, permitindo que assistentes de IA executem operações bancárias através de comandos em linguagem natural.

### Localização

```
mcp-banking-api/
├── server.py           # Implementação do servidor
├── requirements.txt    # Dependências Python
├── Dockerfile         # Container Docker
└── README.md          # Documentação específica
```

### Ferramentas Disponíveis

#### 1. create_user

**Descrição**: Cria um novo usuário e conta bancária

**Parâmetros**:
```json
{
  "name": "string (obrigatório)",
  "email": "string (obrigatório)",
  "initial_balance": "number (opcional, padrão: 1000)"
}
```

**Exemplo de Uso**:
```
"Crie um usuário chamado Maria Silva com email maria@test.com e saldo inicial de R$ 500"
```

**Resposta**:
```json
{
  "user_id": "uuid",
  "account_id": "uuid",
  "name": "Maria Silva",
  "email": "maria@test.com",
  "balance": 500.00
}
```

#### 2. list_users

**Descrição**: Lista todos os usuários cadastrados

**Parâmetros**: Nenhum

**Exemplo de Uso**:
```
"Liste todos os usuários cadastrados"
```

**Resposta**:
```json
[
  {
    "id": "uuid",
    "name": "Maria Silva",
    "email": "maria@test.com",
    "account_id": "uuid"
  }
]
```

#### 3. get_balance

**Descrição**: Consulta o saldo de uma conta

**Parâmetros**:
```json
{
  "account_id": "string (obrigatório)"
}
```

**Exemplo de Uso**:
```
"Qual o saldo da conta abc-123?"
```

**Resposta**:
```json
{
  "account_id": "abc-123",
  "balance": 1500.00,
  "currency": "BRL"
}
```

#### 4. transfer_funds

**Descrição**: Realiza transferência entre contas

**Parâmetros**:
```json
{
  "from_account_id": "string (obrigatório)",
  "to_account_id": "string (obrigatório)",
  "amount": "number (obrigatório)"
}
```

**Exemplo de Uso**:
```
"Transfira R$ 100 da conta abc-123 para a conta def-456"
```

**Resposta**:
```json
{
  "transaction_id": "uuid",
  "from_account_id": "abc-123",
  "to_account_id": "def-456",
  "amount": 100.00,
  "timestamp": "2025-11-24T23:45:57Z",
  "status": "completed"
}
```

#### 5. list_transactions

**Descrição**: Lista transações de uma conta

**Parâmetros**:
```json
{
  "account_id": "string (obrigatório)",
  "limit": "number (opcional, padrão: 10)"
}
```

**Exemplo de Uso**:
```
"Mostre as últimas 5 transações da conta abc-123"
```

**Resposta**:
```json
[
  {
    "id": "uuid",
    "from_account_id": "abc-123",
    "to_account_id": "def-456",
    "amount": 100.00,
    "timestamp": "2025-11-24T23:45:57Z",
    "type": "transfer"
  }
]
```

### Configuração

#### Variáveis de Ambiente

```env
BANKING_API_URL=http://banking-api:80
HTTP_TIMEOUT=30
```

#### Arquivo de Configuração (Cursor)

`~/.cursor/mcp_config.json`:
```json
{
  "mcpServers": {
    "banking-api": {
      "command": "docker",
      "args": ["exec", "-i", "mcp-banking-api", "python", "server.py"]
    }
  }
}
```

#### Arquivo de Configuração (Claude Desktop)

macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "banking-api": {
      "command": "docker",
      "args": ["exec", "-i", "mcp-banking-api", "python", "server.py"]
    }
  }
}
```

## MCP OpenSearch Server

### Visão Geral

Permite consultar logs e traces no OpenSearch através de comandos em linguagem natural, facilitando debugging e análise de observabilidade.

### Localização

```
mcp-opensearch/
├── server.py           # Implementação do servidor
├── requirements.txt    # Dependências Python
├── Dockerfile         # Container Docker
└── README.md          # Documentação específica
```

### Ferramentas Disponíveis

#### 1. search_logs

**Descrição**: Busca logs com filtros avançados

**Parâmetros**:
```json
{
  "query": "string (opcional)",
  "severity": "string (opcional: Information, Warning, Error)",
  "start_time": "string ISO 8601 (opcional)",
  "end_time": "string ISO 8601 (opcional)",
  "size": "number (opcional, padrão: 100)"
}
```

**Exemplo de Uso**:
```
"Mostre os logs de erro das últimas 2 horas"
"Busque logs contendo 'transfer' com severidade Warning"
```

**Resposta**:
```json
{
  "total": 50,
  "logs": [
    {
      "timestamp": "2025-11-24T23:45:57Z",
      "severity": "Error",
      "message": "Transfer failed",
      "trace_id": "abc123",
      "span_id": "def456",
      "attributes": {
        "account_id": "xyz",
        "amount": 100
      }
    }
  ]
}
```

#### 2. search_traces

**Descrição**: Busca traces e spans

**Parâmetros**:
```json
{
  "trace_id": "string (opcional)",
  "span_id": "string (opcional)",
  "start_time": "string ISO 8601 (opcional)",
  "end_time": "string ISO 8601 (opcional)",
  "size": "number (opcional, padrão: 100)"
}
```

**Exemplo de Uso**:
```
"Mostre o trace completo do ID abc123"
"Liste todos os spans das últimas 30 minutos"
```

#### 3. get_log_by_id

**Descrição**: Obtém log específico por ID

**Parâmetros**:
```json
{
  "log_id": "string (obrigatório)"
}
```

#### 4. get_trace_by_id

**Descrição**: Obtém trace completo com todos os spans

**Parâmetros**:
```json
{
  "trace_id": "string (obrigatório)"
}
```

#### 5. aggregate_logs

**Descrição**: Agregações e estatísticas de logs

**Parâmetros**:
```json
{
  "field": "string (obrigatório)",
  "interval": "string (opcional: minute, hour, day)"
}
```

**Exemplo de Uso**:
```
"Agrupe logs por severidade"
"Mostre a distribuição de logs por hora"
```

### Configuração

#### Variáveis de Ambiente

```env
OPENSEARCH_URL=http://opensearch:9200
OPENSEARCH_USERNAME=
OPENSEARCH_PASSWORD=
LOGS_INDEX=logs-banking-api
TRACES_INDEX=traces-banking-api
```

#### Arquivo de Configuração (Cursor)

`~/.cursor/mcp_config.json`:
```json
{
  "mcpServers": {
    "opensearch": {
      "command": "docker",
      "args": ["exec", "-i", "mcp-opensearch", "python", "server.py"]
    }
  }
}
```

## Exemplos de Uso Combinado

### Cenário 1: Criar Usuário e Verificar Logs

```
1. "Crie um usuário chamado João com email joao@test.com"
2. "Mostre os logs relacionados à criação desse usuário"
3. "Há algum erro nos logs?"
```

### Cenário 2: Transferência e Análise de Trace

```
1. "Liste os usuários disponíveis"
2. "Faça uma transferência de R$ 50 do primeiro para o segundo usuário"
3. "Mostre o trace completo dessa transferência"
4. "Qual foi a latência da operação?"
```

### Cenário 3: Debugging de Erro

```
1. "Mostre os logs de erro das últimas 24 horas"
2. "Qual é o erro mais frequente?"
3. "Mostre o trace completo do primeiro erro"
4. "Qual endpoint está causando esse erro?"
```

## Troubleshooting

### MCP Server não responde

```bash
# Verificar se o container está rodando
docker ps | grep mcp

# Ver logs do container
docker logs mcp-banking-api
docker logs mcp-opensearch

# Testar manualmente
docker exec -i mcp-banking-api python server.py
```

### Erro de conexão com serviços

```bash
# Verificar rede Docker
docker network inspect banking-network

# Testar conectividade
docker exec mcp-banking-api curl http://banking-api:80/ping
docker exec mcp-opensearch curl http://opensearch:9200/_cluster/health
```

### Reiniciar MCP Servers

```bash
docker compose restart mcp-banking-api mcp-opensearch
```

## Desenvolvimento

### Adicionar Nova Ferramenta

1. Edite `server.py` no MCP Server correspondente
2. Defina a ferramenta com `@server.call_tool()`
3. Implemente a lógica de integração
4. Adicione documentação no docstring
5. Reconstrua o container: `docker compose up -d --build`

### Exemplo de Nova Ferramenta

```python
@server.call_tool()
async def get_user_by_email(email: str) -> str:
    """
    Get user details by email address
    
    Args:
        email: User's email address
    """
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{BANKING_API_URL}/users",
            params={"email": email}
        )
        return response.text
```

## Boas Práticas

1. **Validação de Entrada**: Sempre valide parâmetros antes de fazer chamadas
2. **Tratamento de Erros**: Retorne mensagens de erro claras e acionáveis
3. **Timeouts**: Configure timeouts adequados para evitar travamentos
4. **Logging**: Registre todas as operações para debugging
5. **Documentação**: Mantenha docstrings atualizadas para cada ferramenta

## Limitações Conhecidas

- MCP Servers não suportam autenticação (ambiente local)
- Comunicação via stdio (não adequado para produção distribuída)
- Sem rate limiting (pode sobrecarregar serviços)
- Sem cache (cada consulta vai ao serviço de origem)

## Próximos Passos

- [ ] Adicionar autenticação JWT
- [ ] Implementar cache de respostas
- [ ] Adicionar rate limiting
- [ ] Suporte a webhooks para notificações
- [ ] Métricas de uso dos MCP Servers

