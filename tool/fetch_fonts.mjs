import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";

const revision = "e44c4b011a820c2cbe2fd2cfa8052037d7edb571";
const upstream = `https://raw.githubusercontent.com/google/fonts/${revision}/ofl/`;
const destination = new URL("../assets/fonts/", import.meta.url);
const files = [
  ["Geist.ttf", "geist/Geist%5Bwght%5D.ttf", 169056, "f63f0afc6390323715972b6645115485f37cc9f4"],
  ["GeistMono.ttf", "geistmono/GeistMono%5Bwght%5D.ttf", 171948, "173867dce0580ea751e4b9c558740d34f20ce549"],
  ["Geist-OFL.txt", "geist/OFL.txt", 4387, "61f6f4b7853081236aec6407f2dd3c7170997f84"],
  ["GeistMono-OFL.txt", "geistmono/OFL.txt", 4387, "61f6f4b7853081236aec6407f2dd3c7170997f84"],
];
const check = process.argv[2] === "--check";
assert(process.argv.length === 2 || (check && process.argv.length === 3),
  "Usage: node tool/fetch_fonts.mjs [--check]");

const verified = [];
for (const [name, path, size, hash] of files) {
  let data;
  if (check) {
    data = await readFile(new URL(name, destination));
  } else {
    const response = await fetch(new URL(path, upstream), {
      signal: AbortSignal.timeout(30000),
    });
    assert(response.ok, `${name}: HTTP ${response.status}`);
    data = Buffer.from(await response.arrayBuffer());
  }
  assert.equal(data.length, size, `${name}: size mismatch`);
  const blobHash = createHash("sha1")
    .update(`blob ${data.length}\0`).update(data).digest("hex");
  assert.equal(blobHash, hash, `${name}: Git blob hash mismatch`);
  if (name.endsWith(".ttf")) {
    assert.equal(data.readUInt32BE(0), 0x00010000, `${name}: not TrueType`);
    let fvar;
    for (let i = 0; i < data.readUInt16BE(4); i++) {
      const record = 12 + i * 16;
      if (data.toString("ascii", record, record + 4) === "fvar") {
        fvar = data.readUInt32BE(record + 8);
      }
    }
    assert.notEqual(fvar, undefined, `${name}: missing variable axes`);
    assert.equal(data.readUInt16BE(fvar + 8), 1, `${name}: expected one axis`);
    const axis = fvar + data.readUInt16BE(fvar + 4);
    assert.equal(data.toString("ascii", axis, axis + 4), "wght");
    assert.deepEqual([4, 8, 12].map((offset) => data.readInt32BE(axis + offset) / 65536),
      [100, 400, 900], `${name}: unexpected weight range/default`);
  } else {
    assert.match(data.toString("utf8"), /Copyright 2024 The Geist Project Authors/);
    assert.match(data.toString("utf8"), /SIL OPEN FONT LICENSE Version 1\.1/);
  }
  verified.push([name, data]);
}

if (!check) {
  await mkdir(destination, { recursive: true });
  for (const [name, data] of verified) {
    await writeFile(new URL(name, destination), data);
  }
}
for (const [name, data] of verified) {
  console.log(`${check ? "Verified" : "Provisioned"} assets/fonts/${name} (${data.length} bytes)`);
}
