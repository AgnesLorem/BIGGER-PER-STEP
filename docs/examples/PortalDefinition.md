# Portal Definition Schema Example

This document provides a conceptual structural template for a Portal configuration. Portal definitions are immutable data structures stored in the configuration layer.

```json
{
  "id": "portal_city_01",
  "displayName": "City Outskirts",
  "zoneId": "lobby",
  "requirements": {
    "size": 100,
    "destruction": 0,
    "rebirths": 0
  },
  "targetWorldId": "world_city_01",
  "visuals": {
    "portalColor": "RGB(0, 120, 255)",
    "particleColor": "RGB(100, 200, 255)",
    "promptText": "Enter City Outskirts"
  }
}
```
