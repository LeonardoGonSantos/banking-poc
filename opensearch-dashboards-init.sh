#!/bin/bash

# Script de inicialização do OpenSearch Dashboards
# Configura index patterns para traces e logs

OPENSEARCH_URL="http://opensearch:9200"
DASHBOARDS_URL="http://opensearch-dashboards:5601"

echo "Aguardando OpenSearch estar disponível..."
until curl -s "$OPENSEARCH_URL/_cluster/health" > /dev/null 2>&1; do
  sleep 2
done

echo "Aguardando OpenSearch Dashboards estar disponível..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -s "$DASHBOARDS_URL/api/status" > /dev/null 2>&1; then
    echo "OpenSearch Dashboards está disponível!"
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  echo "⚠️  OpenSearch Dashboards não ficou disponível a tempo"
  exit 1
fi

echo "Criando index patterns..."

# Criar index pattern para traces
echo "Criando index pattern para traces..."
response=$(curl -s -X POST "$DASHBOARDS_URL/api/saved_objects/index-pattern/traces-banking-api" \
  -H "Content-Type: application/json" \
  -H "osd-xsrf: true" \
  -d '{
    "attributes": {
      "title": "traces-banking-api",
      "timeFieldName": "@timestamp"
    }
  }')

if echo "$response" | grep -q "id"; then
  echo "✅ Index pattern 'traces-banking-api' criado"
else
  echo "⚠️  Index pattern 'traces-banking-api' já existe ou erro ao criar"
fi

# Criar index pattern para logs
echo "Criando index pattern para logs..."
response=$(curl -s -X POST "$DASHBOARDS_URL/api/saved_objects/index-pattern/logs-banking-api" \
  -H "Content-Type: application/json" \
  -H "osd-xsrf: true" \
  -d '{
    "attributes": {
      "title": "logs-banking-api",
      "timeFieldName": "@timestamp"
    }
  }')

if echo "$response" | grep -q "id"; then
  echo "✅ Index pattern 'logs-banking-api' criado"
else
  echo "⚠️  Index pattern 'logs-banking-api' já existe ou erro ao criar"
fi

echo "✅ Index patterns configurados!"

