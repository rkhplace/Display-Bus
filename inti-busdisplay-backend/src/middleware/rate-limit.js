const { HttpError } = require('../lib/http-error');

// Pembatas sederhana di memori, cukup untuk satu instance server.
// Hanya percobaan yang gagal yang dihitung (lihat recordFailure).
function failureLimiter({ maxFailures, windowMs, message }) {
  const failures = new Map();

  function prune(key, now) {
    const recent = (failures.get(key) ?? []).filter((t) => now - t < windowMs);
    if (recent.length === 0) failures.delete(key);
    else failures.set(key, recent);
    return recent;
  }

  return {
    guard(req, _res, next) {
      if (prune(req.ip, Date.now()).length >= maxFailures) {
        throw new HttpError(429, message);
      }
      next();
    },
    recordFailure(req) {
      const recent = prune(req.ip, Date.now());
      recent.push(Date.now());
      failures.set(req.ip, recent);
    },
  };
}

module.exports = { failureLimiter };
