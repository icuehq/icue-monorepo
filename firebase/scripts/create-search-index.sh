#!/usr/bin/env bash
# Creates the text index the `search` database needs (Enterprise edition; not expressible in
# firestore.indexes.json). Run once per project, AFTER creating the database:
#   firebase/scripts/create-search-index.sh <project-id>
# The database itself: Enterprise edition, Native mode, asia-south1, ID `search`.
# (`gcloud firestore indexes composite create` crashes on some gcloud versions, hence REST.)
set -euo pipefail
project="${1:?Usage: create-search-index.sh <project-id>}"
spec='{"searchConfig":{"textSpec":{"indexSpecs":[{"indexType":"TOKENIZED","matchType":"MATCH_GLOBALLY"}]}}}'
curl -sf -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: $project" -H "Content-Type: application/json" \
  "https://firestore.googleapis.com/v1/projects/$project/databases/search/collectionGroups/invItems/indexes" \
  -d "{\"queryScope\":\"COLLECTION\",\"searchIndexOptions\":{\"textLanguage\":\"en\"},\"fields\":[
        $(echo "$spec" | sed 's/^{/{"fieldPath":"name",/'),
        $(echo "$spec" | sed 's/^{/{"fieldPath":"code",/')]}"
