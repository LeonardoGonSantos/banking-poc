using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;

namespace BankingApi.Configuration;

public static class SerilogExtensions
{
    public static void ConfigureSerilog(this WebApplicationBuilder builder)
    {
        builder.Host.UseSerilog((context, services, configuration) =>
        {
            configuration
                .MinimumLevel.Information()
                .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
                .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
                .MinimumLevel.Override("System", LogEventLevel.Warning)
                .Enrich.FromLogContext()
                .Enrich.WithEnvironmentName()
                .Enrich.WithMachineName()
                .Enrich.WithThreadId()
                .Enrich.With(new OpenTelemetryEnricher())
                .Enrich.WithProperty("ApplicationName", "BankingApi")
                .WriteTo.Console(new JsonFormatter());
        });
    }
}

