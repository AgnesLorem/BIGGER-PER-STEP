import sys
import os
import json

sys.path.insert(0, r"f:\BIGGER\.agents\worker_m3_1")
from studio_helper import StudioClient

def main():
    client = StudioClient()
    luau_code = """
        local starterGui = game:GetService("StarterGui")
        local mainHud = starterGui:FindFirstChild("MainHUD")
        if not mainHud then return "No MainHUD" end
        local safeArea = mainHud:FindFirstChild("SafeAreaRoot")
        local overlay = safeArea and safeArea:FindFirstChild("OverlayHUD")
        local panel = overlay and overlay:FindFirstChild("RebirthPanel")
        if not panel then return "No RebirthPanel" end
        
        local tree = {}
        local function serialize(inst)
            local node = {
                Name = inst.Name,
                Class = inst.ClassName,
                Children = {}
            }
            if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
                node.Image = inst.Image
            end
            if inst:IsA("TextLabel") or inst:IsA("TextButton") then
                node.Text = inst.Text
            end
            for _, child in ipairs(inst:GetChildren()) do
                table.insert(node.Children, serialize(child))
            end
            return node
        end
        return game:GetService("HttpService"):JSONEncode(serialize(panel))
    """
    res = client.execute_luau(luau_code, "Edit")
    if "result" in res and "content" in res["result"]:
        txt = res["result"]["content"][0]["text"]
        print("Success:", txt[:300])
    else:
        print("Response:", res)
    client.close()

if __name__ == "__main__":
    main()
