# Instructions for Agents

## Required Context

- Follow `CONVENTIONS.md` as the authoritative source for recurring implementation, security, testing, documentation and maintenance practices.
- Read `README.md` for current user-facing purpose, support, availability and usage.
- Read `docs/architecture-decisions.md` when a change affects the product shape, composition model, release unit, packaging layout or remote-installation boundary.
- Resolve the requested outcome against those documents before changing files.
- Resolve differences between established patterns using the convention precedence in `CONVENTIONS.md`; patterns do not override explicit requirements.

## Agent-Specific Constraints

- Do not introduce new dependencies or external services without prior approval.

## Verification and Reporting

- Run relevant unit and integration tests, including packaged-artefact tests when layout or packaging can be affected.
- If a required check cannot run, first try the supported development environment described in `README.md`. Then run relevant available checks and report the limitation and materially unverified behaviour; distinguish missing tooling from missing credentials or service access.
- Report the changes, reasons, commands run, results and potential impact on related installers, packaging and resources.

## Token Efficiency

- Design tool calls to be input-efficient.
- Use `rg` rather than `grep`, and `fdfind` (aka `fd`) rather than `find`.
- Do not output long unfiltered streams; filter out just the required parts to read them.

## Temporary Working Files

- Use the top-level `tmp/` directory for agent-created tool output, test logs, caches and temporary development scripts needed during a response.
- Keep such working files ignored by Git and remove them when they are no longer useful.
- This directory is an agent and development workspace, not an installer runtime convention.

## Issue Reporting

Report material defects in requests, instructions or authoritative documents. Stop and ask when resolution requires changing an approved product contract, project-wide convention or authority boundary beyond the task's approval. Resolve reasonably reversible local implementation differences within the task's scope using `CONVENTIONS.md`.
