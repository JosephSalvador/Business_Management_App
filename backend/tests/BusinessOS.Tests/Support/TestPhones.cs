using System.Threading;

namespace BusinessOS.Tests.Support;

/// <summary>
/// Generates E.164 phone numbers that are unique across test runs, not just
/// within one process, because the shared test database keeps rows from
/// earlier runs. The random 9-digit seed spreads each run's numbers over a
/// wide space so successive runs virtually never collide.
/// </summary>
public static class TestPhones
{
    private static long _next = new Random(Guid.NewGuid().GetHashCode()).Next(100_000_000, 900_000_000);

    public static string Next() => $"255{Interlocked.Increment(ref _next):D9}";
}
