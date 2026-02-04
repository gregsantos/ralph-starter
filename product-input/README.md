# Product Context Directory

Place your product context files here before running `./ralph.sh product`.

## Recommended Files

```
product-input/
├── vision.md           # Product vision, mission, goals
├── research.md         # User research findings, interviews
├── requirements.md     # Business requirements, constraints
├── constraints.md      # Technical/budget/timeline constraints
└── competitors.md      # Competitive analysis, market intel
```

## Usage

```bash
# Run product mode with default paths
./ralph.sh product

# Or specify custom paths
./ralph.sh product --context ./my-input/ --output ./my-output/
```

## What Gets Generated

See `../product-output/` for the 12 generated artifacts:

1. Executive Summary
2. Product Charter
3. Market Analysis
4. User Personas
5. Journey Map
6. Positioning Document
7. PRD (Product Requirements)
8. Product Roadmap
9. Technical Requirements
10. UX Copy Deck
11. Wireflow
12. Go-to-Market Plan

For artifact specifications, see `../docs/PRODUCT_ARTIFACT_SPEC.md`.
