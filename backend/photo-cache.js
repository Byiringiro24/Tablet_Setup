const fs = require('fs');
const path = require('path');

const PHOTO_CACHE_TTL_MS = 5 * 60 * 1000;
const DEFAULT_CACHE_ROOT = 'C:/EcaAfrica/cache/photos';

function normalizeCacheRoot(rootPath) {
  return (rootPath || DEFAULT_CACHE_ROOT).replace(/\\/g, '/');
}

function sanitizeKey(value) {
  return String(value || '')
    .trim()
    .replace(/[\\/:*?"<>|]/g, '-')
    .replace(/\s+/g, '-');
}

function resolveLocalPhotoPath(studentId, roomKey, rootPath = DEFAULT_CACHE_ROOT) {
  const cacheRoot = normalizeCacheRoot(rootPath);
  const safeStudent = sanitizeKey(studentId || 'unknown-student');
  const safeRoom = sanitizeKey(roomKey || 'all-rooms');
  const localDir = path.join(cacheRoot, safeRoom);
  return path.join(localDir, `${safeStudent}.jpg`);
}

function buildPhotoCacheManifest(students = [], roomKey, deviceId, rootPath = DEFAULT_CACHE_ROOT) {
  return (Array.isArray(students) ? students : []).map((student) => {
    const studentId = student?.id || student?.student_id || student?.studentId || 'unknown';
    const photoUrl = student?.photo_url || student?.photoUrl || '';
    const localPath = resolveLocalPhotoPath(studentId, roomKey, rootPath);

    return {
      studentId,
      roomKey: String(roomKey || 'all-rooms'),
      deviceId: String(deviceId || 'unknown-device'),
      photoUrl,
      localPath,
      updatedAt: Date.now(),
    };
  });
}

function shouldRefreshPhotoCache(entry, now = Date.now()) {
  if (!entry || !entry.updatedAt) return true;
  return (now - Number(entry.updatedAt)) > PHOTO_CACHE_TTL_MS;
}

function ensurePhotoCacheDirectory(localPath) {
  const dir = path.dirname(localPath);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function savePhotoToCache(url, localPath, token = null) {
  if (!url || !localPath) return { ok: false, reason: 'missing-url-or-path' };

  try {
    const dir = ensurePhotoCacheDirectory(localPath);
    if (!dir) return { ok: false, reason: 'missing-dir' };

    return new Promise((resolve) => {
      const request = {
        method: 'GET',
        headers: {},
      };

      if (token) request.headers.Authorization = `Bearer ${token}`;

      fetch(url, request)
        .then(async (response) => {
          if (!response.ok) {
            resolve({ ok: false, reason: `http-${response.status}`, localPath });
            return;
          }

          const buffer = Buffer.from(await response.arrayBuffer());
          fs.writeFileSync(localPath, buffer);
          resolve({ ok: true, localPath, size: buffer.length, updatedAt: Date.now() });
        })
        .catch((error) => {
          resolve({ ok: false, reason: error && error.message ? error.message : 'download-error', localPath });
        });
    });
  } catch (error) {
    return { ok: false, reason: error && error.message ? error.message : 'cache-write-error', localPath };
  }
}

module.exports = {
  PHOTO_CACHE_TTL_MS,
  DEFAULT_CACHE_ROOT,
  buildPhotoCacheManifest,
  shouldRefreshPhotoCache,
  resolveLocalPhotoPath,
  ensurePhotoCacheDirectory,
  savePhotoToCache,
};
