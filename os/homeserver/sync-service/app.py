import asyncio
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

app = FastAPI(title="Homeserver Sync Service")
templates = Jinja2Templates(directory="templates")

# Configuration
REPO_PATH = Path("/dotfiles")
COMPOSE_FILE = REPO_PATH / "os" / "homeserver" / "docker-compose.yml"


class SyncStatus:
    def __init__(self):
        self.last_sync: datetime | None = None
        self.status: str = "idle"
        self.logs: list[str] = []
        self.is_syncing: bool = False

    def add_log(self, message: str):
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.logs.append(f"[{timestamp}] {message}")
        if len(self.logs) > 50:
            self.logs.pop(0)


sync_status = SyncStatus()
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

    try:
        await broadcast_message("🔄 Starting sync process...")

        # Git pull
        await broadcast_message("📥 Pulling latest changes from git...")
        returncode, output = await run_command("git pull", REPO_PATH)

        if returncode != 0:
            await broadcast_message("❌ Git pull failed")
            sync_status.status = "error"
            return False

        if "Already up to date" in output:
            await broadcast_message("✅ Already up to date - no changes")
        else:
            await broadcast_message("✅ Git pull successful")

        # Docker compose up
        await broadcast_message("🐳 Updating Docker containers...")
        returncode, output = await run_command(
            "docker compose up -d --remove-orphans",
            COMPOSE_FILE.parent,
        )

        if returncode != 0:
            await broadcast_message("❌ Docker compose failed")
            sync_status.status = "error"
            return False

        await broadcast_message("✅ Docker containers updated")

        # Cleanup old images
        await broadcast_message("🧹 Cleaning up old images...")
        await run_command("docker image prune -f", COMPOSE_FILE.parent)

        await broadcast_message("✨ Sync completed successfully!")
        sync_status.status = "success"
        sync_status.last_sync = datetime.now()

        return True

    except Exception as e:
        await broadcast_message(f"❌ Error: {e!s}")
        sync_status.status = "error"
        return False
    finally:
        sync_status.is_syncing = False


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
