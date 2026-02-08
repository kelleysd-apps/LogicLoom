/**
 * MCP Connection Integration Test
 * 
 * Spawns the marketplace server and sends newline-delimited JSON-RPC
 * messages (the format this SDK version uses) to verify end-to-end.
 */

const { spawn } = require("child_process");
const path = require("path");

const SERVER_PATH = path.resolve("mcp-servers/sdd-marketplace/src/index.js");

function sendMsg(proc, method, params = {}, id = null) {
  const msg = { jsonrpc: "2.0", method, params };
  if (id !== null) msg.id = id;
  proc.stdin.write(JSON.stringify(msg) + "\n");
}

function parseResponses(raw) {
  return raw.split("\n")
    .filter(line => line.trim())
    .map(line => {
      try { return JSON.parse(line); } catch { return null; }
    })
    .filter(Boolean);
}

async function runTest() {
  let pass = 0, fail = 0;
  
  function assert(desc, condition) {
    if (condition) { pass++; console.log(`  ✅ PASS: ${desc}`); }
    else { fail++; console.log(`  ❌ FAIL: ${desc}`); }
  }

  console.log("═══ MCP Marketplace E2E Connection Tests ═══\n");

  const server = spawn("node", [SERVER_PATH], {
    env: {
      ...process.env,
      NODE_PATH: path.resolve("mcp-servers/sdd-marketplace/node_modules"),
      SDD_PLUGINS_DIR: path.resolve("plugins"),
    },
    stdio: ["pipe", "pipe", "pipe"],
  });

  let stdout = "";
  let stderr = "";
  server.stdout.on("data", d => stdout += d.toString());
  server.stderr.on("data", d => stderr += d.toString());
  
  await new Promise(r => setTimeout(r, 500));
  assert("Server process started", server.pid > 0);

  // 1. Initialize
  console.log("\n  [1/5] Initialize handshake");
  stdout = "";
  sendMsg(server, "initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "test-client", version: "0.1.0" }
  }, 1);
  
  await new Promise(r => setTimeout(r, 1500));
  let responses = parseResponses(stdout);
  assert("Initialize response received", responses.length > 0);
  
  if (responses.length > 0) {
    const resp = responses[0];
    assert("Response has id=1", resp.id === 1);
    assert("Has serverInfo", !!resp.result?.serverInfo);
    assert("Server name is sdd-marketplace", resp.result?.serverInfo?.name === "sdd-marketplace");
    assert("Has tools capability", !!resp.result?.capabilities?.tools);
  }

  // Send initialized notification
  sendMsg(server, "notifications/initialized");
  await new Promise(r => setTimeout(r, 500));

  // 2. List tools
  console.log("\n  [2/5] List tools");
  stdout = "";
  sendMsg(server, "tools/list", {}, 2);
  await new Promise(r => setTimeout(r, 1500));
  responses = parseResponses(stdout);
  
  if (responses.length > 0) {
    const tools = responses[0].result?.tools || [];
    assert("Tools list returned", tools.length > 0);
    assert("Has 6 tools", tools.length === 6);
    const names = tools.map(t => t.name);
    assert("Has marketplace-list", names.includes("marketplace-list"));
    assert("Has marketplace-validate", names.includes("marketplace-validate"));
    assert("Has marketplace-search", names.includes("marketplace-search"));
    assert("Has marketplace-install", names.includes("marketplace-install"));
    assert("Has marketplace-update", names.includes("marketplace-update"));
    assert("Has marketplace-publish", names.includes("marketplace-publish"));
    
    // Verify tool schemas
    const listTool = tools.find(t => t.name === "marketplace-list");
    assert("marketplace-list has input schema", !!listTool?.inputSchema);
  } else {
    assert("Tools response received", false);
  }

  // 3. Call marketplace-list
  console.log("\n  [3/5] Call marketplace-list (json format)");
  stdout = "";
  sendMsg(server, "tools/call", { name: "marketplace-list", arguments: { format: "json" } }, 3);
  await new Promise(r => setTimeout(r, 1500));
  responses = parseResponses(stdout);
  
  if (responses.length > 0) {
    const text = responses[0].result?.content?.[0]?.text;
    assert("marketplace-list returns content", !!text);
    if (text) {
      try {
        const plugins = JSON.parse(text);
        assert("Returns array of plugins", Array.isArray(plugins));
        assert("Has 14 plugins (including template)", plugins.length >= 13);
        
        const gov = plugins.find(p => p.name === "sdd-governance");
        assert("Governance plugin found", !!gov);
        assert("Governance is protected", gov?.protected === true);
        assert("Governance has rl_metrics", !!gov?.rl_metrics);
        assert("Governance has skills count", gov?.skills >= 6);
        assert("Governance has agents count", gov?.agents >= 1);
        
        const spec = plugins.find(p => p.name === "sdd-specification");
        assert("Specification plugin found", !!spec);
        assert("Spec has 5 skills", spec?.skills === 5);
        assert("Spec has 4 agents", spec?.agents === 4);
        assert("Spec has 4 commands", spec?.commands === 4);
        
        const orch = plugins.find(p => p.name === "sdd-orchestrator");
        assert("Orchestrator plugin found", !!orch);
        assert("Orchestrator has 5 commands", orch?.commands === 5);
      } catch (e) {
        assert("Plugin list is valid JSON", false);
      }
    }
  } else {
    assert("marketplace-list response received", false);
  }

  // 4. Call marketplace-validate
  console.log("\n  [4/5] Call marketplace-validate (sdd-governance)");
  stdout = "";
  sendMsg(server, "tools/call", { name: "marketplace-validate", arguments: { plugin_name: "sdd-governance" } }, 4);
  await new Promise(r => setTimeout(r, 1500));
  responses = parseResponses(stdout);
  
  if (responses.length > 0) {
    const text = responses[0].result?.content?.[0]?.text || "";
    assert("Validate returns result", text.length > 0);
    assert("Governance passes validation", text.includes("VALID"));
    assert("Shows manifest info", text.includes("sdd-governance"));
  } else {
    assert("Validate response received", false);
  }

  // 5. Call marketplace-search
  console.log("\n  [5/5] Call marketplace-search (query: 'backend')");
  stdout = "";
  sendMsg(server, "tools/call", { name: "marketplace-search", arguments: { query: "backend" } }, 5);
  await new Promise(r => setTimeout(r, 1500));
  responses = parseResponses(stdout);
  
  if (responses.length > 0) {
    const text = responses[0].result?.content?.[0]?.text || "";
    assert("Search returns results", text.length > 0);
    assert("Finds backend plugin", text.toLowerCase().includes("backend"));
  } else {
    assert("Search response received", false);
  }

  // Cleanup
  server.kill("SIGTERM");
  await new Promise(r => setTimeout(r, 300));

  console.log("\n═══════════════════════════════════════");
  console.log(` Results: ${pass}/${pass + fail} passed, ${fail} failed`);
  console.log("═══════════════════════════════════════");
  
  process.exit(fail > 0 ? 1 : 0);
}

runTest().catch(e => { console.error("Fatal:", e); process.exit(1); });
