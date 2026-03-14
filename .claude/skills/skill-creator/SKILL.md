---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

## Creating a Skill

### Capture Intent

1. What should this skill enable Claude to do?
2. When should this skill trigger?
3. What's the expected output format?
4. Should we set up test cases?

### Write the SKILL.md

Based on user interview, fill in:

- **name**: Skill identifier
- **description**: When to trigger, what it does. Include specific contexts for when to use it. Make descriptions "pushy" to combat undertriggering.
- **the rest of the skill instructions**

### Skill Anatomy

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Executable code
    ├── references/ - Docs loaded as needed
    └── assets/     - Templates, icons, fonts
```

### Progressive Disclosure

1. **Metadata** (name + description) - Always in context (~100 words)
2. **SKILL.md body** - In context when skill triggers (<500 lines ideal)
3. **Bundled resources** - As needed (unlimited)

**Key patterns:**
- Keep SKILL.md under 500 lines
- Reference files clearly with guidance on when to read them
- For large reference files (>300 lines), include a table of contents

### Test Cases

After writing the skill draft, create 2-3 realistic test prompts.

Save test cases to `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

## Running Test Cases

### Step 1: Spawn Runs

For each test case, spawn two subagents — one with the skill, one without.

### Step 2: Draft Assertions

While runs are in progress, draft quantitative assertions.

### Step 3: Capture Timing

Save timing data to `timing.json` when runs complete.

### Step 4: Grade and Aggregate

1. Grade each run against assertions
2. Run aggregation: `python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>`
3. Launch viewer: `python <skill-creator-path>/eval-viewer/generate_review.py <workspace>/iteration-N`

### Step 5: Read Feedback

Read `feedback.json` after user reviews.

## Improving the Skill

### How to Think About Improvements

1. **Generalize from the feedback** - Create skills that work across many prompts
2. **Keep the prompt lean** - Remove things that aren't pulling their weight
3. **Explain the why** - Help the model understand why things are important
4. **Look for repeated work** - Bundle common helper scripts

### The Iteration Loop

1. Apply improvements
2. Rerun all test cases into a new `iteration-<N+1>/` directory
3. Launch reviewer with `--previous-workspace`
4. Wait for user feedback
5. Repeat until satisfied

## Description Optimization

After skill is complete, optimize the description for better triggering:

1. Generate 20 trigger eval queries (mix of should-trigger and should-not-trigger)
2. Review with user via HTML template
3. Run optimization: `python -m scripts.run_loop --eval-set <path> --skill-path <path> --model <model-id> --max-iterations 5`
4. Apply the best description from results

## Reference Files

- `agents/grader.md` — How to evaluate assertions against outputs
- `agents/comparator.md` — How to do blind A/B comparison
- `agents/analyzer.md` — How to analyze why one version beat another
- `references/schemas.md` — JSON structures for evals.json, grading.json, etc.