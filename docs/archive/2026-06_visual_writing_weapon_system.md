# Visual Writing weapon system: discussion draft v2

> This document is a discussion anchor rather than a set of conclusions; it is also a dogfood exercise, written itself according to the low-cognitive-burden principles, to test whether those principles can carry the weight.
>
> v2 changes: absorbed criticism from three sub-agents; cut the "four axes" down to "1 tension axis + adaptive path + 1 upfront gate + 1 uncertainty axis"; split the anti-patterns into severities; changed self-eval from questions to scan actions; moved the original debate into `<details>` at the end.
>
> v2.1 changes (reader feedback): moved "attention budget" from a tension axis to an input of the adaptive path. Whether the reader has 30 seconds or 30 minutes should not be preset; the document should carry both trajectories at once. Only this reframe handles counterexamples like "the same RFC as a first draft vs a heavily changed draft".
>
> **2026-06-14 status update**: the methodology itself has sunk into the "Visual Cognitive Load Reduction" section of `rules/skills/workflow_internal_writing.md` (outside this repo path, under `knowledge_working/rules/skills/`). It covers the three axioms, the arsenal overview, the adaptive path mechanism, the delta from the old markdown-first practice, and the items not yet decided. **This document is kept as a dogfood case analysis, recording the full path of "one PRD/RFC dogfood + three sub-agent debates"**. For the live methodology, read the skill; this is the historical entry point.

## The real question

"Should visual be used at all" and "should more or less of it be used" are both fake questions. The real question is:

> **When AI writes an internal document, when does visual truly reduce burden, and when does visual add fake signals?**

If this question is built into the AI writing loop, how many weapons to keep, how long, and whether to use chips are all natural corollaries.

## Evidence first: 8 anti-patterns dug out of real dogfood material

These 8 are ground truth that the anti-pattern hunter found in real documents I had just written, nothing imagined. Ordered by "severity × fix cost"; the first 3 **need action first, this weekend**.

<style>
.ap-grid{display:grid;grid-template-columns:1fr;gap:8px;margin:12px 0}
.ap-crit{padding:10px 12px;border-left:4px solid var(--bad-border,#ef4444);background:var(--card-bg,#fafbfc);color:var(--fg,#243244);border-radius:0 8px 8px 0}
.ap-form{padding:10px 12px;border-left:4px solid var(--warn-border,#f59e0b);background:var(--card-bg,#fafbfc);color:var(--fg,#243244);border-radius:0 8px 8px 0}
.ap-style{padding:10px 12px;border-left:4px solid var(--block-border,#6b7280);background:var(--card-bg,#fafbfc);color:var(--fg,#243244);border-radius:0 8px 8px 0}
.ap-grid h4{margin:0 0 4px;font-size:.95rem;color:var(--fg,#243244)}
.ap-evi{display:block;margin:3px 0;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.85rem;color:var(--link,#2e5c8a)}
.ap-grid p{margin:3px 0;font-size:.9rem;color:var(--fg,#243244)}
</style>

<div class="ap-grid">

<div class="ap-crit">
<h4>① Cross-document self-contradiction (fix immediately)</h4>
<span class="ap-evi">Evidence · sub-PRD §5.1 left strikethrough "~~Native default~~ update: Web default"; sub-RFC §12 still says "decision: not default for now"</span>
<p>The same decision circulated in 5 versions (sub-PRD / sub-RFC / main PRD / main RFC / WORKING), and only 2 made it into git. Readers cannot tell which one is the source of truth.</p>
</div>

<div class="ap-crit">
<h4>② Table + card mirror used as "fallback", double maintenance (fix immediately)</h4>
<span class="ap-evi">Evidence · visual_explainer_html_md.md "first-screen status cards" + "pure Markdown fallback" mapped item by item</span>
<p>The reason is renderer compatibility; the cost is maintaining the same information twice. One missed edit and they diverge. A fallback should be a rendering degradation, rather than a hand-copied duplicate.</p>
</div>

<div class="ap-crit">
<h4>③ <code>&lt;details&gt;</code> holding core conclusions instead of optional material (fix immediately)</h4>
<span class="ap-evi">Evidence · the details in main RFC §7.5 hold rendering path / JS dependency / security model, which are the target content for RFC engineering readers</span>
<p>"Expand as needed" implies optional reading, but the content is required. Readers either expand it, which makes folding pointless, or skip it and the RFC degrades into a marketing page.</p>
</div>

<div class="ap-form">
<h4>④ Decision reversals stacked as strikethrough + update stamps rather than rewriting the text</h4>
<span class="ap-evi">Evidence · sub-PRD §5.1 "~~first version keeps Native~~ **update (2026-06-14): ...**"</span>
<p>This pours git history back into the body text. This is exactly how documents fall into disrepair after half a year.</p>
</div>

<div class="ap-form">
<h4>⑤ Status classification too fine-grained and drifting within the document</h4>
<span class="ap-evi">Evidence · visual_explainer_html_md.md switches the chip axis 3 times across different sections</span>
<p>"holds but weak / rejected / candidate / blocked" vs "done / next round" vs "not priority / priority / parallel"; the reader has to maintain several sets of color-code semantic mappings.</p>
</div>

<div class="ap-form">
<h4>⑥ Chips used as end-of-line status stamps, one flat color carrying no information</h4>
<span class="ap-evi">Evidence · OpenCode_iOS_Client_PRD.md §4.3.5 status table has 7/8 rows marked "shipped"</span>
<p>A chip here has no filtering value and no comparison value; it just puts a capsule around the word "shipped". Readers instead have to scan line by line for what is not done.<br><em>Note: this document's own v1 fell into this anti-pattern (8 all-red cards); v2 only fixed it by splitting the cards into 3 severity tiers.</em></p>
</div>

<div class="ap-style">
<h4>⑦ Status table row keys use Phase/Sprint rather than user experience</h4>
<span class="ap-evi">Evidence · 2026-06_markdown_web_preview_prd.md (archive/) §"implementation progress" vs main PRD §4.3.5, same information ordered differently</span>
<p>The same team wrote two versions in the same week, which shows AI defaults back to engineering chronology. If the order changes after row keys are replaced with "what the user sees in the App", the current ordering is the anti-pattern.</p>
</div>

<div class="ap-style">
<h4>⑧ Headings state category names rather than verdicts</h4>
<span class="ap-evi">Evidence · sub-RFC §5 "solution overview", §6 "component design", §7 "security model", §8 "UI design"</span>
<p>The skill already warns against headings like "Flowchart" and "Matrix", but "security model" is the same problem one level deeper. "Security model" → "WebView only runs bundle JS; the sanitizer strips scripts after rendering" is a verdict.</p>
</div>

</div>

<p><em>Red border = content or factual errors that mislead readers; orange border = maintainability problems that will decay over time; gray border = form problems that are tiring to read but do not bleed.</em></p>

## The framing that grew out of the evidence

Read the 8 anti-patterns above the other way around and the real fight is over these two tension axes plus two judgment gates, one before and one after; "more or less visual" was never the actual fight.

### One tension axis + adaptive path (block level)

**Axis A · what the reader must do in this block**: commit-to-action (scan and decide) or explore-to-understand (read to think it through)?
For the former, visual is a sharp tool; for the latter, visual creates the illusion of "thinking I understood". **Decision signals**: does this block sit right next to an action item list / does its heading contain a verb? Commit. Does this block argue "why X does not hold" / is it followed by a tradeoff section? Explore.

**"Attention budget" is an input to the adaptive reading path rather than a tension axis**. For the same RFC, a reader facing an intuitive small change is done after a 30-second scan; a reader facing a heavily changed draft will audit it paragraph by paragraph. **Preset the budget as a static value, 30 seconds or 30 minutes, and it will be wrong either way**; the document should carry both trajectories at once. Concretely: give the skimming layer the first screen (visual + a one-sentence takeaway), and provide deep-reading hooks in the body through anchors / links / `<details>`, so a suspicious spot found while skimming can zoom in to evidence, tradeoffs, and reasoning. This is why we need the HTML extension layer instead of markdown alone: the adaptive path relies on anchors / folding / hover, and markdown by itself is not enough.

The unit of judgment is the **block**, not the whole document. A weekly report can have a commit first screen (status cards work well) with explore below it (argument sections must be text). Locking a whole document to one endpoint is overfitting.

### Two gates, one before and one after (pass the gates before discussing the tension axes)

**Upfront gate · shared context depth**: can the reader decode the visual semantics you plan to use?
A reader set of ≤ 3 people within this week = thick; cross-team / cross-quarter / newcomers = thin. **Thin vetoes visual outright, however the tension axes vote**. This gate is a precondition rather than a tension.

**Trailing gate · factual credibility**: are the underlying conclusions stable?
Visual makes things "look certain". When the facts are still moving (decision reversals, unsettled data, an unmerged PR), visual's appearance of certainty becomes a liability; readers will over-trust it. The root cause of anti-patterns ①②④ is visual packaging unstable facts as certain. **While the facts are unsettled, downgrade visual to a table + timestamps, or plain text**.

## Self-evaluation: after writing, scan three things

No questions before writing (AI has no answers); instead, after writing, run **scans + thresholds + repair paths**.

<style>
.se-tbl{margin:8px 0}
.se-tbl table{width:100%;border-collapse:collapse}
.se-tbl th,.se-tbl td{padding:8px 10px;text-align:left;border-bottom:1px solid var(--border,#e6e8eb);color:var(--fg,#243244);font-size:.9rem;vertical-align:top}
.se-tbl th{font-weight:600;background:var(--card-bg,#fafbfc)}
.se-tbl code{font-size:.85rem;background:var(--code-bg,#f0f0f0);padding:1px 5px;border-radius:3px}
</style>

<div class="se-tbl">

| Scan | Threshold = trigger | Repair |
|---|---|---|
| Count the color enum values in the chip column | dominant color ≥ 80% | delete the chip column; exceptional rows become an end-of-line `⚠ Blocking` annotation |
| `grep -r` the current repo for this section's core conclusion | ≥ 2 hits | change this section to `see [path]` and do not copy the text |
| For each `##` / `###` heading: after deleting it, can the first sentence of the body stand alone as the sub-heading | yes = the heading is a category name | rewrite the heading as that verdict sentence from the body |
| Does the text contain strikethrough + "(date)" stamps | present = history poured into the body | rewrite the body as the latest decision and move old versions to a changelog at the end |
| With the content inside `<details>` deleted, can the reader still complete the primary judgment | no = details holds core material | move the core out of details and leave only audit material in the folded area |
| Are the chip / status classification enum values the same set across the earlier and later sections of this document | different = semantic drift | unify one set document-wide (suggest capping at ok/warn/bad/block) |

</div>

## Weapon lineage vs decision mechanism: unequal weight; the latter is the foundation

The joint optimization the user raised is a trade-off, but **the two legs do not weigh the same**.

**Foundation: the decision mechanism**. If the AI internalizes "pass the two gates first, then judge the two axes", even a 4-weapon arsenal (short paragraphs / short tables / details / chips when evenly distributed) hits the vast majority of scenarios.

**Upper layer: the weapon lineage**. More weapons → form factors hit precisely and each use reduces burden deeply; but more weapons → the AI's decision cost and error rate rise. So adding weapons requires dogfood evidence (add only after repeated gaps show up); add nothing for the sake of "a richer arsenal".

Skill upgrade priority: ① internalize the two gates + two axes (foundation) → ② write the self-eval scan table as executable guardrails → ③ add the 8 anti-patterns to the failure mode table → ④ add weapons cautiously (nothing currently must be added).

## Items not yet decided

1. **Downgrade chips overall?** Anti-pattern ⑥ exposed chips as pure decoration when a whole column is one color. Should chips be changed to "used only for anomalies/exceptions" and not appear by default?
2. **How to fix cross-document copying**: (a) single source + links from the other documents / (b) accept the copy + a last-synced stamp. (a) is clean but readers must jump; (b) is realistic but will surely decay after 6 months.
3. **The standard operation for decision reversals**: rewrite the body directly + move history to a changelog, vs strikethrough + update stamps to preserve the audit trail. The latter destroys traceability.
4. **The boundary between the "reader intent" and "attention budget" axes**: Framing Skeptic suggested merging them, but I kept both. A boss reading a 6-screen quarterly doc is commit + high budget; merged, this counterexample cannot be captured. Is this judgment right?

---

## Appendix: the original debates of three sub-agents (audit material, optional reading)

<details>
<summary>Framing Skeptic: does the four-axis framing hold up under attack?</summary>

Having read the whole document, I attack directly. I answer in five points and give my suggested topology at the end.

**1. Independence of the four axes: one pair is tautological, one pair is nested**

**Axis 2 (lifecycle) and axis 4 (reader intent) are highly correlated**. For a read-once-and-discard document, the reader is almost certainly commit-to-action; for a long-lived PRD/RFC, the reader is most likely explore-to-understand. The two axes covary (~70%). But a **retrospective written for yourself 6 months later** is long lifecycle + explore, and an **onboarding doc for an unfamiliar newcomer** is long lifecycle + commit-to-action. So the two axes cannot be merged, though their covariation must be acknowledged.

**Axis 3 (shared context depth) is a meta gate rather than a tension axis**. This is the point of the framework most deserving of attack. Axes 1/2/4 describe "what the reader must do and how long the document lives" on the same abstraction level; axis 3 describes "whether the reader can decode the visual's semantics". Its mechanism is that with thin context, any visual first pays an explanation tax and may veto visual outright, rather than "visual works better at one end and worse at the other". It is a precondition rather than a judgment dimension parallel to the first three axes.

**2. Deeper dimensions that were ignored**

Sifted out two candidates genuinely independent of the existing four axes:

- **Author proficiency**: in AI writing scenarios proficiency is a constant (low), so it is not a decision variable
- **Reader count (1 vs 100)**: in practice absorbed by axis 3
- **Reader attention budget (30 seconds vs 30 minutes)**: **this is the genuinely independent new axis, with strong explanatory power**. Under a 30-second budget, even with the judgment left open, the reader can only rely on visual to frame first; under a 30-minute budget, even when the content is structured, the reader is willing to finish the explanation behind a table. The "weekly report vs PRD" comparison in MD actually conflates two things: judgment structure and attention budget. **Counterexample: a 6-screen quarterly doc for the boss** is structured + long budget; the four-axis framework says "use visual", but the boss will read for 30 minutes and visual becomes noise. **The attention budget axis should be added.**
- **Trust level**: absorbable by axis 3

**3. Extreme tests**

- Quarterly doc for the boss → all four axes vote "heavy visual", but the intuition is wrong: the boss reads paragraph by paragraph. The framework fails; **attention budget** is missing
- Team comparison of "should we adopt X" options → axis 1 looks structured but is actually explore-to-understand; axis 4 is commit-to-action. **Axes 1 and 4 conflict directly**, and the framework does not say which one to follow
- Retrospective for yourself 6 months later → all four axes vote "less visual"; the framework works
- Cross-department status update → axes 1/2/4 all vote visual; axis 3 is thin and vetoes the first three votes outright. **Proof that axis 3 is a gate rather than an axis**

**4. The mixed state of axis 1**

MD's own example already exposes the problem: in a weekly report, "which path holds" is structured visual, while "why confidence cannot be used" is open-ended text. **Both coexisting in the same weekly report** is the norm. The unit of judgment should be the "paragraph/block" rather than "the whole document".

**5. Suggested topology**

- Keep two core tension axes: **Axis A, the judgment the reader must make** (former axis 1, block level), and **Axis B, attention budget × lifecycle** (merged)
- Demote former axis 4 to a sub-case of axis A
- Promote axis 3 to the upfront gate and stop listing it as a tension axis
- Add a third axis: **the author's factual credibility**. The root cause of anti-patterns ①②④ is visual making things "look certain" beyond the certainty of the underlying facts

Final: **2 tension axes + 1 upfront gate + 1 uncertainty axis**.

</details>

<details>
<summary>Implementation Surgeon: grinding abstract principles into operational instructions</summary>

**1. Rules that are too abstract**

"Judging which end the reader is on" is intuition for humans and an empty concept for AI. Observable signals are needed:

- Signals the reader will make a commit decision: the document ends with an action item list / a "Recommended Action" section / the title contains "weekly report", "status", or "decision"; the author personally will schedule work based on this document within 24 hours
- Signals the reader will explore: the document answers "why X does not hold", contains "reasoning" / "analysis" / "tradeoff" sections, runs over 2000 characters, and has no actionable checklist at the end
- Signals a short document lifecycle: the filename carries a date / the path sits under `weekly_reports/` `status/` `worklog/`
- Signals thick shared context: a reader set of ≤ 3 people in the same project in the same week

**2. Reconciling conflicts**

MD anti-pattern 4 vs the skill's "every HTML visual needs a Markdown fallback" looks like a conflict on the surface and is none in substance. A fallback carries equivalent information when rendering fails; it does not mean "two copies side by side for all readers". Reconciliation: put the fallback inside `<details>`; the visibility of the two copies must be mutually exclusive and never side by side on the first screen.

**3. Self-check signals for the 8 anti-patterns**

Directly usable: #2 (details holding core material: "with the details content deleted, can the reader still complete the primary judgment?"), #4 (mirroring: "does every card row correspond one-to-one with the table?"), #7 → now #6 (single-color chips: "is this column ≥80% one color?").

Ones needing clearer discrimination signals:

- #1 (Phase/Sprint ordering): "after row keys are replaced with 'what the user sees in the App', does the order change? A change = anti-pattern"
- #3 (chip semantic drift): "is the chip color semantics of earlier sections of this document the same set as the current one?"
- #5 (cross-document copying): "grep the whole repo for this conclusion's text string; does it hit ≥2 places?"
- #6 → now #8 (category-name headings): "delete this heading; can the body's first sentence stand alone as the sub-heading? Yes = category name"
- #8 → now #4 (strikethrough stamps): "does this text contain strikethrough or 'update (date)' stamps?"

**4. Change self-eval to "scan after writing"**

MD's current checklist is all questions, and AI has no answers before writing. Change it to "scans executed after one writing pass":

- Color distribution → "after finishing a full table, count the color enum values in the chip column; if the dominant color is ≥ 80%, delete the column"
- Cross-document copying → "turn this section's core conclusion into a one-line grep; at ≥ 2 hits, change to a link"
- Heading verdicts → "scan all H2/H3 and ask for each: 'delete the heading; can the body's first sentence serve directly as the sub-heading?'"

The key change: **replace questions with the triple "action + threshold + repair path"**.

**5. Change the four axes to "four yes/no questions per section"**

Before writing any visual, these must all be answered:

1. Will the reader perform some action within 24 hours of finishing this section?
2. Will this document be edited next week / cited 6 months from now? (yes = long lifecycle, visual is a tax)
3. Is the document's target reader set ≤ 3 people, all on this project this week? (no = thin context)
4. After scanning, does the reader "make a decision" or "think it through"? (the latter = no visual)

If ≥1 "no / think it through" appears among the four, add no visual to the current section. **A hard gate rather than a suggestion**.

**6. Classification: skill body vs self-eval**

- Into the skill body (before / during writing): the four-axis yes/no gate, HTML fallback visibility mutual exclusion, anti-patterns 1/2/6 (they affect the skeleton; fixing afterwards costs a lot)
- Into self-eval (scan after writing): anti-patterns 3/4/7 (a local scan catches them), anti-patterns 5/8 (grep + regex can find them)

</details>

<details>
<summary>Visual Form Critic: does MD's own form hold up?</summary>

**1. The "real tension axes" 4-row table**

Lower burden than a markdown table? **Not obviously**. The table has 2 fixed-width columns and mostly prose content; in essence it is "bold label + paragraph". Converting it to pure markdown `**X**:Y<br><sub>e.g. ...</sub>` loses nothing. The CSS block is a first-time "axis card" form that costs the reader a beat to learn, only to discover it is just a table. Negative ROI.

Are the hierarchy jumps right? The main heading at 600 weight against gray subtext em at 0.92x is weakly contrasted. Suggested for axis names: 1rem/700 plus circled numbers ① ② ③ ④.

**Change to**: a markdown table with 2 columns, `| Tension axis | visual load reduced / added |`.

**2. The anti-pattern gallery's 8 red-border cards**

**All-red conflicts with #7 itself**: yes, and it is embarrassing. 8 all-red cards = 8 implicit signals of "same danger level", which is exactly #7's "one flat color carrying no information". The semantics of chips/red borders should carry severity and has instead become decorative framing.

**Change to**: introduce two severity tiers. "Fix immediately" (#5/#2/#4) gets red borders; "form problems that do not bleed" (#6/#7/#1) gets orange or gray. With this change, #7 was confirmed by dogfood on the spot.

The small gray `.ap-evi` evidence gets skipped. Cards are scanned, and small gray 0.85rem text at the bottom of a card reads as "decorative metadata". But the evidence is exactly what sets this document apart from empty talk (the ground truth it claims), so it should float up.

**Change to**: move the evidence line from the card bottom to the line under the h4, in single-color monospace.

**Ordering?** The current 1-8 shows no logic. Order by "severity + fix cost": #5 → #4 → #2 → #8 → #3 → #7 → #1 → #6.

**3. The "weapon lineage vs decision mechanism" two-column layout**

Are the two columns two faces of the same trade-off? **Partly**. Both sides are "precision vs internalization cost". Placing them side by side implies "independent dimensions", but the author's own next sentence says "the two legs do not weigh the same; the decision mechanism is the foundation". Since they are unequal, the two-column layout misleads.

Does it still make sense collapsed to one column on mobile? No.

**Change to**: delete the two columns and write two ordinary paragraphs, with the hierarchy stated explicitly in the labels.

**4. The overall narrative**

The current 6 ## sections: real question → four axes → anti-patterns → the two legs → checklist → discussion items.

**Problem**: the anti-patterns are this draft's unique evidence, and burying them on the third screen is a waste. The frame should grow out of the evidence, rather than being set up first with evidence found afterwards.

**Change to**: move the anti-patterns up to the second section (right after "the real question") and open with the real evidence; the frame becomes "judging from these 8, the real opposition is these two axes + two gates".

**5. The absence of `<details>`**

It should be dogfooded, and not using one now is a real tell: the document explicitly lists details as a key tool and never uses one itself. Legitimate things to fold: the raw output of the three sub-agent debates (an audit trail, not required reading). These are textbook "audit material" use cases and nicely demonstrate the positive side of #2.

**Change to**: add `## Appendix` at the end with three details blocks folding the sub-agent output.

---

**One-sentence summary**: the draft is real at the argument layer and self-contradicts at the form layer in 3 places: the all-red anti-pattern cards collide with #7, the two-column two-legs layout collides with its own "unequal weight" statement, and the missing details throughout collides with its own toolkit claim. Fix these 3 spots and float the anti-patterns up as the opening, and the document can genuinely carry the weight of the principles it preaches.

</details>
