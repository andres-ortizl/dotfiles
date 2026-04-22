# Auth — local dev

Local backend requires a bearer token. Two options:

1. **Auth0 JWT** — obtained via the frontend OIDC flow. Fine for UI sessions, tedious for CLI.
2. **API key** — the practical path. Mint one via a management script against the running stack.

## Check what already exists

```bash
docker compose exec -T -w /app/anyformat/services/backend/src/anyformat/backend backend \
  python manage.py shell -c "
from anyformat.backend.apps.saas_manager.models import APIKey, Organization
from django.contrib.auth import get_user_model
U = get_user_model()
print('users:',     U.objects.count())
print('orgs:',      Organization.objects.count())
print('keys:',      APIKey.objects.count())
print('orgs dump:', list(Organization.objects.values('id','name')[:5]))
print('users dump:', list(U.objects.values('id','username','email')[:5]))
"
```

A fresh local docker-compose seeds **one user** (`username=anyformat`, `email=anyformat@localhost`) and **one org**. The seeded user has an API key in the DB, but **the raw key is not recoverable** — only its SHA256 hash is stored. You have to mint a new one.

## Mint a fresh API key

```bash
docker compose exec -T -w /app/anyformat/services/backend/src/anyformat/backend backend \
  python manage.py shell -c "
import secrets
from anyformat.backend.iam.domain.entities import APIKey as APIKeyEntity
from anyformat.backend.apps.saas_manager.models import APIKey, Organization
from django.contrib.auth import get_user_model
U = get_user_model()
user = U.objects.get(username='anyformat')
org  = Organization.objects.first()
raw  = 'sk-dev-' + secrets.token_urlsafe(32)
APIKey.objects.create(
    owner=user, organization=org,
    key_hash=APIKeyEntity.hash_key(raw),
    prefix=APIKeyEntity._mask(raw),
    name='claude-dev',
)
print('KEY='    + raw)
print('ORG_ID=' + str(org.id))
"
```

Copy the two lines into your shell:

```bash
export TOKEN=sk-dev-...
export ORG_ID=...
export BASE=http://localhost:8080
```

## Verify

```bash
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "$BASE/api/v2/saas_manager/workflows/" \
  -H "Authorization: Bearer $TOKEN" -H "X-Current-Org: $ORG_ID"
# HTTP 200 = good
# HTTP 401 = wrong key / wrong hash
# HTTP 403 = org missing or permissions check failed
```

## How it works (for when things break)

- Authenticator: `Auth0JWTMachineAuthentication` — backend hashes the bearer with SHA256, matches against `APIKey.key_hash` (see `anyformat/services/backend/src/anyformat/backend/utils/auth/rest_authenticators.py:164`).
- On match, `request.META["HTTP_X_CURRENT_ORG"]` is set automatically from the key's `organization_id` — so for v2 endpoints you can often omit `X-Current-Org`. **v3 endpoints still expect it**; always send it.
- Disabled keys: set `is_active=False` on the `APIKey` row.
- Hashing helper: `APIKeyEntity.hash_key(raw) -> sha256 hex`; `APIKeyEntity._mask(raw)` → short prefix for display.

## Gotchas

- The `anyformat` seeded user exists after `docker compose up` — no manual seeding needed.
- APIKey prefix ≠ actual key; it's just a display fingerprint. Always use the raw `sk-dev-...` value as the bearer.
- The ORG_ID is **UUIDv7 hyphenated form** (e.g., `069e7d83-478d-72c6-8000-f2cf7d3dd2bc`). Hex form also works in most places.
