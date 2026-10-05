namespace BusinessOS.Domain.Services;

/// <summary>
/// Derives a short, human-readable device name from a user-agent string for the sessions
/// page. Recognition, not identification: the goal is that a shop owner can tell "my
/// phone" from "a laptop I do not recognise", not to fingerprint a browser.
/// </summary>
public static class DeviceLabel
{
    private const int MaxLength = 60;
    private const string Unknown = "Unknown device";

    public static string FromUserAgent(string? userAgent)
    {
        if (string.IsNullOrWhiteSpace(userAgent))
        {
            return Unknown;
        }

        var platform = DetectPlatform(userAgent);
        var browser = DetectBrowser(userAgent);

        if (platform is null && browser is null)
        {
            return Unknown;
        }

        if (platform is null)
        {
            return Trim(browser!);
        }

        return browser is null ? Trim(platform) : Trim($"{browser} on {platform}");
    }

    private static string? DetectPlatform(string ua)
    {
        if (ua.Contains("iPhone", StringComparison.OrdinalIgnoreCase)) return "iPhone";
        if (ua.Contains("iPad", StringComparison.OrdinalIgnoreCase)) return "iPad";
        if (ua.Contains("Android", StringComparison.OrdinalIgnoreCase)) return "Android";
        if (ua.Contains("Windows", StringComparison.OrdinalIgnoreCase)) return "Windows";
        if (ua.Contains("Mac OS", StringComparison.OrdinalIgnoreCase)
            || ua.Contains("Macintosh", StringComparison.OrdinalIgnoreCase)) return "Mac";
        if (ua.Contains("Linux", StringComparison.OrdinalIgnoreCase)) return "Linux";
        if (ua.Contains("Chrome OS", StringComparison.OrdinalIgnoreCase)) return "Chrome OS";

        return null;
    }

    private static string? DetectBrowser(string ua)
    {
        // Order matters: Edge and Chrome both advertise "Safari", and Chrome advertises
        // "Chrome OS" as a platform token, so the most specific marker must win.
        if (ua.Contains("Edg/", StringComparison.OrdinalIgnoreCase)) return "Edge";
        if (ua.Contains("OPR/", StringComparison.OrdinalIgnoreCase)) return "Opera";
        if (ua.Contains("Firefox", StringComparison.OrdinalIgnoreCase)) return "Firefox";
        if (ua.Contains("Chrome", StringComparison.OrdinalIgnoreCase)) return "Chrome";
        if (ua.Contains("Safari", StringComparison.OrdinalIgnoreCase)) return "Safari";

        return null;
    }

    private static string Trim(string label)
        => label.Length <= MaxLength ? label : label[..MaxLength];
}

/// <summary>Shared display helpers for session projections.</summary>
public static class SessionPresentation
{
    /// <summary>
    /// Friendly fallback when a login arrived without a user-agent header (some API clients
    /// omit it). Falls back to the network address, which is still more useful than blank.
    /// </summary>
    public static string DescribeDevice(string? deviceLabel, string? ipAddress)
    {
        if (!string.IsNullOrWhiteSpace(deviceLabel))
        {
            return deviceLabel;
        }

        return string.IsNullOrWhiteSpace(ipAddress) ? "Unknown device" : ipAddress;
    }

    public static bool IsCurrentSession(Guid familyId, Guid currentFamilyId) => familyId == currentFamilyId;
}
