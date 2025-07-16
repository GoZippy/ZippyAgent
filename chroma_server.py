#!/usr/bin/env python3
"""
ChromaDB Server for ZippyAgent Vector Store
Lightweight vector database server that provides REST API for embeddings storage and retrieval
"""

import os
import sys
import argparse
import uvicorn
from pathlib import Path
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Default paths
DEFAULT_PERSIST_DIR = "./data/vector_db"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8000

class EmbeddingRequest(BaseModel):
    collection_name: str
    documents: List[str]
    metadata: Optional[List[Dict[str, Any]]] = None
    ids: Optional[List[str]] = None

class QueryRequest(BaseModel):
    collection_name: str
    query_texts: List[str]
    n_results: int = 10
    where: Optional[Dict[str, Any]] = None

class ChromaDBServer:
    def __init__(self, persist_dir: str = DEFAULT_PERSIST_DIR):
        self.persist_dir = Path(persist_dir)
        self.persist_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize ChromaDB client
        self.client = chromadb.PersistentClient(
            path=str(self.persist_dir),
            settings=Settings(
                anonymized_telemetry=False,
                allow_reset=True
            )
        )
        
        # Default embedding function
        self.embedding_function = embedding_functions.DefaultEmbeddingFunction()
        
        logger.info(f"ChromaDB server initialized with persistence at: {self.persist_dir}")

    def get_or_create_collection(self, name: str):
        """Get or create a collection with the given name"""
        try:
            return self.client.get_collection(name=name, embedding_function=self.embedding_function)
        except Exception:
            return self.client.create_collection(name=name, embedding_function=self.embedding_function)

    def add_documents(self, collection_name: str, documents: List[str], 
                     metadata: Optional[List[Dict[str, Any]]] = None,
                     ids: Optional[List[str]] = None):
        """Add documents to a collection"""
        collection = self.get_or_create_collection(collection_name)
        
        # Generate IDs if not provided
        if ids is None:
            ids = [f"doc_{i}" for i in range(len(documents))]
        
        # Add documents
        collection.add(
            documents=documents,
            metadatas=metadata,
            ids=ids
        )
        
        return {"status": "success", "added_count": len(documents)}

    def query_collection(self, collection_name: str, query_texts: List[str], 
                        n_results: int = 10, where: Optional[Dict[str, Any]] = None):
        """Query a collection"""
        try:
            collection = self.client.get_collection(name=collection_name, embedding_function=self.embedding_function)
            
            results = collection.query(
                query_texts=query_texts,
                n_results=n_results,
                where=where
            )
            
            return results
        except Exception as e:
            raise HTTPException(status_code=404, detail=f"Collection '{collection_name}' not found: {str(e)}")

    def list_collections(self):
        """List all collections"""
        collections = self.client.list_collections()
        return [{"name": col.name, "count": col.count()} for col in collections]

    def delete_collection(self, collection_name: str):
        """Delete a collection"""
        try:
            self.client.delete_collection(name=collection_name)
            return {"status": "success", "message": f"Collection '{collection_name}' deleted"}
        except Exception as e:
            raise HTTPException(status_code=404, detail=f"Collection '{collection_name}' not found: {str(e)}")

# Initialize server
chroma_server = None

def create_app(persist_dir: str = DEFAULT_PERSIST_DIR) -> FastAPI:
    """Create FastAPI application"""
    global chroma_server
    
    app = FastAPI(
        title="ZippyAgent ChromaDB Server",
        description="Vector database server for ZippyAgent embeddings",
        version="1.0.0"
    )
    
    chroma_server = ChromaDBServer(persist_dir)
    
    @app.get("/")
    async def root():
        return {"message": "ZippyAgent ChromaDB Server", "status": "running"}
    
    @app.get("/health")
    async def health():
        return {"status": "healthy", "persist_dir": str(chroma_server.persist_dir)}
    
    @app.get("/collections")
    async def list_collections():
        return chroma_server.list_collections()
    
    @app.post("/collections/{collection_name}/add")
    async def add_documents(collection_name: str, request: EmbeddingRequest):
        try:
            result = chroma_server.add_documents(
                collection_name=collection_name,
                documents=request.documents,
                metadata=request.metadata,
                ids=request.ids
            )
            return result
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.post("/collections/{collection_name}/query")
    async def query_collection(collection_name: str, request: QueryRequest):
        try:
            result = chroma_server.query_collection(
                collection_name=collection_name,
                query_texts=request.query_texts,
                n_results=request.n_results,
                where=request.where
            )
            return result
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.delete("/collections/{collection_name}")
    async def delete_collection(collection_name: str):
        return chroma_server.delete_collection(collection_name)
    
    @app.get("/collections/{collection_name}/count")
    async def get_collection_count(collection_name: str):
        try:
            collection = chroma_server.client.get_collection(name=collection_name)
            return {"collection": collection_name, "count": collection.count()}
        except Exception as e:
            raise HTTPException(status_code=404, detail=f"Collection '{collection_name}' not found: {str(e)}")
    
    return app

def main():
    parser = argparse.ArgumentParser(description="ZippyAgent ChromaDB Server")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Host to bind to")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to bind to")
    parser.add_argument("--persist-dir", default=DEFAULT_PERSIST_DIR, help="Directory to persist data")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload for development")
    
    args = parser.parse_args()
    
    # Create the FastAPI app
    app = create_app(args.persist_dir)
    
    logger.info(f"Starting ChromaDB server on {args.host}:{args.port}")
    logger.info(f"Persistence directory: {args.persist_dir}")
    
    # Run the server
    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
        reload=args.reload,
        log_level="info"
    )

if __name__ == "__main__":
    main()
