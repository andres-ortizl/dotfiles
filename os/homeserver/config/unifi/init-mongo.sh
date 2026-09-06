#!/bin/bash
set -euo pipefail

mongo_init_bin=mongo
if command -v mongosh >/dev/null 2>&1; then
  mongo_init_bin=mongosh
fi

mongo_pass=$(cat "$MONGO_PASS_FILE")

"$mongo_init_bin" --quiet <<EOF
use ${MONGO_AUTHSOURCE}
db.auth("${MONGO_INITDB_ROOT_USERNAME}", "${MONGO_INITDB_ROOT_PASSWORD}")
db.createUser({
  user: "${MONGO_USER}",
  pwd: "${mongo_pass}",
  roles: [
    "clusterMonitor",
    { db: "${MONGO_DBNAME}", role: "dbOwner" },
    { db: "${MONGO_DBNAME}_stat", role: "dbOwner" },
    { db: "${MONGO_DBNAME}_audit", role: "dbOwner" },
    { db: "${MONGO_DBNAME}_restore", role: "dbOwner" }
  ]
})
EOF
