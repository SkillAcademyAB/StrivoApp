using StrivoApp.Api.Data;
using StrivoApp.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Controllers
builder.Services.AddControllers();

// Swagger / OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title   = "StrivoApp API",
        Version = "v1",
        Description = "A demonstration REST API built with ASP.NET Core 8."
    });
});

// Data layer
builder.Services.AddSingleton<IItemRepository, ItemRepository>();

// Service layer
builder.Services.AddScoped<IItemService, ItemService>();

var app = builder.Build();

// Swagger UI (available in all environments for demonstration purposes)
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "StrivoApp API v1");
    options.RoutePrefix = string.Empty; // Serve Swagger UI at the app root
});

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
