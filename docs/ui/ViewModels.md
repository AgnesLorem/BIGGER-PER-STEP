# ViewModels and UI Data Flow

This document defines the data flow architecture for user interfaces in the **Bigger** repository, establishing a strict unidirectional data loop to prevent tangled state dependencies.

---

## 🏛️ MVVM Data Flow Architecture

```
UI Component (View) ──(Reads snapshot)──> ViewModel (Immutable)
        │                                       ▲
  (Fires event)                            (Mutates/Updates)
        │                                       │
        ▼                                       │
  UI Event Bus ───────────────────────────> Client Controller
```

---

## 🔒 ViewModel Immutability Rules
*   **Immutable Snapshots**: A ViewModel represents an immutable snapshot of game state at a specific frame.
*   **Zero View Mutation**: Views (GUI objects, LocalScripts, UI component modules) are strictly read-only consumers of ViewModels. A View must **never** modify, write, or assign properties back to a ViewModel.
*   **Controller Mutation Authority**: Only authoritatively designated Client Controllers are permitted to instantiate, update, or mutate ViewModels.
*   **Unidirectional Binding**: When a state changes, the Controller creates/updates the ViewModel snapshot and publishes it. Views bind to the update signals to refresh their visual representations.

---

## 🚫 Forbidden GUI Dependency Paths
*   **Direct Service Access**: Views must **never** call or read states directly from client services (e.g. `SessionService`, `InventoryService`, `UpgradeService`, `SaveService`).
*   **Direct Session Reads**: UI scripts must not index session attributes or player profile values directly for presentation values. All raw data must be mapped through a ViewModel.
*   **State Mutation from GUI**: GUI components must never directly call mutations. Instead, they publish action events to the UI Event Bus.
