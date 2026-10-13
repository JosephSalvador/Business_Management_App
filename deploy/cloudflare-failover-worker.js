/**
 * Jolinx Business OS — $0 Multi-Cloud Cloudflare Failover Worker
 * Domain: https://api.joberthix.xyz
 *
 * How to deploy (Free on Cloudflare Workers — 100,000 requests/day):
 * 1. Open Cloudflare Dashboard -> Workers & Pages -> Create Worker -> Name it `jolinx-api-router`.
 * 2. Paste this script into the Worker editor and click "Deploy".
 * 3. In the Worker's Settings -> Domains & Routes -> Add Custom Domain: `api.joberthix.xyz`.
 * 4. Optional: In Settings -> Variables, set:
 *    - PRIMARY_ORIGIN = https://jolinx-api.onrender.com
 *    - BACKUP_ORIGIN  = https://<your-username>-jolinx-api.hf.space (or Koyeb URL)
 *
 * Behavior:
 * - Forwards incoming requests to PRIMARY_ORIGIN first.
 * - If PRIMARY_ORIGIN throws a network error, times out, or returns 502/503/504/521/522/523/524,
 *   automatically retries the exact same request against BACKUP_ORIGIN.
 * - Preserves client IP, HTTP method, headers, query string, and body stream.
 */

const DEFAULT_PRIMARY_ORIGIN = "https://jolinx-api.onrender.com";
const DEFAULT_BACKUP_ORIGIN = "https://businessmanagementapp-bnjucdtx.b4a.run";
const FAILOVER_STATUS_CODES = new Set([502, 503, 504, 520, 521, 522, 523, 524, 530]);

export default {
  async fetch(request, env) {
    const primaryOrigin = (env.PRIMARY_ORIGIN || DEFAULT_PRIMARY_ORIGIN).replace(/\/+$/, "");
    const backupOrigin = (env.BACKUP_ORIGIN || DEFAULT_BACKUP_ORIGIN).replace(/\/+$/, "");

    const incomingUrl = new URL(request.url);
    const pathAndQuery = incomingUrl.pathname + incomingUrl.search;

    // Buffer body for non-GET/HEAD requests so it can be replayed if primary fails.
    let bodyBuffer = null;
    if (request.method !== "GET" && request.method !== "HEAD") {
      bodyBuffer = await request.arrayBuffer();
    }

    try {
      const primaryResponse = await forwardRequest(
        request,
        primaryOrigin + pathAndQuery,
        bodyBuffer,
      );

      if (!FAILOVER_STATUS_CODES.has(primaryResponse.status)) {
        return withUpstreamHeader(primaryResponse, "primary");
      }
    } catch (_) {
      // Primary network/TLS timeout — fall through to backup origin.
    }

    try {
      const backupResponse = await forwardRequest(
        request,
        backupOrigin + pathAndQuery,
        bodyBuffer,
      );
      return withUpstreamHeader(backupResponse, "backup");
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
};

async function forwardRequest(originalRequest, targetUrl, bodyBuffer) {
  const targetHost = new URL(targetUrl).host;
  const headers = new Headers(originalRequest.headers);
  headers.set("Host", targetHost);
  headers.set("X-Forwarded-Host", new URL(originalRequest.url).host);
  headers.set("X-Forwarded-Proto", "https");

  return fetch(targetUrl, {
    method: originalRequest.method,
    headers,
    body: bodyBuffer,
    redirect: "manual",
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
