// The oracle for the grapheme tables. It prints the ranges of a Unicode
// property from the regular expression engine of Node. The first
// argument names the property.
const name = process.argv[2];
const re = new RegExp(`^\\p{${name}}$`, "u");
let start = -1;
const out = [];
for (let cp = 0; cp <= 0x110000; cp++) {
  const has = cp < 0x110000 && !(cp >= 0xD800 && cp <= 0xDFFF) && re.test(String.fromCodePoint(cp));
  if (has && start < 0) start = cp;
  if (!has && start >= 0) {
    out.push(start.toString(16).toUpperCase().padStart(4, "0") + " " + (cp - 1).toString(16).toUpperCase().padStart(4, "0"));
    start = -1;
  }
}
console.log(out.join("\n"));
