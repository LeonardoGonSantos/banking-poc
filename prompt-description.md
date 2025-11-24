Quero que você crie um projeto de POC completo em .NET para uma **API Bancária** com foco em **OBSERVABILIDADE e LOGS ESTRUTURADOS**, com a seguinte arquitetura:

- API REST bancária em ASP.NET Core
- Logging principal com **Serilog**
- Telemetria (**logs, métricas e traces**) via **OpenTelemetry**
- **OpenTelemetry Collector** recebendo OTLP da API
- **OpenSearch** como único destino de observabilidade (logs, traces, métricas) – sem Data Prepper
- **OpenSearch Dashboards** para visualizar tudo
- **MCP (Model Context Protocol)** ativado no OpenSearch para que uma IA (ex: Cursor, Claude) consiga consultar os dados
- **PostgreSQL** como banco de dados da API Bancária
- Ambiente local orquestrado com **Docker Compose**

O foco é ser **didático, simples e demonstrável**, mas tecnicamente consistente para uma POC que será apresentada para time técnico.

---

## 1️⃣ Estrutura de Domínio da API Bancária

Use ASP.NET Core 8 (minimal API ou controllers, o que for mais limpo) com a seguinte estrutura lógica:

### Entidades (Models)

- `User`
  - `Id` (GUID)
  - `Name`
  - `Email`
  - `PasswordHash`

- `Account`
  - `Id` (GUID)
  - `UserId` (FK para `User`)
  - `Balance` (decimal)
  - `CreatedAt` (DateTime)

- `Transaction`
  - `Id` (GUID)
  - `FromAccountId` (FK)
  - `ToAccountId` (FK)
  - `Amount` (decimal)
  - `CreatedAt` (DateTime)
  - `Type` (string: `"CREDIT"`, `"DEBIT"`, `"TRANSFER"`)

### Banco de Dados – PostgreSQL

- Use **PostgreSQL** como banco de dados da API.
- Crie um container `postgres` no `docker-compose` com:
  - imagem `postgres:16`
  - usuário, senha e database via environment:
    - `POSTGRES_USER=banking`
    - `POSTGRES_PASSWORD=banking_pwd`
    - `POSTGRES_DB=bankingdb`
- A API deve se conectar ao Postgres via connection string (por ex.):
  - `Host=postgres;Port=5432;Database=bankingdb;Username=banking;Password=banking_pwd`
- Use **Entity Framework Core** com:
  - `Microsoft.EntityFrameworkCore`
  - `Microsoft.EntityFrameworkCore.Design`
  - `Npgsql.EntityFrameworkCore.PostgreSQL`
- Configure um contexto `BankingDbContext` com `DbSet<User>`, `DbSet<Account>`, `DbSet<Transaction>`.
- Ao subir a API, aplique migrações automaticamente (criação de tabelas).
- Faça um **seed inicial**:
  - 1 usuário (`user@test.com`, senha "123456" com hash fake).
  - 2 contas para esse usuário:
    - Conta A: saldo 1000.00
    - Conta B: saldo 500.00

---

## 2️⃣ Fluxos de Negócio (Endpoints REST)

Implemente os seguintes endpoints com regras mínimas de negócio **e já instrumentados com logs e traces**:

1. `GET /ping`
   - Retorna `{ "status": "ok" }`.
   - Usa log `Information` com tipo `"health_check"`.

2. `POST /auth/login`
   - Body: `{ "email": "...", "password": "..." }`.
   - Se email/senha corresponderem ao usuário seed: retorna token fake `{ "token": "fake-jwt-or-guid" }`.
   - Se inválido: retorna **401** com `{ "error": "Invalid credentials" }`.
   - Logs:
     - `Information` para sucesso (sem logar senha).
     - `Warning` para credenciais inválidas.
   - Trace: span `"AuthLogin"`.

3. `POST /accounts`
   - Cria uma nova conta para o usuário autenticado (simulação: assuma sempre o usuário seed).
   - Body: `{ "initialBalance": 1000.0 }`.
   - Retorno: `{ "accountId": "...", "balance": 1000.0 }`.
   - Logs:
     - `Information` com `accountId`, `userId`, `initialBalance`.
   - Trace: span `"CreateAccount"`.

4. `GET /accounts/{id}/balance`
   - Retorna saldo atual.
   - 404 se conta não existir.
   - Métrica: contador de chamadas para `GetBalance`.
   - Trace: span `"GetBalance"`.

5. `POST /transactions`
   - Body: `{ "fromAccountId": "...", "toAccountId": "...", "amount": 100.0 }`.
   - Regras:
     - Se conta de origem ou destino não existirem: 404.
     - Se saldo insuficiente na origem: 400 com `{ "error": "Insufficient funds" }`.
     - Se ok: debita origem, credita destino, grava em `Transactions`.
   - Logs:
     - `Information` para transferências bem-sucedidas com campos: `fromAccountId`, `toAccountId`, `amount`.
     - `Warning` para saldo insuficiente.
     - `Error` para exceções inesperadas.
   - Trace: span `"TransferFunds"` com spans filhos para operações de BD (queries, updates Postgres).

6. `GET /accounts/{id}/transactions`
   - Lista transações da conta (origem ou destino).
   - Aceita `?startDate=...&endDate=...` simples.
   - Trace: span `"ListTransactions"`.

---

## 3️⃣ Sistema de LOGGING (Serilog + OpenTelemetry)

Quero um sistema de logging **detalhado e estruturado**, pensado para operação em produção e debugging orientado a IA.

### Configuração Geral

- Use **Serilog** como logger principal da aplicação (`Host.UseSerilog()`).
- Sinks:
  - Console em formato **JSON** (ideal para OpenSearch).
- Enrichers:
  - `Environment`
  - `ApplicationName`
  - `MachineName`
  - `ThreadId`
  - `CorrelationId`
  - `ClientId` (se houver no header)
  - `UserId` (se houver contexto/usuário)
  - `TraceId` e `SpanId` (correlação com OpenTelemetry)
- Estruture os logs de forma que cada linha do console seja um **JSON único**.

### Categorias de Logs

- **Application Logs** (operacionais):
  - Eventos de negócio (login, criação de conta, transferência bem-sucedida).
  - Ficam no índice principal, ex: `logs-banking-api`.

- **Warning/Rule Logs**:
  - Regras de negócio quebradas (saldo insuficiente, login inválido).
  - Mesma estrutura de log, apenas nível `Warning`.

- **Error Logs**:
  - Falhas inesperadas, exceções, problemas de infraestrutura (ex: indisponibilidade do Postgres).
  - Devem incluir:
    - `errorType`
    - `exceptionMessage`
    - `stackTrace` (ou ao menos um resumo).

### Campos padrão por log

Cada log deve conter, no mínimo:

- `@timestamp`
- `level`
- `message`
- `sourceContext`
- `traceId`
- `spanId`
- `correlationId`
- `clientId`
- `userId` (se houver)
- `endpoint`
- `httpMethod`
- `path`
- `statusCode` (para logs de requisição/resposta)
- `durationMs` (quando aplicável)
- Em caso de erro:
  - `errorType`
  - `exceptionMessage`
  - `stackTrace` (se possível sem ficar gigante)

### Correlação de Requisições

- Ler cabeçalhos HTTP:
  - `X-Correlation-Id`: se existir, usar esse valor.
  - Senão, gerar um GUID e:
    - Colocar no `HttpContext.Items`.
    - Adicionar no `LogContext` do Serilog.
    - Adicionar na resposta (`X-Correlation-Id`).
- Ler `X-Client-Id`:
  - Se vier, enriquecer logs com `clientId`.
  - Também propagar como Baggage no OpenTelemetry.

### Integração Serilog + OpenTelemetry

- Serilog continua sendo quem escreve no console.
- OpenTelemetry cuida de:
  - Traces (spans).
  - Métricas.
  - Logs exportados via OTLP para o Collector (além do console).
- Certifique-se de:
  - Configurar `OpenTelemetry` com `AddOpenTelemetry().WithLogging(...)`.
  - Exportar logs via OTLP (`AddOtlpExporter()` para logs).

---

## 4️⃣ OpenTelemetry (SDK na API)

No `Program.cs`, configure o OpenTelemetry com:

- `ResourceBuilder` contendo:
  - `service.name = "BankingApi"`
  - `service.version = "1.0.0"`
  - `deployment.environment = "Development"`

- **Traces**:
  - `AddAspNetCoreInstrumentation()` (incluir `RecordException = true`).
  - `AddHttpClientInstrumentation()`.
  - `AddNpgsql()` ou `AddSqlClientInstrumentation()` equivalente para Postgres (usar pacote `OpenTelemetry.Instrumentation.Npgsql`).
  - `AddOtlpExporter()` usando endpoint do Collector via gRPC.

- **Métricas**:
  - `AddAspNetCoreInstrumentation()`.
  - `AddRuntimeInstrumentation()`.
  - `AddMeter("BankingApi.Metrics")` com:
    - Contador de transferências.
    - Métrica de latência média por endpoint (se quiser).
  - `AddOtlpExporter()`.

- **Logs**:
  - Usar `builder.Logging.AddOpenTelemetry(...)` (ou equivalente na pipeline nova),
  - Exportando via OTLP para o Collector.

Configurar os endpoints OTLP via variáveis de ambiente:

- `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`
- `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`
- `OTEL_SERVICE_NAME=BankingApi`

---

## 5️⃣ Docker Compose (Infra local)

Crie um `docker-compose.yml` com serviços:

1. **opensearch**
   - Imagem: `opensearchproject/opensearch:latest`
   - Portas: `9200:9200`
   - Env:
     - `discovery.type=single-node`
     - `DISABLE_SECURITY_PLUGIN=true`
     - `plugins.ml_commons.mcp_server_enabled=true`  # MCP ligado
     - `OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m`

2. **opensearch-dashboards**
   - Imagem: `opensearchproject/opensearch-dashboards:latest`
   - Porta: `5601:5601`
   - Env:
     - `OPENSEARCH_HOSTS=["http://opensearch:9200"]`
     - `DISABLE_SECURITY_DASHBOARDS_PLUGIN=true`
   - `depends_on: opensearch`

3. **otel-collector**
   - Imagem: `otel/opentelemetry-collector:latest`
   - Portas:
     - `4317:4317` (OTLP gRPC)
     - `4318:4318` (OTLP HTTP opcional)
   - Volume:
     - `./otel-collector.yaml:/etc/otel-collector.yaml`
   - Command: `["--config=/etc/otel-collector.yaml"]`
   - `depends_on: opensearch`

4. **postgres**
   - Imagem: `postgres:16`
   - Portas:
     - `5432:5432`
   - Env:
     - `POSTGRES_USER=banking`
     - `POSTGRES_PASSWORD=banking_pwd`
     - `POSTGRES_DB=bankingdb`
   - Volume opcional para dados.

5. **banking-api**
   - Build: `./BankingApi`
   - Porta: `5000:80`
   - Env:
     - `ASPNETCORE_ENVIRONMENT=Development`
     - `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`
     - `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`
     - `OTEL_SERVICE_NAME=BankingApi`
     - `ConnectionStrings__DefaultConnection=Host=postgres;Port=5432;Database=bankingdb;Username=banking;Password=banking_pwd`
   - `depends_on`:
     - `otel-collector`
     - `postgres`

---

## 6️⃣ Arquivo `otel-collector.yaml`

Crie um `otel-collector.yaml` que:

- **receivers**:
  - `otlp`:
    - `protocols`:
      - `grpc: {}` 
      - `http: {}`

- **processors**:
  - `batch: {}`

- **exporters**:
  - `opensearch` (usando o exporter de OpenSearch da distribuição contrib):
    - `endpoints: ["http://opensearch:9200"]`
    - `logs_index: "logs-banking-api"`
    - `traces_index: "traces-banking-api"`
    - `timeout: 10s`
  - `logging`:
    - `loglevel: info`

- **service.pipelines**:
  - `traces`:
    - receivers: `[otlp]`
    - processors: `[batch]`
    - exporters: `[opensearch, logging]`
  - `metrics`:
    - receivers: `[otlp]`
    - processors: `[batch]`
    - exporters: `[logging]` (pode ficar apenas no logging se quiser simplificar)
  - `logs`:
    - receivers: `[otlp]`
    - processors: `[batch]`
    - exporters: `[opensearch, logging]`

---

## 7️⃣ Program.cs

- Configure Serilog (console JSON + enrichers mencionados).
- Configure OpenTelemetry (traces, métricas, logs).
- Crie middlewares para:
  - Gerenciar `X-Correlation-Id` e `X-Client-Id`.
  - Adicionar esses valores ao `LogContext` e `Baggage`.
- Registre `BankingDbContext` com Npgsql e connection string vinda de `Configuration/Env`.
- Exponha os endpoints definidos nos fluxos.
- Adicione Swagger/OpenAPI.

---

## 8️⃣ Dockerfile da API

- Stage de build: `mcr.microsoft.com/dotnet/sdk:8.0`
- Stage de runtime: `mcr.microsoft.com/dotnet/aspnet:8.0`
- Restaurar, publicar em `Release`.
- Copiar publish para a imagem final.
- `ENTRYPOINT` rodando a API.
- Expor porta 80.

---

## 9️⃣ Testes via cURL (mapear em arquivo tests.http ou curl-tests.md)

Crie também um arquivo `tests.http` (ou `.md` com blocos bash) com os comandos abaixo para validar que tudo está funcionando.

Assuma API em `http://localhost:5000`.

### 9.1. Health check

```bash
curl -v http://localhost:5000/ping
