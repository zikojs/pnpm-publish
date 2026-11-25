
import { createTemplateSync } from "../packages/workflow/src/pnpm-sync-templates/index.js";

const [operation] = process.argv.slice(2);

const patterns = (process.env.TEMPLATE_PATTERNS || "scafy/templates/*")
  .split(/\r?\n/)
  .map(x => x.trim())
  .filter(Boolean);

const sync = createTemplateSync(process.cwd(), patterns);

switch (operation) {
  case "prepare":
    sync.prepare();
    break;

  case "restore":
    sync.restore();
    break;

  default:
    throw new Error(`Unknown operation: ${operation}`);
}
