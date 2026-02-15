#!/usr/bin/env node
/**
 * Governance Pre-flight Hook
 *
 * This hook runs before each user prompt is submitted to Claude Code.
 * It enforces the 4-step compliance protocol from FR-707.
 *
 * Constitutional Reference: .specify/memory/constitution.md
 * Output Contract: { blocked: false, hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: string } }
 *
 * Audit Trail: Writes session logs to .docs/governance/audit/YYYY-MM-DD/
 * Version: 1.1.0
 */

const fs = require('fs');
const path = require('path');

// Get repo root (assuming hook is at .claude/hooks/user-prompt-submit/)
const REPO_ROOT = path.resolve(__dirname, '../../..');
const AUDIT_BASE = path.join(REPO_ROOT, '.docs', 'governance', 'audit');

// Constitutional principles (v3.0.0 - 16 principles)
const CONSTITUTIONAL_PRINCIPLES = [
  'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X',
  'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI'
];

// Read the user's prompt from stdin
let userPrompt = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  userPrompt += chunk;
});

process.stdin.on('end', async () => {
  const startTime = Date.now();

  // Parse the hook input
  let hookInput;
  try {
    hookInput = JSON.parse(userPrompt);
  } catch (e) {
    // If not JSON, treat as raw prompt
    hookInput = { message: userPrompt };
  }

  const prompt = hookInput.message || hookInput.prompt || userPrompt;

  // Detect domains from keywords
  const domains = detectDomains(prompt);

  // Build compliance reminder to inject
  const complianceContext = buildComplianceContext(prompt, domains);

  // Calculate duration
  const durationMs = Date.now() - startTime;

  // Write audit log - wait for it to complete before exiting
  try {
    await writeAuditLog(prompt, domains, durationMs);
  } catch (err) {
    // Silently ignore logging errors to not block the hook
    // Could optionally log to stderr: console.error('Audit log failed:', err.message);
  }

  // Output per Claude Code hook contract - MUST include hookEventName
  const output = {
    blocked: false,
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: complianceContext
    }
  };

  console.log(JSON.stringify(output));
});

function buildComplianceContext(prompt, domains) {
  // Build contextual reminder
  let context = '## Pre-Flight Compliance Check (FR-707)\n\n';
  context += '**Constitution**: v3.0.0 (16 Principles)\n';
  context += '**Critical Principles**: II (Test-First >80%), VI (Git Approval), X (Skill-First Routing)\n\n';

  if (domains.length > 0) {
    context += `**Detected Domains**: ${domains.join(', ')}\n`;
    context += '**Routing**: Activate appropriate specialist skills\n\n';
  }

  context += '---\n';

  return context;
}

function detectDomains(prompt) {
  const domainKeywords = {
    'frontend': ['UI', 'component', 'React', 'Next.js', 'CSS', 'HTML', 'responsive', 'button', 'form', 'layout'],
    'backend': ['API', 'endpoint', 'service', 'server', 'REST', 'GraphQL', 'middleware', 'route'],
    'database': ['schema', 'migration', 'query', 'SQL', 'PostgreSQL', 'data model', 'table', 'index'],
    'testing': ['test', 'E2E', 'integration', 'coverage', 'jest', 'pytest', 'spec', 'assert'],
    'security': ['auth', 'encryption', 'XSS', 'SQL injection', 'JWT', 'OAuth', 'password', 'token'],
    'devops': ['deploy', 'CI/CD', 'Docker', 'pipeline', 'Kubernetes', 'container', 'build']
  };

  const detected = [];
  const lowerPrompt = prompt.toLowerCase();

  for (const [domain, keywords] of Object.entries(domainKeywords)) {
    for (const keyword of keywords) {
      if (lowerPrompt.includes(keyword.toLowerCase())) {
        if (!detected.includes(domain)) {
          detected.push(domain);
        }
        break;
      }
    }
  }

  return detected;
}

/**
 * Write audit log to .docs/governance/audit/YYYY-MM-DD/session-*.json
 */
async function writeAuditLog(prompt, domains, durationMs) {
  const now = new Date();

  // Generate timestamp in ISO format with local timezone offset
  const tzOffset = -now.getTimezoneOffset();
  const tzHours = String(Math.floor(Math.abs(tzOffset) / 60)).padStart(2, '0');
  const tzMins = String(Math.abs(tzOffset) % 60).padStart(2, '0');
  const tzSign = tzOffset >= 0 ? '+' : '-';
  const timestamp = now.toISOString().replace('Z', `${tzSign}${tzHours}:${tzMins}`);

  // Generate session ID (epoch seconds + random suffix)
  const epochSeconds = Math.floor(now.getTime() / 1000);
  const randomSuffix = Math.floor(Math.random() * 100000);
  const sessionId = `${epochSeconds}-${randomSuffix}`;

  // Create date folder path using LOCAL date (YYYY-MM-DD)
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const dateFolder = `${year}-${month}-${day}`;
  const auditDir = path.join(AUDIT_BASE, dateFolder);

  // Create audit log entry
  const auditEntry = {
    timestamp: timestamp,
    session_id: sessionId,
    event_type: 'context_injection',
    decision_type: 'context_injection',
    layer: 'hook',
    agent_role: 'governance-hook',
    input_summary: JSON.stringify({
      user_message: prompt.substring(0, 200), // Truncate for summary
      message_length: prompt.length,
      detected_domains: domains
    }),
    output: {
      action: 'inject_governance_context',
      blocked: false,
      domains_detected: domains
    },
    constitutional_principles: CONSTITUTIONAL_PRINCIPLES,
    duration_ms: durationMs
  };

  // Ensure audit directory exists
  await fs.promises.mkdir(auditDir, { recursive: true });

  // Write session file
  const sessionFile = path.join(auditDir, `session-${sessionId}.json`);
  await fs.promises.writeFile(
    sessionFile,
    JSON.stringify(auditEntry, null, 2),
    'utf8'
  );
}
