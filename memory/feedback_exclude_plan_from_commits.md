---
name: exclude_plan_from_commits
description: Never include PLAN.md in git commits
type: feedback
---

Do not stage or commit PLAN.md files.

**Why:** PLAN.md is a planning artifact, not part of the shipped codebase.

**How to apply:** When staging files for a commit, explicitly exclude PLAN.md even if it's untracked/modified.
