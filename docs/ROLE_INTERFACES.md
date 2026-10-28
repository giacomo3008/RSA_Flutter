# Role interfaces

The frontend uses explicit ward-role assignments. A person can have several roles in one ward and a different role in another ward. Account information shows these assignments; choosing another assigned ward does not grant additional access.

| Role | Workspace and permitted actions |
| --- | --- |
| Nurse | Overview, attendance, reporting, authorized conversations, priority inbox, ward diary, document transcription review, handover contribution and assigned incoming acknowledgement. Eligible nurses can explicitly take charge of clinical reports and record an outcome. |
| Healthcare assistant | Care workspace, attendance, reporting, authorized conversations, diary, document transcription review, handover contributions and assigned incoming acknowledgement. No automatic nursing responsibility or physician validation. |
| Technician | Care workspace and equipment/safety reporting, authorized conversations and ward records, document transcription review, contributions and assigned acknowledgement. No automatic nursing or physician authority. |
| Physician | Care workspace plus Clinical review. Can inspect sources and clinically validate a coordinator-reviewed handover. Clinical validation does not sign the outgoing handover. |
| Coordinator / head nurse | Care workspace plus Ward coordination: current shift attendance, availability, skills, open workloads, unhandled reports, ward group conversation and handover review/signature/amendments. Cannot grant roles or access to other wards. |
| Medical management | Aggregate indicators filtered by authorized ward and date; display-name configuration for authorized wards. No resident detail or clinical conversation access unless separately assigned a clinical role. |
| System administrator | Account role assignments per ward, facility notification timings, integration configuration status and audit metadata. No automatic resident-record access. |

The account assignment editor preserves multiple roles per ward, instead of replacing all permissions with a single global professional role. The repository checks permissions on each mutation; hiding controls is supplementary.

Current attendance editing applies to the ward's current shift. Future roster planning and independent per-ward attendance ledgers require the scheduling backend; this interface does not pretend to persist future roster assignments.

The ward conversation follows authorized care membership. “Ward operational lead” does not imply access to private conversations, administration of corporate accounts, or permission to grant access to another ward.

The official navigation does not expose arbitrary persona switching. The requirements specify corporate SSO and MFA; the backend must resolve identity and role assignments. `switchPersona` remains a repository fixture/testing operation, not an authentication mechanism. Role screens are tested with those identities without adding demo controls to the product.

Clinical document transcription confirmation is distinct from physician validation. Conditions requiring clinical validation remain a facility policy decision in the requirements; the interface does not infer approval from an OCR review.

Service integrations display configuration requirements, not fabricated live connection status. No external SSO, push, LLM or OCR provider is contacted by these role interfaces.

References: RSA_agentic_AI R2–R6, R33–R36, UC11–UC12, QA5; plan_0 “Roles and permissions”, p. 11.
