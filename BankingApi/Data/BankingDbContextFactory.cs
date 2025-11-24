using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace BankingApi.Data;

public class BankingDbContextFactory : IDesignTimeDbContextFactory<BankingDbContext>
{
    public BankingDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<BankingDbContext>();
        // Connection string para design-time (será sobrescrita em runtime)
        optionsBuilder.UseNpgsql("Host=localhost;Port=5432;Database=bankingdb;Username=banking;Password=banking_pwd");

        return new BankingDbContext(optionsBuilder.Options);
    }
}

