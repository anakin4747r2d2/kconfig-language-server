# Kconfig Language Server

## Git Best Practices

- **Commit Often:** Make small, focused commits.
- **Descriptive Messages:** Use clear, imperative commit messages.
- **Test Driven Development:**
  - Write tests before implementing features or fixes.
  - After creating the test, stop and request approval before proceeding.
- **.gitignore:** Exclude build artifacts and sensitive files.
- **No Secrets:** Never commit passwords or API keys.
- **Whitespace:** Never leave trailing whitespace

Commit every logical atomic addition or change using git. Each commit should
represent one coherent unit of work (e.g. add a helper function, fix a bug,
update the flake). Do not batch unrelated changes into a single commit. Commit
messages should be concise and written in the imperative mood.

## Code review

After creating a commit code review your work. Ask the following questions to
see how the code can be made cleaner:
- Did your change create any dead code?
- Did your change invalidate some comments?
- Is your change in the style of the codebase?
- Can guard clauses be used to avoid indented code?
- Can this code be refactored into a function to improve readability?
- Is this commit atomic and only focused on one topic?
- Did anything unrelated get included in the commit by accident?
- Does this code reuse functionality already present in the codebase?
- Did the commit duplicate any functionality already present in the codebase?
- Is there a simpler way to implement this solution?
- Did you add any extra functionality that doesn't have a corresponding test?

Fix the code accordingly in new commits.
