/**
 * Jolinx Business OS — $0 Multi-Cloud Cloudflare Failover + Keep-Warm Worker
 * Domain: https://api.joberthix.xyz
 *
 * Features:
 * 1. Automatic Keep-Warm (Cron Trigger `*/10 * * * *`):
 *    Pings PRIMARY_ORIGIN/health/live every 10 minutes so Render never spins down
 *    into a 50-second cold start (Render Free gives 750 hrs/mo; a 31-day month is 744 hrs).
 * 2. Smart Failover Routing:
 *    - Forwards incoming requests to PRIMARY_ORIGIN (Render) with a 25s timeout.
 *    - If PRIMARY_ORIGIN times out or returns 502/503/504/52x, automatically retries
 *      BACKUP_ORIGIN (if configured) or retries PRIMARY_ORIGIN once more.
 */

const DEFAULT_PRIMARY_ORIGIN = "https://jolinx-api.kindsky-ea584b9f.centralindia.azurecontainerapps.io";
const DEFAULT_BACKUP_ORIGIN = "https://jolinx-api.kindsky-ea584b9f.centralindia.azurecontainerapps.io";
const DEFAULT_STAGING_ORIGIN = "https://jolinx-api-staging.kindsky-ea584b9f.centralindia.azurecontainerapps.io";
const FAILOVER_STATUS_CODES = new Set([502, 503, 504, 520, 521, 522, 523, 524, 530]);
const PRIMARY_TIMEOUT_MS = 25000;
const BACKUP_TIMEOUT_MS = 28000;

export default {
  async fetch(request, env) {
    const primaryOrigin = (env.PRIMARY_ORIGIN || DEFAULT_PRIMARY_ORIGIN).replace(/\/+$/, "");
    const backupOrigin = (env.BACKUP_ORIGIN || DEFAULT_BACKUP_ORIGIN).replace(/\/+$/, "");

    const incomingUrl = new URL(request.url);
    const pathAndQuery = incomingUrl.pathname + incomingUrl.search;

    let bodyBuffer = null;
    if (request.method !== "GET" && request.method !== "HEAD") {
      bodyBuffer = await request.arrayBuffer();
    }

    // Detect Staging requests via subdomain (staging-api.joberthix.xyz) or header
    const isStaging =
      incomingUrl.hostname.startsWith("staging-api") ||
      incomingUrl.hostname.startsWith("api-staging") ||
      request.headers.get("x-jolinx-environment") === "staging";

    if (isStaging) {
      const stagingOrigin = (env.STAGING_ORIGIN || DEFAULT_STAGING_ORIGIN).replace(/\/+$/, "");
      try {
        const stagingResponse = await forwardRequest(
          request,
          stagingOrigin + pathAndQuery,
          bodyBuffer,
          PRIMARY_TIMEOUT_MS,
        );
        return withUpstreamHeader(stagingResponse, "staging");
      } catch (err) {
        return new Response(
          JSON.stringify({
            title: "Staging Backend Unavailable",
            detail: "Seva ya Staging haipatikani kwa sasa. Hakikisha staging backend inafanya kazi.",
            status: 503,
            environment: "staging",
            code: "StagingUpstreamUnavailable",
          }),
          {
            status: 503,
            headers: {
              "content-type": "application/problem+json; charset=utf-8",
              "x-jolinx-upstream": "staging-none",
              "x-jolinx-environment": "staging",
            },
          },
        );
      }
    }

    // --- Production Routing with Multi-Cloud Failover ---
    // 1. Try Primary Origin (Production)
    try {
      const primaryResponse = await forwardRequest(
        request,
        primaryOrigin + pathAndQuery,
        bodyBuffer,
        PRIMARY_TIMEOUT_MS,
      );

      if (!FAILOVER_STATUS_CODES.has(primaryResponse.status)) {
        return withUpstreamHeader(primaryResponse, "production-primary");
      }
    } catch (_) {
      // Primary offline or timed out — seamlessly failover to backup below!
    }

    // 2. Try Backup Origin if configured and distinct from primary
    if (backupOrigin && backupOrigin !== primaryOrigin) {
      try {
        const backupResponse = await forwardRequest(
          request,
          backupOrigin + pathAndQuery,
          bodyBuffer,
          BACKUP_TIMEOUT_MS,
        );
        if (backupResponse.status !== 404 && !FAILOVER_STATUS_CODES.has(backupResponse.status)) {
          return withUpstreamHeader(backupResponse, "backup");
        }
      } catch (_) {
        // Backup also unavailable — fall through to second primary attempt.
      }
    }

    // 3. Second attempt on Primary (in case primary just finished waking up from cold start)
    try {
      const retryResponse = await forwardRequest(
        request,
        primaryOrigin + pathAndQuery,
        bodyBuffer,
        BACKUP_TIMEOUT_MS,
      );
      return withUpstreamHeader(retryResponse, "primary-retry");
    } catch (_) {
      return new Response(
        JSON.stringify({
          title: "Service Unavailable",
          detail: "Huduma ya seva haipatikani kwa sasa. Tafadhali jaribu tena baada ya muda mfupi.",
          status: 503,
          code: "UpstreamUnavailable",
        }),
        {
          status: 503,
          headers: {
            "content-type": "application/problem+json; charset=utf-8",
            "x-jolinx-upstream": "none",
          },
        },
      );
    }
  },

  // Automatic Keep-Warm Cron Handler (runs every 10 min so Render never goes to sleep)
  async scheduled(_event, env, ctx) {
    const prodOrigin = (env.BACKUP_ORIGIN || DEFAULT_BACKUP_ORIGIN).replace(/\/+$/, "");
    const stagingOrigin = (env.STAGING_ORIGIN || DEFAULT_STAGING_ORIGIN).replace(/\/+$/, "");
    ctx.waitUntil(
      Promise.allSettled([
        fetch(prodOrigin + "/health/live", {
          method: "GET",
          headers: { "User-Agent": "Jolinx-Cloudflare-KeepWarm/1.0" },
        }).catch(() => {}),
        fetch(stagingOrigin + "/health/live", {
          method: "GET",
          headers: { "User-Agent": "Jolinx-Cloudflare-KeepWarm/1.0" },
        }).catch(() => {}),
      ]),
    );
  },
};

async function forwardRequest(originalRequest, targetUrl, bodyBuffer, timeoutMs) {
  const headers = new Headers(originalRequest.headers);
  headers.set("X-Forwarded-Host", new URL(originalRequest.url).host);
  headers.set("X-Forwarded-Proto", "https");

  if (originalRequest.cf) {
    if (originalRequest.cf.botManagement?.score !== undefined) {
      headers.set("CF-Bot-Score", String(originalRequest.cf.botManagement.score));
    }
    if (originalRequest.cf.tlsJa3Hash) {
      headers.set("CF-JA3-Fingerprint", originalRequest.cf.tlsJa3Hash);
    }
    if (originalRequest.cf.country) {
      headers.set("CF-IPCountry", originalRequest.cf.country);
    }
  }

  return fetch(targetUrl, {
    method: originalRequest.method,
    headers,
    body: bodyBuffer,
    redirect: "manual",
    signal: AbortSignal.timeout(timeoutMs),
  });
}

function withUpstreamHeader(response, upstreamName) {
  const headers = new Headers(response.headers);
  headers.set("x-jolinx-upstream", upstreamName);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
