#!/usr/bin/env python3
"""
MCP Server para Banking API
Expõe todos os endpoints da Banking API como tools MCP
"""
import asyncio
import json
import sys
import os
from typing import Any, Optional
import httpx
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Adicionar diretório atual ao path para imports locais
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config

# Criar instância do servidor MCP
server = Server("banking-api-mcp")

# Cliente HTTP para chamadas à API
http_client = httpx.AsyncClient(
    base_url=config.BANKING_API_URL,
    timeout=config.HTTP_TIMEOUT
)


async def call_api(
    method: str,
    endpoint: str,
    json_data: Optional[dict] = None,
    params: Optional[dict] = None,
    correlation_id: Optional[str] = None,
    client_id: Optional[str] = None
) -> dict[str, Any]:
    """Faz uma chamada HTTP para a Banking API"""
    headers = {}
    if correlation_id:
        headers["X-Correlation-Id"] = correlation_id
    if client_id:
        headers["X-Client-Id"] = client_id
    
    try:
        response = await http_client.request(
            method=method,
            url=endpoint,
            json=json_data,
            params=params,
            headers=headers
        )
        response.raise_for_status()
        return {
            "status_code": response.status_code,
            "data": response.json() if response.content else None,
            "headers": dict(response.headers)
        }
    except httpx.HTTPStatusError as e:
        error_data = None
        try:
            error_data = e.response.json()
        except:
            error_data = {"error": e.response.text}
        
        return {
            "status_code": e.response.status_code,
            "error": error_data,
            "headers": dict(e.response.headers)
        }
    except Exception as e:
        return {
            "status_code": 0,
            "error": {"message": str(e)}
        }


@server.list_tools()
async def list_tools() -> list[Tool]:
    """Lista todas as tools disponíveis"""
    return [
        Tool(
            name="ping",
            description="Verifica se a Banking API está online",
            inputSchema={
                "type": "object",
                "properties": {},
                "required": []
            }
        ),
        Tool(
            name="get_balance",
            description="Obtém o saldo de uma conta bancária",
            inputSchema={
                "type": "object",
                "properties": {
                    "account_id": {
                        "type": "string",
                        "description": "ID da conta (GUID)"
                    },
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação para rastreamento (opcional)"
                    },
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (opcional)"
                    }
                },
                "required": ["account_id"]
            }
        ),
        Tool(
            name="create_user",
            description="Cria um novo usuário e conta bancária",
            inputSchema={
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Nome do usuário"
                    },
                    "email": {
                        "type": "string",
                        "description": "Email do usuário"
                    },
                    "password": {
                        "type": "string",
                        "description": "Senha do usuário"
                    },
                    "initial_balance": {
                        "type": "number",
                        "description": "Saldo inicial da conta"
                    },
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação para rastreamento (opcional)"
                    },
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (opcional)"
                    }
                },
                "required": ["name", "email", "password", "initial_balance"]
            }
        ),
        Tool(
            name="create_account",
            description="Cria uma nova conta bancária para um usuário existente",
            inputSchema={
                "type": "object",
                "properties": {
                    "email": {
                        "type": "string",
                        "description": "Email do usuário dono da conta"
                    },
                    "initial_balance": {
                        "type": "number",
                        "description": "Saldo inicial da conta"
                    },
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação para rastreamento (opcional)"
                    },
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (opcional)"
                    }
                },
                "required": ["email", "initial_balance"]
            }
        ),
        Tool(
            name="login",
            description="Realiza login de um usuário",
            inputSchema={
                "type": "object",
                "properties": {
                    "email": {
                        "type": "string",
                        "description": "Email do usuário"
                    },
                    "password": {
                        "type": "string",
                        "description": "Senha do usuário"
                    },
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação para rastreamento (opcional)"
                    },
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (opcional)"
                    }
                },
                "required": ["email", "password"]
            }
        ),
        Tool(
            name="transfer",
            description="Realiza uma transferência entre contas",
            inputSchema={
                "type": "object",
                "properties": {
                    "from_account_id": {
                        "type": "string",
                        "description": "ID da conta de origem (GUID)"
                    },
                    "to_account_id": {
                        "type": "string",
                        "description": "ID da conta de destino (GUID)"
                    },
                    "amount": {
                        "type": "number",
                        "description": "Valor da transferência"
                    },
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação para rastreamento (opcional)"
                    },
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (opcional)"
                    }
                },
                "required": ["from_account_id", "to_account_id", "amount"]
            }
        ),
        Tool(
            name="list_transactions",
            description="Lista transações de uma conta",
            inputSchema={
                "type": "object",
                "properties": {
                    "account_id": {
                        "type": "string",
                        "description": "ID da conta (GUID)"
                    },
                    "start_date": {
                        "type": "string",
                        "description": "Data de início (formato ISO 8601, opcional)"
                    },
                    "end_date": {
                        "type": "string",
                        "description": "Data de fim (formato ISO 8601, opcional)"
                    },
                    "correlation_id": {
                        "type": "string",
                        "description": "ID de correlação para rastreamento (opcional)"
                    },
                    "client_id": {
                        "type": "string",
                        "description": "ID do cliente (opcional)"
                    }
                },
                "required": ["account_id"]
            }
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    """Executa uma tool específica"""
    
    correlation_id = arguments.get("correlation_id")
    client_id = arguments.get("client_id")
    
    try:
        if name == "ping":
            result = await call_api("GET", "/ping", correlation_id=correlation_id, client_id=client_id)
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, ensure_ascii=False)
            )]
        
        elif name == "get_balance":
            account_id = arguments["account_id"]
            result = await call_api(
                "GET",
                f"/accounts/{account_id}/balance",
                correlation_id=correlation_id,
                client_id=client_id
            )
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, ensure_ascii=False)
            )]
        
        elif name == "create_user":
            result = await call_api(
                "POST",
                "/users",
                json_data={
                    "name": arguments["name"],
                    "email": arguments["email"],
                    "password": arguments["password"],
                    "initialBalance": arguments["initial_balance"]
                },
                correlation_id=correlation_id,
                client_id=client_id
            )
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, ensure_ascii=False)
            )]
        
        elif name == "create_account":
            result = await call_api(
                "POST",
                "/accounts",
                json_data={
                    "email": arguments["email"],
                    "initialBalance": arguments["initial_balance"]
                },
                correlation_id=correlation_id,
                client_id=client_id
            )
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, ensure_ascii=False)
            )]
        
        elif name == "login":
            result = await call_api(
                "POST",
                "/auth/login",
                json_data={
                    "email": arguments["email"],
                    "password": arguments["password"]
                },
                correlation_id=correlation_id,
                client_id=client_id
            )
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, ensure_ascii=False)
            )]
        
        elif name == "transfer":
            result = await call_api(
                "POST",
                "/transactions",
                json_data={
                    "fromAccountId": arguments["from_account_id"],
                    "toAccountId": arguments["to_account_id"],
                    "amount": arguments["amount"]
                },
                correlation_id=correlation_id,
                client_id=client_id
            )
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, ensure_ascii=False)
            )]
        
        elif name == "list_transactions":
            account_id = arguments["account_id"]
            params = {}
            if "start_date" in arguments:
                params["startDate"] = arguments["start_date"]
            if "end_date" in arguments:
                params["endDate"] = arguments["end_date"]
            
            result = await call_api(
                "GET",
                f"/accounts/{account_id}/transactions",
                params=params,
                correlation_id=correlation_id,
                client_id=client_id
            )
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, ensure_ascii=False)
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
            text=json.dumps({"error": str(e)}, indent=2)
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

