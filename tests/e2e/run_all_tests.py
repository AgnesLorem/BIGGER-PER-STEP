#!/usr/bin/env python3
"""
run_all_tests.py
Automated E2E Test Suite Orchestrator for BIGGER RebirthMenu.
Executes Tier 1-4 tests inside Roblox Studio via MCP.
"""

import sys
import os
import json
import time
import argparse

sys.path.insert(0, os.path.dirname(__file__))
from studio_helper import StudioClient

def run_tests(target_datamodel=None, play_solo=False):
    print("=" * 80)
    print("  BIGGER REBIRTHMENU E2E TEST SUITE RUNNER")
    print("=" * 80)
    
    client = StudioClient()
    print("[1/5] Connecting to Roblox Studio...")
    state_res = client.get_studio_state()
    state_text = state_res.get("result", {}).get("content", [{}])[0].get("text", "")
    print(f"      Studio State:\n{state_text}")
    
    is_play_mode = "Current Studio Mode: Play" in state_text
    
    if play_solo and not is_play_mode:
        print("[*] Starting Play Solo session for live runtime verification...")
        client.start_stop_play(True)
        time.sleep(5)
        state_res = client.get_studio_state()
        state_text = state_res.get("result", {}).get("content", [{}])[0].get("text", "")
        is_play_mode = True

    # Determine datamodel to run against
    if target_datamodel:
        datamodel = target_datamodel
    elif is_play_mode:
        datamodel = "Client"  # Default in play mode
    else:
        datamodel = "Edit"

    print(f"[*] Target DataModel: {datamodel}")

    # Read test source files
    e2e_dir = r"f:\BIGGER\tests\e2e"
    with open(os.path.join(e2e_dir, "test_framework.luau"), "r", encoding="utf-8") as f:
        framework_src = f.read()
    with open(os.path.join(e2e_dir, "tier1_feature_coverage.luau"), "r", encoding="utf-8") as f:
        tier1_src = f.read()
    with open(os.path.join(e2e_dir, "tier2_boundary_corner.luau"), "r", encoding="utf-8") as f:
        tier2_src = f.read()
    with open(os.path.join(e2e_dir, "tier3_cross_feature.luau"), "r", encoding="utf-8") as f:
        tier3_src = f.read()
    with open(os.path.join(e2e_dir, "tier4_real_world_scenarios.luau"), "r", encoding="utf-8") as f:
        tier4_src = f.read()

    print("[2/5] Preparing test bundle...")
    runner_script = f"""
        local HttpService = game:GetService("HttpService")
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        
        -- [Framework]
        local FrameworkModule = (function()
            {framework_src}
        end)()
        
        -- [Tier 1]
        local Tier1Module = (function()
            {tier1_src}
        end)()
        
        -- [Tier 2]
        local Tier2Module = (function()
            {tier2_src}
        end)()
        
        -- [Tier 3]
        local Tier3Module = (function()
            {tier3_src}
        end)()
        
        -- [Tier 4]
        local Tier4Module = (function()
            {tier4_src}
        end)()
        
        -- Execute
        FrameworkModule.ClearTests()
        local player = Players:GetPlayers()[1] or Players.LocalPlayer
        local context = {{
            Player = player,
            Datamodel = "{datamodel}",
        }}
        
        Tier1Module.Register(FrameworkModule, context)
        Tier2Module.Register(FrameworkModule, context)
        Tier3Module.Register(FrameworkModule, context)
        Tier4Module.Register(FrameworkModule, context)
        
        local report = FrameworkModule.RunAll()
        return HttpService:JSONEncode(report)
    """

    print(f"[3/5] Executing E2E Test Suite in Studio [{datamodel}] DataModel...")
    exec_res = client.execute_luau(runner_script, datamodel)
    
    if "result" not in exec_res or "content" not in exec_res["result"]:
        print("ERROR executing test bundle:", exec_res)
        client.close()
        return False

    raw_output = exec_res["result"]["content"][0]["text"]
    try:
        report = json.loads(raw_output)
    except Exception as e:
        print("ERROR parsing test output JSON:", e)
        print("Raw Output:", raw_output)
        client.close()
        return False

    print("[4/5] Processing Test Results...")
    print("-" * 80)
    
    total = report.get("Total", 0)
    passed = report.get("Passed", 0)
    failed = report.get("Failed", 0)
    duration = report.get("DurationMs", 0)
    
    tier_summary = report.get("TierSummary", {})
    for tier_name, counts in sorted(tier_summary.items()):
        t_total = counts.get("Total", 0)
        t_passed = counts.get("Passed", 0)
        t_failed = counts.get("Failed", 0)
        status = "PASSED" if t_failed == 0 else "FAILED"
        print(f"  [{status:6s}] {tier_name:<10s}: {t_passed}/{t_total} passed ({t_failed} failed)")

    print("-" * 80)
    print("Detailed Test Cases:")
    for res in report.get("Results", []):
        t_name = res.get("Name")
        t_tier = res.get("Tier")
        t_passed = res.get("Passed")
        t_dur = res.get("DurationMs")
        t_err = res.get("Error")
        status_sym = "[PASS]" if t_passed else "[FAIL]"
        feat_tag = f"[{res.get('Feature')}]" if res.get('Feature') else ""
        print(f"  {status_sym} {t_tier:<6s} {feat_tag:<10s} {t_name} ({t_dur}ms)")
        if not t_passed and t_err:
            print(f"         Error: {t_err}")

    print("=" * 80)
    print(f"  OVERALL RESULT: {passed}/{total} PASSED ({failed} FAILED) in {duration}ms")
    print("=" * 80)

    # Save detailed JSON report
    report_path = os.path.join(e2e_dir, "latest_e2e_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(f"[*] Report saved to {report_path}")
    
    if play_solo:
        print("[*] Stopping Play Solo session...")
        client.start_stop_play(False)
        time.sleep(2)

    client.close()
    return failed == 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run BIGGER RebirthMenu E2E tests.")
    parser.add_argument("--datamodel", choices=["Edit", "Client", "Server"], default=None, help="Target datamodel")
    parser.add_argument("--play-solo", action="store_true", help="Start Play Solo mode if not running")
    parser.add_argument("--sync", action="store_true", help="Sync disk scripts to Studio before running tests")
    args = parser.parse_args()
    
    if args.sync:
        print("[*] Running script synchronization to Studio...")
        import subprocess as sp
        sp.run([sys.executable, "scratch/sync_all_to_studio.py"], check=True)

    success = run_tests(target_datamodel=args.datamodel, play_solo=args.play_solo)
    sys.exit(0 if success else 1)
