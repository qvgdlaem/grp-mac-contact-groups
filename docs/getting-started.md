# Install and use GRP

## Install

1. Download `GRP-…-universal.zip` from the project's
   [GitHub Releases](https://github.com/qvgdlaem/grp-mac-contact-groups/releases).
   GitHub's “Source code” archives contain source, not the compiled app.
2. Unzip the file and move GRP.app to Applications. Quit an older copy before
   opening the new one.
3. Open GRP. This preview is ad hoc signed and not Apple-notarized. If macOS
   blocks it because the developer cannot be verified, and you trust this download,
   try opening it once, then use System Settings → Privacy & Security → Open Anyway.
   Follow [Apple's guidance](https://support.apple.com/en-us/102445). The app does
   not require disabling Gatekeeper or removing quarantine with Terminal commands.

A SHA-256 file accompanies each release. To check the download, put the ZIP and
`SHA256SUMS.txt` in one directory, open Terminal there, and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

An OK result confirms that the archive matches that checksum. It does not replace
Developer ID signing or notarization.

## Connect

GRP initially displays fictional sample cards. Choose **Connect Apple Contacts**
and grant Contacts access when macOS asks. If access was denied, enable GRP under
System Settings → Privacy & Security → Contacts and try connecting again.

GRP also uses Automation to ask Apple Contacts for notes, whole-card dates and
vCard details, and to save group memberships. Allow GRP to control Contacts when
prompted, or enable it under Privacy & Security → Automation. If macOS offers
limited contact access, only the permitted cards can be shown.

The public app uses `io.github.qvgdlaem.grp`. Earlier development builds use a
separate identity; you may need to grant permissions again. Keep only one copy
running while testing changes.

## Edit groups

For one contact, use **Add to group** or remove a group tag on its open card.
Those changes save immediately. The toolbar's Undo group change restores only
the last confirmed single-card membership change.

For several contacts:

1. Check their row boxes, use Command/Shift-click, or select all visible contacts.
2. Choose **Groups for selected…**.
3. Review each group's checkbox: tick means all eligible selected cards, dash
   means some, empty means none. The account and eligible selected-card count
   appear below its name.
4. Click a dash or empty box to add the group to everyone in that account. Click
   a tick to remove it from everyone. Unchanged groups are left alone.
5. Review the additions/removals count and choose **Apply**. Reset changes or
   Cancel discards staged edits before saving.

Selection is limited to the visible list; changing the view or search removes
hidden selections. An open bulk sheet freezes its selection while it saves.
Each group affects only cards from its own account. Bulk writes run one at a
time and stop at the first failure. Earlier confirmed changes remain; a failed
write may be uncertain. Refresh and check Apple Contacts before retrying. There
is no bulk undo.

To change other card fields, choose **Edit fields…** to open that card in Apple
Contacts. GRP refreshes after you return. Whole-card deletion is a separate,
confirmed action; it is never part of bulk group editing.
