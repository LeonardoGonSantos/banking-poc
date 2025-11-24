using System.Diagnostics;
using BankingApi.Data;
using BankingApi.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace BankingApi.Endpoints;

public static class AuthEndpoint
{
    public static void MapAuthEndpoint(this IEndpointRouteBuilder app)
    {
        app.MapPost("/auth/login", async (LoginRequest request, BankingDbContext db) =>
        {
            using var activity = new ActivitySource("BankingApi.Traces").StartActivity("AuthLogin");
            activity?.SetTag("auth.email", request.Email);

            try
            {
                var user = await db.Users
                    .FirstOrDefaultAsync(u => u.Email == request.Email);

                if (user == null)
                {
                    Log.Warning("Invalid login attempt for email: {Email}", request.Email);
                    return Results.Unauthorized();
                }

                // Verificar senha (hash fake: "fake-hash-{password}")
                var expectedHash = $"fake-hash-{request.Password}";
                if (user.PasswordHash != expectedHash)
                {
                    Log.Warning("Invalid login attempt for email: {Email}", request.Email);
                    return Results.Unauthorized();
                }

                var token = Guid.NewGuid().ToString();
                
                Log.Information("User logged in successfully: {Email}, UserId: {UserId}", request.Email, user.Id);
                
                return Results.Ok(new LoginResponse(token));
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Error during login for email: {Email}", request.Email);
                return Results.StatusCode(500);
            }
        })
        .WithName("Login")
        .WithTags("Auth")
        .Produces<LoginResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status401Unauthorized);
    }
}

