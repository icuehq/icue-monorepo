# Contracts

`contracts/*.yaml` is the single source of truth for what Flutter and Cloud Functions share:
Firestore collection names, status sets, document field keys and the Dart view models of
Inventory and Library. `tool/gen_contracts.dart` turns it into:

| Output | Holds |
| --- | --- |
| `packages/icue_firebase/lib/src/contracts.g.dart` | `Collections`, enum string constants, subsets, `<Document>Fields` |
| `firebase/functions/src/shared/contracts.ts` | `Collections`, enum objects and types, subsets, document interfaces |
| `features/<name>/lib/src/models/<file>.g.dart` | model classes with `fromMap` |

```bash
melos run gen:contracts     # regenerate
melos run check:contracts   # fail if the outputs are stale
```

Never edit the outputs. A model's getters and methods live in `extension XMembers on X` in the
hand-written `<file>.dart`, which also re-exports the generated file.

## Format

```yaml
collections: [libraryLoans]            # names under schools/{schoolId}/

enums:                                 # values are the exact stored strings
  LoanStatus: { doc: ..., values: [active, returned, lost] }

constants:                             # checked subsets of an enum
  editableStatuses: { enum: LoanStatus, values: [active] }

documents:                             # Firestore shape, for TS interfaces and key constants
  LibraryLoan:
    collection: libraryLoans
    fields: { number: string, remarks: string?, renewals: list<LoanRenewal> }

modelsPackage: school_library          # Dart package and directory of the models
modelsDir: features/library/lib/src/models
models:
  library_loans:                       # -> library_loans.g.dart
    LibraryLoan:
      document: LibraryLoan            # optional: each key must exist in the document
      id: id                           # field filled from the document ID (takesId: no field)
      fields:
        dueDate: string
        status: { type: string, default: LoanStatus.active }
        maxRenewals: { type: int, key: policySnapshot.maxRenewals }
```

Field types: `string int double bool num day timestamp json` (`day`: a Timestamp at midnight India time, read as `yyyy-MM-dd`), `list<string|int|Model>`,
`map<string>`, another model, or a hand-written enum with a static `parse` (e.g. `Tracking`).
`?` allows null. Options: `key` (Firestore key, dotted for nested), `default`, `notEquals`
(`bool` from `key != 'x'`), `present` (`bool` from `key != null`), `length` (`int` from a list's
length), `doc`, and `from` (a raw Dart expression over `data` and `id`; its `type` is the Dart
type). Use `from` only when nothing else fits.
