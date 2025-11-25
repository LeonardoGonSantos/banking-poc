#!/usr/bin/env python3
"""
MCP Server para OpenSearch
Permite consultar logs e traces com filtros por clientId, correlationId e período
"""
import asyncio
import json
import sys
import os
from typing import Any, Optional
from concurrent.futures import ThreadPoolExecutor
from opensearchpy import OpenSearch
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Adicionar diretório atual ao path para imports locais
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
import query_builder

# Criar cliente OpenSearch
opensearch_client = OpenSearch(
    hosts=[config.OPENSEARCH_URL],
    http_auth=(
        (config.OPENSEARCH_USERNAME, config.OPENSEARCH_PASSWORD)
        if config.OPENSEARCH_USERNAME and config.OPENSEARCH_PASSWORD
        else None
    ),
    use_ssl=False,
    verify_certs=False,
    ssl_show_warn=False
)

# Executor para operações síncronas do OpenSearch
executor = ThreadPoolExecutor(max_workers=4)


async def search_opensearch(query: dict) -> dict:
    """Executa busca no OpenSearch de forma assíncrona"""
    loop = asyncio.get_event_loop()
    # Extrair index e body do query dict (criar cópia para não modificar original)
    query_copy = query.copy()
    index = query_copy.pop("index")
    body = query_copy.pop("body")
    return await loop.run_in_executor(
        executor,
        lambda: opensearch_client.search(index=index, body=body, **query_copy)
    )

# Criar instância do servidor MCP
server = Server("opensearch-mcp")


@server.list_tools()
async def list_tools() -> list[Tool]:
    """Lista todas as tools disponíveis"""
    return [
        Tool(
            name="search_logs_by_client",
            description="Busca logs no OpenSearch filtrados por clientId e período opcional. Útil para analisar todas as operações de um cliente específico.",
            inputSchema={
                "type": "object",
                "properties": {
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (ex: '12345')"
                    },
                    "period": {
                        "type": "string",
                        "description": "Período em linguagem natural (ex: 'ontem', 'há 2 horas', '24 de novembro às 14h', 'última semana'). Se não fornecido, busca últimas 24 horas."
                    }
                },
                "required": ["client_id"]
            }
        ),
        Tool(
            name="search_logs_by_correlation",
            description="Busca logs no OpenSearch filtrados por correlationId e período opcional. Útil para rastrear o fluxo completo de uma requisição específica.",
            inputSchema={
                "type": "object",
                "properties": {
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação (ex: 'init-10-op-5')"
                    },
                    "period": {
                        "type": "string",
                        "description": "Período em linguagem natural (ex: 'ontem', 'há 2 horas'). Se não fornecido, busca últimas 24 horas."
                    }
                },
                "required": ["correlation_id"]
            }
        ),
        Tool(
            name="search_traces_by_client",
            description="Busca traces no OpenSearch filtrados por clientId e período opcional. Útil para analisar o desempenho e fluxo de operações de um cliente.",
            inputSchema={
                "type": "object",
                "properties": {
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (ex: '12345')"
                    },
                    "period": {
                        "type": "string",
                        "description": "Período em linguagem natural (ex: 'ontem', 'há 2 horas'). Se não fornecido, busca últimas 24 horas."
                    }
                },
                "required": ["client_id"]
            }
        ),
        Tool(
            name="search_traces_by_correlation",
            description="Busca traces no OpenSearch filtrados por correlationId e período opcional. Útil para rastrear o fluxo completo de uma requisição específica em nível de traces.",
            inputSchema={
                "type": "object",
                "properties": {
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação (ex: 'init-10-op-5')"
                    },
                    "period": {
                        "type": "string",
                        "description": "Período em linguagem natural (ex: 'ontem', 'há 2 horas'). Se não fornecido, busca últimas 24 horas."
                    }
                },
                "required": ["correlation_id"]
            }
        ),
        Tool(
            name="get_full_flow",
            description="Busca logs E traces completos por correlationId e período. Retorna o fluxo completo de uma requisição para análise detalhada pela IA.",
            inputSchema={
                "type": "object",
                "properties": {
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação (ex: 'init-10-op-5')"
                    },
                    "period": {
                        "type": "string",
                        "description": "Período em linguagem natural (ex: 'ontem', 'há 2 horas'). Se não fornecido, busca últimas 24 horas."
                    }
                },
                "required": ["correlation_id"]
            }
        ),
        Tool(
            name="search_logs_by_period",
            description="Busca logs no OpenSearch filtrados apenas por período. Útil para análise geral de logs em um período específico.",
            inputSchema={
                "type": "object",
                "properties": {
                    "period": {
                        "type": "string",
                        "description": "Período em linguagem natural (ex: 'ontem', 'há 2 horas', '24 de novembro às 14h', 'última semana')"
                    },
                    "severity": {
                        "type": "string",
                        "description": "Filtrar por severidade (opcional): 'Information', 'Warning', 'Error'"
                    }
                },
                "required": ["period"]
            }
        ),
        Tool(
            name="search_traces_by_period",
            description="Busca traces no OpenSearch filtrados apenas por período. Útil para análise geral de traces em um período específico.",
            inputSchema={
                "type": "object",
                "properties": {
                    "period": {
                        "type": "string",
                        "description": "Período em linguagem natural (ex: 'ontem', 'há 2 horas', '24 de novembro às 14h', 'última semana')"
                    },
                    "operation_name": {
                        "type": "string",
                        "description": "Filtrar por nome da operação (opcional, ex: 'TransferFunds', 'GetBalance')"
                    }
                },
                "required": ["period"]
            }
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    """Executa uma tool específica"""
    
    try:
        if name == "search_logs_by_client":
            client_id = arguments["client_id"]
            period = arguments.get("period")
            
            query = query_builder.build_query(
                index=config.LOGS_INDEX,
                client_id=client_id,
                period=period,
                size=100
            )
            
            results = await search_opensearch(query)
            formatted = query_builder.format_results_for_ai(results, "logs")
            
            return [TextContent(
                type="text",
                text=formatted
            )]
        
        elif name == "search_logs_by_correlation":
            correlation_id = arguments["correlation_id"]
            period = arguments.get("period")
            
            query = query_builder.build_query(
                index=config.LOGS_INDEX,
                correlation_id=correlation_id,
                period=period,
                size=100
            )
            
            results = await search_opensearch(query)
            formatted = query_builder.format_results_for_ai(results, "logs")
            
            return [TextContent(
                type="text",
                text=formatted
            )]
        
        elif name == "search_traces_by_client":
            client_id = arguments["client_id"]
            period = arguments.get("period")
            
            query = query_builder.build_query(
                index=config.TRACES_INDEX,
                client_id=client_id,
                period=period,
                size=100
            )
            
            results = await search_opensearch(query)
            formatted = query_builder.format_results_for_ai(results, "traces")
            
            return [TextContent(
                type="text",
                text=formatted
            )]
        
        elif name == "search_traces_by_correlation":
            correlation_id = arguments["correlation_id"]
            period = arguments.get("period")
            
            query = query_builder.build_query(
                index=config.TRACES_INDEX,
                correlation_id=correlation_id,
                period=period,
                size=100
            )
            
            results = await search_opensearch(query)
            formatted = query_builder.format_results_for_ai(results, "traces")
            
            return [TextContent(
                type="text",
                text=formatted
            )]
        
        elif name == "get_full_flow":
            correlation_id = arguments["correlation_id"]
            period = arguments.get("period")
            
            # Buscar logs
            logs_query = query_builder.build_query(
                index=config.LOGS_INDEX,
                correlation_id=correlation_id,
                period=period,
                size=100
            )
            logs_results = await search_opensearch(logs_query)
            logs_formatted = query_builder.format_results_for_ai(logs_results, "logs")
            
            # Buscar traces
            traces_query = query_builder.build_query(
                index=config.TRACES_INDEX,
                correlation_id=correlation_id,
                period=period,
                size=100
            )
            traces_results = await search_opensearch(traces_query)
            traces_formatted = query_builder.format_results_for_ai(traces_results, "traces")
            
            # Combinar resultados
            combined = f"""
=== FLUXO COMPLETO - CorrelationId: {correlation_id} ===

--- LOGS ---
{logs_formatted}

--- TRACES ---
{traces_formatted}

=== FIM DO FLUXO ===
"""
            
            return [TextContent(
                type="text",
                text=combined
            )]
        
        elif name == "search_logs_by_period":
            period = arguments["period"]
            severity = arguments.get("severity")
            
            additional_filters = None
            if severity:
                additional_filters = {
                    "must": [
                        {
                            "term": {
                                "SeverityText": severity
                            }
                        }
                    ]
                }
            
            query = query_builder.build_query(
                index=config.LOGS_INDEX,
                period=period,
                additional_filters=additional_filters,
                size=100
            )
            
            results = await search_opensearch(query)
            formatted = query_builder.format_results_for_ai(results, "logs")
            
            return [TextContent(
                type="text",
                text=formatted
            )]
        
        elif name == "search_traces_by_period":
            period = arguments["period"]
            operation_name = arguments.get("operation_name")
            
            additional_filters = None
            if operation_name:
                additional_filters = {
                    "must": [
                        {
                            "term": {
                                "Name": operation_name
                            }
                        }
                    ]
                }
            
            query = query_builder.build_query(
                index=config.TRACES_INDEX,
                period=period,
                additional_filters=additional_filters,
                size=100
            )
            
            results = await search_opensearch(query)
            formatted = query_builder.format_results_for_ai(results, "traces")
            
            return [TextContent(
                type="text",
                text=formatted
            )]
        
        else:
            return [TextContent(
                type="text",
                text=json.dumps({"error": f"Tool '{name}' não encontrada"}, indent=2)
            )]
    
    except KeyError as e:
        return [TextContent(
            type="text",
            text=json.dumps({"error": f"Parâmetro obrigatório ausente: {e}"}, indent=2)
        )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=json.dumps({"error": str(e), "type": type(e).__name__}, indent=2)
        )]


async def main():
    """Função principal"""
    # Executar servidor MCP via stdio
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())

