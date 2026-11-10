// The oracle for the text splits. It reads one JSON array of code point
// lists per line from the input. The first argument names the
// granularity: grapheme (the default), word or sentence. It prints the
// segment sizes in code points as a space separated list. The word
// granularity adds a bar and the isWordLike flag of each segment.
import { createInterface } from "node:readline";
const gran = process.argv[2] || "grapheme";
const seg = new Intl.Segmenter("en", { granularity: gran });
const rl = createInterface({ input: process.stdin });
rl.on("line", (line) => {
  const cps = JSON.parse(line);
  const text = String.fromCodePoint(...cps);
  const sizes = [];
  const flags = [];
  for (const s of seg.segment(text)) {
    sizes.push([...s.segment].length);
    flags.push(s.isWordLike ? 1 : 0);
  }
  console.log(gran === "word" ? sizes.join(" ") + "|" + flags.join(" ") : sizes.join(" "));
});
