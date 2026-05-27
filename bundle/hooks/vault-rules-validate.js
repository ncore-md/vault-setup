#!/usr/bin/env node
// vault-rules-validate.js — PreToolUse hook
// Blocks direct writes to managed vault paths. Agents must use Obsidian CLI or wiki_tool.py.

const fs = require('fs');
const path = require('path');

// Resolve vault paths: --vault-path arg > $VAULT_PATH env > state file > auto-detect
function resolveVaultPaths() {
  const args = process.argv.slice(2);

  // Single --vault-path flag (for backward compat)
  for (let i = 0; i < args.length - 1; i++) {
    if (args[i] === '--vault-path') return [args[i + 1]];
  }

  // Comma-separated $VAULT_PATH (e.g., "/path/a,/path/b")
  if (process.env.VAULT_PATH) {
    return process.env.VAULT_PATH.split(',').map(p => p.trim()).filter(Boolean);
  }

  const stateFile = path.join(process.env.HOME || '/root', '.claude/hooks/vault-rules-state.json');
  try {
    const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
    if (state.vault_paths && Array.isArray(state.vault_paths) && state.vault_paths.length > 0) {
      return state.vault_paths;
    }
    if (state.vault_path) {
      return [state.vault_path];
    }
  } catch (_) { /* fall through */ }

  // Auto-detect: scan ~/.vault/*/AGENTS.md
  const vaultDir = path.join(process.env.HOME || '/root', '.vault');
  try {
    const entries = fs.readdirSync(vaultDir);
    return entries.map(e => path.join(vaultDir, e)).filter(p => fs.existsSync(path.join(p, 'AGENTS.md')));
  } catch (_) { /* no vault dir */ }

  return [];
}

const VAULT_PATHS = resolveVaultPaths();
if (VAULT_PATHS.length === 0) process.exit(0);

let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 3000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);

  try {
    const data = JSON.parse(input);
    if (data.tool_name !== 'Write' && data.tool_name !== 'Edit') return;

    const filePath = data.args?.file_path || '';
    for (const vaultPath of VAULT_PATHS) {
      if (filePath.startsWith(vaultPath)) {
        console.log(`BLOCKED: Direct write to managed vault is not allowed. Use Obsidian CLI or wiki_tool.py instead.`);
        process.exit(1);
      }
    }
  } catch (e) { /* silently ignore */ }
});
