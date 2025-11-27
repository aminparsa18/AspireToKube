using Microsoft.EntityFrameworkCore;

namespace AspireToKube.ApiService.Extensions;

public static class AppBuilderExtensions
{
    public static void CallDbInitializer(this IApplicationBuilder app)
    {
        var scopeFactory = app.ApplicationServices.GetRequiredService<IServiceScopeFactory>();
        using var scope = scopeFactory.CreateScope();
        using var context = scope.ServiceProvider.GetService<ApplicationDbContext>();
        context.Database.EnsureCreated();
        context.Database.Migrate();
    }
}
