import fs from "fs";
const g = process.argv[2] || "word";
const seg = new Intl.Segmenter("und", { granularity: g });
for (const line of fs.readFileSync(0, "utf8").split("\n")) {
  if (!line.trim()) continue;
  const s = String.fromCodePoint(...line.trim().split(" ").map(x => parseInt(x, 16)));
  const b = [0];
  let last = 0;
  for (const x of seg.segment(s)) { last = x.index + x.segment.length; b.push(last); }
  console.log(b.join(" ") + " ");
}
