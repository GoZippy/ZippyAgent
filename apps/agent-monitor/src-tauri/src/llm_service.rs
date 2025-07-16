pub mod ollama_cli {
    use std::process::Command;
    use thiserror::Error;

    #[derive(Error, Debug)]
    pub enum OllamaError {
        #[error("Command error: {0}")]
        CommandError(String),
    }

    pub fn list_models() -> Result<String, OllamaError> {
        Command::new("ollama")
            .arg("list")
            .output()
            .map_err(|e| OllamaError::CommandError(e.to_string()))
            .map(|output| String::from_utf8_lossy(&output.stdout).into_owned())
    }

    pub fn pull_model(model_name: &str) -> Result<String, OllamaError> {
        Command::new("ollama")
            .arg("pull")
            .arg(model_name)
            .status()
            .map_err(|e| OllamaError::CommandError(e.to_string()))
            .map(|_| format!("Model {} pulled successfully.", model_name))
    }

    pub fn remove_model(model_name: &str) -> Result<String, OllamaError> {
        Command::new("ollama")
            .arg("rm")
            .arg(model_name)
            .status()
            .map_err(|e| OllamaError::CommandError(e.to_string()))
            .map(|_| format!("Model {} removed successfully.", model_name))
    }

    pub fn update_models() -> Result<String, OllamaError> {
        Command::new("ollama")
            .arg("update")
            .status()
            .map_err(|e| OllamaError::CommandError(e.to_string()))
            .map(|_| "Models updated successfully.".to_string())
    }
}

pub mod model_downloader {
    use reqwest::Client;
    use sha2::{Digest, Sha256};
    use std::{fs::File, io::copy, path::Path};
    use thiserror::Error;

    #[derive(Error, Debug)]
    pub enum DownloadError {
        #[error("HTTP request error: {0}")]
        HttpRequestError(String),
        #[error("File I/O error: {0}")]
        FileIoError(String),
        #[error("Checksum mismatch")]
        ChecksumMismatch,
    }

    pub async fn download_model(url: &str, dest: &Path, expected_checksum: &str) -> Result<(), DownloadError> {
        let client = Client::new();
        let response = client
            .get(url)
            .send()
            .await
            .map_err(|e| DownloadError::HttpRequestError(e.to_string()))?
            .bytes()
            .await
            .map_err(|e| DownloadError::HttpRequestError(e.to_string()))?;

        let mut hasher = Sha256::new();
        hasher.update(&response);
        let actual_checksum = hex::encode(hasher.finalize());

        if actual_checksum != expected_checksum {
            return Err(DownloadError::ChecksumMismatch);
        }

        let mut file = File::create(dest).map_err(|e| DownloadError::FileIoError(e.to_string()))?;
        copy(&mut &*response, &mut file).map_err(|e| DownloadError::FileIoError(e.to_string()))?;

        Ok(())
    }
}
