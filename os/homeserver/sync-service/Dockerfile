FROM ghcr.io/astral-sh/uv:python3.12-alpine

WORKDIR /app

# Install bash, git, and docker CLI
RUN apk add --no-cache bash git docker-cli

# Configure git to trust the repo directory
RUN git config --global safe.directory /homeserver

# Copy dependency files
COPY pyproject.toml .

# Install dependencies
RUN uv pip install --system --no-cache -r pyproject.toml

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the application
CMD ["fastapi", "run", "app.py", "--host", "0.0.0.0", "--port", "8000"]
