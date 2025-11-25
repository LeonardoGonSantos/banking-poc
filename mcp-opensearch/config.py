import os

# URL do OpenSearch (dentro do Docker network)
OPENSEARCH_URL = os.getenv("OPENSEARCH_URL", "http://opensearch:9200")

# Credenciais (opcional, se segurança estiver habilitada)
OPENSEARCH_USERNAME = os.getenv("OPENSEARCH_USERNAME", "")
OPENSEARCH_PASSWORD = os.getenv("OPENSEARCH_PASSWORD", "")

# Índices padrão
LOGS_INDEX = os.getenv("LOGS_INDEX", "logs-banking-api")
TRACES_INDEX = os.getenv("TRACES_INDEX", "traces-banking-api")


