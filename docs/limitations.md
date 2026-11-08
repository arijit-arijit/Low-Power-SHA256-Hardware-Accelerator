# Limitations
* Block-level core only: no padding, no multi-block control, no IV generation.
* "Low power" is not demonstrated against a baseline; only one design's power was measured.
* Power is simulation-based, zero-delay, single corner, one data pattern.
* Z_13p50 margin is +0.027 ns; the layout fails at its 13.2 ns implementation clock.
* Large 900x900 µm die at 17.3% utilization; post-route area is about 1.9x synthesis area; roughly 19% of it is antenna diodes (10,255 cells inserted to reach zero antenna violations), the rest is only partly itemised.
* Golden vectors for the gate-level test came from this project's RTL (independently cross-checked once).
* Unverified: "7169" figure, E2 pre-route STA, original −0.27 ns log, S2-vs-E2 evidence, Verilator lint output.
* No formal verification or coverage closure.
