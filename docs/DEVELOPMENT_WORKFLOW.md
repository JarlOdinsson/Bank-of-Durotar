# Development Workflow

This workflow keeps Bank of Durotar scoped, reviewable, and designed to comply with Blizzard's addon policy.

## 1. Architect

- Read `AGENTS.md` and all required governance docs.
- Identify the module boundaries affected by the requested work.
- Prefer the existing namespace and adapter patterns.
- Record API uncertainty before coding.

## 2. Requirements

- Confirm the exact user problem.
- Tie the feature to the product mission.
- Identify which roadmap milestone owns the work.
- Defer features that do not support the mission.

## 3. Milestone Task Definition

- Restate the assigned milestone or task.
- Define what is in scope and out of scope.
- Do not begin the next milestone automatically.
- Keep future milestone details provisional until assigned.

## 4. Compliance Review

- Review `docs/BLIZZARD_COMPLIANCE.md`.
- Identify protected functions, hardware-action requirements, query throttles, and external-service risks.
- Stop and ask for review if policy applicability or API behavior is unclear.

## 5. Implementation

- Modify only assigned scope.
- Keep Lua compatible with the verified Classic Anniversary client.
- Use runtime detection for optional APIs.
- Keep modules small and focused.
- Do not add external libraries without documented architectural review.

## 6. Static Review

- Review changed files manually.
- Run available text searches and syntax checks.
- Confirm no forbidden automation or transaction calls were introduced.
- Confirm SavedVariables remain bounded.

## 7. Human Diff Approval

- Show changed files and behavioral impact.
- Highlight protected functions and Auction House APIs touched.
- Report compliance risks and live-client assumptions.
- Leave the working tree ready for review.

## 8. Live-Client Test

- Provide exact in-game steps.
- Do not claim live verification until the user supplies results.
- Record live results in `docs/TESTING.md` and, when relevant, `docs/BLIZZARD_COMPLIANCE.md`.

## 9. Bug Repair

- Fix only bugs related to the assigned task or live-test findings.
- Preserve unrelated user changes.
- Re-run focused checks.

## 10. Documentation Update

- Update README, architecture, testing, tasks, compliance, or changelog as appropriate.
- Keep docs aligned with actual behavior.
- Preserve runtime-detection language for future client changes.

## 11. Commit

- Commit only reviewed, scoped changes.
- Use concise imperative commit messages.
- Good examples:
  - `Close milestone 0.0.1 with live Classic AH probe findings`
  - `Add governance and compliance guardrails`
  - `Document live-client auction API findings`

## 12. Push

- Push only when explicitly requested.
- Do not create remotes unless explicitly requested.
- Confirm branch and remote before pushing.

## 13. Release Packaging

- Package only source-visible addon files required for release.
- Do not include development junk, logs, or local SavedVariables.
- Confirm `.toc` interface value and changelog.

## 14. CurseForge Release Gate

Release to CurseForge only after the release gate passes:

- Scope is complete.
- Compliance review is complete.
- No paid, premium, advertisement, or hidden-code feature exists.
- Live-client test has passed for the release target.
- Documentation and changelog are current.
- Packaged addon contains readable source code.

## Branch Guidance

- Keep `main` stable.
- Use short feature branches for risky or multi-step work when requested.
- For small documentation or milestone tasks, direct work on `main` is acceptable if the user has requested it.

## Commit Guidance

- One commit should represent one coherent task.
- Do not mix unrelated refactors with milestone work.
- Do not commit without user permission when the task says not to.
- Always report final git status.
