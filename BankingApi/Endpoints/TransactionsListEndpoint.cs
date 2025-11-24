using System.Diagnostics;
using BankingApi.Data;
using BankingApi.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace BankingApi.Endpoints;

public static class TransactionsListEndpoint
{
    public static void MapTransactionsListEndpoint(this IEndpointRouteBuilder app)
    {
        app.MapGet("/accounts/{id:guid}/transactions", async (Guid id, [FromQuery] string? startDate, [FromQuery] string? endDate, BankingDbContext db) =>
        {
            using var activity = new ActivitySource("BankingApi.Traces").StartActivity("ListTransactions");
            activity?.SetTag("account.id", id.ToString());
            if (!string.IsNullOrEmpty(startDate)) activity?.SetTag("filter.startDate", startDate);
            if (!string.IsNullOrEmpty(endDate)) activity?.SetTag("filter.endDate", endDate);

            try
            {
                var account = await db.Accounts.FindAsync(id);

                if (account == null)
                {
                    Log.Warning("Account not found: {AccountId}", id);
                    return Results.NotFound(new ErrorResponse("Account not found"));
                }

                var query = db.Transactions
                    .Where(t => t.FromAccountId == id || t.ToAccountId == id)
                    .AsQueryable();

                if (!string.IsNullOrEmpty(startDate) && DateTime.TryParse(startDate, out var startDateParsed))
                {
                    var startDateUtc = startDateParsed.Kind == DateTimeKind.Utc 
                        ? startDateParsed 
                        : DateTime.SpecifyKind(startDateParsed, DateTimeKind.Utc);
                    query = query.Where(t => t.CreatedAt >= startDateUtc);
                }

                if (!string.IsNullOrEmpty(endDate) && DateTime.TryParse(endDate, out var endDateParsed))
                {
                    var endDateUtc = endDateParsed.Kind == DateTimeKind.Utc 
                        ? endDateParsed 
                        : DateTime.SpecifyKind(endDateParsed, DateTimeKind.Utc);
                    query = query.Where(t => t.CreatedAt <= endDateUtc);
                }

                var transactions = await query
                    .OrderByDescending(t => t.CreatedAt)
                    .Select(t => new TransactionResponse(
                        t.Id,
                        t.FromAccountId,
                        t.ToAccountId,
                        t.Amount,
                        t.CreatedAt,
                        t.Type
                    ))
                    .ToListAsync();

                Log.Information("Transactions listed: AccountId: {AccountId}, Count: {Count}", id, transactions.Count);

                return Results.Ok(transactions);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error listing transactions for account: {AccountId}", id);
                return Results.Problem("Error listing transactions");
            }
        })
        .WithName("ListTransactions")
        .WithTags("Transactions")
        .Produces<List<TransactionResponse>>(StatusCodes.Status200OK)
        .Produces<ErrorResponse>(StatusCodes.Status404NotFound);
    }
}

