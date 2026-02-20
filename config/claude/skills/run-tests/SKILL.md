---
name: run-tests
description: Run tests for the current anyformat workspace package
triggers:
  - run tests
  - run the tests
  - pytest
---

# Run Tests — anyformat monorepo

Detect which workspace package the current work relates to and run the appropriate test command.

## Local packages (no Docker)

```bash
cd anyformat/domain && uv run pytest
cd anyformat/libs && uv run pytest
cd anyformat/anyformat-engine && uv run pytest
cd anyformat/inference && uv run pytest
cd anyformat/cli && uv run pytest
```

## Docker services (require infrastructure)

```bash
docker compose run --rm backend pytest -n auto
docker compose run --rm external-api pytest
docker compose run --rm anyformat-core pytest -n auto
```

## Rules

1. Determine which package(s) the recent changes touch by looking at file paths.
2. If changes span multiple packages, run tests for each affected package.
3. For local packages, run from the **monorepo root** using the `cd <pkg> && uv run pytest` pattern.
4. For Docker services, run from the **monorepo root** using `docker compose run --rm`.
5. To run a specific test file, append the path relative to the package: `uv run pytest tests/test_foo.py` or `docker compose run --rm backend pytest path/to/test.py`.
6. Use `-x` flag to stop on first failure when debugging.
7. Backend and anyformat-core support `-n auto` for parallel execution.
