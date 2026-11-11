// The locale case mapping oracle for Node. Arguments: a language tag and
// one of upper, lower. Each input line holds the code points of one text
// in hex, separated by spaces. The output holds the converted text in the
// same form.
import { readFileSync } from "fs";

const [tag, kind] = process.argv.slice(2);
const hex = (cp) => cp.toString(16).toUpperCase().padStart(4, "0");
const lines = readFileSync(0, "utf8").split("\n").filter((s) => s.length > 0);
const out = [];
for (const line of lines) {
	const s = String.fromCodePoint(...line.split(/\s+/).map((h) => Number.parseInt(h, 16)));
	const r = kind === "upper" ? s.toLocaleUpperCase(tag) : s.toLocaleLowerCase(tag);
	out.push([...r].map((c) => hex(c.codePointAt(0))).join(" "));
}
console.log(out.join("\n"));
