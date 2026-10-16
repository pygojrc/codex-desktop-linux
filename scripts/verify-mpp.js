#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");

const [beforePath, afterPath, reportPath] = process.argv.slice(2);
const readManifest = (file) => new Map(fs.readFileSync(file, "utf8").trimEnd().split("\n")
  .map((line) => {
    const match = /^([a-f0-9]{64})  (.*)$/.exec(line);
    if (!match) throw new Error(`Invalid hash manifest line in ${file}`);
    return [match[2], match[1]];
  }));
const before = readManifest(beforePath);
const after = readManifest(afterPath);
if (before.size !== after.size || [...before.keys()].some((file) => !after.has(file))) {
  throw new Error("ASAR extraction added or removed files");
}
const changed = [...before.keys()].filter((file) => before.get(file) !== after.get(file));
const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const expected = new Set(report.patches.map((patch) => patch.assetName));
if (changed.length !== expected.size || changed.some((file) => !expected.has(path.basename(file)))) {
  throw new Error(`Unexpected ASAR changes: ${JSON.stringify(changed)}; expected assets ${JSON.stringify([...expected])}`);
}
console.log(`Only ${changed.length} expected webview assets changed: ${changed.join(", ")}`);
