namespace BankingApi.DTOs;

public record CreateUserResponse(Guid UserId, Guid AccountId, string Token);

