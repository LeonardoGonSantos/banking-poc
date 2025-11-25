import os

# URL da Banking API (dentro do Docker network)
BANKING_API_URL = os.getenv("BANKING_API_URL", "http://banking-api:80")

# Timeout para requisições HTTP
HTTP_TIMEOUT = int(os.getenv("HTTP_TIMEOUT", "30"))

