/**
 * Contract Test - Skill Invocation v2
 * Task: T003
 * Purpose: Validate skill-to-agent invocation contracts
 *
 * Coverage:
 * - rl_performance tracking per invocation
 * - DS-STAR integration options
 * - Context validation (max 10 fields)
 *
 * TDD Phase: Tests written first (RED phase expected)
 */

const fs = require('fs');
const path = require('path');

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

// Valid DS-STAR agents (FR-709)
const VALID_DS_STAR_AGENTS = [
  'router-agent',
  'verifier-agent',
  'auto-debug-agent',
  'finalizer-agent',
  'context-analyzer'
];

/**
 * Helper: Validate invocation context structure
 */
function validateInvocationContext(context) {
  const errors = [];

  if (!context) {
    errors.push('context is required');
    return errors;
  }

  // Required: skill-id
  if (!context['skill-id']) {
    errors.push('context.skill-id is required');
  } else if (!/^[a-z][a-z0-9-]*\/[a-z][a-z0-9-]*$/.test(context['skill-id'])) {
    errors.push(`context.skill-id "${context['skill-id']}" must match pattern category/skill-name`);
  }

  // Required: agent-id
  if (!context['agent-id']) {
    errors.push('context.agent-id is required');
  } else if (!VALID_CONSOLIDATED_AGENTS.includes(context['agent-id'])) {
    errors.push(`context.agent-id "${context['agent-id']}" is not a valid consolidated agent`);
  }

  // Required: context-subset (1-10 items)
  if (!context['context-subset']) {
    errors.push('context.context-subset is required');
  } else if (!Array.isArray(context['context-subset'])) {
    errors.push('context.context-subset must be an array');
  } else if (context['context-subset'].length === 0) {
    errors.push('context.context-subset must have at least 1 item');
  } else if (context['context-subset'].length > 10) {
    errors.push(`context.context-subset has ${context['context-subset'].length} items, max is 10`);
  }

  // Required: when condition
  if (!context.when) {
    errors.push('context.when condition is required');
  } else if (context.when.length < 10) {
    errors.push('context.when must be at least 10 characters');
  }

  return errors;
}

/**
 * Helper: Validate expected-output format
 */
function validateExpectedOutput(output) {
  const errors = [];

  if (!output) {
    errors.push('expected-output is required');
    return errors;
  }

  // Must have format
  if (!output.format) {
    errors.push('expected-output.format is required');
  }

  return errors;
}

/**
 * Helper: Validate rl_performance per invocation
 */
function validateInvocationRLPerformance(rlPerf) {
  const errors = [];

  if (!rlPerf) {
    return errors; // Optional but recommended
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

  // last_invocation must be ISO8601 if present
  if (rlPerf.last_invocation) {
    const dateRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;
    if (!dateRegex.test(rlPerf.last_invocation)) {
      errors.push('rl_performance.last_invocation must be ISO8601 format');
    }
  }

  return errors;
}

/**
 * Helper: Validate DS-STAR integration options
 */
function validateDSStarOptions(options) {
  const errors = [];

  if (!options) {
    return errors; // Optional
  }

  // validate_with_verifier must be boolean
  if (options.validate_with_verifier !== undefined && typeof options.validate_with_verifier !== 'boolean') {
    errors.push('ds_star_options.validate_with_verifier must be boolean');
  }

  // enable_auto_debug must be boolean
  if (options.enable_auto_debug !== undefined && typeof options.enable_auto_debug !== 'boolean') {
    errors.push('ds_star_options.enable_auto_debug must be boolean');
  }

  // max_refinement_rounds must be 1-20
  if (options.max_refinement_rounds !== undefined) {
    if (options.max_refinement_rounds < 1 || options.max_refinement_rounds > 20) {
      errors.push('ds_star_options.max_refinement_rounds must be 1-20');
    }
  }

  // early_stop_threshold must be 0-1
  if (options.early_stop_threshold !== undefined) {
    if (options.early_stop_threshold < 0 || options.early_stop_threshold > 1) {
      errors.push('ds_star_options.early_stop_threshold must be 0-1');
    }
  }

  return errors;
}

/**
 * Validate complete skill invocation contract
 */
function validateSkillInvocation(invocation) {
  const errors = [];

  // Validate context structure
  errors.push(...validateInvocationContext(invocation));

  // Validate expected-output
  errors.push(...validateExpectedOutput(invocation['expected-output']));

  // Validate rl_performance (optional)
  errors.push(...validateInvocationRLPerformance(invocation.rl_performance));

  // Validate DS-STAR options (optional)
  errors.push(...validateDSStarOptions(invocation.ds_star_options));

  // Validate timeout format if present
  if (invocation.timeout) {
    const timeoutPattern = /^\d+[smh]$/;
    if (!timeoutPattern.test(invocation.timeout)) {
      errors.push(`timeout "${invocation.timeout}" must match format Ns, Nm, or Nh`);
    }
  }

  return errors;
}

// Test Suite
describe('Skill Invocation v2 Contract Tests', () => {

  describe('Invocation Context Validation', () => {

    test('T003-AC1: validates invocation context structure', () => {
      const validContext = {
        'skill-id': 'domain/database-operations',
        'agent-id': 'database-specialist',
        'context-subset': ['data-model', 'constraints', 'schema-requirements'],
        when: 'database schema design is needed',
        'expected-output': {
          format: 'sql',
          schema: {}
        }
      };

      const errors = validateSkillInvocation(validContext);
      expect(errors).toHaveLength(0);
    });

    test('T003-AC1: fails when context fields missing', () => {
      const invalidContext = {};
      const errors = validateSkillInvocation(invalidContext);

      expect(errors.length).toBeGreaterThan(0);
      expect(errors.some(e => e.includes('skill-id'))).toBe(true);
      expect(errors.some(e => e.includes('agent-id'))).toBe(true);
      expect(errors.some(e => e.includes('context-subset'))).toBe(true);
      expect(errors.some(e => e.includes('when'))).toBe(true);
    });
  });

  describe('Expected Output Format Validation', () => {

    test('T003-AC2: validates expected-output format matching', () => {
      // Valid format
      const validOutput = { format: 'markdown' };
      expect(validateExpectedOutput(validOutput)).toHaveLength(0);

      // Missing format
      const invalidOutput = {};
      const errors = validateExpectedOutput(invalidOutput);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('format');
    });
  });

  describe('RL Performance Per Invocation', () => {

    test('T003-AC3: validates rl_performance metrics per invocation', () => {
      const validRLPerf = {
        invocation_count: 50,
        success_rate: 0.88,
        avg_tokens: 1200,
        last_invocation: '2026-01-13T10:00:00Z'
      };

      expect(validateInvocationRLPerformance(validRLPerf)).toHaveLength(0);
    });

    test('T003-AC3: validates rl_performance bounds', () => {
      // Invalid success_rate
      expect(validateInvocationRLPerformance({ success_rate: 1.5 }).length).toBeGreaterThan(0);

      // Invalid invocation_count
      expect(validateInvocationRLPerformance({ invocation_count: -1 }).length).toBeGreaterThan(0);

      // Invalid timestamp format
      expect(validateInvocationRLPerformance({ last_invocation: 'invalid' }).length).toBeGreaterThan(0);
    });
  });

  describe('DS-STAR Integration Options', () => {

    test('T003-AC4: validates DS-STAR integration options', () => {
      const validOptions = {
        validate_with_verifier: true,
        enable_auto_debug: true,
        max_refinement_rounds: 10,
        early_stop_threshold: 0.95
      };

      expect(validateDSStarOptions(validOptions)).toHaveLength(0);
    });

    test('T003-AC4: max_refinement_rounds must be 1-20', () => {
      expect(validateDSStarOptions({ max_refinement_rounds: 0 }).length).toBeGreaterThan(0);
      expect(validateDSStarOptions({ max_refinement_rounds: 21 }).length).toBeGreaterThan(0);
      expect(validateDSStarOptions({ max_refinement_rounds: 20 })).toHaveLength(0);
    });

    test('T003-AC4: early_stop_threshold must be 0-1', () => {
      expect(validateDSStarOptions({ early_stop_threshold: -0.1 }).length).toBeGreaterThan(0);
      expect(validateDSStarOptions({ early_stop_threshold: 1.1 }).length).toBeGreaterThan(0);
      expect(validateDSStarOptions({ early_stop_threshold: 0.95 })).toHaveLength(0);
    });
  });

  describe('Context Minimality', () => {

    test('T003-AC5: validates context minimality (max 10 fields)', () => {
      // Valid: 10 fields
      const valid10 = {
        'skill-id': 'domain/test-skill',
        'agent-id': 'database-specialist',
        'context-subset': Array(10).fill('field'),
        when: 'some valid condition text',
        'expected-output': { format: 'json' }
      };
      expect(validateInvocationContext(valid10)).toHaveLength(0);

      // Invalid: 11 fields
      const invalid11 = {
        'skill-id': 'domain/test-skill',
        'agent-id': 'database-specialist',
        'context-subset': Array(11).fill('field'),
        when: 'some valid condition text',
        'expected-output': { format: 'json' }
      };
      const errors = validateInvocationContext(invalid11);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('max is 10');
    });
  });

  describe('Agent Reference Validation', () => {

    test('T003-AC6: validates agent-id references consolidated agents', () => {
      // Valid consolidated agent
      const valid = {
        'skill-id': 'domain/test-skill',
        'agent-id': 'implementation-specialist',
        'context-subset': ['context'],
        when: 'valid condition text here'
      };
      expect(validateInvocationContext(valid)).toHaveLength(0);

      // Invalid: old agent name
      const invalid = {
        'skill-id': 'domain/test-skill',
        'agent-id': 'frontend-specialist', // Should be implementation-specialist
        'context-subset': ['context'],
        when: 'valid condition text here'
      };
      const errors = validateInvocationContext(invalid);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0]).toContain('not a valid consolidated agent');
    });
  });
});

// Export for use in other tests
module.exports = {
  validateSkillInvocation,
  validateInvocationContext,
  validateExpectedOutput,
  validateInvocationRLPerformance,
  validateDSStarOptions,
  VALID_CONSOLIDATED_AGENTS,
  VALID_DS_STAR_AGENTS
};
