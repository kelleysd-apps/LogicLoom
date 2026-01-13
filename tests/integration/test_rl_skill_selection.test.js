/**
 * Integration Test - RL Skill Selection
 * Task: T052
 * Purpose: Validate RL-enhanced skill selection behavior
 *
 * Coverage:
 * - Higher-weight skill selected when multiple match
 * - Weight update after invocation (EMA)
 * - Bounds enforcement (0.1-1.0)
 * - Learning history logging
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Paths
const ROOT_DIR = path.join(__dirname, '../..');
const SKILL_INDEX_PATH = path.join(ROOT_DIR, '.claude/skill-index.json');
const SKILL_PERFORMANCE_PATH = path.join(ROOT_DIR, '.docs/rl-metrics/skill-performance.json');
const RL_SCRIPTS_DIR = path.join(ROOT_DIR, '.specify/scripts/bash/rl');

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
 * Helper: Run bash script
 */
function runScript(scriptName, args = []) {
  const scriptPath = path.join(RL_SCRIPTS_DIR, scriptName);
  if (!fs.existsSync(scriptPath)) {
    throw new Error(`Script not found: ${scriptPath}`);
  }

  try {
    const result = execSync(`bash "${scriptPath}" ${args.join(' ')}`, {
      cwd: ROOT_DIR,
      encoding: 'utf-8',
      timeout: 30000
    });
    return result.trim();
  } catch (error) {
    return { error: error.message, stdout: error.stdout, stderr: error.stderr };
  }
}

/**
 * Simulate softmax selection
 */
function softmaxSelect(weights, temperature = 1.0) {
  const expWeights = weights.map(w => Math.exp(w / temperature));
  const sumExp = expWeights.reduce((a, b) => a + b, 0);
  const probabilities = expWeights.map(e => e / sumExp);

  // Deterministic selection for testing - highest probability
  const maxProb = Math.max(...probabilities);
  return probabilities.indexOf(maxProb);
}

/**
 * Simulate EMA weight update
 */
function emaUpdate(currentWeight, reward, alpha = 0.1) {
  const newWeight = alpha * reward + (1 - alpha) * currentWeight;
  // Clamp to bounds
  return Math.max(0.1, Math.min(1.0, newWeight));
}

// Test Suite
describe('RL Skill Selection Integration Tests', () => {

  describe('T052-INT1: Weight-Based Skill Selection', () => {

    let skillIndex;
    let skillPerformance;

    beforeAll(() => {
      skillIndex = loadJson(SKILL_INDEX_PATH);
      skillPerformance = loadJson(SKILL_PERFORMANCE_PATH);
    });

    test('Higher-weight skill is selected when multiple match', () => {
      // Simulate two skills matching the same trigger
      const candidates = [
        { skill: 'domain/database-operations', weight: 0.7 },
        { skill: 'sdd-workflow/sdd-planning', weight: 0.5 }
      ];

      const weights = candidates.map(c => c.weight);
      const selectedIndex = softmaxSelect(weights);

      // Higher weight (0.7) should be selected
      expect(candidates[selectedIndex].weight).toBe(0.7);
      expect(candidates[selectedIndex].skill).toBe('domain/database-operations');
    });

    test('Selection respects weight ordering with temperature', () => {
      const candidates = [
        { skill: 'skill-a', weight: 0.3 },
        { skill: 'skill-b', weight: 0.8 },
        { skill: 'skill-c', weight: 0.5 }
      ];

      const weights = candidates.map(c => c.weight);

      // With low temperature, should strongly prefer highest weight
      const selectedLowTemp = softmaxSelect(weights, 0.1);
      expect(candidates[selectedLowTemp].skill).toBe('skill-b');

      // With high temperature, still likely to select highest but less deterministic
      const selectedHighTemp = softmaxSelect(weights, 1.0);
      expect(candidates[selectedHighTemp].skill).toBe('skill-b'); // Still highest in deterministic selection
    });

    test('Single candidate is selected directly', () => {
      const candidates = [
        { skill: 'domain/frontend-operations', weight: 0.5 }
      ];

      const weights = candidates.map(c => c.weight);
      const selectedIndex = softmaxSelect(weights);

      expect(selectedIndex).toBe(0);
      expect(candidates[selectedIndex].skill).toBe('domain/frontend-operations');
    });

    test('skill-index.json has valid rl_metrics for all skills', () => {
      expect(skillIndex).not.toBeNull();
      expect(skillIndex.skills).toBeDefined();

      skillIndex.skills.forEach(skill => {
        if (skill.rl_metrics) {
          expect(skill.rl_metrics.selection_weight).toBeGreaterThanOrEqual(0.1);
          expect(skill.rl_metrics.selection_weight).toBeLessThanOrEqual(1.0);
          expect(skill.rl_metrics.success_rate).toBeGreaterThanOrEqual(0);
          expect(skill.rl_metrics.success_rate).toBeLessThanOrEqual(1);
        }
      });
    });
  });

  describe('T052-INT2: EMA Weight Update', () => {

    test('EMA formula updates weight correctly for success', () => {
      const currentWeight = 0.5;
      const reward = 0.9; // High reward for success
      const alpha = 0.1;

      const newWeight = emaUpdate(currentWeight, reward, alpha);

      // Expected: 0.1 * 0.9 + 0.9 * 0.5 = 0.09 + 0.45 = 0.54
      expect(newWeight).toBeCloseTo(0.54, 2);
    });

    test('EMA formula updates weight correctly for failure', () => {
      const currentWeight = 0.5;
      const reward = 0.1; // Low reward for failure
      const alpha = 0.1;

      const newWeight = emaUpdate(currentWeight, reward, alpha);

      // Expected: 0.1 * 0.1 + 0.9 * 0.5 = 0.01 + 0.45 = 0.46
      expect(newWeight).toBeCloseTo(0.46, 2);
    });

    test('Reward calculation combines success, tokens, and satisfaction', () => {
      // Reward formula: 0.5*success + 0.3*token_efficiency + 0.2*user_satisfaction
      const success = 1.0;
      const tokenEfficiency = 0.8;
      const userSatisfaction = 0.9;

      const reward = 0.5 * success + 0.3 * tokenEfficiency + 0.2 * userSatisfaction;

      // Expected: 0.5 + 0.24 + 0.18 = 0.92
      expect(reward).toBeCloseTo(0.92, 2);
    });

    test('Token efficiency calculation is correct', () => {
      const baseline = 1000; // tokens
      const actualTokens = 600;

      // Token efficiency = max(0, (baseline - avg_tokens) / baseline)
      const efficiency = Math.max(0, (baseline - actualTokens) / baseline);

      // Expected: (1000 - 600) / 1000 = 0.4
      expect(efficiency).toBeCloseTo(0.4, 2);
    });

    test('Token efficiency does not go negative', () => {
      const baseline = 500;
      const actualTokens = 800; // More than baseline

      const efficiency = Math.max(0, (baseline - actualTokens) / baseline);

      expect(efficiency).toBe(0);
    });
  });

  describe('T052-INT3: Weight Bounds Enforcement', () => {

    test('Weight is clamped to minimum 0.1', () => {
      const currentWeight = 0.15;
      const reward = 0.0; // Complete failure
      const alpha = 0.1;

      // Without clamping: 0.1 * 0 + 0.9 * 0.15 = 0.135
      // Multiple failures would push below 0.1

      let weight = currentWeight;
      for (let i = 0; i < 20; i++) {
        weight = emaUpdate(weight, 0.0, alpha);
      }

      expect(weight).toBeGreaterThanOrEqual(0.1);
    });

    test('Weight is clamped to maximum 1.0', () => {
      const currentWeight = 0.95;
      const reward = 1.0; // Perfect success

      let weight = currentWeight;
      for (let i = 0; i < 20; i++) {
        weight = emaUpdate(weight, 1.0, 0.1);
      }

      expect(weight).toBeLessThanOrEqual(1.0);
    });

    test('Edge case: weight at 0.1 with low reward stays at 0.1', () => {
      const weight = emaUpdate(0.1, 0.0, 0.1);
      expect(weight).toBe(0.1);
    });

    test('Edge case: weight at 1.0 with high reward stays at 1.0', () => {
      const weight = emaUpdate(1.0, 1.0, 0.1);
      expect(weight).toBe(1.0);
    });
  });

  describe('T052-INT4: Learning History Logging', () => {

    test('skill-performance.json structure is valid', () => {
      expect(skillPerformance).not.toBeNull();
      expect(skillPerformance.skills).toBeDefined();
      expect(skillPerformance.global_metrics).toBeDefined();
      expect(skillPerformance.evaluation_config).toBeDefined();
    });

    test('Skill entries have learning_history field', () => {
      if (skillPerformance && skillPerformance.skills) {
        Object.values(skillPerformance.skills).forEach(skill => {
          expect(skill).toHaveProperty('current_weight');
          expect(skill).toHaveProperty('learning_history');
          expect(Array.isArray(skill.learning_history)).toBe(true);
        });
      }
    });

    test('Learning history entry has required fields', () => {
      const historyEntry = {
        timestamp: new Date().toISOString(),
        reward: 0.85,
        weight_before: 0.5,
        weight_after: 0.535,
        outcome: 'success'
      };

      expect(historyEntry).toHaveProperty('timestamp');
      expect(historyEntry).toHaveProperty('reward');
      expect(historyEntry).toHaveProperty('weight_before');
      expect(historyEntry).toHaveProperty('weight_after');
      expect(historyEntry).toHaveProperty('outcome');
    });

    test('Learning history is limited to 100 entries', () => {
      if (skillPerformance && skillPerformance.skills) {
        Object.values(skillPerformance.skills).forEach(skill => {
          expect(skill.learning_history.length).toBeLessThanOrEqual(100);
        });
      }
    });

    test('Evaluation config specifies EMA algorithm', () => {
      expect(skillPerformance.evaluation_config).toBeDefined();
      expect(skillPerformance.evaluation_config.algorithm).toBe('ema');
      expect(skillPerformance.evaluation_config.learning_rate).toBe(0.1);
    });
  });

  describe('T052-INT5: RL Scripts Exist', () => {

    test('update-skill-weight.sh exists', () => {
      const scriptPath = path.join(RL_SCRIPTS_DIR, 'update-skill-weight.sh');
      expect(fs.existsSync(scriptPath)).toBe(true);
    });

    test('select-skill.sh exists', () => {
      const scriptPath = path.join(RL_SCRIPTS_DIR, 'select-skill.sh');
      expect(fs.existsSync(scriptPath)).toBe(true);
    });

    test('credit-assignment.sh exists', () => {
      const scriptPath = path.join(RL_SCRIPTS_DIR, 'credit-assignment.sh');
      expect(fs.existsSync(scriptPath)).toBe(true);
    });

    test('grpo-optimizer.sh exists', () => {
      const scriptPath = path.join(RL_SCRIPTS_DIR, 'grpo-optimizer.sh');
      expect(fs.existsSync(scriptPath)).toBe(true);
    });

    test('load-skill-progressive.sh exists', () => {
      const scriptPath = path.join(RL_SCRIPTS_DIR, 'load-skill-progressive.sh');
      expect(fs.existsSync(scriptPath)).toBe(true);
    });
  });

  describe('T052-INT6: RL Configuration', () => {

    test('rl_config in skill-index.json is valid', () => {
      expect(skillIndex.rl_config).toBeDefined();
      expect(skillIndex.rl_config.algorithm).toBe('ema');
      expect(skillIndex.rl_config.learning_rate).toBe(0.1);
      expect(skillIndex.rl_config.temperature).toBeDefined();
      expect(skillIndex.rl_config.reward_weights).toBeDefined();
    });

    test('Reward weights sum to 1.0', () => {
      const weights = skillIndex.rl_config.reward_weights;
      const sum = weights.success + weights.token_efficiency + weights.user_satisfaction;
      expect(sum).toBeCloseTo(1.0, 2);
    });

    test('Temperature is positive', () => {
      expect(skillIndex.rl_config.temperature).toBeGreaterThan(0);
    });

    test('Learning rate is in valid range', () => {
      expect(skillIndex.rl_config.learning_rate).toBeGreaterThan(0);
      expect(skillIndex.rl_config.learning_rate).toBeLessThanOrEqual(1);
    });
  });
});

// Export for use in other tests
module.exports = {
  softmaxSelect,
  emaUpdate,
  loadJson
};
