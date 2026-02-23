import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend, Counter } from "k6/metrics";

// ─────────────────────────────────────────────
// Environment variables (override via -e flag)
// ─────────────────────────────────────────────
const BASE_URL   = __ENV.BASE_URL   || "https://savegb.org";
const ENDPOINT   = __ENV.ENDPOINT   || "/courses";
const AUTH_TOKEN = __ENV.AUTH_TOKEN || "";       // optional Bearer / session token
const VUS        = parseInt(__ENV.VUS      || "300");
const DURATION   = __ENV.DURATION          || "10m";
const RAMP_UP    = __ENV.RAMP_UP           || "1m";
const RAMP_DOWN  = __ENV.RAMP_DOWN         || "30s";

const TARGET_URL = `${BASE_URL}${ENDPOINT}`;

// ─────────────────────────────────────────────
// Custom metrics
// ─────────────────────────────────────────────
const errorRate      = new Rate("error_rate");
const timeoutRate    = new Rate("timeout_rate");
const successLatency = new Trend("success_latency", true);   // true → display in ms
const totalErrors    = new Counter("total_errors");

// ─────────────────────────────────────────────
// Load profile
// ─────────────────────────────────────────────
export const options = {
  stages: [
    { duration: RAMP_UP,   target: VUS },   // ramp up   → 300 VUs
    { duration: DURATION,  target: VUS },   // soak      → hold 300 VUs for 10 min
    { duration: RAMP_DOWN, target: 0   },   // ramp down → graceful teardown
  ],

  // ── Pass / fail thresholds (used by CI / CD) ──────────────────
  thresholds: {
    // 95th-percentile response time must stay under 2 000 ms
    http_req_duration: ["p(95)<2000"],

    // Custom: our tracked success latency (only successful responses)
    success_latency: ["p(95)<2000"],

    // Error rate must stay under 1 %
    error_rate: ["rate<0.01"],

    // Total HTTP failures must stay under 1 %
    http_req_failed: ["rate<0.01"],
  },
};

// ─────────────────────────────────────────────
// Build request headers
// ─────────────────────────────────────────────
function buildHeaders() {
  const headers = {
    "Accept":          "application/json, text/html, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "User-Agent":      "k6-OpenEdX-LoadTest/2.0",
  };
  if (AUTH_TOKEN) {
    // Works for JWT (Bearer) tokens and edx-jwt-cookie alike
    headers["Authorization"] = `Bearer ${AUTH_TOKEN}`;
  }
  return headers;
}

// ─────────────────────────────────────────────
// Default function — executed by every VU
// ─────────────────────────────────────────────
export default function () {
  const params = {
    headers: buildHeaders(),
    timeout: "30s",   // per-request timeout
    redirects: 5,
  };

  const res = http.get(TARGET_URL, params);

  // ── Checks ──────────────────────────────────
  const ok = check(res, {
    "status is 2xx":            (r) => r.status >= 200 && r.status < 300,
    "status is not 5xx":        (r) => r.status < 500,
    "response time < 2000 ms":  (r) => r.timings.duration < 2000,
    "body is not empty":        (r) => r.body && r.body.length > 0,
  });

  // ── Record custom metrics ────────────────────
  const isError   = res.status === 0 || res.status >= 400;
  const isTimeout = res.status === 0;

  errorRate.add(isError   ? 1 : 0);
  timeoutRate.add(isTimeout ? 1 : 0);

  if (!isError) {
    successLatency.add(res.timings.duration);
  } else {
    totalErrors.add(1);
    console.warn(`[VU ${__VU}] ERROR — status=${res.status} url=${TARGET_URL} body=${res.body ? res.body.substring(0, 120) : "empty"}`);
  }

  // ── Think time (realistic user pacing) ──────
  // Keeps requests-per-second realistic rather than hammering at full speed.
  // Remove or reduce this if you want maximum throughput testing.
  sleep(Math.random() * 2 + 1);  // 1–3 s think time per VU
}

// ─────────────────────────────────────────────
// Lifecycle hooks (optional)
// ─────────────────────────────────────────────

/** Called once before the test starts — good for a warm-up check. */
export function setup() {
  console.log("═".repeat(60));
  console.log(`  Target  : ${TARGET_URL}`);
  console.log(`  VUs     : ${VUS}`);
  console.log(`  Duration: ${DURATION} soak  (ramp ${RAMP_UP} / teardown ${RAMP_DOWN})`);
  console.log(`  Auth    : ${AUTH_TOKEN ? "✓ token set" : "✗ anonymous (no token)"}`);
  console.log("═".repeat(60));

  // Quick connectivity probe (1 request, no metrics)
  const probe = http.get(TARGET_URL, { headers: buildHeaders(), timeout: "10s" });
  if (probe.status === 0) {
    console.error(`[SETUP] Cannot reach ${TARGET_URL} — aborting.`);
  } else {
    console.log(`[SETUP] Probe → HTTP ${probe.status}  (${probe.timings.duration.toFixed(0)} ms) ✓`);
  }
}

/** Called once after all VUs finish — print a human-readable summary. */
export function teardown() {
  console.log("\n  Load test complete. Check the summary table above for thresholds.");
  console.log("  Tip: pipe --out json=results.json and import into Grafana for charts.");
}