# UI Event Bus

This document defines the decoupled communication patterns and typed event registry for user interfaces in the **Bigger** repository.

---

## 📡 Decoupling Pattern
*   **Zero Direct Dependency**: Client controllers (e.g. `GuiController`, `InventoryController`, `ShopController`) are forbidden from referencing or calling each other directly.
*   **Event Hub**: All controller-to-controller messages, screen changes, and gameplay triggers must go through the centralized `UIEventBus.luau`.
*   **Decoupled Chain**:
    *   `ResponsiveController` publishes category/viewport/profile state.
    *   `ResponsivePolicy` translates category to layout rules.
    *   The policies and actions are published to `UIEventBus`.
    *   Specific controllers subscribe to `UIEventBus` topics to handle presentations.

---

## 🏷️ Centrally Typed Events
To prevent runtime string typos, all events published through `UIEventBus` must map to a defined event name registry:

| Event Name | Parameter Type | Description |
|---|---|---|
| `LayoutChanged` | `LayoutProfile` | Fired when a new CDRA layout profile is applied |
| `InventoryOpened` | `nil` | Requests opening the Inventory panel overlay |
| `InventoryClosed` | `nil` | Requests closing the Inventory panel overlay |
| `ShopOpened` | `nil` | Requests opening the Upgrade Shop panel overlay |
| `QuestOpened` | `nil` | Requests opening the Quests panel overlay |
| `SidebarCollapsed` | `string` (Sidebar Name) | Notifies that a sidebar has collapsed into compact mode |
| `PopupClosed` | `string` (Popup Name) | Notifies that a confirmation popup has closed |

---

## 🛠️ Usage Guideline
*   **Subscribe**: Controllers register listeners during their `Init()` lifecycle phase:
```luau
UIEventBus.Subscribe("LayoutChanged", function(newProfile: LayoutProfile)
	self:ApplyProfile(newProfile)
end)
```
*   **Publish**: Events are published asynchronously using `task.spawn` inside the event hub to ensure subscriber errors do not halt game critical loops:
```luau
UIEventBus.Publish("InventoryOpened")
```
