using BankingApi.Configuration;
using BankingApi.Data;
using BankingApi.Endpoints;
using BankingApi.Middleware;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;

var builder = WebApplication.CreateBuilder(args);

// Configurar URLs para escutar em todas as interfaces (necessário no Docker)
builder.WebHost.UseUrls("http://0.0.0.0:80");

// Configurar OpenTelemetry
builder.ConfigureOpenTelemetry();

// Configurar Serilog
builder.ConfigureSerilog();

// Add services to the container
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configurar Entity Framework Core com PostgreSQL
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Host=postgres;Port=5432;Database=bankingdb;Username=banking;Password=banking_pwd";

builder.Services.AddDbContext<BankingDbContext>(options =>
    options.UseNpgsql(connectionString));

var app = builder.Build();

// Aplicar migrações e seed data
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<BankingDbContext>();
    try
    {
        db.Database.Migrate();
        await DataSeeder.SeedAsync(db);
        Log.Information("Database migrations applied and seed data created");
    }
    catch (Exception ex)
    {
        Log.Error(ex, "Error applying migrations or seeding data");
    }
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Middlewares de correlação (devem vir antes de outros middlewares)
app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<ClientIdMiddleware>();

// Mapear endpoints
app.MapPingEndpoint();
app.MapAuthEndpoint();
app.MapUsersEndpoint();
app.MapAccountsEndpoint();
app.MapBalanceEndpoint();
app.MapTransactionsEndpoint();
app.MapTransactionsListEndpoint();

Log.Information("Application starting and listening on configured port");

app.Run();
