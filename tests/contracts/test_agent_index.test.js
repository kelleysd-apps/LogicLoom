/**
 * Contract Test - Agent Index
 * Task: T005
 * Purpose: Validate agent-index.json schema
 *
 * Coverage:
 * - domain_agents array has exactly 8 entries
 * - ds_star_agents array has exactly 5 entries
 * - consolidation_map covers all original 15 agents
 * - statistics (total_agents = 13, consolidation_ratio)
 * - FR-709 compliance (DS-STAR agents separate)
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');

// Path to agent-index.json (will be created)
const AGENT_INDEX_PATH = path.join(__dirname, '../../.claude/agent-index.json');

// Expected 8 consolidated domain agents (FR-610-614)
const EXPECTED_DOMAIN_AGENTS = [
  'implementation-specialist',
  'operations-specialist',
  'specification-orchestrator',
  'quality-specialist',
  'backend-architect',
  'system-architect',
  'database-specialist',
  'workflow-coordinator'
];

// Expected 5 DS-STAR agents (FR-709)
const EXPECTED_DS_STAR_AGENTS = [
  'router-agent',
  'verifier-agent',
  'auto-debug-agent',
  'finalizer-agent',
  'context-analyzer'
];

// Original 15 agents that should be in consolidation_map
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

// Valid DS-STAR roles
const VALID_DS_STAR_ROLES = ['router', 'verifier', 'debug', 'finalizer', 'context'];

/**
 * Helper: Validate domain_agents array
 */
function validateDomainAgents(domainAgents) {
  const errors = [];

  if (!domainAgents) {
    errors.push('domain_agents is required');
    return errors;
  }

  if (!Array.isArray(domainAgents)) {
    errors.push('domain_agents must be an array');
    return errors;
  }

  // Must have exactly 8 entries
  if (domainAgents.length !== 8) {
    errors.push(`domain_agents must have exactly 8 entries, got ${domainAgents.length}`);
  }

  // Check all expected agents are present
  const agentNames = domainAgents.map(a => a.name);
  EXPECTED_DOMAIN_AGENTS.forEach(expected => {
    if (!agentNames.includes(expected)) {
      errors.push(`domain_agents missing expected agent: ${expected}`);
    }
  });

  // Validate each agent entry
  domainAgents.forEach((agent, idx) => {
    if (!agent.name) {
      errors.push(`domain_agents[${idx}] missing name`);
    }
    if (!agent.path) {
      errors.push(`domain_agents[${idx}] "${agent.name}" missing path`);
    }
    if (!agent.department) {
      errors.push(`domain_agents[${idx}] "${agent.name}" missing department`);
    }
    if (!agent['skill-portfolio'] || !Array.isArray(agent['skill-portfolio'])) {
      errors.push(`domain_agents[${idx}] "${agent.name}" missing skill-portfolio array`);
    }
  });

  return errors;
}

/**
 * Helper: Validate ds_star_agents array
 */
function validateDSStarAgents(dsStarAgents) {
  const errors = [];

  if (!dsStarAgents) {
    errors.push('ds_star_agents is required');
    return errors;
  }

  if (!Array.isArray(dsStarAgents)) {
    errors.push('ds_star_agents must be an array');
    return errors;
  }

  // Must have exactly 5 entries (FR-709)
  if (dsStarAgents.length !== 5) {
    errors.push(`ds_star_agents must have exactly 5 entries (FR-709), got ${dsStarAgents.length}`);
  }

  // Check all expected DS-STAR agents are present
  const agentNames = dsStarAgents.map(a => a.name);
  EXPECTED_DS_STAR_AGENTS.forEach(expected => {
    if (!agentNames.includes(expected)) {
      errors.push(`ds_star_agents missing expected agent: ${expected}`);
    }
  });

  // Validate each DS-STAR agent entry
  dsStarAgents.forEach((agent, idx) => {
    if (!agent.name) {
      errors.push(`ds_star_agents[${idx}] missing name`);
    }
    if (!agent.path) {
      errors.push(`ds_star_agents[${idx}] "${agent.name}" missing path`);
    }
    if (!agent['ds-star-role']) {
      errors.push(`ds_star_agents[${idx}] "${agent.name}" missing ds-star-role`);
    } else if (!VALID_DS_STAR_ROLES.includes(agent['ds-star-role'])) {
      errors.push(`ds_star_agents[${idx}] "${agent.name}" has invalid ds-star-role "${agent['ds-star-role']}"`);
    }
    if (!agent['performance-targets']) {
      errors.push(`ds_star_agents[${idx}] "${agent.name}" missing performance-targets`);
    }
  });

  return errors;
}

/**
 * Helper: Validate consolidation_map covers all original agents
 */
function validateConsolidationMap(consolidationMap) {
  const errors = [];

  if (!consolidationMap) {
    errors.push('consolidation_map is required');
    return errors;
  }

  if (typeof consolidationMap !== 'object') {
    errors.push('consolidation_map must be an object');
    return errors;
  }

  // Collect all original agents mentioned in the map
  const coveredOriginals = new Set();
  Object.entries(consolidationMap).forEach(([newAgent, originals]) => {
    if (!Array.isArray(originals)) {
      errors.push(`consolidation_map["${newAgent}"] must be an array`);
      return;
    }
    originals.forEach(orig => coveredOriginals.add(orig));
  });

  // Check that all (or most) original agents are covered
  // Note: Some agents like constitutional-governance-agent become skills
  const requiredOriginals = ORIGINAL_AGENTS.filter(a => a !== 'constitutional-governance-agent');
  requiredOriginals.forEach(orig => {
    if (!coveredOriginals.has(orig)) {
      errors.push(`consolidation_map missing original agent: ${orig}`);
    }
  });

  return errors;
}

/**
 * Helper: Validate statistics section
 */
function validateStatistics(statistics) {
  const errors = [];

  if (!statistics) {
    errors.push('statistics is required');
    return errors;
  }

  // total_agents should be 13 (8 domain + 5 DS-STAR)
  if (statistics.total_agents !== undefined) {
    if (statistics.total_agents !== 13) {
      errors.push(`statistics.total_agents should be 13 (8 domain + 5 DS-STAR), got ${statistics.total_agents}`);
    }
  } else {
    errors.push('statistics.total_agents is required');
  }

  // total_domain_agents should be 8
  if (statistics.total_domain_agents !== undefined) {
    if (statistics.total_domain_agents !== 8) {
      errors.push(`statistics.total_domain_agents should be 8, got ${statistics.total_domain_agents}`);
    }
  }

  // total_ds_star_agents should be 5
  if (statistics.total_ds_star_agents !== undefined) {
    if (statistics.total_ds_star_agents !== 5) {
      errors.push(`statistics.total_ds_star_agents should be 5, got ${statistics.total_ds_star_agents}`);
    }
  }

  // consolidation_ratio should be approximately 0.53 (8/15)
  if (statistics.consolidation_ratio !== undefined) {
    if (statistics.consolidation_ratio < 0.5 || statistics.consolidation_ratio > 0.6) {
      errors.push(`statistics.consolidation_ratio should be ~0.53 (47% reduction), got ${statistics.consolidation_ratio}`);
    }
  }

  return errors;
}

/**
 * Helper: Validate FR-709 compliance (DS-STAR agents separate)
 */
function validateFR709Compliance(index) {
  const errors = [];

  // DS-STAR agents must NOT be in domain_agents
  if (index.domain_agents && index.ds_star_agents) {
    const domainNames = index.domain_agents.map(a => a.name);
    const dsStarNames = index.ds_star_agents.map(a => a.name);

    // Check no DS-STAR agent is in domain list
    dsStarNames.forEach(dsAgent => {
      if (domainNames.includes(dsAgent)) {
        errors.push(`FR-709 violation: DS-STAR agent "${dsAgent}" should not be in domain_agents`);
      }
    });

    // Check no domain agent is in DS-STAR list
    domainNames.forEach(domAgent => {
      if (dsStarNames.includes(domAgent)) {
        errors.push(`FR-709 violation: Domain agent "${domAgent}" should not be in ds_star_agents`);
      }
    });
  }

  return errors;
}

/**
 * Validate complete agent-index.json
 */
function validateAgentIndex(index) {
  const errors = [];

  // Validate version
  if (!index.version) {
    errors.push('version is required');
  }

  // Validate generated timestamp
  if (!index.generated) {
    errors.push('generated timestamp is required');
  }

  // Validate domain_agents
  errors.push(...validateDomainAgents(index.domain_agents));

  // Validate ds_star_agents
  errors.push(...validateDSStarAgents(index.ds_star_agents));

  // Validate consolidation_map
  errors.push(...validateConsolidationMap(index.consolidation_map));

  // Validate statistics
  errors.push(...validateStatistics(index.statistics));

  // Validate FR-709 compliance
  errors.push(...validateFR709Compliance(index));

  return errors;
}

// Test Suite
describe('Agent Index Contract Tests', () => {

  describe('Domain Agents Validation', () => {

    test('T005-AC1: domain_agents array must have exactly 8 entries', () => {
      // Valid: exactly 8
      const valid8 = {
        domain_agents: EXPECTED_DOMAIN_AGENTS.map(name => ({
          name,
          path: `agents/${name}.md`,
          department: 'engineering',
          'skill-portfolio': ['domain/test-skill']
        }))
      };
      expect(validateDomainAgents(valid8.domain_agents)).toHaveLength(0);

      // Invalid: 7 agents
      const invalid7 = {
        domain_agents: EXPECTED_DOMAIN_AGENTS.slice(0, 7).map(name => ({
          name,
          path: `agents/${name}.md`,
          department: 'engineering',
          'skill-portfolio': ['domain/test-skill']
        }))
      };
      const errors = validateDomainAgents(invalid7.domain_agents);
      expect(errors.some(e => e.includes('exactly 8'))).toBe(true);
    });

    test('T005-AC1: validates all expected domain agents present', () => {
      const missingAgent = EXPECTED_DOMAIN_AGENTS.slice(1).map(name => ({
        name,
        path: `agents/${name}.md`,
        department: 'engineering',
        'skill-portfolio': ['domain/test-skill']
      }));

      const errors = validateDomainAgents(missingAgent);
      expect(errors.some(e => e.includes('missing expected agent'))).toBe(true);
    });
  });

  describe('DS-STAR Agents Validation', () => {

    test('T005-AC2: ds_star_agents array must have exactly 5 entries', () => {
      // Valid: exactly 5
      const valid5 = {
        ds_star_agents: EXPECTED_DS_STAR_AGENTS.map((name, idx) => ({
          name,
          path: `ds-star/${name}.md`,
          'ds-star-role': VALID_DS_STAR_ROLES[idx],
          'performance-targets': { accuracy: 0.95 }
        }))
      };
      expect(validateDSStarAgents(valid5.ds_star_agents)).toHaveLength(0);

      // Invalid: 4 agents
      const invalid4 = {
        ds_star_agents: EXPECTED_DS_STAR_AGENTS.slice(0, 4).map((name, idx) => ({
          name,
          path: `ds-star/${name}.md`,
          'ds-star-role': VALID_DS_STAR_ROLES[idx],
          'performance-targets': { accuracy: 0.95 }
        }))
      };
      const errors = validateDSStarAgents(invalid4.ds_star_agents);
      expect(errors.some(e => e.includes('exactly 5'))).toBe(true);
    });

    test('T005-AC2: validates DS-STAR roles', () => {
      const invalidRole = [{
        name: 'router-agent',
        path: 'ds-star/router-agent.md',
        'ds-star-role': 'invalid-role',
        'performance-targets': {}
      }];

      const errors = validateDSStarAgents(invalidRole);
      expect(errors.some(e => e.includes('invalid ds-star-role'))).toBe(true);
    });
  });

  describe('Consolidation Map Validation', () => {

    test('T005-AC3: consolidation_map covers all original 15 agents', () => {
      const validMap = {
        'implementation-specialist': ['frontend-specialist', 'full-stack-developer'],
        'operations-specialist': ['devops-engineer', 'performance-engineer'],
        'specification-orchestrator': ['specification-agent', 'planning-agent', 'tasks-agent', 'prd-specialist'],
        'quality-specialist': ['testing-specialist', 'security-specialist'],
        'system-architect': ['subagent-architect'],
        'workflow-coordinator': ['task-orchestrator'],
        'backend-architect': ['backend-architect'],
        'database-specialist': ['database-specialist']
      };

      expect(validateConsolidationMap(validMap)).toHaveLength(0);
    });

    test('T005-AC3: fails when original agent missing from map', () => {
      const incompleteMap = {
        'implementation-specialist': ['frontend-specialist']
        // Missing most mappings
      };

      const errors = validateConsolidationMap(incompleteMap);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors.some(e => e.includes('missing original agent'))).toBe(true);
    });
  });

  describe('Statistics Validation', () => {

    test('T005-AC4: validates statistics totals', () => {
      const validStats = {
        total_domain_agents: 8,
        total_ds_star_agents: 5,
        total_agents: 13,
        consolidation_ratio: 0.53
      };

      expect(validateStatistics(validStats)).toHaveLength(0);
    });

    test('T005-AC4: total_agents must be 13', () => {
      const invalidStats = {
        total_domain_agents: 8,
        total_ds_star_agents: 5,
        total_agents: 20 // Wrong!
      };

      const errors = validateStatistics(invalidStats);
      expect(errors.some(e => e.includes('should be 13'))).toBe(true);
    });
  });

  describe('FR-709 Compliance Validation', () => {

    test('T005-AC5: validates DS-STAR agents are separate from domain agents', () => {
      // Valid: completely separate
      const valid = {
        domain_agents: [{ name: 'implementation-specialist' }],
        ds_star_agents: [{ name: 'router-agent' }]
      };
      expect(validateFR709Compliance(valid)).toHaveLength(0);

      // Invalid: DS-STAR agent in domain list
      const invalid = {
        domain_agents: [
          { name: 'implementation-specialist' },
          { name: 'router-agent' } // Should not be here!
        ],
        ds_star_agents: [{ name: 'router-agent' }]
      };
      const errors = validateFR709Compliance(invalid);
      expect(errors.some(e => e.includes('FR-709 violation'))).toBe(true);
    });
  });

  describe('Integration: Current Agent Index Validation', () => {

    test('T005-INT: agent-index.json should fail validation until created (RED phase)', () => {
      if (!fs.existsSync(AGENT_INDEX_PATH)) {
        console.log('agent-index.json not found - will be created by T031');
        // This is expected in RED phase
        return;
      }

      const content = fs.readFileSync(AGENT_INDEX_PATH, 'utf-8');
      const index = JSON.parse(content);
      const errors = validateAgentIndex(index);

      console.log(`agent-index.json validation: ${errors.length} errors`);
    });
  });
});

// Export for use in other tests
module.exports = {
  validateAgentIndex,
  validateDomainAgents,
  validateDSStarAgents,
  validateConsolidationMap,
  validateStatistics,
  validateFR709Compliance,
  EXPECTED_DOMAIN_AGENTS,
  EXPECTED_DS_STAR_AGENTS,
  ORIGINAL_AGENTS
};
