#!/usr/bin/env python3
"""
Jolinx Business OS — Load & Latency Benchmarking Tool
Usage:
    python3 scripts/benchmark_performance.py [--url http://localhost:5000] [--concurrency 20] [--requests 100]

Tests:
1. Baseline Ping (/health/live)
2. Fast-Path TLS Fingerprint / Bot Rejection (/api/v1/auth/login with CF-Bot-Score: 5)
3. Auth Login Latency (/api/v1/auth/login)
4. Sale Creation Validation Throughput (/api/v1/sales)
"""

import argparse
import concurrent.futures
import json
import statistics
import sys
import time
import urllib.error
import urllib.request

def parse_args():
    parser = argparse.ArgumentParser(description="Jolinx Business OS API Performance Benchmarker")
    parser.add_argument("--url", default="http://localhost:5000", help="Base URL of API (default: http://localhost:5000)")
    parser.add_argument("--concurrency", type=int, default=10, help="Number of concurrent workers (default: 10)")
    parser.add_argument("--requests", type=int, default=50, help="Total requests per test case (default: 50)")
    return parser.parse_args()

def make_request(url, method="GET", headers=None, payload=None, timeout=10):
    headers = headers or {}
    data = None
    if payload is not None:
        if isinstance(payload, (dict, list)):
            data = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        elif isinstance(payload, str):
            data = payload.encode("utf-8")
        else:
            data = payload

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            duration_ms = (time.perf_counter() - start) * 1000
            return resp.status, duration_ms, None
    except urllib.error.HTTPError as e:
        duration_ms = (time.perf_counter() - start) * 1000
        return e.code, duration_ms, None
    except Exception as e:
        duration_ms = (time.perf_counter() - start) * 1000
        return None, duration_ms, str(e)

def run_benchmark(name, url, method="GET", headers=None, payload=None, concurrency=10, total_requests=50):
    print(f"\n=======================================================")
    print(f"[*] Benchmark: {name}")
    print(f"    Target: {method} {url}")
    print(f"    Concurrency: {concurrency} | Total Requests: {total_requests}")
    print(f"=======================================================")

    durations = []
    statuses = {}
    errors = 0

    wall_start = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [
            executor.submit(make_request, url, method, headers, payload)
            for _ in range(total_requests)
        ]
        for f in concurrent.futures.as_completed(futures):
            status, duration_ms, err = f.result()
            durations.append(duration_ms)
            if status:
                statuses[status] = statuses.get(status, 0) + 1
            if err:
                errors += 1

    wall_duration = time.perf_counter() - wall_start
    rps = len(durations) / wall_duration if wall_duration > 0 else 0

    durations.sort()
    p50 = statistics.median(durations)
    p90 = durations[int(len(durations) * 0.90)]
    p95 = durations[int(len(durations) * 0.95)]
    p99 = durations[min(int(len(durations) * 0.99), len(durations) - 1)]

    print(f"  Duration:      {wall_duration:.2f}s")
    print(f"  Throughput:    {rps:.1f} req/s")
    print(f"  P50 (Median):  {p50:.1f}ms")
    print(f"  P90:           {p90:.1f}ms")
    print(f"  P95:           {p95:.1f}ms")
    print(f"  P99:           {p99:.1f}ms")
    print(f"  Min / Max:     {min(durations):.1f}ms / {max(durations):.1f}ms")
    print(f"  Status Codes:  {statuses}")
    if errors > 0:
        print(f"  Network Errors:{errors}")

    return {
        "name": name,
        "rps": rps,
        "p50": p50,
        "p95": p95,
        "statuses": statuses,
    }

def main():
    args = parse_args()
    base_url = args.url.rstrip("/")

    print("=================================================================")
    print("   JOLINX BUSINESS OS — BENCHMARK & PERFORMANCE SUITE            ")
    print(f"   Target: {base_url}")
    print("=================================================================")

    # 1. Baseline Health Check
    run_benchmark(
        name="Baseline Ping /health/live",
        url=f"{base_url}/health/live",
        method="GET",
        concurrency=args.concurrency,
        total_requests=args.requests,
    )

    # 2. Fast-Path Bot / TLS Fingerprint Rejection (< 5ms expected)
    run_benchmark(
        name="TLS Fingerprint & Bot Fast-Rejection (CF-Bot-Score: 5)",
        url=f"{base_url}/api/v1/auth/login",
        method="POST",
        headers={
            "CF-Bot-Score": "5",
            "CF-JA3-Fingerprint": "b32309a26ce51605669718c9842d3485"
        },
        payload={"email": "bot@attacker.com", "password": "stolen-password"},
        concurrency=args.concurrency,
        total_requests=args.requests,
    )

    # 3. Legitimate Login Request (Exercises BCrypt factor 11 and DbContext pool)
    run_benchmark(
        name="Legitimate Auth Login Throughput",
        url=f"{base_url}/api/v1/auth/login",
        method="POST",
        headers={
            "CF-Bot-Score": "99",
            "CF-JA3-Fingerprint": "chrome-legit-fingerprint"
        },
        payload={"email": "owner@demo.jolinx.com", "password": "WrongPassword42!"},
        concurrency=args.concurrency,
        total_requests=args.requests,
    )

    print("\n[+] Benchmark suite execution complete.")

if __name__ == "__main__":
    main()
