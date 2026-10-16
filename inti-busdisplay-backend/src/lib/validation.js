const { HttpError } = require('./http-error');

// Harus sama dengan AnimationMode.label di lib/core/models/animation_mode.dart (app Flutter).
const ANIMATION_LABELS = [
  'Running',
  'Static',
  'Blink',
  'Scroll Left',
  'Scroll Right',
  'Scroll Up',
  'Scroll Down',
];

const DIRECTIONS = ['Pergi', 'Pulang'];

function requireString(value, field, { max }) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new HttpError(400, `Field "${field}" wajib diisi.`);
  }
  const trimmed = value.trim();
  if (trimmed.length > max) {
    throw new HttpError(400, `Field "${field}" maksimal ${max} karakter.`);
  }
  return trimmed;
}

function requirePercent(value, field) {
  if (!Number.isInteger(value) || value < 0 || value > 100) {
    throw new HttpError(400, `Field "${field}" harus bilangan bulat 0-100.`);
  }
  return value;
}

function requireObject(value, field) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpError(400, `Field "${field}" harus berupa objek.`);
  }
  return value;
}

// Bentuk payload dari DisplayPayloadBuilder.build() di aplikasi.
function parseDisplayPayload(body) {
  const payload = requireObject(body, 'payload');

  const route = requireString(payload.route, 'route', { max: 120 });

  if (!DIRECTIONS.includes(payload.direction)) {
    throw new HttpError(400, 'Field "direction" harus "Pergi" atau "Pulang".');
  }
  if (!ANIMATION_LABELS.includes(payload.animation)) {
    throw new HttpError(400, 'Mode animasi tidak dikenal.');
  }

  return {
    route,
    direction: payload.direction,
    animation: payload.animation,
    speed: requirePercent(payload.speed, 'speed'),
    brightness: requirePercent(payload.brightness, 'brightness'),
    fontSize: requirePercent(payload.fontSize, 'fontSize'),
  };
}

function parseRouteInput(body) {
  requireObject(body, 'body');
  return {
    code: requireString(body.code, 'code', { max: 10 }),
    origin: requireString(body.origin, 'origin', { max: 40 }),
    destination: requireString(body.destination, 'destination', { max: 40 }),
  };
}

function parsePresetInput(body) {
  requireObject(body, 'body');
  return {
    name: requireString(body.name, 'name', { max: 50 }),
    payload: parseDisplayPayload(body.payload),
  };
}

module.exports = {
  ANIMATION_LABELS,
  parseDisplayPayload,
  parseRouteInput,
  parsePresetInput,
};
