# MCP Server Catalog

Reference tables for MCP server selection by category.

## Category 1: Core Infrastructure (Always Available)

| Tool | Purpose |
|------|---------|
| `mcp-find` | Search server catalog |
| `mcp-add` | Add servers dynamically |
| `mcp-config-set` | Configure servers |
| `mcp-exec` | Execute any tool |
| `code-mode` | Combine MCPs in JavaScript |
| `mcp-remove` | Remove servers |

## Category 2: Database & Backend

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| Supabase | `supabase` | `npx -y @anthropic-ai/mcp-supabase` |
| PostgreSQL | `postgres` | `npx -y @anthropic-ai/mcp-postgres` |
| SQLite | `SQLite` | `npx -y @anthropic-ai/mcp-sqlite` |
| Prisma | `prisma` | `npx -y @prisma/mcp-prisma` |
| Firebase | `firebase` | `npx -y @anthropic-ai/mcp-firebase` |
| MongoDB | `mongodb` | `npx -y @anthropic-ai/mcp-mongodb` |

## Category 3: Cloud & Deployment

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| AWS | `aws` or `aws-api` | `npx -y @anthropic-ai/mcp-aws` |
| GCP | `gcp` | `npx -y @anthropic-ai/mcp-gcp` |
| Azure | `azure` or `aks` | `npx -y @anthropic-ai/mcp-azure` |
| Vercel | `vercel` | `npx -y @anthropic-ai/mcp-vercel` |
| Netlify | `netlify` | `npx -y @anthropic-ai/mcp-netlify` |
| Docker | `docker` | `npx -y @anthropic-ai/mcp-docker` |

## Category 4: Browser & Testing

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| Browser automation | `browsermcp` | `npx -y @anthropic-ai/mcp-browsermcp` |
| Playwright | `playwright` | `npx -y @anthropic-ai/mcp-playwright` |
| Puppeteer | `puppeteer` | `npx -y @anthropic-ai/mcp-puppeteer` |

## Category 5: Search & Documentation

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| AI Search | `perplexity` | `npx -y @anthropic-ai/mcp-perplexity` |
| Brave Search | `brave-search` | `npx -y @anthropic-ai/mcp-brave-search` |
| GitHub | `github-official` | `npx -y @anthropic-ai/mcp-github` |
| Notion | `notion` | `npx -y @anthropic-ai/mcp-notion` |
| Confluence | `atlassian` | `npx -y @anthropic-ai/mcp-confluence` |
| Library docs | `context7` | `npx -y @anthropic-ai/mcp-context7` |

## Category 6: Communication & Collaboration

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| Slack | `slack` | `npx -y @anthropic-ai/mcp-slack` |
| Linear | `linear` | `npx -y @anthropic-ai/mcp-linear` |
| Jira | `atlassian` | `npx -y @anthropic-ai/mcp-jira` |
| Asana | `asana` | `npx -y @anthropic-ai/mcp-asana` |

## Domain-to-MCP Mapping

| Domain | Recommended MCPs |
|--------|------------------|
| **Backend** | aws/gcp/azure, postgres/supabase |
| **Frontend** | browsermcp, github-official, context7 |
| **Database** | postgres, supabase, firebase |
| **Testing** | browsermcp, playwright |
| **Security** | browsermcp, playwright |
| **Specification** | github-official, notion, linear |
| **DevOps** | aws/gcp/azure, docker |
| **Performance** | aws/gcp/azure, docker |
