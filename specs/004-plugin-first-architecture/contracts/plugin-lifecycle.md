# Contract: Plugin Lifecycle

## Install Plugin
```
POST /plugin/install
Input:  { name: string, marketplace?: string }
Output: { success: boolean, plugin: PluginManifest, message: string }
Errors: 
  - PLUGIN_NOT_FOUND: Plugin not in marketplace
  - DEPENDENCY_MISSING: Required plugin not installed
  - ALREADY_INSTALLED: Plugin already present
```

## Enable Plugin
```
POST /plugin/enable
Input:  { name: string }
Output: { success: boolean, message: string }
Errors:
  - PLUGIN_NOT_FOUND: Plugin not installed
  - ALREADY_ENABLED: Plugin already active
Side Effects: Plugin commands, agents, skills, hooks become active
```

## Disable Plugin
```
POST /plugin/disable
Input:  { name: string }
Output: { success: boolean, message: string }
Errors:
  - PLUGIN_NOT_FOUND: Plugin not installed
  - GOVERNANCE_PROTECTED: Cannot disable sdd-governance
  - DEPENDENCY_CONFLICT: Other plugins depend on this one
Side Effects: Plugin commands, agents, skills, hooks become inactive
```

## Update Plugin
```
POST /plugin/update
Input:  { name: string, version?: string }
Output: { success: boolean, old_version: string, new_version: string }
Errors:
  - PLUGIN_NOT_FOUND: Plugin not installed
  - NO_UPDATE_AVAILABLE: Already at latest version
  - VERSION_NOT_FOUND: Specified version doesn't exist
```

## List Plugins
```
GET /plugin/list
Input:  { filter?: "enabled" | "disabled" | "all" }
Output: { plugins: PluginManifest[], count: number }
```
