# Filtering by multiple groups

Click **Group filter** above the contact list. Each group has an **Ignore**,
**Include**, or **Exclude** setting. Search within the panel to find groups by
name or account; your selections remain active when that panel search changes.
Results, the count and the rule summary update immediately. **Done** closes the
panel; it does not save or change any contact's memberships.

| Find cards tagged with… | Match | Include | Exclude | No other groups |
| --- | --- | --- | --- | --- |
| A AND B | All (AND) | A, B | — | Off |
| A AND B but NOT C | All (AND) | A, B | C | Off |
| A OR B | Any (OR) | A, B | — | Off |
| (A OR B) and nothing else | Any (OR) | A, B | — | On |
| Exactly A AND B | All (AND) | A, B | — | On |
| Anything except C | Either | — | C | Off |
| Ungrouped only | Either | — | — | On |

“No other groups” applies to all memberships on that individual account card,
not just the currently visible groups. With Any + A/B, it allows A alone, B alone
or A and B together, but excludes A/C or A/B/C. Excluded groups always reject a
card. Include and Exclude are mutually exclusive for each group in the UI.

Advanced filtering uses **All contacts** within the currently selected account
and main text search. If opened from one sidebar group, that group starts included.
Clicking a sidebar group or Ungrouped, changing accounts, or connecting from demo
to live contacts clears advanced rules. **Clear** resets the query in place.

Same-named groups from different accounts are separate choices; account labels
and summaries distinguish them. A removed/unavailable included group is retained
as an unavailable criterion rather than silently broadening the search; Clear
removes it. Family colors remain visual cues, not additional query rules.

The controls deliberately avoid query-language syntax and operator precedence.
The Match setting applies only to included groups; exclusions and “No other
groups” are additional AND conditions. Nested expressions such as
`(A AND B) OR (C AND D)` are not part of this version.
