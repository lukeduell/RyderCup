using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using RyderCup.Api.Data;
using RyderCup.Api.Endpoints;

// Default to Development environment when running locally. Production deploys
// (Railway/Docker) set ASPNETCORE_ENVIRONMENT=Production explicitly, so this only
// affects local runs that bypass launchSettings.json (e.g. running the binary directly
// from an IDE).
if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")))
{
    Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Development");
}

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .AllowAnyOrigin()
    .AllowAnyHeader()
    .AllowAnyMethod()));

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter(System.Text.Json.JsonNamingPolicy.CamelCase));
});

string? source = null;
string? connectionString = Environment.GetEnvironmentVariable("DATABASE_URL");
if (!string.IsNullOrWhiteSpace(connectionString)) source = "DATABASE_URL env var";
if (string.IsNullOrWhiteSpace(connectionString))
{
    connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    if (!string.IsNullOrWhiteSpace(connectionString))
        source = "ConnectionStrings:DefaultConnection in appsettings";
}
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        $"No database connection string found. Environment is '{builder.Environment.EnvironmentName}'. " +
        "Set the DATABASE_URL environment variable (Railway), or paste your Neon connection " +
        "string into backend/appsettings.Development.json under ConnectionStrings:DefaultConnection (local).");
}

Console.WriteLine($"[startup] env={builder.Environment.EnvironmentName} | DB from: {source}");

// Railway / Neon supply a postgres:// URI; convert it to Npgsql key/value form.
connectionString = ConnectionStringNormalizer.Normalize(connectionString);

builder.Services.AddDbContext<RyderCupDbContext>(o =>
    o.UseNpgsql(connectionString, npgsql => npgsql.EnableRetryOnFailure(
        maxRetryCount: 5,
        maxRetryDelay: TimeSpan.FromSeconds(10),
        errorCodesToAdd: null)));

var app = builder.Build();

// Neon free-tier databases auto-suspend after a few minutes idle. The first
// connection has to wake them up, which can blow past Npgsql's default 15s
// timeout. Retry a few times before giving up.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<RyderCupDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    const int maxAttempts = 6;
    for (int attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            db.Database.Migrate();
            logger.LogInformation("Database migrations applied successfully.");
            break;
        }
        catch (Exception ex) when (attempt < maxAttempts)
        {
            var delay = TimeSpan.FromSeconds(Math.Min(30, 3 * attempt));
            logger.LogWarning(
                "Migrate attempt {Attempt}/{Max} failed ({Message}). Retrying in {Delay}s (Neon may be waking up)…",
                attempt, maxAttempts, ex.Message, delay.TotalSeconds);
            Thread.Sleep(delay);
        }
    }
}

app.UseCors();

app.MapGet("/", () => Results.Ok(new { ok = true, service = "RyderCup API" }));
app.MapGet("/health", () => Results.Ok(new { ok = true }));

TournamentEndpoints.Map(app);
ScoreEndpoints.Map(app);
SideGameEndpoints.Map(app);

app.Run();

static class ConnectionStringNormalizer
{
    /// Accepts either a postgres URI (`postgresql://user:pass@host/db?...`) or
    /// Npgsql key/value form (`Host=...;Database=...;...`) and returns a key/value
    /// string with our resilience settings layered on top (long timeouts +
    /// keep-alive for Neon's cold-start behaviour).
    public static string Normalize(string raw)
    {
        Npgsql.NpgsqlConnectionStringBuilder b;

        if (raw.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)
            || raw.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
        {
            var uri = new Uri(raw);
            var userInfo = uri.UserInfo.Split(':', 2);
            var user = Uri.UnescapeDataString(userInfo[0]);
            var pass = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
            var db = uri.AbsolutePath.TrimStart('/');
            b = new Npgsql.NpgsqlConnectionStringBuilder
            {
                Host = uri.Host,
                Port = uri.Port <= 0 ? 5432 : uri.Port,
                Username = user,
                Password = pass,
                Database = db,
                SslMode = Npgsql.SslMode.Require,
            };

            // Honour explicit ?channel_binding=... and ?sslmode=... query params.
            var query = System.Web.HttpUtility.ParseQueryString(uri.Query);
            var cb = query["channel_binding"];
            if (string.Equals(cb, "require", StringComparison.OrdinalIgnoreCase))
                b.ChannelBinding = Npgsql.ChannelBinding.Require;
            else if (string.Equals(cb, "disable", StringComparison.OrdinalIgnoreCase))
                b.ChannelBinding = Npgsql.ChannelBinding.Disable;
            else if (string.Equals(cb, "prefer", StringComparison.OrdinalIgnoreCase))
                b.ChannelBinding = Npgsql.ChannelBinding.Prefer;
            var sm = query["sslmode"];
            if (!string.IsNullOrEmpty(sm) && Enum.TryParse<Npgsql.SslMode>(sm, ignoreCase: true, out var smv))
                b.SslMode = smv;

            // Pass through other query params Npgsql understands (e.g. options=endpoint%3D...)
            var opt = query["options"];
            if (!string.IsNullOrEmpty(opt)) b.Options = opt;
        }
        else
        {
            // Already in key/value form. Just parse it.
            b = new Npgsql.NpgsqlConnectionStringBuilder(raw);
        }

        // Always layer in our resilience settings — only set them if the user
        // hasn't overridden. Neon's compute can take 10–30s to wake from suspend.
        if (b.Timeout == 15) b.Timeout = 60;            // Npgsql default is 15s
        if (b.CommandTimeout == 30) b.CommandTimeout = 60; // Npgsql default is 30s
        if (b.KeepAlive == 0) b.KeepAlive = 30;         // disabled by default

        return b.ConnectionString;
    }
}
