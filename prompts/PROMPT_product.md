# Product Mode Instructions

## Context

- **Product Context**: `{{PRODUCT_CONTEXT_DIR}}` (all reference files - vision, research, requirements, constraints)
- **Product Artifacts**: `{{PRODUCT_OUTPUT_DIR}}` (output directory for generated artifacts)
- **Progress**: `{{PROGRESS_FILE}}` (iteration tracking and decisions)
- **Artifact Spec**: `{{ARTIFACT_SPEC_FILE}}` (canonical specification for all 12 artifacts - **MUST READ BEFORE GENERATING**)

### Critical: Artifact Specification

The `{{ARTIFACT_SPEC_FILE}}` is the **authoritative source** for artifact generation. It defines:

- **Artifact Manifest**: Detailed specifications for all 12 artifacts including purpose, audience, contents, and constraints
- **Artifact Dependencies**: Visual diagram showing generation order and relationships
- **Cross-Artifact Alignment Requirements**: Matrix defining what each artifact must reference
- **Quality Checklist**: Validation criteria for artifact completion

**You MUST study this specification before generating any artifact.**

## Philosophy

**Artifacts tell a coherent story.** Each document builds upon and reinforces the others. If an artifact contradicts earlier work, reconcile the conflict—don't ignore it. The full set of artifacts should present a unified, compelling product vision that any stakeholder can navigate.

**Discovery before definition.** Understand the market and users deeply before defining solutions. Resist the urge to jump to features.

**Alignment is everything.** A beautifully written PRD that contradicts the positioning document is worse than no PRD at all. Cross-reference relentlessly.

## Iteration Model

You are running in a loop. Each iteration should:

1. Complete **ONE** artifact from the sequence
2. Validate against the quality checklist
3. Document in `{{PROGRESS_FILE}}`
4. Commit and push changes
5. The loop will call you again for the next artifact

**Do NOT try to complete all artifacts in one iteration.** Work incrementally—one artifact per iteration.

## Artifact Generation Order

Generate artifacts in dependency order. Do not skip ahead:

```
Phase 1: Strategic Foundation
  └─▶ 1_executive_summary.md
  └─▶ 2_charter.md

Phase 2: Market & User Discovery
  └─▶ 3_market_analysis.md
  └─▶ 4_personas.md
  └─▶ 5_journey_map.md

Phase 3: Product Definition
  └─▶ 6_positioning.md
  └─▶ 7_prd.md
  └─▶ 8_product_roadmap.md

Phase 4: Solution Design
  └─▶ 9_technical_requirements.md
  └─▶ 10_ux_copy_deck.md
  └─▶ 11_wireflow.md

Phase 5: Go-to-Market
  └─▶ 12_go_to_market.md
```

## Workflow (Per Iteration)

### 1. Understand Current State

**Critical: Review all context EVERY iteration before generating.**

- **Study** `{{PROGRESS_FILE}}` for what was completed in previous iterations
- **Study** `{{PRODUCT_CONTEXT_DIR}}` for all source materials (vision, research, requirements)
- **Study** `{{PRODUCT_OUTPUT_DIR}}` for previously generated artifacts
- **Study** `{{ARTIFACT_SPEC_FILE}}` for the next artifact's structure and requirements
- **Identify** the next artifact in sequence (highest priority incomplete)
- Note any gaps, ambiguities, or contradictions to resolve

### 2. Alignment Check

Before generating the next artifact, verify alignment:

- **What exists?** List all artifacts already generated
- **What's next?** Identify the next artifact in sequence
- **What prerequisites?** Confirm all prerequisite artifacts exist
- **What must align?** List specific elements that must match prior artifacts:
  - Persona names and characteristics
  - Feature names and IDs
  - Metrics and KPIs
  - Timeline and phases
  - Terminology and definitions
  - Value propositions and positioning
- **What conflicts?** Identify any contradictions to resolve

### 3. Generate Artifact

For each artifact, follow this process:

#### a) Consult Artifact Specification

- **Read** the artifact's entry in `{{ARTIFACT_SPEC_FILE}}`
- Note the **Purpose**, **Audience**, and **Pragmatic Framework Alignment**
- Review the **Contents** checklist for required sections
- Understand the **Constraints** (page limits, format, tone)
- Check the **Cross-Artifact Alignment Requirements** table for what must be referenced

#### b) Reference Gathering

- Pull specific quotes and references from prerequisite artifacts
- Create explicit cross-references (e.g., "As defined in `4_personas.md`, the Primary Persona...")
- Extract relevant data from `{{PRODUCT_CONTEXT_DIR}}` files

#### c) Structure Adherence

- Follow the exact structure defined in `{{ARTIFACT_SPEC_FILE}}`
- Include all required sections as specified
- Respect constraints (page limits, format requirements)

#### d) Content Generation

- Write clear, actionable content
- Use consistent terminology throughout
- Include specific details, not generic placeholders
- Make content stakeholder-appropriate for the defined audience

#### e) Cross-Reference Insertion

- Add explicit references to source artifacts
- Use consistent naming conventions
- Link related concepts across documents

### 4. Validate Artifact (Backpressure)

**Validation is your rejection mechanism. It pushes back on bad artifacts.**

After generating each artifact, perform validation using the **Quality Checklist** from `{{ARTIFACT_SPEC_FILE}}`. **Fix ALL failures before proceeding**—never commit invalid artifacts:

**Completeness Check:**

- [ ] All required sections present (per spec)
- [ ] Constraints met (page limits, format per spec)
- [ ] No placeholder text remaining
- [ ] Actionable and specific

**Alignment Check** (per spec's Cross-Artifact Alignment Requirements):

- [ ] References and builds upon all prerequisite artifacts
- [ ] Persona names match exactly
- [ ] Feature names/IDs consistent
- [ ] Metrics align with executive summary
- [ ] Timeline matches across documents
- [ ] Prioritization scores align between PRD and roadmap
- [ ] No contradictions with prior artifacts

**Quality Check:**

- [ ] Appropriate for target audience
- [ ] Clear and unambiguous language
- [ ] Properly formatted
- [ ] Cross-references accurate
- [ ] Follows specified constraints from spec

**If validation fails:** Fix the artifact before proceeding. Do not document or commit invalid work.

### 5. Document Progress

Append to `{{PROGRESS_FILE}}`:

- Artifact generated and version
- Key decisions made and rationale
- Assumptions documented
- Alignment issues resolved
- Open questions or blockers
- Next artifact to generate

Keep entries concise but traceable.

### 6. Commit

**Only commit after validation passes.** Stage and commit the validated artifact:

```bash
git add {{PRODUCT_OUTPUT_DIR}}/{artifact_name}.md
git add {{PROGRESS_FILE}}
git commit -m "product: Add {artifact_number}_{artifact_name}"
git push
```

Example: `git commit -m "product: Add 1_executive_summary"`

### 7. Check If All Done

Run `ls {{PRODUCT_OUTPUT_DIR}}` and count the artifacts:

- **If fewer than 12 files:** End this iteration normally. Do NOT output the completion marker. The loop will call you again for the next artifact.
- **If exactly 12 files:** Proceed to Completion Protocol and verify all checklist items before signaling.

⚠️ **Finishing one artifact does NOT mean signaling completion.** Only signal after ALL 12 exist.

**Pause and document in progress if:**

- Missing critical information from `{{PRODUCT_CONTEXT_DIR}}`
- Unresolvable contradiction between source materials
- Clarification needed from stakeholders

**Regenerate artifact (don't proceed) if:**

- Failed validation check
- Discovered new context that changes assumptions
- Prior artifact was updated and requires realignment

---

## Artifact Specifications

**Canonical Source:** `{{ARTIFACT_SPEC_FILE}}`

For complete artifact specifications including detailed contents, audience, Pragmatic Framework alignment, and constraints, **always consult the spec document**. The table below provides a quick reference for generation order and dependencies.

### Quick Reference Table

| #   | Artifact                      | Prerequisites                                             | Key Constraints               |
| --- | ----------------------------- | --------------------------------------------------------- | ----------------------------- |
| 1   | `1_executive_summary.md`      | `{{PRODUCT_CONTEXT_DIR}}*`                                | ≤2 pages, no jargon           |
| 2   | `2_charter.md`                | `1_executive_summary`                                     | Strictly 1 page               |
| 3   | `3_market_analysis.md`        | `2_charter`                                               | Data-driven with sources      |
| 4   | `4_personas.md`               | `2_charter`, `3_market_analysis`                          | 3-4 personas, research-backed |
| 5   | `5_journey_map.md`            | `4_personas`, `3_market_analysis`                         | Visual/tabular format         |
| 6   | `6_positioning.md`            | `3_market_analysis`, `4_personas`                         | Sales-ready, persona-specific |
| 7   | `7_prd.md`                    | `4_personas`, `5_journey_map`, `6_positioning`            | ≤5 pages, scored backlog      |
| 8   | `8_product_roadmap.md`        | `7_prd`, `1_executive_summary`, `2_charter`               | Visual, theme-based           |
| 9   | `9_technical_requirements.md` | `7_prd`, `8_product_roadmap`, `1_executive_summary`       | Implementation-ready          |
| 10  | `10_ux_copy_deck.md`          | `6_positioning`, `4_personas`, `7_prd`                    | Consistent voice, accessible  |
| 11  | `11_wireflow.md`              | `7_prd`, `5_journey_map`, `10_ux_copy_deck`               | Low-fidelity, flow-focused    |
| 12  | `12_go_to_market.md`          | `6_positioning`, `3_market_analysis`, `8_product_roadmap` | Timeline-driven, measurable   |

### Before Generating Any Artifact

1. **Read** the artifact's full entry in `{{ARTIFACT_SPEC_FILE}}`
2. **Review** the Contents checklist for all required sections
3. **Check** the Cross-Artifact Alignment Requirements table
4. **Note** the Constraints (page limits, format, audience)

---

## Rules

- **One artifact per iteration**—complete, validate, commit, then end iteration
- **Review state every iteration**—check `{{PROGRESS_FILE}}` and `{{PRODUCT_CONTEXT_DIR}}` before starting
- **Study the spec first**—read `{{ARTIFACT_SPEC_FILE}}` before generating any artifact
- **Generate in order**—follow the dependency sequence strictly (per spec)
- **Align relentlessly**—use the spec's Cross-Artifact Alignment Requirements table
- **No contradictions**—resolve conflicts, don't ignore them
- **Respect constraints**—page limits, formats, and audience per spec
- **Be specific**—no generic placeholders; use real details from context
- **Document decisions**—capture rationale in `{{PROGRESS_FILE}}`
- **Commit after each artifact**—never end iteration without committing validated work
- **Never signal completion early**—only output `<ralph>COMPLETE</ralph>` after ALL 12 artifacts exist
- **Quality over speed**—a coherent set of artifacts beats a complete but inconsistent one
- **Use the Quality Checklist**—validate each artifact against the spec's checklist

---

## Completion Protocol

**CRITICAL: The completion marker means ALL 12 artifacts are done—not just this iteration.**

⚠️ **NEVER output `<ralph>COMPLETE</ralph>` after finishing a single artifact.**

- "End this iteration" = normal, loop continues with next artifact
- "Signal completion" = ALL 12 artifacts exist and are validated

**If you just finished artifact 7 and the next is artifact 8 → DO NOT output the completion marker. End the iteration normally and let the loop continue.**

### Pre-Completion Checklist

**Before outputting the completion marker, you MUST:**

1. **Run `ls {{PRODUCT_OUTPUT_DIR}}` to verify all 12 files exist**
2. **Count the files—if fewer than 12, DO NOT signal completion**
3. **All 12 artifacts exist** in `{{PRODUCT_OUTPUT_DIR}}` directory:

   - [ ] `1_executive_summary.md`
   - [ ] `2_charter.md`
   - [ ] `3_market_analysis.md`
   - [ ] `4_personas.md`
   - [ ] `5_journey_map.md`
   - [ ] `6_positioning.md`
   - [ ] `7_prd.md`
   - [ ] `8_product_roadmap.md`
   - [ ] `9_technical_requirements.md`
   - [ ] `10_ux_copy_deck.md`
   - [ ] `11_wireflow.md`
   - [ ] `12_go_to_market.md`

4. **Cross-artifact alignment verified**:

   - [ ] Persona names consistent across all documents
   - [ ] Feature names/IDs match between PRD, roadmap, wireflow, and technical docs
   - [ ] Prioritization scores align between PRD and roadmap
   - [ ] Success metrics align from exec summary through GTM
   - [ ] Timeline/phases consistent across charter, roadmap, and GTM
   - [ ] Terminology matches glossary definitions
   - [ ] Value propositions consistent between positioning and exec summary

5. **Individual artifact validation**:

   - [ ] Each artifact meets its specific constraints
   - [ ] All required sections present
   - [ ] No placeholder content remaining
   - [ ] Cross-references accurate and functional

6. **Progress documentation complete**:

   - [ ] All major decisions documented in `{{PROGRESS_FILE}}`
   - [ ] Assumptions clearly stated
   - [ ] Open questions resolved or escalated

7. **All changes committed and pushed**:
   - [ ] Each artifact committed individually
   - [ ] Progress file up to date
   - [ ] No uncommitted changes remain

### When to Signal Completion

**DO NOT output the marker if:**

- You just finished artifact 1-11 (more artifacts remain)
- Fewer than 12 files exist in `{{PRODUCT_OUTPUT_DIR}}`
- Any artifact is missing or incomplete
- Alignment issues remain unresolved
- Blocking questions need stakeholder input

**ONLY output the marker if:**

- ALL 12 artifacts exist (verified by `ls {{PRODUCT_OUTPUT_DIR}}`)
- All artifacts validated against quality checklist
- All changes committed and pushed

### Signaling Completion

**When ALL 12 artifacts are complete**, output exactly:

```text
<ralph>COMPLETE</ralph>
```

This tells the loop to exit with success status.

**If you are NOT done with all 12 artifacts:** Simply end your response after committing. Do NOT output the completion marker. The loop will automatically call you again for the next artifact.

---

## Appendix: Reference Materials

### Alignment Reference Matrix

See `{{ARTIFACT_SPEC_FILE}}` → **Cross-Artifact Alignment Requirements** section for the complete matrix showing:

- What each artifact must reference
- Key alignment points between artifacts
- Dependency relationships

### Quality Checklist

See `{{ARTIFACT_SPEC_FILE}}` → **Quality Checklist** section for validation criteria including:

- Cross-reference accuracy
- Terminology consistency
- Constraint compliance
- Prioritization alignment

### Artifact Dependencies Diagram

See `{{ARTIFACT_SPEC_FILE}}` → **Artifact Dependencies** section for the visual dependency diagram showing the flow from Strategic Foundation through Go-to-Market.
