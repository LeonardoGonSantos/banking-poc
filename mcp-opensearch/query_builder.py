"""
Query Builder para OpenSearch com suporte a linguagem natural para períodos
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import dateparser
import pytz


def parse_period(period_text: str, reference_time: Optional[datetime] = None) -> Dict[str, str]:
    """
    Converte um período em linguagem natural para um range de @timestamp do OpenSearch
    
    Exemplos:
    - "ontem" -> range de ontem 00:00 até hoje 00:00
    - "última semana" -> range de 7 dias atrás até agora
    - "24 de novembro às 14h" -> range específico
    - "há 2 horas" -> range de 2 horas atrás até agora
    - "hoje" -> range de hoje 00:00 até agora
    
    Retorna um dict com "gte" e "lte" no formato ISO 8601
    """
    if reference_time is None:
        reference_time = datetime.now(pytz.UTC)
    
    # Tentar parsing direto com dateparser
    parsed_date = dateparser.parse(
        period_text,
        languages=['pt', 'en'],
        settings={
            'RELATIVE_BASE': reference_time,
            'TIMEZONE': 'UTC',
            'RETURN_AS_TIMEZONE_AWARE': True
        }
    )
    
    if parsed_date:
        # Se parseou uma data específica, criar range de 1 hora ao redor
        gte = (parsed_date - timedelta(hours=0.5)).isoformat()
        lte = (parsed_date + timedelta(hours=0.5)).isoformat()
        return {"gte": gte, "lte": lte}
    
    # Casos especiais em português
    period_lower = period_text.lower().strip()
    
    if period_lower in ["hoje", "today"]:
        start = reference_time.replace(hour=0, minute=0, second=0, microsecond=0)
        return {
            "gte": start.isoformat(),
            "lte": reference_time.isoformat()
        }
    
    elif period_lower in ["ontem", "yesterday"]:
        yesterday = reference_time - timedelta(days=1)
        start = yesterday.replace(hour=0, minute=0, second=0, microsecond=0)
        end = reference_time.replace(hour=0, minute=0, second=0, microsecond=0)
        return {
            "gte": start.isoformat(),
            "lte": end.isoformat()
        }
    
    elif period_lower in ["última semana", "last week", "semana passada"]:
        start = reference_time - timedelta(days=7)
        return {
            "gte": start.isoformat(),
            "lte": reference_time.isoformat()
        }
    
    elif period_lower in ["último mês", "last month", "mês passado"]:
        start = reference_time - timedelta(days=30)
        return {
            "gte": start.isoformat(),
            "lte": reference_time.isoformat()
        }
    
    elif period_lower.startswith("há ") or period_lower.startswith("hà "):
        # "há 2 horas", "há 3 dias", etc.
        try:
            # Extrair número e unidade
            parts = period_lower.split()
            if len(parts) >= 3:
                amount = int(parts[1])
                unit = parts[2]
                
                if "hora" in unit or "hour" in unit:
                    start = reference_time - timedelta(hours=amount)
                elif "dia" in unit or "day" in unit:
                    start = reference_time - timedelta(days=amount)
                elif "semana" in unit or "week" in unit:
                    start = reference_time - timedelta(weeks=amount)
                elif "mês" in unit or "month" in unit:
                    start = reference_time - timedelta(days=amount * 30)
                else:
                    # Default: horas
                    start = reference_time - timedelta(hours=amount)
                
                return {
                    "gte": start.isoformat(),
                    "lte": reference_time.isoformat()
                }
        except (ValueError, IndexError):
            pass
    
    # Se não conseguiu parsear, usar range padrão de últimas 24 horas
    start = reference_time - timedelta(hours=24)
    return {
        "gte": start.isoformat(),
        "lte": reference_time.isoformat()
    }


def build_query(
    index: str,
    client_id: Optional[str] = None,
    correlation_id: Optional[str] = None,
    period: Optional[str] = None,
    additional_filters: Optional[Dict[str, Any]] = None,
    size: int = 100
) -> Dict[str, Any]:
    """
    Constrói uma query do OpenSearch com filtros opcionais
    
    Args:
        index: Nome do índice (logs-banking-api ou traces-banking-api)
        client_id: Filtrar por clientId
        correlation_id: Filtrar por correlationId
        period: Período em linguagem natural (ex: "ontem", "há 2 horas")
        additional_filters: Filtros adicionais em formato OpenSearch
        size: Número máximo de resultados
    """
    must_clauses = []
    
    # Filtro por clientId
    if client_id:
        must_clauses.append({
            "term": {
                "Attributes.clientId": client_id
            }
        })
    
    # Filtro por correlationId
    if correlation_id:
        must_clauses.append({
            "term": {
                "Attributes.correlationId": correlation_id
            }
        })
    
    # Filtro por período
    if period:
        time_range = parse_period(period)
        must_clauses.append({
            "range": {
                "@timestamp": time_range
            }
        })
    
    # Filtros adicionais
    if additional_filters:
        must_clauses.extend(additional_filters.get("must", []))
    
    query = {
        "index": index,
        "body": {
            "size": size,
            "sort": [
                {
                    "@timestamp": {
                        "order": "desc"
                    }
                }
            ]
        }
    }
    
    if must_clauses:
        query["body"]["query"] = {
            "bool": {
                "must": must_clauses
            }
        }
    else:
        query["body"]["query"] = {
            "match_all": {}
        }
    
    return query


def format_results_for_ai(results: Dict[str, Any], result_type: str = "logs") -> str:
    """
    Formata os resultados do OpenSearch para contexto da IA
    
    Args:
        results: Resultados da busca do OpenSearch
        result_type: Tipo de resultado ("logs" ou "traces")
    """
    if not results or "hits" not in results or "hits" not in results["hits"]:
        return "Nenhum resultado encontrado."
    
    hits = results["hits"]["hits"]
    total = results["hits"]["total"].get("value", 0)
    
    if total == 0:
        return "Nenhum resultado encontrado."
    
    formatted = [f"Total de {result_type}: {total}\n"]
    
    for i, hit in enumerate(hits[:20], 1):  # Limitar a 20 resultados
        source = hit.get("_source", {})
        timestamp = source.get("@timestamp", "N/A")
        
        if result_type == "logs":
            severity = source.get("SeverityText", "N/A")
            body = source.get("Body", "N/A")
            correlation_id = source.get("Attributes", {}).get("correlationId", "N/A")
            client_id = source.get("Attributes", {}).get("clientId", "N/A")
            
            formatted.append(f"\n--- Log {i} ---")
            formatted.append(f"Timestamp: {timestamp}")
            formatted.append(f"Severity: {severity}")
            formatted.append(f"CorrelationId: {correlation_id}")
            formatted.append(f"ClientId: {client_id}")
            formatted.append(f"Message: {body}")
        
        elif result_type == "traces":
            name = source.get("Name", "N/A")
            kind = source.get("Kind", "N/A")
            duration = source.get("Duration", "N/A")
            trace_id = source.get("TraceId", "N/A")
            span_id = source.get("SpanId", "N/A")
            
            formatted.append(f"\n--- Trace {i} ---")
            formatted.append(f"Timestamp: {timestamp}")
            formatted.append(f"Name: {name}")
            formatted.append(f"Kind: {kind}")
            formatted.append(f"Duration: {duration}ns")
            formatted.append(f"TraceId: {trace_id}")
            formatted.append(f"SpanId: {span_id}")
    
    if total > 20:
        formatted.append(f"\n... e mais {total - 20} resultados.")
    
    return "\n".join(formatted)


