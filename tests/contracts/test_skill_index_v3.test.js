/**
 * Contract Test - Skill Index v3
 * Task: T004
 * Purpose: Validate skill-index.json v3 schema with RL metrics
 *
 * Coverage:
 * - Version field equals "3.0.0"
 * - rl_config with algorithm, learning_rate, reward_weights
 * - Routing table structure (command-routes, keyword-routes, domain-routes)
 * - rl_statistics in statistics section
 * - Skill entries include rl_metrics
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');

// Path to skill-index.json
const SKILL_INDEX_PATH = path.join(__dirname, '../../.claude/skill-index.json');

// Valid RL algorithms
const VALID_RL_ALGORITHMS = ['ema', 'grpo', 'ppo'];

// Valid architecture modes
const VALID_ARCHITECTURE_MODES = ['hybrid', 'skills-first', 'legacy-agents'];

// Valid skill statuses
const VALID_SKILL_STATUSES = ['active', 'deprecated', 'draft'];

/**
 * Helper: Validate version is exactly 3.0.0
 */
function validateVersion(index) {
  const errors = [];

  if (!index.version) {
    errors.push('version is required');
  } else if (index.version !== '3.0.0') {
    errors.push(`version must be "3.0.0", got "${index.version}"`);
  }

  return errors;
}

/**
 * Helper: Validate rl_config structure
 */
function validateRLConfig(rlConfig) {
  const errors = [];

  if (!rlConfig) {
    errors.push('rl_config is required for skill-index v3');
    return errors;
  }

  // Required: algorithm
  if (!rlConfig.algorithm) {
    errors.push('rl_config.algorithm is required');
  } else if (!VALID_RL_ALGORITHMS.includes(rlConfig.algorithm)) {
    errors.push(`rl_config.algorithm "${rlConfig.algorithm}" is not valid. Valid: ${VALID_RL_ALGORITHMS.join(', ')}`);
  }

  // Required: learning_rate (0.01-0.5)
  if (rlConfig.learning_rate === undefined) {
    errors.push('rl_config.learning_rate is required');
  } else if (rlConfig.learning_rate < 0.01 || rlConfig.learning_rate > 0.5) {
    errors.push(`rl_config.learning_rate ${rlConfig.learning_rate} must be between 0.01 and 0.5`);
  }

  // Required: reward_weights
  if (!rlConfig.reward_weights) {
    errors.push('rl_config.reward_weights is required');
  } else {
    // Check reward_weights structure
    if (rlConfig.reward_weights.success_rate === undefined) {
      errors.push('rl_config.reward_weights.success_rate is required');
    }
    if (rlConfig.reward_weights.token_efficiency === undefined) {
      errors.push('rl_config.reward_weights.token_efficiency is required');
    }
    if (rlConfig.reward_weights.user_satisfaction === undefined) {
      errors.push('rl_config.reward_weights.user_satisfaction is required');
    }

    // Weights should sum to approximately 1.0
    if (rlConfig.reward_weights.success_rate !== undefined &&
        rlConfig.reward_weights.token_efficiency !== undefined &&
        rlConfig.reward_weights.user_satisfaction !== undefined) {
      const sum = rlConfig.reward_weights.success_rate +
                  rlConfig.reward_weights.token_efficiency +
                  rlConfig.reward_weights.user_satisfaction;
      if (sum < 0.99 || sum > 1.01) {
        errors.push(`rl_config.reward_weights should sum to 1.0, got ${sum}`);
      }
    }
  }

  // Optional but validated: selection_temperature (0.1-2.0)
  if (rlConfig.selection_temperature !== undefined) {
    if (rlConfig.selection_temperature < 0.1 || rlConfig.selection_temperature > 2.0) {
      errors.push(`rl_config.selection_temperature ${rlConfig.selection_temperature} must be between 0.1 and 2.0`);
    }
  }

  // Optional but validated: min_weight and max_weight
  if (rlConfig.min_weight !== undefined && rlConfig.max_weight !== undefined) {
    if (rlConfig.min_weight >= rlConfig.max_weight) {
      errors.push('rl_config.min_weight must be less than max_weight');
    }
  }

  return errors;
}

/**
 * Helper: Validate routing table structure
 */
function validateRoutingTable(routing) {
  const errors = [];

  if (!routing) {
    errors.push('routing is required');
    return errors;
  }

  // Required: command-routes
  if (!routing['command-routes']) {
    errors.push('routing.command-routes is required');
  } else if (typeof routing['command-routes'] !== 'object') {
    errors.push('routing.command-routes must be an object');
  }

  // Required: keyword-routes
  if (!routing['keyword-routes']) {
    errors.push('routing.keyword-routes is required');
  } else if (typeof routing['keyword-routes'] !== 'object') {
    errors.push('routing.keyword-routes must be an object');
  }

  // Required: domain-routes
  if (!routing['domain-routes']) {
    errors.push('routing.domain-routes is required');
  } else if (typeof routing['domain-routes'] !== 'object') {
    errors.push('routing.domain-routes must be an object');
  }

  return errors;
}

/**
 * Helper: Validate skill entry RL metrics
 */
function validateSkillEntryRLMetrics(skill, idx) {
  const errors = [];

  if (!skill.rl_metrics) {
    errors.push(`skills[${idx}] "${skill.name}" is missing rl_metrics (required for v3)`);
    return errors;
  }

  const rl = skill.rl_metrics;

  // Required fields
  if (rl.success_rate === undefined) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.success_rate is required`);
  } else if (rl.success_rate < 0 || rl.success_rate > 1) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.success_rate must be 0-1`);
  }

  if (rl.selection_weight === undefined) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.selection_weight is required`);
  } else if (rl.selection_weight < 0.1 || rl.selection_weight > 1.0) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.selection_weight must be 0.1-1.0`);
  }

  if (rl.invocation_count === undefined) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.invocation_count is required`);
  } else if (rl.invocation_count < 0) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.invocation_count must be >= 0`);
  }

  if (rl.avg_tokens === undefined) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.avg_tokens is required`);
  } else if (rl.avg_tokens < 0) {
    errors.push(`skills[${idx}] "${skill.name}" rl_metrics.avg_tokens must be >= 0`);
  }

  return errors;
}

/**
 * Helper: Validate statistics section includes rl_statistics
 */
function validateStatistics(statistics) {
  const errors = [];

  if (!statistics) {
    errors.push('statistics is required');
    return errors;
  }

  // Required: rl_statistics for v3
  if (!statistics.rl_statistics) {
    errors.push('statistics.rl_statistics is required for skill-index v3');
    return errors;
  }

  const rlStats = statistics.rl_statistics;

  // Optional but validated if present
  if (rlStats.avg_selection_weight !== undefined) {
    if (rlStats.avg_selection_weight < 0.1 || rlStats.avg_selection_weight > 1.0) {
      errors.push(`statistics.rl_statistics.avg_selection_weight ${rlStats.avg_selection_weight} must be 0.1-1.0`);
    }
  }

  if (rlStats.avg_success_rate !== undefined) {
    if (rlStats.avg_success_rate < 0 || rlStats.avg_success_rate > 1) {
      errors.push(`statistics.rl_statistics.avg_success_rate ${rlStats.avg_success_rate} must be 0-1`);
    }
  }

  if (rlStats.total_invocations !== undefined && rlStats.total_invocations < 0) {
    errors.push(`statistics.rl_statistics.total_invocations ${rlStats.total_invocations} must be >= 0`);
  }

  return errors;
}

/**
 * Validate complete skill-index.json v3
 */
function validateSkillIndex(index) {
  const errors = [];

  // Validate version
  errors.push(...validateVersion(index));

  // Validate architecture-mode
  if (!index['architecture-mode']) {
    errors.push('architecture-mode is required');
  } else if (!VALID_ARCHITECTURE_MODES.includes(index['architecture-mode'])) {
    errors.push(`architecture-mode "${index['architecture-mode']}" is not valid`);
  }

  // Validate generated timestamp
  if (!index.generated) {
    errors.push('generated timestamp is required');
  }

  // Validate rl_config
  errors.push(...validateRLConfig(index.rl_config));

  // Validate routing table
  errors.push(...validateRoutingTable(index.routing));

  // Validate skills array
  if (!index.skills || !Array.isArray(index.skills)) {
    errors.push('skills array is required');
  } else {
    index.skills.forEach((skill, idx) => {
      errors.push(...validateSkillEntryRLMetrics(skill, idx));

      // Validate skill status
      if (skill.status && !VALID_SKILL_STATUSES.includes(skill.status)) {
        errors.push(`skills[${idx}] "${skill.name}" has invalid status "${skill.status}"`);
      }
    });
  }

  // Validate statistics
  errors.push(...validateStatistics(index.statistics));

  return errors;
}

// Test Suite
describe('Skill Index v3 Contract Tests', () => {

  describe('Version Validation', () => {

    test('T004-AC1: version field must equal "3.0.0"', () => {
      expect(validateVersion({ version: '3.0.0' })).toHaveLength(0);
      expect(validateVersion({ version: '2.0.0' }).length).toBeGreaterThan(0);
      expect(validateVersion({}).length).toBeGreaterThan(0);
    });
  });

  describe('RL Config Validation', () => {

    test('T004-AC2: validates rl_config with algorithm, learning_rate, reward_weights', () => {
      const validConfig = {
        algorithm: 'ema',
        learning_rate: 0.1,
        reward_weights: {
          success_rate: 0.5,
          token_efficiency: 0.3,
          user_satisfaction: 0.2
        },
        selection_temperature: 1.0,
        min_weight: 0.1,
        max_weight: 1.0
      };

      expect(validateRLConfig(validConfig)).toHaveLength(0);
    });

    test('T004-AC2: algorithm must be ema, grpo, or ppo', () => {
      expect(validateRLConfig({ algorithm: 'ema', learning_rate: 0.1, reward_weights: { success_rate: 0.5, token_efficiency: 0.3, user_satisfaction: 0.2 } })).toHaveLength(0);
      expect(validateRLConfig({ algorithm: 'grpo', learning_rate: 0.1, reward_weights: { success_rate: 0.5, token_efficiency: 0.3, user_satisfaction: 0.2 } })).toHaveLength(0);
      expect(validateRLConfig({ algorithm: 'invalid', learning_rate: 0.1, reward_weights: { success_rate: 0.5, token_efficiency: 0.3, user_satisfaction: 0.2 } }).length).toBeGreaterThan(0);
    });

    test('T004-AC2: learning_rate must be 0.01-0.5', () => {
      const base = { algorithm: 'ema', reward_weights: { success_rate: 0.5, token_efficiency: 0.3, user_satisfaction: 0.2 } };

      expect(validateRLConfig({ ...base, learning_rate: 0.01 })).toHaveLength(0);
      expect(validateRLConfig({ ...base, learning_rate: 0.5 })).toHaveLength(0);
      expect(validateRLConfig({ ...base, learning_rate: 0.005 }).length).toBeGreaterThan(0);
      expect(validateRLConfig({ ...base, learning_rate: 0.6 }).length).toBeGreaterThan(0);
    });

    test('T004-AC2: reward_weights should sum to 1.0', () => {
      const base = { algorithm: 'ema', learning_rate: 0.1 };

      // Valid: sums to 1.0
      expect(validateRLConfig({ ...base, reward_weights: { success_rate: 0.5, token_efficiency: 0.3, user_satisfaction: 0.2 } })).toHaveLength(0);

      // Invalid: sums to 0.5
      const errors = validateRLConfig({ ...base, reward_weights: { success_rate: 0.2, token_efficiency: 0.2, user_satisfaction: 0.1 } });
      expect(errors.some(e => e.includes('sum to 1.0'))).toBe(true);
    });
  });

  describe('Routing Table Validation', () => {

    test('T004-AC3: validates routing table structure', () => {
      const validRouting = {
        'command-routes': {
          '/specify': 'sdd-workflow/sdd-specification'
        },
        'keyword-routes': {
          'database': ['domain/database-operations']
        },
        'domain-routes': {
          'database': {
            'primary-skill': 'domain/database-operations',
            'primary-agent': 'database-specialist'
          }
        }
      };

      expect(validateRoutingTable(validRouting)).toHaveLength(0);
    });

    test('T004-AC3: requires command-routes, keyword-routes, domain-routes', () => {
      expect(validateRoutingTable({}).length).toBeGreaterThan(0);
      expect(validateRoutingTable({ 'command-routes': {} }).length).toBeGreaterThan(0);
    });
  });

  describe('Skill Entry RL Metrics Validation', () => {

    test('T004-AC4: validates skill entries include rl_metrics', () => {
      const validSkill = {
        name: 'test-skill',
        rl_metrics: {
          success_rate: 0.85,
          avg_tokens: 1200,
          selection_weight: 0.75,
          invocation_count: 100
        }
      };

      expect(validateSkillEntryRLMetrics(validSkill, 0)).toHaveLength(0);
    });

    test('T004-AC4: fails when rl_metrics missing', () => {
      const invalidSkill = { name: 'test-skill' };
      const errors = validateSkillEntryRLMetrics(invalidSkill, 0);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('missing rl_metrics');
    });

    test('T004-AC4: validates rl_metrics bounds', () => {
      const invalidSkill = {
        name: 'test-skill',
        rl_metrics: {
          success_rate: 1.5, // Invalid
          selection_weight: 0.05, // Invalid
          invocation_count: -1, // Invalid
          avg_tokens: -100 // Invalid
        }
      };

      const errors = validateSkillEntryRLMetrics(invalidSkill, 0);
      expect(errors.length).toBeGreaterThan(0);
    });
  });

  describe('Statistics with RL Validation', () => {

    test('T004-AC5: validates rl_statistics in statistics section', () => {
      const validStats = {
        'total-skills': 35,
        rl_statistics: {
          avg_selection_weight: 0.65,
          total_invocations: 1500,
          avg_success_rate: 0.87,
          improvement_over_baseline: 0.18
        }
      };

      expect(validateStatistics(validStats)).toHaveLength(0);
    });

    test('T004-AC5: fails when rl_statistics missing', () => {
      const invalidStats = { 'total-skills': 35 };
      const errors = validateStatistics(invalidStats);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('rl_statistics is required');
    });
  });

  describe('Integration: Current Skill Index Validation', () => {

    test('T004-INT: Current skill-index.json should fail v3 validation (RED phase)', () => {
      if (!fs.existsSync(SKILL_INDEX_PATH)) {
        console.log('skill-index.json not found - will be created by T013');
        return;
      }

      const content = fs.readFileSync(SKILL_INDEX_PATH, 'utf-8');
      const index = JSON.parse(content);
      const errors = validateSkillIndex(index);

      // In RED phase, current index should fail v3 validation
      console.log(`skill-index.json validation: ${errors.length} errors`);
      if (errors.length > 0) {
        console.log('Expected failures (RED phase):');
        errors.slice(0, 5).forEach(e => console.log(`  - ${e}`));
      }
    });
  });
});

// Export for use in other tests
module.exports = {
  validateSkillIndex,
  validateVersion,
  validateRLConfig,
  validateRoutingTable,
  validateSkillEntryRLMetrics,
  validateStatistics,
  VALID_RL_ALGORITHMS,
  VALID_ARCHITECTURE_MODES
};
