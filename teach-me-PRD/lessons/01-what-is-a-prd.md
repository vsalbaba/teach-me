# Lesson 1: What Is a PRD?

> Understanding Product Requirements Documents -- what they are, who uses them, and why they exist

---

## 01 / The One-Sentence Definition

A **PRD (Product Requirements Document)** defines *what* a product or feature should do from the user's perspective -- its purpose, behavior, constraints, and success criteria. [[1]](#sources)

> **Key insight:** A PRD answers **"what and why"** -- never "how." It describes the problem to solve and the behavior the solution must exhibit, but leaves implementation decisions to the engineering team. [[2]](#sources)

Think of it as a contract between three groups:

- **Product** -- defines the problem and success metrics
- **Engineering** -- builds the solution within the stated constraints
- **QA / QE** -- verifies the solution meets the acceptance criteria

As a developer *and* QE engineer, you sit on the receiving end of this contract. As a hobby PM, you'll also write it. That dual perspective is a strength -- you'll write PRDs that are actually testable and implementable.

---

## 02 / Who Uses PRDs and How

| Role | Reads the PRD to... | Writes/contributes... |
|------|---------------------|----------------------|
| Product Manager | Align stakeholders on scope | Owns the document: problem, goals, scope, metrics |
| Designer | Understand user needs and constraints | UX flows, wireframes, interaction specs |
| Developer | Know what to build and what's out of scope | Feasibility input, NFRs, technical constraints |
| QA / QE | Derive test cases from acceptance criteria | Edge cases, testability feedback |
| Stakeholders | Confirm business alignment | Business context, priority input |

> **Key insight:** The best PRD is the one people actually read and update. Pick the format your engineering partners already live in. [[3]](#sources) For you, that's Markdown -- and that's a fine choice.

---

## 03 / PRD vs. Other Documents

PRDs often get confused with adjacent artifacts:

| Document | Focus | Owned by |
|----------|-------|----------|
| **PRD** | What to build and why (user perspective) | Product |
| Design doc / RFC | How to build it (technical approach) | Engineering |
| MRD (Market Req. Doc) | Market opportunity and business case | Product Marketing |
| User stories | Individual behaviors from user perspective | Product + Eng |
| Test plan | How to verify the build is correct | QA / QE |

A PRD is upstream of user stories and test plans. It's the source they're derived from. [[4]](#sources)

---

## 04 / Anatomy of a PRD

A well-structured PRD has these sections. [[1]](#sources) Not all are always needed -- scale to the size of the feature.

1. **Overview & Context** -- The problem, why now, links to research
2. **Goals & Success Metrics** -- Primary/secondary metrics with targets, plus guardrails
3. **Users & Use Cases** -- Who benefits and what they do (user stories)
4. **Scope** -- In-scope and out-of-scope, explicitly
5. **Functional Requirements** -- Behaviors the system must support
6. **Acceptance Criteria** -- Testable Given/When/Then scenarios
7. **Non-Functional Requirements** -- Performance, security, reliability, accessibility
8. **Design & UX** -- Links to wireframes, prototypes
9. **Analytics & Telemetry** -- What to measure, alert thresholds
10. **Dependencies & Constraints** -- APIs, legal, platform limits
11. **Risks & Assumptions** -- Value, usability, feasibility, business risks
12. **Rollout & Ops** -- Phasing, feature flags, migration
13. **Open Questions** -- With owners and due dates
14. **Changelog** -- Dated entries for material updates

> **Watch out:** Don't treat this as a form to fill in. A small feature might need sections 1-6 and nothing else. A large initiative might need all 14. The sections exist to prevent you from *forgetting* something important, not to create busywork. [[1]](#sources)

---

## 05 / What Makes a Requirement "Good"

The single most important skill in PRD writing is making requirements **testable**. If a QE engineer can't write a test from your requirement, it's not a requirement -- it's a wish. [[1]](#sources)

### Vague vs. Testable

| Vague (avoid) | Testable (prefer) |
|--------------|-------------------|
| "The system should be fast" | "p95 search latency < 200ms at 2x current traffic" |
| "The UI should be user-friendly" | "WCAG 2.2 AA for all new UI components" |
| "Handle errors gracefully" | "On network timeout, show retry button; auto-retry up to 3 times with exponential backoff" |

The gold standard for acceptance criteria is **Given/When/Then** (Gherkin) format:

```gherkin
Scenario: Reset password via email
  Given an existing user with a verified email
  When they request a password reset
  Then they receive a reset link that expires in 15 minutes

Scenario: Reset password with unverified email
  Given a user whose email is not verified
  When they request a password reset
  Then they see an error: "Please verify your email first"
  And no reset email is sent
```

> **Key insight:** Cover both the happy path *and* the edge cases. As a QE engineer, you already think this way. That's your superpower when writing PRDs -- you naturally ask "what happens when this goes wrong?"

---

## 06 / The Five Deadly Sins of PRDs

1. **Jumping to solutions.** Starting with "add a modal dialog with a blue button" instead of "users need to reset their password." [[1]](#sources)
2. **Vague acceptance criteria.** "It should be fast" is not a requirement. [[1]](#sources)
3. **Ignoring NFRs.** Skipping security or performance requirements means they get decided ad-hoc during implementation -- or not at all. [[2]](#sources)
4. **Scope creep via omission.** If you don't explicitly list what's *out* of scope, everything is in scope. [[1]](#sources)
5. **Write-once, never update.** A PRD that doesn't evolve with the project becomes misleading. Add a changelog. [[1]](#sources)

---

## 07 / From PRD to Issues: Vertical Slicing

Once a PRD is written, it needs to become *work*. The best decomposition method is **vertical slicing** -- breaking the PRD into thin, end-to-end features rather than layer-by-layer tasks. [[5]](#sources)

### Horizontal (avoid) vs. Vertical (prefer)

**Horizontal slicing:**
- Issue 1: Create database schema
- Issue 2: Build API endpoints
- Issue 3: Build frontend UI
- Issue 4: Write tests
- *Nothing is demoable until all 4 are done.*

**Vertical slicing:**
- Issue 1: User can request password reset (schema + API + UI + tests)
- Issue 2: User can set new password via link (schema + API + UI + tests)
- Issue 3: Expired links show error (logic + UI + tests)
- *Each issue is independently demoable.*

### The five-step decomposition process [[5]](#sources)

1. **Gather context** -- read the PRD, understand the domain
2. **Explore the codebase** -- find what exists, identify prefactoring needs
3. **Draft vertical slices** -- each slice is a complete path through all layers
4. **Validate** -- check granularity, dependencies, and coverage against the PRD
5. **Publish issues** -- in dependency order, blockers first

### Issue template

| Section | Purpose |
|---------|---------|
| **Parent** | Links back to the PRD or epic |
| **What to build** | End-to-end behavior description |
| **Acceptance criteria** | Checklist of verifiable outcomes |
| **Blocked by** | Issue IDs of dependencies, or "None" |

---

## 08 / PRD Formats: Pick Your Weight Class

Not every feature needs 14 sections. Match the PRD format to the risk and size: [[1]](#sources)

| Format | When to use | Sections |
|--------|------------|----------|
| **Lean one-pager** | Minor enhancements, low risk | Problem, goal metric, scope, 3-5 acceptance criteria, at-risk NFRs |
| **Standard PRD** | Most features | Sections 1-7, plus whatever else applies |
| **Full PRD** | Large initiatives, compliance-sensitive | All 14 sections |
| **Amazon PR/FAQ** | When biggest risk is "will anyone care?" | Press release + FAQ, precursor to PRD |

---

## Sources

1. [Ulad Shauchenka -- "How to Write a Good PRD: A Tactical, Modern Guide"](https://www.uladshauchenka.com/p/how-to-write-a-good-product-requirements)
2. [Perforce -- "How to Write a PRD: Your Complete Guide"](https://www.perforce.com/blog/alm/how-write-product-requirements-document-prd)
3. [Parallel -- "How to Write Product Requirements: 2026 Guide & PRD Template"](https://www.parallelhq.com/blog/how-to-write-product-requirements)
4. [Carlin Yuen -- "Writing PRDs and Product Requirements" (Medium)](https://carlinyuen.medium.com/writing-prds-and-product-requirements-2effdb9c6def)
5. [DeepWiki -- "Breaking PRDs into Vertical Slices" (Matt Pocock's Skills)](https://deepwiki.com/mattpocock/skills/3.2-breaking-prds-into-vertical-slices)
