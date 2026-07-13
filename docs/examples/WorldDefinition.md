# World Definition Schema Example

This document provides a conceptual structural template for a World configuration. World definitions link static map models with their objective rules.

```json
{
  "id": "world_city_01",
  "displayName": "City Ruins",
  "mapModelAssetId": "rbxassetid://123456789",
  "entrySizeLimit": 100,
  "timeLimitSeconds": 180,
  "mainObjective": {
    "id": "destroyable_city_house_01",
    "spawnOffset": { "x": 0, "y": 10, "z": -120 }
  },
  "rewards": {
    "destructionGranted": 1
  }
}
```
