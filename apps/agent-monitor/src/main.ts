import './style.css'
import { invoke } from '@tauri-apps/api/tauri'
import Chart from 'chart.js/auto'

interface AgentStatus {
  name: string
  status: string
  last_activity: string
  pid: number | null
  cpu_usage: number
  memory_usage: number
  log_path: string
  is_held: boolean
}

interface OrchestrationConfig {
  orchestrator_path: string
  llm_provider: string
  llm_endpoint: string
  llm_api_key: string | null
}

// Initialize UI
document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
  <div class="container">
    <h1>ZippyAgent Agent Monitor</h1>
    
    <div class="control-panel">
      <div class="config-section">
        <h3>Orchestration Configuration</h3>
        <div class="form-group">
          <label>Orchestrator Path:</label>
          <input type="text" id="orchestrator-path" value="../orchestrate-agents.ps1" />
        </div>
        <div class="form-group">
          <label>LLM Provider:</label>
          <select id="llm-provider">
            <option value="ollama">Ollama (Local)</option>
            <option value="warp">Warp AI</option>
          </select>
        </div>
        <div class="form-group">
          <label>LLM Endpoint:</label>
          <input type="text" id="llm-endpoint" value="http://localhost:11434" />
        </div>
        <div class="form-group">
          <label>API Key (optional):</label>
          <input type="password" id="llm-api-key" placeholder="Leave empty for local providers" />
        </div>
      </div>
      
      <div class="actions">
        <button id="start" class="btn btn-primary">Start Orchestrator</button>
        <button id="stop" class="btn btn-danger">Stop Orchestrator</button>
        <button id="check-ollama" class="btn btn-info">Check Ollama Status</button>
      </div>
    </div>

    <div class="status-grid">
      <div class="agents-section">
        <h2>Agent Status</h2>
        <div id="agents-container"></div>
      </div>
      
      <div class="metrics-section">
        <h2>System Metrics</h2>
        <canvas id="metrics-chart"></canvas>
      </div>
    </div>
    
    <div class="logs-section">
      <h2>Recent Logs</h2>
      <select id="agent-selector">
        <option value="">Select an agent...</option>
      </select>
      <div id="logs-container"></div>
    </div>
  </div>
`

// Get DOM elements
const startButton = document.querySelector('#start') as HTMLButtonElement
const stopButton = document.querySelector('#stop') as HTMLButtonElement
const checkOllamaButton = document.querySelector('#check-ollama') as HTMLButtonElement
const agentsContainer = document.querySelector('#agents-container') as HTMLDivElement
const logsContainer = document.querySelector('#logs-container') as HTMLDivElement
const agentSelector = document.querySelector('#agent-selector') as HTMLSelectElement

// Chart setup
const ctx = (document.querySelector('#metrics-chart') as HTMLCanvasElement).getContext('2d')
const metricsChart = new Chart(ctx!, {
  type: 'line',
  data: {
    labels: [],
    datasets: []
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      y: {
        beginAtZero: true,
        max: 100
      }
    }
  }
})

// Agent status tracking
let agentStatuses: AgentStatus[] = []
const metricsHistory: { [key: string]: number[] } = {}

// Event handlers
startButton.addEventListener('click', async () => {
  const config: OrchestrationConfig = {
    orchestrator_path: (document.querySelector('#orchestrator-path') as HTMLInputElement).value,
    llm_provider: (document.querySelector('#llm-provider') as HTMLSelectElement).value,
    llm_endpoint: (document.querySelector('#llm-endpoint') as HTMLInputElement).value,
    llm_api_key: (document.querySelector('#llm-api-key') as HTMLInputElement).value || null
  }
  
  try {
    const result = await invoke<string>('start_orchestrator', { config })
    showNotification(result, 'success')
  } catch (error) {
    showNotification(`Error: ${error}`, 'error')
  }
})

stopButton.addEventListener('click', async () => {
  try {
    const result = await invoke<string>('stop_orchestrator')
    showNotification(result, 'success')
  } catch (error) {
    showNotification(`Error: ${error}`, 'error')
  }
})

checkOllamaButton.addEventListener('click', async () => {
  const endpoint = (document.querySelector('#llm-endpoint') as HTMLInputElement).value
  try {
    const isRunning = await invoke<boolean>('check_ollama_status', { endpoint })
    showNotification(`Ollama status: ${isRunning ? 'Running' : 'Not running'}`, isRunning ? 'success' : 'warning')
  } catch (error) {
    showNotification(`Error checking Ollama: ${error}`, 'error')
  }
})

agentSelector.addEventListener('change', async (e) => {
  const agentName = (e.target as HTMLSelectElement).value
  if (agentName) {
    await loadAgentLogs(agentName)
  }
})

// Functions
function showNotification(message: string, type: 'success' | 'error' | 'warning') {
  const notification = document.createElement('div')
  notification.className = `notification notification-${type}`
  notification.textContent = message
  document.body.appendChild(notification)
  
  setTimeout(() => {
    notification.remove()
  }, 3000)
}

async function loadAgentStatus() {
  try {
    agentStatuses = await invoke<AgentStatus[]>('get_agent_statuses')
    updateAgentDisplay()
    updateMetricsChart()
    updateAgentSelector()
  } catch (error) {
    console.error('Error loading agent status:', error)
  }
}

function updateAgentDisplay() {
  agentsContainer.innerHTML = agentStatuses.map(agent => `
    <div class="agent-card ${agent.status} ${agent.is_held ? 'held' : ''}">
      <h3>${agent.name}</h3>
      <div class="agent-status">
        <span class="status-badge ${agent.status}">${agent.status}</span>
        ${agent.is_held ? '<span class="held-badge">HELD</span>' : ''}
      </div>
      <div class="agent-metrics">
        <div>CPU: ${agent.cpu_usage.toFixed(1)}%</div>
        <div>Memory: ${agent.memory_usage.toFixed(1)} MB</div>
        <div>PID: ${agent.pid || 'N/A'}</div>
      </div>
      <div class="agent-activity">
        Last activity: ${new Date(agent.last_activity).toLocaleTimeString()}
      </div>
    </div>
  `).join('')
}

function updateMetricsChart() {
  const timestamp = new Date().toLocaleTimeString()
  
  // Update labels
  if (metricsChart.data.labels!.length > 20) {
    metricsChart.data.labels!.shift()
  }
  (metricsChart.data.labels as string[]).push(timestamp)
  
  // Update datasets
  agentStatuses.forEach(agent => {
    if (!metricsHistory[agent.name]) {
      metricsHistory[agent.name] = []
      metricsChart.data.datasets.push({
        label: agent.name,
        data: [],
        borderColor: getColorForAgent(agent.name),
        backgroundColor: getColorForAgent(agent.name, 0.2),
        tension: 0.1
      })
    }
    
    const dataset = metricsChart.data.datasets.find(d => d.label === agent.name)
    if (dataset && dataset.data) {
      if (dataset.data.length > 20) {
        dataset.data.shift()
      }
      (dataset.data as number[]).push(agent.cpu_usage)
    }
  })
  
  metricsChart.update()
}

function updateAgentSelector() {
  const currentValue = agentSelector.value
  agentSelector.innerHTML = '<option value="">Select an agent...</option>' + 
    agentStatuses.map(agent => 
      `<option value="${agent.name}">${agent.name}</option>`
    ).join('')
  agentSelector.value = currentValue
}

async function loadAgentLogs(agentName: string) {
  try {
    const logs = await invoke<string[]>('read_agent_logs', { 
      agentName, 
      lines: 50 
    })
    logsContainer.innerHTML = `<pre>${logs.join('\n')}</pre>`
  } catch (error) {
    logsContainer.innerHTML = `<p>Error loading logs: ${error}</p>`
  }
}

function getColorForAgent(agentName: string, alpha: number = 1): string {
  const colors: { [key: string]: string } = {
    'CoreBlockchain': `rgba(255, 99, 132, ${alpha})`,
    'SDK': `rgba(54, 162, 235, ${alpha})`,
    'SmartContracts': `rgba(255, 206, 86, ${alpha})`,
    'TestingQA': `rgba(75, 192, 192, ${alpha})`,
    'TrustEngine': `rgba(153, 102, 255, ${alpha})`
  }
  return colors[agentName] || `rgba(201, 203, 207, ${alpha})`
}

// Start monitoring
loadAgentStatus()
setInterval(loadAgentStatus, 2000) // Update every 2 seconds
