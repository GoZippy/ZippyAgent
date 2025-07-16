use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolConfig {
    pub name: String,
    pub description: String,
    pub executable: HashMap<String, String>,
    pub install_paths: Option<HashMap<String, Vec<String>>>,
    pub launch_args: Option<Vec<String>>,
    pub process_name: String,
    pub category: String,
    pub url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolsConfig {
    pub tools: HashMap<String, ToolConfig>,
    pub categories: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolStatus {
    pub name: String,
    pub id: String,
    pub category: String,
    pub description: String,
    pub is_installed: bool,
    pub is_running: bool,
    pub executable_path: Option<String>,
    pub pid: Option<u32>,
    pub last_launched: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LaunchResult {
    pub success: bool,
    pub message: String,
    pub pid: Option<u32>,
}

pub struct ToolLauncher {
    config: ToolsConfig,
    config_path: PathBuf,
}

impl ToolLauncher {
    pub fn new(config_path: PathBuf) -> Result<Self, String> {
        let config_content = fs::read_to_string(&config_path)
            .map_err(|e| format!("Failed to read tools config: {}", e))?;
        
        let config: ToolsConfig = serde_json::from_str(&config_content)
            .map_err(|e| format!("Failed to parse tools config: {}", e))?;
        
        Ok(Self {
            config,
            config_path,
        })
    }

    pub fn get_platform() -> &'static str {
        if cfg!(target_os = "windows") {
            "windows"
        } else if cfg!(target_os = "macos") {
            "macos"
        } else {
            "linux"
        }
    }

    pub fn find_executable(&self, tool_config: &ToolConfig) -> Option<String> {
        let platform = Self::get_platform();
        
        // Get the executable name for this platform
        let executable_name = tool_config.executable.get(platform)?;
        
        // Handle special cases
        if executable_name == "default_browser" {
            return Some("default_browser".to_string());
        }
        
        // Check install paths first
        if let Some(install_paths) = &tool_config.install_paths {
            if let Some(paths) = install_paths.get(platform) {
                for path in paths {
                    let expanded_path = expand_environment_variables(path);
                    if std::path::Path::new(&expanded_path).exists() {
                        return Some(expanded_path);
                    }
                }
            }
        }
        
        // Try to find in PATH
        if let Ok(output) = Command::new("where")
            .arg(executable_name)
            .output()
        {
            if output.status.success() {
                let path = String::from_utf8_lossy(&output.stdout);
                let path = path.trim();
                if !path.is_empty() {
                    return Some(path.to_string());
                }
            }
        }
        
        None
    }

    pub fn is_process_running(&self, process_name: &str) -> (bool, Option<u32>) {
        if cfg!(target_os = "windows") {
            if let Ok(output) = Command::new("tasklist")
                .arg("/FI")
                .arg(format!("IMAGENAME eq {}.exe", process_name))
                .arg("/FO")
                .arg("CSV")
                .output()
            {
                if output.status.success() {
                    let output_str = String::from_utf8_lossy(&output.stdout);
                    let lines: Vec<&str> = output_str.lines().collect();
                    
                    if lines.len() > 1 {
                        // Parse the first process entry to get PID
                        if let Some(line) = lines.get(1) {
                            let parts: Vec<&str> = line.split(',').collect();
                            if parts.len() >= 2 {
                                let pid_str = parts[1].trim_matches('"');
                                if let Ok(pid) = pid_str.parse::<u32>() {
                                    return (true, Some(pid));
                                }
                            }
                        }
                        return (true, None);
                    }
                }
            }
        } else {
            // Unix-like systems
            if let Ok(output) = Command::new("pgrep")
                .arg("-x")
                .arg(process_name)
                .output()
            {
                if output.status.success() {
                    let output_str = String::from_utf8_lossy(&output.stdout);
                    let pid_str = output_str.trim();
                    if !pid_str.is_empty() {
                        if let Ok(pid) = pid_str.parse::<u32>() {
                            return (true, Some(pid));
                        }
                        return (true, None);
                    }
                }
            }
        }
        
        (false, None)
    }

    pub fn launch_tool(&self, tool_id: &str, project_path: Option<&str>) -> LaunchResult {
        let tool_config = match self.config.tools.get(tool_id) {
            Some(config) => config,
            None => return LaunchResult {
                success: false,
                message: format!("Tool '{}' not found in configuration", tool_id),
                pid: None,
            },
        };

        // Handle web-based tools
        if let Some(url) = &tool_config.url {
            return self.launch_web_tool(url);
        }

        // Handle desktop applications
        let executable_path = match self.find_executable(tool_config) {
            Some(path) => path,
            None => return LaunchResult {
                success: false,
                message: format!("Executable for '{}' not found", tool_config.name),
                pid: None,
            },
        };

        // Build arguments
        let mut args = Vec::new();
        
        // Add configured launch args
        if let Some(launch_args) = &tool_config.launch_args {
            args.extend(launch_args.iter().cloned());
        }
        
        // Add project path if provided
        if let Some(path) = project_path {
            if std::path::Path::new(path).exists() {
                args.push(path.to_string());
            }
        }

        // Launch the process
        match Command::new(&executable_path)
            .args(&args)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
        {
            Ok(child) => LaunchResult {
                success: true,
                message: format!("{} launched successfully", tool_config.name),
                pid: Some(child.id()),
            },
            Err(e) => LaunchResult {
                success: false,
                message: format!("Failed to launch {}: {}", tool_config.name, e),
                pid: None,
            },
        }
    }

    fn launch_web_tool(&self, url: &str) -> LaunchResult {
        let result = if cfg!(target_os = "windows") {
            Command::new("cmd")
                .args(["/C", "start", url])
                .output()
        } else if cfg!(target_os = "macos") {
            Command::new("open")
                .arg(url)
                .output()
        } else {
            Command::new("xdg-open")
                .arg(url)
                .output()
        };

        match result {
            Ok(output) => {
                if output.status.success() {
                    LaunchResult {
                        success: true,
                        message: format!("Web tool launched successfully: {}", url),
                        pid: None,
                    }
                } else {
                    LaunchResult {
                        success: false,
                        message: format!("Failed to launch web tool: {}", url),
                        pid: None,
                    }
                }
            }
            Err(e) => LaunchResult {
                success: false,
                message: format!("Failed to launch web tool: {}", e),
                pid: None,
            },
        }
    }

    pub fn get_tool_status(&self, tool_id: &str) -> Option<ToolStatus> {
        let tool_config = self.config.tools.get(tool_id)?;
        
        let executable_path = self.find_executable(tool_config);
        let is_installed = executable_path.is_some();
        
        let (is_running, pid) = if is_installed {
            self.is_process_running(&tool_config.process_name)
        } else {
            (false, None)
        };

        Some(ToolStatus {
            name: tool_config.name.clone(),
            id: tool_id.to_string(),
            category: tool_config.category.clone(),
            description: tool_config.description.clone(),
            is_installed,
            is_running,
            executable_path,
            pid,
            last_launched: None, // TODO: Track launch history
        })
    }

    pub fn get_all_tools_status(&self) -> Vec<ToolStatus> {
        self.config.tools.keys()
            .filter_map(|tool_id| self.get_tool_status(tool_id))
            .collect()
    }

    pub fn get_tools_by_category(&self) -> HashMap<String, Vec<ToolStatus>> {
        let mut categorized = HashMap::new();
        
        for status in self.get_all_tools_status() {
            categorized
                .entry(status.category.clone())
                .or_insert_with(Vec::new)
                .push(status);
        }
        
        categorized
    }

    pub fn reload_config(&mut self) -> Result<(), String> {
        let config_content = fs::read_to_string(&self.config_path)
            .map_err(|e| format!("Failed to read tools config: {}", e))?;
        
        let config: ToolsConfig = serde_json::from_str(&config_content)
            .map_err(|e| format!("Failed to parse tools config: {}", e))?;
        
        self.config = config;
        Ok(())
    }
}

fn expand_environment_variables(path: &str) -> String {
    let mut result = path.to_string();
    
    // Handle Windows environment variables
    if cfg!(target_os = "windows") {
        if let Ok(localappdata) = std::env::var("LOCALAPPDATA") {
            result = result.replace("%LOCALAPPDATA%", &localappdata);
        }
        if let Ok(programfiles) = std::env::var("PROGRAMFILES") {
            result = result.replace("%PROGRAMFILES%", &programfiles);
        }
        if let Ok(programfiles_x86) = std::env::var("PROGRAMFILES(X86)") {
            result = result.replace("%PROGRAMFILES(X86)%", &programfiles_x86);
        }
    }
    
    // Handle Unix-like home directory
    if path.starts_with("~/") {
        if let Ok(home) = std::env::var("HOME") {
            result = result.replace("~", &home);
        }
    }
    
    result
}
