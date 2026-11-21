# voter_app — agent workflow

This repo uses four Claude Code subagents (`.claude/agents/`) driven in a fixed loop:

- **po-agent** — turns requests into specs/acceptance criteria, triages QA's ambiguous findings, owns `docs/PRODUCT_BACKLOG.md`. Cannot talk to the user directly.
- **dev-agent** — implements/fixes code in `lib/` and `functions/` against po-agent's acceptance criteria.
- **qa-agent** — full test pass (functional, API/integration, performance, black-box, security, boundary-value/equivalence-partitioning, accessibility) on every dev-agent change; verdict is PASS, FAIL (bugs → back to dev-agent), or DECISION NEEDED (→ po-agent → human).
- **sre-agent** — commits and (on explicit human go-ahead) deploys via Firebase, only after a clean QA pass.

Run `/feature-cycle <feature or bug>` to drive the whole loop (spec → build → test → fix-loop → human decision where it matters → commit/deploy) on one piece of work. Use `/po-sync` to talk to po-agent about backlog/requirements/gaps without triggering a build. The orchestrating session (not any subagent) is the only one that puts decisions to the human, via `AskUserQuestion`.

This is a Flutter app (`lib/`, Firebase: `firebase_auth`/`cloud_firestore`/`cloud_functions`, local `sqflite` cache) handling voter PII and admin roles (`functions/bootstrap_primary_admin.js`, `functions/set_primary_admin.js`, `lib/admin/`) — treat auth/role/`firestore.rules` changes as security-sensitive by default.
