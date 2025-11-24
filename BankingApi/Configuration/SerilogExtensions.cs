using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;
using Serilog.Sinks.OpenTelemetry;

namespace BankingApi.Configuration;

public static class SerilogExtensions
{
    public static void ConfigureSerilog(this WebApplicationBuilder builder)
    {
        builder.Host.UseSerilog((context, services, configuration) =>
        {
            var otelEndpoint = builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] ?? "http://otel-collector:4317";
            
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
                .WriteTo.Console(new JsonFormatter())
                .WriteTo.OpenTelemetry(options =>
                {
                    options.Endpoint = otelEndpoint;
                    options.Protocol = OtlpProtocol.Grpc; // Ou HttpProtobuf dependendo da porta/config
                    options.ResourceAttributes = new Dictionary<string, object>
                    {
                        ["service.name"] = "BankingApi",
                        ["service.version"] = "1.0.0",
                        ["deployment.environment"] = builder.Environment.EnvironmentName
                    };
                });
        });
    }
}

