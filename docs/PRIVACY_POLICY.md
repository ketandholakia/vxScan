# vxScan Privacy Policy

_Last updated: 2026-11-19_

## Short version

vxScan works **entirely offline**. Your scans, generated barcodes, tags and
notes are stored **only on your device**. The app has no analytics, no ads,
no tracking, and no accounts.

## Permissions

| Permission | Why | When |
|---|---|---|
| `CAMERA` | Live barcode scanning | Only while the scanner screen is open |

The app requests **no other permissions**:

- Gallery import goes through the Android system photo picker, so no storage
  access is needed.
- Exports and backups are handed to the Android share sheet / file picker;
  you choose where the file goes.
- Smart actions (call, email, add contact, add calendar event) are performed
  by the corresponding system apps via intents; vxScan never reads your
  contacts or calendar.

## Data handling

- **Scan results** (decoded text, barcode format, timestamp) are stored in a
  local SQLite database in the app's private storage. They never leave the
  device unless you explicitly share or export them.
- **Product lookups** ("Food facts" on a product scan) open the Open Food
  Facts website with the barcode in the URL. This only happens when you tap
  the button — nothing is sent automatically.
- **Web search / "Open" actions** leave the device only when you tap them,
  and go to the browser, not to us.
- **Deleting the app** removes all local data.

## Children

vxScan does not collect any data, so there is nothing to apply age limits to.
The app is not directed at children under 13 and offers no communication
features.

## Contact

Open an issue in the project repository.
