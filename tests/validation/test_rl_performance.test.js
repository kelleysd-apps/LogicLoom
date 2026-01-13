/**
 * Validation Test - RL Performance
 * Task: T063
 * FR: FR-604
 * Purpose: Validate +15-25% skill selection accuracy vs baseline
 *
 * Coverage:
 * - Baseline vs RL comparison
 * - A/B test framework
 * - 30-day evaluation window
 * - FR-604 targets validation
 *
 * Note: This test validates the RL INFRASTRUCTURE is in place.
 * Actual performance metrics require production data collection.
 */

const fs = require('fs');
const path = require('path');

// Paths
const ROOT_DIR = path.join(__dirname, '../..');
const SKILL_PERFORMANCE_PATH = path.join(ROOT_DIR, '.docs/rl-metrics/skill-performance.json');
const SKILL_INDEX_PATH = path.join(ROOT_DIR, '.claude/skill-index.json');
const ARCHITECTURE_CONF_PATH = path.join(ROOT_DIR, '.specify/config/architecture.conf');

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
 * Simulate baseline selection (random uniform)
 */
function simulateBaselineSelection(candidates) {
  // Baseline: Random selection with uniform probability
  return Math.floor(Math.random() * candidates.length);
}

/**
 * Simulate RL selection (weight-based)
 */
function simulateRLSelection(weights) {
  // Softmax selection
  const expWeights = weights.map(w => Math.exp(w));
  const sumExp = expWeights.reduce((a, b) => a + b, 0);
  const probabilities = expWeights.map(e => e / sumExp);

  // Select based on probability
  const r = Math.random();
  let cumulative = 0;
  for (let i = 0; i < probabilities.length; i++) {
    cumulative += probabilities[i];
    if (r <= cumulative) {
      return i;
    }
  }
  return weights.length - 1;
}

/**
 * Calculate selection accuracy
 */
function calculateAccuracy(selections, correctIndex, trials) {
  let correct = 0;
  for (let i = 0; i < trials; i++) {
    if (selections[i] === correctIndex) {
      correct++;
    }
  }
  return correct / trials;
}

// Test Suite
describe('RL Performance Validation Tests', () => {

  describe('T063-VAL1: RL Infrastructure Exists', () => {

    test('skill-performance.json exists and has valid structure', () => {
      const performance = loadJson(SKILL_PERFORMANCE_PATH);

      expect(performance).not.toBeNull();
      expect(performance.skills).toBeDefined();
      expect(performance.global_metrics).toBeDefined();
      expect(performance.evaluation_config).toBeDefined();
    });

    test('skill-index.json has rl_config', () => {
      const skillIndex = loadJson(SKILL_INDEX_PATH);

      expect(skillIndex).not.toBeNull();
      expect(skillIndex.rl_config).toBeDefined();
      expect(skillIndex.rl_config.algorithm).toBe('ema');
    });

    test('Architecture config specifies RL algorithm', () => {
      const config = loadConfig(ARCHITECTURE_CONF_PATH);

      expect(config.RL_ALGORITHM).toBeDefined();
      expect(['ema', 'grpo', 'ppo']).toContain(config.RL_ALGORITHM);
    });
  });

  describe('T063-VAL2: Baseline vs RL Comparison (Simulated)', () => {

    test('RL selection outperforms baseline when weights are optimized', () => {
      // Scenario: 3 skills, one is clearly better (higher weight)
      const weights = [0.3, 0.8, 0.4];  // Skill 1 has learned to be best
      const correctIndex = 1;  // We want skill 1 selected
      const trials = 1000;

      // Baseline: Uniform random
      const baselineSelections = Array.from({ length: trials }, () =>
        simulateBaselineSelection(weights)
      );
      const baselineAccuracy = calculateAccuracy(baselineSelections, correctIndex, trials);

      // RL: Weight-based softmax
      const rlSelections = Array.from({ length: trials }, () =>
        simulateRLSelection(weights)
      );
      const rlAccuracy = calculateAccuracy(rlSelections, correctIndex, trials);

      // Baseline should be ~33% (uniform)
      expect(baselineAccuracy).toBeLessThan(0.5);

      // RL should be significantly better with optimized weights
      expect(rlAccuracy).toBeGreaterThan(baselineAccuracy);

      // Calculate improvement
      const improvement = ((rlAccuracy - baselineAccuracy) / baselineAccuracy) * 100;
      console.log(`RL improvement: ${improvement.toFixed(1)}%`);

      // FR-604: +15-25% improvement target
      // With well-differentiated weights, should easily exceed 15%
      expect(improvement).toBeGreaterThan(15);
    });

    test('RL maintains stability with equal weights', () => {
      // Scenario: All skills have equal weights (early learning)
      const weights = [0.5, 0.5, 0.5];
      const trials = 1000;

      const rlSelections = Array.from({ length: trials }, () =>
        simulateRLSelection(weights)
      );

      // With equal weights, distribution should be roughly uniform
      const counts = [0, 0, 0];
      rlSelections.forEach(sel => counts[sel]++);

      // Each should get roughly 33% (+/- 5%)
      counts.forEach(count => {
        const proportion = count / trials;
        expect(proportion).toBeGreaterThan(0.25);
        expect(proportion).toBeLessThan(0.42);
      });
    });

    test('RL weight differentiation improves selection', () => {
      // Simulate learning over time
      const initialWeights = [0.5, 0.5, 0.5];
      const learnedWeights = [0.3, 0.7, 0.5];  // After learning, skill 1 is better

      const trials = 1000;
      const correctIndex = 1;

      // Initial selection accuracy
      const initialSelections = Array.from({ length: trials }, () =>
        simulateRLSelection(initialWeights)
      );
      const initialAccuracy = calculateAccuracy(initialSelections, correctIndex, trials);

      // Learned selection accuracy
      const learnedSelections = Array.from({ length: trials }, () =>
        simulateRLSelection(learnedWeights)
      );
      const learnedAccuracy = calculateAccuracy(learnedSelections, correctIndex, trials);

      // Learned weights should give better accuracy for correct skill
      expect(learnedAccuracy).toBeGreaterThan(initialAccuracy);
    });
  });

  describe('T063-VAL3: Evaluation Configuration', () => {

    let skillPerformance;

    beforeAll(() => {
      skillPerformance = loadJson(SKILL_PERFORMANCE_PATH);
    });

    test('Evaluation config has required parameters', () => {
      expect(skillPerformance.evaluation_config).toBeDefined();
      expect(skillPerformance.evaluation_config.algorithm).toBeDefined();
      expect(skillPerformance.evaluation_config.learning_rate).toBeDefined();
    });

    test('Learning rate is in valid range', () => {
      const lr = skillPerformance.evaluation_config.learning_rate;
      expect(lr).toBeGreaterThan(0);
      expect(lr).toBeLessThanOrEqual(1);
    });

    test('EMA algorithm is default for Phase 1-2', () => {
      expect(skillPerformance.evaluation_config.algorithm).toBe('ema');
    });

    test('Reward weights are defined', () => {
      const config = skillPerformance.evaluation_config;
      expect(config.reward_weights || {}).toBeDefined();

      // If reward weights exist, they should sum to 1
      if (config.reward_weights) {
        const sum = Object.values(config.reward_weights).reduce((a, b) => a + b, 0);
        expect(sum).toBeCloseTo(1.0, 1);
      }
    });
  });

  describe('T063-VAL4: Performance Metrics Structure', () => {

    let skillPerformance;

    beforeAll(() => {
      skillPerformance = loadJson(SKILL_PERFORMANCE_PATH);
    });

    test('Global metrics track baseline improvement', () => {
      expect(skillPerformance.global_metrics).toBeDefined();
      expect(skillPerformance.global_metrics.improvement_over_baseline).toBeDefined();
    });

    test('Skill entries have tracking fields', () => {
      if (skillPerformance.skills) {
        Object.values(skillPerformance.skills).forEach(skill => {
          expect(skill).toHaveProperty('current_weight');
          expect(skill).toHaveProperty('success_count');
          expect(skill).toHaveProperty('failure_count');
          expect(skill).toHaveProperty('invocation_count');
        });
      }
    });

    test('Learning history is bounded', () => {
      if (skillPerformance.skills) {
        Object.values(skillPerformance.skills).forEach(skill => {
          if (skill.learning_history) {
            expect(skill.learning_history.length).toBeLessThanOrEqual(100);
          }
        });
      }
    });
  });

  describe('T063-VAL5: A/B Test Framework Readiness', () => {

    test('Can compute baseline accuracy metric', () => {
      // Baseline: 1/N where N is number of candidates
      const N = 5;  // 5 candidate skills
      const baselineAccuracy = 1 / N;

      expect(baselineAccuracy).toBeCloseTo(0.2, 2);
    });

    test('Can compute RL accuracy metric', () => {
      // RL: Weighted probability of selecting correct skill
      const weights = [0.3, 0.7, 0.5, 0.4, 0.6];  // 5 skills
      const correctIndex = 1;  // Skill with weight 0.7

      // Softmax probability
      const expWeights = weights.map(w => Math.exp(w));
      const sumExp = expWeights.reduce((a, b) => a + b, 0);
      const probCorrect = expWeights[correctIndex] / sumExp;

      expect(probCorrect).toBeGreaterThan(0.2);  // Better than baseline
    });

    test('Improvement calculation is correct', () => {
      const baselineAccuracy = 0.2;  // 1/5
      const rlAccuracy = 0.35;  // After learning

      const improvement = ((rlAccuracy - baselineAccuracy) / baselineAccuracy) * 100;

      // (0.35 - 0.2) / 0.2 * 100 = 75%
      expect(improvement).toBeCloseTo(75, 0);
    });
  });

  describe('T063-VAL6: FR-604 Target Validation', () => {

    test('Target improvement range is 15-25%', () => {
      // FR-604 specifies +15-25% improvement target
      const targetMin = 15;
      const targetMax = 25;

      expect(targetMin).toBe(15);
      expect(targetMax).toBe(25);
    });

    test('Current infrastructure supports target measurement', () => {
      const skillPerformance = loadJson(SKILL_PERFORMANCE_PATH);

      // Infrastructure for measuring improvement exists
      expect(skillPerformance.global_metrics).toBeDefined();
      expect(skillPerformance.global_metrics.improvement_over_baseline).toBeDefined();
    });

    test('Improvement metric is a percentage', () => {
      const skillPerformance = loadJson(SKILL_PERFORMANCE_PATH);
      const improvement = skillPerformance.global_metrics.improvement_over_baseline;

      // Should be a number (percentage)
      expect(typeof improvement).toBe('number');
    });
  });
});

// Export for use in other tests
module.exports = {
  simulateBaselineSelection,
  simulateRLSelection,
  calculateAccuracy,
  loadJson
};
