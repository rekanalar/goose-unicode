// The oracle for the UTF-16 tables. It reads one line per case from the
// input. The first mode encodes: a line holds the code points of a text
// in hex, then a bar, then the byte order. The output holds the UTF-16
// bytes of the text in hex and the number of the units. The second mode
// decodes: a line holds the UTF-16 bytes of a text in hex, then a bar,
// then the byte order. The output holds the code points in hex, or the
// word "bad" when the bytes hold a lone surrogate or an odd count. The
// decoder runs in the fatal mode, so it refuses what Rust refuses.
import { createInterface } from "node:readline";

const mode = process.argv[2] || "encode";
const rl = createInterface({ input: process.stdin });
rl.on("line", (line) => {
  const at = line.lastIndexOf("|");
  const body = (at < 0 ? line : line.slice(0, at)).trim();
  const order = (at < 0 ? "le" : line.slice(at + 1).trim()) === "be" ? "be" : "le";
  const parts = body.length === 0 ? [] : body.split(/\s+/);
  if (mode === "decode") {
    const bytes = parts.map((h) => parseInt(h, 16));
    if (bytes.length % 2 !== 0) {
      console.log("bad");
      return;
    }
    const units = [];
    for (let i = 0; i < bytes.length; i += 2) {
      units.push(order === "be" ? (bytes[i] << 8) | bytes[i + 1] : (bytes[i + 1] << 8) | bytes[i]);
    }
    let text;
    try {
      text = new TextDecoder("utf-16" + order, { fatal: true }).decode(Uint8Array.from(bytes));
    } catch {
      console.log("bad");
      return;
    }
    const out = [...text].map((c) => c.codePointAt(0).toString(16).toUpperCase().padStart(4, "0"));
    console.log(out.join(" "));
    return;
  }
  const cps = parts.map((h) => parseInt(h, 16));
  const units = [];
  for (const cp of cps) {
    if (cp > 0xFFFF) {
      const v = cp - 0x10000;
      units.push(0xD800 + (v >> 10));
      units.push(0xDC00 + (v & 0x3FF));
    } else {
      units.push(cp);
    }
  }
  const bytes = [];
  for (const u of units) {
    if (order === "be") {
      bytes.push((u >> 8) & 0xFF, u & 0xFF);
    } else {
      bytes.push(u & 0xFF, (u >> 8) & 0xFF);
    }
  }
  console.log(bytes.map((b) => b.toString(16).toUpperCase().padStart(2, "0")).join(" ") + "|" + units.length);
});
