# Contributing to GRP

Please open an issue for a bug or substantial feature change. For bug reports,
include macOS version, GRP version, account provider and steps to reproduce.
Use fictional examples and redact personal contact information from screenshots,
logs and exported cards. Never attach your live address book.

Build and test on macOS 14 or later with Xcode Command Line Tools and Python 3:

```sh
bash scripts/check.sh
bash scripts/build.sh
bash scripts/render-row-previews.sh dist/previews --app
```

Keep ordinary authored text solid black in light appearance and white in dark
appearance. Do not introduce gray placeholder text, secondary/tertiary text styles
or text opacity. Preserve accessible group names and three-state labels; color
must never be the only cue. Keep tags compact rounded rectangles.

Membership changes must target exact account-card and group IDs. Preserve
same-account validation, typed Apple event arguments, fresh post-save membership
verification and visible error reporting. Never replay failed writes automatically.
Bulk updates stop on failure and report partial success. Don't introduce silent
rollback or drop unavailable selection/filter IDs to broaden an operation.

Keep ordinary card field editing in Apple Contacts and keep whole-card deletion
separate from the group-writing bridge. Preserve deletion confirmation and its
store-change guard. Requesting CNContactNoteKey requires a restricted entitlement;
notes currently use user-authorized, read-only Automation instead.

Tests and screenshots must use synthetic contacts. A preview model must remain
`live = false`, so store notifications cannot trigger personal-data reads. Real
integration tests require disposable contacts in a writable test account and must
be reported separately from synthetic checks. Never claim a live provider works
based on compilation alone.

The numbered color library and filter behavior are documented in
[docs/group-colors.md](docs/group-colors.md) and
[docs/group-filter.md](docs/group-filter.md). Add palette IDs without renumbering
existing ones. Keep contact data local; do not add telemetry or uploads.
