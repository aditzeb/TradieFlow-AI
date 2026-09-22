const assert = require('node:assert/strict');
const { readFileSync, writeFileSync } = require('node:fs');
const { join } = require('node:path');
const { deflateSync } = require('node:zlib');

const svg = readFileSync(join(__dirname, 'icons', 'tradieflow.svg'), 'utf8');
const rectangles = [...svg.matchAll(/<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"/g)]
  .map((match) => match.slice(1).map(Number));
assert.equal(rectangles.length, 5);
for (const [x, y, width, height] of rectangles) {
  for (const [cx, cy] of [[x, y], [x + width, y], [x, y + height], [x + width, y + height]]) {
    assert.ok(Math.hypot(cx - 256, cy - 256) < 512 * 0.4);
  }
}

function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data]);
  let crc = 0xffffffff;
  for (const byte of body) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
  return Buffer.concat([length, body, checksum]);
}

function png(size) {
  const rows = Buffer.alloc(size * (1 + size * 3));
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const sx = (x + 0.5) * 512 / size;
      const sy = (y + 0.5) * 512 / size;
      const white = rectangles.some(([rx, ry, width, height]) =>
        sx >= rx && sx < rx + width && sy >= ry && sy < ry + height);
      const offset = y * (1 + size * 3) + 1 + x * 3;
      rows[offset] = white ? 255 : 15;
      rows[offset + 1] = white ? 255 : 20;
      rows[offset + 2] = white ? 255 : 25;
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header[8] = 8;
  header[9] = 2;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(rows, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

for (const size of [192, 512]) {
  const image = png(size);
  writeFileSync(join(__dirname, 'icons', `Icon-${size}.png`), image);
  writeFileSync(join(__dirname, 'icons', `Icon-maskable-${size}.png`), image);
}
writeFileSync(join(__dirname, 'favicon.png'), png(32));
