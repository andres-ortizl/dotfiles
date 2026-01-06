FROM ghcr.io/astral-sh/uv:python3.12-alpine

WORKDIR /app

# Install bash, git, docker CLI and docker-compose
RUN apk add --no-cache bash git docker-cli docker-cli-compose

# Configure git to trust the dotfiles repository
RUN git config --global --add safe.directory /dotfiles

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
