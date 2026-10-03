import http from 'k6/http';
import { check, sleep } from 'k6';
import encoding from 'k6/encoding';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const EMAIL = __ENV.TEST_EMAIL;
const PASSWORD = __ENV.TEST_PASSWORD;
const CREATE_APPOINTMENT = (__ENV.CREATE_APPOINTMENT || 'false').toLowerCase() === 'true';
const UPLOAD_IMAGE = (__ENV.UPLOAD_IMAGE || 'false').toLowerCase() === 'true';

export const options = {
  stages: [
    { duration: '1m', target: Number(__ENV.VUS || 10) },
    { duration: '2m', target: Number(__ENV.VUS || 10) },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<1000'],
  },
};

function jsonHeaders(token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return { headers };
}

function login() {
  if (!EMAIL || !PASSWORD) {
    throw new Error('Set TEST_EMAIL and TEST_PASSWORD for authenticated load tests.');
  }

  const res = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ email: EMAIL, password: PASSWORD }),
    jsonHeaders(),
  );

  check(res, {
    'login status is 200': (r) => r.status === 200,
    'login success true': (r) => r.json('success') === true,
    'access token present': (r) => Boolean(r.json('data.accessToken')),
  });

  return res.json('data.accessToken');
}

function nextDate() {
  const date = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  return date.toISOString().slice(0, 10);
}

export default function () {
  const token = login();
  const auth = jsonHeaders(token);

  check(http.get(`${BASE_URL}/actuator/health`), {
    'health 200': (r) => r.status === 200,
  });

  check(http.get(`${BASE_URL}/api/user/profile`, auth), {
    'profile 200': (r) => r.status === 200,
    'profile json success': (r) => r.json('success') === true,
  });

  check(http.get(`${BASE_URL}/api/appointments`, auth), {
    'appointments 200': (r) => r.status === 200,
  });

  check(http.get(`${BASE_URL}/api/treatment/protocols`, auth), {
    'protocols 200': (r) => r.status === 200,
  });

  check(http.get(`${BASE_URL}/api/treatment/active`, auth), {
    'active treatment 200': (r) => r.status === 200,
  });

  check(http.get(`${BASE_URL}/api/treatment/sessions/next`, auth), {
    'next session 200': (r) => r.status === 200,
  });

  check(http.get(`${BASE_URL}/api/notifications`, auth), {
    'notifications 200': (r) => r.status === 200,
  });

  check(http.get(`${BASE_URL}/api/notifications/unread-count`, auth), {
    'unread count 200': (r) => r.status === 200,
  });

  if (CREATE_APPOINTMENT) {
    const appointment = http.post(
      `${BASE_URL}/api/appointments`,
      JSON.stringify({
        appointmentDate: nextDate(),
        appointmentTime: '10:30:00',
        branch: 'BURJUMAN',
        note: `k6 test ${__VU}-${__ITER}`,
      }),
      auth,
    );
    check(appointment, {
      'create appointment handled': (r) => [200, 400].includes(r.status),
      'create appointment json': (r) => typeof r.json('success') === 'boolean',
    });
  }

  if (UPLOAD_IMAGE) {
    const png = encoding.b64decode(open('./fixtures/1x1.png.b64'), 'rawstd');
    const upload = http.post(`${BASE_URL}/api/user/profile/image`, {
      file: http.file(png, 'profile.png', 'image/png'),
    }, {
      headers: { Authorization: `Bearer ${token}` },
    });
    check(upload, {
      'upload handled': (r) => [200, 413, 415].includes(r.status),
      'upload json': (r) => typeof r.json('success') === 'boolean',
    });
  }

  sleep(1);
}
