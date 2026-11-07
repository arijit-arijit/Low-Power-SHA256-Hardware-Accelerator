import json, os, sys
BASE = "F3_13p2"
g = lambda m, k: m.get(k, 0) or 0
have = lambda r: os.path.exists(f"runs/{r}/final/metrics.json")
load = lambda r: json.load(open(f"runs/{r}/final/metrics.json"))
cfg = lambda r: json.load(open(f"config_{r}.json"))
def ok(m):
    return (g(m,"timing__setup__ws") >= 0 and g(m,"timing__hold__ws") >= 0.02
            and g(m,"magic__drc_error__count") == 0 and g(m,"klayout__drc_error__count") == 0
            and g(m,"design__lvs_error__count") == 0 and g(m,"design__max_slew_violation__count") == 0
            and g(m,"design__max_cap_violation__count") == 0 and g(m,"design__instance__area__stdcell") <= 140000)
cmd = sys.argv[1]
if cmd == "mk":
    name, base, upd = sys.argv[2], sys.argv[3], json.loads(sys.argv[4])
    res = json.load(open(f"runs/{BASE}/resolved.json"))
    bad = [k for k in upd if k not in res]
    if bad:
        print("UNKNOWN KEYS", bad, "-> skipping", name); sys.exit(3)
    c = cfg(base); c.update(upd)
    json.dump(c, open(f"config_{name}.json", "w"), indent=2)
elif cmd == "rank":
    rows = []
    for r in sys.argv[2:]:
        if not have(r): continue
        m = load(r)
        per = cfg(r).get("CLOCK_PERIOD", 99) if os.path.exists(f"config_{r}.json") else 99
        rows.append((not ok(m), g(m,"antenna__violating__nets"), g(m,"design__instance__area__stdcell"), per, r, m))
    rows.sort(key=lambda x: x[:4])
    print(f"{'run':12}{'ok':>3}{'T':>6}{'setup':>8}{'hold':>7}{'area':>8}{'slew':>6}{'cap':>4}{'ant':>5}")
    for x in rows:
        m = x[5]
        print(f"{x[4]:12}{'Y' if not x[0] else 'N':>3}{x[3]:>6}{g(m,'timing__setup__ws'):>8.3f}{g(m,'timing__hold__ws'):>7.3f}{x[2]:>8.0f}{g(m,'design__max_slew_violation__count'):>6}{g(m,'design__max_cap_violation__count'):>4}{x[1]:>5}")
    print("BEST", rows[0][4] if rows else BASE)
elif cmd == "sel":
    ants, holds = sys.argv[2].split(","), sys.argv[3].split(",")
    bm, bc = load(BASE), cfg(BASE)
    diff = lambda r: {k: v for k, v in cfg(r).items() if bc.get(k) != v}
    A = sorted([(g(load(r),"antenna__violating__nets"), r) for r in ants if have(r) and ok(load(r)) and g(load(r),"antenna__violating__nets") < g(bm,"antenna__violating__nets")], reverse=True)
    H = [(g(load(r),"design__instance__area__stdcell"), r) for r in holds if have(r) and ok(load(r)) and g(load(r),"design__instance__area__stdcell") < g(bm,"design__instance__area__stdcell")]
    out = {}
    for a, r in A: out.update(diff(r))
    if H: out.update(diff(min(H)[1]))
    print(json.dumps(out))
elif cmd == "valid":
    sys.exit(0 if have(sys.argv[2]) and ok(load(sys.argv[2])) else 1)
elif cmd == "pareto":
    rows = []
    for r in sys.argv[2:]:
        if not have(r): continue
        m = load(r); per = cfg(r).get("CLOCK_PERIOD", 99); a = g(m, "design__instance__area__stdcell")
        rows.append((not ok(m), a * per, r, m, per, a))
    rows.sort(key=lambda x: x[:2])
    print(f"{'run':12}{'ok':>3}{'T':>6}{'setup':>8}{'hold':>7}{'area':>8}{'A*T/1k':>8}{'Mbit/s':>7}{'ant':>5}")
    for bad, at, r, m, per, a in rows:
        print(f"{r:12}{'N' if bad else 'Y':>3}{per:>6}{g(m,'timing__setup__ws'):>8.3f}{g(m,'timing__hold__ws'):>7.3f}{a:>8.0f}{at/1000:>8.0f}{512000/(67*per):>7.0f}{g(m,'antenna__violating__nets'):>5}")
elif cmd == "nextper":
    r = sys.argv[2]; s = g(load(r), "timing__setup__ws"); t = cfg(r)["CLOCK_PERIOD"]
    print("none" if s < 0.1 else max(11.5, round(t - 0.8 * s, 1)))
