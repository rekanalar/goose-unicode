// The full case mapping oracle for Node. Each input line holds one code
// point in hex. The output holds its full upper case and its full lower
// case, separated by a tab.
import { readFileSync } from "fs";

const hex = (cp) => cp.toString(16).toUpperCase().padStart(4, "0");
const lines = readFileSync(0, "utf8").split("\n").filter((s) => s.length > 0);
const out = [];
for (const line of lines) {
	const cp = Number.parseInt(line, 16);
	const s = String.fromCodePoint(cp);
	out.push([...s.toUpperCase()].map((c) => hex(c.codePointAt(0))).join(" ")
		+ "\t" + [...s.toLowerCase()].map((c) => hex(c.codePointAt(0))).join(" "));
}
console.log(out.join("\n"));
