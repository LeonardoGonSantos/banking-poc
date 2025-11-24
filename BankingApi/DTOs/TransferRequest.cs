namespace BankingApi.DTOs;

public record TransferRequest(Guid FromAccountId, Guid ToAccountId, decimal Amount);

