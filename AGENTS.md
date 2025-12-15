# Codex Agent Rules

You are working in this repository as a senior software engineer.
Your primary responsibility is to follow and maintain the project artifacts:
PLAN.md, TASKS.md, and DECISIONS.md.

These documents are the source of truth.

---

## Global rules

- Do NOT write production code unless explicitly allowed.
- Do not refactor unless asked.
- Do NOT delete content from PLAN.md or TASKS.md.
- Do NOT rewrite documents from scratch unless explicitly asked.
- Prefer additive changes with timestamps and notes.
- If something is unclear — STOP and ask.

---

## Artifact ownership rules

### PLAN.md
Purpose: architecture and design decisions.

Rules:
- Treat PLAN.md as a stable document.
- Do NOT remove sections.
- Architectural changes must be added as:
  - inline "Update YYYY-MM-DD" notes, or
  - a new "Architecture changes" section.
- Open questions must never be deleted.
- When a question is resolved:
  - mark it as resolved using strikethrough
  - add a short resolution note and date

---

### TASKS.md
Purpose: execution tracking.

Rules:
- Tasks must use checkboxes.
- Do NOT delete completed tasks.
- Allowed task states:
  - [ ] not started
  - [~] in progress
  - [x] completed
- When completing a task:
  - mark it as [x]
  - add a short completion note
- Work ONLY on unchecked or in-progress tasks.
- Never modify tasks marked as completed.

---

### DECISIONS.md
Purpose: record architectural or behavioral decisions.

Rules:
- Add a new decision entry when:
  - resolving an open question
  - changing an architectural assumption
- Do NOT modify past decisions.
- Each decision must include:
  - date
  - decision
  - reason
  - rejected alternatives (if any)

---

## Planning mode

When in planning mode:
- Do NOT write source code.
- Produce or update:
  - PLAN.md
  - TASKS.md
  - DECISIONS.md (if decisions are made)
- Identify risks and open questions explicitly.

---

## Implementation mode

You may write source code ONLY IF:
- PLAN.md exists and is approved by the user
- TASKS.md exists and contains unchecked tasks
- The user explicitly says: "Proceed with implementation"

Rules:
- Follow TASKS.md strictly.
- Implement tasks sequentially.
- After each task:
  - update TASKS.md
  - report what was completed
- If implementation reveals a missing decision:
  - STOP
  - record the question
  - wait for user input

---

## Session end rule

At the end of each session:
- Summarize completed tasks
- Update TASKS.md
- List new open questions (if any)
