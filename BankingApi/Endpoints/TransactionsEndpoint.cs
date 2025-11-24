using System.Diagnostics;
using System.Diagnostics.Metrics;
using BankingApi.Data;
using BankingApi.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace BankingApi.Endpoints;

public static class TransactionsEndpoint
{
    private static readonly Meter Meter = new("BankingApi.Metrics");
    private static readonly Counter<long> TransferCounter = Meter.CreateCounter<long>("banking.transfer.count");

    public static void MapTransactionsEndpoint(this IEndpointRouteBuilder app)
    {
        app.MapPost("/transactions", async (TransferRequest request, BankingDbContext db) =>
        {
            using var activity = new ActivitySource("BankingApi.Traces").StartActivity("TransferFunds");
            activity?.SetTag("transfer.fromAccountId", request.FromAccountId.ToString());
            activity?.SetTag("transfer.toAccountId", request.ToAccountId.ToString());
            activity?.SetTag("transfer.amount", request.Amount);

            try
            {
                using var dbActivity = new ActivitySource("BankingApi.Traces").StartActivity("Database.Transaction");
                
                // Verificar se as contas existem
                var fromAccount = await db.Accounts.FindAsync(request.FromAccountId);
                var toAccount = await db.Accounts.FindAsync(request.ToAccountId);

                if (fromAccount == null)
                {
                    Log.Warning("From account not found: {FromAccountId}", request.FromAccountId);
                    return Results.NotFound(new ErrorResponse("From account not found"));
                }

                if (toAccount == null)
                {
                    Log.Warning("To account not found: {ToAccountId}", request.ToAccountId);
                    return Results.NotFound(new ErrorResponse("To account not found"));
                }

                // Verificar saldo suficiente
                if (fromAccount.Balance < request.Amount)
                {
                    Log.Warning("Insufficient funds: FromAccountId: {FromAccountId}, Balance: {Balance}, Amount: {Amount}",
                        request.FromAccountId, fromAccount.Balance, request.Amount);
                    return Results.BadRequest(new ErrorResponse("Insufficient funds"));
                }

                // Executar transferência
                fromAccount.Balance -= request.Amount;
                toAccount.Balance += request.Amount;

                var transaction = new Models.Transaction
                {
                    Id = Guid.NewGuid(),
                    FromAccountId = request.FromAccountId,
                    ToAccountId = request.ToAccountId,
                    Amount = request.Amount,
                    CreatedAt = DateTime.UtcNow,
                    Type = "TRANSFER"
                };

                db.Transactions.Add(transaction);
                await db.SaveChangesAsync();

                TransferCounter.Add(1, new KeyValuePair<string, object?>("status", "success"));

                Log.Information("Transfer completed: FromAccountId: {FromAccountId}, ToAccountId: {ToAccountId}, Amount: {Amount}, TransactionId: {TransactionId}",
                    request.FromAccountId, request.ToAccountId, request.Amount, transaction.Id);

                return Results.Ok(new TransactionResponse(
                    transaction.Id,
                    transaction.FromAccountId,
                    transaction.ToAccountId,
                    transaction.Amount,
                    transaction.CreatedAt,
                    transaction.Type
                ));
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error processing transfer: FromAccountId: {FromAccountId}, ToAccountId: {ToAccountId}, Amount: {Amount}",
                    request.FromAccountId, request.ToAccountId, request.Amount);
                TransferCounter.Add(1, new KeyValuePair<string, object?>("status", "error"));
                return Results.Problem("Error processing transfer");
            }
        })
        .WithName("TransferFunds")
        .WithTags("Transactions")
        .Produces<TransactionResponse>(StatusCodes.Status200OK)
        .Produces<ErrorResponse>(StatusCodes.Status400BadRequest)
        .Produces<ErrorResponse>(StatusCodes.Status404NotFound);
    }
}

