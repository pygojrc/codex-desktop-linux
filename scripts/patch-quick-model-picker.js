#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const assetDir = process.argv[2];
if (!assetDir) {
  throw new Error("usage: patch-quick-model-picker.js <webview-assets-dir>");
}

const files = fs
  .readdirSync(assetDir)
  .filter((name) => /^app-primary-[^.]+\.js$/.test(name));
if (files.length !== 1) {
  throw new Error(`expected one app-primary bundle, found ${files.length}`);
}

const filePath = path.join(assetDir, files[0]);
const source = fs.readFileSync(filePath, "utf8");
const marker = "codex-linux-luna-medium-quick-slider";
if (source.includes(marker)) {
  process.stdout.write(`already patched: ${filePath}\n`);
  process.exit(0);
}

const functionStart = source.indexOf("function hur(");
if (functionStart < 0 || source.indexOf("function hur(", functionStart + 1) >= 0) {
  throw new Error("expected exactly one hur function");
}

const parameterStart = source.indexOf("(", functionStart);
let parameterDepth = 0;
let parameterQuote = null;
let parameterEscaped = false;
let parameterEnd = -1;
for (let i = parameterStart; i < source.length; i += 1) {
  const ch = source[i];
  if (parameterQuote !== null) {
    if (parameterEscaped) {
      parameterEscaped = false;
    } else if (ch === "\\") {
      parameterEscaped = true;
    } else if (ch === parameterQuote) {
      parameterQuote = null;
    }
    continue;
  }
  if (ch === "`" || ch === "'" || ch === '"') {
    parameterQuote = ch;
  } else if (ch === "(") {
    parameterDepth += 1;
  } else if (ch === ")") {
    parameterDepth -= 1;
    if (parameterDepth === 0) {
      parameterEnd = i + 1;
      break;
    }
  }
}
if (parameterEnd < 0) {
  throw new Error("could not find the end of hur parameters");
}

const braceStart = source.indexOf("{", parameterEnd);
if (braceStart < 0) {
  throw new Error("could not find the start of hur body");
}
let depth = 0;
let quote = null;
let escaped = false;
let functionEnd = -1;
for (let i = braceStart; i < source.length; i += 1) {
  const ch = source[i];
  if (quote !== null) {
    if (escaped) {
      escaped = false;
    } else if (ch === "\\") {
      escaped = true;
    } else if (ch === quote) {
      quote = null;
    }
    continue;
  }
  if (ch === "`" || ch === "'" || ch === '"') {
    quote = ch;
    continue;
  }
  if (ch === "{") {
    depth += 1;
  } else if (ch === "}") {
    depth -= 1;
    if (depth === 0) {
      functionEnd = i + 1;
      break;
    }
  }
}

if (functionEnd < 0) {
  throw new Error("could not find the end of hur function");
}

const original = source.slice(functionStart, functionEnd);
if (!original.includes("sliderModelsConfig")) {
  throw new Error("hur marker missing: sliderModelsConfig");
}
for (const required of ["function vur(", "function xur(", "supportedReasoningEfforts", "wur", "Eur"]) {
  if (!original.includes(required)) {
    if (!source.includes(required)) {
      throw new Error(`bundle marker missing: ${required}`);
    }
  }
}
for (const required of ["supportedReasoningEfforts", "wur", "Eur"]) {
  if (!source.includes(required)) {
    throw new Error(`bundle marker missing: ${required}`);
  }
}
if (!source.includes("gpt-5.6-sol")) {
  throw new Error("bundle marker missing: gpt-5.6-sol");
}

const wrapped = `${original.replace("function hur(", "function codexLinuxOriginalHur(")}
function hur(e,options={}){let codexLinuxSelections=codexLinuxOriginalHur(e,options),codexLinuxLuna={id:\`gpt-5.6-luna:medium\`,model:\`gpt-5.6-luna\`,modelLabel:\`5.6 Luna\`,reasoningEffort:\`medium\`},codexLinuxHasLuna=Array.isArray(e)&&e.some(({model:t})=>t===\`gpt-5.6-luna\`),codexLinuxHasMedium=Array.isArray(e)&&e.some(({model:t,supportedReasoningEfforts:n})=>t===\`gpt-5.6-luna\`&&n?.some(({reasoningEffort:t})=>t===\`medium\`));if(!codexLinuxHasLuna&&!codexLinuxHasMedium)return[codexLinuxLuna,...codexLinuxSelections.filter(({model:t})=>t!==\`gpt-5.6-luna\`)].map((e,t)=>({...e,powerSettingIndex:t}));let codexLinuxLunaSelections=vur(e).filter(({model:t,reasoningEffort:n})=>t===\`gpt-5.6-luna\`&&n===\`medium\`);if(codexLinuxLunaSelections.length===0)codexLinuxLunaSelections=[codexLinuxLuna];return[...codexLinuxLunaSelections,...codexLinuxSelections.filter(({model:t})=>t!==\`gpt-5.6-luna\`)].map((e,t)=>({...e,powerSettingIndex:t}))}/*${marker}*/`;

fs.writeFileSync(filePath, source.slice(0, functionStart) + wrapped + source.slice(functionEnd));
process.stdout.write(`patched: ${filePath}\n`);
