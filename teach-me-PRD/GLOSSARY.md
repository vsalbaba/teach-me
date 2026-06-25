# PRD Glossary

Terminology for Product Requirements Documents and the process of turning product ideas into implementable work.

## Terms

**PRD (Product Requirements Document)**:
A document that defines what a product or feature should do from the user's perspective -- its purpose, behavior, constraints, and success criteria.
_Avoid_: spec, product spec (too vague), design doc (different artifact)

**Requirement**:
A concise, atomic statement of what needs to be accomplished. States only *what*, never *how*.
_Avoid_: feature request, wish-list item

**Functional requirement**:
A requirement describing a specific behavior the system must support -- what it does in response to inputs or conditions.
_Avoid_: feature, capability (too loose)

**Non-functional requirement (NFR)**:
A requirement describing a quality attribute of the system -- performance, security, reliability, accessibility -- rather than a specific behavior.
_Avoid_: "-ilities", quality attribute (correct but less common in PRD context)

**Acceptance criteria**:
Testable conditions that must be true for a requirement to be considered complete. Often written in Given/When/Then format.
_Avoid_: definition of done (related but broader), test cases (downstream artifact)

**User story**:
A requirement expressed as "As a [role], I want [goal], so that [benefit]." Captures who needs what and why.
_Avoid_: use case (more formal, different structure), ticket (implementation artifact)

**Vertical slice**:
A unit of work that delivers a narrow but complete path through every layer of the system (data, API, UI, tests). Each slice is independently demoable.
_Avoid_: task, horizontal slice (layer-by-layer work)
