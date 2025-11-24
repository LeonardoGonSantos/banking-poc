using System.Diagnostics;
using System.Diagnostics.Metrics;
using BankingApi.Data;
using BankingApi.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace BankingApi.Endpoints;

public static class BalanceEndpoint
{
    private static readonly Meter Meter = new("BankingApi.Metrics");
    private static readonly Counter<long> GetBalanceCounter = Meter.CreateCounter<long>("banking.get_balance.count");

    public static void MapBalanceEndpoint(this IEndpointRouteBuilder app)
    {
        app.MapGet("/accounts/{id:guid}/balance", async (Guid id, BankingDbContext db) =>
        {
            using var activity = new ActivitySource("BankingApi.Traces").StartActivity("GetBalance");
            activity?.SetTag("account.id", id.ToString());
            
            GetBalanceCounter.Add(1);

            try
            {
                var account = await db.Accounts.FindAsync(id);

                if (account == null)
                {
                    Log.Warning("Account not found: {AccountId}", id);
                    return Results.NotFound(new ErrorResponse("Account not found"));
                }

                Log.Information("Balance retrieved: AccountId: {AccountId}, Balance: {Balance}", id, account.Balance);

                return Results.Ok(new BalanceResponse(account.Balance));
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error retrieving balance for account: {AccountId}", id);
                return Results.Problem("Error retrieving balance");
            }
        })
        .WithName("GetBalance")
        .WithTags("Accounts")
        .Produces<BalanceResponse>(StatusCodes.Status200OK)
        .Produces<ErrorResponse>(StatusCodes.Status404NotFound);
    }
}

