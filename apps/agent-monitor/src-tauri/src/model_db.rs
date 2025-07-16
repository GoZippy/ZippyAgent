use serde::{Deserialize, Serialize};
use sqlx::{sqlite::SqlitePool, Row};
use std::collections::HashMap;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DatabaseError {
    #[error("Database error: {0}")]
    SqlxError(#[from] sqlx::Error),
    #[error("Migration error: {0}")]
    MigrationError(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelMetadata {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub size: Option<i64>,
    pub installed: bool,
    pub version: Option<String>,
    pub download_url: Option<String>,
    pub checksum: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallProgress {
    pub model_id: String,
    pub progress: f64,
    pub status: String,
    pub error: Option<String>,
}

pub struct ModelDatabase {
    pool: SqlitePool,
}

impl ModelDatabase {
    pub async fn new(database_url: &str) -> Result<Self, DatabaseError> {
        let pool = SqlitePool::connect(database_url).await?;
        
        // Create tables if they don't exist
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS models (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                size INTEGER,
                installed BOOLEAN NOT NULL DEFAULT FALSE,
                version TEXT,
                download_url TEXT,
                checksum TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
            "#,
        )
        .execute(&pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS install_progress (
                model_id TEXT PRIMARY KEY,
                progress REAL NOT NULL DEFAULT 0.0,
                status TEXT NOT NULL DEFAULT 'pending',
                error TEXT,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (model_id) REFERENCES models (id)
            )
            "#,
        )
        .execute(&pool)
        .await?;

        Ok(Self { pool })
    }

    pub async fn get_all_models(&self) -> Result<Vec<ModelMetadata>, DatabaseError> {
        let rows = sqlx::query(
            r#"
            SELECT id, name, description, size, installed, version, 
                   download_url, checksum, created_at, updated_at
            FROM models
            ORDER BY name
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut models = Vec::new();
        for row in rows {
            models.push(ModelMetadata {
                id: row.get("id"),
                name: row.get("name"),
                description: row.get("description"),
                size: row.get("size"),
                installed: row.get("installed"),
                version: row.get("version"),
                download_url: row.get("download_url"),
                checksum: row.get("checksum"),
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
            });
        }

        Ok(models)
    }

    pub async fn get_model(&self, id: &str) -> Result<Option<ModelMetadata>, DatabaseError> {
        let row = sqlx::query(
            r#"
            SELECT id, name, description, size, installed, version, 
                   download_url, checksum, created_at, updated_at
            FROM models
            WHERE id = ?
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            Ok(Some(ModelMetadata {
                id: row.get("id"),
                name: row.get("name"),
                description: row.get("description"),
                size: row.get("size"),
                installed: row.get("installed"),
                version: row.get("version"),
                download_url: row.get("download_url"),
                checksum: row.get("checksum"),
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
            }))
        } else {
            Ok(None)
        }
    }

    pub async fn insert_or_update_model(&self, model: &ModelMetadata) -> Result<(), DatabaseError> {
        sqlx::query(
            r#"
            INSERT OR REPLACE INTO models 
            (id, name, description, size, installed, version, download_url, checksum, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&model.id)
        .bind(&model.name)
        .bind(&model.description)
        .bind(model.size)
        .bind(model.installed)
        .bind(&model.version)
        .bind(&model.download_url)
        .bind(&model.checksum)
        .bind(model.created_at)
        .bind(model.updated_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn update_model_installed_status(&self, id: &str, installed: bool) -> Result<(), DatabaseError> {
        sqlx::query(
            r#"
            UPDATE models 
            SET installed = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            "#,
        )
        .bind(installed)
        .bind(id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn remove_model(&self, id: &str) -> Result<(), DatabaseError> {
        sqlx::query("DELETE FROM models WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    pub async fn get_install_progress(&self, model_id: &str) -> Result<Option<InstallProgress>, DatabaseError> {
        let row = sqlx::query(
            r#"
            SELECT model_id, progress, status, error
            FROM install_progress
            WHERE model_id = ?
            "#,
        )
        .bind(model_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            Ok(Some(InstallProgress {
                model_id: row.get("model_id"),
                progress: row.get("progress"),
                status: row.get("status"),
                error: row.get("error"),
            }))
        } else {
            Ok(None)
        }
    }

    pub async fn update_install_progress(
        &self,
        model_id: &str,
        progress: f64,
        status: &str,
        error: Option<&str>,
    ) -> Result<(), DatabaseError> {
        sqlx::query(
            r#"
            INSERT OR REPLACE INTO install_progress 
            (model_id, progress, status, error, updated_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            "#,
        )
        .bind(model_id)
        .bind(progress)
        .bind(status)
        .bind(error)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn get_all_install_progress(&self) -> Result<HashMap<String, InstallProgress>, DatabaseError> {
        let rows = sqlx::query(
            r#"
            SELECT model_id, progress, status, error
            FROM install_progress
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut progress_map = HashMap::new();
        for row in rows {
            let progress = InstallProgress {
                model_id: row.get("model_id"),
                progress: row.get("progress"),
                status: row.get("status"),
                error: row.get("error"),
            };
            progress_map.insert(progress.model_id.clone(), progress);
        }

        Ok(progress_map)
    }

    pub async fn clear_install_progress(&self, model_id: &str) -> Result<(), DatabaseError> {
        sqlx::query("DELETE FROM install_progress WHERE model_id = ?")
            .bind(model_id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }
}
