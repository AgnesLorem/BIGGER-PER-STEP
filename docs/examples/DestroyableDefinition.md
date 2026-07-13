# Destroyable Definition Schema Example

This document provides a conceptual structural template for a Destroyable Object definition. Destroyable Objects are the main targets inside WorldInstances.

```json
{
  "id": "destroyable_city_house_01",
  "displayName": "Abandoned Suburban House",
  "requiredSizeToDestroy": 80,
  "baseHealth": 200,
  "rewards": {
    "sizeGranted": 25,
    "destructionGranted": 0
  },
  "asset": {
    "modelAssetId": "rbxassetid://444455556",
    "scaleFactor": 1.0,
    "bounds": { "width": 30, "height": 20, "depth": 30 }
  }
}
```
