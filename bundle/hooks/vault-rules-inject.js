#!/usr/bin/env node
// vault-rules-inject.js — PreToolUse hook for Core Vault rules injection.

const fs = require('fs');
const path = require('path');

// Resolve vault path: --vault-path arg > $VAULT_PATH env > state file > auto-detect
function resolveVaultPath() {
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length - 1; i++) {
    if (args[i] === '--vault-path') return args[i + 1];
  }
  if (process.env.VAULT_PATH) return process.env.VAULT_PATH;

  const stateFile = path.join(process.env.HOME || '/root', '.claude/hooks/vault-rules-state.json');
  try {
    const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
    if (state.vault_path) return state.vault_path;
  } catch (_) { /* fall through */ }

  // Auto-detect: scan ~/.vault/*/AGENTS.md for single vault
  const vaultDir = path.join(process.env.HOME || '/root', '.vault');
  try {
    const entries = fs.readdirSync(vaultDir);
    for (const entry of entries) {
      const agentsPath = path.join(vaultDir, entry, 'AGENTS.md');
      if (fs.existsSync(agentsPath)) return path.join(vaultDir, entry);
    }
  } catch (_) { /* no vault dir */ }

  return null;
}

const VAULT_ROOT = resolveVaultPath();
if (!VAULT_ROOT) process.exit(0);

let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 5000);

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);

  try {
    const data = JSON.parse(input);
    const toolName = data.tool_name;

    if (toolName === 'Read') {
      const filePath = data.args?.file_path || '';
      if (!filePath.startsWith(VAULT_ROOT)) return;
      if (path.basename(filePath) === 'AGENTS.md') return;
    }

    if (toolName === 'Bash') {
      const cmd = data.args?.command || '';
      if (!cmd.includes('obsidian') && !cmd.includes('wiki_tool')) return;
    }

    const agentsPath = path.join(VAULT_ROOT, 'AGENTS.md');
    if (!fs.existsSync(agentsPath)) return;

    const rules = fs.readFileSync(agentsPath, 'utf8');
    console.log(`=== Vault Rules ===

The agent must use the following rules when working with this vault:
${rules}

=== End Vault Rules ===`);
  } catch (e) { /* silently ignore errors */ }
});
