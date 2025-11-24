# POC API Bancária Observável

POC completa de uma API Bancária em .NET 8 com foco em **Observabilidade e Logs Estruturados**, utilizando:

- **ASP.NET Core 8** (Minimal API)
- **Serilog** para logging estruturado
- **OpenTelemetry** para telemetria (logs, métricas e traces)
- **OpenTelemetry Collector** recebendo OTLP da API
- **OpenSearch** como destino único de observabilidade
- **OpenSearch Dashboards** para visualização
- **PostgreSQL** como banco de dados
- **Docker Compose** para orquestração local

## 🏗️ Arquitetura

```
┌─────────────┐
│ Banking API │
│  (.NET 8)   │
└──────┬──────┘
       │ OTLP (gRPC)
       ▼
┌──────────────────┐
│ OTEL Collector   │
└──────┬───────────┘
       │
       ▼
┌─────────────┐     ┌──────────────────┐
│  OpenSearch │◄────│ OpenSearch       │
│             │     │ Dashboards       │
└─────────────┘     └──────────────────┘
       ▲
       │
┌─────────────┐
│  PostgreSQL │
└─────────────┘
```

## 📋 Pré-requisitos

- Docker e Docker Compose instalados
- .NET 8 SDK (opcional, apenas para desenvolvimento local)

## 🚀 Como Executar

### 1. Subir o ambiente completo

```bash
docker-compose up -d
```

Este comando irá:
- Criar e iniciar todos os containers (OpenSearch, OpenSearch Dashboards, OTEL Collector, PostgreSQL, Banking API)
- Aplicar migrações do banco de dados automaticamente
- Criar dados de seed (usuário `user@test.com` com 2 contas)

### 2. Verificar se os serviços estão rodando

```bash
docker-compose ps
```

Todos os serviços devem estar com status `Up`.

### 3. Acessar os serviços

- **API Banking**: http://localhost:5000
- **Swagger UI**: http://localhost:5000/swagger
- **OpenSearch Dashboards**: http://localhost:5601
- **OpenSearch API**: http://localhost:9200
- **PostgreSQL**: localhost:5432

## 🧪 Testes da API

### Usando o arquivo curl-tests.http

O arquivo `curl-tests.http` contém uma bateria completa de testes. Você pode:

1. **Usar no VS Code/Cursor**: Instale a extensão "REST Client" e execute os testes diretamente no editor
2. **Copiar e colar no terminal**: Cada bloco pode ser executado via curl

### Testes manuais via curl

#### Health Check
```bash
curl -v http://localhost:5000/ping \
  -H "X-Correlation-Id: test-1" \
  -H "X-Client-Id: test-client"
```

#### Login
```bash
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: login-1" \
  -H "X-Client-Id: test-client" \
  -d '{"email":"user@test.com","password":"123456"}'
```

#### Criar Conta
```bash
curl -X POST http://localhost:5000/accounts \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: create-account-1" \
  -H "X-Client-Id: test-client" \
  -d '{"initialBalance":1000.0}'
```

## 📊 Validação de Observabilidade

### 1. Verificar Logs no OpenSearch Dashboards

1. Acesse http://localhost:5601
2. Vá em **Discover** (ícone de lupa no menu lateral)
3. Selecione o índice `logs-banking-api`
4. Você verá todos os logs estruturados em JSON com campos como:
   - `@timestamp`
   - `level`
   - `message`
   - `correlationId`
   - `clientId`
   - `traceId`
   - `spanId`
   - `endpoint`
   - `httpMethod`
   - `statusCode`

### 2. Verificar Traces no OpenSearch Dashboards

1. Acesse http://localhost:5601
2. Vá em **Discover**
3. Selecione o índice `traces-banking-api`
4. Você verá os traces com spans hierárquicos mostrando:
   - Operações HTTP
   - Operações de banco de dados
   - Correlação via `traceId` e `spanId`

### 3. Verificar Dados no PostgreSQL

```bash
# Conectar ao container PostgreSQL
docker exec -it postgres psql -U banking -d bankingdb

# Listar usuários
SELECT * FROM "Users";

# Listar contas
SELECT * FROM "Accounts";

# Listar transações
SELECT * FROM "Transactions";
```

### 4. Verificar Logs da API

```bash
# Ver logs do container da API
docker logs -f banking-api

# Os logs são exibidos em formato JSON estruturado
```

### 5. Verificar Logs do OTEL Collector

```bash
# Ver logs do collector
docker logs -f otel-collector
```

## 🔍 Endpoints da API

### Health Check
- `GET /ping` - Retorna status da API

### Autenticação
- `POST /auth/login` - Login (retorna token fake)

### Contas
- `POST /accounts` - Criar nova conta
- `GET /accounts/{id}/balance` - Consultar saldo

### Transações
- `POST /transactions` - Realizar transferência
- `GET /accounts/{id}/transactions` - Listar transações (com filtros opcionais de data)

## 📝 Dados de Seed

Ao iniciar a API, os seguintes dados são criados automaticamente:

- **Usuário**:
  - Email: `user@test.com`
  - Senha: `123456`
  - PasswordHash: `fake-hash-123456` (POC apenas)

- **Contas** (2 contas para o usuário seed):
  - Conta A: Saldo R$ 1.000,00
  - Conta B: Saldo R$ 500,00

## 🛠️ Desenvolvimento Local

### Executar a API localmente (sem Docker)

1. Certifique-se de que o PostgreSQL está rodando (via Docker ou localmente)
2. Configure a connection string em `appsettings.json` ou variáveis de ambiente
3. Execute:

```bash
cd BankingApi
dotnet run
```

### Aplicar migrações manualmente

```bash
cd BankingApi
dotnet ef database update
```

### Criar nova migration

```bash
cd BankingApi
dotnet ef migrations add NomeDaMigration
```

## 🐛 Troubleshooting

### API não inicia

1. Verifique se o PostgreSQL está rodando:
   ```bash
   docker-compose ps postgres
   ```

2. Verifique os logs:
   ```bash
   docker logs banking-api
   ```

### OpenSearch não recebe dados

1. Verifique se o OTEL Collector está rodando:
   ```bash
   docker logs otel-collector
   ```

2. Verifique a configuração do `otel-collector.yaml`

3. Verifique se o OpenSearch está acessível:
   ```bash
   curl http://localhost:9200
   ```

### Erro de conexão com PostgreSQL

1. Verifique se o container está rodando:
   ```bash
   docker-compose ps postgres
   ```

2. Verifique a connection string no `docker-compose.yml`

## 📚 Estrutura do Projeto

```
banking-poc/
├── BankingApi/
│   ├── Configuration/     # Extensões Serilog e OpenTelemetry
│   ├── Data/              # DbContext, Migrations, Seed
│   ├── DTOs/              # Data Transfer Objects
│   ├── Endpoints/         # Minimal API Endpoints
│   ├── Middleware/       # CorrelationId e ClientId
│   ├── Models/            # Entidades (User, Account, Transaction)
│   ├── Dockerfile
│   └── Program.cs
├── docker-compose.yml
├── otel-collector.yaml
├── curl-tests.http
└── README.md
```

## 🔐 Observabilidade

### Campos de Log Estruturado

Cada log contém:
- `@timestamp` - Data/hora do evento
- `level` - Nível do log (Information, Warning, Error)
- `message` - Mensagem do log
- `sourceContext` - Contexto da origem
- `traceId` - ID do trace OpenTelemetry
- `spanId` - ID do span atual
- `correlationId` - ID de correlação da requisição
- `clientId` - ID do cliente (se fornecido no header)
- `userId` - ID do usuário (quando aplicável)
- `endpoint` - Endpoint chamado
- `httpMethod` - Método HTTP
- `path` - Caminho da requisição
- `statusCode` - Código de status HTTP
- `durationMs` - Duração da requisição (quando aplicável)

### Headers de Correlação

A API suporta os seguintes headers HTTP:
- `X-Correlation-Id` - ID de correlação (gerado automaticamente se não fornecido)
- `X-Client-Id` - ID do cliente (opcional)

## 📖 Referências

- [Serilog](https://serilog.net/)
- [OpenTelemetry](https://opentelemetry.io/)
- [OpenSearch](https://opensearch.org/)
- [ASP.NET Core Minimal APIs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis)

## 📄 Licença

Este é um projeto de POC para demonstração técnica.
