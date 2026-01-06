import asyncio
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlmodel import Field, Session, SQLModel, create_engine, select

app = FastAPI(title="Homeserver Sync Service")
templates = Jinja2Templates(directory="templates")

# Configuration
REPO_PATH = Path("/dotfiles")
COMPOSE_FILE = REPO_PATH / "os" / "homeserver" / "docker-compose.yml"
DB_PATH = Path("/app/data/sync.db")

# Ensure data directory exists
DB_PATH.parent.mkdir(parents=True, exist_ok=True)


# Database models
class SyncLog(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    timestamp: datetime = Field(default_factory=datetime.now)
    status: str
    message: str


class SyncHistory(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    started_at: datetime
    completed_at: datetime | None = None
    status: str
    git_output: str = ""
    docker_output: str = ""


# Create database
engine = create_engine(f"sqlite:///{DB_PATH}")
SQLModel.metadata.create_all(engine)


class SyncStatus:
    def __init__(self):
        self.last_sync: datetime | None = None
        self.status: str = "idle"
        self.logs: list[str] = []
        self.is_syncing: bool = False
        self.current_history_id: int | None = None

    def add_log(self, message: str):
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.logs.append(log_entry)
        if len(self.logs) > 50:
            self.logs.pop(0)

        # Save to database
        with Session(engine) as session:
            log = SyncLog(
                timestamp=datetime.now(),
                status=self.status,
                message=message,
            )
            session.add(log)
            session.commit()

    def load_last_sync(self):
        """Load last sync time from database"""
        with Session(engine) as session:
            statement = (
                select(SyncHistory)
                .where(
                    SyncHistory.status == "success",
                )
                .order_by(SyncHistory.completed_at.desc())
                .limit(1)
            )
            result = session.exec(statement).first()
            if result:
                self.last_sync = result.completed_at


sync_status = SyncStatus()
sync_status.load_last_sync()
active_connections: list[WebSocket] = []


async def broadcast_message(message: str):
    """Broadcast message to all connected WebSocket clients"""
    sync_status.add_log(message)
    disconnected = []
    for connection in active_connections:
        try:
            await connection.send_json(
                {
                    "type": "log",
                    "message": message,
                    "timestamp": datetime.now().isoformat(),
                },
            )
        except:
            disconnected.append(connection)

    for conn in disconnected:
        active_connections.remove(conn)


async def run_command(cmd: str, cwd: Path) -> tuple[int, str]:
    """Run shell command and return exit code and output"""
    await broadcast_message(f"$ {cmd}")

    process = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        cwd=cwd,
        executable="/bin/bash",
    )

    output = []
    while True:
        line = await process.stdout.readline()
        if not line:
            break
        decoded = line.decode().strip()
        if decoded:
            output.append(decoded)
            await broadcast_message(decoded)

    await process.wait()
    return process.returncode, "\n".join(output)


async def sync_and_update():
    """Main sync function"""
    if sync_status.is_syncing:
        await broadcast_message("⚠️  Sync already in progress")
        return False

    sync_status.is_syncing = True
    sync_status.status = "syncing"

    # Create history record
    with Session(engine) as session:
        history = SyncHistory(
            started_at=datetime.now(),
            status="running",
        )
        session.add(history)
        session.commit()
        session.refresh(history)
        sync_status.current_history_id = history.id

    git_output = ""
    docker_output = ""

    try:
        await broadcast_message("🔄 Starting sync process...")

        # Git pull
        await broadcast_message("📥 Pulling latest changes from git...")
        returncode, output = await run_command("git pull", REPO_PATH)
        git_output = output

        if returncode != 0:
            await broadcast_message("❌ Git pull failed")
            sync_status.status = "error"
            _update_history(
                sync_status.current_history_id,
                "error",
                git_output,
                docker_output,
            )
            return False

        if "Already up to date" in output:
            await broadcast_message("✅ Already up to date - no changes to apply")
            await broadcast_message("✨ Everything in sync!")
        else:
            await broadcast_message("✅ Git pull successful")

            # Schedule docker compose to run after we finish responding
            await broadcast_message("🐳 Scheduling container updates...")
            await broadcast_message("⚠️  Connection will drop during restart")

            # Run in background with delay so this service can respond first
            returncode, output = await run_command(
                "sh -c 'sleep 3 && docker compose up -d --remove-orphans && docker image prune -f' > /tmp/compose.log 2>&1 &",
                COMPOSE_FILE.parent,
            )
            docker_output = "Scheduled for background execution"

            await broadcast_message(
                "✅ Update scheduled - containers will restart in 3 seconds"
            )
            await broadcast_message("✨ Sync initiated successfully!")
        sync_status.status = "success"
        sync_status.last_sync = datetime.now()
        _update_history(
            sync_status.current_history_id,
            "success",
            git_output,
            docker_output,
        )

        return True

    except Exception as e:
        await broadcast_message(f"❌ Error: {e!s}")
        sync_status.status = "error"
        _update_history(
            sync_status.current_history_id,
            "error",
            git_output,
            docker_output,
        )
        return False
    finally:
        sync_status.is_syncing = False


def _update_history(history_id: int, status: str, git_output: str, docker_output: str):
    """Update sync history record"""
    with Session(engine) as session:
        history = session.get(SyncHistory, history_id)
        if history:
            history.completed_at = datetime.now()
            history.status = status
            history.git_output = git_output
            history.docker_output = docker_output
            session.add(history)
            session.commit()


@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    """Serve the main UI"""
    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "last_sync": sync_status.last_sync.strftime("%Y-%m-%d %H:%M:%S")
            if sync_status.last_sync
            else "Never",
            "status": sync_status.status,
        },
    )


@app.post("/sync")
async def trigger_sync():
    """Trigger sync process"""
    if sync_status.is_syncing:
        return {"status": "error", "message": "Sync already in progress"}

    asyncio.create_task(sync_and_update())
    return {"status": "started", "message": "Sync process started"}


@app.get("/status")
async def get_status():
    """Get current sync status"""
    return {
        "status": sync_status.status,
        "last_sync": sync_status.last_sync.isoformat()
        if sync_status.last_sync
        else None,
        "is_syncing": sync_status.is_syncing,
        "logs": sync_status.logs[-10:],
    }


@app.get("/history")
async def get_history(limit: int = 10):
    """Get sync history"""
    with Session(engine) as session:
        statement = (
            select(SyncHistory)
            .order_by(
                SyncHistory.started_at.desc(),
            )
            .limit(limit)
        )
        results = session.exec(statement).all()
        return [
            {
                "id": r.id,
                "started_at": r.started_at.isoformat(),
                "completed_at": r.completed_at.isoformat() if r.completed_at else None,
                "status": r.status,
                "duration": (r.completed_at - r.started_at).total_seconds()
                if r.completed_at
                else None,
            }
            for r in results
        ]


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time logs"""
    await websocket.accept()
    active_connections.append(websocket)

    # Send recent logs
    for log in sync_status.logs[-10:]:
        await websocket.send_json(
            {
                "type": "log",
                "message": log,
                "timestamp": datetime.now().isoformat(),
            },
        )

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        active_connections.remove(websocket)


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy"}
