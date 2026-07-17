# UI Migration and Report Generation

This document defines the requirements, execution modes, validation report structures, and rollback policies for the edit-mode migration script `scratch/apply_cdra_hud.luau`.

---

## 🛠️ Execution Modes
The migration tool supports four distinct execution modes:

1.  **`ValidateOnly`**:
    *   Scans the target UI for CDRA compliance.
    *   Generates a machine-readable JSON validation report.
    *   Performs **zero** mutations on the place hierarchy or properties.
2.  **`Repair`**:
    *   Applies the necessary Scale, AnchorPoint, UDim2 corrections, and adds missing constraints.
    *   Uses idempotent lookups to reuse existing constraints.
    *   Does **not** modify hierarchy structures (Hierarchy Freeze).
3.  **`Backup`**:
    *   Serializes and exports all current layout properties of `MainHUD` to `scratch/hud_backup.json` before any modification is made.
4.  **`Restore`**:
    *   Reads `scratch/hud_backup.json` and restores the exact original properties and positioning of elements, permitting safe rollbacks.

---

## 🚨 Hierarchy Integrity Check (Abort Rule)
*   **Safety Rule**: Before executing any mutations (in `Repair` mode), the script must validate that the expected hierarchy structure matches baseline assumptions.
*   **Abort Action**: If any expected base containers (e.g. `LeftSidebar`, `BottomHUD`, `RightSidebar`) are missing, misnamed, or parented in an unexpected manner, the script must immediately **abort** with an error. It is strictly forbidden from trying to forcefully rename, move, delete, or reconstruct hierarchies.

---

## 📊 Machine-Readable Report Structure (`hud_validation_report.json`)
When executed in `ValidateOnly` mode, the script writes a validation report to `scratch/hud_validation_report.json` using this format:

```json
{
	"Timestamp": "2026-07-17T15:00:00Z",
	"ComplianceScore": 85.0,
	"Errors": [
		{
			"Path": "StarterGui.MainHUD.BottomHUD.ProgressBarFrame.ProgressBG",
			"Type": "InvalidScale",
			"Message": "ProgressBG has invalid Y-scale scale of 2.88"
		}
	],
	"Warnings": [
		{
			"Path": "StarterGui.MainHUD.LeftSidebar.Store",
			"Type": "MissingConstraint",
			"Message": "Store is missing UIAspectRatioConstraint"
		}
	],
	"Duplicates": [],
	"FixesApplied": 0
}
```

---

## 🔄 Idempotency Verification
To guarantee safety, the migration script must be tested for true idempotency:
1.  Run the tool in `Repair` mode once.
2.  Run the tool in `ValidateOnly` mode immediately after.
3.  **Pass Criteria**: The second run must report a `ComplianceScore` of `100.0`, zero errors, zero warnings, and zero fixes applied. If the second run generates warnings, duplicates, or applies new fixes, the script has failed idempotency testing.
