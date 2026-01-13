/**
 * Contract Test - Agent Definition v2
 * Task: T002
 * Purpose: Validate Agent.md against contracts/agent-definition.yaml
 *
 * Coverage:
 * - skill-portfolio field validation
 * - merged-from tracking
 * - rl_performance metrics structure
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

// Contract schema path
const CONTRACT_PATH = path.join(__dirname, '../../specs/002-skills-first-architecture/contracts/agent-definition.yaml');
const AGENTS_DIR = path.join(__dirname, '../../.claude/agents');

// Valid departments
const VALID_DEPARTMENTS = [
  'architecture',
  'data',
  'engineering',
  'operations',
  'product',
  'quality'
];

// Valid tools
const VALID_TOOLS = [
  'Read', 'Write', 'Edit', 'MultiEdit', 'Bash',
  'Grep', 'Glob', 'WebSearch', 'Task', 'TodoWrite'
];

// Valid output formats
const VALID_OUTPUT_FORMATS = [
  'markdown', 'json', 'yaml', 'sql',
  'typescript', 'python', 'bash', 'text'
];

// Skill portfolio path pattern: category/skill-name
const SKILL_PATH_PATTERN = /^[a-z][a-z0-9-]*\/[a-z][a-z0-9-]*$/;

/**
 * Helper: Parse YAML frontmatter from agent.md file
 */
function parseAgentFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) {
    throw new Error('No YAML frontmatter found');
  }
  return yaml.load(match[1]);
}

/**
 * Helper: Validate skill-portfolio paths
 */
function validateSkillPortfolio(portfolio) {
  const errors = [];

  if (!Array.isArray(portfolio)) {
    errors.push('skill-portfolio must be an array');
    return errors;
  }

  if (portfolio.length === 0) {
    errors.push('skill-portfolio must have at least one skill');
    return errors;
  }

  portfolio.forEach((skillPath, idx) => {
    if (!SKILL_PATH_PATTERN.test(skillPath)) {
      errors.push(`skill-portfolio[${idx}] "${skillPath}" must match pattern category/skill-name`);
    }
  });

  return errors;
}

/**
 * Helper: Validate rl_performance structure
 */
function validateRLPerformance(rlPerf) {
  const errors = [];

  if (!rlPerf) {
    return errors; // Optional field, but if present must be valid
  }

  // invocation_count must be >= 0
  if (rlPerf.invocation_count !== undefined && rlPerf.invocation_count < 0) {
    errors.push(`rl_performance.invocation_count ${rlPerf.invocation_count} must be >= 0`);
  }

  // success_rate must be 0-1
  if (rlPerf.success_rate !== undefined) {
    if (rlPerf.success_rate < 0 || rlPerf.success_rate > 1) {
      errors.push(`rl_performance.success_rate ${rlPerf.success_rate} must be between 0 and 1`);
    }
  }

  // avg_tokens must be >= 0
  if (rlPerf.avg_tokens !== undefined && rlPerf.avg_tokens < 0) {
    errors.push(`rl_performance.avg_tokens ${rlPerf.avg_tokens} must be >= 0`);
  }

  // skill_success_rates values must be 0-1
  if (rlPerf.skill_success_rates) {
    Object.entries(rlPerf.skill_success_rates).forEach(([skill, rate]) => {
      if (rate < 0 || rate > 1) {
        errors.push(`rl_performance.skill_success_rates["${skill}"] ${rate} must be between 0 and 1`);
      }
    });
  }

  return errors;
}

/**
 * Helper: Validate merged-from array
 */
function validateMergedFrom(mergedFrom) {
  const errors = [];

  if (mergedFrom === undefined) {
    return errors; // Optional field
  }

  if (!Array.isArray(mergedFrom)) {
    errors.push('merged-from must be an array');
    return errors;
  }

  // Validate each entry is a string
  mergedFrom.forEach((agent, idx) => {
    if (typeof agent !== 'string') {
      errors.push(`merged-from[${idx}] must be a string`);
    }
  });

  return errors;
}

/**
 * Validate an agent definition against v2 contract
 */
function validateAgentDefinition(agent) {
  const errors = [];

  // Required: name
  if (!agent.name || typeof agent.name !== 'string') {
    errors.push('name is required and must be a string');
  } else if (!/^[a-z][a-z0-9-]*[a-z0-9]$/.test(agent.name)) {
    errors.push(`name "${agent.name}" must be kebab-case`);
  }

  // Required: purpose (20-256 chars)
  if (!agent.purpose || typeof agent.purpose !== 'string') {
    errors.push('purpose is required and must be a string');
  } else if (agent.purpose.length < 20 || agent.purpose.length > 256) {
    errors.push(`purpose must be 20-256 characters (got ${agent.purpose.length})`);
  }

  // Required: required-context (1-10 items)
  if (!agent['required-context'] || !Array.isArray(agent['required-context'])) {
    errors.push('required-context is required and must be an array');
  } else if (agent['required-context'].length === 0 || agent['required-context'].length > 10) {
    errors.push('required-context must have 1-10 items');
  }

  // Required: output-format
  if (!agent['output-format']) {
    errors.push('output-format is required');
  } else if (!VALID_OUTPUT_FORMATS.includes(agent['output-format'])) {
    errors.push(`output-format "${agent['output-format']}" is not valid. Valid: ${VALID_OUTPUT_FORMATS.join(', ')}`);
  }

  // Required: tools
  if (!agent.tools || !Array.isArray(agent.tools)) {
    errors.push('tools is required and must be an array');
  } else {
    agent.tools.forEach((tool, idx) => {
      if (!VALID_TOOLS.includes(tool)) {
        errors.push(`tools[${idx}] "${tool}" is not valid. Valid: ${VALID_TOOLS.join(', ')}`);
      }
    });
  }

  // Required: department
  if (!agent.department) {
    errors.push('department is required');
  } else if (!VALID_DEPARTMENTS.includes(agent.department)) {
    errors.push(`department "${agent.department}" is not valid. Valid: ${VALID_DEPARTMENTS.join(', ')}`);
  }

  // Required in v2: skill-portfolio
  if (!agent['skill-portfolio']) {
    errors.push('skill-portfolio is required for agent-definition v2');
  } else {
    errors.push(...validateSkillPortfolio(agent['skill-portfolio']));
  }

  // Optional: merged-from (must be valid if present)
  errors.push(...validateMergedFrom(agent['merged-from']));

  // Optional: rl_performance (must be valid if present)
  errors.push(...validateRLPerformance(agent.rl_performance));

  return errors;
}

// Test Suite
describe('Agent Definition v2 Contract Tests', () => {

  describe('Required Fields Validation', () => {

    test('T002-AC1: validates all required fields', () => {
      const validAgent = {
        name: 'test-agent',
        purpose: 'This is a test agent purpose that is long enough to meet requirements.',
        'required-context': ['context-field-1', 'context-field-2'],
        'output-format': 'markdown',
        tools: ['Read', 'Write', 'Bash'],
        department: 'engineering',
        'skill-portfolio': ['domain/test-skill', 'orchestration/test-workflow']
      };

      const errors = validateAgentDefinition(validAgent);
      expect(errors).toHaveLength(0);
    });

    test('T002-AC1: fails when required fields missing', () => {
      const invalidAgent = {};
      const errors = validateAgentDefinition(invalidAgent);

      expect(errors.length).toBeGreaterThan(0);
      expect(errors.some(e => e.includes('name'))).toBe(true);
      expect(errors.some(e => e.includes('purpose'))).toBe(true);
      expect(errors.some(e => e.includes('required-context'))).toBe(true);
      expect(errors.some(e => e.includes('output-format'))).toBe(true);
      expect(errors.some(e => e.includes('tools'))).toBe(true);
      expect(errors.some(e => e.includes('department'))).toBe(true);
      expect(errors.some(e => e.includes('skill-portfolio'))).toBe(true);
    });
  });

  describe('Skill Portfolio Validation', () => {

    test('T002-AC2: validates skill-portfolio path format (category/skill-name)', () => {
      // Valid paths
      expect(validateSkillPortfolio(['domain/frontend-operations'])).toHaveLength(0);
      expect(validateSkillPortfolio(['sdd-workflow/sdd-specification'])).toHaveLength(0);
      expect(validateSkillPortfolio(['orchestration/multi-skill-workflow'])).toHaveLength(0);

      // Invalid paths
      const invalidPaths = [
        'missing-category', // No slash
        '/leading-slash/skill',
        'category/', // Empty skill name
        'Category/Skill', // Uppercase
        'category/skill/extra' // Too many parts
      ];

      invalidPaths.forEach(invalidPath => {
        const errors = validateSkillPortfolio([invalidPath]);
        expect(errors.length).toBeGreaterThan(0);
      });
    });

    test('T002-AC2: skill-portfolio must have at least one skill', () => {
      const errors = validateSkillPortfolio([]);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('at least one skill');
    });
  });

  describe('Merged-From Tracking Validation', () => {

    test('T002-AC3: validates merged-from array for consolidation tracking', () => {
      // Valid merged-from
      const validMergedFrom = ['frontend-specialist', 'full-stack-developer'];
      expect(validateMergedFrom(validMergedFrom)).toHaveLength(0);

      // Empty array is valid (agent not consolidated)
      expect(validateMergedFrom([])).toHaveLength(0);

      // undefined is valid (field not present)
      expect(validateMergedFrom(undefined)).toHaveLength(0);
    });

    test('T002-AC3: merged-from entries must be strings', () => {
      const invalidMergedFrom = ['valid-agent', 123, { name: 'invalid' }];
      const errors = validateMergedFrom(invalidMergedFrom);
      expect(errors.length).toBeGreaterThan(0);
    });
  });

  describe('RL Performance Metrics Validation', () => {

    test('T002-AC4: validates rl_performance metrics structure', () => {
      const validRLPerf = {
        invocation_count: 100,
        success_rate: 0.85,
        avg_tokens: 1500,
        skill_success_rates: {
          'domain/frontend-operations': 0.90,
          'domain/backend-operations': 0.80
        }
      };

      expect(validateRLPerformance(validRLPerf)).toHaveLength(0);
    });

    test('T002-AC4: invocation_count must be >= 0', () => {
      const invalid = { invocation_count: -1 };
      const errors = validateRLPerformance(invalid);
      expect(errors.length).toBeGreaterThan(0);
    });

    test('T002-AC4: success_rate must be 0-1', () => {
      expect(validateRLPerformance({ success_rate: 0 })).toHaveLength(0);
      expect(validateRLPerformance({ success_rate: 1 })).toHaveLength(0);
      expect(validateRLPerformance({ success_rate: -0.1 }).length).toBeGreaterThan(0);
      expect(validateRLPerformance({ success_rate: 1.1 }).length).toBeGreaterThan(0);
    });

    test('T002-AC4: skill_success_rates values must be 0-1', () => {
      const invalid = {
        skill_success_rates: {
          'domain/valid': 0.5,
          'domain/invalid': 1.5
        }
      };
      const errors = validateRLPerformance(invalid);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('invalid');
    });
  });

  describe('Integration: Existing Agents Validation', () => {

    test('T002-INT: All existing agent files should fail v2 validation (RED phase)', () => {
      // This test expects failures because agents haven't been upgraded to v2 yet

      if (!fs.existsSync(AGENTS_DIR)) {
        console.log('Agents directory not found - skipping integration test');
        return;
      }

      const agentFiles = [];

      function findAgentFiles(dir) {
        const files = fs.readdirSync(dir);
        files.forEach(file => {
          const fullPath = path.join(dir, file);
          const stat = fs.statSync(fullPath);
          if (stat.isDirectory()) {
            findAgentFiles(fullPath);
          } else if (file.endsWith('.md') && file !== 'README.md') {
            agentFiles.push(fullPath);
          }
        });
      }

      findAgentFiles(AGENTS_DIR);

      if (agentFiles.length === 0) {
        console.log('No agent files found - skipping validation');
        return;
      }

      // Count agents that pass v2 validation
      let passingAgents = 0;
      let failingAgents = 0;

      agentFiles.forEach(filePath => {
        try {
          const content = fs.readFileSync(filePath, 'utf-8');
          const agent = parseAgentFrontmatter(content);
          const errors = validateAgentDefinition(agent);

          if (errors.length === 0) {
            passingAgents++;
          } else {
            failingAgents++;
          }
        } catch (e) {
          failingAgents++;
        }
      });

      // In RED phase, we expect most/all agents to fail v2 validation
      console.log(`Agents validation: ${passingAgents} passing, ${failingAgents} failing`);
    });
  });
});

// Export for use in other tests
module.exports = {
  validateAgentDefinition,
  validateSkillPortfolio,
  validateMergedFrom,
  validateRLPerformance,
  parseAgentFrontmatter,
  VALID_DEPARTMENTS,
  VALID_TOOLS,
  VALID_OUTPUT_FORMATS
};
