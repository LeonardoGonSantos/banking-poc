#!/bin/bash

echo "Verificando Docker daemon..."

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker daemon não está rodando!"
    echo "Por favor, inicie o Docker Desktop ou o Docker daemon e tente novamente."
    exit 1
fi

echo "✅ Docker daemon está rodando"
echo "Versão Docker: $(docker --version)"
echo "Versão Docker Compose: $(docker compose version)"

exit 0

