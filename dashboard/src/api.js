export class ApiError extends Error {
  constructor(message, status, requestId) { super(message); this.status = status; this.requestId = requestId; }
}
export function createApi(fetcher = fetch) {
  let csrf, csrfPending, refreshing, generation = 0;
  async function csrfToken() {
    // Spring may clear the CSRF cookie when cookie authentication is established.
    // Fetch the current challenge for each mutation; concurrent callers share it.
    if (!csrfPending) csrfPending = fetcher('/api/staff-auth/csrf', { credentials: 'same-origin' })
      .then(async r => { if (!r.ok) throw new ApiError('Unable to establish a secure session', r.status); csrf = (await r.json()).token; return csrf; })
      .finally(() => { csrfPending = undefined; });
    return csrfPending;
  }
  async function send(path, options) {
    const headers = { ...options.headers };
    if (options.body && !(options.body instanceof FormData)) headers['Content-Type'] = 'application/json';
    if (options.method && options.method !== 'GET') headers['X-XSRF-TOKEN'] = await csrfToken();
    return fetcher(path, { ...options, headers, credentials: 'same-origin' });
  }
  async function rotate() {
    if (!refreshing) refreshing = send('/api/staff-auth/refresh', { method: 'POST' })
      .then(r => { if (!r.ok) throw new ApiError('Your session has expired. Sign in again.', r.status); generation++; })
      .finally(() => { refreshing = undefined; });
    return refreshing;
  }
  async function request(path, options = {}) {
    const {responseType, ...requestOptions} = options;
    const started = generation;
    let response = await send(path, requestOptions);
    if (response.status === 401 && (!path.startsWith('/api/staff-auth/') || path === '/api/staff-auth/logout')) {
      if (started === generation) await rotate();
      response = await send(path, requestOptions);
    }
    if (responseType === 'blob' && response.ok) return response.blob();
    let payload;
    try { payload = await response.json(); } catch { throw new ApiError('The service returned an unreadable response.', response.status); }
    if (!response.ok || payload.success === false) throw new ApiError(payload.message || 'Request could not be completed.', response.status, response.headers.get('X-Request-Id'));
    return payload.data;
  }
  return { request, reset() { csrf = undefined; generation++; } };
}
export const api = createApi();
export const params = values => new URLSearchParams(Object.entries(values).filter(([,v]) => v !== undefined && v !== null)).toString();
