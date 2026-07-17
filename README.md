<div align="center">

# CarSpot

**A car social network for lb-phone and sd-phone — share builds, meet up, compete, and show off your garage.**

</div>

---

## About

**CarSpot** turns the in-game phone into a social platform built around cars — posts, follows, garage, events, and weekly rankings.

Works with **lb-phone** and **sd-phone** from the same resource (`Config.Phone = 'auto'`).

---

## Requirements

| Dependency | Required |
|---|---|
| lb-phone **or** sd-phone | One of these |
| oxmysql | Yes |
| ox_lib | Yes |
| QBCore / Qbox / ESX | One of these |

---

## Installation

```
resources/[phone]/m-carspot
```

### server.cfg

Start **after** your phone:

```cfg
ensure oxmysql
ensure ox_lib
ensure sd-phone   # or: ensure lb-phone
ensure m-carspot
```

### Configure

`shared/config.lua`:

```lua
Config.Phone = 'auto'       -- 'auto' | 'lb-phone' | 'sd-phone'
Config.Framework = 'qbcore' -- 'qbcore' | 'esx'
Config.Locale = 'en'        -- en | pt | es | fr | de | it
Config.DefaultApp = false   -- false = App Store download
```

---

## Features

| | |
|---|---|
| **Feed** | Infinite-scroll posts with likes, comments, saves |
| **Posts** | Gallery photos + vehicle details |
| **Profiles** | Username, bio, avatar, banner, follow |
| **Garage** | Showcase / import owned vehicles |
| **Events** | Meets & races with optional reminders |
| **Ranking** | Weekly most voted / class categories |
| **Locales** | en, pt, es, fr, de, it |

---

## Notes

- Database tables (`carspot_*`) are created automatically from `carspot.sql`.
- Do not run a second CarSpot resource against the same DB if you want separate data.
