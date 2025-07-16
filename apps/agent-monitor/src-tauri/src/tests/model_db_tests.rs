use crate::model_db::{ModelDatabase, ModelMetadata, InstallProgress, DatabaseError};
use chrono::Utc;
use std::collections::HashMap;
use tempfile::NamedTempFile;

#[cfg(test)]
mod tests {
    use super::*;

    async fn create_test_db() -> Result<ModelDatabase, DatabaseError> {
        let temp_file = NamedTempFile::new().unwrap();
        let db_path = format!("sqlite:{}", temp_file.path().to_str().unwrap());
        ModelDatabase::new(&db_path).await
    }

    fn create_test_model(id: &str, name: &str, installed: bool) -> ModelMetadata {
        ModelMetadata {
            id: id.to_string(),
            name: name.to_string(),
            description: Some(format!("Test model {}", name)),
            size: Some(1000000000), // 1GB
            installed,
            version: Some("1.0".to_string()),
            download_url: Some("https://example.com/model.bin".to_string()),
            checksum: Some("abc123".to_string()),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    #[tokio::test]
    async fn test_database_initialization() {
        let db = create_test_db().await;
        assert!(db.is_ok());
    }

    #[tokio::test]
    async fn test_insert_and_retrieve_model() {
        let db = create_test_db().await.unwrap();
        let test_model = create_test_model("test-model", "Test Model", false);

        // Insert model
        let result = db.insert_or_update_model(&test_model).await;
        assert!(result.is_ok());

        // Retrieve model
        let retrieved = db.get_model("test-model").await.unwrap();
        assert!(retrieved.is_some());
        
        let retrieved_model = retrieved.unwrap();
        assert_eq!(retrieved_model.id, "test-model");
        assert_eq!(retrieved_model.name, "Test Model");
        assert_eq!(retrieved_model.installed, false);
    }

    #[tokio::test]
    async fn test_list_all_models() {
        let db = create_test_db().await.unwrap();
        
        // Insert multiple models
        let models = vec![
            create_test_model("model1", "Model 1", true),
            create_test_model("model2", "Model 2", false),
            create_test_model("model3", "Model 3", true),
        ];

        for model in &models {
            db.insert_or_update_model(model).await.unwrap();
        }

        // Retrieve all models
        let all_models = db.get_all_models().await.unwrap();
        assert_eq!(all_models.len(), 3);
        
        // Verify models are sorted by name
        assert_eq!(all_models[0].name, "Model 1");
        assert_eq!(all_models[1].name, "Model 2");
        assert_eq!(all_models[2].name, "Model 3");
    }

    #[tokio::test]
    async fn test_update_model_installed_status() {
        let db = create_test_db().await.unwrap();
        let test_model = create_test_model("test-model", "Test Model", false);

        // Insert model
        db.insert_or_update_model(&test_model).await.unwrap();

        // Update installed status
        db.update_model_installed_status("test-model", true).await.unwrap();

        // Verify update
        let updated_model = db.get_model("test-model").await.unwrap().unwrap();
        assert_eq!(updated_model.installed, true);
    }

    #[tokio::test]
    async fn test_remove_model() {
        let db = create_test_db().await.unwrap();
        let test_model = create_test_model("test-model", "Test Model", false);

        // Insert model
        db.insert_or_update_model(&test_model).await.unwrap();

        // Verify model exists
        assert!(db.get_model("test-model").await.unwrap().is_some());

        // Remove model
        db.remove_model("test-model").await.unwrap();

        // Verify model is removed
        assert!(db.get_model("test-model").await.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_install_progress_tracking() {
        let db = create_test_db().await.unwrap();

        // Test inserting progress
        db.update_install_progress("test-model", 25.5, "downloading", None).await.unwrap();
        
        let progress = db.get_install_progress("test-model").await.unwrap();
        assert!(progress.is_some());
        
        let progress = progress.unwrap();
        assert_eq!(progress.model_id, "test-model");
        assert_eq!(progress.progress, 25.5);
        assert_eq!(progress.status, "downloading");
        assert!(progress.error.is_none());
    }

    #[tokio::test]
    async fn test_install_progress_with_error() {
        let db = create_test_db().await.unwrap();

        // Test inserting progress with error
        db.update_install_progress("test-model", 50.0, "failed", Some("Network error")).await.unwrap();
        
        let progress = db.get_install_progress("test-model").await.unwrap().unwrap();
        assert_eq!(progress.progress, 50.0);
        assert_eq!(progress.status, "failed");
        assert_eq!(progress.error, Some("Network error".to_string()));
    }

    #[tokio::test]
    async fn test_get_all_install_progress() {
        let db = create_test_db().await.unwrap();

        // Insert multiple progress records
        db.update_install_progress("model1", 100.0, "completed", None).await.unwrap();
        db.update_install_progress("model2", 75.0, "downloading", None).await.unwrap();
        db.update_install_progress("model3", 0.0, "failed", Some("Error")).await.unwrap();

        let all_progress = db.get_all_install_progress().await.unwrap();
        assert_eq!(all_progress.len(), 3);
        
        assert!(all_progress.contains_key("model1"));
        assert!(all_progress.contains_key("model2"));
        assert!(all_progress.contains_key("model3"));
        
        assert_eq!(all_progress["model1"].status, "completed");
        assert_eq!(all_progress["model2"].status, "downloading");
        assert_eq!(all_progress["model3"].status, "failed");
    }

    #[tokio::test]
    async fn test_clear_install_progress() {
        let db = create_test_db().await.unwrap();

        // Insert progress
        db.update_install_progress("test-model", 50.0, "downloading", None).await.unwrap();
        
        // Verify progress exists
        assert!(db.get_install_progress("test-model").await.unwrap().is_some());

        // Clear progress
        db.clear_install_progress("test-model").await.unwrap();

        // Verify progress is cleared
        assert!(db.get_install_progress("test-model").await.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_update_existing_model() {
        let db = create_test_db().await.unwrap();
        let mut test_model = create_test_model("test-model", "Test Model", false);

        // Insert original model
        db.insert_or_update_model(&test_model).await.unwrap();

        // Update model data
        test_model.name = "Updated Model".to_string();
        test_model.installed = true;
        test_model.version = Some("2.0".to_string());

        // Update model
        db.insert_or_update_model(&test_model).await.unwrap();

        // Verify update
        let updated_model = db.get_model("test-model").await.unwrap().unwrap();
        assert_eq!(updated_model.name, "Updated Model");
        assert_eq!(updated_model.installed, true);
        assert_eq!(updated_model.version, Some("2.0".to_string()));
    }

    #[tokio::test]
    async fn test_database_error_handling() {
        // Test with invalid database path
        let result = ModelDatabase::new("invalid://path").await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_model_filtering_and_search() {
        let db = create_test_db().await.unwrap();
        
        // Insert test models with different properties
        let models = vec![
            create_test_model("llama2", "Llama 2", true),
            create_test_model("codellama", "Code Llama", false),
            create_test_model("mistral", "Mistral", true),
        ];

        for model in &models {
            db.insert_or_update_model(model).await.unwrap();
        }

        let all_models = db.get_all_models().await.unwrap();
        
        // Test filtering installed models
        let installed_models: Vec<_> = all_models.iter().filter(|m| m.installed).collect();
        assert_eq!(installed_models.len(), 2);
        
        // Test filtering by name pattern
        let llama_models: Vec<_> = all_models.iter().filter(|m| m.name.contains("Llama")).collect();
        assert_eq!(llama_models.len(), 2);
    }

    #[tokio::test]
    async fn test_concurrent_database_operations() {
        let db = create_test_db().await.unwrap();
        
        // Test concurrent insertions
        let handles = (0..10).map(|i| {
            let model = create_test_model(&format!("model{}", i), &format!("Model {}", i), false);
            let db_clone = &db; // Note: in real async code, you'd need proper cloning
            tokio::spawn(async move {
                db_clone.insert_or_update_model(&model).await
            })
        });

        // Wait for all operations to complete
        for handle in handles {
            handle.await.unwrap().unwrap();
        }

        // Verify all models were inserted
        let all_models = db.get_all_models().await.unwrap();
        assert_eq!(all_models.len(), 10);
    }
}

// Additional integration tests
#[cfg(test)]
mod integration_tests {
    use super::*;

    #[tokio::test]
    async fn test_complete_model_lifecycle() {
        let db = create_test_db().await.unwrap();
        let model_id = "lifecycle-test";
        
        // 1. Insert new model
        let new_model = create_test_model(model_id, "Lifecycle Test", false);
        db.insert_or_update_model(&new_model).await.unwrap();
        
        // 2. Start installation progress
        db.update_install_progress(model_id, 0.0, "starting", None).await.unwrap();
        
        // 3. Update progress
        db.update_install_progress(model_id, 50.0, "downloading", None).await.unwrap();
        
        // 4. Complete installation
        db.update_install_progress(model_id, 100.0, "completed", None).await.unwrap();
        db.update_model_installed_status(model_id, true).await.unwrap();
        
        // 5. Verify final state
        let final_model = db.get_model(model_id).await.unwrap().unwrap();
        assert!(final_model.installed);
        
        let final_progress = db.get_install_progress(model_id).await.unwrap().unwrap();
        assert_eq!(final_progress.progress, 100.0);
        assert_eq!(final_progress.status, "completed");
        
        // 6. Clean up
        db.clear_install_progress(model_id).await.unwrap();
        db.remove_model(model_id).await.unwrap();
        
        // 7. Verify cleanup
        assert!(db.get_model(model_id).await.unwrap().is_none());
        assert!(db.get_install_progress(model_id).await.unwrap().is_none());
    }
}
