// The sign of the root collator of the ECMAScript Intl object for each
// input pair. Each line holds two texts in hex code points, separated
// by a bar. The output holds -1, 0 or 1. The und locale is the root
// locale.
import { createInterface } from "node:readline";

const col = new Intl.Collator("und");
const rl = createInterface({ input: process.stdin });
for await (const line of rl) {
    const [a, b] = line.split("|");
    const text = (hex) => {
        let s = "";
        for (const f of hex.trim().split(/\s+/)) {
            s += String.fromCodePoint(parseInt(f, 16));
        }
        return s;
    };
    process.stdout.write(`${col.compare(text(a), text(b))}\n`);
}
