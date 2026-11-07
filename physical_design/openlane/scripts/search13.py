import glob, json, os, re, shutil, subprocess, time
os.chdir(os.path.expanduser("~/pd/wt_e2/pd/openlane"))
OL = "/nix/store/9hhfv2x4r4x6v55799pa58jc2yni6awy-python3.11-openlane-2.3.10/bin/openlane"
LOG = "batch_logs/search13.log"; AREA_MAX = 150000
g = lambda m, k: m.get(k, 0) or 0
def log(s): open(LOG, "a").write(time.strftime("%H:%M:%S ") + s + "\n")
def busy():
    for pat in ("[o]penlane-wrapped", "campaign([5-9]|1[01])[.]sh", "[s]earch12[.]py"):
        if subprocess.run(["pgrep", "-f", pat], capture_output=True, text=True).stdout.strip(): return True
    return False
def load(n):
    p = f"runs/{n}/final/metrics.json"
    return json.load(open(p)) if os.path.exists(p) else None
def why(m):
    b = []
    if g(m, "timing__setup__ws") < 0: b.append("setup %.3f" % g(m, "timing__setup__ws"))
    if g(m, "timing__hold__ws") < 0.02: b.append("hold %.3f" % g(m, "timing__hold__ws"))
    for k, n in (("magic__drc_error__count", "magic DRC"), ("klayout__drc_error__count", "klayout DRC"), ("design__lvs_error__count", "LVS"), ("design__max_slew_violation__count", "slew"), ("design__max_cap_violation__count", "cap")):
        if g(m, k): b.append(f"{n} {g(m, k)}")
    if g(m, "design__instance__area__stdcell") > AREA_MAX: b.append("area")
    return b
timing_ok = lambda m: not why(m)
success = lambda m: timing_ok(m) and g(m, "antenna__violating__nets") == 0
def sdc(T):
    tag = f"{T:.2f}".replace(".", "p"); p = f"{os.getcwd()}/sha256_core_S{tag}ns.sdc"
    open(p, "w").write(open("sha256_core_13p2ns.sdc").read().replace("-period 13.200", f"-period {T:.3f}"))
    return p
def run(n, upd, base="config_U1.json"):
    c = json.load(open(base)); c.update(upd); json.dump(c, open(f"config_{n}.json", "w"), indent=2)
    if load(n) is None:
        while busy(): time.sleep(30)
        if shutil.disk_usage("/mnt/c").free < 8e9: log("C: under 8 GB - stopping"); return None
        shutil.rmtree(f"runs/{n}", ignore_errors=True); log(f"START {n}")
        with open(f"batch_logs/{n}.txt", "w") as f:
            subprocess.run([OL, "--run-tag", n, f"config_{n}.json"], stdout=f, stderr=subprocess.STDOUT)
    m = load(n)
    if m is None: log(f"NO METRICS {n}"); return None
    log(f"DONE {n} setup={g(m,'timing__setup__ws'):.3f} hold={g(m,'timing__hold__ws'):.3f} ant={g(m,'antenna__violating__nets')} slew={g(m,'design__max_slew_violation__count')} cap={g(m,'design__max_cap_violation__count')} area={g(m,'design__instance__area__stdcell'):.0f} {'SUCCESS' if success(m) else ''}")
    return m
log("search13 start")
z1 = run("Z_13p60", {"SIGNOFF_SDC_FILE": sdc(13.6)})
if z1 is not None and success(z1):
    log("Z_13p60 reproduced the zero-antenna layout with timing met; trying signoff 13.5 and 13.7")
    run("Z_13p50", {"SIGNOFF_SDC_FILE": sdc(13.5)}); run("Z_13p70", {"SIGNOFF_SDC_FILE": sdc(13.7)})
else:
    log("Z_13p60 did not succeed; testing routing without metal 1")
    run("M_met2_U1", {"RT_MIN_LAYER": "met2", "SIGNOFF_SDC_FILE": sdc(13.6)})
    run("M_met2_W", {"RT_MIN_LAYER": "met2"}, base="config_W_13p6_T60.json")
def sp(nm):
    c = json.load(open(f"config_{nm}.json")); f = (c.get("SIGNOFF_SDC_FILE") or c.get("PNR_SDC_FILE") or "").replace("dir::", "")
    if f and not os.path.isabs(f): f = os.path.join(os.getcwd(), f)
    try: return float(re.search(r"-period\s+([0-9.]+)", open(f).read()).group(1))
    except Exception: return float(c["CLOCK_PERIOD"])
def pins(nm):
    f = sorted(glob.glob(f"runs/{nm}/*checkantennas-1/reports/antenna_summary.rpt"))
    if not f: return "n/a"
    out = []
    for l in open(f[-1]):
        if "│" in l:
            c = [x.strip() for x in l.split("│")]; out.append(f"{c[5]}({c[1]})")
    return " ".join(out) if out else "none"
fixed = ["U1", "W_13p6_T60", "W_13p8_T60", "W_14p0_T60", "R3", "F3_13p2", "H1"]
names = fixed + sorted(os.path.basename(d) for p in ("Y_*", "Z_*", "M_*") for d in glob.glob("runs/" + p))
rows = []
for nm in names:
    m = load(nm)
    if m is not None and os.path.exists(f"config_{nm}.json"): rows.append((nm, sp(nm), json.load(open(f"config_{nm}.json"))["CLOCK_PERIOD"], m))
rows.sort(key=lambda r: (not timing_ok(r[3]), g(r[3], "antenna__violating__nets"), g(r[3], "design__instance__area__stdcell") * r[1]))
out = ["=====BEGIN====="] + [l.rstrip() for l in open(LOG)]
out.append("--- ranked: valid first, then antenna nets, then area x signoff period")
out.append(f"{'run':14}{'impl':>6}{'sign':>6}{'setup':>8}{'hold':>7}{'area':>8}{'slew':>5}{'cap':>4}{'ant':>4}  status")
for nm, per, impl, m in rows:
    w = why(m)
    out.append(f"{nm:14}{impl:>6}{per:>6}{g(m,'timing__setup__ws'):>8.3f}{g(m,'timing__hold__ws'):>7.3f}{g(m,'design__instance__area__stdcell'):>8.0f}{g(m,'design__max_slew_violation__count'):>5}{g(m,'design__max_cap_violation__count'):>4}{g(m,'antenna__violating__nets'):>4}  " + ("SUCCESS (antenna 0)" if success(m) else ("valid" if not w else "fails: " + ", ".join(w))))
out.append("--- violating pins per new run (pin(ratio))")
for nm, per, impl, m in rows:
    if nm[:2] in ("Z_", "M_", "Y_"): out.append(f"{nm}: {pins(nm)}")
W, WS, WI, WM = rows[0] if rows else ("W_13p6_T60", 13.6, 13.6, {})
out.append(f"RESULT: {'ZERO-ANTENNA VALID RUN FOUND: ' + W if success(WM) else 'NOT FOUND; best valid run is ' + W}")
out.append(f"--- winner {W}: implementation target {WI} ns, signoff clock {WS} ns, throughput {512000/(67*WS):.0f} Mbit/s")
for k in ("timing__setup__ws", "timing__hold__ws", "design__max_slew_violation__count", "design__max_cap_violation__count", "antenna__violating__nets", "design__instance__area__stdcell", "magic__drc_error__count", "klayout__drc_error__count", "design__lvs_error__count"):
    out.append(f"  {k}: {WM.get(k)}")
rj = json.load(open(f"runs/{W}/resolved.json"))
out.append("  resolved: " + ", ".join(f"{k}={rj.get(k)}" for k in ("CLOCK_PERIOD", "PNR_SDC_FILE", "SIGNOFF_SDC_FILE", "RT_MIN_LAYER", "HEURISTIC_ANTENNA_THRESHOLD")))
for f in glob.glob(f"runs/{W}/final/sdc/*.sdc"): out.append(f"  final sdc {os.path.basename(f)}: " + " | ".join(l.strip() for l in open(f) if "create_clock" in l))
net = open(f"runs/{W}/final/nl/sha256_core.nl.v").read()
lib = open(glob.glob(os.path.expanduser("~/.volare/volare/sky130/versions/*/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"))[0]).read()
ar = lambda c: (re.search(r'cell \("sky130_fd_sc_hd__' + c + r'"\)\s*\{.*?area\s*:\s*([0-9.]+)', lib, re.S) or [0, "?"])[1]
out.append(f"--- cells: heuristic diodes={net.count(' ANTENNA__')} total diode_2={net.count('diode_2')} (area each {ar('diode_2')} um2) hold cells={net.count('dlygate4sd3_1')} (area each {ar('dlygate4sd3_1')} um2)")
pdk = glob.glob(os.path.expanduser("~/.volare/volare/sky130/versions/*/sky130A/libs.ref/sky130_fd_sc_hd"))[0]
spef = glob.glob(f"runs/{W}/final/spef/max*/*.spef") or glob.glob(f"runs/{W}/final/spef/*max*/*.spef")
if spef:
    open("/tmp/chk13.tcl", "w").write(f"read_liberty {pdk}/lib/sky130_fd_sc_hd__ss_100C_1v60.lib\nread_verilog {os.getcwd()}/runs/{W}/final/nl/sha256_core.nl.v\nlink_design sha256_core\nread_sdc {os.getcwd()}/runs/{W}/final/sdc/sha256_core.sdc\nread_spef {os.getcwd()}/{spef[0]}\nreport_check_types -max_slew -max_capacitance -violators\nreport_worst_slack -max\n")
    r = subprocess.run(["/home/arijit/OpenSTA/build/sta", "-no_splash", "-exit", "/tmp/chk13.tcl"], capture_output=True, text=True)
    out.append("--- independent OpenSTA check at max_ss")
    out += [l for l in (r.stdout + r.stderr).splitlines() if l.strip() and "Warning 198" not in l][:8]
out.append("--- sustained power and gate-level check (top valid runs, at their signoff clock)")
for nm, per, impl, m in [r for r in rows if timing_ok(r[3])][:3]:
    r = subprocess.run([os.path.expanduser("~/pd/wt_e2/power2.sh"), f"runs/{nm}", nm, str(per)], capture_output=True, text=True)
    out += [l for l in r.stdout.splitlines() if "TB_RESULT" in l or "SUSTAINED" in l]
for nm, per, impl, m in rows:
    if nm[:2] in ("Z_", "M_"):
        d = os.path.expanduser(f"~/pd/evidence/search13/{nm}"); os.makedirs(d, exist_ok=True)
        shutil.copy(f"runs/{nm}/final/metrics.json", d); shutil.copy(f"config_{nm}.json", d)
out.append("--- space: " + subprocess.run("df -h /mnt/c | tail -n 1", shell=True, capture_output=True, text=True).stdout.strip())
out.append("=====END=====")
open("batch_logs/search13_report.txt", "w").write("\n".join(out) + "\n"); log("SEARCH13 ALL DONE")
# END_OF_SCRIPT
