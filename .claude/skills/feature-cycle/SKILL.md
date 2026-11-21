---
name: feature-cycle
description: Run one feature/fix through the full Dev → QA → Dev-fix loop with PO-framed human-in-the-loop (HITL) decisions and an SRE commit at the end. Use when the user gives a feature or bug to implement end-to-end with the project's agent workflow, or says things like "build this", "ship this feature", "run the loop on X".
---

# Feature cycle: PO → Dev → QA → (loop) → HITL → SRE

You (the main session) are the **orchestrator**. You do not write the feature, test it, or deploy it yourself — you drive four subagents (`po-agent`, `dev-agent`, `qa-agent`, `sre-agent`, defined in `.claude/agents/`) through this loop via the Agent tool, and you are the only one who can talk to the human, via `AskUserQuestion`.

## Inputs
`args` is the feature/bug description the user gave (e.g. `/feature-cycle add CSV export of voters to admin dashboard`). If it's missing or too vague to spec, ask the user directly first — don't invent scope for an electoral/voter-data app.

## Loop

1. **Spec (po-agent)** — unless the request is already a small, unambiguous bug fix, call `po-agent` to turn the request into acceptance criteria, non-goals, and any PII/privilege implications, and to update `docs/PRODUCT_BACKLOG.md`. If po-agent's spec includes an open question that needs the human before dev-agent can start, go to step 4 now with that question.

2. **Build (dev-agent)** — call `dev-agent` with the acceptance criteria (or bug report). It implements, self-verifies (`flutter analyze`/`flutter test`), and returns a change summary. If dev-agent says a requirement is ambiguous, go to step 4 with that question, then resume here once answered.

3. **Test (qa-agent)** — call `qa-agent` with the change summary. It returns one of:
   - **PASS** (BUGs: none, DECISION NEEDED: none) → go to step 5.
   - **FAIL** with **BUG**s → go back to step 2, handing dev-agent the exact repro list. Loop steps 2↔3 until PASS or the only remaining items are DECISION NEEDED.
   - **DECISION NEEDED** items (with or without separate BUGs) → resolve any BUGs via the 2↔3 loop first, then go to step 4 for the decision items.

4. **HITL (po-agent frames it → you ask)** — call `po-agent` with the raw ambiguity/decision item to get it framed as a question + 2–4 real options + a recommendation. Then call `AskUserQuestion` with that question and those options verbatim (po-agent's recommendation as the first option) — never decide this yourself and never let dev-agent/qa-agent guess at it. Feed the human's answer back into dev-agent's/qa-agent's next call, and tell po-agent to log it in the Decisions Log. Resume at whichever step was waiting (2 or 3).

5. **Ship (sre-agent)** — only once qa-agent has returned a clean PASS. Summarize what's about to be committed (and, if relevant, deployed) and get the human's explicit go-ahead in chat before calling `sre-agent` — it will not commit/push/deploy without that. Then call `sre-agent` to commit (and deploy only if the human said to deploy, not just commit).

6. **Close out** — tell po-agent to mark the feature Done in `docs/PRODUCT_BACKLOG.md`, and summarize to the user what shipped, what was tested, and any decisions logged.

## Rules for you as orchestrator
- Never skip qa-agent, even for a change dev-agent calls "trivial" — let qa-agent decide the test depth, not you.
- Never let `AskUserQuestion` get bypassed by a subagent's own guess on anything po-agent or qa-agent flagged as needing a human.
- Never call sre-agent to commit/push/deploy without a fresh, explicit human go-ahead for *that specific* change — a prior approval for a different feature doesn't carry over.
- If the user's original request was itself a whole project ("build the admin dashboard"), break it into features and run this cycle once per feature rather than one giant uncontrolled pass — check in with the user (or po-agent's backlog ordering) on sequencing if it's not obvious.
- Keep status visible: after every step, a one-line update (which agent, what verdict) so the user can follow the loop without reading subagent transcripts.
