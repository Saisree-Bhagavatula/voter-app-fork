---
name: po-sync
description: Talk directly to the po-agent about features, requirements, gaps, and backlog status without running the full dev/QA build loop. Use when the user wants to discuss, prioritize, or decide something product-level ("what's left", "let's talk through requirements for X", "what are the open gaps").
---

# Product sync (po-agent only)

Call `po-agent` (via the Agent tool) with the user's question/topic and the current state of `docs/PRODUCT_BACKLOG.md`. Relay its output to the user as-is where it's informational (backlog status, gaps). Where po-agent frames something as needing a human decision, put that exact question/options to the user yourself via `AskUserQuestion` — po-agent cannot ask the user directly. Record the answer by calling po-agent again to log it in the Decisions Log. This skill never calls dev-agent, qa-agent, or sre-agent.
