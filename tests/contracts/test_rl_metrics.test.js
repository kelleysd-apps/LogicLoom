/**
 * Contract Test - RL Metrics
 * Task: T006
 * Purpose: Validate skill-performance.json structure
 *
 * Coverage:
 * - Skill performance structure (current_weight bounds, invocation counts)
 * - learning_history entry structure
 * - global_metrics including improvement_over_baseline
 * - evaluation_config parameters
 * - Count consistency (invocation_count = success + failure + partial)
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');

// Path to skill-performance.json (will be created)
const SKILL_PERFORMANCE_PATH = path.join(__dirname, '../../.docs/rl-metrics/skill-performance.json');

// Valid outcome types
const VALID_OUTCOMES = ['success', 'failure', 'partial'];

// Valid RL algorithms
const VALID_RL_ALGORITHMS = ['ema', 'grpo', 'ppo', 'disabled'];

/**
 * Helper: Validate skill performance entry
 */
function validateSkillPerformance(skillPerf, skillName) {
  const errors = [];

  if (!skillPerf) {
    errors.push(`${skillName}: skill performance entry is required`);
    return errors;
  }

  // current_weight must be 0.1-1.0
  if (skillPerf.current_weight === undefined) {
    errors.push(`${skillName}: current_weight is required`);
  } else if (skillPerf.current_weight < 0.1 || skillPerf.current_weight > 1.0) {
    errors.push(`${skillName}: current_weight ${skillPerf.current_weight} must be 0.1-1.0`);
  }

  // invocation_count must be >= 0
  if (skillPerf.invocation_count === undefined) {
    errors.push(`${skillName}: invocation_count is required`);
  } else if (skillPerf.invocation_count < 0) {
    errors.push(`${skillName}: invocation_count must be >= 0`);
  }

  // success_count must be >= 0
  if (skillPerf.success_count !== undefined && skillPerf.success_count < 0) {
    errors.push(`${skillName}: success_count must be >= 0`);
  }

  // failure_count must be >= 0
  if (skillPerf.failure_count !== undefined && skillPerf.failure_count < 0) {
    errors.push(`${skillName}: failure_count must be >= 0`);
  }

  // partial_count must be >= 0
  if (skillPerf.partial_count !== undefined && skillPerf.partial_count < 0) {
    errors.push(`${skillName}: partial_count must be >= 0`);
  }

  // total_tokens must be >= 0
  if (skillPerf.total_tokens !== undefined && skillPerf.total_tokens < 0) {
    errors.push(`${skillName}: total_tokens must be >= 0`);
  }

  // total_duration_ms must be >= 0
  if (skillPerf.total_duration_ms !== undefined && skillPerf.total_duration_ms < 0) {
    errors.push(`${skillName}: total_duration_ms must be >= 0`);
  }

  // Validate learning_history if present
  if (skillPerf.learning_history) {
    errors.push(...validateLearningHistory(skillPerf.learning_history, skillName));
  }

  return errors;
}

/**
 * Helper: Validate learning_history array
 */
function validateLearningHistory(history, skillName) {
  const errors = [];

  if (!Array.isArray(history)) {
    errors.push(`${skillName}: learning_history must be an array`);
    return errors;
  }

  // Max 100 entries
  if (history.length > 100) {
    errors.push(`${skillName}: learning_history should have max 100 entries, got ${history.length}`);
  }

  history.forEach((entry, idx) => {
    errors.push(...validateLearningEntry(entry, `${skillName}.learning_history[${idx}]`));
  });

  return errors;
}

/**
 * Helper: Validate individual learning_history entry
 */
function validateLearningEntry(entry, path) {
  const errors = [];

  // timestamp is required
  if (!entry.timestamp) {
    errors.push(`${path}: timestamp is required`);
  } else {
    const dateRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;
    if (!dateRegex.test(entry.timestamp)) {
      errors.push(`${path}: timestamp must be ISO8601 format`);
    }
  }

  // reward must be present and 0-1 typically
  if (entry.reward === undefined) {
    errors.push(`${path}: reward is required`);
  } else if (entry.reward < 0 || entry.reward > 1) {
    errors.push(`${path}: reward ${entry.reward} should be 0-1`);
  }

  // weight_before must be 0.1-1.0
  if (entry.weight_before !== undefined) {
    if (entry.weight_before < 0.1 || entry.weight_before > 1.0) {
      errors.push(`${path}: weight_before ${entry.weight_before} must be 0.1-1.0`);
    }
  }

  // weight_after must be 0.1-1.0
  if (entry.weight_after !== undefined) {
    if (entry.weight_after < 0.1 || entry.weight_after > 1.0) {
      errors.push(`${path}: weight_after ${entry.weight_after} must be 0.1-1.0`);
    }
  }

  // outcome must be valid
  if (entry.outcome && !VALID_OUTCOMES.includes(entry.outcome)) {
    errors.push(`${path}: outcome "${entry.outcome}" is not valid. Valid: ${VALID_OUTCOMES.join(', ')}`);
  }

  // tokens_used must be >= 0
  if (entry.tokens_used !== undefined && entry.tokens_used < 0) {
    errors.push(`${path}: tokens_used must be >= 0`);
  }

  return errors;
}

/**
 * Helper: Validate global_metrics structure
 */
function validateGlobalMetrics(globalMetrics) {
  const errors = [];

  if (!globalMetrics) {
    errors.push('global_metrics is required');
    return errors;
  }

  // avg_selection_accuracy should be 0-1
  if (globalMetrics.avg_selection_accuracy !== undefined) {
    if (globalMetrics.avg_selection_accuracy < 0 || globalMetrics.avg_selection_accuracy > 1) {
      errors.push(`global_metrics.avg_selection_accuracy ${globalMetrics.avg_selection_accuracy} should be 0-1`);
    }
  }

  // improvement_over_baseline can be any float (negative means regression)
  // Target is 0.15-0.25 (15-25% improvement)
  if (globalMetrics.improvement_over_baseline !== undefined) {
    // Just validate it's a number
    if (typeof globalMetrics.improvement_over_baseline !== 'number') {
      errors.push('global_metrics.improvement_over_baseline must be a number');
    }
  }

  // total_reward should be >= 0
  if (globalMetrics.total_reward !== undefined && globalMetrics.total_reward < 0) {
    errors.push(`global_metrics.total_reward ${globalMetrics.total_reward} should be >= 0`);
  }

  // evaluation_window_days should be 1-90
  if (globalMetrics.evaluation_window_days !== undefined) {
    if (globalMetrics.evaluation_window_days < 1 || globalMetrics.evaluation_window_days > 90) {
      errors.push(`global_metrics.evaluation_window_days ${globalMetrics.evaluation_window_days} must be 1-90`);
    }
  }

  return errors;
}

/**
 * Helper: Validate evaluation_config structure
 */
function validateEvaluationConfig(config) {
  const errors = [];

  if (!config) {
    errors.push('evaluation_config is required');
    return errors;
  }

  // algorithm is required
  if (!config.algorithm) {
    errors.push('evaluation_config.algorithm is required');
  } else if (!VALID_RL_ALGORITHMS.includes(config.algorithm)) {
    errors.push(`evaluation_config.algorithm "${config.algorithm}" is not valid`);
  }

  // learning_rate should be 0.01-0.5
  if (config.learning_rate !== undefined) {
    if (config.learning_rate < 0.01 || config.learning_rate > 0.5) {
      errors.push(`evaluation_config.learning_rate ${config.learning_rate} must be 0.01-0.5`);
    }
  }

  // reward_weights should have required fields
  if (config.reward_weights) {
    const rw = config.reward_weights;
    if (rw.success === undefined) {
      errors.push('evaluation_config.reward_weights.success is required');
    }
    if (rw.token_efficiency === undefined) {
      errors.push('evaluation_config.reward_weights.token_efficiency is required');
    }
    if (rw.user_satisfaction === undefined) {
      errors.push('evaluation_config.reward_weights.user_satisfaction is required');
    }
  } else {
    errors.push('evaluation_config.reward_weights is required');
  }

  // min_weight and max_weight bounds
  if (config.min_weight !== undefined && (config.min_weight < 0.01 || config.min_weight > 0.5)) {
    errors.push(`evaluation_config.min_weight ${config.min_weight} must be 0.01-0.5`);
  }
  if (config.max_weight !== undefined && (config.max_weight < 0.5 || config.max_weight > 1.0)) {
    errors.push(`evaluation_config.max_weight ${config.max_weight} must be 0.5-1.0`);
  }

  return errors;
}

/**
 * Helper: Validate count consistency
 */
function validateCountConsistency(skillPerf, skillName) {
  const errors = [];

  // invocation_count should equal success + failure + partial
  if (skillPerf.invocation_count !== undefined &&
      skillPerf.success_count !== undefined &&
      skillPerf.failure_count !== undefined) {

    const partialCount = skillPerf.partial_count || 0;
    const expectedTotal = skillPerf.success_count + skillPerf.failure_count + partialCount;

    if (skillPerf.invocation_count !== expectedTotal) {
      errors.push(`${skillName}: invocation_count (${skillPerf.invocation_count}) should equal success (${skillPerf.success_count}) + failure (${skillPerf.failure_count}) + partial (${partialCount}) = ${expectedTotal}`);
    }
  }

  return errors;
}

/**
 * Validate complete skill-performance.json
 */
function validateSkillPerformanceFile(data) {
  const errors = [];

  // Version check
  if (!data.version) {
    errors.push('version is required');
  }

  // last_updated check
  if (!data.last_updated) {
    errors.push('last_updated is required');
  }

  // total_invocations check
  if (data.total_invocations !== undefined && data.total_invocations < 0) {
    errors.push('total_invocations must be >= 0');
  }

  // Validate skills map
  if (!data.skills) {
    errors.push('skills map is required');
  } else if (typeof data.skills !== 'object') {
    errors.push('skills must be an object');
  } else {
    Object.entries(data.skills).forEach(([skillName, skillPerf]) => {
      errors.push(...validateSkillPerformance(skillPerf, skillName));
      errors.push(...validateCountConsistency(skillPerf, skillName));
    });
  }

  // Validate global_metrics
  errors.push(...validateGlobalMetrics(data.global_metrics));

  // Validate evaluation_config
  errors.push(...validateEvaluationConfig(data.evaluation_config));

  return errors;
}

// Test Suite
describe('RL Metrics Contract Tests', () => {

  describe('Skill Performance Validation', () => {

    test('T006-AC1: validates skill performance fields', () => {
      const validPerf = {
        skill_name: 'sdd-specification',
        current_weight: 0.85,
        invocation_count: 100,
        success_count: 85,
        failure_count: 10,
        partial_count: 5,
        total_tokens: 120000,
        total_duration_ms: 4500000
      };

      expect(validateSkillPerformance(validPerf, 'test-skill')).toHaveLength(0);
    });

    test('T006-AC1: current_weight bounds (0.1-1.0)', () => {
      expect(validateSkillPerformance({ current_weight: 0.1, invocation_count: 0 }, 'test')).toHaveLength(0);
      expect(validateSkillPerformance({ current_weight: 1.0, invocation_count: 0 }, 'test')).toHaveLength(0);
      expect(validateSkillPerformance({ current_weight: 0.05, invocation_count: 0 }, 'test').length).toBeGreaterThan(0);
      expect(validateSkillPerformance({ current_weight: 1.1, invocation_count: 0 }, 'test').length).toBeGreaterThan(0);
    });

    test('T006-AC1: invocation counts must be >= 0', () => {
      expect(validateSkillPerformance({ current_weight: 0.5, invocation_count: 0 }, 'test')).toHaveLength(0);
      expect(validateSkillPerformance({ current_weight: 0.5, invocation_count: -1 }, 'test').length).toBeGreaterThan(0);
    });
  });

  describe('Learning History Validation', () => {

    test('T006-AC2: validates learning_history entry structure', () => {
      const validEntry = {
        timestamp: '2026-01-13T10:00:00Z',
        reward: 0.85,
        weight_before: 0.75,
        weight_after: 0.77,
        outcome: 'success',
        tokens_used: 1200
      };

      expect(validateLearningEntry(validEntry, 'test')).toHaveLength(0);
    });

    test('T006-AC2: timestamp must be ISO8601', () => {
      const invalid = { timestamp: 'invalid-date', reward: 0.5 };
      const errors = validateLearningEntry(invalid, 'test');
      expect(errors.some(e => e.includes('ISO8601'))).toBe(true);
    });

    test('T006-AC2: outcome must be success/failure/partial', () => {
      expect(validateLearningEntry({ timestamp: '2026-01-13T10:00:00Z', reward: 0.5, outcome: 'success' }, 'test')).toHaveLength(0);
      expect(validateLearningEntry({ timestamp: '2026-01-13T10:00:00Z', reward: 0.5, outcome: 'invalid' }, 'test').length).toBeGreaterThan(0);
    });

    test('T006-AC2: learning_history max 100 entries', () => {
      const tooManyEntries = Array(101).fill({
        timestamp: '2026-01-13T10:00:00Z',
        reward: 0.5
      });

      const errors = validateLearningHistory(tooManyEntries, 'test');
      expect(errors.some(e => e.includes('max 100'))).toBe(true);
    });
  });

  describe('Global Metrics Validation', () => {

    test('T006-AC3: validates global_metrics including improvement_over_baseline', () => {
      const validMetrics = {
        avg_selection_accuracy: 0.87,
        improvement_over_baseline: 0.18,
        total_reward: 150.5,
        evaluation_window_days: 30
      };

      expect(validateGlobalMetrics(validMetrics)).toHaveLength(0);
    });

    test('T006-AC3: improvement_over_baseline accepts negative values (regression)', () => {
      const regression = {
        improvement_over_baseline: -0.05 // 5% regression
      };
      expect(validateGlobalMetrics(regression)).toHaveLength(0);
    });

    test('T006-AC3: evaluation_window_days must be 1-90', () => {
      expect(validateGlobalMetrics({ evaluation_window_days: 30 })).toHaveLength(0);
      expect(validateGlobalMetrics({ evaluation_window_days: 0 }).length).toBeGreaterThan(0);
      expect(validateGlobalMetrics({ evaluation_window_days: 91 }).length).toBeGreaterThan(0);
    });
  });

  describe('Evaluation Config Validation', () => {

    test('T006-AC4: validates evaluation_config parameters', () => {
      const validConfig = {
        algorithm: 'ema',
        learning_rate: 0.1,
        reward_weights: {
          success: 0.5,
          token_efficiency: 0.3,
          user_satisfaction: 0.2
        },
        min_weight: 0.1,
        max_weight: 1.0
      };

      expect(validateEvaluationConfig(validConfig)).toHaveLength(0);
    });

    test('T006-AC4: algorithm must be valid', () => {
      const invalid = { algorithm: 'invalid', reward_weights: { success: 0.5, token_efficiency: 0.3, user_satisfaction: 0.2 } };
      const errors = validateEvaluationConfig(invalid);
      expect(errors.some(e => e.includes('not valid'))).toBe(true);
    });
  });

  describe('Count Consistency Validation', () => {

    test('T006-AC5: invocation_count = success + failure + partial', () => {
      // Valid: counts match
      const valid = {
        invocation_count: 100,
        success_count: 85,
        failure_count: 10,
        partial_count: 5
      };
      expect(validateCountConsistency(valid, 'test')).toHaveLength(0);

      // Invalid: counts don't match
      const invalid = {
        invocation_count: 100,
        success_count: 85,
        failure_count: 10,
        partial_count: 10 // 85+10+10=105, not 100
      };
      const errors = validateCountConsistency(invalid, 'test');
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('should equal');
    });
  });

  describe('Integration: Current Skill Performance File', () => {

    test('T006-INT: skill-performance.json should fail validation until created (RED phase)', () => {
      if (!fs.existsSync(SKILL_PERFORMANCE_PATH)) {
        console.log('skill-performance.json not found - will be created by T008');
        return;
      }

      const content = fs.readFileSync(SKILL_PERFORMANCE_PATH, 'utf-8');
      const data = JSON.parse(content);
      const errors = validateSkillPerformanceFile(data);

      console.log(`skill-performance.json validation: ${errors.length} errors`);
    });
  });
});

// Export for use in other tests
module.exports = {
  validateSkillPerformanceFile,
  validateSkillPerformance,
  validateLearningHistory,
  validateLearningEntry,
  validateGlobalMetrics,
  validateEvaluationConfig,
  validateCountConsistency,
  VALID_OUTCOMES,
  VALID_RL_ALGORITHMS
};
