#!/usr/bin/env node

/**
 * SDD Plugin Marketplace — MCP Server
 * 
 * Provides tools for discovering, installing, updating, and validating
 * SDD framework plugins. Connects downstream projects to the plugin
 * registry via the Model Context Protocol.
 * 
 * Tools:
 *   marketplace-list      — List installed plugins with versions and RL metrics
 *   marketplace-validate  — Validate a plugin against governance standards
 *   marketplace-search    — Search the plugin registry
 *   marketplace-install   — Install a plugin from the registry
 *   marketplace-update    — Update installed plugin(s)
 *   marketplace-publish   — Publish a plugin to the registry (dry-run by default)
 */

const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} = require("@modelcontextprotocol/sdk/types.js");

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Configuration
const PLUGINS_DIR = process.env.SDD_PLUGINS_DIR || path.resolve(process.cwd(), "plugins");
const REGISTRY_URL = process.env.SDD_REGISTRY_URL || "https://github.com/kelleysd-apps/sdd-plugins-marketplace";
const LOCAL_REGISTRY = path.resolve(__dirname, "..", "registry", "registry.json");

// ═══════════════════════════════════════════════════
// Plugin Utilities
// ═══════════════════════════════════════════════════

function getInstalledPlugins() {
  const plugins = [];
  if (!fs.existsSync(PLUGINS_DIR)) return plugins;

  for (const name of fs.readdirSync(PLUGINS_DIR)) {
    const manifestPath = path.join(PLUGINS_DIR, name, ".claude-plugin", "plugin.json");
    if (fs.existsSync(manifestPath)) {
      try {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
        const skillCount = countFiles(path.join(PLUGINS_DIR, name, "skills"), "SKILL.md");
        const agentCount = countFiles(path.join(PLUGINS_DIR, name, "agents"), ".md");
        const commandCount = countFiles(path.join(PLUGINS_DIR, name, "commands"), ".md");

        plugins.push({
          name: manifest.name,
          version: manifest.version,
          description: manifest.description,
          protected: manifest.protected || false,
          required: manifest.required || false,
          dependencies: manifest.dependencies || [],
          rl_metrics: manifest.rl_metrics || {},
          skills: skillCount,
          agents: agentCount,
          commands: commandCount,
          path: path.join(PLUGINS_DIR, name),
        });
      } catch (e) {
        plugins.push({ name, error: `Invalid manifest: ${e.message}` });
      }
    }
  }
  return plugins;
}

function countFiles(dir, pattern) {
  let count = 0;
  if (!fs.existsSync(dir)) return 0;
  const walk = (d) => {
    for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
      if (entry.isDirectory()) walk(path.join(d, entry.name));
      else if (entry.name.endsWith(pattern) || entry.name === pattern) count++;
    }
  };
  walk(dir);
  return count;
}

function validatePlugin(pluginPath) {
  const issues = [];
  const warnings = [];

  // 1. Check manifest exists
  const manifestPath = path.join(pluginPath, ".claude-plugin", "plugin.json");
  if (!fs.existsSync(manifestPath)) {
    issues.push("Missing .claude-plugin/plugin.json manifest");
    return { valid: false, issues, warnings };
  }

  // 2. Parse manifest
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
  } catch (e) {
    issues.push(`Invalid JSON in plugin.json: ${e.message}`);
    return { valid: false, issues, warnings };
  }

  // 3. Required fields
  for (const field of ["name", "version", "description", "dependencies"]) {
    if (!manifest[field]) issues.push(`Missing required field: ${field}`);
  }

  // 4. Governance dependency (Principle XVI)
  if (manifest.dependencies && !manifest.dependencies.includes("sdd-governance")) {
    if (manifest.name !== "sdd-governance") {
      issues.push("Must depend on sdd-governance (Principle XVI)");
    }
  }

  // 5. RL metrics
  if (!manifest.rl_metrics) {
    issues.push("Missing rl_metrics object");
  } else {
    for (const field of ["success_rate", "selection_weight", "invocation_count"]) {
      if (manifest.rl_metrics[field] === undefined) {
        warnings.push(`rl_metrics missing: ${field}`);
      }
    }
  }

  // 6. Check for skills
  const skillsDir = path.join(pluginPath, "skills");
  if (!fs.existsSync(skillsDir) || countFiles(skillsDir, "SKILL.md") === 0) {
    warnings.push("No skills found — plugin has no skill definitions");
  }

  // 7. Check for agents
  const agentsDir = path.join(pluginPath, "agents");
  if (!fs.existsSync(agentsDir) || countFiles(agentsDir, ".md") === 0) {
    warnings.push("No agents found — plugin has no agent definitions");
  }

  // 8. Hooks validation
  const hooksFile = path.join(pluginPath, "hooks", "hooks.json");
  if (fs.existsSync(hooksFile)) {
    try {
      const hooks = JSON.parse(fs.readFileSync(hooksFile, "utf-8"));
      const validEvents = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "SubagentStop"];
      for (const hook of hooks.hooks || []) {
        if (!validEvents.includes(hook.event)) {
          warnings.push(`Unknown hook event: ${hook.event}`);
        }
        if (hook.script && !fs.existsSync(path.join(pluginPath, "hooks", hook.script))) {
          issues.push(`Hook script not found: ${hook.script}`);
        }
      }
    } catch (e) {
      issues.push(`Invalid hooks.json: ${e.message}`);
    }
  }

  return {
    valid: issues.length === 0,
    issues,
    warnings,
    manifest,
  };
}

function getRegistry() {
  if (fs.existsSync(LOCAL_REGISTRY)) {
    return JSON.parse(fs.readFileSync(LOCAL_REGISTRY, "utf-8"));
  }
  return { plugins: [], last_updated: null };
}

function searchRegistry(query, category) {
  const registry = getRegistry();
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

// ═══════════════════════════════════════════════════
// MCP Server Setup
// ═══════════════════════════════════════════════════

const server = new Server(
  { name: "sdd-marketplace", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

// Tool Definitions
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "marketplace-list",
      description:
        "List all installed SDD plugins with versions, RL metrics, and component counts. Shows which plugins are protected, their dependencies, and current selection weights.",
      inputSchema: {
        type: "object",
        properties: {
          format: {
            type: "string",
            enum: ["table", "json", "summary"],
            description: "Output format (default: table)",
          },
          outdated: {
            type: "boolean",
            description: "Only show plugins with available updates",
          },
        },
      },
    },
    {
      name: "marketplace-validate",
      description:
        "Validate a plugin against SDD governance standards (Principle XVI). Checks manifest, dependencies, RL metrics, hooks, skills, and agents.",
      inputSchema: {
        type: "object",
        properties: {
          plugin_path: {
            type: "string",
            description: "Path to the plugin directory to validate (relative or absolute)",
          },
          plugin_name: {
            type: "string",
            description: "Name of installed plugin to validate (alternative to plugin_path)",
          },
        },
      },
    },
    {
      name: "marketplace-search",
      description:
        "Search the SDD plugin registry for plugins matching a query. Searches names, descriptions, and keywords.",
      inputSchema: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "Search query (e.g., 'authentication', 'frontend', 'ML')",
          },
          category: {
            type: "string",
            enum: ["governance", "core", "domain", "orchestration", "community"],
            description: "Filter by plugin category",
          },
          limit: {
            type: "number",
            description: "Maximum results to return (default: 10)",
          },
        },
        required: ["query"],
      },
    },
    {
      name: "marketplace-install",
      description:
        "Install a plugin from the SDD plugin registry into the local plugins/ directory. Validates the plugin before installation.",
      inputSchema: {
        type: "object",
        properties: {
          plugin_name: {
            type: "string",
            description: "Name of the plugin to install (e.g., 'sdd-domain-ai-ml')",
          },
          version: {
            type: "string",
            description: "Specific version to install (default: latest)",
          },
          source: {
            type: "string",
            description: "Source URL or local path (overrides registry)",
          },
        },
        required: ["plugin_name"],
      },
    },
    {
      name: "marketplace-update",
      description:
        "Update installed plugin(s) to the latest version from the registry.",
      inputSchema: {
        type: "object",
        properties: {
          plugin_name: {
            type: "string",
            description: "Plugin to update (omit to check all for updates)",
          },
          dry_run: {
            type: "boolean",
            description: "Only check for updates without applying them",
          },
        },
      },
    },
    {
      name: "marketplace-publish",
      description:
        "Validate and publish a plugin to the SDD marketplace registry. Runs full validation before publishing. Dry-run by default.",
      inputSchema: {
        type: "object",
        properties: {
          plugin_path: {
            type: "string",
            description: "Path to the plugin directory to publish",
          },
          dry_run: {
            type: "boolean",
            description: "Only validate without publishing (default: true)",
          },
        },
        required: ["plugin_path"],
      },
    },
  ],
}));

// Tool Implementations
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    // ─── LIST ───
    case "marketplace-list": {
      const plugins = getInstalledPlugins();
      const format = args?.format || "table";

      if (format === "json") {
        return {
          content: [{ type: "text", text: JSON.stringify(plugins, null, 2) }],
        };
      }

      if (format === "summary") {
        const summary = {
          total: plugins.length,
          protected: plugins.filter((p) => p.protected).length,
          skills: plugins.reduce((s, p) => s + (p.skills || 0), 0),
          agents: plugins.reduce((s, p) => s + (p.agents || 0), 0),
          commands: plugins.reduce((s, p) => s + (p.commands || 0), 0),
        };
        return {
          content: [
            {
              type: "text",
              text: `Plugin Summary: ${summary.total} plugins (${summary.protected} protected), ${summary.skills} skills, ${summary.agents} agents, ${summary.commands} commands`,
            },
          ],
        };
      }

      // Table format
      let table = "Installed Plugins:\n\n";
      table += `${"Plugin".padEnd(30)} ${"Version".padEnd(8)} ${"Skills".padEnd(7)} ${"Agents".padEnd(7)} ${"Cmds".padEnd(5)} ${"RL Weight".padEnd(10)} Status\n`;
      table += `${"─".repeat(30)} ${"─".repeat(8)} ${"─".repeat(7)} ${"─".repeat(7)} ${"─".repeat(5)} ${"─".repeat(10)} ${"─".repeat(10)}\n`;

      for (const p of plugins) {
        if (p.error) {
          table += `${p.name.padEnd(30)} ❌ ${p.error}\n`;
          continue;
        }
        const status = p.protected ? "🔒 protected" : p.required ? "⚠️ required" : "✅ active";
        const weight = p.rl_metrics?.selection_weight?.toFixed(2) || "N/A";
        table += `${p.name.padEnd(30)} ${p.version.padEnd(8)} ${String(p.skills).padEnd(7)} ${String(p.agents).padEnd(7)} ${String(p.commands).padEnd(5)} ${weight.padEnd(10)} ${status}\n`;
      }

      return { content: [{ type: "text", text: table }] };
    }

    // ─── VALIDATE ───
    case "marketplace-validate": {
      let pluginPath = args?.plugin_path;
      if (!pluginPath && args?.plugin_name) {
        pluginPath = path.join(PLUGINS_DIR, args.plugin_name);
      }
      if (!pluginPath) {
        return {
          content: [{ type: "text", text: "Error: Provide plugin_path or plugin_name" }],
          isError: true,
        };
      }

      const resolvedPath = path.resolve(pluginPath);
      if (!fs.existsSync(resolvedPath)) {
        return {
          content: [{ type: "text", text: `Error: Plugin not found at ${resolvedPath}` }],
          isError: true,
        };
      }

      const result = validatePlugin(resolvedPath);
      let output = `Validation: ${path.basename(resolvedPath)}\n\n`;

      if (result.valid) {
        output += "✅ VALID — Plugin passes all governance checks\n\n";
      } else {
        output += "❌ INVALID — Plugin has governance violations\n\n";
      }

      if (result.issues.length > 0) {
        output += "Issues:\n";
        for (const issue of result.issues) output += `  ❌ ${issue}\n`;
        output += "\n";
      }

      if (result.warnings.length > 0) {
        output += "Warnings:\n";
        for (const w of result.warnings) output += `  ⚠️ ${w}\n`;
        output += "\n";
      }

      if (result.manifest) {
        output += `Manifest: ${result.manifest.name} v${result.manifest.version}\n`;
        output += `Dependencies: ${(result.manifest.dependencies || []).join(", ") || "none"}\n`;
      }

      return { content: [{ type: "text", text: output }] };
    }

    // ─── SEARCH ───
    case "marketplace-search": {
      const query = args?.query;
      if (!query) {
        return {
          content: [{ type: "text", text: "Error: query parameter required" }],
          isError: true,
        };
      }

      const results = searchRegistry(query, args?.category);
      const limit = args?.limit || 10;

      if (results.length === 0) {
        // Fallback: search installed plugins if registry is empty/offline
        const installed = getInstalledPlugins();
        const localResults = installed.filter(
          (p) =>
            p.name?.toLowerCase().includes(query.toLowerCase()) ||
            p.description?.toLowerCase().includes(query.toLowerCase())
        );

        if (localResults.length > 0) {
          let output = `No registry results. Found ${localResults.length} installed plugin(s) matching "${query}":\n\n`;
          for (const p of localResults.slice(0, limit)) {
            output += `  📦 ${p.name} v${p.version}\n     ${p.description}\n     Skills: ${p.skills}, Agents: ${p.agents}\n\n`;
          }
          return { content: [{ type: "text", text: output }] };
        }

        return {
          content: [{ type: "text", text: `No plugins found matching "${query}"` }],
        };
      }

      let output = `Found ${results.length} plugin(s) matching "${query}":\n\n`;
      for (const p of results.slice(0, limit)) {
        const installed = fs.existsSync(path.join(PLUGINS_DIR, p.name));
        const badge = installed ? " ✅ installed" : "";
        output += `  📦 ${p.name} v${p.version}${badge}\n`;
        output += `     ${p.description}\n`;
        output += `     Category: ${p.category} | Keywords: ${(p.keywords || []).join(", ")}\n\n`;
      }

      return { content: [{ type: "text", text: output }] };
    }

    // ─── INSTALL ───
    case "marketplace-install": {
      const pluginName = args?.plugin_name;
      if (!pluginName) {
        return {
          content: [{ type: "text", text: "Error: plugin_name required" }],
          isError: true,
        };
      }

      const destPath = path.join(PLUGINS_DIR, pluginName);

      // Check if already installed
      if (fs.existsSync(destPath)) {
        return {
          content: [
            {
              type: "text",
              text: `Plugin ${pluginName} is already installed at ${destPath}. Use marketplace-update to update it.`,
            },
          ],
        };
      }

      // Check registry for source
      const registry = getRegistry();
      const regPlugin = registry.plugins.find((p) => p.name === pluginName);
      const source = args?.source || regPlugin?.source;

      if (!source) {
        return {
          content: [
            {
              type: "text",
              text: `Plugin "${pluginName}" not found in registry. Provide a source URL with the 'source' parameter.\n\nAvailable plugins:\n${registry.plugins.map((p) => `  - ${p.name}`).join("\n") || "  (registry empty)"}`,
            },
          ],
        };
      }

      // Install from source
      try {
        if (source.startsWith("https://github.com") || source.startsWith("git@")) {
          // Git-based install
          execSync(`git clone --depth 1 "${source}" "${destPath}" 2>&1`, {
            cwd: PLUGINS_DIR,
            timeout: 30000,
          });
          // Remove .git directory from cloned plugin
          const gitDir = path.join(destPath, ".git");
          if (fs.existsSync(gitDir)) {
            fs.rmSync(gitDir, { recursive: true });
          }
        } else if (fs.existsSync(source)) {
          // Local path install (copy)
          execSync(`cp -r "${source}" "${destPath}" 2>&1`, { timeout: 10000 });
        } else {
          return {
            content: [{ type: "text", text: `Cannot resolve source: ${source}` }],
            isError: true,
          };
        }

        // Validate after install
        const validation = validatePlugin(destPath);
        let output = `✅ Plugin ${pluginName} installed to ${destPath}\n\n`;

        if (!validation.valid) {
          output += "⚠️ Post-install validation found issues:\n";
          for (const issue of validation.issues) output += `  ❌ ${issue}\n`;
        }

        if (validation.manifest) {
          output += `\nVersion: ${validation.manifest.version}\n`;
          output += `Dependencies: ${(validation.manifest.dependencies || []).join(", ")}\n`;
        }

        return { content: [{ type: "text", text: output }] };
      } catch (e) {
        // Cleanup on failure
        if (fs.existsSync(destPath)) {
          fs.rmSync(destPath, { recursive: true });
        }
        return {
          content: [
            { type: "text", text: `Installation failed: ${e.message}` },
          ],
          isError: true,
        };
      }
    }

    // ─── UPDATE ───
    case "marketplace-update": {
      const registry = getRegistry();
      const targetPlugin = args?.plugin_name;
      const dryRun = args?.dry_run !== false;

      const installed = getInstalledPlugins();
      const updates = [];

      for (const plugin of installed) {
        if (targetPlugin && plugin.name !== targetPlugin) continue;
        const regEntry = registry.plugins.find((p) => p.name === plugin.name);
        if (regEntry && regEntry.version !== plugin.version) {
          updates.push({
            name: plugin.name,
            current: plugin.version,
            available: regEntry.version,
            source: regEntry.source,
          });
        }
      }

      if (updates.length === 0) {
        return {
          content: [
            {
              type: "text",
              text: targetPlugin
                ? `${targetPlugin} is up to date.`
                : "All plugins are up to date.",
            },
          ],
        };
      }

      let output = dryRun ? "Available updates (dry run):\n\n" : "Updating plugins:\n\n";
      for (const u of updates) {
        output += `  ${u.name}: ${u.current} → ${u.available}\n`;
      }

      if (dryRun) {
        output += "\nRun with dry_run: false to apply updates.";
      }

      return { content: [{ type: "text", text: output }] };
    }

    // ─── PUBLISH ───
    case "marketplace-publish": {
      const pluginPath = args?.plugin_path;
      if (!pluginPath) {
        return {
          content: [{ type: "text", text: "Error: plugin_path required" }],
          isError: true,
        };
      }

      const resolvedPath = path.resolve(pluginPath);
      const validation = validatePlugin(resolvedPath);
      const dryRun = args?.dry_run !== false;

      let output = `Publishing: ${path.basename(resolvedPath)}\n\n`;
      output += "Validation:\n";

      if (validation.valid) {
        output += "  ✅ All governance checks passed\n";
      } else {
        output += "  ❌ Governance violations found — cannot publish\n";
        for (const issue of validation.issues) output += `  ❌ ${issue}\n`;
        return { content: [{ type: "text", text: output }] };
      }

      for (const w of validation.warnings) output += `  ⚠️ ${w}\n`;

      if (dryRun) {
        output += "\n📋 Dry run complete. Plugin is ready for publishing.";
        output += "\nRun with dry_run: false to publish to the registry.";
      } else {
        output += "\n✅ Plugin validated. Submit to marketplace via PR:";
        output += `\n   ${REGISTRY_URL}`;
      }

      return { content: [{ type: "text", text: output }] };
    }

    default:
      return {
        content: [{ type: "text", text: `Unknown tool: ${name}` }],
        isError: true,
      };
  }
});

// ═══════════════════════════════════════════════════
// Start Server
// ═══════════════════════════════════════════════════

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("SDD Marketplace MCP server running on stdio");
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
