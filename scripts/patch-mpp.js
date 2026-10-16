#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const [extractedDir, configPath, reportPath] = process.argv.slice(2);
if (!extractedDir || !configPath || !reportPath) {
  throw new Error("Usage: patch-mpp.js <extracted-asar> <features.json> <report.json>");
}

const upstream = path.resolve(__dirname, "../upstream/ilysenko");
const expectedCommit = "a0b23fed42be7f03d5a23f017efb111b1346a559";
const { execFileSync } = require("node:child_process");
const actualCommit = execFileSync("git", ["-C", upstream, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
if (actualCommit !== expectedCommit) throw new Error(`Unexpected feature source commit: ${actualCommit}`);

const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
if (JSON.stringify(config.enabled) !== JSON.stringify(["model-picker-default-presets"])) {
  throw new Error("MPP must be the only enabled feature");
}
const presets = config.settings?.["model-picker-default-presets"]?.presets;
if (!Array.isArray(presets) || presets.length === 0 ||
    presets.filter((preset) => preset.default === true).length !== 1) {
  throw new Error("Configure at least one preset and exactly one default");
}

const { patchExtractedApp } = require(path.join(upstream, "scripts/patches/runner.js"));
const { createPatchReport, enabledFeatureFailuresFromReport } = require(
  path.join(upstream, "scripts/lib/patch-report.js"));
const { descriptors } = require(path.join(upstream, "linux-features/model-picker-default-presets/patch.js"));
const report = createPatchReport();
const emptyCore = fs.mkdtempSync(path.join(os.tmpdir(), "codex-mpp-core-"));
try {
  patchExtractedApp(extractedDir, {
    report,
    corePatchRoot: emptyCore,
    featuresRoot: path.join(upstream, "linux-features"),
    featuresConfigPath: path.resolve(configPath),
  });
} finally {
  fs.rmSync(emptyCore, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
}

const expectedNames = descriptors.map(({ id }) => `feature:model-picker-default-presets:${id}`).sort();
const actualNames = report.patches.map(({ name }) => name).sort();
if (JSON.stringify(actualNames) !== JSON.stringify(expectedNames) ||
    JSON.stringify(report.enabledFeatures) !== JSON.stringify(["model-picker-default-presets"]) ||
    report.patches.some((patch) => patch.status !== "applied" || patch.sourceKind !== "feature" ||
      patch.featureId !== "model-picker-default-presets" || !patch.assetName) ||
    enabledFeatureFailuresFromReport(report).length) {
  throw new Error(`MPP patch contract failed; inspect ${reportPath}`);
}
console.log(`Verified ${report.patches.length} MPP descriptors; no core descriptors ran`);
