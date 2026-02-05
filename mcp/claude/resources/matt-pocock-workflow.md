# Matt Pocock's Claude Code Workflow

Source: "How I use Claude Code for real engineering"
https://recapio.com/digest/how-i-use-claude-code-for-real-engineering-by-matt-pocock

## Key Techniques

### 1. Plan Mode
- Start large tasks in plan mode
- Forces Claude to explore codebase FIRST
- Ask clarifying questions before writing code
- Command: `/plan` or enter plan mode

### 2. Concise Communication
Add to user memory:
> "Be extremely concise and sacrifice grammar for the sake of concision"

### 3. Multi-Phase Planning
- Break large features into phases
- Avoid context window overflow
- Each phase = one focused session

### 4. Context Window Management
- Store plans in GitHub issues
- Reset context, preserve plan externally
- Use `gh issue create` to save state

### 5. Tools Stack
- GitHub CLI (`gh`) for issues/PRs
- VS Code for diff review
- Dictation for fast prompts

## Workflow Pattern

```
1. Create GitHub issue with requirements
2. Enter plan mode
3. Let Claude explore + ask questions
4. Approve plan
5. Execute in phases
6. Review diffs in VS Code
7. Store progress in issue comments
```

## Commands Reference

```bash
# Start planning
claude --plan "implement feature X"

# Create issue for context
gh issue create --title "Feature: X" --body "requirements..."

# Resume with context
gh issue view 123 | claude "continue from this"
```
