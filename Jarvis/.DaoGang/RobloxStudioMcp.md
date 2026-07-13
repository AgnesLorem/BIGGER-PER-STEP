# RobloxStudioMcp.md - Project Genesis

Child workflow for connecting AI coding agents to Roblox Studio through MCP.

Always read [`Jarvis.md`](Jarvis.md) first. This file only covers Studio MCP setup,
Studio-instance selection, and safe use of Studio command tools.

## 1. Purpose

Use Roblox Studio MCP when an agent needs to inspect or change the live Studio
DataModel, verify synced source objects, create missing Studio-owned source
objects, or run narrow Studio-side Luau commands.

MCP does not replace the repository source tree. Local files under `src/`
remain the main reference for project structure.

## 2. Client Setup

Roblox Studio provides a stdio MCP server through:

```text
%LOCALAPPDATA%\Roblox\mcp.bat
```

For JSON-based MCP clients, use:

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": [
        "/c",
        "%LOCALAPPDATA%\\Roblox\\mcp.bat"
      ]
    }
  }
}
```

For Claude Code, use:

```powershell
claude mcp add --transport stdio Roblox_Studio -- "cmd.exe" "/c" "%LOCALAPPDATA%\Roblox\mcp.bat"
```

For Codex, use `command` and `args`, not `url`, because Roblox Studio MCP is a
stdio server:

```toml
[mcp_servers.roblox_studio]
enabled = true
command = "cmd.exe"
args = ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
startup_timeout_sec = 20
tool_timeout_sec = 120
```

After changing MCP client config, restart the AI client or start a new session.
MCP tool registration is normally loaded at client startup.

MCP preflight:

- Before any MCP-dependent task, confirm the current client config still has the
  Roblox Studio server enabled.
- If MCP client config changed, restart the AI client or start a new session
  before assuming the tools are available.
- Confirm the current session actually exposes Roblox Studio MCP tools before
  continuing with MCP-dependent work.
- If MCP is not enabled or the tools are missing, troubleshoot this doc's setup
  and launcher sections before proceeding.

## 3. Studio Setup

In Roblox Studio, enable Studio as an MCP server before expecting tools to work.
The Studio UI may show `No clients connected` until the AI client starts the MCP
server and connects.

The plugin `Scope` setting, such as `Global` or `Project`, controls where plugin
settings are stored. It does not choose which place the agent edits, and it does
not change Azul sync scope.

## 4. Known Launcher Issue

On this machine, `%LOCALAPPDATA%\Roblox\mcp.bat` has previously contained a
malformed fallback `if` / `else` branch. The hardcoded `StudioMCP.exe` path can
still work while that installed Studio version exists, but the fallback may print
batch errors or fail after Roblox updates.

If MCP fails to start:

1. Inspect `%LOCALAPPDATA%\Roblox\mcp.bat`.
2. Confirm the current `StudioMCP.exe` under `%LOCALAPPDATA%\Roblox\Versions`.
3. If needed, configure the MCP client to call the real executable directly.

Direct executable example:

```toml
[mcp_servers.roblox_studio]
enabled = true
command = "C:\\Users\\Admin\\AppData\\Local\\Roblox\\Versions\\<version>\\StudioMCP.exe"
startup_timeout_sec = 20
tool_timeout_sec = 120
```

Use the actual installed `<version>` folder. Do not assume a remembered
`StudioMCP.exe` path is still current after Roblox updates.

## 5. Multiple Studio Windows

Multiple open Studio windows do not automatically mean multiple usable MCP tool
sets. A single MCP connection can enumerate multiple open Studio instances.

Before any Studio modification, always call the Studio-list tool and set the
correct active Studio instance. Do not rely on the MCP server's heuristic active
instance when more than one Studio window is open.

Required sequence:

1. List connected Studio instances.
2. Identify the intended project/place.
3. Set that Studio instance active.
4. Verify the target path and project markers.
5. Only then read, create, edit, or execute Luau.

If the correct Studio instance cannot be proven, stop and warn instead of
editing a guessed place.

## 6. Selecting The Correct Place

Use the target path and file structure as the primary selection evidence.

For each candidate Studio instance:

1. Set it active temporarily.
2. Check that expected source files (e.g. `src/server/services/SaveService.luau`) exist in Studio with matching names and classes.
3. Check the exact target source object exists when editing an existing source.
4. Check repo-specific markers when useful, such as:
   - expected `src/server/services/` or `src/client/controllers/` paths
   - a known source snippet from the local file
5. Prefer the Studio instance where the target path and markers match the local source tree.

Do not choose by window title alone when several Studio windows are open. Window titles can be ambiguous, stale, or unrelated to the active synced tree.

If two Studio instances both match the same target evidence, stop and ask for confirmation.

## 7. Safe MCP Edits

When using `execute_luau` or similar write-capable tools:

- Keep commands narrow and idempotent.
- Verify the active Studio instance immediately before the command.
- Prefer exact paths over broad tree scans for writes.
- Do not run destructive DataModel cleanup commands unless explicitly requested.
- Return a concise verification summary from the command.
- Re-check the target path after the command completes.

For new source objects under `src/`, ensure they exist in Roblox Studio. You can use Roblox Studio MCP to create or verify the Studio object first when needed.

If MCP is unavailable, the active Studio cannot be proven, the create command fails, or the Studio object is not verified at the target path, warn clearly and stop.

## 8. Common Tool Expectations

Roblox Studio MCP may expose tools such as:

- `list_roblox_studios`
- `set_active_studio`
- `search_game_tree`
- `inspect_instance`
- `script_read`
- `script_search`
- `script_grep`
- `execute_luau`
- `multi_edit`
- `start_stop_play`

Available tools can differ by installed Studio/MCP version. Verify the actual tool surface in the current session before depending on a tool name.

## 9. Verification and Sync

- After creating or modifying a file locally under `src/`, verify that the changes are successfully mapped in Roblox Studio before calling the task complete.
- Verify that your local file and the corresponding Studio script object are fully in sync.
- Use `start_stop_play` to start, pause, or stop the Studio simulation to verify that runtime gameplay code behaves correctly during local tests.

