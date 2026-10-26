---
name: review-deep
description: Standard review for a med or high-risk diff. Looks for the root cause and names the bug class.
---

# Deep review

Use this when risk is med or high. The quick-review contract still applies. This pass may read the callees and the test that should have failed.

On a bug fix, check the root cause, not only the line that changed. Say which bug class the author should eliminate everywhere it appears.

A high-risk or sensitive diff still does not get a bot approval. Leave the merge to a human.

When this run's cycle is past the maximum, stop. Tell the author to reconsider the approach instead of patching the same diff again.
