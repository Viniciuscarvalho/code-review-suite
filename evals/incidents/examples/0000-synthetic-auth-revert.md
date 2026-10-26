# 0000 synthetic auth revert

This fixture is synthetic. It shows the incident format. It is not a production revert.

- id: 0000-synthetic-auth-revert
- kind: revert
- synthetic: true
- title: Missing session is treated as signed in
- bug_class: authz-fail-open
- path: src/auth/session.ts
- line: 18
- pr: 0
- bad_commit: 0000000
- revert_commit: 0000001
- notes: A reviewer change must still flag authz-fail-open on this diff. The expected finding is Important, at src/auth/session.ts:18.

## diff

```diff
--- a/src/auth/session.ts
+++ b/src/auth/session.ts
@@ -16,3 +16,3 @@
 export function isSignedIn(user: User | null): boolean {
-  return user != null && user.session != null;
+  return user == null || user.session != null;
 }
```
