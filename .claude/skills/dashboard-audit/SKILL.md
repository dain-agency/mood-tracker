---
description: Dashboard Audit — checklist for KPI honesty, zero-data safety, Quick Actions wiring, and chart organism enforcement. Auto-invoked by ship-ui-auditor when auditing dashboard/stats/overview pages.
---

# Dashboard Audit

Auto-invoked by `ship-ui-auditor` when the page path or archetype name contains `dashboard`, `stats`, or `overview`. Run this checklist **before** the standard CLEAR pillars.

---

## 1. KPI Label Honesty

Each KPI metric visible on the dashboard must be audited for label ↔ query alignment:

- [ ] **Label describes what the query actually returns** — not what the product manager wishes. "Delivery Rate" must be `sent / total × 100`, not `1.0` when total is 0.
- [ ] **Denominator guard** — any percentage or ratio KPI must handle the zero-denominator case explicitly (show `—` or `N/A`, never `100%` or `Infinity`).
- [ ] **Time window is stated** — "Admissions" is ambiguous; "Admissions (last 30 days)" is not. If the query has a date filter, the label must reflect it.
- [ ] **No optimistic defaults** — KPIs must not initialise to a "good" value (0%, On Target, Green) before data loads. Use `LoadingState` skeleton until the query resolves.

**Evidence required:** for each KPI, name the query/hook it reads from and confirm the label matches the returned field.

---

## 2. Zero-Data Fallback

Dashboards must render sensibly on empty tenants (new accounts, demo environments):

- [ ] **No misleading stats at zero** — "100% delivery rate" with 0 sent, "On target!" with all metrics at zero, "0 incidents this month" presented as positive when the query hasn't run — all are BLOCK.
- [ ] **EmptyState renders when all KPIs are zero** — show a helpful message ("No activity yet — data will appear once you start using Herbert") rather than a grid of zeroes.
- [ ] **Charts handle empty datasets** — no blank axes, no uncaught errors, no `NaN` in tooltips. Chart organisms must receive an explicit `emptyState` prop or equivalent.

---

## 3. Quick Actions Pattern

If a Quick Actions section is present:

- [ ] **Every button has a real `onClick`** — no `() => {}` placeholders. Click each button in the browser and verify a navigation, dialog open, or mutation fires.
- [ ] **Keyboard reachable** — tab through Quick Actions. Every button must receive focus and activate with Enter/Space.
- [ ] **Visible disabled state** — buttons that are not yet wired (pending future work) must be `disabled` with a tooltip explaining why ("Coming soon" or "Requires billing setup"), not silently non-functional.
- [ ] **Button count** — more than 6 Quick Actions creates visual noise. Flag > 6 as WARN; flag > 8 as BLOCK.

---

## 4. Chart Organism Enforcement

- [ ] **No raw `recharts` imports outside `organisms/charts/`** — grep the files built this round:
  ```bash
  grep -rn "from 'recharts'\|from \"recharts\"" --include="*.tsx" --include="*.ts" <files>
  ```
  Any hit outside `apps/web/src/components/organisms/charts/` is a **BLOCK**. Use the chart organisms (`AreaChart`, `BarChart`, `DonutChart`, etc.) instead.
- [ ] **Chart organisms receive typed data** — no `data: any[]` prop. Verify the data prop type matches the organism's exported interface.

---

## 5. Foggy-Glasses Test (Dashboard-Specific)

Squint at the dashboard at 1024px viewport:

- [ ] **KPIs are visually dominant** — they should be the first thing the eye lands on, not competing equally with Quick Actions, charts, and activity feeds.
- [ ] **Quick Actions section is clearly secondary** — smaller cards, lower visual weight than KPIs.
- [ ] **Primary action is identifiable within 2 seconds** — what is the most important thing a user should do from this screen? If it's not obvious, the layout needs hierarchy work.

---

## 6. Responsive Grid Collapse

- [ ] **KPI cards reflow** — 4-up at 1440px → 2-up at 1024px → 1-up at 768px (or 2-up if cards are narrow). Verify at all three viewports.
- [ ] **Charts do not overflow** — chart containers must be `w-full` with a defined `height`. Verify no horizontal overflow at 768px.
- [ ] **Quick Actions grid reflows** — does not force horizontal scroll at any viewport.

---

## 7. State Persistence

- [ ] **Period selector persists** — if the dashboard has a date range / period toggle, the selected value must survive page reload (localStorage key: `herbert:<domain>:dashboard-period`).
- [ ] **View toggle persists** — if the user can switch between chart and table view, that preference must persist.
- [ ] **Column visibility persists** — any summary table on the dashboard must use `PRESET_DASHBOARD_SUMMARY` which handles column visibility via localStorage.

---

## Output

Append a `### Dashboard Audit` section to the standard UI Audit report:

```markdown
### Dashboard Audit
- KPI honesty: PASS / BLOCK (detail)
- Zero-data fallback: PASS / WARN / BLOCK (detail)
- Quick Actions wiring: PASS / BLOCK (detail)
- Chart organism enforcement: PASS / BLOCK (detail)
- Foggy-Glasses (dashboard): PASS / WARN / BLOCK (detail)
- Responsive grid: PASS / WARN / BLOCK (detail)
- State persistence: PASS / WARN / BLOCK (detail)
- Dashboard verdict: PASS / WARN / BLOCK
```

A BLOCK in Dashboard Audit overrides any CLEAR PASS for the page.
