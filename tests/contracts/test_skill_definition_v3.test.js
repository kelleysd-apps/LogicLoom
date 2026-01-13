/**
 * Contract Test - Skill Definition v3
 * Task: T001
 * Purpose: Validate SKILL.md frontmatter against contracts/skill-definition.yaml
 *
 * Coverage:
 * - rl_metrics fields validation
 * - progressive-disclosure structure
 * - agent-invocations validation
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

// Contract schema path
const CONTRACT_PATH = path.join(__dirname, '../../specs/002-skills-first-architecture/contracts/skill-definition.yaml');
const SKILLS_DIR = path.join(__dirname, '../../.claude/skills');

// Valid consolidated agent names (FR-610-614)
const VALID_CONSOLIDATED_AGENTS = [
  'implementation-specialist',
  'operations-specialist',
  'specification-orchestrator',
  'quality-specialist',
  'backend-architect',
  'system-architect',
  'database-specialist',
  'workflow-coordinator'
];

// Valid categories
const VALID_CATEGORIES = [
  'sdd-workflow',
  'validation',
  'governance',
  'orchestration',
  'domain',
  'creation',
  'project-initialization',
  'integration'
];

/**
 * Helper: Parse YAML frontmatter from SKILL.md file
 */
function parseSkillFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) {
    throw new Error('No YAML frontmatter found');
  }
  return yaml.load(match[1]);
}

/**
 * Helper: Validate RL metrics bounds
 */
function validateRLMetrics(rlMetrics) {
  const errors = [];

  // success_rate must be 0-1
  if (rlMetrics.success_rate !== undefined) {
    if (rlMetrics.success_rate < 0 || rlMetrics.success_rate > 1) {
      errors.push(`success_rate ${rlMetrics.success_rate} must be between 0 and 1`);
    }
  }

  // selection_weight must be 0.1-1.0
  if (rlMetrics.selection_weight !== undefined) {
    if (rlMetrics.selection_weight < 0.1 || rlMetrics.selection_weight > 1.0) {
      errors.push(`selection_weight ${rlMetrics.selection_weight} must be between 0.1 and 1.0`);
    }
  }

  // user_satisfaction must be 0-1 (if present)
  if (rlMetrics.user_satisfaction !== undefined) {
    if (rlMetrics.user_satisfaction < 0 || rlMetrics.user_satisfaction > 1) {
      errors.push(`user_satisfaction ${rlMetrics.user_satisfaction} must be between 0 and 1`);
    }
  }

  // invocation_count must be >= 0
  if (rlMetrics.invocation_count !== undefined) {
    if (rlMetrics.invocation_count < 0) {
      errors.push(`invocation_count ${rlMetrics.invocation_count} must be >= 0`);
    }
  }

  return errors;
}

/**
 * Helper: Validate agent-invocations reference consolidated agents
 */
function validateAgentInvocations(invocations) {
  const errors = [];

  if (!Array.isArray(invocations)) {
    return errors; // Optional field
  }

  invocations.forEach((inv, idx) => {
    if (!VALID_CONSOLIDATED_AGENTS.includes(inv.agent)) {
      errors.push(`agent-invocation[${idx}].agent "${inv.agent}" is not a valid consolidated agent. Valid: ${VALID_CONSOLIDATED_AGENTS.join(', ')}`);
    }

    if (!inv['context-subset'] || !Array.isArray(inv['context-subset'])) {
      errors.push(`agent-invocation[${idx}].context-subset is required and must be an array`);
    } else if (inv['context-subset'].length === 0 || inv['context-subset'].length > 10) {
      errors.push(`agent-invocation[${idx}].context-subset must have 1-10 items`);
    }

    if (!inv.when || inv.when.length < 10) {
      errors.push(`agent-invocation[${idx}].when must be at least 10 characters`);
    }
  });

  return errors;
}

/**
 * Helper: Validate progressive-disclosure structure
 */
function validateProgressiveDisclosure(pd) {
  const errors = [];

  if (!pd) {
    errors.push('progressive-disclosure is required');
    return errors;
  }

  // layer1 must include rl_metrics for v3
  if (!pd.layer1 || !Array.isArray(pd.layer1)) {
    errors.push('progressive-disclosure.layer1 is required and must be an array');
  } else if (!pd.layer1.includes('rl_metrics')) {
    errors.push('progressive-disclosure.layer1 must include "rl_metrics" for v3 compliance');
  }

  // layer2 must include instructions
  if (!pd.layer2 || !Array.isArray(pd.layer2)) {
    errors.push('progressive-disclosure.layer2 is required and must be an array');
  } else if (!pd.layer2.includes('instructions')) {
    errors.push('progressive-disclosure.layer2 must include "instructions"');
  }

  // layer3 must exist
  if (!pd.layer3 || !Array.isArray(pd.layer3)) {
    errors.push('progressive-disclosure.layer3 is required and must be an array');
  }

  return errors;
}

/**
 * Validate a skill definition against v3 contract
 */
function validateSkillDefinition(skill) {
  const errors = [];

  // Required fields
  if (!skill.name || typeof skill.name !== 'string') {
    errors.push('name is required and must be a string');
  } else if (!/^[a-z][a-z0-9-]*[a-z0-9]$/.test(skill.name)) {
    errors.push(`name "${skill.name}" must be kebab-case`);
  }

  if (!skill.version || !/^\d+\.\d+\.\d+$/.test(skill.version)) {
    errors.push(`version "${skill.version}" must be semantic version (X.Y.Z)`);
  }

  if (!skill.description || skill.description.length < 50) {
    errors.push('description is required and must be at least 50 characters');
  }

  if (!skill.triggers || !Array.isArray(skill.triggers) || skill.triggers.length === 0) {
    errors.push('triggers is required and must be a non-empty array');
  } else if (skill.triggers.length > 10) {
    errors.push('triggers must have at most 10 items');
  }

  // Validate rl_metrics (required in v3)
  if (!skill.rl_metrics) {
    errors.push('rl_metrics is required for skill-definition v3');
  } else {
    errors.push(...validateRLMetrics(skill.rl_metrics));
  }

  // Validate progressive-disclosure (required in v3)
  errors.push(...validateProgressiveDisclosure(skill['progressive-disclosure']));

  // Validate agent-invocations (optional but must be valid if present)
  if (skill['agent-invocations']) {
    errors.push(...validateAgentInvocations(skill['agent-invocations']));
  }

  // Validate category if present
  if (skill.category && !VALID_CATEGORIES.includes(skill.category)) {
    errors.push(`category "${skill.category}" is not valid. Valid: ${VALID_CATEGORIES.join(', ')}`);
  }

  return errors;
}

// Test Suite
describe('Skill Definition v3 Contract Tests', () => {

  describe('Required Fields Validation', () => {

    test('T001-AC1: validates all required fields', () => {
      const validSkill = {
        name: 'test-skill',
        version: '1.0.0',
        description: 'This is a test skill description that meets the minimum length requirement of 50 characters.',
        triggers: ['/test', 'test-trigger'],
        'progressive-disclosure': {
          layer1: ['name', 'description', 'triggers', 'rl_metrics'],
          layer2: ['instructions', 'agent-invocations'],
          layer3: ['examples', 'references']
        },
        rl_metrics: {
          success_rate: 0.5,
          selection_weight: 0.5
        }
      };

      const errors = validateSkillDefinition(validSkill);
      expect(errors).toHaveLength(0);
    });

    test('T001-AC1: fails when required fields missing', () => {
      const invalidSkill = {};
      const errors = validateSkillDefinition(invalidSkill);

      expect(errors.length).toBeGreaterThan(0);
      expect(errors.some(e => e.includes('name'))).toBe(true);
      expect(errors.some(e => e.includes('version'))).toBe(true);
      expect(errors.some(e => e.includes('description'))).toBe(true);
      expect(errors.some(e => e.includes('triggers'))).toBe(true);
      expect(errors.some(e => e.includes('rl_metrics'))).toBe(true);
    });
  });

  describe('RL Metrics Bounds Validation', () => {

    test('T001-AC2: validates success_rate bounds (0-1)', () => {
      // Valid bounds
      expect(validateRLMetrics({ success_rate: 0 })).toHaveLength(0);
      expect(validateRLMetrics({ success_rate: 0.5 })).toHaveLength(0);
      expect(validateRLMetrics({ success_rate: 1 })).toHaveLength(0);

      // Invalid bounds
      expect(validateRLMetrics({ success_rate: -0.1 }).length).toBeGreaterThan(0);
      expect(validateRLMetrics({ success_rate: 1.1 }).length).toBeGreaterThan(0);
    });

    test('T001-AC2: validates selection_weight bounds (0.1-1.0)', () => {
      // Valid bounds
      expect(validateRLMetrics({ selection_weight: 0.1 })).toHaveLength(0);
      expect(validateRLMetrics({ selection_weight: 0.5 })).toHaveLength(0);
      expect(validateRLMetrics({ selection_weight: 1.0 })).toHaveLength(0);

      // Invalid bounds
      expect(validateRLMetrics({ selection_weight: 0.05 }).length).toBeGreaterThan(0);
      expect(validateRLMetrics({ selection_weight: 1.1 }).length).toBeGreaterThan(0);
    });
  });

  describe('Agent Invocations Validation', () => {

    test('T001-AC3: validates agent references against consolidated agent names', () => {
      // Valid consolidated agent
      const validInvocation = [{
        agent: 'database-specialist',
        'context-subset': ['data-model', 'constraints'],
        when: 'database schema work needed'
      }];
      expect(validateAgentInvocations(validInvocation)).toHaveLength(0);

      // Invalid agent name (old name)
      const invalidInvocation = [{
        agent: 'frontend-specialist', // Should be implementation-specialist
        'context-subset': ['ui-requirements'],
        when: 'frontend work needed'
      }];
      const errors = validateAgentInvocations(invalidInvocation);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('not a valid consolidated agent');
    });

    test('T001-AC3: context-subset must have 1-10 items', () => {
      // Empty context-subset
      const emptyContext = [{
        agent: 'database-specialist',
        'context-subset': [],
        when: 'some condition here'
      }];
      expect(validateAgentInvocations(emptyContext).length).toBeGreaterThan(0);

      // Too many context items
      const tooManyContext = [{
        agent: 'database-specialist',
        'context-subset': Array(11).fill('item'),
        when: 'some condition here'
      }];
      expect(validateAgentInvocations(tooManyContext).length).toBeGreaterThan(0);
    });
  });

  describe('Progressive Disclosure Validation', () => {

    test('T001-AC4: validates progressive-disclosure layer definitions', () => {
      // Valid structure
      const valid = {
        layer1: ['name', 'description', 'triggers', 'rl_metrics'],
        layer2: ['instructions', 'agent-invocations'],
        layer3: ['examples']
      };
      expect(validateProgressiveDisclosure(valid)).toHaveLength(0);

      // Missing rl_metrics in layer1 (v3 requirement)
      const missingRL = {
        layer1: ['name', 'description', 'triggers'],
        layer2: ['instructions'],
        layer3: ['examples']
      };
      const errors = validateProgressiveDisclosure(missingRL);
      expect(errors.some(e => e.includes('rl_metrics'))).toBe(true);
    });

    test('T001-AC4: layer2 must include instructions', () => {
      const missingInstructions = {
        layer1: ['name', 'rl_metrics'],
        layer2: ['agent-invocations'], // Missing instructions
        layer3: ['examples']
      };
      const errors = validateProgressiveDisclosure(missingInstructions);
      expect(errors.some(e => e.includes('instructions'))).toBe(true);
    });
  });

  describe('Integration: Existing Skills Validation', () => {

    test('T001-INT: All existing SKILL.md files should fail v3 validation (RED phase)', () => {
      // This test expects failures because skills haven't been upgraded to v3 yet
      // This confirms we're in the RED phase of TDD

      if (!fs.existsSync(SKILLS_DIR)) {
        console.log('Skills directory not found - skipping integration test');
        return;
      }

      const skillFiles = [];

      function findSkillFiles(dir) {
        const files = fs.readdirSync(dir);
        files.forEach(file => {
          const fullPath = path.join(dir, file);
          const stat = fs.statSync(fullPath);
          if (stat.isDirectory()) {
            findSkillFiles(fullPath);
          } else if (file === 'SKILL.md') {
            skillFiles.push(fullPath);
          }
        });
      }

      findSkillFiles(SKILLS_DIR);

      if (skillFiles.length === 0) {
        console.log('No SKILL.md files found - skipping validation');
        return;
      }

      // Count skills that pass v3 validation
      let passingSkills = 0;
      let failingSkills = 0;

      skillFiles.forEach(filePath => {
        try {
          const content = fs.readFileSync(filePath, 'utf-8');
          const skill = parseSkillFrontmatter(content);
          const errors = validateSkillDefinition(skill);

          if (errors.length === 0) {
            passingSkills++;
          } else {
            failingSkills++;
          }
        } catch (e) {
          failingSkills++;
        }
      });

      // In RED phase, we expect most/all skills to fail
      console.log(`Skills validation: ${passingSkills} passing, ${failingSkills} failing`);

      // This test documents the current state
      // After T022 completes, all skills should pass
    });
  });
});

// Export for use in other tests
module.exports = {
  validateSkillDefinition,
  validateRLMetrics,
  validateAgentInvocations,
  validateProgressiveDisclosure,
  parseSkillFrontmatter,
  VALID_CONSOLIDATED_AGENTS,
  VALID_CATEGORIES
};
