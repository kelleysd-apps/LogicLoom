/**
 * Integration Test - Skills-First Architecture
 * Tasks: T039, T040
 * Purpose: Validate end-to-end skills-first workflow with RL and DS-STAR
 *
 * Coverage:
 * - FR-707 compliance check integration
 * - RL-enhanced skill selection
 * - Agent consolidation
 * - DS-STAR flow
 * - Hybrid mode backward compatibility
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');

// Paths
const ROOT_DIR = path.join(__dirname, '../..');
const SKILL_INDEX_PATH = path.join(ROOT_DIR, '.claude/skill-index.json');
const AGENT_INDEX_PATH = path.join(ROOT_DIR, '.claude/agent-index.json');
const PERFORMANCE_PATH = path.join(ROOT_DIR, '.docs/rl-metrics/skill-performance.json');
const ARCHITECTURE_CONF_PATH = path.join(ROOT_DIR, '.logic-loom/config/architecture.conf');

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
 * Helper: Load config file
 */
function loadConfig(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  const config = {};
  content.split('\n').forEach(line => {
    if (line && !line.startsWith('#') && line.includes('=')) {
      const [key, value] = line.split('=');
      config[key.trim()] = value.trim();
    }
  });
  return config;
}

/**
 * Simulate FR-707 compliance check
 */
function simulateComplianceCheck(message) {
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
    timestamp: new Date().toISOString(),
    domains_detected: domains,
    delegation_target: domains.length >= 2
      ? 'orchestration/multi-skill-workflow'
      : domains.length === 1
        ? `domain/${domains[0]}-operations`
        : 'direct_execution'
  };
}

/**
 * Simulate RL skill selection
 */
function simulateRLSelection(candidates, skillIndex) {
  if (!skillIndex || candidates.length === 0) {
    return null;
  }

  if (candidates.length === 1) {
    return candidates[0];
  }

  // Get weights
  const weights = candidates.map(skillPath => {
    const skill = skillIndex.skills.find(s =>
      `${s.category}/${s.name}` === skillPath || s.name === skillPath.split('/').pop()
    );
    return skill?.rl_metrics?.selection_weight || 0.5;
  });

  // Simple max selection (deterministic for testing)
  const maxWeight = Math.max(...weights);
  const maxIndex = weights.indexOf(maxWeight);

  return candidates[maxIndex];
}

/**
 * Simulate agent lookup from skill
 */
function simulateAgentLookup(skillPath, skillIndex, agentIndex) {
  if (!skillIndex || !agentIndex) {
    return null;
  }

  const skill = skillIndex.skills.find(s =>
    `${s.category}/${s.name}` === skillPath || s.name === skillPath.split('/').pop()
  );

  if (!skill || !skill.agents || skill.agents.length === 0) {
    return null;
  }

  const agentName = skill.agents[0];
  const agent = agentIndex.domain_agents.find(a => a.name === agentName);

  return agent;
}

// Test Suite
describe('Skills-First Architecture Integration Tests', () => {

  describe('T039: Skills-First Flow Integration', () => {

    let skillIndex;
    let agentIndex;
    let performance;
    let config;

    beforeAll(() => {
      skillIndex = loadJson(SKILL_INDEX_PATH);
      agentIndex = loadJson(AGENT_INDEX_PATH);
      performance = loadJson(PERFORMANCE_PATH);
      config = loadConfig(ARCHITECTURE_CONF_PATH);
    });

    test('T039-INT1: Architecture files exist and are valid', () => {
      expect(skillIndex).not.toBeNull();
      expect(agentIndex).not.toBeNull();
      expect(performance).not.toBeNull();

      // Validate versions
      expect(skillIndex.version).toBe('3.0.0');
      expect(agentIndex.version).toBe('1.0.0');
    });

    test('T039-INT2: skill-index.json contains expected skills', () => {
      expect(skillIndex.skills.length).toBeGreaterThanOrEqual(20);

      // Check for key skills
      const skillNames = skillIndex.skills.map(s => s.name);
      expect(skillNames).toContain('sdd-specification');
      expect(skillNames).toContain('sdd-planning');
      expect(skillNames).toContain('sdd-tasks');
      expect(skillNames).toContain('message-preflight');
      expect(skillNames).toContain('database-operations');
    });

    test('T039-INT3: agent-index.json contains 8 domain + 5 DS-STAR agents', () => {
      expect(agentIndex.domain_agents).toHaveLength(8);
      expect(agentIndex.ds_star_agents).toHaveLength(5);
      expect(agentIndex.statistics.total_agents).toBe(13);
    });

    test('T039-INT4: FR-707 compliance check simulates correctly', () => {
      // Single domain
      const singleDomain = simulateComplianceCheck('Create a database schema');
      expect(singleDomain.compliance_status).toBe('PASS');
      expect(singleDomain.domains_detected).toContain('database');

      // Multi-domain
      const multiDomain = simulateComplianceCheck('Build UI with API and database');
      expect(multiDomain.domains_detected.length).toBeGreaterThanOrEqual(2);
      expect(multiDomain.delegation_target).toBe('orchestration/multi-skill-workflow');

      // No domain
      const noDomain = simulateComplianceCheck('What time is it?');
      expect(noDomain.domains_detected).toHaveLength(0);
      expect(noDomain.delegation_target).toBe('direct_execution');
    });

    test('T039-INT5: RL selection works with skill weights', () => {
      const candidates = ['domain/database-operations', 'sdd-workflow/sdd-planning'];

      const selected = simulateRLSelection(candidates, skillIndex);

      expect(selected).not.toBeNull();
      expect(candidates).toContain(selected);
    });

    test('T039-INT6: Agent lookup from skill works', () => {
      const agent = simulateAgentLookup('domain/database-operations', skillIndex, agentIndex);

      expect(agent).not.toBeNull();
      expect(agent.name).toBe('database-specialist');
      expect(agent['skill-portfolio']).toContain('domain/database-operations');
    });
  });

  describe('T040: DS-STAR Integration Tests', () => {

    let agentIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('T040-INT1: DS-STAR agents have correct roles', () => {
      const dsStarAgents = agentIndex.ds_star_agents;

      const roles = dsStarAgents.map(a => a['ds-star-role']);
      expect(roles).toContain('router');
      expect(roles).toContain('verifier');
      expect(roles).toContain('debug');
      expect(roles).toContain('finalizer');
      expect(roles).toContain('context');
    });

    test('T040-INT2: DS-STAR agents have performance targets', () => {
      const dsStarAgents = agentIndex.ds_star_agents;

      dsStarAgents.forEach(agent => {
        expect(agent['performance-targets']).toBeDefined();
        expect(Object.keys(agent['performance-targets']).length).toBeGreaterThan(0);
      });
    });

    test('T040-INT3: Router agent has 3.5x accuracy target', () => {
      const router = agentIndex.ds_star_agents.find(a => a.name === 'router-agent');

      expect(router).toBeDefined();
      expect(router['performance-targets'].task_completion_accuracy).toBe(3.5);
    });

    test('T040-INT4: Verifier agent has 95% accuracy target', () => {
      const verifier = agentIndex.ds_star_agents.find(a => a.name === 'verifier-agent');

      expect(verifier).toBeDefined();
      expect(verifier['performance-targets'].decision_accuracy).toBe(0.95);
    });

    test('T040-INT5: Auto-debug agent has 70% fix rate target', () => {
      const autoDebug = agentIndex.ds_star_agents.find(a => a.name === 'auto-debug-agent');

      expect(autoDebug).toBeDefined();
      expect(autoDebug['performance-targets'].auto_fix_rate).toBe(0.70);
    });

    test('T040-INT6: Finalizer agent has 0% false pass target', () => {
      const finalizer = agentIndex.ds_star_agents.find(a => a.name === 'finalizer-agent');

      expect(finalizer).toBeDefined();
      expect(finalizer['performance-targets'].false_pass_rate).toBe(0.0);
    });

    test('T040-INT7: Context analyzer has <2s latency target', () => {
      const context = agentIndex.ds_star_agents.find(a => a.name === 'context-analyzer');

      expect(context).toBeDefined();
      expect(context['performance-targets'].retrieval_latency_ms).toBeLessThanOrEqual(2000);
    });
  });

  describe('Agent Consolidation Verification', () => {

    let agentIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('Consolidation map covers all original agents', () => {
      const consolidationMap = agentIndex.consolidation_map;

      // All original agents covered
      const coveredOriginals = Object.values(consolidationMap).flat();

      expect(coveredOriginals).toContain('frontend-specialist');
      expect(coveredOriginals).toContain('full-stack-developer');
      expect(coveredOriginals).toContain('devops-engineer');
      expect(coveredOriginals).toContain('performance-engineer');
      expect(coveredOriginals).toContain('specification-agent');
      expect(coveredOriginals).toContain('planning-agent');
      expect(coveredOriginals).toContain('tasks-agent');
      expect(coveredOriginals).toContain('testing-specialist');
      expect(coveredOriginals).toContain('security-specialist');
      expect(coveredOriginals).toContain('subagent-architect');
      expect(coveredOriginals).toContain('task-orchestrator');
    });

    test('Consolidated agents have skill portfolios', () => {
      const domainAgents = agentIndex.domain_agents;

      domainAgents.forEach(agent => {
        expect(agent['skill-portfolio']).toBeDefined();
        expect(agent['skill-portfolio'].length).toBeGreaterThan(0);
      });
    });

    test('Consolidation ratio is approximately 47%', () => {
      const ratio = agentIndex.statistics.consolidation_ratio;

      // 8/15 = 0.53 (53% of original, 47% reduction)
      expect(ratio).toBeGreaterThanOrEqual(0.5);
      expect(ratio).toBeLessThanOrEqual(0.6);
    });
  });

  describe('Skills-First Mode Configuration (Phase 4)', () => {

    let config;
    let skillIndex;

    beforeAll(() => {
      config = loadConfig(ARCHITECTURE_CONF_PATH);
      skillIndex = loadJson(SKILL_INDEX_PATH);
    });

    test('Architecture mode is skills-first for Phase 4', () => {
      expect(config.ARCHITECTURE_MODE).toBe('skills-first');
      expect(skillIndex['architecture-mode']).toBe('skills-first');
    });

    test('RL algorithm is EMA', () => {
      expect(config.RL_ALGORITHM).toBe('ema');
      expect(skillIndex.rl_config.algorithm).toBe('ema');
    });

    test('domain-routes provide skill-to-agent mappings', () => {
      const domainRoutes = skillIndex.routing['domain-routes'];

      expect(domainRoutes.database).toBeDefined();
      expect(domainRoutes.database['primary-skill']).toBe('domain/database-operations');
      expect(domainRoutes.database['primary-agent']).toBe('database-specialist');
    });

    test('Legacy pattern blocking is enabled in Phase 4', () => {
      expect(config.DEPRECATION_LEVEL).toBe('block');
      expect(config.DEPRECATION_GRACE_PERIOD_DAYS).toBe('0');
    });

    test('Current phase is 4', () => {
      expect(config.CURRENT_PHASE).toBe('4');
    });
  });
});

// Export for use in other tests
module.exports = {
  simulateComplianceCheck,
  simulateRLSelection,
  simulateAgentLookup,
  loadJson,
  loadConfig
};
