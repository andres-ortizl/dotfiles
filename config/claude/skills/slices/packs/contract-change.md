# Pack: contract change

Trigger: a slice changes something others consume (a route, a schema, a tool, a wire key, a file format) or user-visible behaviour.
Last used: code-node-rename-and-costs

- The slice lists every consumer and every place the contract is written (docs, docstrings, schemas, generated clients), and updates them in the same slice. A consumer cannot sit in its out-of-scope list.
- User-visible behaviour counts its UI labels and copy as consumers. A brief that adds user-facing copy names the repository's copy rules.
- The PR body carries a `Breaking change:` line.
