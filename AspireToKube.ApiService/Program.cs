using AspireToKube.ApiService.Extensions;
using AspireToKube.ApiService.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults & Aspire client integrations.
builder.AddServiceDefaults();

// Add services to the container.
builder.Services.AddProblemDetails();

builder.AddSqlServerDbContext<ApplicationDbContext>("ecsdb");

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

string[] summaries = ["Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"]; 

app.MapGet("/", () => "API service is running. Navigate to /zombies to see sample data.");

app.MapGet("/zombies", async (ApplicationDbContext db) =>
{
    var zombies = await db.Zombies.ToListAsync();
    return zombies.Any() ? zombies : [new Zombie { Id = 0, Name = "Kos Lis", BrainsConsumed = 80, FavoriteHumanPart = Zombie.HumanPart.Brain, IsDangerous = true, Type = "Kale kiri"}];
})
.WithName("GetWeatherForecast");

app.MapDefaultEndpoints();

app.CallDbInitializer();

app.Run();