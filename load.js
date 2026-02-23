/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║   savegb.org — k6 Load Test (Proctored Exam Attempt API)        ║
 * ║   300 VUs · 10-minute soak · exact headers from browser         ║
 * ╚══════════════════════════════════════════════════════════════════╝
 *
 * INSTALL k6:
 *   macOS:          brew install k6
 *   Ubuntu/Debian:  sudo apt-get install k6   (see k6.io/docs/get-started)
 *   Docker:         docker run --rm -i grafana/k6 run - < savegb_load_test.js
 *
 * RUN:
 *   k6 run savegb_load_test.js
 *
 *   # Override VU count or duration at runtime:
 *   k6 run savegb_load_test.js -e VUS=50 -e DURATION=2m
 *
 *   # Export results to JSON:
 *   k6 run savegb_load_test.js --out json=results.json
 *
 *   # Export to InfluxDB + Grafana dashboard:
 *   k6 run savegb_load_test.js --out influxdb=http://localhost:8086/k6
 *
 * ⚠️  NOTE: The cookies below contain your live session tokens.
 *     If your session expires mid-test, you will see 401/403 errors.
 *     Rotate the cookies from a fresh browser login when that happens.
 */

import http   from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend, Counter } from "k6/metrics";

// ─── Config (override with -e FLAG=value) ──────────────────────────
const VUS      = parseInt(__ENV.VUS      || "300");
const DURATION = __ENV.DURATION          || "10m";
const RAMP_UP  = __ENV.RAMP_UP           || "1m";
const RAMP_DOWN = __ENV.RAMP_DOWN        || "30s";

// ─── Target ────────────────────────────────────────────────────────
const TARGET_URL =
  "https://savegb.org/api/edx_proctoring/v1/proctored_exam/attempt/course_id" +
  "/course-v1:Alnafi+Aios_ops_101+2026_01?is_learning_mfe=true";

// ─── Custom metrics ────────────────────────────────────────────────
const errorRate   = new Rate("error_rate");
const timeoutRate = new Rate("timeout_rate");
const okLatency   = new Trend("ok_latency_ms", true);
const totalErrors = new Counter("total_errors");

// ─── Load profile ──────────────────────────────────────────────────
export const options = {
  stages: [
    { duration: RAMP_UP,   target: VUS }, // 0 → 300 VUs over 1 min
    { duration: DURATION,  target: VUS }, // hold 300 VUs for 10 min
    { duration: RAMP_DOWN, target: 0   }, // graceful teardown
  ],

  thresholds: {
    // 95th-percentile must stay under 2 s
    http_req_duration: ["p(95)<2000", "p(99)<4000"],
    // Custom latency for successful responses only
    ok_latency_ms:     ["p(95)<2000"],
    // Error rate must stay below 1 %
    error_rate:        ["rate<0.01"],
    http_req_failed:   ["rate<0.01"],
  },
};

// ─── Exact headers copied from your Network tab ────────────────────
const HEADERS = {
  // Auth & session cookies (rotate if session expires)
  "cookie": [
    "openedx-language-preference=en",
    "indigo-toggle-dark=light",
    "edxloggedin=true",
    `edx-user-info="{\"version\": 1\\054 \"username\": \"admin\"\\054 \"email\": \"admin@savegb.org\"\\054 \"header_urls\": {\"logout\": \"https://savegb.org/logout\"\\054 \"account_settings\": \"https://apps.savegb.org/account/\"\\054 \"learner_profile\": \"https://apps.savegb.org/u/admin\"}\\054 \"user_image_urls\": {\"full\": \"https://savegb.org/static/images/profiles/default_500.4215dbe8010f.png\"\\054 \"large\": \"https://savegb.org/static/images/profiles/default_120.4a5e0900098e.png\"\\054 \"medium\": \"https://savegb.org/static/images/profiles/default_50.3455a6581573.png\"\\054 \"small\": \"https://savegb.org/static/images/profiles/default_30.deee7287e843.png\"}}"`,
    "edx-jwt-cookie-header-payload=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJvcGVuZWR4IiwiZXhwIjoxNzcxODI3OTg5LCJncmFudF90eXBlIjoicGFzc3dvcmQiLCJpYXQiOjE3NzE4MjQzODksImlzcyI6Imh0dHBzOi8vc2F2ZWdiLm9yZy9vYXV0aDIiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJhZG1pbiIsInNjb3BlcyI6WyJ1c2VyX2lkIiwiZW1haWwiLCJwcm9maWxlIl0sInZlcnNpb24iOiIxLjIuMCIsInN1YiI6ImIxMjdkNjQ0YjQxYWMyNjkzMGExMmQxYWNkZjNiZmE5IiwiZmlsdGVycyI6WyJ1c2VyOm1lIl0sImlzX3Jlc3RyaWN0ZWQiOmZhbHNlLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwidXNlcl9pZCI6NSwiZW1haWwiOiJhZG1pbkBzYXZlZ2Iub3JnIiwibmFtZSI6IiIsImZhbWlseV9uYW1lIjoiIiwiZ2l2ZW5fbmFtZSI6IiIsImFkbWluaXN0cmF0b3IiOnRydWUsInN1cGVydXNlciI6dHJ1ZX0",
    "edx-jwt-cookie-signature=KPatDRsdQkkWU979qEjthr-POHN5I46OY0_bqrBUQOmv-zAc_OLqTz9LOq1AgRZK84-yfcCxNTy72wfyxfrAQ5mhRmnMisPUopp7rrqnuJRjoG6g04naYDT3IxnCG3sQeX9lmcpDRirfI5nxjzfirjvAZm5wtxvJYW5HM7L_TZ_J51ZFgVrZ7DjGI1XlZRqmSpcYZZDgFZD9IBkOYf8G5M5wtnDueUjniKRNCpenv9JSFmvYA1PZ3ojTa1fCdeWrH0kxCa-l9BiffDbnXEtxehtio2iNZhkPRM06k8r9fJ7WOjqU7ruW1UC4FyET6uSs2LwcBpYHP61wXbWNYesYBA",
    "csrftoken=eXjUhIKotoR0eBXUbyIhVRYeaGj02iHo",
    "sessionid=1|hyrvxcnel5uenbz2uwxac12laef7aaa0|8tovSRRTdYuu|Ijk4NjRhNTZiMGYzMWIwYThlM2QzYTNjMTIyZWM2ZDA5ZTBjZDM0ZDEzMWFjYzVkZWEyMTNlMzAyYzZiNGFjNjki:1vuOoP:l_yAwVCA1SvAUeWjhUJDA1Zq2poMkBIf5Y0RKp-D7Jg",
  ].join("; "),

  // Standard request headers (exact copy from Network tab)
  "accept":              "application/json, text/plain, */*",
  "accept-encoding":     "gzip, deflate, br, zstd",
  "accept-language":     "en-GB,en-US;q=0.9,en;q=0.8",
  "origin":              "https://apps.savegb.org",
  "referer":             "https://apps.savegb.org/",
  "priority":            "u=1, i",
  "sec-ch-ua":           '"Not(A:Brand";v="8", "Chromium";v="144", "Google Chrome";v="144"',
  "sec-ch-ua-mobile":    "?1",
  "sec-ch-ua-platform":  '"Android"',
  "sec-fetch-dest":      "empty",
  "sec-fetch-mode":      "cors",
  "sec-fetch-site":      "same-site",
  "use-jwt-cookie":      "true",
  "user-agent":          "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36",
};

// ─── Main VU function ──────────────────────────────────────────────
export default function () {
  const res = http.get(TARGET_URL, {
    headers:   HEADERS,
    timeout:   "30s",
    redirects: 5,
  });

  // Checks
  const passed = check(res, {
    "status 200":              (r) => r.status === 200,
    "no 401 Unauthorized":     (r) => r.status !== 401,
    "no 403 Forbidden":        (r) => r.status !== 403,
    "no 5xx Server Error":     (r) => r.status < 500,
    "response < 2000 ms":      (r) => r.timings.duration < 2000,
    "body contains attempt":   (r) => r.body && r.body.includes("attempt"),
  });

  // Record custom metrics
  const isError   = res.status === 0 || res.status >= 400;
  const isTimeout = res.status === 0;

  errorRate.add(isError ? 1 : 0);
  timeoutRate.add(isTimeout ? 1 : 0);

  if (!isError) {
    okLatency.add(res.timings.duration);
  } else {
    totalErrors.add(1);

    // Detect expired session early
    if (res.status === 401 || res.status === 403) {
      console.error(
        `[VU ${__VU}] Auth failure (${res.status}) — ` +
        "your session/JWT may have expired. Re-capture cookies from the browser."
      );
    } else {
      console.warn(`[VU ${__VU}] HTTP ${res.status} — ${res.body ? res.body.substring(0, 200) : "empty body"}`);
    }
  }

  // Think time: 1–3 s (realistic browser pacing)
  sleep(Math.random() * 2 + 1);
}

// ─── Setup: connectivity probe before load starts ──────────────────
export function setup() {
  console.log("═".repeat(65));
  console.log("  TARGET  : " + TARGET_URL);
  console.log(`  PROFILE : ramp ${RAMP_UP} → soak ${DURATION} → down ${RAMP_DOWN}`);
  console.log(`  VUs     : ${VUS}`);
  console.log("═".repeat(65));

  const probe = http.get(TARGET_URL, { headers: HEADERS, timeout: "10s" });

  if (probe.status === 0) {
    console.error("[SETUP] ✗ Cannot reach target — check URL and network.");
  } else if (probe.status === 401 || probe.status === 403) {
    console.error(`[SETUP] ✗ Auth error (${probe.status}) — cookies/JWT may be expired!`);
  } else {
    console.log(`[SETUP] ✓ Probe → HTTP ${probe.status}  (${probe.timings.duration.toFixed(0)} ms)`);
    console.log("[SETUP] ✓ Auth looks good — starting load test.\n");
  }
}

// ─── Teardown: final advice ────────────────────────────────────────
export function teardown() {
  console.log("\n  Test complete!");
  console.log("  • If error_rate > 1 % → check server logs / autoscaling triggers.");
  console.log("  • If p(95) > 2 s     → check DB queries, cache hit rates, worker counts.");
  console.log("  • 401/403 spikes     → session expired mid-test; use multi-user credentials.");
  console.log("  • Export full data:  k6 run savegb_load_test.js --out json=results.json\n");
}