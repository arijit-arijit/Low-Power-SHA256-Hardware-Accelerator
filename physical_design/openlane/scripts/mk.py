import json, sys
name, base, upd = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
c = json.load(open(base)); c.update(upd)
json.dump(c, open(f"config_{name}.json", "w"), indent=2)
