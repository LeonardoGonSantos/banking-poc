using System.Diagnostics;
using BankingApi.Data;
using BankingApi.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace BankingApi.Endpoints;

public static class AccountsEndpoint
{
    public static void MapAccountsEndpoint(this IEndpointRouteBuilder app)
    {
        app.MapPost("/accounts", async (CreateAccountRequest request, BankingDbContext db) =>
        {
            using var activity = new ActivitySource("BankingApi.Traces").StartActivity("CreateAccount");
            activity?.SetTag("account.initialBalance", request.InitialBalance);
            activity?.SetTag("account.userEmail", request.Email);

            try
            {
                // Buscar usuário informado no request
                var user = await db.Users
                    .FirstOrDefaultAsync(u => u.Email == request.Email);

                if (user == null)
                {
                    Log.Warning("User not found for account creation: {Email}", request.Email);
                    return Results.BadRequest(new ErrorResponse("User not found"));
                }

                var account = new Models.Account
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    Balance = request.InitialBalance,
                    CreatedAt = DateTime.UtcNow
                };

                db.Accounts.Add(account);
                await db.SaveChangesAsync();

                Log.Information("Account created: AccountId: {AccountId}, UserId: {UserId}, InitialBalance: {InitialBalance}",
                    account.Id, user.Id, request.InitialBalance);

                return Results.Ok(new CreateAccountResponse(account.Id, account.Balance));
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error creating account");
                return Results.Problem("Error creating account");
            }
        })
        .WithName("CreateAccount")
        .WithTags("Accounts")
        .Produces<CreateAccountResponse>(StatusCodes.Status200OK);
    }
}

