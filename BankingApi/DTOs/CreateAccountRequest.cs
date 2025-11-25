namespace BankingApi.DTOs;

public record CreateAccountRequest(string Email, decimal InitialBalance);

