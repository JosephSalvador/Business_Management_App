using Asp.Versioning.Builder;
using Microsoft.AspNetCore.Mvc;

namespace BusinessOS.Api.Endpoints;

public static class AppVersionEndpoints
{
    public static IEndpointRouteBuilder MapAppVersionEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var appGroup = api.MapGroup("/app")
            .WithApiVersionSet(versionSet)
            .WithTags("AppDistribution")
            .AllowAnonymous()
            .RequireRateLimiting("global");

        appGroup.MapGet("/version", GetAppVersionAsync)
            .WithName("GetAppVersion")
            .WithSummary("Check latest application version, build number, and OTA update manifest.");

        appGroup.MapGet("/download/android", DownloadAndroidApkAsync)
            .WithName("DownloadAndroidApk")
            .WithSummary("Direct redirect to latest Android APK download.");

        appGroup.MapGet("/download/ios", DownloadIosPwaAsync)
            .WithName("DownloadIosPwa")
            .WithSummary("Direct redirect to Apple iOS PWA distribution URL.");

        return app;
    }

    private static IResult GetAppVersionAsync(IConfiguration config)
    {
        var section = config.GetSection("AppDistribution");

        var response = new AppVersionResponse(
            Version: section["LatestVersion"] ?? "1.0.0",
            BuildNumber: int.TryParse(section["BuildNumber"], out var b) ? b : 10,
            MinSupportedBuild: int.TryParse(section["MinSupportedBuild"], out var m) ? m : 8,
            AndroidApkUrl: section["AndroidApkUrl"] ?? "https://github.com/JosephSalvador/Business_Management_App/releases/download/latest/jolinx-android.apk",
            WebPwaUrl: section["WebPwaUrl"] ?? "https://staging.jolinx-app.pages.dev",
            ReleaseNotesSw: section["ReleaseNotesSw"] ?? "Maboresho ya mfumo wa mauzo, risiti za Bluetooth, na usasishaji wa haraka wa ndani kwa ndani bila Google Play Store.",
            ReleaseNotesEn: section["ReleaseNotesEn"] ?? "System enhancements, Bluetooth receipt printing, and instant in-place auto-updates without app stores.",
            ForceUpdate: bool.TryParse(section["ForceUpdate"], out var f) && f,
            ReleasedAt: DateTimeOffset.UtcNow
        );

        return Results.Ok(response);
    }

    private static IResult DownloadAndroidApkAsync(IConfiguration config)
    {
        var url = config["AppDistribution:AndroidApkUrl"] 
            ?? "https://github.com/JosephSalvador/Business_Management_App/releases/download/latest/jolinx-android.apk";
        return Results.Redirect(url);
    }

    private static IResult DownloadIosPwaAsync(IConfiguration config)
    {
        var url = config["AppDistribution:WebPwaUrl"] 
            ?? "https://staging.jolinx-app.pages.dev";
        return Results.Redirect(url);
    }

    public sealed record AppVersionResponse(
        string Version,
        int BuildNumber,
        int MinSupportedBuild,
        string AndroidApkUrl,
        string WebPwaUrl,
        string ReleaseNotesSw,
        string ReleaseNotesEn,
        bool ForceUpdate,
        DateTimeOffset ReleasedAt
    );
}
