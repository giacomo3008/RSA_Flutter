# Shift handover

The handover workspace follows requirements R31–R36 and UC9–UC10 in the supplied RSA RASD. Its document is distinct from live event ownership and closure. The desktop layout groups the record beside staff contributions and the incoming team; narrower layouts stack these cards.

The coordinator selects an outgoing ward shift, prepares a source-based draft, edits the text, records review and signs the exact saved version. A physician can edit clinical content and record clinical validation after coordinator review. When the handover's `requiresClinicalValidation` policy flag is set, signing is blocked until physician validation. That flag is supplied by policy; the UI does not invent a universal clinical-validation rule. Staff can add attributable contributions. Incoming staff are explicitly assigned by the coordinator and acknowledge their own receipt of a signed version.

`prepareHandoverDraft()` currently organizes retained reports and contributions into factual sections locally. It does not call an AI model and is labelled “Prepare draft” in the product. The future authenticated AI service can supply generated text through the same draft/edit/review/sign boundary. No generated draft is automatically official.

New shift records include events in the selected interval and earlier unresolved reports as carry-forward items. This frontend selection policy must be confirmed with the facility when connecting the backend: the requirements leave late-event inclusion and exact handover source selection open. Future-dated events are excluded from earlier shifts. New records have no inferred incoming recipients; coordinators assign them explicitly.

Saved edits clear prior review and clinical validation. New sources or contributions mark the narrative as needing refresh or explicit editing before review. Signing stores the reviewed narrative, original prepared draft, signer, time and complete source-event snapshots. The main signed record displays those retained source statuses, while opening a linked report shows its current state. The amber callout deliberately shows current unresolved high-priority work. Signing and acknowledging never close those events.

An amendment preserves the prior signed record and version-bound receipts, increments the version and opens a new draft with the amendment text. That version needs fresh review, validation when required, signature and incoming acknowledgement. Retained snapshots appear as readable history rather than raw JSON.

Existing saved data predating narrative/source snapshots cannot be retroactively frozen. These records keep their retained history and source links and explicitly state when an earlier signed narrative is unavailable. Newly signed versions and fresh seeded fixtures use the complete snapshot format. The local frontend signature is a recorded workflow action, not a qualified electronic signature or backend identity proof.

## Readable reports and version history

The record presents exact source-matching lines as report cards with event icon, priority, responsibility state, place, occurrence time and the original observation. Repeated references use compact cards. Human-edited or unmatched narrative remains visible verbatim. A signed view uses retained source snapshots, so a report closed later does not silently rewrite the signed status. Linked reports open their current detail separately.

Version history groups all activity into one card per document version. A draft save is an edit within that version; an amendment opens the next version. Each card identifies current/previous status, signer and signature time, reason for the next version where retained, and acknowledgement count. View signed version opens the preserved document read only; View activity lists saves and amendment actions without repeating the entire handover. Saved edit comparisons remain available on request.

## Contributions before and after signature

Your shift contribution accepts facts and outstanding tasks from any authorized care role. Before signature, a submitted contribution is a source note and resets review until the draft includes it. After signature, the same input sends an update awaiting coordinator review. These pending updates are stored separately with author/time; they do not change the signed narrative, version, signature or acknowledgements.

The coordinator can explicitly include pending updates. If the current document is signed, this creates the next draft version and archives the existing signed content and receipts. The new draft includes the notes while retaining their original authors and timestamps, and requires a fresh review/signature. If a draft already exists, the notes enter that draft. Staff cannot use this action to acquire coordinator privileges. Submission and inclusion check the selected record/version before saving.
