---
# 📄 Product Requirements Document (PRD)
## Project Name: Autonomous AI Agent Platform (ZippyAgent)

---

## 🔍 Overview
ZippyAgent is a full-stack platform designed to let users deploy self-orchestrating, intelligent AI agents to brainstorm, plan, build, deploy, and optimize digital businesses (SaaS, APIs, marketplaces, tools, PWA apps) entirely from a local or hybrid cloud+local agent network. It supports containerized agent runtime (via LXC on Proxmox or Docker), local LLM access via Ollama, and external APIs from ChatGPT, Claude, and Grok.

Users will interface via a modern PWA website that:
- Visualizes all active agent tasks, services, businesses
- Allows creation of new goal prompts ("launch me a SaaS that sells downloadable AI agents")
- Displays agent performance, task flows, scoring and retry trees
- Provides access to deployable websites/tools built by the agent network

---

## 🎯 Goals
- Allow autonomous AI agents to launch and iterate on digital business ideas
- Track agent performance, learning, and result scoring
- Enable visual interface for observing and managing agents and services
- Allow configuration of local/remote LLM backends
- Support deployment to LXC, Docker, and VMs

---

## 🔨 Features
### MVP Scope:
- [x] User auth & dashboard (token-based)
- [x] Start new business task prompt
- [ ] Display active agent clusters by business goal
- [ ] Show agent performance & audit trails
- [ ] Deploy preview UI & code of websites/services
- [ ] Assign and configure LLM API keys or connect to Ollama
- [ ] UI for container status (LXC/Docker)
- [ ] Manual override or prompt injection
- [ ] Agent skill tagging (e.g., Python, SEO, Web Dev)
- [ ] Prompt templates for common tasks (e.g., launch blog + CMS)

### V2 Goals:
- [ ] White-label subdomains and PWA generation per project
- [ ] End-user access portals for SaaS products created
- [ ] Payment gateway module for monetization APIs
- [ ] Real-time monitoring graphs (Prometheus/Grafana integrations)

---

## 🌐 Frontend Tech Stack
- React + Next.js
- TailwindCSS + ShadCN
- Framer Motion (transitions)
- Heroicons / Lucide for UI
- SWR + Axios for API calls
- PWA support

## 🧠 Backend Stack
- Node.js (or Python FastAPI alt)
- PostgreSQL (agent memory, project logs, config store)
- Redis (task queues, RAG ranking)
- Ollama (local LLM) + Optional GPT/Claude APIs
- LXC CLI wrappers (or Docker CLI API)

---

## 🗂 Folder Structure `/`
```
/docs
  |- PRD.md
  |- TECH_SPEC.md
  |- UI_DESIGN.md
  |- DATA_MODEL.md
  |- TODO.md
/public
/src
  |- /components
  |- /pages
  |- /styles
  |- /lib
/server
  |- /agents
  |- /orchestrator
  |- /db
  |- /llm
  |- /utils
```

---

# ✅ TODO Features Map

## Core Website Pages
- [ ] `/dashboard`: Project summary
- [ ] `/agent-center`: View running agent chains
- [ ] `/projects/[id]`: Live agent UI + service logs
- [ ] `/prompt-launcher`: Submit new goal/task
- [ ] `/config`: Set API keys, Ollama host, LLM choice

## Agent Core Modules
- [ ] `orchestrator.js`: task splitter, goal memory
- [ ] `agent_worker.js`: multi-model inference + RAG loop
- [ ] `evaluator.js`: response scoring, retry logic
- [ ] `compliance_checker.js`: validate code, structure, docs
- [ ] `lxc_service.js`: launch/stop/status containers

## Agent Knowledge Memory (PostgreSQL)
- `agents` table: ID, name, type, performance score
- `tasks` table: assigned_to, goal, status, model, logs
- `rag_responses`: uuid, source, content, tag, score
- `llm_profiles`: model_id, description, provider, latency

---

# 🧑‍💻 Developer Standards
- All API endpoints must be documented using OpenAPI/Swagger
- All frontend code must support dark mode & mobile-first
- Persistent agent logs should be timestamped and immutable
- Sensitive API keys must be encrypted and stored server-side only
- Modular folder layout with reusable UI components
- Use changelogs in all major file updates during dev
- Prefer task queues for all agent inference or file processing

---

# 🚀 Bolt.new Prompt (copy-paste for project init)
```markdown
# 🚀 Bolt.new Prompt: ZippyAgent Autonomous AI Business Builder

Create a full-stack PWA web app named "ZippyAgent" that allows authenticated users to:

1. Launch prompts like “Build me a SaaS that tracks crypto wallets”
2. Watch agent execution trees work on tasks
3. View agent performance scores and retry chains
4. Deploy and test services created by agents
5. Configure LLM provider access (Ollama local, GPT API key, etc)
6. Deploy containerized services using LXC or Docker CLI wrappers
7. Enable white-label domains & subdomain PWA outputs

Include:
- Dark/light mode toggle
- Tailwind UI
- Agent activity logs
- Component map and folders for `/src/components/AgentCard`, `/src/pages/dashboard.tsx`, `/src/pages/config.tsx`
- Built-in support for local dev and production builds
- Support for custom Docker or LXC templates
- Form components for launching prompts, selecting models, and reviewing output
- JWT-based auth, protected routes, and optional guest view mode
```
---

