#!/usr/bin/env node
// Astro has no equivalent of `mkdocs build --strict`. This walks the built site and
// checks that every internal href resolves to a page or an asset that exists, so a
// broken cross-reference fails the build rather than reaching the published site.
import { readFileSync, existsSync } from "node:fs";
import { readdirSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

const DIST = "dist";
const BASE = "/mitoforge";

if (!existsSync(DIST)) {
    console.error(`${DIST}/ not found - run \`npm run build\` first.`);
    process.exit(1);
}

function walk(dir) {
    return readdirSync(dir).flatMap((name) => {
        const p = join(dir, name);
        return statSync(p).isDirectory() ? walk(p) : [p];
    });
}

const files = walk(DIST);
const html = files.filter((f) => f.endsWith(".html"));

// Every URL the site actually serves.
const pages = new Set(
    html
        .filter((f) => f.endsWith(`${sep}index.html`))
        .map((f) => {
            const rel = relative(DIST, f).slice(0, -"index.html".length).split(sep).join("/");
            return `${BASE}/${rel}`;
        }),
);

let checked = 0;
const broken = [];

for (const file of html) {
    const text = readFileSync(file, "utf8");
    for (const m of text.matchAll(/href="([^"]+)"/g)) {
        const href = m[1].replace(/&amp;/g, "&");
        if (!href.startsWith(BASE)) continue;
        const target = href.split("#")[0];
        checked++;
        if (target.endsWith("/")) {
            if (!pages.has(target)) broken.push([relative(DIST, file), href]);
        } else if (!existsSync(join(DIST, target.slice(BASE.length + 1)))) {
            broken.push([relative(DIST, file), href]);
        }
    }
}

console.log(`pages: ${pages.size}   internal links checked: ${checked}   broken: ${broken.length}`);
if (broken.length) {
    for (const [from, href] of broken) console.error(`  ${from}  ->  ${href}`);
    process.exit(1);
}
