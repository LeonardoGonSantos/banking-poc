namespace BankingApi.DTOs;

public record TransactionResponse(
    Guid Id,
    Guid FromAccountId,
    Guid ToAccountId,
    decimal Amount,
    DateTime CreatedAt,
    string Type
);

