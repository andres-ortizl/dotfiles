# Pack: contract change

Trigger: a slice changes something others consume (a route, a schema, a tool, a wire key, a file format) or user-visible behaviour.
Last used: deps-stack-refresh-2026-11

- The slice lists every consumer and every place the contract is written (docs, docstrings, schemas, generated clients), and updates them in the same slice. A consumer cannot sit in its out-of-scope list.
- User-visible behaviour counts its UI labels and copy as consumers. A brief that adds user-facing copy names the repository's copy rules.
- A slice that moves or renames a class proves where an instance is serialized by its class path (a pickle, a cache blob, a remote call's return value) by running that path live, not by grepping for `pickle`.
- The PR body carries a `Breaking change:` line.
