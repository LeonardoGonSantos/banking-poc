using Microsoft.EntityFrameworkCore;
using BankingApi.Models;

namespace BankingApi.Data;

public static class DataSeeder
{
    public static async Task SeedAsync(BankingDbContext context)
    {
        if (await context.Users.AnyAsync())
        {
            return; // Já tem dados
        }

        // Criar usuário seed com dados aleatórios (ou fixos, mas com cara de aleatório)
        var randomSuffix = new Random().Next(1000, 9999);
        var user = new User
        {
            Id = Guid.NewGuid(),
            Name = "Test User",
            Email = $"user-{randomSuffix}@test.com",
            PasswordHash = "fake-hash-123456" // Hash fake para POC
        };

        context.Users.Add(user);

        // Criar 2 contas para o usuário
        var accountA = new Account
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Balance = 1000.00m,
            CreatedAt = DateTime.UtcNow
        };

        var accountB = new Account
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Balance = 500.00m,
            CreatedAt = DateTime.UtcNow
        };

        context.Accounts.AddRange(accountA, accountB);
        await context.SaveChangesAsync();
    }
}

