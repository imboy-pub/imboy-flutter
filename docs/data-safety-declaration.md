# Google Play Data Safety Declaration — IMBoy

> 本文档为 Google Play Console "Data safety" 表单填写指南。
> 提交时按照以下内容逐项填写。

---

## Overview

| Question | Answer |
|----------|--------|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS/WSS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** (设置 > 隐私设置 > 注销账号) |

---

## Data Types Collected

### 1. Personal info

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Name (nickname) | Yes | No | App functionality | No |
| Phone number | Yes | No | Account management | No |
| User IDs | Yes | No | App functionality | No |

### 2. Messages

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Other in-app messages | Yes | No | App functionality | No |

> Note: In E2EE mode, message content is end-to-end encrypted. Server cannot access plaintext.

### 3. Photos and videos

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Photos | Yes | No | App functionality | Yes |
| Videos | Yes | No | App functionality | Yes |

### 4. Audio

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Voice or sound recordings | Yes | No | App functionality | Yes |

### 5. Files and docs

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Files and docs | Yes | No | App functionality | Yes |

### 6. Location

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Approximate location | Yes | No | App functionality | Yes |
| Precise location | Yes | No | App functionality | Yes |

> Location is only accessed when user sends location message or uses "People nearby".

### 7. App info and performance

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Crash logs | Yes | No | Analytics | No |
| Performance diagnostics | Yes | No | Analytics | No |

### 8. Device or other IDs

| Data type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Device or other IDs | Yes | No | App functionality, Analytics | No |

---

## Data NOT Collected

- Financial info (payment, purchase history)
- Health and fitness
- Emails
- Search history
- Browsing history
- Calendar
- Contacts (address book)

---

## Data Handling

| Aspect | Details |
|--------|---------|
| Encryption in transit | Yes — all data transmitted over HTTPS/WSS with TLS 1.2+ |
| Encryption at rest | Yes — sensitive fields (passwords, keys) encrypted; E2EE messages stored encrypted |
| Data deletion | Users can request account deletion (Settings > Privacy > Delete account). Data purged within 60 days. |
| Data retention | Active accounts: retained while account exists. Deleted accounts: purged within 60 days. |

---

## Apple App Privacy (App Store)

### Data Used to Track You
- **None**

### Data Linked to You
- Phone number, User ID, Name/nickname

### Data Not Linked to You
- Crash data, Performance data

---

## Notes for Submission

1. **No third-party analytics SDK** currently integrated (Sentry pending)
2. **No advertising SDK** — no ad-related data collection
3. **No Firebase Analytics** — only FCM for push notifications (pending)
4. When FCM is integrated, add: "Device or other IDs → collected for Push notifications"
