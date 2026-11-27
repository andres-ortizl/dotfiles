# Pack: live probe

Trigger: an acceptance criterion or a brief calls a live API, a finding claims what a class or endpoint accepts, or a slice's tests replace an external binary (docker, a database client, a CLI) with a fake.
Last used: deps-stack-refresh-2026-11

- Build the requests from the API's SDK or schema, never from guessed field names, and record the status and body of every non-200 response.
- When the tests fake an external binary, one acceptance criterion runs the real binary on the slice's real path, so a fake that answers yes cannot hide a refusal.
- Prove what a class or endpoint accepts with a probe on that same class or endpoint, not by reading its base.
