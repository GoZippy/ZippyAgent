# ZippyCoin Agent Monitor

A Windows desktop application built with Tauri for monitoring and managing ZippyCoin agents orchestrated by PowerShell scripts.

## Features

- **Real-time Agent Monitoring**: View the status of all running agents (active, paused, held, or stopped)
- **Performance Metrics**: Track CPU and memory usage for each agent with live charts
- **Log Viewer**: Read recent logs from any agent directly in the app
- **Orchestration Control**: Start and stop the orchestrator service
- **LLM Integration**: Support for both local (Ollama) and cloud (Warp AI) LLM providers
- **Status Indicators**: Visual indicators for agent states and hold conditions

## Prerequisites

- Windows 10/11
- Node.js 16+ and npm
- Rust (latest stable)
- PowerShell 7+
- Ollama (optional, for local LLM)

## Installation

1. Clone the repository and navigate to the app directory:
```bash
cd agent-monitor-app
```

2. Install dependencies:
```bash
npm install
```

3. Install Tauri CLI:
```bash
npm install -g @tauri-apps/cli
```

## Development

To run the app in development mode:

```bash
npm run tauri dev
```

This will start both the Vite dev server and the Tauri app.

## Building

To build the app for production:

```bash
npm run tauri build
```

The built executable will be available in `src-tauri/target/release/`.

## Usage

1. **Configure Orchestration**:
   - Set the path to your orchestrator PowerShell script
   - Choose your LLM provider (Ollama or Warp)
   - Configure the LLM endpoint (default: http://localhost:11434 for Ollama)
   - Add API key if using a cloud provider

2. **Start Monitoring**:
   - Click "Start Orchestrator" to begin agent orchestration
   - Agents will appear in the status grid as they start
   - Monitor real-time CPU usage in the metrics chart

3. **View Agent Status**:
   - Green border = Active
   - Orange border = Paused
   - Red border = Stopped
   - Yellow background = Agent is held/waiting for input

4. **Check Logs**:
   - Select an agent from the dropdown
   - View the last 50 lines of logs
   - Logs update when you switch agents

## Agent States

- **Active**: Agent is running and processing tasks
- **Paused**: Agent is running but held/waiting for input
- **Stopped**: Agent process is not running

## Troubleshooting

- **Agents not showing**: Ensure the orchestrator script is running and agents are properly configured
- **Ollama connection failed**: Check that Ollama is running on the configured port
- **Permission errors**: Run the app as administrator if needed for process management

## Architecture

- **Frontend**: TypeScript + Vite + Chart.js
- **Backend**: Rust + Tauri
- **Agent Detection**: PowerShell process monitoring
- **Log Reading**: Direct file system access via PowerShell

## License

This project is part of the ZippyCoin ecosystem.
