using AspireToKube.ApiService.Models;
using Microsoft.EntityFrameworkCore;

internal class ApplicationDbContext : DbContext
{
    public ApplicationDbContext()
    {
    }

    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    public virtual DbSet<Zombie> Zombies { get; set; }


    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);
        builder.HasDefaultSchema("dbo");
    }
}