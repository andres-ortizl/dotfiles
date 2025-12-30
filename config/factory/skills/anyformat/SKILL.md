---
name: run-tests
description: Run the test suite for anyformat-backend services using Docker Compose. Use when you need to validate code changes, debug failing tests, or verify that implementations work correctly before committing.
---
# Skill: Run Tests

## Purpose

Execute the test suite for anyformat-backend services in a Dockerized environment, ensuring code changes are validated against the full test infrastructure including database, message broker, and object storage dependencies.

## When to use this skill

- After implementing or modifying backend logic, models, or API endpoints.
- When debugging a failing test or investigating test behavior.
- Before committing code to verify no regressions were introduced.
- When validating that a bug fix resolves the reported issue.

## Primary command

```bash
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -vvv -n auto --maxfail=1
```

### Flag breakdown

| Flag | Purpose |
|------|---------|
| `--rm` | Remove the container after the test run completes |
| `--remove-orphans` | Clean up any orphaned containers from previous runs |
| `-vvv` | Maximum verbosity for detailed test output |
| `-n auto` | Parallel execution using all available CPU cores (pytest-xdist) |
| `--maxfail=1` | Stop after the first failure for faster feedback |

## Service-specific test commands

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

Filter tests using pytest markers:

| Marker | Description |
|--------|-------------|
| `unit` | Fast tests with no external dependencies |
| `smoke` | Integration tests requiring running services |
| `integration` | Full integration tests |
| `minio` | Requires AWS/MinIO credentials |
| `llm` | Requires LLM API access |

### Example usage

```bash
# Run only unit tests
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -m unit -vvv

# Skip tests requiring external services
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -m "not llm and not minio" -vvv -n auto
```

## Running specific tests

```bash
# Single test file
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_specific.py -vvv

# Single test function
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_specific.py::test_function_name -vvv

# Tests matching a pattern
docker-compose run --rm --remove-orphans anyformat-core pytest tests/ -k "keyword" -vvv
```

## Prerequisites

Ensure Docker services are running:

```bash
# Start infrastructure services
docker-compose up -d postgres redis rabbitmq minio

# Or start all services
docker-compose up -d
```

## Infrastructure dependencies

The test environment requires:

- **postgres**: PostgreSQL 16.4 database
- **redis**: Caching and session storage
- **rabbitmq**: Message broker for async tasks
- **minio**: S3-compatible object storage (for tests marked `minio`)
- **litellm**: LLM API proxy (for tests marked `llm`)

## Interpreting results

### Success output

```
==================== X passed in Y.YYs ====================
```

### Failure output

Look for:
1. **FAILED** lines indicating which tests failed
2. **AssertionError** or exception details
3. **Short test summary** at the end listing all failures

### Common failure patterns

| Pattern | Likely cause |
|---------|--------------|
| `Connection refused` | Infrastructure services not running |
| `relation does not exist` | Database migrations not applied |
| `timeout` | Service startup delay or deadlock |
| `ModuleNotFoundError` | Missing dependency or import path issue |

## Debugging failing tests

```bash
# Run with print statements visible
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_file.py -vvv -s

# Run with debugger (drops into pdb on failure)
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_file.py --pdb

# Run without parallelization for clearer output
docker-compose run --rm --remove-orphans anyformat-core pytest tests/test_file.py -vvv --maxfail=1
```

## Verification checklist

The skill is complete when:

- [ ] All targeted tests pass (or expected failures are documented)
- [ ] No infrastructure errors (connection refused, timeouts)
- [ ] Test output is reviewed for warnings that may indicate issues
- [ ] Any new test failures are investigated before proceeding

## Safety notes

- Tests run in isolated containers and do not affect production data.
- The `--rm` flag ensures containers are cleaned up after runs.
- Use `--remove-orphans` to prevent container accumulation from interrupted runs.
- If tests modify shared state, run them without `-n auto` to avoid race conditions.
