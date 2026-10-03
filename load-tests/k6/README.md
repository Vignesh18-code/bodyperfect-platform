# k6 Load Tests

These scripts are for local and staging only. Do not run heavy tests against production.

## Install

```bash
brew install k6
```

## Local smoke test

Start the backend locally, then run:

```bash
cd load-tests/k6
BASE_URL=http://localhost:8080 TEST_EMAIL=user@example.com TEST_PASSWORD='Password@123' k6 run api-smoke.js
```

## Staging tests

Use a seeded test user and a staging API URL:

```bash
BASE_URL=https://staging-api.bodyperfect.ae \
TEST_EMAIL=loadtest@example.com \
TEST_PASSWORD='Password@123' \
VUS=10 \
k6 run api-smoke.js
```

## Suggested stages

- Smoke: `VUS=10`
- Basic: `VUS=100`
- Stress: `VUS=500`
- Large staging only: `VUS=1000`

Use 1000 users only on staging with production-like database, object storage, email limits disabled or mocked, and monitoring enabled.

## Optional write tests

Appointment creation and profile image upload are disabled by default to avoid mutating data.

```bash
CREATE_APPOINTMENT=true k6 run api-smoke.js
UPLOAD_IMAGE=true k6 run api-smoke.js
```

Create separate staging users for write tests. Clean up staging data after each run.

## Safety

Start small. Watch database CPU, connection pool usage, p95 latency, error rate, memory, and email provider rate limits. Stop immediately if error rate rises above 5% or p95 latency stays above your SLA.
