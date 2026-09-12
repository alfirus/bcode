// Generates android/icon.png — bcode bolt mark on near-black.
// Zero dependencies: raw RGBA -> PNG via node:zlib. Run: node scripts/make-icon.mjs
import { deflateSync } from "node:zlib";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const W = 128;
const H = 128;

const BG = [6, 6, 6];
const AMBER = [232, 185, 62];
const AMBER_DK = [150, 115, 30];

// Bolt polygon (x,y), drawn in a 128 box.
const BOLT = [
  [74, 14], [42, 72], [60, 72], [52, 114], [86, 56], [66, 56],
];

function insideBolt(x, y) {
  let inside = false;
  for (let i = 0, j = BOLT.length - 1; i < BOLT.length; j = i++) {
    const [xi, yi] = BOLT[i];
    const [xj, yj] = BOLT[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

const raw = Buffer.alloc((W * 4 + 1) * H);
let o = 0;
for (let y = 0; y < H; y++) {
  raw[o++] = 0; // filter byte
  for (let x = 0; x < W; x++) {
    // faint amber ring glow near edges
    const edge = Math.min(x, y, W - 1 - x, H - 1 - y);
    let r = BG[0], g = BG[1], b = BG[2];
    if (edge < 3) {
      const t = (3 - edge) / 3;
      r += (AMBER[0] - r) * 0.25 * t;
      g += (AMBER[1] - g) * 0.25 * t;
      b += (AMBER[2] - b) * 0.25 * t;
    }
    if (insideBolt(x, y)) {
      const t = y / H; // amber top -> deep amber bottom
      r = AMBER[0] + (AMBER_DK[0] - AMBER[0]) * t;
      g = AMBER[1] + (AMBER_DK[1] - AMBER[1]) * t;
      b = AMBER[2] + (AMBER_DK[2] - AMBER[2]) * t;
    }
    raw[o++] = r;
    raw[o++] = g;
    raw[o++] = b;
    raw[o++] = 255;
  }
}

function crc(table, buf) {
  let c = 0xffffffff;
  for (const byte of buf) c = table[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
const table = new Int32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  table[n] = c;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const sum = Buffer.alloc(4);
  sum.writeUInt32BE(crc(table, body));
  return Buffer.concat([len, body, sum]);
}

const png = Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk("IHDR", (() => {
    const h = Buffer.alloc(13);
    h.writeUInt32BE(W, 0);
    h.writeUInt32BE(H, 4);
    h[8] = 8; h[9] = 6;
    return h;
  })()),
  chunk("IDAT", deflateSync(raw)),
  chunk("IEND", Buffer.alloc(0)),
]);

const out = join(dirname(fileURLToPath(import.meta.url)), "..", "icon.png");
writeFileSync(out, png);
console.log(`icon written: ${out} (${png.length} bytes)`);
