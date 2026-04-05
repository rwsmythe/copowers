# Adversarial Review Guide

Reference material for getting the most out of copowers adversarial Codex reviews.

## Effective Adversarial Prompts

### Be Specific
Bad: "Are there any problems?"
Good: "What happens when the cache file is corrupted mid-write?"
Good: "Which assumptions about ReqIF namespace versioning could be wrong?"

### Use the Three Roles
The adversarial-critic uses three simultaneous roles:
- **Devil's Advocate**: Challenge design decisions. "What alternatives were not considered?"
- **Red Team**: Find failure modes. "What breaks when X happens?"
- **Steelman Opponent**: Argue against the output. "A skeptical expert would object that..."

When responding to issues, address the role that raised it. A red-team finding needs a fix or a documented risk acceptance. A devil's advocate challenge needs a rationale for the chosen approach.

### Reference Constraints
The most effective challenges reference the spec's own constraints:
- "The spec says no IR changes, but this mapping implies a new field on Element"
- "D-69 says core first, but this acceptance criterion requires full fidelity"

## Antipatterns

### Vague Acceptance
Bad: "Accepted — seems fine"
Good: "Accepted — this is a Phase 6a simplification per D-69. The architecture supports adding full fidelity later without API changes."

### Accepting Everything
If every issue in a round is "accepted", the review added no value. At least one issue per round should either be fixed or produce a meaningful design insight in the rationale.

### Over-Correcting
Not every minor observation needs a code change. The severity classification exists for a reason:
- **Critical**: Must fix before proceeding
- **Major**: Fix or explicitly accept with rationale
- **Minor**: Advisory — note and move on

Fixing every minor issue creates churn without quality gain and burns review rounds.

### Infinite Loops
If rounds 4-5 keep raising new major issues, the problem is usually:
- The scope is too large — decompose into smaller specs
- The spec has a fundamental design gap — go back to brainstorming
- The reviewer is nitpicking — push back with "this is out of scope per [decision]"

## Resolution Recipes

### RESOLVED Format
State what changed and why:
> "RESOLVED: Changed `_serialize_xhtml_value()` to handle plain text in THE-VALUE when no child elements exist. The ReqIF spec allows plain text directly in THE-VALUE, not just wrapped XHTML."

### ACCEPTED Format
State the rationale, scope boundary, and tracking:
> "ACCEPTED: Regex-based XHTML stripping is an intentional simplification per D-69 (core first, full fidelity later). Original XHTML preserved in attributes['reqif_xhtml'] so no data is lost. Module can be upgraded to lxml-based structural extraction without API changes."

### When to Fix vs Accept
**Fix** when:
- The change is small (< 10 lines)
- The issue is clearly correct
- It improves safety or correctness

**Accept** when:
- The issue is out of scope for this phase
- It's a design tradeoff with documented rationale
- The fix would require architectural changes
- The current behavior is intentionally simplified
