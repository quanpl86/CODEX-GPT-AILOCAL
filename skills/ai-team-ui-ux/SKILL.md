---
name: ai-team-ui-ux
description: Implement or review product interfaces using one design system, complete interaction states, accessibility and external Chrome verification. Use for web UI and educational game interfaces, not backend-only work.
---

# UI and UX

Inspect the existing product, tokens, shared components and main user journey first.
Preserve the approved brand. New screens use the same semantic colors, type scale,
spacing, radii, focus and component states; do not create screen-specific token systems.
For a new product, agree a baseline before expanding the component library.

- Specify the main task, information hierarchy, navigation and error recovery before code.
- Reuse or extend shared components; local AI can implement small components against their
  exact props/state contracts. Codex verifies integration and browser behavior.
- Include loading, empty, error, disabled and success states where the flow needs them.
- Check keyboard/focus order, labels, contrast, responsive layout, touch and reduced motion.
  Do not use color alone for learning feedback or validation.
- For games, keep game state independent of frame rate; test reset/retry, repeated input,
  listener/animation cleanup, paused/resumed play and learning objectives versus scoring.
- Run the final served source on external Chrome when the user requires it. Verify the
  actual happy path and relevant failure states, console/network and responsive sizes.
- Record URL/build, steps, expected/actual and evidence. Screenshots alone are not
  interaction tests; a ChatGPT browser session is not the product's runtime evidence.

Do not add an unrelated UI framework or redesign the entire product for a narrow task.
