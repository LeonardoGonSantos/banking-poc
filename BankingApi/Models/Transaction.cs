namespace BankingApi.Models;

public class Transaction
{
    public Guid Id { get; set; }
    public Guid FromAccountId { get; set; }
    public Guid ToAccountId { get; set; }
    public decimal Amount { get; set; }
    public DateTime CreatedAt { get; set; }
    public string Type { get; set; } = string.Empty; // "CREDIT", "DEBIT", "TRANSFER"
    
    public Account FromAccount { get; set; } = null!;
    public Account ToAccount { get; set; } = null!;
}

