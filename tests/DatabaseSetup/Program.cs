using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage;
using Npgsql;
using Octopets.Backend.Data;
using Octopets.Backend.Models;

try
{
    var connection = Environment.GetEnvironmentVariable("OCTOPETS_SETUP_CONNECTION")
        ?? throw new InvalidOperationException("Setup connection missing.");
    var expectedHost = Environment.GetEnvironmentVariable("OCTOPETS_SETUP_HOST")
        ?? throw new InvalidOperationException("Expected host missing.");
    var appPassword = Environment.GetEnvironmentVariable("OCTOPETS_APP_PASSWORD")
        ?? throw new InvalidOperationException("App password missing.");
    var settings = new NpgsqlConnectionStringBuilder(connection);
    if (settings.Host != expectedHost || !expectedHost.StartsWith("octopets-abarca-pg-", StringComparison.Ordinal)
        || !expectedHost.EndsWith(".postgres.database.azure.com", StringComparison.Ordinal)
        || settings.Database != "octopetsdb" || settings.SslMode != SslMode.VerifyFull)
    {
        throw new InvalidOperationException("Setup target is outside the dedicated TLS-verified demo database.");
    }

    var options = new DbContextOptionsBuilder<AppDbContext>().UseNpgsql(connection)
        .ConfigureWarnings(warnings => warnings.Ignore(RelationalEventId.PendingModelChangesWarning)).Options;
    await using var db = new AppDbContext(options);
    // Schema changes are explicit deployment work; the runtime role will not have DDL rights.
    await db.Database.MigrateAsync();
    await using var transaction = await db.Database.BeginTransactionAsync();
    if (await db.Listings.AnyAsync() || await db.Reviews.AnyAsync())
    {
        throw new InvalidOperationException("Refusing to overwrite an already populated database.");
    }

    var names = new[] { "Pawsome Park", "Whiskers Cafe", "Pet Haven Home", "Pets & Pillows Hotel", "Furry Friends Store", "Mooch's Meow" };
    var photos = new[] { "park", "cafe", "home", "hotel", "store", "moochs" };
    var types = new[] { "Park", "Cafe", "Home", "Hotel", "Store", "Cafe" };
    for (var index = 0; index < names.Length; index++)
    {
        db.Listings.Add(new Listing
        {
            Id = index + 1,
            Name = names[index],
            Description = "Synthetic Octopets demonstration listing. Not customer data.",
            Location = "Demo City",
            Address = $"{index + 1} Demo Lane",
            Type = types[index],
            Price = 10 + index * 5,
            AllowedPets = ["Dogs", "Cats"],
            Amenities = ["Parking", "Water"],
            Rating = 5,
            Photos = [$"{photos[index]}1.jpg", $"{photos[index]}2.jpg"],
            CreatedAt = DateTime.UtcNow,
            Reviews = [new Review
            {
                Reviewer = "Synthetic Demo Reviewer",
                Rating = 5,
                Comment = "Synthetic review for demonstration only.",
                CreatedAt = DateTime.UtcNow
            }]
        });
    }
    await db.SaveChangesAsync();
    await db.Database.ExecuteSqlRawAsync("SELECT setval(pg_get_serial_sequence('\"Listings\"', 'Id'), (SELECT MAX(\"Id\") FROM \"Listings\"))");

    await using var command = ((NpgsqlConnection)db.Database.GetDbConnection()).CreateCommand();
    command.Transaction = (NpgsqlTransaction)transaction.GetDbTransaction();
    command.CommandText = "SELECT format('CREATE ROLE octopets_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L', @password)";
    command.Parameters.AddWithValue("password", appPassword);
    var createRole = (string)(await command.ExecuteScalarAsync())!;
    command.Parameters.Clear();
    command.CommandText = createRole;
    await command.ExecuteNonQueryAsync();
    command.CommandText = """
        REVOKE CREATE ON SCHEMA public FROM PUBLIC;
        GRANT CONNECT ON DATABASE octopetsdb TO octopets_app;
        GRANT USAGE ON SCHEMA public TO octopets_app;
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "Listings", "Reviews" TO octopets_app;
        GRANT SELECT ON TABLE "__EFMigrationsHistory" TO octopets_app;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO octopets_app;
        """;
    await command.ExecuteNonQueryAsync();
    await transaction.CommitAsync();
    Console.WriteLine(JsonSerializer.Serialize(new { SyntheticListings = 6, SyntheticReviews = 6, RuntimeRole = "octopets_app", SchemaInitialized = true }));
}
catch (Exception exception)
{
    // Setup diagnostics must never disclose SQL containing a password or a connection string.
    Console.Error.WriteLine(JsonSerializer.Serialize(new { SetupFailed = true, ErrorType = exception.GetType().Name }));
    Environment.ExitCode = 1;
}