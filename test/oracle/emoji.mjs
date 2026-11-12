// The oracle for the emoji sequences. It reads one text per line from the
// input. Each line holds the code points of the text in hex. The first
// mode tests the six classes and the class RGI_Emoji on the whole text,
// with the v flag. It prints the mask of the kinds and the flag of the
// class RGI_Emoji. The second mode scans the text with the class
// RGI_Emoji. It prints the byte pairs of the matches. The pairs hold the
// start and the end of each match, in bytes of UTF-8.
import { createInterface } from "node:readline";

const mode = process.argv[2] || "kinds";

// The classes of the kinds, in the order of the mask of the package.
// Each class tests the whole text.
const KINDS = [
  ["Basic_Emoji", 1],
  ["Emoji_Keycap_Sequence", 2],
  ["RGI_Emoji_Modifier_Sequence", 4],
  ["RGI_Emoji_Flag_Sequence", 8],
  ["RGI_Emoji_Tag_Sequence", 16],
  ["RGI_Emoji_ZWJ_Sequence", 32],
].map(([name, bit]) => [new RegExp("^\\p{" + name + "}$", "v"), bit]);

const rgi = new RegExp("^\\p{RGI_Emoji}$", "v");

// The byte offsets of the units of the text.
function offsets(text) {
  const offs = [0];
  let bytes = 0;
  for (const ch of text) {
    const cp = ch.codePointAt(0);
    bytes += cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
    offs.push(bytes);
    if (ch.length === 2) offs.push(bytes);
  }
  return offs;
}

const rl = createInterface({ input: process.stdin });
rl.on("line", (line) => {
  const body = line.trim();
  const cps = body.length === 0 ? [] : body.split(/\s+/).map((h) => parseInt(h, 16));
  const text = String.fromCodePoint(...cps);
  if (mode === "scan") {
    const offs = offsets(text);
    const out = [];
    for (const m of text.matchAll(/\p{RGI_Emoji}/gv)) {
      out.push(offs[m.index], offs[m.index + m[0].length]);
    }
    console.log(out.join(" "));
    return;
  }
  let mask = 0;
  for (const [re, bit] of KINDS) {
    if (re.test(text)) mask |= bit;
  }
  console.log(mask + " " + (rgi.test(text) ? 1 : 0));
});
