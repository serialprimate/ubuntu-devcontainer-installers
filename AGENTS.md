# Instructions for Agents

## Required Context

- Follow `PROJECT.md` for the current project scope, product policy, milestones and acceptance criteria.
- Follow `CONVENTIONS.md` as the authoritative source for recurring implementation, security, testing, documentation and maintenance practices.
- Read `README.md` for current user-facing purpose, support, availability and usage.
- Resolve the requested outcome against those documents before changing files.
- Stop and report any material conflict between the request, authoritative documents or established repository patterns.

## Agent-Specific Constraints

- Do not introduce new dependencies or external services without prior approval.

## Verification and Reporting

- Run relevant unit and integration tests, including packaged-artefact tests when layout or packaging can be affected.
- If a required test interface is not implemented, run all available checks and report the limitation.
- Report the changes, reasons, commands run, results and potential impact on related installers, packaging and resources.

## Token Efficiency

- Design tool calls to be input-efficient.
- Use `rg` rather than `grep`, and `fdfind` (aka `fd`) rather than `find`.
- Do not dump long raw streams; filter them before reading relevant portions.

## Temporary Working Files

- Use `/tmp/ubuntu-devcontainer-installers/` for agent-created tool output, test logs, caches and temporary development scripts needed during a response.
- Keep such working files out of the repository and remove them when they are no longer useful.
- This path is an agent and development workspace, not an installer runtime convention.

## Issue Reporting

If a request, instruction or authoritative document is materially suboptimal or incompatible, stop, summarise the specific issue concisely and ask how to proceed.

## Preservation of Intent

- Keep intent and meaning together with the code, conventions, instructions, comments, and documentation to which it is scoped.
- When restructuring or refactoring, always preserve the intent and meaning of the code, conventions, instructions, comments, and documentation.
- Always consider the impact or coverage of a change, in terms of intent and meaning and not just the mechanical effects.
