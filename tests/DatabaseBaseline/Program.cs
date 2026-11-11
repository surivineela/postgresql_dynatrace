using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Octopets.Backend.Data;

// Read-only gate: a new app revision must not silently apply migrations or rewrite photos.
var connection = Environment.GetEnvironmentVariable("ConnectionStrings__octopetsdb")
    ?? throw new InvalidOperationException("Database connection is required in the environment.");
var options = new DbContextOptionsBuilder<AppDbContext>().UseNpgsql(connection).Options;
await using var db = new AppDbContext(options);
await db.Database.OpenConnectionAsync();
await db.Database.ExecuteSqlRawAsync("SET default_transaction_read_only = on");
var pending = (await db.Database.GetPendingMigrationsAsync()).ToArray();
var listings = await db.Listings.AsNoTracking().Where(listing => listing.Id >= 1 && listing.Id <= 6).ToListAsync();
var photoUpdates = listings.Count(listing => listing.Photos is null || listing.Photos.Count == 0
    || listing.Photos.Any(photo => photo.Contains("/images/venues/")));
await using var permissions = ((NpgsqlConnection)db.Database.GetDbConnection()).CreateCommand();
permissions.CommandText = "SELECT has_schema_privilege(current_user, 'public', 'CREATE') OR (SELECT rolsuper OR rolcreatedb OR rolcreaterole FROM pg_roles WHERE rolname = current_user)";
var runtimeHasDdl = (bool)(await permissions.ExecuteScalarAsync())!;
Console.WriteLine(JsonSerializer.Serialize(new { PendingMigrationCount = pending.Length, PhotoUpdatesRequired = photoUpdates, ListingCount = listings.Count, RuntimeHasDdl = runtimeHasDdl }));
if (pending.Length != 0 || photoUpdates != 0 || listings.Count != 6 || runtimeHasDdl) Environment.ExitCode = 1;