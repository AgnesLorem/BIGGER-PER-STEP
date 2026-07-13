# Player Profile Example Schema

This document provides a structural representation of a loaded Player Profile as it exists in the Save and Session Layers.

```json
{
  "playerUserId": 12345678,
  "profileData": {
    "size": 120.5,
    "destruction": 3,
    "rebirths": 1,
    "unlockedUpgrades": [
      "upgrade_growth_01",
      "upgrade_growth_02"
    ],
    "equippedUpgrade": "upgrade_growth_02",
    "completedPortals": [
      "portal_city_01"
    ],
    "settings": {
      "soundEnabled": true,
      "musicEnabled": false
    },
    "metadata": {
      "lastLogoutTimestamp": 1783940292
    }
  }
}
```
