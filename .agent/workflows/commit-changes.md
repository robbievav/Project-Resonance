---
description: Commit and push all changes to GitHub after completing a task
---

After completing any code changes for the user, always commit and push to GitHub:

// turbo-all

1. Stage all changed files:
```powershell
git add -A
```

2. Commit with a descriptive message following conventional commits format (e.g. `fix:`, `feat:`, `refactor:`, `chore:`):
```powershell
git commit -m "<type>: <short description of what changed>"
```

3. Push to the remote:
```powershell
git push origin main
```
