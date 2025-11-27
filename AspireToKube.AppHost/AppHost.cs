var builder = DistributedApplication.CreateBuilder(args);

//Redis
var cache = builder.AddRedis("cache");

var password = builder.AddParameter("password", secret: true);

//MSSQL 
var sqlServer = builder.AddSqlServer("sql", password)
    .WithDataVolume() // Persist data
    .WithLifetime(ContainerLifetime.Persistent)
    .AddDatabase("ecsdb");

var apiService = builder.AddProject<Projects.AspireToKube_ApiService>("apiservice")
    .WithHttpHealthCheck("/health").WaitFor(sqlServer).WithReference(sqlServer);

builder.AddProject<Projects.AspireToKube_Web>("webfrontend")
    .WithExternalHttpEndpoints()
    .WithHttpHealthCheck("/health")
    .WithReference(cache)
    .WaitFor(cache)
    .WithReference(apiService)
    .WaitFor(apiService);

builder.Build().Run();
