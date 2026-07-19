#!/usr/bin/env node
/**
 * USSD sync check — CASERO (iOS).
 *
 * MyUSSDCodes-collection is the single source of truth for USSD/SMS codes across
 * all of albertolicea00's apps. CASERO's guest-report code is NOT finalized yet:
 * `USSDSMSReporter` still ships `smsDestination` / `reportBody` placeholders, and
 * the canonical `casero-report` collection is a placeholder too.
 *
 * This check stays RED on purpose until the real reporting code is published in
 * MyUSSDCodes-collection (the `placeholder` tag removed from casero-report.json).
 * That red is the reminder that the code is still unspecified. Once it's real,
 * the check goes green — then wire the actual dial string into both apps.
 *
 * Zero dependencies. Node 18+ (uses global fetch). Exit 0 = ready, 1 = not yet.
 *
 * Local testing:
 *   CANONICAL_FILE=../my-ussd-codes/my-ussd-codes-collection/codes/casero-report.json \
 *     node .github/scripts/check-ussd-sync.mjs
 */

import fs from "node:fs";

const CANONICAL_ID = "casero-report";
const CANONICAL_URL = `https://raw.githubusercontent.com/albertolicea00/MyUSSDCodes-collection/main/codes/${CANONICAL_ID}.json`;

const lines = [];
const say = (s = "") => lines.push(s);

async function loadCanonical() {
  if (process.env.CANONICAL_FILE) {
    return JSON.parse(fs.readFileSync(process.env.CANONICAL_FILE, "utf8"));
  }
  const res = await fetch(CANONICAL_URL, { headers: { "user-agent": "ussd-sync-check" } });
  if (!res.ok) {
    throw new Error(`canonical not reachable: HTTP ${res.status} for ${CANONICAL_URL}`);
  }
  return res.json();
}

async function main() {
  let canonical;
  try {
    canonical = await loadCanonical();
  } catch (err) {
    say(`## USSD sync check failed to run`);
    say();
    say(String(err.message));
    finish(true);
    return;
  }

  const codes = canonical.codes ?? [];
  const placeholders = codes.filter((c) => (c.tags ?? []).includes("placeholder"));

  if (placeholders.length > 0) {
    say(`## CASERO reporting code is not finalized`);
    say();
    say(`Source of truth: [MyUSSDCodes-collection \`codes/${CANONICAL_ID}.json\`](${CANONICAL_URL})`);
    say();
    say(`The official casero.rem.cu USSD/SMS guest-report format is still a placeholder:`);
    say("```");
    placeholders.forEach((c) => say(`${c.code}  — ${c.name}`));
    say("```");
    say();
    say(`This check is expected to stay red until the real code is published in`);
    say(`MyUSSDCodes-collection (remove the \`placeholder\` tag). Then replace the`);
    say(`\`smsDestination\` / \`reportBody\` placeholders in \`USSDSMSReporter\`.`);
    finish(true);
    return;
  }

  say(`Ready: MyUSSDCodes-collection \`${CANONICAL_ID}\` has a real reporting code.`);
  say(`Make sure \`USSDSMSReporter\` matches it, then close the tracking issue.`);
  finish(false);
}

function finish(notReady) {
  const out = lines.join("\n") + "\n";
  process.stdout.write(out);
  if (process.env.REPORT_FILE) fs.writeFileSync(process.env.REPORT_FILE, out);
  process.exit(notReady ? 1 : 0);
}

main();
