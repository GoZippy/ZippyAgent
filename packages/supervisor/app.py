import os, socket


def find_free_port(start: int = 8000) -> int:
    port = start
    while port < 9000:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("localhost", port)) != 0:
                return port
        port += 1
    raise RuntimeError("No free port in 8000-8999 range")

if __name__ == "__main__":
    import uvicorn

    port_env = int(os.getenv("SUPERVISOR_PORT", "0"))
    port = port_env or find_free_port(8000)
    uvicorn.run("supervisor.app:app", host="0.0.0.0", port=port, reload=True)

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List

app = FastAPI(title="ZippyAgent Supervisor", version="0.1.0")

# --- Data Models -----------------------------------------------------------------
class Agent(BaseModel):
    name: str
    status: str = "idle"

class Motion(BaseModel):
    title: str
    description: str
    status: str = "pending"

# --- In-memory stores -------------------------------------------------------------
AGENTS: dict[str, Agent] = {}
MOTIONS: List[Motion] = []

# --- API Endpoints ----------------------------------------------------------------
@app.post("/register", response_model=Agent)
def register_agent(agent: Agent):
    if agent.name in AGENTS:
        raise HTTPException(status_code=409, detail="Agent already registered")
    AGENTS[agent.name] = agent
    return agent

@app.get("/agents", response_model=List[Agent])
def list_agents():
    return list(AGENTS.values())

@app.post("/motions", response_model=Motion)
def create_motion(motion: Motion):
    MOTIONS.append(motion)
    return motion

@app.get("/motions", response_model=List[Motion])
def list_motions():
    return MOTIONS 