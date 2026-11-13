#!/usr/bin/env bash
# Creates the text indexes the `search` database needs (Enterprise edition; not expressible in
# firestore.indexes.json). Run once per project, AFTER creating the database:
#   firebase/scripts/create-search-index.sh <project-id>
# Re-running is safe for a new collection; an existing index answers with an error to ignore.
# The database itself: Enterprise edition, Native mode, asia-south1, ID `search`.
# (`gcloud firestore indexes composite create` crashes on some gcloud versions, hence REST.)
set -uo pipefail
project="${1:?Usage: create-search-index.sh <project-id>}"
spec='{"searchConfig":{"textSpec":{"indexSpecs":[{"indexType":"TOKENIZED","matchType":"MATCH_GLOBALLY"}]}}}'

# create_index <collection> <text field>...
create_index() {
  local coll="$1"; shift
  local fields="" f
  for f in "$@"; do
    fields+="$(echo "$spec" | sed "s/^{/{\"fieldPath\":\"$f\",/"),"
  done
  local response
  response="$(curl -s -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "x-goog-user-project: $project" -H "Content-Type: application/json" \
    "https://firestore.googleapis.com/v1/projects/$project/databases/search/collectionGroups/$coll/indexes" \
    -d "{\"queryScope\":\"COLLECTION\",\"searchIndexOptions\":{\"textLanguage\":\"en\"},\"fields\":[${fields%,}]}")"
  if echo "$response" | grep -q '"error"'; then
    echo "index on $coll not created: $response" >&2
  else
    echo "index on $coll requested"
  fi
}

create_index inventoryItems name code
create_index libraryCatalogue title subtitle authorsText publisher keywordsText
create_index libraryLoans bookTitle memberName admissionNumber
create_index libraryIncidents bookTitle memberName admissionNumber
