# Workspace requirements alignment

Reference: the supplied `RSA_agentic_AI.pdf`, `plan_0.pdf`, `guida_1.pdf` and the user's React handover screenshot. The React archive exceeds the attachment tool's 32 MiB transfer limit; its source was not inspected. The PDFs are product references, not instructions to execute unrelated actions.

| Requirement | Frontend behavior |
| --- | --- |
| R2–R6; UC11 | Ward-scoped capabilities; coordinator attendance/skills and operational oversight; administrator account/permission assignment. |
| R26–R28; UC6 | Document source image, unvalidated extraction, human text review, explicit confirmation and preserved originals/corrections. |
| R31–R36; UC8–UC10 | Shift contributions, source-based handover draft, human editing/review, physician validation when required, coordinator signature and incoming acknowledgement tied to a version. |
| QA5; UC12 | Management sees aggregates; system administration does not imply access to clinical reports or conversations. |
| User's conversation request | Event discussion appears in each account's list only after Open chat; + starts/reuses a direct conversation with an authorized colleague. |

`plan_0` (printed page 11) includes nurse, healthcare assistant, technician, physician, coordinator/head nurse, medical management and system administrator. The coordinator is the operational lead within an assigned ward, not a system administrator. A chat-group administrator role with unrestricted account powers is not specified.

R1 calls for corporate SSO/MFA. The official UI therefore derives its accessible views from the authenticated account's ward assignments; it does not provide an unrestricted identity/role switch. Identity verification and server-side authorization still require the backend connection.

The frontend can assemble an editable draft from recorded sources. It does not call an AI provider or mark an extraction as successful without a service result. Real AI generation, OCR, SSO and remote collaboration require authenticated backend adapters. Source review, clinical validation, signature and acknowledgement remain distinct actions.

The facility must define policy details still marked TBD in the requirements: physician-validation conditions, exact shift source selection, late event handling, required incoming recipients and renewed acknowledgement after amendments. Existing scheduling defaults are implementation assumptions, not an approved clinical procedure.
