import subprocess
import json
import time
import os

import glob

def find_studio_mcp():
    # 1. Try to find the directory of currently running RobloxStudioBeta
    try:
        import subprocess as sp
        out = sp.check_output(
            ["powershell", "-NoProfile", "-Command", "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path"],
            text=True, stderr=sp.DEVNULL
        ).strip()
        if out and os.path.exists(out):
            candidate = os.path.join(os.path.dirname(out), "StudioMCP.exe")
            if os.path.exists(candidate):
                return candidate
    except Exception:
        pass

    # 2. Search versions directory sorted by mtime
    base = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions")
    matches = glob.glob(os.path.join(base, "version-*", "StudioMCP.exe"))
    if matches:
        matches.sort(key=os.path.getmtime, reverse=True)
        return matches[0]

    # 3. Fallback to default path in localappdata
    fallback = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\version-9fe94fb0e9d84c25\StudioMCP.exe")
    return fallback

STUDIO_MCP_EXE = find_studio_mcp()

class StudioClient:
    def __init__(self):
        self.proc = subprocess.Popen(
            [STUDIO_MCP_EXE, "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        self.msg_id = 1
        self._init_handshake()
        self.studio_id = self._get_studio_id()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def __del__(self):
        try:
            self.close()
        except Exception:
            pass

    def _init_handshake(self):
        init_req = {
            "jsonrpc": "2.0",
            "id": self.msg_id,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "StudioE2EClient", "version": "1.0"}
            }
        }
        self.msg_id += 1
        self.proc.stdin.write(json.dumps(init_req) + "\n")
        self.proc.stdin.flush()
        self._read_response()
        
        notif = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        }
        self.proc.stdin.write(json.dumps(notif) + "\n")
        self.proc.stdin.flush()

    def _read_response(self):
        while True:
            line = self.proc.stdout.readline()
            if not line:
                return None
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                return data
            except Exception:
                continue

    def call_tool(self, name, arguments):
        req = {
            "jsonrpc": "2.0",
            "id": self.msg_id,
            "method": "tools/call",
            "params": {
                "name": name,
                "arguments": arguments
            }
        }
        self.msg_id += 1
        self.proc.stdin.write(json.dumps(req) + "\n")
        self.proc.stdin.flush()
        return self._read_response()

    def _get_studio_id(self):
        for _ in range(15):
            studios = self.call_tool("list_roblox_studios", {})
            if isinstance(studios, dict):
                res = studios.get("result", {})
                if not res.get("isError"):
                    content = res.get("content", [{}])[0].get("text", "")
                    try:
                        s_data = json.loads(content)
                        if len(s_data.get("studios", [])) > 0:
                            return s_data["studios"][0]["id"]
                    except Exception:
                        pass
            time.sleep(1)
        return None

    def get_studio_state(self):
        return self.call_tool("get_studio_state", {"studio_id": self.studio_id})

    def start_stop_play(self, is_start):
        return self.call_tool("start_stop_play", {"studio_id": self.studio_id, "is_start": is_start})

    def execute_luau(self, code, datamodel="Edit"):
        return self.call_tool("execute_luau", {
            "studio_id": self.studio_id,
            "datamodel_type": datamodel,
            "code": code
        })

    def inspect_instance(self, path):
        return self.call_tool("inspect_instance", {"studio_id": self.studio_id, "path": path})

    def get_console_output(self):
        return self.call_tool("get_console_output", {"studio_id": self.studio_id})

    def user_mouse_input(self, actions, datamodel="Client"):
        return self.call_tool("user_mouse_input", {
            "studio_id": self.studio_id,
            "actions": actions,
            "datamodel_type": datamodel
        })

    def screen_capture(self, capture_id="capture"):
        return self.call_tool("screen_capture", {
            "studio_id": self.studio_id,
            "capture_id": capture_id
        })

    def close(self):
        try:
            if self.proc and self.proc.poll() is None:
                self.proc.terminate()
                try:
                    self.proc.wait(timeout=2)
                except Exception:
                    self.proc.kill()
        except Exception:
            pass
