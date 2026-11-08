// The oracle for the cluster split. It reads one JSON array of code point
// lists per line from the input. It prints the cluster boundaries that
// Intl.Segmenter of Node gives, as a space separated list of cluster
// sizes in code points.
import { createInterface } from "node:readline";
const seg = new Intl.Segmenter("en", { granularity: "grapheme" });
const rl = createInterface({ input: process.stdin });
rl.on("line", (line) => {
  const cps = JSON.parse(line);
  const text = String.fromCodePoint(...cps);
  const sizes = [];
  for (const s of seg.segment(text)) sizes.push([...s.segment].length);
  console.log(sizes.join(" "));
});
