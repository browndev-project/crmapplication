# Dashboard & Analytics API

The Dashboard module provides high-level metrics and real-time operational insights. All data is dynamically filtered using **Hierarchical Scoping** to ensure users only see data they are authorized to manage.

## Base Path: `/api/v1/dashboard`

---

## 🔐 Permissions & Access Control

### Backend Authorization
Backend endpoints use the `authenticate` middleware to verify the user. Data filtering is then performed by the `resolveScope` utility:
- **Visibility**: Automatically restricted to the user's assigned leads, team, or group.
- **No Hard Permissions**: The backend does not check specific permission strings (e.g., `leads.view`) for dashboard aggregates; it relies entirely on the hierarchical scope.

### Frontend Modular Gating
The frontend UI gates widgets based on company-enabled modules:
- `modules.base`: Required to view the Dashboard page.
- `modules.lead`: Required for Leads, Pipeline, Status, and Sources charts.
- `modules.task`: Required for the "Tasks Due Today" card.
- `modules.meeting`: Required for the "Meetings Today" card.
- `modules.visit`: Required for the "Visits Today" card.

user base permissions:
- `leads.view`: Required for Leads, Pipeline, Status, and Sources charts.
- `tasks.view`: Required for the "Tasks Due Today" card.
- `meetings.view`: Required for the "Meetings Today" card.
- `visits.view`: Required for the "Visits Today" card.

### Role-Based UI Restrictions
- **Team Intelligence**: Only visible to users with `designation` higher than `SALES_EXECUTIVE` (e.g., Managers, Admins).

---

## 🏗️ Response Envelope
All dashboard APIs return a standardized `ApiResponse` object:
```json
{
  "statusCode": 200,
  "success": true,
  "data": { ... },
  "message": "Descriptive message"
}
```

---

## 1. Operational Schedule

### A. Today's Tasks & Meetings
**Endpoint:** `GET /today-schedule`  
**Description:** Returns counts for tasks and meetings due today (IST timezone range).

**Response Data Structure:**
```json
{
  "tasksDueToday": 12,
  "meetingsToday": 5
}
```

### B. Today's Site Visits
**Endpoint:** `GET /today-visits`  
**Description:** Breakdown of site visits scheduled for the current day.

**Response Data Structure:**
```json
{
  "totalVisits": 10,
  "scheduled": 6,
  "completed": 3,
  "cancelled": 1
}
```

---

## 2. Lead Funnel & Distribution

### A. Pipeline Stages (Funnels)
**Endpoint:** `GET /pipelines`  
**Description:** Count of leads in each pipeline stage (Hot, Warm, Cold).

**Response Data Structure:**
```json
{
  "pipelines": {
    "Hot": 45,
    "Warm": 30,
    "Cold": 15
  }
}
```

### B. Lead Status Distribution
**Endpoint:** `GET /lead-status`  
**Query Parameters:** `startDate`, `endDate` (YYYY-MM-DD)  
**Description:** Returns lead counts grouped by status. Status names are normalized (e.g., "new" -> "New").

**Response Data Structure:**
```json
{
  "leadStatusCounts": {
    "New": 20,
    "Contacted": 15,
    "Converted": 10,
    "Lost": 5
  }
}
```

### C. Lead Acquisition Sources
**Endpoint:** `GET /lead-sources`  
**Query Parameters:** `startDate`, `endDate` (YYYY-MM-DD)  
**Description:** Breakdown of leads by source (Website, Meta Ads, etc.).

**Response Data Structure:**
```json
{
  "leadSources": {
    "Website": 50,
    "Meta Ads": 30,
    "Manual": 5
  }
}
```

### D. Lead Counts
- `GET /convertedLeads`: Returns `{ "convertedLeads": number }`
- `GET /total-leads`: Returns `{ "totalLeads": number }`
- `GET /lead-assignment`: Returns `{ "assigned": number, "unassigned": number }` (Management only)

---

## 3. Call Intelligence

### A. Personal Call Stats (Today)
**Endpoint:** `GET /personal-call-stats`  
**Description:** Call metrics for the logged-in user for the current day.

**Response Data Structure:**
```json
{
  "totalCalls": 50,
  "connectedCalls": 35,
  "notConnectedCalls": 15,
  "totalDuration": 1800,
  "incomingDuration": 600,
  "outgoingDuration": 1200,
  "incomingCalls": 10,
  "outgoingCalls": 40
}
```

### B. Team Call Stats
**Endpoint:** `GET /team-call-stats`  
**Query Parameters:** `startDate`, `endDate` (YYYY-MM-DD)  
**Description:** Aggregated call metrics for all employees in the user's management scope.

**Response Data Structure (Array of Objects):**
```json
[
  {
    "id": "67b...",
    "name": "John Sales",
    "role": "sales_executive",
    "isSelf": true,
    "stats": {
      "total": { "count": 100, "connected": 70, "missed": 20, "agentNotPicked": 10, "duration": 5000, "ivr": 15 },
      "outgoing": { "count": 80, "connected": 55, "missed": 15, "agentNotPicked": 10, "duration": 4000, "ivr": 10 },
      "incoming": { "count": 20, "connected": 15, "missed": 5, "agentNotPicked": 0, "duration": 1000, "ivr": 5 }
    }
  }
]
```

---

## ⚙️ Logic Reference

### Call Metric Definitions
- **Connected**: Call was answered. For IVR, status is `completed`. For Dialer, status is `delivered` with an `ACTIVE` state duration.
- **Missed**: Call was not answered or failed.
- **Agent Not Picked**: Specific state for IVR calls where the agent failed to answer the incoming bridge.
- **Duration**: Total time in seconds spent in the `ACTIVE` state.

### Time Range Logic
Endpoints like `/lead-status` and `/lead-sources` use a custom utility `getUtcRangeForLocalDates` which parses IST dates and creates a UTC `$gte` and `$lte` range for MongoDB queries.
