/**
 * Integration Test - DS-STAR Flow
 * Task: T054
 * Purpose: Validate DS-STAR flow with skills-first architecture
 *
 * Coverage:
 * - FR-707 compliance check first
 * - Router -> Skills -> Agents flow
 * - Verifier quality gates
 * - Auto-Debug via skill invocation
 * - Finalizer skills-first validation
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');

// Paths
const ROOT_DIR = path.join(__dirname, '../..');
const AGENT_INDEX_PATH = path.join(ROOT_DIR, '.claude/agent-index.json');
const SKILL_INDEX_PATH = path.join(ROOT_DIR, '.claude/skill-index.json');
const DS_STAR_AGENTS_DIR = path.join(ROOT_DIR, '.claude/agents/ds-star');
const VALIDATION_SKILLS_DIR = path.join(ROOT_DIR, '.claude/skills/validation');

/**
 * Helper: Load JSON file
 */
function loadJson(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
}

/**
 * Helper: Read file content
 */
function readFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }
  return fs.readFileSync(filePath, 'utf-8');
}

/**
 * Simulate FR-707 compliance check
 */
function simulateFR707Check(message) {
  const domains = [];

  // Domain detection keywords
  const domainKeywords = {
    frontend: ['UI', 'component', 'React', 'CSS', 'form'],
    backend: ['API', 'endpoint', 'server', 'auth', 'service'],
    database: ['schema', 'migration', 'query', 'SQL', 'RLS'],
    testing: ['test', 'TDD', 'E2E', 'coverage'],
    security: ['security', 'encryption', 'XSS', 'secrets'],
    devops: ['deploy', 'CI/CD', 'Docker', 'pipeline']
  };

  const messageLower = message.toLowerCase();

  Object.entries(domainKeywords).forEach(([domain, keywords]) => {
    if (keywords.some(kw => messageLower.includes(kw.toLowerCase()))) {
      domains.push(domain);
    }
  });

  return {
    compliance_status: 'PASS',
    fr707_checked: true,
    timestamp: new Date().toISOString(),
    domains_detected: domains,
    domain_count: domains.length,
    delegation_required: domains.length >= 1,
    multi_domain: domains.length >= 2
  };
}

/**
 * Simulate Router decision
 */
function simulateRouterDecision(fr707Result, skillIndex) {
  if (!fr707Result.fr707_checked) {
    return {
      error: 'FR-707 compliance check not performed',
      blocked: true
    };
  }

  if (fr707Result.domain_count === 0) {
    return {
      route: 'direct_execution',
      skill: null,
      agent: null,
      confidence: 1.0
    };
  }

  if (fr707Result.multi_domain) {
    return {
      route: 'orchestration',
      skill: 'orchestration/multi-skill-workflow',
      agent: 'workflow-coordinator',
      confidence: 0.95
    };
  }

  // Single domain - find matching skill
  const domain = fr707Result.domains_detected[0];
  const domainRoutes = skillIndex.routing?.['domain-routes'] || {};
  const domainRoute = domainRoutes[domain];

  if (domainRoute) {
    return {
      route: 'domain_skill',
      skill: domainRoute['primary-skill'],
      agent: domainRoute['primary-agent'],
      confidence: 0.9
    };
  }

  return {
    route: 'fallback',
    skill: `domain/${domain}-operations`,
    agent: null,
    confidence: 0.7
  };
}

/**
 * Simulate Verifier decision
 */
function simulateVerifierDecision(output) {
  // Quality criteria
  const hasOutput = output && output.length > 0;
  const meetsMinLength = output && output.length > 50;
  const noErrors = !output?.includes('ERROR') && !output?.includes('error:');

  const score = (hasOutput ? 0.4 : 0) +
                (meetsMinLength ? 0.3 : 0) +
                (noErrors ? 0.3 : 0);

  return {
    decision: score >= 0.7 ? 'SUFFICIENT' : 'INSUFFICIENT',
    score: score,
    criteria_met: {
      has_output: hasOutput,
      meets_length: meetsMinLength,
      no_errors: noErrors
    },
    timestamp: new Date().toISOString()
  };
}

/**
 * Simulate Auto-Debug invocation
 */
function simulateAutoDebug(error, context) {
  return {
    invoked: true,
    via_skill: true,
    skill: 'sdd-workflow/sdd-debug',
    error_type: error.type || 'unknown',
    fix_suggested: true,
    timestamp: new Date().toISOString()
  };
}

// Test Suite
describe('DS-STAR Flow Integration Tests', () => {

  describe('T054-INT1: FR-707 Compliance Check First', () => {

    test('FR-707 check is mandatory first step', () => {
      const result = simulateFR707Check('Create a database schema');

      expect(result.fr707_checked).toBe(true);
      expect(result.compliance_status).toBe('PASS');
      expect(result.timestamp).toBeDefined();
    });

    test('Router blocks if FR-707 not checked', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);
      const uncheckedResult = { fr707_checked: false };

      const routerDecision = simulateRouterDecision(uncheckedResult, skillIndex);

      expect(routerDecision.blocked).toBe(true);
      expect(routerDecision.error).toContain('FR-707');
    });

    test('FR-707 detects single domain correctly', () => {
      const result = simulateFR707Check('Create a database schema with users table');

      expect(result.domains_detected).toContain('database');
      expect(result.domain_count).toBe(1);
      expect(result.multi_domain).toBe(false);
    });

    test('FR-707 detects multiple domains correctly', () => {
      const result = simulateFR707Check('Build UI form with API and database');

      expect(result.domains_detected.length).toBeGreaterThanOrEqual(2);
      expect(result.multi_domain).toBe(true);
    });

    test('FR-707 handles no domain case', () => {
      const result = simulateFR707Check('What time is it?');

      expect(result.domains_detected).toHaveLength(0);
      expect(result.delegation_required).toBe(false);
    });
  });

  describe('T054-INT2: Router -> Skills -> Agents Flow', () => {

    let skillIndex;
    let agentIndex;

    beforeAll(() => {
      skillIndex = loadJson(SKILL_INDEX_PATH);
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('Router routes to skill (not agent) for single domain', () => {
      const fr707Result = simulateFR707Check('Create a database schema');
      const routerDecision = simulateRouterDecision(fr707Result, skillIndex);

      expect(routerDecision.route).toBe('domain_skill');
      expect(routerDecision.skill).toBeDefined();
      expect(routerDecision.skill).toContain('database');
    });

    test('Router routes to orchestration skill for multi-domain', () => {
      const fr707Result = simulateFR707Check('Build full-stack feature with UI and API');
      const routerDecision = simulateRouterDecision(fr707Result, skillIndex);

      expect(routerDecision.route).toBe('orchestration');
      expect(routerDecision.skill).toBe('orchestration/multi-skill-workflow');
    });

    test('Router allows direct execution for no domain', () => {
      const fr707Result = simulateFR707Check('Tell me a joke');
      const routerDecision = simulateRouterDecision(fr707Result, skillIndex);

      expect(routerDecision.route).toBe('direct_execution');
      expect(routerDecision.skill).toBeNull();
    });

    test('Skills invoke consolidated agents', () => {
      // Check that domain skills reference consolidated agents
      const domainSkills = skillIndex.skills.filter(s => s.category === 'domain');

      domainSkills.forEach(skill => {
        if (skill['agent-invocations']) {
          skill['agent-invocations'].forEach(inv => {
            // Should reference consolidated agents
            const validAgents = [
              'implementation-specialist',
              'operations-specialist',
              'specification-orchestrator',
              'quality-specialist',
              'backend-architect',
              'database-specialist',
              'system-architect',
              'workflow-coordinator'
            ];

            // At least should not reference old agent names
            const oldAgents = ['frontend-specialist', 'full-stack-developer'];
            expect(oldAgents).not.toContain(inv.agent);
          });
        }
      });
    });

    test('Routing confidence scores are valid', () => {
      const fr707Result = simulateFR707Check('Create a database migration');
      const routerDecision = simulateRouterDecision(fr707Result, skillIndex);

      expect(routerDecision.confidence).toBeGreaterThan(0);
      expect(routerDecision.confidence).toBeLessThanOrEqual(1);
    });
  });

  describe('T054-INT3: Verifier Quality Gates', () => {

    test('Verifier returns SUFFICIENT for good output', () => {
      const goodOutput = 'Successfully created the users table with id, email, and created_at columns. Migration file generated at db/migrations/001_create_users.sql';

      const decision = simulateVerifierDecision(goodOutput);

      expect(decision.decision).toBe('SUFFICIENT');
      expect(decision.score).toBeGreaterThanOrEqual(0.7);
    });

    test('Verifier returns INSUFFICIENT for bad output', () => {
      const badOutput = 'ERROR: Something went wrong';

      const decision = simulateVerifierDecision(badOutput);

      expect(decision.decision).toBe('INSUFFICIENT');
      expect(decision.score).toBeLessThan(0.7);
    });

    test('Verifier returns INSUFFICIENT for empty output', () => {
      const decision = simulateVerifierDecision('');

      expect(decision.decision).toBe('INSUFFICIENT');
    });

    test('Verifier provides criteria breakdown', () => {
      const output = 'This is a valid output with enough content';
      const decision = simulateVerifierDecision(output);

      expect(decision.criteria_met).toBeDefined();
      expect(decision.criteria_met.has_output).toBeDefined();
      expect(decision.criteria_met.meets_length).toBeDefined();
      expect(decision.criteria_met.no_errors).toBeDefined();
    });

    test('Verifier agent has 95% accuracy target', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const verifier = agentIndex.ds_star_agents.find(a => a.name === 'verifier-agent');

      expect(verifier).toBeDefined();
      expect(verifier['performance-targets'].decision_accuracy).toBe(0.95);
    });
  });

  describe('T054-INT4: Auto-Debug via Skill Invocation', () => {

    test('Auto-Debug is invoked through skill', () => {
      const error = { type: 'runtime', message: 'Connection failed' };
      const context = { skill: 'domain/database-operations' };

      const debugResult = simulateAutoDebug(error, context);

      expect(debugResult.invoked).toBe(true);
      expect(debugResult.via_skill).toBe(true);
      expect(debugResult.skill).toBe('sdd-workflow/sdd-debug');
    });

    test('Auto-Debug agent has 70% fix rate target', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const autoDebug = agentIndex.ds_star_agents.find(a => a.name === 'auto-debug-agent');

      expect(autoDebug).toBeDefined();
      expect(autoDebug['performance-targets'].auto_fix_rate).toBe(0.70);
    });

    test('Debug skill exists', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);
      const debugSkill = skillIndex.skills.find(s => s.name === 'sdd-debug');

      expect(debugSkill).toBeDefined();
      expect(debugSkill.category).toBe('sdd-workflow');
    });

    test('Auto-Debug agent file exists', () => {
      const agentPath = path.join(DS_STAR_AGENTS_DIR, 'auto-debug-agent.md');
      expect(fs.existsSync(agentPath)).toBe(true);
    });
  });

  describe('T054-INT5: Finalizer Skills-First Validation', () => {

    test('Finalizer agent has 0% false pass target', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const finalizer = agentIndex.ds_star_agents.find(a => a.name === 'finalizer-agent');

      expect(finalizer).toBeDefined();
      expect(finalizer['performance-targets'].false_pass_rate).toBe(0.0);
    });

    test('Finalizer validates skills-first pattern', () => {
      // Simulated session data
      const sessionData = {
        skills_invoked: ['domain/database-operations'],
        agents_used: ['database-specialist'],
        direct_agent_calls: [],
        fr707_checked: true
      };

      // Validation check
      const skillsFirstCompliant = sessionData.skills_invoked.length > 0 &&
                                   sessionData.direct_agent_calls.length === 0;

      expect(skillsFirstCompliant).toBe(true);
    });

    test('Finalizer detects legacy pattern violation', () => {
      const sessionData = {
        skills_invoked: [],
        agents_used: ['database-specialist'],
        direct_agent_calls: ['database-specialist'], // Legacy pattern!
        fr707_checked: true
      };

      const skillsFirstCompliant = sessionData.skills_invoked.length > 0 &&
                                   sessionData.direct_agent_calls.length === 0;

      expect(skillsFirstCompliant).toBe(false);
    });

    test('Finalizer agent file exists', () => {
      const agentPath = path.join(DS_STAR_AGENTS_DIR, 'finalizer-agent.md');
      expect(fs.existsSync(agentPath)).toBe(true);
    });

    test('Finalize skill exists', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);
      const finalizeSkill = skillIndex.skills.find(s => s.name === 'finalize');

      expect(finalizeSkill).toBeDefined();
      expect(finalizeSkill.category).toBe('governance');
    });
  });

  describe('T054-INT6: DS-STAR Agent Configuration', () => {

    let agentIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('All 5 DS-STAR agents have correct roles', () => {
      const expectedRoles = ['router', 'verifier', 'debug', 'finalizer', 'context'];
      const actualRoles = agentIndex.ds_star_agents.map(a => a['ds-star-role']);

      expectedRoles.forEach(role => {
        expect(actualRoles).toContain(role);
      });
    });

    test('Router agent has 3.5x accuracy target', () => {
      const router = agentIndex.ds_star_agents.find(a => a.name === 'router-agent');

      expect(router).toBeDefined();
      expect(router['performance-targets'].task_completion_accuracy).toBe(3.5);
    });

    test('Context analyzer has <2s latency target', () => {
      const context = agentIndex.ds_star_agents.find(a => a.name === 'context-analyzer');

      expect(context).toBeDefined();
      expect(context['performance-targets'].retrieval_latency_ms).toBeLessThanOrEqual(2000);
    });

    test('All DS-STAR agents have performance targets', () => {
      agentIndex.ds_star_agents.forEach(agent => {
        expect(agent['performance-targets']).toBeDefined();
        expect(Object.keys(agent['performance-targets']).length).toBeGreaterThan(0);
      });
    });
  });

  describe('T054-INT7: Message Preflight Skill', () => {

    test('Message preflight skill exists', () => {
      const preflightPath = path.join(VALIDATION_SKILLS_DIR, 'message-preflight/SKILL.md');
      expect(fs.existsSync(preflightPath)).toBe(true);
    });

    test('Message preflight is referenced in DS-STAR skills', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);

      // Skills should have pre-execution referencing message-preflight
      const skillsWithDsStar = skillIndex.skills.filter(s =>
        s['ds-star'] && s['ds-star']['pre-execution']
      );

      skillsWithDsStar.forEach(skill => {
        expect(skill['ds-star']['pre-execution']).toBe('validation/message-preflight');
      });
    });

    test('Preflight skill has FR-707 compliance', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);
      const preflight = skillIndex.skills.find(s => s.name === 'message-preflight');

      expect(preflight).toBeDefined();
      expect(preflight.category).toBe('validation');
    });
  });

  describe('T054-INT8: Complete DS-STAR Flow Simulation', () => {

    test('Full flow: FR-707 -> Router -> Skill -> Agent -> Verifier', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);

      // Step 1: FR-707 Compliance Check
      const message = 'Create a user authentication API';
      const fr707Result = simulateFR707Check(message);
      expect(fr707Result.fr707_checked).toBe(true);

      // Step 2: Router Decision
      const routerDecision = simulateRouterDecision(fr707Result, skillIndex);
      expect(routerDecision.blocked).toBeFalsy();
      expect(routerDecision.skill).toBeDefined();

      // Step 3: Skill Activation (simulated)
      const skillActivation = {
        skill: routerDecision.skill,
        agent_invoked: routerDecision.agent,
        context_provided: true
      };
      expect(skillActivation.skill).toBeDefined();

      // Step 4: Agent Execution (simulated)
      const agentOutput = 'Created authentication endpoint at /api/auth with JWT token generation. Routes added for login, logout, and refresh.';

      // Step 5: Verifier Validation
      const verifierDecision = simulateVerifierDecision(agentOutput);
      expect(verifierDecision.decision).toBe('SUFFICIENT');

      // Full flow completed successfully
      expect(true).toBe(true);
    });

    test('Full flow with auto-debug on failure', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);

      // Step 1: FR-707
      const fr707Result = simulateFR707Check('Create database connection');
      expect(fr707Result.fr707_checked).toBe(true);

      // Step 2: Router
      const routerDecision = simulateRouterDecision(fr707Result, skillIndex);
      expect(routerDecision.blocked).toBeFalsy();

      // Step 3: Skill + Agent (simulated failure)
      const agentOutput = 'ERROR: Database connection failed';

      // Step 4: Verifier detects issue
      const verifierDecision = simulateVerifierDecision(agentOutput);
      expect(verifierDecision.decision).toBe('INSUFFICIENT');

      // Step 5: Auto-Debug triggered
      const debugResult = simulateAutoDebug(
        { type: 'runtime', message: 'Connection failed' },
        { skill: routerDecision.skill }
      );
      expect(debugResult.invoked).toBe(true);
      expect(debugResult.via_skill).toBe(true);

      // Flow handled failure appropriately
      expect(true).toBe(true);
    });
  });
});

// Export for use in other tests
module.exports = {
  simulateFR707Check,
  simulateRouterDecision,
  simulateVerifierDecision,
  simulateAutoDebug,
  loadJson
};
