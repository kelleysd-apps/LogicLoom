/**
 * SDD Marketplace MCP Server — Unit Tests
 * 
 * Tests the core utility functions without requiring MCP protocol.
 * Uses Node.js built-in test runner (node --test).
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");

// Test helpers
const FIXTURES_DIR = path.join(__dirname, "fixtures");
const PLUGINS_DIR = path.resolve(__dirname, "..", "..", "..", "..", "plugins");

// ═══════════════════════════════════════════════════
// Registry Tests
// ═══════════════════════════════════════════════════

describe("Registry", () => {
  const registryPath = path.resolve(__dirname, "..", "..", "registry", "registry.json");

  it("registry.json exists and is valid JSON", () => {
    assert.ok(fs.existsSync(registryPath), "registry.json should exist");
    const data = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    assert.ok(data.plugins, "should have plugins array");
    assert.ok(data.plugins.length >= 13, `should have 13+ plugins, got ${data.plugins.length}`);
  });

  it("all registry entries have required fields", () => {
    const data = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    for (const plugin of data.plugins) {
      assert.ok(plugin.name, `plugin missing name`);
      assert.ok(plugin.version, `${plugin.name} missing version`);
      assert.ok(plugin.description, `${plugin.name} missing description`);
      assert.ok(plugin.category, `${plugin.name} missing category`);
      assert.ok(plugin.source, `${plugin.name} missing source`);
      assert.ok(Array.isArray(plugin.dependencies), `${plugin.name} dependencies should be array`);
    }
  });

  it("all registry sources have repo and path fields", () => {
    const data = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    for (const plugin of data.plugins) {
      assert.ok(typeof plugin.source === "object", `${plugin.name}: source should be object`);
      assert.ok(plugin.source.repo, `${plugin.name}: source.repo missing`);
      assert.ok(plugin.source.path, `${plugin.name}: source.path missing`);
      assert.ok(plugin.source.type, `${plugin.name}: source.type missing`);
      assert.ok(
        plugin.source.path.startsWith("plugins/"),
        `${plugin.name}: source.path should start with plugins/`
      );
    }
  });

  it("governance plugin is marked as protected", () => {
    const data = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    const gov = data.plugins.find((p) => p.name === "sdd-governance");
    assert.ok(gov, "sdd-governance should be in registry");
    assert.strictEqual(gov.protected, true, "should be protected");
    assert.strictEqual(gov.category, "governance", "should be governance category");
  });

  it("core/domain plugins depend on sdd-governance", () => {
    const data = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    const infraPlugins = ["sdd-governance", "sdd-memory", "sdd-orchestrator-hook"];
    for (const plugin of data.plugins) {
      if (infraPlugins.includes(plugin.name)) continue;
      assert.ok(
        plugin.dependencies.includes("sdd-governance"),
        `${plugin.name} should depend on sdd-governance`
      );
    }
  });

  it("registry has correct category distribution", () => {
    const data = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    const cats = {};
    for (const p of data.plugins) {
      cats[p.category] = (cats[p.category] || 0) + 1;
    }
    assert.strictEqual(cats.governance, 1, "should have 1 governance plugin");
    assert.ok(cats.core >= 4, `should have 4+ core plugins, got ${cats.core}`);
    assert.ok(cats.domain >= 7, `should have 7+ domain plugins, got ${cats.domain}`);
    assert.ok(cats.orchestration >= 1, `should have 1+ orchestration plugins, got ${cats.orchestration}`);
  });

  it("template plugin is excluded from registry", () => {
    const data = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    const template = data.plugins.find((p) => p.name === "sdd-domain-CHANGEME");
    assert.strictEqual(template, undefined, "template should not be in registry");
  });
});

// ═══════════════════════════════════════════════════
// Plugin Validation Tests (against actual plugins/)
// ═══════════════════════════════════════════════════

describe("Plugin Validation (live plugins/)", () => {
  it("all plugins have valid manifests", () => {
    for (const name of fs.readdirSync(PLUGINS_DIR)) {
      const manifestPath = path.join(PLUGINS_DIR, name, ".claude-plugin", "plugin.json");
      if (!fs.existsSync(manifestPath)) continue;

      const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
      assert.ok(manifest.name, `${name}: missing name`);
      assert.ok(manifest.version, `${name}: missing version`);
      // governance is the root plugin (no dependencies), all others must have dependencies
      if (name !== "sdd-governance") {
        assert.ok(manifest.dependencies, `${name}: missing dependencies`);
      }
    }
  });

  it("all plugins have rl_metrics", () => {
    for (const name of fs.readdirSync(PLUGINS_DIR)) {
      const manifestPath = path.join(PLUGINS_DIR, name, ".claude-plugin", "plugin.json");
      if (!fs.existsSync(manifestPath)) continue;

      const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
      assert.ok(manifest.rl_metrics, `${name}: missing rl_metrics`);
      assert.ok(
        typeof manifest.rl_metrics.success_rate === "number",
        `${name}: rl_metrics.success_rate should be number`
      );
      assert.ok(
        typeof manifest.rl_metrics.selection_weight === "number",
        `${name}: rl_metrics.selection_weight should be number`
      );
    }
  });

  it("governance plugin is protected and required", () => {
    const manifestPath = path.join(PLUGINS_DIR, "sdd-governance", ".claude-plugin", "plugin.json");
    const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
    assert.strictEqual(manifest.protected, true);
    assert.strictEqual(manifest.required, true);
  });

  it("core/domain plugins depend on sdd-governance", () => {
    const infraPlugins = ["sdd-governance", "sdd-memory", "sdd-orchestrator-hook"];
    for (const name of fs.readdirSync(PLUGINS_DIR)) {
      if (infraPlugins.includes(name)) continue;
      const manifestPath = path.join(PLUGINS_DIR, name, ".claude-plugin", "plugin.json");
      if (!fs.existsSync(manifestPath)) continue;

      const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
      assert.ok(
        manifest.dependencies.includes("sdd-governance"),
        `${name}: should depend on sdd-governance`
      );
    }
  });

  it("plugins with hooks have valid hooks.json", () => {
    const validEvents = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "SubagentStop"];

    for (const name of fs.readdirSync(PLUGINS_DIR)) {
      const hooksPath = path.join(PLUGINS_DIR, name, "hooks", "hooks.json");
      if (!fs.existsSync(hooksPath)) continue;

      const hooks = JSON.parse(fs.readFileSync(hooksPath, "utf-8"));
      assert.ok(Array.isArray(hooks.hooks), `${name}: hooks should be array`);

      for (const hook of hooks.hooks) {
        assert.ok(validEvents.includes(hook.event), `${name}: invalid hook event '${hook.event}'`);
      }
    }
  });
});

// ═══════════════════════════════════════════════════
// Registry Search Tests
// ═══════════════════════════════════════════════════

describe("Registry Search", () => {
  const registryPath = path.resolve(__dirname, "..", "..", "registry", "registry.json");

  function search(query, category) {
    const registry = JSON.parse(fs.readFileSync(registryPath, "utf-8"));
    const q = query.toLowerCase();
    return registry.plugins.filter((p) => {
      const matchesQuery =
        p.name.toLowerCase().includes(q) ||
        p.description.toLowerCase().includes(q) ||
        (p.keywords || []).some((k) => k.toLowerCase().includes(q));
      const matchesCategory = !category || p.category === category;
      return matchesQuery && matchesCategory;
    });
  }

  it("search by name finds exact plugin", () => {
    const results = search("sdd-governance");
    assert.ok(results.length >= 1);
    assert.strictEqual(results[0].name, "sdd-governance");
  });

  it("search by domain keyword finds domain plugins", () => {
    const results = search("frontend");
    assert.ok(results.length >= 1);
    assert.ok(results.some((r) => r.name.includes("frontend")));
  });

  it("search by category filters correctly", () => {
    const results = search("sdd", "core");
    assert.ok(results.length >= 4);
    assert.ok(results.every((r) => r.category === "core"));
  });

  it("search for non-existent returns empty", () => {
    const results = search("nonexistentpluginxyz");
    assert.strictEqual(results.length, 0);
  });
});

// ═══════════════════════════════════════════════════
// MCP Configuration Tests
// ═══════════════════════════════════════════════════

describe("MCP Configuration", () => {
  const mcpPath = path.resolve(__dirname, "..", "..", "..", "..", ".mcp.json");

  it(".mcp.json includes sdd-marketplace server", () => {
    const mcp = JSON.parse(fs.readFileSync(mcpPath, "utf-8"));
    assert.ok(mcp.mcpServers["sdd-marketplace"], "sdd-marketplace should be configured");
  });

  it("marketplace server points to correct entrypoint", () => {
    const mcp = JSON.parse(fs.readFileSync(mcpPath, "utf-8"));
    const server = mcp.mcpServers["sdd-marketplace"];
    assert.strictEqual(server.command, "node");
    assert.ok(server.args[0].includes("sdd-marketplace"));
  });

  it("marketplace server has SDD_PLUGINS_DIR env", () => {
    const mcp = JSON.parse(fs.readFileSync(mcpPath, "utf-8"));
    const server = mcp.mcpServers["sdd-marketplace"];
    assert.ok(server.env?.SDD_PLUGINS_DIR, "should have SDD_PLUGINS_DIR");
  });
});
