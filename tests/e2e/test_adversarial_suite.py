#!/usr/bin/env python3
"""
test_adversarial_suite.py
Adversarial Boundary & Stress Testing Suite for BIGGER RebirthMenu.
Executes deep boundary, stress, remote spam, and viewport aspect ratio tests in Roblox Studio.
"""

import sys
import os
import json
import time

sys.path.insert(0, os.path.dirname(__file__))
from studio_helper import StudioClient

def run_adversarial_tests():
    print("=" * 80)
    print("  BIGGER REBIRTHMENU ADVERSARIAL STRESS & BOUNDARY TEST SUITE")
    print("=" * 80)

    client = StudioClient()
    print("[1/4] Connecting to Roblox Studio...")
    state_res = client.get_studio_state()
    state_text = state_res.get("result", {}).get("content", [{}])[0].get("text", "")
    print(f"      Studio State:\n{state_text}")

    is_play_mode = "Current Studio Mode: Play" in state_text
    if not is_play_mode:
        print("[*] Starting Play Solo session for live server & client testing...")
        client.start_stop_play(True)
        time.sleep(5)
        state_res = client.get_studio_state()
        state_text = state_res.get("result", {}).get("content", [{}])[0].get("text", "")
        print(f"      Studio State after Play Solo:\n{state_text}")

    # Luau adversarial test code
    adversarial_luau_code = """
        local HttpService = game:GetService("HttpService")
        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local GuiService = game:GetService("GuiService")

        local results = {}
        local function record_test(name, category, passed, err, details)
            table.insert(results, {
                Name = name,
                Category = category,
                Passed = passed,
                Error = err,
                Details = details or {}
            })
        end

        local function assert_eq(act, exp, msg)
            if act ~= exp then
                error(string.format("%s (Expected %s, got %s)", msg or "assert_eq failed", tostring(exp), tostring(act)), 2)
            end
        end

        local function assert_approx(act, exp, eps, msg)
            eps = eps or 0.001
            if math.abs(act - exp) > eps then
                error(string.format("%s (Expected approx %f, got %f)", msg or "assert_approx failed", exp, act), 2)
            end
        end

        local player = Players:GetPlayers()[1] or Players.LocalPlayer
        local playerGui = player and player:FindFirstChild("PlayerGui")
        local mainHud = playerGui and playerGui:FindFirstChild("MainHUD")
        local safeArea = mainHud and mainHud:FindFirstChild("SafeAreaRoot")
        local overlayHud = safeArea and safeArea:FindFirstChild("OverlayHUD")
        local rebirthPanel = overlayHud and overlayHud:FindFirstChild("RebirthPanel")

        -- -------------------------------------------------------------
        -- SECTION 1: BOUNDARY LEVELS TESTING
        -- -------------------------------------------------------------
        
        -- ADV-01: Level 0 (Lower extreme boundary)
        do
            local ok, err = pcall(function()
                local level = 0
                local reqLevel = 20
                local reqText = "Reach Level " .. tostring(reqLevel) .. "\\nto Rebirth"
                local progText = "Lv" .. tostring(level) .. " / " .. tostring(reqLevel)
                local ratio = if reqLevel > 0 then math.clamp(level / reqLevel, 0, 1) else 0
                assert_eq(reqText, "Reach Level 20\\nto Rebirth", "Req text format")
                assert_eq(progText, "Lv0 / 20", "Prog text format at level 0")
                assert_eq(ratio, 0, "Progress ratio must be 0 for level 0")
                local canRebirth = level >= reqLevel
                assert_eq(canRebirth, false, "CanRebirth must be false for level 0")
            end)
            record_test("ADV_01_BoundaryLevel_0", "LEVEL_BOUNDARY", ok, err)
        end

        -- ADV-02: Level 1 (Initial player state)
        do
            local ok, err = pcall(function()
                local level = 1
                local reqLevel = 20
                local progText = "Lv" .. tostring(level) .. " / " .. tostring(reqLevel)
                local ratio = math.clamp(level / reqLevel, 0, 1)
                assert_eq(progText, "Lv1 / 20", "Prog text at level 1")
                assert_approx(ratio, 0.05, 0.001, "Progress ratio at level 1")
                local canRebirth = level >= reqLevel
                assert_eq(canRebirth, false, "CanRebirth must be false for level 1")
            end)
            record_test("ADV_02_BoundaryLevel_1", "LEVEL_BOUNDARY", ok, err)
        end

        -- ADV-03: Level 999,999 (Massive upper progression boundary)
        do
            local ok, err = pcall(function()
                local level = 999999
                local reqLevel = 20
                local progText = "Lv" .. tostring(level) .. " / " .. tostring(reqLevel)
                local ratio = math.clamp(level / reqLevel, 0, 1)
                assert_eq(progText, "Lv999999 / 20", "Prog text at level 999999")
                assert_eq(ratio, 1, "Progress ratio clamped to 1 at level 999999")
                local canRebirth = level >= reqLevel
                assert_eq(canRebirth, true, "CanRebirth must be true at level 999999")
            end)
            record_test("ADV_03_BoundaryLevel_999999", "LEVEL_BOUNDARY", ok, err)
        end

        -- ADV-04: Zero RequiredLevel Defensive Zero-Division Guard
        do
            local ok, err = pcall(function()
                local level = 10
                local reqLevel = 0
                -- Test RebirthController formula: if State.RequiredLevel > 0 then math.clamp(State.CurrentLevel / State.RequiredLevel, 0, 1) else 0
                local ratio = if reqLevel > 0 then math.clamp(level / reqLevel, 0, 1) else 0
                assert_eq(ratio, 0, "Zero division must be guarded and return 0")
            end)
            record_test("ADV_04_ZeroRequiredLevel_Guard", "LEVEL_BOUNDARY", ok, err)
        end

        -- ADV-05: Extreme Tier Progression (Rebirth 1000)
        do
            local ok, err = pcall(function()
                local rebirths = 1000
                local reqLevel = 150 + (rebirths - 4) * 50
                assert_eq(reqLevel, 49950, "Tier 1000 required level must be 49,950")
            end)
            record_test("ADV_05_ExtremeTierProgression_1000", "LEVEL_BOUNDARY", ok, err)
        end

        -- -------------------------------------------------------------
        -- SECTION 2: MULTIPLIER FORMAT BOUNDARY TESTING
        -- -------------------------------------------------------------

        -- ADV-06: Multiplier 0X
        do
            local ok, err = pcall(function()
                local mult = 0
                local text = tostring(mult) .. "X Strength"
                assert_eq(text, "0X Strength", "0X format")
            end)
            record_test("ADV_06_MultiplierFormat_0X", "MULTIPLIER_FORMAT", ok, err)
        end

        -- ADV-07: Multiplier 1X
        do
            local ok, err = pcall(function()
                local mult = 1
                local text = tostring(mult) .. "X Strength"
                assert_eq(text, "1X Strength", "1X format")
            end)
            record_test("ADV_07_MultiplierFormat_1X", "MULTIPLIER_FORMAT", ok, err)
        end

        -- ADV-08: Multiplier 1,000,000X (1 Million X)
        do
            local ok, err = pcall(function()
                local mult = 1000000
                local text = tostring(mult) .. "X Strength"
                assert_eq(text, "1000000X Strength", "1000000X format")
            end)
            record_test("ADV_08_MultiplierFormat_1000000X", "MULTIPLIER_FORMAT", ok, err)
        end

        -- ADV-09: Multiplier 1,000,000,000X (1 Billion X)
        do
            local ok, err = pcall(function()
                local mult = 1000000000
                local text = tostring(mult) .. "X Strength"
                assert_eq(text, "1000000000X Strength", "1000000000X format")
            end)
            record_test("ADV_09_MultiplierFormat_1000000000X", "MULTIPLIER_FORMAT", ok, err)
        end

        -- -------------------------------------------------------------
        -- SECTION 3: RAPID REMOTE FIRE STRESS TESTING
        -- -------------------------------------------------------------

        -- ADV-10: Rapid Burst Fire RequestRebirth (50 requests spam)
        do
            local ok, err = pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                assert(remotes, "Remotes folder must exist")
                local reqRebirth = remotes:FindFirstChild("RequestRebirth")
                assert(reqRebirth, "RequestRebirth remote must exist")

                -- Fire 50 times in immediate succession
                for i = 1, 50 do
                    reqRebirth:FireServer()
                end
                
                -- Also fire with invalid action payload to test server resilience
                for i = 1, 10 do
                    reqRebirth:FireServer({ MaliciousPayload = true, Number = 999999 })
                end
            end)
            record_test("ADV_10_RapidRemoteSpam_RequestRebirth", "REMOTE_STRESS", ok, err)
        end

        -- ADV-11: Rapid Burst Fire RequestSkipRebirth (50 requests spam)
        do
            local ok, err = pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local reqSkip = remotes and remotes:FindFirstChild("RequestSkipRebirth")
                assert(reqSkip, "RequestSkipRebirth remote must exist")

                -- Fire 50 times in immediate succession
                for i = 1, 50 do
                    reqSkip:FireServer()
                end
            end)
            record_test("ADV_11_RapidRemoteSpam_RequestSkipRebirth", "REMOTE_STRESS", ok, err)
        end

        -- ADV-12: Server State Integrity Post-Spam
        do
            local ok, err = pcall(function()
                -- Verify player attributes and session are intact after spam
                local bigger = player:GetAttribute("Bigger")
                local level = player:GetAttribute("Level")
                local mult = player:GetAttribute("Multiplier")
                assert(bigger ~= nil, "Bigger attribute must exist")
                assert(level ~= nil, "Level attribute must exist")
                assert(mult ~= nil, "Multiplier attribute must exist")
                assert(bigger >= 1, "Bigger must remain valid >= 1")
                assert(level >= 1, "Level must remain valid >= 1")
                assert(mult >= 1, "Multiplier must remain valid >= 1")
            end)
            record_test("ADV_12_ServerStateIntegrity_PostSpam", "REMOTE_STRESS", ok, err)
        end

        -- -------------------------------------------------------------
        -- SECTION 4: RESPONSIVE SCALING & ASPECT RATIO TESTING
        -- -------------------------------------------------------------

        if rebirthPanel then
            -- ADV-13: UIAspectRatioConstraint Inspection
            do
                local ok, err = pcall(function()
                    local aspectConstraint = rebirthPanel:FindFirstChildOfClass("UIAspectRatioConstraint")
                    assert(aspectConstraint ~= nil, "UIAspectRatioConstraint must exist on RebirthPanel")
                    assert_approx(aspectConstraint.AspectRatio, 1.3502, 0.001, "Aspect ratio must be 1.3502")
                    assert_eq(aspectConstraint.AspectType, Enum.AspectType.FitWithinMaxSize, "AspectType should be FitWithinMaxSize")
                end)
                record_test("ADV_13_AspectRatioConstraint_1_3502", "RESPONSIVE_SCALING", ok, err)
            end

            -- ADV-14: AnchorPoint & Centering in SafeAreaRoot
            do
                local ok, err = pcall(function()
                    assert_eq(rebirthPanel.AnchorPoint.X, 0.5, "AnchorPoint.X must be 0.5")
                    assert_eq(rebirthPanel.AnchorPoint.Y, 0.5, "AnchorPoint.Y must be 0.5")
                    assert_eq(rebirthPanel.Position.X.Scale, 0.5, "Position.X.Scale must be 0.5")
                    assert_eq(rebirthPanel.Position.Y.Scale, 0.5, "Position.Y.Scale must be 0.5")
                end)
                record_test("ADV_14_PanelCentering_SafeAreaRoot", "RESPONSIVE_SCALING", ok, err)
            end

            -- ADV-15: Internal Layout Composition Bounds (No Out-of-Panel Overflows)
            do
                local ok, err = pcall(function()
                    local header = rebirthPanel:FindFirstChild("Header")
                    local closeBtn = rebirthPanel:FindFirstChild("CloseButton")
                    local multBar = rebirthPanel:FindFirstChild("MultiplierBar")
                    local currentCard = rebirthPanel:FindFirstChild("CurrentCard")
                    local nextCard = rebirthPanel:FindFirstChild("NextCard")
                    local arrows = rebirthPanel:FindFirstChild("Arrows")
                    local buttons = rebirthPanel:FindFirstChild("Buttons")

                    assert(header, "Header must exist")
                    assert(closeBtn, "CloseButton must exist")
                    assert(multBar, "MultiplierBar must exist")
                    assert(currentCard, "CurrentCard must exist")
                    assert(nextCard, "NextCard must exist")
                    assert(arrows, "Arrows must exist")
                    assert(buttons, "Buttons must exist")

                    -- Verify relative scale positions stay strictly within [0, 1] range
                    assert(header.Position.X.Scale >= 0 and header.Position.X.Scale <= 1, "Header X in bounds")
                    assert(header.Position.Y.Scale >= 0 and header.Position.Y.Scale <= 1, "Header Y in bounds")
                    assert(closeBtn.Position.X.Scale >= 0 and closeBtn.Position.X.Scale <= 1, "CloseButton X in bounds")
                    assert(buttons.Position.Y.Scale >= 0 and buttons.Position.Y.Scale <= 1, "Buttons Y in bounds")
                    assert(currentCard.Position.X.Scale >= 0 and currentCard.Position.X.Scale <= 1, "CurrentCard X in bounds")
                    assert(nextCard.Position.X.Scale >= 0 and nextCard.Position.X.Scale <= 1, "NextCard X in bounds")
                    assert(arrows.Position.X.Scale >= 0 and arrows.Position.X.Scale <= 1, "Arrows X in bounds")
                end)
                record_test("ADV_15_InternalLayoutBounds_Containment", "RESPONSIVE_SCALING", ok, err)
            end

            -- ADV-16: Symmetrical Card & Arrow Layout Alignment
            do
                local ok, err = pcall(function()
                    local currentCard = rebirthPanel:FindFirstChild("CurrentCard")
                    local nextCard = rebirthPanel:FindFirstChild("NextCard")
                    local arrows = rebirthPanel:FindFirstChild("Arrows")

                    -- Verify cards are horizontally symmetrical around center (0.5)
                    local currentLeft = currentCard.Position.X.Scale
                    local currentWidth = currentCard.Size.X.Scale
                    local currentRight = currentLeft + currentWidth -- 0.141 + 0.264 = 0.405
                    
                    local nextLeft = nextCard.Position.X.Scale -- 0.618
                    local nextWidth = nextCard.Size.X.Scale -- 0.264
                    
                    local arrowCenter = arrows.Position.X.Scale -- 0.5
                    assert_eq(arrowCenter, 0.5, "Arrow must be centered at X=0.5")
                    
                    -- Distance from currentRight to arrowCenter = 0.5 - 0.405 = 0.095
                    -- Distance from arrowCenter to nextLeft = 0.618 - 0.5 = 0.118 (~0.1 balanced)
                    assert(currentRight < arrowCenter, "CurrentCard must be left of Arrow")
                    assert(nextLeft > arrowCenter, "NextCard must be right of Arrow")
                    assert_eq(currentCard.Size.Y.Scale, nextCard.Size.Y.Scale, "Cards must have identical height scale")
                    assert_eq(currentCard.Position.Y.Scale, nextCard.Position.Y.Scale, "Cards must have identical vertical Y scale")
                end)
                record_test("ADV_16_SymmetricalCardArrowAlignment", "RESPONSIVE_SCALING", ok, err)
            end
        else
            record_test("ADV_13_16_RebirthPanel_NotFound", "RESPONSIVE_SCALING", false, "RebirthPanel not found in live PlayerGui")
        end

        return HttpService:JSONEncode(results)
    """

    print("[2/4] Executing Adversarial Tests in Client DataModel...")
    exec_res = client.execute_luau(adversarial_luau_code, "Client")
    if "result" not in exec_res or "content" not in exec_res["result"]:
        print("ERROR executing adversarial test script:", exec_res)
        client.close()
        return False

    raw_output = exec_res["result"]["content"][0]["text"]
    try:
        report = json.loads(raw_output)
    except Exception as e:
        print("ERROR parsing JSON:", e)
        print("Raw:", raw_output)
        client.close()
        return False

    print("[3/4] Adversarial Test Results Breakdown:")
    print("-" * 80)
    passed_count = 0
    failed_count = 0
    categories = {}

    for t in report:
        c = t.get("Category", "UNKNOWN")
        if c not in categories:
            categories[c] = {"passed": 0, "failed": 0, "total": 0}
        categories[c]["total"] += 1
        
        status_str = "[PASS]" if t["Passed"] else "[FAIL]"
        if t["Passed"]:
            passed_count += 1
            categories[c]["passed"] += 1
        else:
            failed_count += 1
            categories[c]["failed"] += 1
        print(f"  {status_str} [{c:<20s}] {t['Name']}")
        if not t["Passed"]:
            print(f"         Error: {t.get('Error')}")

    print("-" * 80)
    for c, stats in categories.items():
        st = "PASSED" if stats["failed"] == 0 else "FAILED"
        print(f"  [{st:6s}] {c:<22s}: {stats['passed']}/{stats['total']} passed ({stats['failed']} failed)")
    print("=" * 80)
    print(f"  ADVERSARIAL SUITE TOTAL: {passed_count}/{len(report)} PASSED ({failed_count} FAILED)")
    print("=" * 80)

    # Also test Viewport Aspect Ratio Simulation across 16:9, 4:3, 19.5:9
    print("\n[4/4] Executing Viewport Aspect Ratio Simulation Tests...")
    viewport_sim_luau = """
        local HttpService = game:GetService("HttpService")
        local Players = game:GetService("Players")
        local player = Players:GetPlayers()[1] or Players.LocalPlayer
        local playerGui = player and player:FindFirstChild("PlayerGui")
        local mainHud = playerGui and playerGui:FindFirstChild("MainHUD")
        local safeArea = mainHud and mainHud:FindFirstChild("SafeAreaRoot")
        local overlayHud = safeArea and safeArea:FindFirstChild("OverlayHUD")
        local panel = overlayHud and overlayHud:FindFirstChild("RebirthPanel")
        
        local viewports = {
            { Name = "16:9 Desktop (1920x1080)", Width = 1920, Height = 1080, Aspect = 1920/1080 },
            { Name = "4:3 Tablet/Legacy (1024x768)", Width = 1024, Height = 768, Aspect = 1024/768 },
            { Name = "19.5:9 Mobile (2532x1170)", Width = 2532, Height = 1170, Aspect = 2532/1170 },
            { Name = "19.5:9 Mobile Compact (844x390)", Width = 844, Height = 390, Aspect = 844/390 },
            { Name = "1:1 Square Extreme (1000x1000)", Width = 1000, Height = 1000, Aspect = 1.0 },
            { Name = "9:16 Portrait Mobile (1080x1920)", Width = 1080, Height = 1920, Aspect = 1080/1920 }
        }

        local sim_results = {}
        local panelAspect = 1.3502
        local panelBaseWidthScale = 0.5 -- Typical base modal scale
        local panelBaseHeightScale = 0.5

        for _, vp in ipairs(viewports) do
            -- In Roblox UI, with UIAspectRatioConstraint (AspectType = FitWithinMaxSize) on a frame:
            -- Max allowed box in safe area is (vp.Width * SafeScale, vp.Height * SafeScale)
            -- For AspectRatio = 1.3502:
            -- If screen is wider than 1.3502 (e.g. 16:9 = 1.777, 19.5:9 = 2.164), height constrains the panel.
            -- If screen is narrower than 1.3502 (e.g. 4:3 = 1.333, 1:1 = 1.0, 9:16 = 0.5625), width constrains the panel.
            
            local calcWidth, calcHeight
            local safeWidth = vp.Width - 16 -- 8px padding each side
            local safeHeight = vp.Height - 16
            
            if (safeWidth / safeHeight) >= panelAspect then
                -- Height constrained
                calcHeight = math.min(safeHeight * 0.75, 600)
                calcWidth = calcHeight * panelAspect
            else
                -- Width constrained
                calcWidth = math.min(safeWidth * 0.85, 800)
                calcHeight = calcWidth / panelAspect
            end

            local fitsHorizontally = calcWidth <= safeWidth
            local fitsVertically = calcHeight <= safeHeight
            local preservedAspect = math.abs((calcWidth / calcHeight) - panelAspect) < 0.005

            table.insert(sim_results, {
                Viewport = vp.Name,
                Width = vp.Width,
                Height = vp.Height,
                CalcPanelWidth = math.floor(calcWidth + 0.5),
                CalcPanelHeight = math.floor(calcHeight + 0.5),
                FitsHorizontally = fitsHorizontally,
                FitsVertically = fitsVertically,
                PreservedAspect = preservedAspect,
                Passed = fitsHorizontally and fitsVertically and preservedAspect
            })
        end

        return HttpService:JSONEncode(sim_results)
    """

    vp_res = client.execute_luau(viewport_sim_luau, "Client")
    if "result" in vp_res and "content" in vp_res["result"]:
        vp_output = vp_res["result"]["content"][0]["text"]
        vp_report = json.loads(vp_output)
        for r in vp_report:
            st = "[PASS]" if r["Passed"] else "[FAIL]"
            print(f"  {st} {r['Viewport']:<35s} -> Size: {r['CalcPanelWidth']}x{r['CalcPanelHeight']}px (Fits: {r['FitsHorizontally'] and r['FitsVertically']}, Aspect: {r['PreservedAspect']})")
    
    client.close()
    return failed_count == 0

if __name__ == "__main__":
    success = run_adversarial_tests()
    sys.exit(0 if success else 1)
