#!/usr/bin/env python3
"""Print Markdown tables from results/*.jsonl and each run's render path from its .log."""
import json
import pathlib
import re
import sys

results = pathlib.Path(__file__).parent / "results"
labels = sys.argv[1:] or sorted(p.stem for p in results.glob("*.jsonl"))


def render_path(label):
    log = results / f"{label}.log"
    if not log.exists():
        return "?"
    text = log.read_text(errors="replace")
    if "VideoOutput: S/W rendering." in text:
        return "S/W"
    if re.search(r"VideoOutput: H/W rendering", text):
        same = re.search(r"SPIKE PATCH raster EGLDisplay .*\((same|DIFFERENT)\)", text)
        return "H/W" + (f" (display {same.group(1)})" if same else "")
    return "?"


print("| Run | Render | mpv | Zap p50/p95 plain (ms) | Zap p50/p95 2 s burst (ms) | Zap failures |")
print("|---|---|---|---|---|---|")
per_sample = {}
for label in labels:
    zap, mpv = {}, "?"
    for line in (results / f"{label}.jsonl").read_text().splitlines():
        r = json.loads(line)
        if r["type"] == "start":
            mpv = r["versions"]["mpv-version"].replace("mpv ", "")
        elif r["type"] == "zap_result":
            zap[r["burst_s"]] = r
        elif r["type"] == "sample_result":
            per_sample.setdefault(r["sample"], {})[label] = r
    fmt = lambda z: f"{z['p50_ms']} / {z['p95_ms']}" if z else "—"
    fails = sum(z["failures"] for z in zap.values()) if zap else "—"
    print(f"| {label} | {render_path(label)} | {mpv} | {fmt(zap.get(0))} | {fmt(zap.get(2))} | {fails} |")

print()
print("Per sample: hwdec-current · first frame ms · CPU % all cores (one core) · VO drops in window")
print()
print("| Sample | " + " | ".join(labels) + " |")
print("|---|" + "---|" * len(labels))
for sample, runs in per_sample.items():
    cells = []
    for label in labels:
        r = runs.get(label)
        if r is None:
            cells.append("—")
        elif not r["ok"]:
            cells.append("**FAIL** " + r.get("reason", ""))
        else:
            hw = ",".join(r["seen"]["hwdec-current"])
            cells.append(f"{hw} · {r['first_frame_ms']} · {r['cpu_total_pct']} ({r['cpu_one_core_pct']}) · {r['vo_drops']}")
    print(f"| {sample} | " + " | ".join(cells) + " |")
