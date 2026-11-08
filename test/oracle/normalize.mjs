// The oracle for the conformance cases. Each input line holds five columns
// of code points in hex, separated by bars. The output holds the four
// forms of each column, with the same layout as the Go oracle.
import { createInterface } from "node:readline";
const rl = createInterface({ input: process.stdin });
const hex = (s) => [...s].map((c) => c.codePointAt(0).toString(16).toUpperCase().padStart(4, "0")).join(" ");
rl.on("line", (line) => {
  const outs = [];
  for (const col of line.split("|")) {
    const text = String.fromCodePoint(...col.trim().split(/\s+/).filter(Boolean).map((h) => parseInt(h, 16)));
    for (const f of ["NFC", "NFD", "NFKC", "NFKD"]) outs.push(hex(text.normalize(f)));
  }
  console.log(outs.join("|"));
});
