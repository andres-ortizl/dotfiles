FROM python:3.11-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app
CMD ["install.sh"]
