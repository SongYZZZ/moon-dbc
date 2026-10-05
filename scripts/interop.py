"""Test oracle only. Never imported by MoonDBC at runtime."""
import argparse
import json
import math
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".oracle"))
import cantools


def run(binary, args):
    p = subprocess.run([str(binary), *args], cwd=ROOT, capture_output=True,
                       text=True, encoding="utf-8", timeout=30)
    assert p.returncode == 0, (args, p.stderr, p.stdout)
    return p.stdout.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", default="dist/moon-dbc.exe")
    parser.add_argument("--output", default=".verification/interop.json")
    args = parser.parse_args()
    binary = (ROOT / args.binary).resolve()
    vectors = [
        ("basic", "E02E030000000000"), ("basic", "0000000000000000"),
        ("basic", "FFFF070000000000"), ("motorola", "0540FFF000000000"),
        ("motorola", "0000800000000000"), ("motorola", "07C07FF000000000"),
        ("multiplex", "0000000B"), ("multiplex", "00FFFF0B"),
        ("multiplex", "0134120B"), ("multiplex", "0234120B"),
        ("canfd", "FF" * 64),
        ("canfd", "0000000000000080" + "00" * 55 + "A5"),
    ]
    rows = []
    for name, payload in vectors:
        path = f"tests/fixtures/{name}.dbc"
        db = cantools.database.load_file(str(ROOT/path), encoding="utf-8")
        m = db.messages[0]
        dbc_id = m.frame_id | (0x80000000 if m.is_extended_frame else 0)
        expected = m.decode(bytes.fromhex(payload), decode_choices=False, scaling=False)
        physical = m.decode(bytes.fromhex(payload), decode_choices=False, scaling=True)
        moon = json.loads(run(binary, ["decode", path, str(dbc_id), payload, "--json"]))
        actual = {s["name"]: s for s in moon["signals"]}
        assert set(actual) == set(expected)
        for key, raw in expected.items():
            assert int(actual[key]["raw"]) == raw, (name, key, actual, expected)
            assert math.isclose(actual[key]["physical"], physical[key], rel_tol=1e-12, abs_tol=1e-9)
        # MoonDBC's explicit raw mode bypasses physical min/max; retain out-of-range
        # decode vectors and use the equivalent oracle encoding policy.
        encoded = m.encode(expected, scaling=False, strict=False).hex().upper()
        result = run(binary, ["encode", path, str(dbc_id), "--raw", *[f"{k}={v}" for k,v in expected.items()]])
        assert result == encoded, (name, result, encoded)
        rows.append({"fixture": path, "input": payload, "dbc_id": dbc_id,
                     "moon": moon, "oracle_raw": expected, "oracle_physical": physical,
                     "moon_encoded": result, "oracle_encoded": encoded, "match": True})
    m = cantools.database.load_file(str(ROOT/"tests/fixtures/motorola.dbc")).messages[0]
    for unsigned in [0, 1, 15, 16, 31]:
        for signed in [-2048, -1, 0, 1, 2047]:
            raw = {"Unaligned": unsigned, "Signed12": signed}
            payload = m.encode(raw, scaling=False).hex().upper()
            moon = json.loads(run(binary, ["decode", "tests/fixtures/motorola.dbc", "292", payload, "--json"]))
            assert {s["name"]: int(s["raw"]) for s in moon["signals"]} == raw
            result = run(binary, ["encode", "tests/fixtures/motorola.dbc", "292", "--raw", f"Unaligned={unsigned}", f"Signed12={signed}"])
            assert result == payload
            rows.append({"fixture":"tests/fixtures/motorola.dbc", "input":payload,
                         "oracle_raw":raw, "moon":moon, "moon_encoded":result,
                         "oracle_encoded":payload, "match":True})
    report = {"date":"2026-10-05", "oracle":"cantools", "version":cantools.__version__,
              "cases":len(rows), "passed":len(rows), "rows":rows}
    output = ROOT/args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"cantools {cantools.__version__}: {len(rows)}/{len(rows)} interoperability vectors passed")


if __name__ == "__main__":
    main()
