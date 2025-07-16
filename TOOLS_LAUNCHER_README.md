# Development Tools Integration System

This system provides a unified interface for launching and managing development tools across the ZippyAgent platform. It includes PowerShell scripts for tool launching, a Rust cross-platform wrapper, and a UI panel for easy tool management.

## Features

- **Cross-platform tool launching** (Windows, macOS, Linux)
- **Process detection and status monitoring** 
- **Configurable tool definitions** via JSON
- **UI panel with categorized tools**
- **Live status indicators** (running/dormant/not installed)
- **Project path integration** for context-aware launching
- **Automatic tool discovery** in common installation paths

## Components

### 1. Configuration (`tools.json`)

The main configuration file defining all available tools:

```json
{
  "tools": {
    "cursor": {
      "name": "Cursor",
      "description": "AI-powered code editor",
      "executable": {
        "windows": "cursor.exe",
        "macos": "cursor",
        "linux": "cursor"
      },
      "install_paths": {
        "windows": [
          "%LOCALAPPDATA%\\Programs\\cursor\\cursor.exe",
          "%PROGRAMFILES%\\Cursor\\cursor.exe"
        ]
      },
      "launch_args": [],
      "process_name": "cursor",
      "category": "editor"
    }
  }
}
```

### 2. PowerShell Scripts (`scripts/tool-launcher/`)

#### Individual Tool Launchers
- `Launch-Cursor.ps1` - Launches Cursor AI editor
- `Launch-Warp.ps1` - Launches Warp terminal
- `Launch-Bolt.ps1` - Opens Bolt.new in browser

#### Generic Launcher
- `Launch-Tool.ps1` - Universal launcher that reads from `tools.json`

#### Usage Examples

```powershell
# Launch Cursor with a specific project
.\Launch-Cursor.ps1 -ProjectPath "C:\Projects\ZippyAgent"

# Launch Warp terminal in a directory
.\Launch-Warp.ps1 -WorkingDirectory "C:\Projects\ZippyAgent"

# Launch any tool generically
.\Launch-Tool.ps1 -ToolName "cursor" -ProjectPath "C:\Projects\ZippyAgent"

# Open Bolt.new
.\Launch-Bolt.ps1
```

### 3. Rust Integration (`src-tauri/src/tool_launcher.rs`)

The Rust backend provides:

- **Cross-platform executable detection**
- **Process monitoring and status tracking**
- **Safe tool launching with error handling**
- **Configuration management and reloading**

#### Key Structures

```rust
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

pub struct LaunchResult {
    pub success: bool,
    pub message: String,
    pub pid: Option<u32>,
}
```

#### Tauri Commands

- `initialize_tool_launcher()` - Initialize the tool launcher system
- `get_tools_status()` - Get status of all tools
- `get_tools_by_category()` - Get tools organized by category
- `launch_tool(tool_id, project_path)` - Launch a specific tool
- `get_tool_status(tool_id)` - Get status of a single tool
- `reload_tools_config()` - Reload configuration from disk

### 4. UI Panel (`src/tools-panel.html`)

A modern web interface providing:

- **Categorized tool display**
- **Real-time status indicators**
- **Quick launch buttons**
- **Project path input**
- **Live process monitoring**
- **Configuration refresh**

#### Features

- **Visual Status Indicators**:
  - 🟢 Green: Tool is running
  - 🟡 Yellow: Tool is installed but not running
  - 🔴 Red: Tool is not installed

- **Interactive Elements**:
  - Launch buttons for each tool
  - Project path input fields
  - Refresh button for live updates
  - Error and success notifications

## Installation and Setup

### 1. Prerequisites

- PowerShell 5.1+ (Windows) or PowerShell Core 6+ (cross-platform)
- Rust 1.70+ with Tauri dependencies
- Node.js 16+ (for UI development)

### 2. Configuration

1. Copy `tools.json` to your project root
2. Modify tool definitions as needed
3. Add any custom tools to the configuration

### 3. Build and Run

```bash
# Build the Rust backend
cd apps/agent-monitor/src-tauri
cargo build

# Run the Tauri application
cargo tauri dev
```

### 4. Testing PowerShell Scripts

```powershell
# Test individual launchers
.\scripts\tool-launcher\Launch-Cursor.ps1 -ProjectPath "."
.\scripts\tool-launcher\Launch-Warp.ps1 -WorkingDirectory "."

# Test generic launcher
.\scripts\tool-launcher\Launch-Tool.ps1 -ToolName "bolt"
```

## Adding New Tools

### 1. Update `tools.json`

```json
{
  "tools": {
    "my-tool": {
      "name": "My Development Tool",
      "description": "Description of what this tool does",
      "executable": {
        "windows": "mytool.exe",
        "macos": "mytool",
        "linux": "mytool"
      },
      "install_paths": {
        "windows": [
          "%LOCALAPPDATA%\\MyTool\\mytool.exe",
          "%PROGRAMFILES%\\MyTool\\mytool.exe"
        ],
        "macos": [
          "/Applications/MyTool.app/Contents/MacOS/mytool"
        ],
        "linux": [
          "/usr/bin/mytool",
          "/usr/local/bin/mytool"
        ]
      },
      "launch_args": ["--flag", "value"],
      "process_name": "mytool",
      "category": "editor"
    }
  }
}
```

### 2. Create PowerShell Script (Optional)

```powershell
# scripts/tool-launcher/Launch-MyTool.ps1
param(
    [string]$ProjectPath = "",
    [string[]]$Arguments = @()
)

# Tool-specific launch logic here
```

### 3. Update UI Categories (Optional)

In `tools-panel.html`, add your category to the `getCategoryTitle` function:

```javascript
function getCategoryTitle(categoryId) {
    const categoryNames = {
        'editor': '📝 Code Editors',
        'terminal': '💻 Terminals',
        'web': '🌐 Web Tools',
        'ai': '🤖 AI Tools',
        'infrastructure': '🏗️ Infrastructure',
        'my-category': '🔧 My Tools'  // Add your category
    };
    return categoryNames[categoryId] || categoryId;
}
```

## Platform-Specific Notes

### Windows
- Uses `tasklist` for process detection
- Supports environment variable expansion (`%LOCALAPPDATA%`, `%PROGRAMFILES%`)
- PowerShell execution policy may need to be set: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned`

### macOS
- Uses `pgrep` for process detection
- Application paths typically in `/Applications/`
- May require permissions for accessibility features

### Linux
- Uses `pgrep` for process detection
- Tools typically in `/usr/bin/` or `/usr/local/bin/`
- May require package manager installation

## Error Handling

The system includes comprehensive error handling:

- **Tool not found**: Clear error messages with installation suggestions
- **Launch failures**: Detailed error reporting
- **Process monitoring**: Graceful handling of process detection failures
- **Configuration errors**: JSON validation and user-friendly error messages

## Development and Debugging

### Logging

The Rust backend includes extensive logging:

```rust
// Enable debug logging
RUST_LOG=debug cargo tauri dev
```

### Testing

```bash
# Run Rust tests
cargo test

# Test PowerShell scripts
.\scripts\tool-launcher\Launch-Tool.ps1 -ToolName "cursor" -ProjectPath "."
```

### Common Issues

1. **Tools not detected**: Check `install_paths` in configuration
2. **Launch failures**: Verify executable permissions and paths
3. **Process monitoring**: Ensure process names match actual executables
4. **Cross-platform issues**: Test on target platforms

## Integration with ZippyAgent

This tool launcher integrates seamlessly with the ZippyAgent ecosystem:

- **Agent Orchestration**: Tools can be launched as part of agent workflows
- **Project Context**: Automatically detects and uses project paths
- **Status Monitoring**: Integrates with agent monitoring systems
- **Configuration Management**: Uses ZippyAgent's configuration patterns

## Future Enhancements

- **Tool installation automation**
- **Version management and updates**
- **Workspace-specific tool configurations**
- **Integration with CI/CD pipelines**
- **Tool usage analytics and reporting**
- **Cloud-based tool management**

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your tool configurations and scripts
4. Test across platforms
5. Submit a pull request

## License

This system is part of the ZippyAgent platform and follows the same licensing terms.
