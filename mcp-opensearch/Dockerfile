FROM python:3.11-slim

WORKDIR /app

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements primeiro para cache de layers
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código da aplicação
COPY . .

# Expor porta para SSE (opcional)
EXPOSE 9901

# Comando padrão: stdio (para Cursor/Claude Desktop)
# Para SSE, usar: python server.py --transport sse
CMD ["python", "server.py"]


