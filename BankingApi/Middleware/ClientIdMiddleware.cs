using OpenTelemetry;
using Serilog.Context;

namespace BankingApi.Middleware;

public class ClientIdMiddleware
{
    private readonly RequestDelegate _next;
    private const string ClientIdHeader = "X-Client-Id";
    private const string ClientIdItemKey = "ClientId";

    public ClientIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var clientId = context.Request.Headers[ClientIdHeader].FirstOrDefault();
        
        if (!string.IsNullOrEmpty(clientId))
        {
            context.Items[ClientIdItemKey] = clientId;
            
            using (LogContext.PushProperty("clientId", clientId))
            {
                // Adicionar ao Baggage do OpenTelemetry
                Baggage.Current.SetBaggage("client.id", clientId);
                
                await _next(context);
            }
        }
        else
        {
            await _next(context);
        }
    }
}

