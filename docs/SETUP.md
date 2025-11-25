# 🚀 Guia de Setup e Instalação

## Pré-requisitos

### Software Necessário

- **Docker**: versão 20.10 ou superior
- **Docker Compose**: versão 2.0 ou superior
- **Git**: para clonar o repositório
- **Cursor** ou **Claude Desktop**: para usar os MCP Servers

### Verificar Instalação

```bash
docker --version
docker compose version
git --version
```

### Recursos de Sistema

- **RAM**: Mínimo 8GB (recomendado 16GB)
- **Disco**: 10GB livres
- **CPU**: 4 cores (recomendado)

## Instalação Rápida

### 1. Clonar o Repositório

```bash
git clone <repository-url>
cd banking-poc
```

### 2. Iniciar o Ambiente

```bash
docker compose up -d --build
```

Este comando irá:
- ✅ Baixar todas as imagens Docker necessárias
- ✅ Construir as imagens customizadas (Banking API, MCP Servers)
- ✅ Criar a rede `banking-network`
- ✅ Iniciar todos os containers
- ✅ Executar migrações do banco de dados
- ✅ Configurar OpenSearch Dashboards
- ✅ Gerar 1.000 requests de teste

**⏱️ Tempo estimado**: 5-10 minutos (primeira execução)

### 3. Verificar Status

```bash
docker compose ps
```

**Saída esperada**:
```
NAME                    STATUS
banking-api             Up (healthy)
postgres                Up (healthy)
opensearch              Up (healthy)
opensearch-dashboards   Up
otel-collector          Up (healthy)
mcp-banking-api         Up
mcp-opensearch          Up
environment-init        Exited (0)
```

### 4. Acessar Serviços

- **API Swagger**: http://localhost:5001/swagger
- **OpenSearch Dashboards**: http://localhost:5601
- **API Health**: http://localhost:5001/ping

## Configuração dos MCP Servers

### Para Cursor

1. Localize o arquivo de configuração:
   ```bash
   # macOS/Linux
   ~/.cursor/mcp_config.json
   
   # Windows
   %USERPROFILE%\.cursor\mcp_config.json
   ```

2. Adicione a configuração:
   ```json
   {
     "mcpServers": {
       "banking-api": {
         "command": "docker",
         "args": ["exec", "-i", "mcp-banking-api", "python", "server.py"]
       },
       "opensearch": {
         "command": "docker",
         "args": ["exec", "-i", "mcp-opensearch", "python", "server.py"]
       }
     }
   }
   ```

3. Reinicie o Cursor

### Para Claude Desktop

1. Localize o arquivo de configuração:
   ```bash
   # macOS
   ~/Library/Application Support/Claude/claude_desktop_config.json
   
   # Windows
   %APPDATA%\Claude\claude_desktop_config.json
   
   # Linux
   ~/.config/Claude/claude_desktop_config.json
   ```

2. Adicione a configuração:
   ```json
   {
     "mcpServers": {
       "banking-api": {
         "command": "docker",
         "args": ["exec", "-i", "mcp-banking-api", "python", "server.py"]
       },
       "opensearch": {
         "command": "docker",
         "args": ["exec", "-i", "mcp-opensearch", "python", "server.py"]
       }
     }
   }
   ```

3. Reinicie o Claude Desktop

### Verificar Conexão MCP

No Cursor ou Claude Desktop, teste:
```
"Liste todos os usuários cadastrados"
```

Se funcionar, os MCP Servers estão configurados corretamente! ✅

## Configuração Avançada

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```env
# Banking API
ASPNETCORE_ENVIRONMENT=Development
DATABASE_CONNECTION_STRING=Host=postgres;Database=banking;Username=postgres;Password=postgres

# OpenSearch
OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
DISABLE_SECURITY_PLUGIN=true

# OTEL Collector
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317

# MCP Servers
BANKING_API_URL=http://banking-api:80
OPENSEARCH_URL=http://opensearch:9200
HTTP_TIMEOUT=30
```

### Ajustar Recursos

Edite `docker-compose.yml` para ajustar limites:

```yaml
services:
  opensearch:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

### Portas Customizadas

Para alterar portas expostas, edite `docker-compose.yml`:

```yaml
services:
  banking-api:
    ports:
      - "8080:80"  # Altere 5001 para 8080
```

## Validação da Instalação

### 1. Testar API

```bash
# Health check
curl http://localhost:5001/ping

# Criar usuário
curl -X POST http://localhost:5001/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "initialBalance": 1000
  }'
```

### 2. Verificar Logs no OpenSearch

```bash
# Contar logs
curl http://localhost:9200/logs-banking-api/_count

# Contar traces
curl http://localhost:9200/traces-banking-api/_count
```

### 3. Testar MCP Servers

```bash
# Testar MCP Banking API
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | \
  docker exec -i mcp-banking-api python server.py

# Testar MCP OpenSearch
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | \
  docker exec -i mcp-opensearch python server.py
```

## Dados de Teste

### Usuários Pré-criados

O script de inicialização cria 20 usuários:
- Emails: `user-{timestamp}-{random}@test.com`
- Saldo inicial: R$ 1.000,00

### Transações Geradas

- Total: 1.000 operações
- Sucessos: ~40%
- Falhas: ~60% (saldo insuficiente, conta não encontrada)

### Consultar Dados

```bash
# Listar usuários via API
curl http://localhost:5001/users

# Listar via MCP (no Cursor/Claude)
"Liste todos os usuários cadastrados"
```

## Troubleshooting

### Container não inicia

```bash
# Ver logs detalhados
docker compose logs <service-name>

# Exemplos
docker compose logs banking-api
docker compose logs opensearch
```

### Porta já em uso

```bash
# Verificar processos usando a porta
lsof -i :5001  # macOS/Linux
netstat -ano | findstr :5001  # Windows

# Parar processo ou alterar porta no docker-compose.yml
```

### OpenSearch não responde

```bash
# Verificar saúde do cluster
curl http://localhost:9200/_cluster/health

# Aumentar memória (edite docker-compose.yml)
OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
```

### Logs não aparecem

```bash
# Verificar OTEL Collector
docker logs otel-collector

# Verificar índices
curl http://localhost:9200/_cat/indices?v

# Reenviar dados
docker compose restart banking-api
```

### MCP Server não conecta

```bash
# Verificar containers
docker ps | grep mcp

# Testar manualmente
docker exec -i mcp-banking-api python server.py

# Ver logs
docker logs mcp-banking-api
docker logs mcp-opensearch

# Reconstruir
docker compose up -d --build mcp-banking-api mcp-opensearch
```

## Comandos Úteis

### Parar Ambiente

```bash
docker compose down
```

### Parar e Remover Volumes

```bash
docker compose down -v
```

### Reconstruir Tudo

```bash
docker compose down -v
docker compose up -d --build
```

### Ver Logs em Tempo Real

```bash
docker compose logs -f banking-api
```

### Executar Comando em Container

```bash
docker exec -it banking-api bash
```

### Limpar Sistema Docker

```bash
# Remover containers parados
docker container prune

# Remover imagens não utilizadas
docker image prune

# Limpar tudo (CUIDADO!)
docker system prune -a --volumes
```

## Atualização

### Atualizar Código

```bash
git pull origin main
docker compose up -d --build
```

### Atualizar Apenas um Serviço

```bash
docker compose up -d --build banking-api
```

### Migração de Banco de Dados

As migrações são executadas automaticamente no startup da API. Para executar manualmente:

```bash
docker exec -it banking-api dotnet ef database update
```

## Backup e Restore

### Backup do PostgreSQL

```bash
docker exec postgres pg_dump -U postgres banking > backup.sql
```

### Restore do PostgreSQL

```bash
cat backup.sql | docker exec -i postgres psql -U postgres banking
```

### Backup do OpenSearch

```bash
# Criar snapshot repository
curl -X PUT "http://localhost:9200/_snapshot/backup" \
  -H "Content-Type: application/json" \
  -d '{"type":"fs","settings":{"location":"/backup"}}'

# Criar snapshot
curl -X PUT "http://localhost:9200/_snapshot/backup/snapshot_1"
```

## Próximos Passos

Após a instalação bem-sucedida:

1. 📖 Leia [MCP_SERVERS.md](MCP_SERVERS.md) para entender as ferramentas disponíveis
2. 🏗️ Consulte [ARCHITECTURE.md](ARCHITECTURE.md) para entender a arquitetura
3. 🧪 Veja [USAGE.md](USAGE.md) para exemplos de uso
4. 🐛 Confira [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para problemas comuns

