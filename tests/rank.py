#!/usr/bin/env python3
"""Rank glider-soccer AI variants from a tournament results CSV.

Reads tests/results.csv, aggregates per-variant stats over all matches
(played in either color, normalized so blue/orange are symmetric), and
emits a ranked leaderboard to stdout and tests/REPORT.md.
"""
import csv
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(HERE, "results.csv")
REPORT_PATH = os.path.join(HERE, "REPORT.md")


class Variant:
    def __init__(self, name):
        self.name = name
        self.matches = 0
        self.w = self.d = self.l = 0
        self.goals_for = 0
        self.goals_against = 0
        self.territory = 0.0
        self.third_for = 0
        self.press_for = 0
        self.diffs = []  # per-match goal_for - goal_against, for SE

    def add(self, gf, ga, terr, third, press):
        self.matches += 1
        self.goals_for += gf
        self.goals_against += ga
        self.territory += terr
        self.third_for += third
        self.press_for += press
        self.diffs.append(gf - ga)
        if gf > ga:
            self.w += 1
        elif gf < ga:
            self.l += 1
        else:
            self.d += 1

    @property
    def goal_diff(self):
        return self.goals_for - self.goals_against

    @property
    def avg_diff(self):
        return (sum(self.diffs) / len(self.diffs)) if self.diffs else 0.0

    @property
    def se_diff(self):
        n = len(self.diffs)
        if n < 2:
            return 0.0
        m = self.avg_diff
        var = sum((x - m) ** 2 for x in self.diffs) / (n - 1)
        return math.sqrt(var / n)

    @property
    def avg_territory(self):
        return (self.territory / self.matches) if self.matches else 0.0


def load(path):
    variants = {}

    def get(name):
        if name not in variants:
            variants[name] = Variant(name)
        return variants[name]

    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            bv = row["blue_variant"]
            ov = row["orange_variant"]
            bg = int(row["blue_goals"])
            og = int(row["orange_goals"])
            sum_z = float(row["sum_z"])
            bt = int(row["blue_third"])
            ot = int(row["orange_third"])
            bp = int(row["blue_press"])
            op = int(row["orange_press"])
            # Blue attacks +Z; positive sum_z favors blue's attacking side.
            get(bv).add(bg, og, sum_z, bt, bp)
            get(ov).add(og, bg, -sum_z, ot, op)
    return variants


def rank(variants):
    return sorted(
        variants.values(),
        key=lambda v: (v.goal_diff, v.avg_territory),
        reverse=True,
    )


def build_report(ranked, variants):
    lines = []
    lines.append("# Tournament Leaderboard")
    lines.append("")
    lines.append(
        "| Rank | Variant | MP | W-D-L | GF | GA | GD | "
        "AvgGD (±SE) | AvgTerr | Third | Press |"
    )
    lines.append(
        "|-----:|---------|---:|:-----:|---:|---:|---:|"
        ":-----------:|--------:|------:|------:|"
    )
    for i, v in enumerate(ranked, 1):
        lines.append(
            "| {r} | {name} | {mp} | {w}-{d}-{l} | {gf} | {ga} | {gd:+d} | "
            "{avg:+.2f} ±{se:.2f} | {terr:+.1f} | {third} | {press} |".format(
                r=i, name=v.name, mp=v.matches, w=v.w, d=v.d, l=v.l,
                gf=v.goals_for, ga=v.goals_against, gd=v.goal_diff,
                avg=v.avg_diff, se=v.se_diff, terr=v.avg_territory,
                third=v.third_for, press=v.press_for,
            )
        )
    lines.append("")
    best = ranked[0]
    lines.append("BEST: {}".format(best.name))
    lines.append("")
    lines.append(interpret(ranked, variants))
    return "\n".join(lines) + "\n"


def interpret(ranked, variants):
    best = ranked[0]
    base = variants.get("base")
    parts = []
    parts.append(
        "**{best}** tops the table with a goal differential of {gd:+d} "
        "(avg {avg:+.2f} ±{se:.2f} per match) and {terr} territorial "
        "control.".format(
            best=best.name, gd=best.goal_diff, avg=best.avg_diff,
            se=best.se_diff,
            terr=("positive" if best.avg_territory >= 0 else "negative"),
        )
    )
    if base is not None and best.name != "base":
        gap = best.avg_diff - base.avg_diff
        # Combined SE of the difference of two means.
        comb_se = math.hypot(best.se_diff, base.se_diff)
        sig = abs(gap) > comb_se and comb_se > 0
        parts.append(
            "Its avg goal_diff edge over `base` is {gap:+.2f} per match "
            "(combined SE {cse:.2f}), which {verdict} ~1 standard error, so "
            "the lead {claim}.".format(
                gap=gap, cse=comb_se,
                verdict=("exceeds" if sig else "does not exceed"),
                claim=("looks statistically meaningful"
                       if sig else "may be within noise"),
            )
        )
    elif best.name == "base":
        parts.append("`base` itself is the strongest variant here.")
    parts.append(
        "Ranking is by total goal differential, with average territory as "
        "the tie-breaker."
    )
    return " ".join(parts)


def main():
    if not os.path.exists(CSV_PATH):
        sys.stderr.write("error: {} not found\n".format(CSV_PATH))
        return 1
    variants = load(CSV_PATH)
    if not variants:
        sys.stderr.write("error: no rows in results.csv\n")
        return 1
    ranked = rank(variants)
    report = build_report(ranked, variants)
    sys.stdout.write(report)
    with open(REPORT_PATH, "w") as f:
        f.write(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
