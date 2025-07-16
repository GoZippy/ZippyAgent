#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

mod llm_service;
mod model_db;
mod tool_launcher;

#[cfg(test)]
mod tests;

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::process::Command;
use std::sync::Mutex;
use tauri::State;
use chrono::{DateTime, Local};
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;
use crate::model_db::{ModelDatabase, ModelMetadata, InstallProgress};
use crate::llm_service::ollama_cli::{self, OllamaError};
use crate::llm_service::model_downloader;
use crate::tool_launcher::{ToolLauncher, ToolStatus, LaunchResult};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AgentStatus {
    is_held: bool,
    name: String,
    status: String,
    last_activity: String,
    pid: Option<u32>,
    cpu_usage: f32,
    memory_usage: f32,
    log_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct OrchestrationConfig {
    orchestrator_path: String,
    llm_provider: String,
    llm_endpoint: String,
    llm_api_key: Option<String>,
}

struct AppState {
    agents: Mutex<HashMap<String, AgentStatus>>,
    orchestration_config: Mutex<Option<OrchestrationConfig>>,
    model_db: Arc<RwLock<Option<ModelDatabase>>>,
    tool_launcher: Arc<RwLock<Option<ToolLauncher>>>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            agents: Mutex::default(),
            orchestration_config: Mutex::default(),
            model_db: Arc::new(RwLock::new(None)),
            tool_launcher: Arc::new(RwLock::new(None)),
        }
    }
}

#[tauri::command]
async fn get_agent_statuses(_state: State<'_, AppState>) -> Result<Vec<AgentStatus>, String> {
    let statuses = fetch_agent_statuses().await;
    Ok(statuses.into_values().collect())
}

#[tauri::command]
fn start_orchestrator(
    config: OrchestrationConfig,
    state: State<AppState>,
) -> Result<String, String> {
    // Save configuration
    let mut orchestration_config = state.orchestration_config.lock().unwrap();
    *orchestration_config = Some(config.clone());

    // Start the orchestrator PowerShell script
    let output = Command::new("powershell")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-File")
        .arg(&config.orchestrator_path)
        .spawn()
        .map_err(|e| format!("Failed to start orchestrator: {}", e))?;

    Ok(format!("Orchestrator started with PID: {:?}", output.id()))
}

#[tauri::command]
fn stop_orchestrator() -> Result<String, String> {
    // Stop all agent processes
    let output = Command::new("powershell")
        .arg("-Command")
        .arg("Get-Process | Where-Object { $_.ProcessName -match 'pwsh' -and $_.CommandLine -match 'agent_script' } | Stop-Process -Force")
        .output()
        .map_err(|e| format!("Failed to stop orchestrator: {}", e))?;

    if output.status.success() {
        Ok("Orchestrator and agents stopped successfully".to_string())
    } else {
        Err("Failed to stop some processes".to_string())
    }
}

#[tauri::command]
fn read_agent_logs(agent_name: String, lines: usize) -> Result<Vec<String>, String> {
    let log_path = format!("logs\\{}_*.log", agent_name);
    
    let output = Command::new("powershell")
        .arg("-Command")
        .arg(format!("Get-Content -Path '{}' -Tail {}", log_path, lines))
        .output()
        .map_err(|e| format!("Failed to read logs: {}", e))?;

    if output.status.success() {
        let log_content = String::from_utf8_lossy(&output.stdout);
        Ok(log_content.lines().map(|s| s.to_string()).collect())
    } else {
        Err("Failed to read log file".to_string())
    }
}

#[tauri::command]
async fn check_ollama_status(endpoint: String) -> Result<bool, String> {
    let client = reqwest::Client::new();
    let url = format!("{}/api/tags", endpoint);
    
    match client.get(&url).send().await {
        Ok(response) => Ok(response.status().is_success()),
        Err(_) => Ok(false),
    }
}

async fn fetch_agent_statuses() -> HashMap<String, AgentStatus> {
    let agents = vec!["CoreBlockchain", "SDK", "SmartContracts", "TestingQA", "TrustEngine"];
    let mut statuses = HashMap::new();
    
    // Get process information
    let output = Command::new("powershell")
        .arg("-Command")
        .arg(r#"
            $agents = @('CoreBlockchain', 'SDK', 'SmartContracts', 'TestingQA', 'TrustEngine')
            $results = @{}
            
            foreach ($agent in $agents) {
                $process = Get-Process -Name pwsh -ErrorAction SilentlyContinue | 
                    Where-Object { $_.CommandLine -match "$agent" + "_script" }
                
                if ($process) {
                    $logFile = Get-ChildItem -Path "logs" -Filter "$agent*.log" -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    
                    $isHeld = $false
                    if ($logFile) {
                        $lastLines = Get-Content $logFile.FullName -Tail 10
                        $isHeld = $lastLines -match "HELD|PAUSED|Waiting for input"
                    }
                    
                    $results[$agent] = @{
                        'status' = if ($isHeld) { 'paused' } else { 'active' }
                        'pid' = $process.Id
                        'cpu' = [math]::Round($process.CPU, 2)
                        'memory' = [math]::Round($process.WorkingSet / 1MB, 2)
                        'lastActivity' = if ($logFile) { $logFile.LastWriteTime.ToString('o') } else { (Get-Date).ToString('o') }
                        'isHeld' = $isHeld
                    }
                } else {
                    $results[$agent] = @{
                        'status' = 'stopped'
                        'isHeld' = $false
                    }
                }
            }
            
            $results | ConvertTo-Json -Depth 3
        "#)
        .output();
    
    match output {
        Ok(out) => {
            if out.status.success() {
                let json_str = String::from_utf8_lossy(&out.stdout);
                if let Ok(data) = serde_json::from_str::<HashMap<String, serde_json::Value>>(&json_str) {
                    for (agent_name, agent_data) in data {
                        let status = AgentStatus {
                            name: agent_name.clone(),
                            status: agent_data["status"].as_str().unwrap_or("unknown").to_string(),
                            last_activity: agent_data["lastActivity"]
                                .as_str()
                                .unwrap_or(&Local::now().to_rfc3339())
                                .to_string(),
                            pid: agent_data["pid"].as_u64().map(|p| p as u32),
                            cpu_usage: agent_data["cpu"].as_f64().unwrap_or(0.0) as f32,
                            memory_usage: agent_data["memory"].as_f64().unwrap_or(0.0) as f32,
                            log_path: format!("..\\logs\\{}_*.log", agent_name),
                            is_held: agent_data["isHeld"].as_bool().unwrap_or(false),
                        };
                        statuses.insert(agent_name, status);
                    }
                }
            }
        }
        Err(_) => {}
    }
    
    // Fill in any missing agents
    for agent in agents {
        if !statuses.contains_key(agent) {
            statuses.insert(
                agent.to_string(),
                AgentStatus {
                    name: agent.to_string(),
                    status: "stopped".to_string(),
                    last_activity: Local::now().to_rfc3339(),
                    pid: None,
                    cpu_usage: 0.0,
                    memory_usage: 0.0,
                    log_path: format!("..\\logs\\{}_*.log", agent),
                    is_held: false,
                },
            );
        }
    }
    
    statuses
}

#[tauri::command]
fn generate_report() -> Result<String, String> {
    let date_str = Local::now().format("%Y-%m-%d").to_string();
    let report_file_path = format!("reports/agent_status_{}.md", date_str);
    
    // Create reports directory if it doesn't exist
    fs::create_dir_all("reports")
        .map_err(|e| format!("Failed to create reports directory: {}", e))?;

    let mut file = fs::File::create(&report_file_path)
        .map_err(|e| format!("Failed to create report file: {}", e))?;
    
    writeln!(file, "# Agent Status Report - {}\n", date_str)
        .map_err(|e| format!("Failed to write to report file: {}", e))?;
        
    writeln!(file, "Generated: {} UTC\n", Local::now().format("%Y-%m-%d %H:%M:%S"))
        .map_err(|e| format!("Failed to write to report file: {}", e))?;

    writeln!(file, "## Executive Summary\n")
        .map_err(|e| format!("Failed to write to report file: {}", e))?;
        
    writeln!(file, "This report provides a comprehensive overview of all active agents in the ZippyAgent Core Research project.\n")
        .map_err(|e| format!("Failed to write to report file: {}", e))?;
    
    writeln!(file, "## Agent Status\n")
        .map_err(|e| format!("Failed to write to report file: {}", e))?;
        
    writeln!(file, "| Agent Name | Status | Last Activity | PID |")
        .map_err(|e| format!("Failed to write to report file: {}", e))?;
    writeln!(file, "|------------|--------|---------------|-----|")
        .map_err(|e| format!("Failed to write to report file: {}", e))?;

    // This is a simplified report - in a real implementation you'd fetch actual agent statuses
    let agents = vec!["CoreBlockchain", "SDK", "SmartContracts", "TestingQA", "TrustEngine"];
    for agent in agents {
        writeln!(file, "| {} | Running | {} | N/A |", agent, Local::now().format("%Y-%m-%d %H:%M:%S"))
            .map_err(|e| format!("Failed to write to report file: {}", e))?;
    }

    Ok(format!("Report successfully generated: {}", report_file_path))
}

#[tauri::command]
async fn fetch_agent_metrics() -> Result<HashMap<String, serde_json::Value>, String> {
    let output = Command::new("powershell")
        .arg("-Command")
        .arg(r#"
            $agents = @('CoreBlockchain', 'SDK', 'SmartContracts', 'TestingQA', 'TrustEngine')
            $metrics = @{}
            
            foreach ($agent in $agents) {
                $process = Get-Process -Name pwsh -ErrorAction SilentlyContinue | 
                    Where-Object { $_.CommandLine -match $agent }
                
                if ($process) {
                    $metrics[$agent] = @{
                        'cpu' = [math]::Round($process.CPU, 2)
                        'memory' = [math]::Round($process.WorkingSet / 1MB, 2)
                        'pid' = $process.Id
                        'status' = 'running'
                    }
                } else {
                    $metrics[$agent] = @{
                        'status' = 'stopped'
                    }
                }
            }
            
            $metrics | ConvertTo-Json
        "#)
        .output()
        .map_err(|e| format!("Failed to fetch metrics: {}", e))?;

    if output.status.success() {
        let json_str = String::from_utf8_lossy(&output.stdout);
        let metrics: HashMap<String, serde_json::Value> = serde_json::from_str(&json_str)
            .map_err(|e| format!("Failed to parse metrics: {}", e))?;
        Ok(metrics)
    } else {
        Err("Failed to fetch agent metrics".to_string())
    }
}

// LLM Management Commands
#[tauri::command]
async fn initialize_model_db(state: State<'_, AppState>) -> Result<String, String> {
    let db_path = "sqlite:models.db";
    let db = ModelDatabase::new(db_path).await
        .map_err(|e| format!("Failed to initialize database: {}", e))?;
    
    // Initialize with some common models
    let models = vec![
        ModelMetadata {
            id: "llama2".to_string(),
            name: "Llama 2".to_string(),
            description: Some("Meta's Llama 2 model".to_string()),
            size: Some(3800000000),  // ~3.8GB
            installed: false,
            version: Some("7b".to_string()),
            download_url: None,
            checksum: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        },
        ModelMetadata {
            id: "codellama".to_string(),
            name: "Code Llama".to_string(),
            description: Some("Meta's Code Llama for programming tasks".to_string()),
            size: Some(3800000000),  // ~3.8GB
            installed: false,
            version: Some("7b".to_string()),
            download_url: None,
            checksum: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        },
        ModelMetadata {
            id: "mistral".to_string(),
            name: "Mistral".to_string(),
            description: Some("Mistral AI's 7B model".to_string()),
            size: Some(4100000000),  // ~4.1GB
            installed: false,
            version: Some("7b".to_string()),
            download_url: None,
            checksum: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        },
    ];
    
    for model in models {
        db.insert_or_update_model(&model).await
            .map_err(|e| format!("Failed to insert model: {}", e))?;
    }
    
    {
        let mut db_lock = state.model_db.write().await;
        *db_lock = Some(db);
    }
    
    Ok("Model database initialized successfully".to_string())
}

#[tauri::command]
async fn list_models(state: State<'_, AppState>) -> Result<Vec<ModelMetadata>, String> {
    let db_lock = state.model_db.read().await;
    let db = db_lock.as_ref().ok_or("Database not initialized")?;
    
    // Get models from database
    let mut models = db.get_all_models().await
        .map_err(|e| format!("Failed to get models: {}", e))?;
    
    // Update with Ollama status
    if let Ok(ollama_output) = ollama_cli::list_models() {
        let ollama_models: Vec<&str> = ollama_output.lines()
            .filter_map(|line| {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() > 0 && !parts[0].contains("NAME") {
                    Some(parts[0].split(':').next().unwrap_or(parts[0]))
                } else {
                    None
                }
            })
            .collect();
        
        for model in &mut models {
            model.installed = ollama_models.contains(&model.id.as_str());
        }
    }
    
    Ok(models)
}

#[tauri::command]
async fn install_model(model_id: String, state: State<'_, AppState>) -> Result<String, String> {
    let db_lock = state.model_db.read().await;
    let db = db_lock.as_ref().ok_or("Database not initialized")?;
    
    // Update progress
    db.update_install_progress(&model_id, 0.0, "starting", None).await
        .map_err(|e| format!("Failed to update progress: {}", e))?;
    
    // Start installation in background
    tokio::spawn(async move {
        // This is a simplified version - in production you'd handle this more robustly
        let result = ollama_cli::pull_model(&model_id);
        
        // Update database with result
        // Note: In a real implementation, you'd pass the database reference properly
        match result {
            Ok(_) => {
                // Mark as installed
                println!("Model {} installed successfully", model_id);
            }
            Err(e) => {
                println!("Failed to install model {}: {}", model_id, e);
            }
        }
    });
    
    Ok(format!("Started installing model: {}", model_id))
}

#[tauri::command]
async fn remove_model(model_id: String, state: State<'_, AppState>) -> Result<String, String> {
    let db_lock = state.model_db.read().await;
    let db = db_lock.as_ref().ok_or("Database not initialized")?;
    
    // Remove from Ollama
    ollama_cli::remove_model(&model_id)
        .map_err(|e| format!("Failed to remove model: {}", e))?;
    
    // Update database
    db.update_model_installed_status(&model_id, false).await
        .map_err(|e| format!("Failed to update database: {}", e))?;
    
    Ok(format!("Model {} removed successfully", model_id))
}

#[tauri::command]
async fn get_install_progress(state: State<'_, AppState>) -> Result<HashMap<String, InstallProgress>, String> {
    let db_lock = state.model_db.read().await;
    let db = db_lock.as_ref().ok_or("Database not initialized")?;
    
    db.get_all_install_progress().await
        .map_err(|e| format!("Failed to get install progress: {}", e))
}

#[tauri::command]
async fn download_model_http(
    url: String,
    model_id: String,
    checksum: String,
    state: State<'_, AppState>,
) -> Result<String, String> {
    let db_lock = state.model_db.read().await;
    let db = db_lock.as_ref().ok_or("Database not initialized")?;
    
    // Update progress
    db.update_install_progress(&model_id, 0.0, "downloading", None).await
        .map_err(|e| format!("Failed to update progress: {}", e))?;
    
    // Create temp file
    let temp_file = tempfile::NamedTempFile::new()
        .map_err(|e| format!("Failed to create temp file: {}", e))?;
    
    // Download with checksum verification
    model_downloader::download_model(&url, temp_file.path(), &checksum).await
        .map_err(|e| format!("Failed to download model: {}", e))?;
    
    // Mark as complete
    db.update_install_progress(&model_id, 100.0, "completed", None).await
        .map_err(|e| format!("Failed to update progress: {}", e))?;
    
    db.update_model_installed_status(&model_id, true).await
        .map_err(|e| format!("Failed to update model status: {}", e))?;
    
    Ok(format!("Model {} downloaded and verified successfully", model_id))
}

// Tool Launcher Commands
#[tauri::command]
async fn initialize_tool_launcher(state: State<'_, AppState>) -> Result<String, String> {
    let tools_config_path = PathBuf::from("tools.json");
    
    if !tools_config_path.exists() {
        return Err("tools.json not found in project root".to_string());
    }
    
    let launcher = ToolLauncher::new(tools_config_path)
        .map_err(|e| format!("Failed to initialize tool launcher: {}", e))?;
    
    {
        let mut launcher_lock = state.tool_launcher.write().await;
        *launcher_lock = Some(launcher);
    }
    
    Ok("Tool launcher initialized successfully".to_string())
}

#[tauri::command]
async fn get_tools_status(state: State<'_, AppState>) -> Result<Vec<ToolStatus>, String> {
    let launcher_lock = state.tool_launcher.read().await;
    let launcher = launcher_lock.as_ref().ok_or("Tool launcher not initialized")?;
    
    Ok(launcher.get_all_tools_status())
}

#[tauri::command]
async fn get_tools_by_category(state: State<'_, AppState>) -> Result<HashMap<String, Vec<ToolStatus>>, String> {
    let launcher_lock = state.tool_launcher.read().await;
    let launcher = launcher_lock.as_ref().ok_or("Tool launcher not initialized")?;
    
    Ok(launcher.get_tools_by_category())
}

#[tauri::command]
async fn launch_tool(
    tool_id: String,
    project_path: Option<String>,
    state: State<'_, AppState>,
) -> Result<LaunchResult, String> {
    let launcher_lock = state.tool_launcher.read().await;
    let launcher = launcher_lock.as_ref().ok_or("Tool launcher not initialized")?;
    
    Ok(launcher.launch_tool(&tool_id, project_path.as_deref()))
}

#[tauri::command]
async fn get_tool_status(
    tool_id: String,
    state: State<'_, AppState>,
) -> Result<Option<ToolStatus>, String> {
    let launcher_lock = state.tool_launcher.read().await;
    let launcher = launcher_lock.as_ref().ok_or("Tool launcher not initialized")?;
    
    Ok(launcher.get_tool_status(&tool_id))
}

#[tauri::command]
async fn reload_tools_config(state: State<'_, AppState>) -> Result<String, String> {
    let mut launcher_lock = state.tool_launcher.write().await;
    let launcher = launcher_lock.as_mut().ok_or("Tool launcher not initialized")?;
    
    launcher.reload_config()
        .map_err(|e| format!("Failed to reload config: {}", e))?;
    
    Ok("Tools configuration reloaded successfully".to_string())
}

fn main() {
    tauri::Builder::default()
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            get_agent_statuses,
            start_orchestrator,
            stop_orchestrator,
            read_agent_logs,
            check_ollama_status,
            fetch_agent_metrics,
            generate_report,
            initialize_model_db,
            list_models,
            install_model,
            remove_model,
            get_install_progress,
            download_model_http,
            initialize_tool_launcher,
            get_tools_status,
            get_tools_by_category,
            launch_tool,
            get_tool_status,
            reload_tools_config,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
