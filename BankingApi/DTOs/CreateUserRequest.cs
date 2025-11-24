namespace BankingApi.DTOs;

public record CreateUserRequest(string Name, string Email, string Password, decimal InitialBalance);

