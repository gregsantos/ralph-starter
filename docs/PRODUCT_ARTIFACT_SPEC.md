# Product Artifact Specification

Canonical specification for generating product documentation artifacts with Ralph Loop product mode.

## Overview

This specification defines the comprehensive set of markdown artifacts to be generated during product discovery, validation, and planning. These artifacts serve as the foundation for stakeholder buy-in, cross-functional alignment, and implementation handoff.

## Artifact Dependencies

```
Phase 1: Strategic Foundation
  ┌─────────────────────────┐
  │ 1_executive_summary.md  │ ◄── Product Context (vision, research, requirements)
  └───────────┬─────────────┘
              │
  ┌───────────▼─────────────┐
  │ 2_charter.md            │
  └───────────┬─────────────┘
              │
Phase 2: Market & User Discovery
              │
  ┌───────────▼─────────────┐
  │ 3_market_analysis.md    │
  └───────────┬─────────────┘
              │
  ┌───────────▼─────────────┐
  │ 4_personas.md           │ ◄── Also depends on 3_market_analysis
  └───────────┬─────────────┘
              │
  ┌───────────▼─────────────┐
  │ 5_journey_map.md        │ ◄── Also depends on 3_market_analysis
  └───────────┬─────────────┘
              │
Phase 3: Product Definition
              │
  ┌───────────▼─────────────┐
  │ 6_positioning.md        │ ◄── Also depends on 3_market_analysis, 4_personas
  └───────────┬─────────────┘
              │
  ┌───────────▼─────────────┐
  │ 7_prd.md                │ ◄── Also depends on 4_personas, 5_journey_map
  └───────────┬─────────────┘
              │
  ┌───────────▼─────────────┐
  │ 8_product_roadmap.md    │ ◄── Also depends on 1_executive_summary, 2_charter
  └───────────┬─────────────┘
              │
Phase 4: Solution Design
              │
  ┌───────────▼─────────────┐
  │ 9_technical_requirements│ ◄── Also depends on 1_executive_summary
  └───────────┬─────────────┘
              │
  ┌───────────▼─────────────┐
  │ 10_ux_copy_deck.md      │ ◄── Also depends on 4_personas, 6_positioning
  └───────────┬─────────────┘
              │
  ┌───────────▼─────────────┐
  │ 11_wireflow.md          │ ◄── Also depends on 5_journey_map, 10_ux_copy_deck
  └───────────┬─────────────┘
              │
Phase 5: Go-to-Market
              │
  ┌───────────▼─────────────┐
  │ 12_go_to_market.md      │ ◄── Also depends on 3_market_analysis, 6_positioning
  └─────────────────────────┘
```

---

## Artifact Manifest

### Phase 1: Strategic Foundation

#### 1. Executive Summary

| Attribute | Value |
|-----------|-------|
| **File** | `1_executive_summary.md` |
| **Purpose** | Investment-ready overview for executives and potential investors |
| **Audience** | Executive Team, Investors, Board Members |
| **Pragmatic Alignment** | Business Plan, Innovation |
| **Prerequisites** | Product context files |

**Contents:**
- [ ] Product vision statement (2-3 sentences)
- [ ] Problem-solution fit summary
- [ ] Target market and opportunity size (TAM/SAM/SOM)
- [ ] Key value propositions (3-5 bullets)
- [ ] Success metrics and KPIs
- [ ] Investment ask or resource requirements
- [ ] Timeline overview with key milestones
- [ ] Risk summary with mitigation strategies

**Constraints:** ≤2 pages | Executive-friendly language | No technical jargon

---

#### 2. Product Charter

| Attribute | Value |
|-----------|-------|
| **File** | `2_charter.md` |
| **Purpose** | One-page project charter establishing scope and alignment |
| **Audience** | All Stakeholders, Cross-functional Teams |
| **Pragmatic Alignment** | Market Problems, Stakeholder Communication |
| **Prerequisites** | `1_executive_summary.md` |

**Contents:**
- [ ] Problem statement (what pain exists, for whom)
- [ ] Product vision and mission
- [ ] Goals and objectives (SMART format)
- [ ] Scope boundaries (in-scope / out-of-scope)
- [ ] Key stakeholders and RACI matrix
- [ ] Assumptions and constraints
- [ ] Dependencies and prerequisites
- [ ] Success criteria and definition of done

**Constraints:** Strictly 1 page | Clear boundaries | Actionable scope

---

### Phase 2: Market & User Discovery

#### 3. Market Analysis

| Attribute | Value |
|-----------|-------|
| **File** | `3_market_analysis.md` |
| **Purpose** | Comprehensive market intelligence and competitive positioning |
| **Audience** | Strategy Team, Executives, Product Marketing |
| **Pragmatic Alignment** | Market Definition, Competitive Landscape, Distinctive Competencies, Win/Loss Analysis |
| **Prerequisites** | `2_charter.md` |

**Contents:**
- [ ] Market definition and segmentation
- [ ] Total Addressable Market (TAM) analysis
- [ ] Target segment profiles with sizing
- [ ] Competitive landscape matrix (features, pricing, positioning)
- [ ] Competitor strengths and weaknesses
- [ ] Distinctive competencies assessment
- [ ] Market trends and dynamics
- [ ] Win/loss insights (if available)
- [ ] Strategic opportunities and threats
- [ ] Recommended market entry strategy

**Constraints:** Data-driven | Include sources | Visual matrices encouraged

---

#### 4. User Personas

| Attribute | Value |
|-----------|-------|
| **File** | `4_personas.md` |
| **Purpose** | Archetypical user and buyer profiles driving product decisions |
| **Audience** | Design, Engineering, Marketing, Sales |
| **Pragmatic Alignment** | User Personas, Buyer Personas |
| **Prerequisites** | `2_charter.md`, `3_market_analysis.md` |

**Contents:**
- [ ] 3-4 distinct personas (mix of users and buyers)
- [ ] For each persona:
  - [ ] Persona name and archetype
  - [ ] Demographics and firmographics
  - [ ] Role and responsibilities
  - [ ] Goals and motivations
  - [ ] Pain points and frustrations
  - [ ] Current solutions and workarounds
  - [ ] Decision-making process (for buyers)
  - [ ] Technology comfort level
  - [ ] Key quotes (voice of customer)
  - [ ] Success metrics from their perspective
  - [ ] Photo/avatar placeholder
- [ ] Primary persona designation (clearly marked)
- [ ] Persona prioritization (primary, secondary)

**Constraints:** Research-backed | Empathy-focused | Actionable for design

---

#### 5. Journey Map

| Attribute | Value |
|-----------|-------|
| **File** | `5_journey_map.md` |
| **Purpose** | End-to-end experience mapping for primary persona |
| **Audience** | Design, Product, Marketing, Customer Success |
| **Pragmatic Alignment** | Buyer Experience, Use Scenarios |
| **Prerequisites** | `4_personas.md`, `3_market_analysis.md` |

**Contents:**
- [ ] Journey overview and scope
- [ ] Persona reference (link to personas doc)
- [ ] Journey stages (Awareness → Consideration → Decision → Onboarding → Usage → Advocacy)
- [ ] For each stage:
  - [ ] User goals and expectations
  - [ ] Actions and behaviors
  - [ ] Touchpoints and channels
  - [ ] Thoughts and questions
  - [ ] Emotional state (sentiment curve)
  - [ ] Pain points and friction
  - [ ] Opportunities for delight
- [ ] Moments of truth identification
- [ ] Service blueprint elements (frontstage/backstage)
- [ ] Key metrics per stage

**Constraints:** Visual/tabular format | Empathy-driven | Opportunity-focused

---

### Phase 3: Product Definition

#### 6. Positioning Document

| Attribute | Value |
|-----------|-------|
| **File** | `6_positioning.md` |
| **Purpose** | Strategic positioning and messaging framework |
| **Audience** | Marketing, Sales, Product, Executives |
| **Pragmatic Alignment** | Positioning, Distinctive Competencies |
| **Prerequisites** | `3_market_analysis.md`, `4_personas.md` |

**Contents:**
- [ ] Positioning statement (Geoffrey Moore format)
- [ ] Value proposition canvas
- [ ] Key differentiators (vs. competitors)
- [ ] Messaging hierarchy:
  - [ ] Tagline
  - [ ] Elevator pitch (30 seconds)
  - [ ] Key messages by persona
  - [ ] Proof points and evidence
- [ ] Competitive positioning map (2x2 matrix)
- [ ] Brand voice and tone guidelines
- [ ] Objection handling framework
- [ ] Messaging do's and don'ts

**Constraints:** Clear differentiation | Persona-specific | Sales-ready

---

#### 7. Product Requirements Document (PRD)

| Attribute | Value |
|-----------|-------|
| **File** | `7_prd.md` |
| **Purpose** | Product requirements with features and acceptance criteria |
| **Audience** | Engineering, Design, QA, Product |
| **Pragmatic Alignment** | Requirements, Use Scenarios |
| **Prerequisites** | `4_personas.md`, `5_journey_map.md`, `6_positioning.md` |

**Contents:**
- [ ] Document metadata (version, author, date, status)
- [ ] Executive summary (link to exec summary)
- [ ] Goals and success metrics
- [ ] **Prioritization Framework:**
  - [ ] Scoring methodology (RICE, ICE, or Value/Effort)
  - [ ] Impact criteria definitions
  - [ ] Effort estimation approach
  - [ ] Prioritization matrix/scorecard
- [ ] User stories with acceptance criteria (Given/When/Then)
- [ ] Feature specifications:
  - [ ] Feature name and ID
  - [ ] User story reference
  - [ ] Description and rationale
  - [ ] Acceptance criteria
  - [ ] Priority score and rationale
  - [ ] Dependencies
  - [ ] Open questions
- [ ] Non-functional requirements (performance, security, accessibility)
- [ ] Constraints and limitations
- [ ] MVP definition (what's in v1.0 vs. future)
- [ ] Out of scope items
- [ ] Glossary of terms

**Constraints:** ≤5 pages (excluding backlog) | Testable criteria | Scored and ranked backlog

---

#### 8. Product Roadmap

| Attribute | Value |
|-----------|-------|
| **File** | `8_product_roadmap.md` |
| **Purpose** | Strategic, visual plan for product development direction and timeline |
| **Audience** | Executives, Product, Engineering, Stakeholders, Investors |
| **Pragmatic Alignment** | Product Roadmap, Product Portfolio, Innovation |
| **Prerequisites** | `7_prd.md`, `1_executive_summary.md`, `2_charter.md` |

**Contents:**
- [ ] Roadmap vision statement
- [ ] Strategic themes and objectives
- [ ] Time horizon definition (Now/Next/Later or quarterly)
- [ ] **Roadmap visualization:**
  - [ ] Theme-based or goal-based organization
  - [ ] Swimlanes by workstream/team (if applicable)
  - [ ] Milestone markers
  - [ ] Dependency indicators
- [ ] Phase breakdown:
  - [ ] Phase name and timeframe
  - [ ] Key deliverables and features (reference PRD IDs)
  - [ ] Success criteria per phase
  - [ ] Dependencies and prerequisites
  - [ ] Resource/team implications
- [ ] MVP vs. MLP (Minimum Lovable Product) definition
- [ ] Feature parking lot (future considerations)
- [ ] Roadmap assumptions and risks
- [ ] Review and update cadence
- [ ] **Note:** Roadmap is a plan, not a commitment (change management approach)

**Constraints:** Visual format required | Theme-based not date-driven | Flexible horizons

---

### Phase 4: Solution Design

#### 9. Technical Requirements

| Attribute | Value |
|-----------|-------|
| **File** | `9_technical_requirements.md` |
| **Purpose** | Technology stack, architecture decisions, and development setup |
| **Audience** | Engineering, DevOps, Technical Leadership |
| **Pragmatic Alignment** | Buy/Build/Partner, Asset Assessment |
| **Prerequisites** | `7_prd.md`, `8_product_roadmap.md`, `1_executive_summary.md` |

**Contents:**
- [ ] Technical vision and principles
- [ ] Architecture overview (high-level diagram description)
- [ ] Technology stack decisions:
  - [ ] Frontend framework and libraries
  - [ ] Backend/API layer
  - [ ] Database and data storage
  - [ ] Infrastructure and hosting
  - [ ] Third-party services and APIs
- [ ] Build vs. Buy vs. Partner analysis
- [ ] Integration requirements
- [ ] Security requirements and compliance
- [ ] Performance requirements and SLAs
- [ ] Scalability considerations
- [ ] Development environment setup:
  - [ ] Prerequisites
  - [ ] Installation commands
  - [ ] Configuration
  - [ ] Local development workflow
- [ ] CI/CD pipeline requirements
- [ ] Monitoring and observability needs
- [ ] Technical debt considerations
- [ ] Migration/upgrade path (if applicable)

**Constraints:** Justified decisions | Implementation-ready | Maintainable

---

#### 10. UX Copy Deck

| Attribute | Value |
|-----------|-------|
| **File** | `10_ux_copy_deck.md` |
| **Purpose** | Information architecture and UX copy guidelines |
| **Audience** | Design, Content, Engineering, Marketing |
| **Pragmatic Alignment** | Positioning, User Personas |
| **Prerequisites** | `6_positioning.md`, `4_personas.md`, `7_prd.md` |

**Contents:**
- [ ] Voice and tone principles
- [ ] Content strategy overview
- [ ] Information architecture:
  - [ ] Site/app structure
  - [ ] Navigation hierarchy
  - [ ] Content types and templates
- [ ] UX copy specifications:
  - [ ] Headlines and titles
  - [ ] Button labels and CTAs
  - [ ] Form labels and placeholders
  - [ ] Error messages and validation
  - [ ] Empty states
  - [ ] Loading states
  - [ ] Success/confirmation messages
  - [ ] Onboarding copy
  - [ ] Tooltip and help text
- [ ] Terminology glossary (user-facing)
- [ ] Localization considerations
- [ ] Accessibility (WCAG) copy guidelines
- [ ] SEO considerations (if web-based)

**Constraints:** Consistent voice | Accessible | Action-oriented

---

#### 11. Wireflow

| Attribute | Value |
|-----------|-------|
| **File** | `11_wireflow.md` |
| **Purpose** | Low-fidelity user flows and screen specifications |
| **Audience** | Design, Engineering, Product, QA |
| **Pragmatic Alignment** | Use Scenarios, Buyer Experience |
| **Prerequisites** | `7_prd.md`, `5_journey_map.md`, `10_ux_copy_deck.md` |

**Contents:**
- [ ] Flow overview and scope
- [ ] User flow diagrams (ASCII or Mermaid notation):
  - [ ] Primary user flows
  - [ ] Alternative paths
  - [ ] Error paths
  - [ ] Edge cases
- [ ] Screen inventory:
  - [ ] Screen name and ID
  - [ ] Purpose and user goal
  - [ ] Entry points
  - [ ] Exit points
  - [ ] Key components/elements
  - [ ] Interactions and behaviors
  - [ ] State variations
  - [ ] Data requirements
- [ ] Responsive breakpoint considerations
- [ ] Accessibility requirements per screen
- [ ] Animation/transition notes
- [ ] Component reuse mapping

**Constraints:** Low-fidelity focus | Flow-first | Annotated clearly

---

### Phase 5: Go-to-Market

#### 12. Go-to-Market Plan

| Attribute | Value |
|-----------|-------|
| **File** | `12_go_to_market.md` |
| **Purpose** | Launch strategy, pricing, and market entry plan |
| **Audience** | Marketing, Sales, Executives, Product |
| **Pragmatic Alignment** | Marketing Plan, Launch, Pricing, Distribution Strategy, Awareness, Advocacy |
| **Prerequisites** | `6_positioning.md`, `3_market_analysis.md`, `8_product_roadmap.md` |

**Contents:**
- [ ] GTM strategy overview
- [ ] Launch phases and timeline:
  - [ ] Alpha/Beta strategy
  - [ ] Soft launch
  - [ ] General availability
- [ ] Target segment prioritization
- [ ] Pricing strategy:
  - [ ] Pricing model (subscription, usage, one-time)
  - [ ] Price points and tiers
  - [ ] Competitive pricing analysis
  - [ ] Discounting and promotion strategy
- [ ] Distribution channels:
  - [ ] Direct vs. indirect
  - [ ] Channel partner strategy
  - [ ] Platform/marketplace considerations
- [ ] Marketing plan summary:
  - [ ] Awareness campaigns
  - [ ] Content marketing
  - [ ] Demand generation
  - [ ] PR and communications
- [ ] Sales enablement needs (high-level)
- [ ] Launch success metrics
- [ ] Risk mitigation plan
- [ ] Post-launch optimization strategy

**Constraints:** Timeline-driven | Measurable | Resource-aware

---

## Cross-Artifact Alignment Requirements

Each artifact must maintain consistency with previously generated artifacts:

| When Creating... | Must Reference & Align With... |
|------------------|-------------------------------|
| `2_charter.md` | `1_executive_summary.md` goals and metrics |
| `3_market_analysis.md` | `2_charter.md` scope and target market |
| `4_personas.md` | `2_charter.md` problem statement, `3_market_analysis.md` segments |
| `5_journey_map.md` | `4_personas.md` primary persona, `3_market_analysis.md` competitive gaps |
| `6_positioning.md` | `3_market_analysis.md` competitive landscape, `4_personas.md` pain points |
| `7_prd.md` | `4_personas.md` user stories, `5_journey_map.md` opportunities, `6_positioning.md` value props |
| `8_product_roadmap.md` | `7_prd.md` prioritized features, `1_executive_summary.md` timeline, `2_charter.md` goals |
| `9_technical_requirements.md` | `7_prd.md` features, `8_product_roadmap.md` phases, `1_executive_summary.md` constraints |
| `10_ux_copy_deck.md` | `6_positioning.md` voice/tone, `4_personas.md` language, `7_prd.md` features |
| `11_wireflow.md` | `7_prd.md` user stories, `5_journey_map.md` flows, `10_ux_copy_deck.md` IA |
| `12_go_to_market.md` | `6_positioning.md` messaging, `3_market_analysis.md` channels, `8_product_roadmap.md` timeline |

### Critical Alignment Checks

1. **Persona names** must be identical across: Personas, Journey Map, PRD, UX Copy
2. **Feature IDs** must match between: PRD, Roadmap, Technical Requirements, Wireflow
3. **Success metrics** must align: Executive Summary → Charter → PRD → Roadmap → GTM
4. **Timeline/phases** must be consistent: Charter → Roadmap → GTM
5. **Terminology** must follow glossary defined in UX Copy Deck
6. **Value propositions** must align: Positioning → Executive Summary → GTM
7. **Prioritization scores** must align between PRD and Roadmap

---

## Quality Checklist

### Before Committing Any Artifact

**Completeness:**
- [ ] All required sections present (per manifest above)
- [ ] Constraints met (page limits, format)
- [ ] No placeholder text remaining
- [ ] Content is specific and actionable

**Alignment:**
- [ ] References and builds upon all prerequisite artifacts
- [ ] Terminology matches glossary
- [ ] Names (personas, features) are consistent
- [ ] Metrics align with executive summary
- [ ] Timeline matches charter and roadmap

**Quality:**
- [ ] Appropriate for target audience
- [ ] Clear and unambiguous
- [ ] Properly formatted (markdown)
- [ ] Visual elements where required

### Final Validation (All 12 Complete)

- [ ] All 12 artifacts exist in output directory
- [ ] Persona names consistent across all documents
- [ ] Feature IDs traceable from PRD → Roadmap → Technical → Wireflow
- [ ] Prioritization scores align between PRD and Roadmap
- [ ] Success metrics flow from Executive Summary through GTM
- [ ] No contradictions between artifacts
- [ ] All cross-references are accurate

---

## Usage

```bash
# Generate product artifacts (default paths)
./ralph.sh product

# Custom context and output directories
./ralph.sh product --context ./my-input/ --output ./my-output/

# Use a different artifact spec
./ralph.sh product --artifact-spec ./path/to/spec.md

# Dry run to preview configuration
./ralph.sh product --dry-run
```

### Directory Setup

Before running product mode, create your context directory with source materials:

```
product-input/
├── vision.md           # Product vision and goals
├── research.md         # User research findings
├── requirements.md     # Business requirements
├── constraints.md      # Technical/business constraints
└── competitors.md      # Competitive intelligence
```

Artifacts will be generated to:

```
product-output/
├── 1_executive_summary.md
├── 2_charter.md
├── 3_market_analysis.md
├── 4_personas.md
├── 5_journey_map.md
├── 6_positioning.md
├── 7_prd.md
├── 8_product_roadmap.md
├── 9_technical_requirements.md
├── 10_ux_copy_deck.md
├── 11_wireflow.md
└── 12_go_to_market.md
```

---

## Quick Reference Table

| # | Artifact | Prerequisites | Key Constraints |
|---|----------|---------------|-----------------|
| 1 | `1_executive_summary.md` | Product context files | ≤2 pages, no jargon |
| 2 | `2_charter.md` | `1_executive_summary` | Strictly 1 page |
| 3 | `3_market_analysis.md` | `2_charter` | Data-driven with sources |
| 4 | `4_personas.md` | `2_charter`, `3_market_analysis` | 3-4 personas, research-backed |
| 5 | `5_journey_map.md` | `4_personas`, `3_market_analysis` | Visual/tabular format |
| 6 | `6_positioning.md` | `3_market_analysis`, `4_personas` | Sales-ready, persona-specific |
| 7 | `7_prd.md` | `4_personas`, `5_journey_map`, `6_positioning` | ≤5 pages, scored backlog |
| 8 | `8_product_roadmap.md` | `7_prd`, `1_executive_summary`, `2_charter` | Visual, theme-based |
| 9 | `9_technical_requirements.md` | `7_prd`, `8_product_roadmap`, `1_executive_summary` | Implementation-ready |
| 10 | `10_ux_copy_deck.md` | `6_positioning`, `4_personas`, `7_prd` | Consistent voice, accessible |
| 11 | `11_wireflow.md` | `7_prd`, `5_journey_map`, `10_ux_copy_deck` | Low-fidelity, flow-focused |
| 12 | `12_go_to_market.md` | `6_positioning`, `3_market_analysis`, `8_product_roadmap` | Timeline-driven, measurable |
