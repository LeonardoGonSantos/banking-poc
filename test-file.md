Quero que você gere um arquivo de testes de API baseado em **curl**, para eu validar a POC da minha API Bancária observável.

### Contexto

- A API já foi criada em outro passo, rodando em `http://localhost:5000`.
- Endpoints principais:

  - `GET /ping`
  - `POST /auth/login`
  - `POST /accounts`
  - `GET /accounts/{id}/balance`
  - `POST /transactions`
  - `GET /accounts/{id}/transactions`

- A API está atrás de um OpenTelemetry Collector que exporta para o OpenSearch.
- Para observabilidade, quero sempre mandar headers:
  - `X-Correlation-Id`
  - `X-Client-Id`

### O que eu quero que você produza

Crie **um único arquivo** chamado, por exemplo, `curl-tests.http` (ou `curl-tests.md` se for mais confortável) contendo uma bateria de testes com `curl` para validar:

1. **Disponibilidade básica da API**
   - Teste simples de `GET /ping`.

2. **Autenticação / Login**
   - Login de sucesso:
     - `email = "user@test.com"`
     - `password = "123456"`
   - Login com senha inválida.
   - Login com email inexistente.
   - Sempre usando `X-Correlation-Id` e `X-Client-Id` diferentes em cada cenário para eu conseguir ver isso nos logs.

3. **Criação de Conta**
   - `POST /accounts` com `initialBalance` variando (por exemplo 1000.0, 2000.0, 3000.0).
   - Deixe claro em comentários que o `accountId` retornado deve ser copiado e usado em outros testes depois.

4. **Consulta de Saldo**
   - `GET /accounts/{ACCOUNT_ID}/balance` com:
     - Uma conta válida.
     - Uma conta inválida (GUID inexistente) para gerar 404 e log/trace de erro de regra.

5. **Transferências**
   - `POST /transactions` com os cenários:
     - Transferência OK entre duas contas válidas.
     - Transferência com **saldo insuficiente** (gera Warning).
     - Transferência com conta de origem inexistente.
     - Transferência com conta de destino inexistente.
   - Sempre com `X-Correlation-Id` descritivo, tipo `transfer-ok-1`, `transfer-insufficient`, `transfer-invalid-destination`, etc.

6. **Extrato / Transações**
   - `GET /accounts/{ACCOUNT_ID}/transactions`:
     - Lista completa.
     - Lista com `startDate` e `endDate` (ex: `2025-01-01` até `2030-01-01`).

7. **Erros de validação & parsing**
   - `POST /transactions` com JSON quebrado para forçar erro 400/500 e log de exceção.
   - Chamar `POST /ping` (método errado) para gerar 405 e log correspondente.

8. **Spam / Carga leve para logs & traces**
   - Loop de várias requisições `GET /ping` (ex: 30 vezes).
   - Loop de várias transferências pequenas (ex: 20 transferências de R$ 1,00) usando os mesmos `fromAccountId` e `toAccountId`.
   - Isso pode ser em forma de script bash dentro do mesmo arquivo (comentado), por exemplo:
     ```bash
     for i in {1..30}; do
       curl -s http://localhost:5000/ping \
         -H "X-Correlation-Id: spam-ping-$i" \
         -H "X-Client-Id: load-tester" > /dev/null
     done
     ```

### Formato do arquivo

- Use blocos `bash` ou o formato nativo de `.http` (ex: no VSCode/JetBrains/Cursor) – qualquer um é aceitável, desde que eu consiga:
  - Copiar e colar no terminal, ou
  - Rodar diretamente como arquivo `.http` pelo Cursor.

- Antes de cada grupo de testes, coloque comentários explicando o objetivo, por exemplo:
  - `# Teste básico de health check`
  - `# Login – cenário de sucesso`
  - `# Transferência com saldo insuficiente (deve retornar 400)`

- Para endpoints que dependem de `ACCOUNT_ID`, `FROM_ACCOUNT_ID`, `TO_ACCOUNT_ID`, use placeholders claros como:
  - `{ACCOUNT_ID}`
  - `{FROM_ACCOUNT_ID}`
  - `{TO_ACCOUNT_ID}`
  e comente que devo substituir manualmente pelos IDs retornados da API.

### Detalhes importantes

- Em todos os `curl`, inclua:
  - `-w "\nHTTP %{http_code}\n"` ao final, para eu ver rapidamente o status code.
- Onde fizer sentido, use:
  - `-s` (silent) para não poluir demais a saída.
- Inclua pelo menos **um teste** de cada endpoint que deve gerar:
  - Sucesso (2xx),
  - Erro de regra (4xx),
  - Erro de entrada inválida (400/500 se o backend tratar assim).

No final, o arquivo `curl-tests.http` deve estar pronto pra eu:

1. Subir o ambiente com `docker-compose up -d`.
2. Rodar os `curl` na ordem que você planejou.
3. Ir até o OpenSearch Dashboards e conseguir visualizar:
   - Logs dos cenários (com `traceId`, `spanId`, `correlationId`, `clientId`).
   - Traces dos fluxos de login, criação de conta, transferências e extrato.
