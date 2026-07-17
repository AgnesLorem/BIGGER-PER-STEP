# Player Profile Example Schema

This document provides a structural representation of a loaded Player Profile as it exists in the Save and Session Layers.

```json
{
  "SchemaVersion": 1,
  "Bigger": 120,
  "Destruction": 3,
  "Rebirth": 1,
  "UnlockedGrowthUpgrades": {
    "Upgrade_1": true,
    "Upgrade_2": true
  },
  "EquippedGrowthUpgrade": "Upgrade_2",
  "CompletedPortals": {
    "Portal_City_1": true
  },
  "Settings": {
    "SoundEnabled": true,
    "MusicEnabled": false
  },
  "HasDoubleMultiplier": false,
  "HasVip": false,
  "ProcessedPurchaseIds": {
    "Purchase:example-123": true
  },
  "LastActiveTimestamp": 1783940292,
  "LastLogoutTimestamp": 1783940200,
  "LastSaveTimestamp": 1783940292,
  "LeaseOwner": "server-job-id",
  "LeaseExpiresAt": 1783940472
}
```

Optional `nil` fields are omitted. Runtime-only fields such as `PendingPurchaseIds` and `ProfileMutationsFrozen` are never stored in this profile.
