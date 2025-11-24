using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Serilog;

namespace BankingApi.Endpoints;

public static class PingEndpoint
{
    public static void MapPingEndpoint(this IEndpointRouteBuilder app)
    {
        app.MapGet("/ping", () =>
        {
            using var activity = new ActivitySource("BankingApi.Traces").StartActivity("Ping");
            
            Log.Information("Health check requested");
            
            return Results.Ok(new { status = "ok" });
        })
        .WithName("Ping")
        .WithTags("Health")
        .Produces<object>(StatusCodes.Status200OK);
    }
}

