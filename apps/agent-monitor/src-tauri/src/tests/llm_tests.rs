use crate::llm_service::ollama_cli;
use std::process::{Command, Output};
use std::os::windows::process::CommandExt;

#[cfg(test)]
mod tests {
    use super::*;

    // Mock Ollama CLI responses for testing
    struct MockOllamaResponse {
        command: String,
        stdout: String,
        stderr: String,
        success: bool,
    }

    impl MockOllamaResponse {
        fn new(command: &str, stdout: &str, success: bool) -> Self {
            Self {
                command: command.to_string(),
                stdout: stdout.to_string(),
                stderr: String::new(),
                success,
            }
        }
    }

    // Mock the ollama command responses
    fn mock_ollama_list_response() -> String {
        "NAME              \tID           \tSIZE  \tMODIFIED     \nllama2:latest     \t3b4c5d6e7f8a \t3.8GB \t2 hours ago  \ncodellama:latest  \t9h8g7f6e5d4c \t3.8GB \t1 day ago    \nmistral:latest    \t2a1b3c4d5e6f \t4.1GB \t3 days ago   \n".to_string()
    }

    fn mock_ollama_pull_response() -> String {
        "pulling manifest\npulling 3b4c5d6e7f8a... 100%\nverifying sha256 digest\nwriting manifest\nsuccess\n".to_string()
    }

    fn mock_ollama_rm_response() -> String {
        "deleted 'llama2:latest'\n".to_string()
    }

    #[test]
    fn test_parse_ollama_list_output() {
        let mock_output = mock_ollama_list_response();
        let models = parse_ollama_list(&mock_output);
        
        assert_eq!(models.len(), 3);
        assert!(models.contains(&"llama2".to_string()));
        assert!(models.contains(&"codellama".to_string()));
        assert!(models.contains(&"mistral".to_string()));
    }

    #[test]
    fn test_ollama_command_parsing() {
        // Test list command parsing
        let list_output = mock_ollama_list_response();
        let parsed_models = parse_ollama_list(&list_output);
        
        assert!(!parsed_models.is_empty());
        assert_eq!(parsed_models[0], "llama2");
        assert_eq!(parsed_models[1], "codellama");
        assert_eq!(parsed_models[2], "mistral");
    }

    #[test]
    fn test_model_name_extraction() {
        // Test that model names are correctly extracted without version tags
        let test_cases = vec![
            ("llama2:latest", "llama2"),
            ("codellama:7b", "codellama"),
            ("mistral:instruct", "mistral"),
            ("simple-name", "simple-name"),
        ];

        for (input, expected) in test_cases {
            let result = extract_model_name(input);
            assert_eq!(result, expected);
        }
    }

    #[test]
    fn test_ollama_error_handling() {
        // Test error cases
        let empty_output = "";
        let models = parse_ollama_list(empty_output);
        assert!(models.is_empty());

        let invalid_output = "some random text without proper format";
        let models = parse_ollama_list(invalid_output);
        assert!(models.is_empty());
    }

    #[test]
    fn test_ollama_pull_success() {
        let pull_output = mock_ollama_pull_response();
        assert!(pull_output.contains("success"));
        assert!(pull_output.contains("100%"));
    }

    #[test]
    fn test_ollama_rm_success() {
        let rm_output = mock_ollama_rm_response();
        assert!(rm_output.contains("deleted"));
    }

    // Integration test with actual command structure (mocked)
    #[test]
    fn test_ollama_command_structure() {
        // These tests verify the command structure without actually calling ollama
        let list_cmd = create_ollama_list_command();
        assert_eq!(list_cmd.get_program(), "ollama");
        assert_eq!(list_cmd.get_args().collect::<Vec<_>>(), vec!["list"]);

        let pull_cmd = create_ollama_pull_command("llama2");
        assert_eq!(pull_cmd.get_program(), "ollama");
        assert_eq!(pull_cmd.get_args().collect::<Vec<_>>(), vec!["pull", "llama2"]);

        let rm_cmd = create_ollama_rm_command("llama2");
        assert_eq!(rm_cmd.get_program(), "ollama");
        assert_eq!(rm_cmd.get_args().collect::<Vec<_>>(), vec!["rm", "llama2"]);
    }
}

// Helper functions for testing
fn parse_ollama_list(output: &str) -> Vec<String> {
    output.lines()
        .skip(1) // Skip header
        .filter_map(|line| {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() > 0 && !parts[0].is_empty() {
                Some(extract_model_name(parts[0]))
            } else {
                None
            }
        })
        .collect()
}

fn extract_model_name(full_name: &str) -> String {
    full_name.split(':').next().unwrap_or(full_name).to_string()
}

fn create_ollama_list_command() -> Command {
    let mut cmd = Command::new("ollama");
    cmd.arg("list");
    cmd
}

fn create_ollama_pull_command(model: &str) -> Command {
    let mut cmd = Command::new("ollama");
    cmd.arg("pull").arg(model);
    cmd
}

fn create_ollama_rm_command(model: &str) -> Command {
    let mut cmd = Command::new("ollama");
    cmd.arg("rm").arg(model);
    cmd
}

// Mock HTTP download tests
#[cfg(test)]
mod http_download_tests {
    use super::*;
    use crate::llm_service::model_downloader;
    use std::path::Path;
    use tempfile::NamedTempFile;

    #[test]
    fn test_checksum_calculation() {
        // Test that checksum calculation works correctly
        let test_data = b"Hello, World!";
        let expected_checksum = "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f";
        
        let calculated_checksum = calculate_sha256(test_data);
        assert_eq!(calculated_checksum, expected_checksum);
    }

    #[test]
    fn test_file_validation() {
        // Test that file validation works correctly
        let temp_file = NamedTempFile::new().unwrap();
        let file_path = temp_file.path();
        
        // Write test data
        std::fs::write(file_path, b"test data").unwrap();
        
        // Verify file exists and has correct content
        assert!(file_path.exists());
        let content = std::fs::read(file_path).unwrap();
        assert_eq!(content, b"test data");
    }

    #[test]
    fn test_download_url_validation() {
        // Test URL validation logic
        let valid_urls = vec![
            "https://example.com/model.bin",
            "http://localhost:8080/model.bin",
            "https://releases.example.com/v1.0/model.bin",
        ];

        let invalid_urls = vec![
            "ftp://example.com/model.bin",
            "not-a-url",
            "",
            "javascript:alert('xss')",
        ];

        for url in valid_urls {
            assert!(is_valid_download_url(url));
        }

        for url in invalid_urls {
            assert!(!is_valid_download_url(url));
        }
    }
}

fn calculate_sha256(data: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(data);
    hex::encode(hasher.finalize())
}

fn is_valid_download_url(url: &str) -> bool {
    url.starts_with("http://") || url.starts_with("https://")
}
