using System.Diagnostics;
using BankingApi.Data;
using BankingApi.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace BankingApi.Endpoints;

public static class UsersEndpoint
{
    public static void MapUsersEndpoint(this IEndpointRouteBuilder app)
    {
        app.MapPost("/users", async (CreateUserRequest request, BankingDbContext db) =>
        {
            using var activity = new ActivitySource("BankingApi.Traces").StartActivity("CreateUser");
            activity?.SetTag("user.email", request.Email);
            activity?.SetTag("user.name", request.Name);

            try
            {
                // Verificar se email já existe
                var existingUser = await db.Users
                    .FirstOrDefaultAsync(u => u.Email == request.Email);

                if (existingUser != null)
                {
                    Log.Warning("User already exists with email: {Email}", request.Email);
                    return Results.BadRequest(new ErrorResponse("User with this email already exists"));
                }

                // Criar usuário
                var user = new Models.User
                {
                    Id = Guid.NewGuid(),
                    Name = request.Name,
                    Email = request.Email,
                    PasswordHash = $"fake-hash-{request.Password}" // Hash fake para POC
                };

                db.Users.Add(user);

                // Criar conta inicial para o usuário
                var account = new Models.Account
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    Balance = request.InitialBalance,
                    CreatedAt = DateTime.UtcNow
                };

                db.Accounts.Add(account);
                await db.SaveChangesAsync();

                // Gerar token fake
                var token = Guid.NewGuid().ToString();

                Log.Information("User and account created: UserId: {UserId}, AccountId: {AccountId}, Email: {Email}, InitialBalance: {InitialBalance}",
                    user.Id, account.Id, request.Email, request.InitialBalance);

                return Results.Ok(new CreateUserResponse(user.Id, account.Id, token));
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error creating user: {Email}", request.Email);
                return Results.Problem("Error creating user");
            }
        })
        .WithName("CreateUser")
        .WithTags("Users")
        .Produces<CreateUserResponse>(StatusCodes.Status200OK)
        .Produces<ErrorResponse>(StatusCodes.Status400BadRequest);
    }
}

