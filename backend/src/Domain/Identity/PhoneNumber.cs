namespace BusinessOS.Domain.Identity;

/// <summary>
/// Normalizes merchant phone input to E.164. The default country is Tanzania
/// (+255): a bare local number such as 0712345678 is treated as Tanzanian.
/// Kenya (+254) and Uganda (+256) are honoured only when dialled explicitly
/// with their country codes.
/// </summary>
public static class PhoneNumber
{
    public static readonly string[] SupportedCountryCodes = ["255", "254", "256"];

    /// <summary>Returns the canonical E.164 form, or null when unparseable.</summary>
    public static string? Normalize(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return null;
        }

        var cleaned = new string(input
            .Where(char.IsDigit)
            .ToArray());
        var hasPlus = input.TrimStart().StartsWith('+');

        if (cleaned.Length == 0)
        {
            return null;
        }

        if (hasPlus || input.TrimStart().StartsWith("00"))
        {
            var digits = hasPlus ? cleaned : cleaned[2..];
            return IsValidE164(digits) ? "+" + digits : null;
        }

        foreach (var code in SupportedCountryCodes)
        {
            if (cleaned.StartsWith(code) && cleaned.Length == code.Length + 9)
            {
                return "+" + cleaned;
            }
        }

        if (cleaned.StartsWith('0') && cleaned.Length == 10)
        {
            return "+255" + cleaned[1..];
        }

        return null;
    }

    public static bool IsNormalizable(string? input) => Normalize(input) is not null;

    private static bool IsValidE164(string digits) => digits.Length is >= 9 and <= 15;
}
