# RTL design
| File | Role |
|---|---|
| `sha256_core.sv` | top: ports, working registers, digest accumulate |
| `sha256_ctrl.sv` | FSM, round counter, busy/done |
| `sha256_round.sv` | one round: Ch, Maj, Σ0, Σ1, CSA tree, prefix adders for `a_next`/`e_next` |
| `sha256_msg_sched.sv` | 16-word window, `w_next = σ1(W[t+14]) + W[t+9] + σ0(W[t+1]) + W[t]` |
| `sha256_k_rom.sv` | 64 round constants |
| `prefix_add32.sv` | 32-bit Sklansky parallel-prefix adder |

Port list of `sha256_core`: `clk, rst_n, start, block[511:0], h_in[255:0], busy, done, digest[255:0]`.

Known cosmetic issues: `sha256_round.sv` header comment says CSA only (it also contains prefix adders) and some lines are unindented. Not changed, because the RTL is the version that was synthesized and laid out.
