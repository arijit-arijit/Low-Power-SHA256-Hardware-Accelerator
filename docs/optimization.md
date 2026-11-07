# Optimization
| Step | Change | ABC delay (ps) | Area (µm²) |
|---|---|---|---|
| A -> B | CSA | 11,884 -> 10,058 | 67,457 -> 71,316 |
| B -> C | prefix adder in digest accumulate | 10,058 -> 9,091 | 71,316 -> 71,343 |
| C -> E2 | prefix adders in round | 9,091 -> 9,972 | 71,343 -> 71,715 |

A -> C: −23.50% ABC delay, +5.76% area (matches the earlier claim).

**Honest finding:** by the ABC estimate E2 is *slower* than C. E2 was kept as the final RTL, but the comparison showing a post-route benefit of E2 over C (S2 vs E2 campaign) was **not located in the recovered reports** -> UNVERIFIED. No A/B power comparison exists. The `campaign_history` table recovered shows an earlier, different-area campaign (~116k µm²) and is not used for Z-run claims.
