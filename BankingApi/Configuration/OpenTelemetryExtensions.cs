using System.Diagnostics;
using System.Diagnostics.Metrics;
using OpenTelemetry;
using OpenTelemetry.Extensions.Hosting;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace BankingApi.Configuration;

public static class OpenTelemetryExtensions
{
    public static void ConfigureOpenTelemetry(this WebApplicationBuilder builder)
    {
        var serviceName = builder.Configuration["OTEL_SERVICE_NAME"] ?? "BankingApi";
        var serviceVersion = "1.0.0";
        var environment = builder.Environment.EnvironmentName;

        var resourceBuilder = ResourceBuilder.CreateDefault()
            .AddService(serviceName, serviceVersion: serviceVersion)
            .AddAttributes(new Dictionary<string, object>
            {
                ["deployment.environment"] = environment
            });

        // Traces
        builder.Services.AddOpenTelemetry()
            .WithTracing(tracerProviderBuilder =>
            {
                tracerProviderBuilder
                    .SetResourceBuilder(resourceBuilder)
                    .AddAspNetCoreInstrumentation(options =>
                    {
                        // RecordException é habilitado por padrão na versão 1.9.0
                        options.EnrichWithHttpRequest = (activity, request) =>
                        {
                            activity.SetTag("http.request.method", request.Method);
                            activity.SetTag("http.request.path", request.Path);
                        };
                        options.EnrichWithHttpResponse = (activity, response) =>
                        {
                            activity.SetTag("http.response.status_code", response.StatusCode);
                        };
                    })
                    .AddHttpClientInstrumentation()
                    .AddSource("BankingApi.Traces")
                    .AddOtlpExporter(options =>
                    {
                        var endpoint = builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] ?? "http://otel-collector:4317";
                        options.Endpoint = new Uri(endpoint);
                    });
            })
            .WithMetrics(meterProviderBuilder =>
            {
                meterProviderBuilder
                    .SetResourceBuilder(resourceBuilder)
                    .AddAspNetCoreInstrumentation()
                    .AddRuntimeInstrumentation()
                    .AddMeter("BankingApi.Metrics")
                    .AddOtlpExporter(options =>
                    {
                        var endpoint = builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] ?? "http://otel-collector:4317";
                        options.Endpoint = new Uri(endpoint);
                    });
            });

        // Logs (Configurados via Serilog, removendo integração ILogger -> OTLP para evitar duplicação ou conflitos)
        // builder.Logging.AddOpenTelemetry(...) 
        builder.Logging.ClearProviders(); // Opcional: remover outros providers se quiser apenas Serilog
    }
}

