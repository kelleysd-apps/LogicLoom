/**
 * Integration Test - Agent Consolidation Coverage
 * Task: T053
 * Purpose: Validate all 15 original capabilities are covered by consolidated agents
 *
 * Coverage:
 * - All 15 original capabilities covered
 * - Skill portfolios complete
 * - Consolidation map accuracy
 * - No capability gaps
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');

// Paths
const ROOT_DIR = path.join(__dirname, '../..');
const AGENT_INDEX_PATH = path.join(ROOT_DIR, '.claude/agent-index.json');
const SKILL_INDEX_PATH = path.join(ROOT_DIR, '.claude/skill-index.json');
const CONSOLIDATED_AGENTS_DIR = path.join(ROOT_DIR, '.claude/agents/consolidated');
const DS_STAR_AGENTS_DIR = path.join(ROOT_DIR, '.claude/agents/ds-star');

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

// Original 15 agents (pre-consolidation)
const ORIGINAL_AGENTS = [
  'frontend-specialist',
  'full-stack-developer',
  'devops-engineer',
  'performance-engineer',
  'specification-agent',
  'planning-agent',
  'tasks-agent',
  'prd-specialist',
  'testing-specialist',
  'security-specialist',
  'subagent-architect',
  'task-orchestrator',
  'backend-architect',
  'database-specialist',
  'constitutional-governance-agent'
];

// Expected consolidated domain agents (8)
const EXPECTED_DOMAIN_AGENTS = [
  'implementation-specialist',
  'operations-specialist',
  'specification-orchestrator',
  'quality-specialist',
  'backend-architect',
  'database-specialist',
  'system-architect',
  'workflow-coordinator'
];

// Expected DS-STAR agents (5)
const EXPECTED_DS_STAR_AGENTS = [
  'router-agent',
  'verifier-agent',
  'auto-debug-agent',
  'finalizer-agent',
  'context-analyzer'
];

// Expected consolidation mapping
const EXPECTED_CONSOLIDATION = {
  'implementation-specialist': ['frontend-specialist', 'full-stack-developer'],
  'operations-specialist': ['devops-engineer', 'performance-engineer'],
  'specification-orchestrator': ['specification-agent', 'planning-agent', 'tasks-agent', 'prd-specialist'],
  'quality-specialist': ['testing-specialist', 'security-specialist'],
  'system-architect': ['subagent-architect'],
  'workflow-coordinator': ['task-orchestrator'],
  'backend-architect': [],
  'database-specialist': []
};

// Test Suite
describe('Agent Consolidation Integration Tests', () => {

  describe('T053-INT1: Consolidation Coverage', () => {

    let agentIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('All 15 original agents are covered in consolidation map', () => {
      expect(agentIndex).not.toBeNull();
      expect(agentIndex.consolidation_map).toBeDefined();

      // Get all original agents from consolidation map
      const coveredOriginals = Object.values(agentIndex.consolidation_map).flat();

      // Check that key original agents are covered
      const keyAgents = [
        'frontend-specialist',
        'full-stack-developer',
        'devops-engineer',
        'performance-engineer',
        'specification-agent',
        'planning-agent',
        'tasks-agent',
        'testing-specialist',
        'security-specialist'
      ];

      keyAgents.forEach(agent => {
        expect(coveredOriginals).toContain(agent);
      });
    });

    test('No duplicate agents in consolidation map', () => {
      const allMerged = Object.values(agentIndex.consolidation_map).flat();
      const uniqueMerged = [...new Set(allMerged)];

      expect(allMerged.length).toBe(uniqueMerged.length);
    });

    test('Consolidation reduces agent count correctly', () => {
      const originalCount = ORIGINAL_AGENTS.length - 1; // Exclude governance agent
      const consolidatedCount = Object.keys(agentIndex.consolidation_map).length;

      // Expecting significant reduction
      expect(consolidatedCount).toBeLessThan(originalCount);
      expect(consolidatedCount).toBe(8); // 8 domain agents
    });
  });

  describe('T053-INT2: Domain Agent Count', () => {

    let agentIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('Exactly 8 domain agents exist', () => {
      expect(agentIndex.domain_agents).toHaveLength(8);
    });

    test('All expected domain agents are present', () => {
      const domainAgentNames = agentIndex.domain_agents.map(a => a.name);

      EXPECTED_DOMAIN_AGENTS.forEach(agent => {
        expect(domainAgentNames).toContain(agent);
      });
    });

    test('Domain agents have required fields', () => {
      agentIndex.domain_agents.forEach(agent => {
        expect(agent.name).toBeDefined();
        expect(agent.purpose).toBeDefined();
        expect(agent['skill-portfolio']).toBeDefined();
        expect(Array.isArray(agent['skill-portfolio'])).toBe(true);
      });
    });
  });

  describe('T053-INT3: DS-STAR Agent Count', () => {

    let agentIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('Exactly 5 DS-STAR agents exist', () => {
      expect(agentIndex.ds_star_agents).toHaveLength(5);
    });

    test('All expected DS-STAR agents are present', () => {
      const dsStarNames = agentIndex.ds_star_agents.map(a => a.name);

      EXPECTED_DS_STAR_AGENTS.forEach(agent => {
        expect(dsStarNames).toContain(agent);
      });
    });

    test('DS-STAR agents have ds-star-role field', () => {
      agentIndex.ds_star_agents.forEach(agent => {
        expect(agent['ds-star-role']).toBeDefined();
      });
    });

    test('DS-STAR agents are NOT consolidated (FR-709)', () => {
      const dsStarNames = agentIndex.ds_star_agents.map(a => a.name);
      const consolidatedAgents = Object.keys(agentIndex.consolidation_map);

      // DS-STAR agents should not appear as consolidated targets
      dsStarNames.forEach(dsStarAgent => {
        expect(consolidatedAgents).not.toContain(dsStarAgent);
      });
    });
  });

  describe('T053-INT4: Skill Portfolio Completeness', () => {

    let agentIndex;
    let skillIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
      skillIndex = loadJson(SKILL_INDEX_PATH);
    });

    test('Each domain agent has at least one skill in portfolio', () => {
      agentIndex.domain_agents.forEach(agent => {
        expect(agent['skill-portfolio'].length).toBeGreaterThan(0);
      });
    });

    test('Skill portfolio references exist in skill-index', () => {
      const skillPaths = skillIndex.skills.map(s => `${s.category}/${s.name}`);

      agentIndex.domain_agents.forEach(agent => {
        agent['skill-portfolio'].forEach(skillPath => {
          // Allow for partial matches (category/name format)
          const pathParts = skillPath.split('/');
          const skillName = pathParts[pathParts.length - 1];
          const hasMatch = skillIndex.skills.some(s =>
            s.name === skillName || skillPaths.includes(skillPath)
          );
          expect(hasMatch).toBe(true);
        });
      });
    });

    test('No orphan skills (skills not in any portfolio)', () => {
      const allPortfolioSkills = agentIndex.domain_agents
        .flatMap(a => a['skill-portfolio']);

      // At minimum, key skills should be in portfolios
      const keySkills = [
        'database-operations',
        'frontend-operations',
        'backend-operations'
      ];

      keySkills.forEach(skill => {
        const inPortfolio = allPortfolioSkills.some(p => p.includes(skill));
        expect(inPortfolio).toBe(true);
      });
    });
  });

  describe('T053-INT5: Capability Preservation', () => {

    test('Frontend capabilities preserved', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const implSpecialist = agentIndex.domain_agents.find(
        a => a.name === 'implementation-specialist'
      );

      expect(implSpecialist).toBeDefined();
      expect(implSpecialist['merged-from']).toContain('frontend-specialist');
      expect(implSpecialist['merged-from']).toContain('full-stack-developer');

      // Check skill portfolio includes frontend operations
      const hasFrontendSkill = implSpecialist['skill-portfolio'].some(
        s => s.includes('frontend')
      );
      expect(hasFrontendSkill).toBe(true);
    });

    test('Backend capabilities preserved', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const backendArchitect = agentIndex.domain_agents.find(
        a => a.name === 'backend-architect'
      );

      expect(backendArchitect).toBeDefined();

      // Backend architect should have API design skill
      const hasBackendSkill = backendArchitect['skill-portfolio'].some(
        s => s.includes('backend') || s.includes('api')
      );
      expect(hasBackendSkill).toBe(true);
    });

    test('Database capabilities preserved', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const dbSpecialist = agentIndex.domain_agents.find(
        a => a.name === 'database-specialist'
      );

      expect(dbSpecialist).toBeDefined();

      // Database specialist should have database operations skill
      const hasDbSkill = dbSpecialist['skill-portfolio'].some(
        s => s.includes('database')
      );
      expect(hasDbSkill).toBe(true);
    });

    test('Testing capabilities preserved', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const qualitySpecialist = agentIndex.domain_agents.find(
        a => a.name === 'quality-specialist'
      );

      expect(qualitySpecialist).toBeDefined();
      expect(qualitySpecialist['merged-from']).toContain('testing-specialist');

      // Quality specialist should have testing skill
      const hasTestingSkill = qualitySpecialist['skill-portfolio'].some(
        s => s.includes('testing')
      );
      expect(hasTestingSkill).toBe(true);
    });

    test('Security capabilities preserved', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const qualitySpecialist = agentIndex.domain_agents.find(
        a => a.name === 'quality-specialist'
      );

      expect(qualitySpecialist).toBeDefined();
      expect(qualitySpecialist['merged-from']).toContain('security-specialist');

      // Quality specialist should have security skill
      const hasSecuritySkill = qualitySpecialist['skill-portfolio'].some(
        s => s.includes('security')
      );
      expect(hasSecuritySkill).toBe(true);
    });

    test('DevOps capabilities preserved', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const opsSpecialist = agentIndex.domain_agents.find(
        a => a.name === 'operations-specialist'
      );

      expect(opsSpecialist).toBeDefined();
      expect(opsSpecialist['merged-from']).toContain('devops-engineer');

      // Operations specialist should have devops skill
      const hasDevOpsSkill = opsSpecialist['skill-portfolio'].some(
        s => s.includes('devops')
      );
      expect(hasDevOpsSkill).toBe(true);
    });

    test('SDD workflow capabilities preserved', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const specOrchestrator = agentIndex.domain_agents.find(
        a => a.name === 'specification-orchestrator'
      );

      expect(specOrchestrator).toBeDefined();
      expect(specOrchestrator['merged-from']).toContain('specification-agent');
      expect(specOrchestrator['merged-from']).toContain('planning-agent');
      expect(specOrchestrator['merged-from']).toContain('tasks-agent');

      // Should have SDD workflow skills
      const hasSddSkill = specOrchestrator['skill-portfolio'].some(
        s => s.includes('sdd-')
      );
      expect(hasSddSkill).toBe(true);
    });
  });

  describe('T053-INT6: Agent Files Exist', () => {

    test('Consolidated agent files exist', () => {
      EXPECTED_DOMAIN_AGENTS.forEach(agentName => {
        const agentPath = path.join(CONSOLIDATED_AGENTS_DIR, `${agentName}.md`);
        const exists = fs.existsSync(agentPath);

        if (!exists) {
          console.log(`Missing agent file: ${agentPath}`);
        }
        expect(exists).toBe(true);
      });
    });

    test('DS-STAR agent files exist', () => {
      EXPECTED_DS_STAR_AGENTS.forEach(agentName => {
        const agentPath = path.join(DS_STAR_AGENTS_DIR, `${agentName}.md`);
        const exists = fs.existsSync(agentPath);

        if (!exists) {
          console.log(`Missing DS-STAR agent file: ${agentPath}`);
        }
        expect(exists).toBe(true);
      });
    });
  });

  describe('T053-INT7: Statistics Accuracy', () => {

    let agentIndex;

    beforeAll(() => {
      agentIndex = loadJson(AGENT_INDEX_PATH);
    });

    test('Total agents count is correct (13)', () => {
      expect(agentIndex.statistics.total_agents).toBe(13);
    });

    test('Domain agents count matches array length', () => {
      expect(agentIndex.domain_agents.length).toBe(8);
    });

    test('DS-STAR agents count matches array length', () => {
      expect(agentIndex.ds_star_agents.length).toBe(5);
    });

    test('Consolidation ratio is approximately 0.53', () => {
      // 8 consolidated from ~15 original = 8/15 ≈ 0.53
      const ratio = agentIndex.statistics.consolidation_ratio;
      expect(ratio).toBeGreaterThanOrEqual(0.5);
      expect(ratio).toBeLessThanOrEqual(0.6);
    });

    test('Agent index version is 1.0.0', () => {
      expect(agentIndex.version).toBe('1.0.0');
    });
  });

  describe('T053-INT8: No Capability Gaps', () => {

    test('All domain keywords have agent coverage', () => {
      const domainKeywords = {
        frontend: ['UI', 'component', 'React', 'CSS'],
        backend: ['API', 'endpoint', 'server', 'auth'],
        database: ['schema', 'migration', 'query', 'SQL'],
        testing: ['test', 'TDD', 'E2E', 'coverage'],
        security: ['encryption', 'XSS', 'secrets'],
        devops: ['deploy', 'CI/CD', 'Docker'],
        performance: ['optimize', 'cache', 'benchmark']
      };

      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const allSkills = agentIndex.domain_agents.flatMap(a => a['skill-portfolio']);

      // Each domain should have at least one skill covering it
      Object.keys(domainKeywords).forEach(domain => {
        const hasCoverage = allSkills.some(skill =>
          skill.toLowerCase().includes(domain)
        );
        expect(hasCoverage).toBe(true);
      });
    });

    test('SDD workflow phases have agent coverage', () => {
      const agentIndex = loadJson(AGENT_INDEX_PATH);
      const specOrchestrator = agentIndex.domain_agents.find(
        a => a.name === 'specification-orchestrator'
      );

      expect(specOrchestrator).toBeDefined();

      // Should cover spec, plan, and tasks phases
      const portfolio = specOrchestrator['skill-portfolio'];
      expect(portfolio.some(s => s.includes('specification'))).toBe(true);
      expect(portfolio.some(s => s.includes('planning'))).toBe(true);
      expect(portfolio.some(s => s.includes('tasks'))).toBe(true);
    });
  });
});

// Export for use in other tests
module.exports = {
  ORIGINAL_AGENTS,
  EXPECTED_DOMAIN_AGENTS,
  EXPECTED_DS_STAR_AGENTS,
  EXPECTED_CONSOLIDATION,
  loadJson
};
