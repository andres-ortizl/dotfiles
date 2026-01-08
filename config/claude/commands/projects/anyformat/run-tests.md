# Run Tests

Execute the test suite for anyformat-backend services in a Dockerized environment.

## When to use

- After implementing or modifying backend logic, models, or API endpoints
- When debugging a failing test or investigating test behavior
- Before committing code to verify no regressions
- When validating that a bug fix resolves the reported issue

## Primary command

```bash
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -vvv -n auto --maxfail=1
```

## Service-specific commands

### anyformat-core (Dramatiq workers)
```bash
# Full test suite
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -vvv -n auto --maxfail=1

# Exclude LLM and minio-dependent tests
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -vvv -n auto -m "not llm and not minio"
```

### Backend (Django)
```bash
docker-compose run --rm backend pytest -n auto
```

### External API
```bash
# Unit tests only
docker-compose run --rm external-api pytest -k unit -n auto

# All tests
docker-compose run --rm external-api pytest
```

## Test markers

| Marker | Description |
|--------|-------------|
| `unit` | Fast tests with no external dependencies |
| `smoke` | Integration tests requiring running services |
| `integration` | Full integration tests |
| `minio` | Requires AWS/MinIO credentials |
| `llm` | Requires LLM API access |

## Running specific tests

```bash
# Single test file
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_specific.py -vvv

# Single test function
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_specific.py::test_function_name -vvv

# Tests matching a pattern
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -k "keyword" -vvv
```

## Debugging

```bash
# With print statements visible
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_file.py -vvv -s

# With debugger (drops into pdb on failure)
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_file.py --pdb

# Without parallelization for clearer output
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_file.py -vvv --maxfail=1
```

## Prerequisites

Ensure Docker services are running:
```bash
docker-compose up -d postgres redis rabbitmq minio
```
