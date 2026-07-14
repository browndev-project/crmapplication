This document provides a comprehensive technical reference for the APIs used in the **Staff**, **Projects**, **Inventory**, **Visits**, and **Location** modules of the Trevion CRM.

---

## 🔐 Permissions & Module Constants

These constants define granular access control across the system. 100% technical match with frontend `constants.js`.

### 1. Permissions Registry (`PERMISSIONS`)
Used in staff creation and permission check APIs.

| Feature Area | Permission Key |
| :--- | :--- |
| **Leads** | `leads.view`, `leads.delete`, `leads.download`, `leads.createManual`, `leads.bulkUpload`, `leads.assign`, `leads.call`, `leads.whatsapp`, `leads.mail`, `leads.updateDetails`, `leads.updateStatus`, `leads.updatePipeline`, `leads.bulkUpdate` |
| **Documents** | `leads.docs.view`, `leads.docs.upload`, `leads.docs.delete`, `leads.docs.download`, `leads.docs.request`, `leads.docs.form.create`, `leads.docs.form.edit`, `leads.docs.form.delete` |
| **Tasks** | `tasks.view`, `tasks.create`, `tasks.update`, `tasks.delete` |
| **Visits** | `visits.view`, `visits.create`, `visits.update`, `visits.updateStatus`, `visits.delete` |
| **Inventory** | `project.view`, `project.create`, `project.update`, `project.updateStatus`, `project.delete`, `property.view`, `property.create`, `property.update`, `property.updateStatus`, `property.delete` |
| **Staff Mgmt** | `salesExecutives.view`, `salesExecutives.create`, `salesExecutives.update`, `salesExecutives.delete` |
| **Integrations**| `integrations.ivr.call` |

### 2. Module Access Keys (`MODULES`)
Used to enable/disable entire modules for a company.

- `modules.lead`, `modules.service`, `modules.product`, `modules.property`, `modules.visit`, `modules.meeting`, `modules.task`, `modules.asset`, `modules.attendance`, `modules.invoice`, `modules.itinerary`, `modules.whatsapp`, `modules.marketing`, `modules.integration.ivr`.

### 3. Default Role Permissions
Assigned automatically if no custom array is provided.

- **Sales Manager**: `["users.create.executive", "users.update.team", "leads.assign", "leads.read.team", "users.update.salesManager"]` + Base Employee Perms.
- **Team Leader**: `["leads.read.team", "leads.assign", "tasks.create", "visits.create"]` (Backend resolves team scope).
- **Sales Executive**: `["leads.create", "leads.read.own", "leads.update.own"]`.

---

## 👥 Staff Module (User & Team Management)

Manage company administrators, sales managers, team leaders, and sales executives.

### 1. List Users by System Role (V2)
**Endpoint:** `GET /api/v1/users/system/list`  
**Description:** High-fidelity listing for role-based filtering. Moves current user to top.  
**Query Parameters:**
- `systemRole` (string): `sales_manager`, `team_leader`, `sales_executive`
- `status` (boolean): `true` / `false`
- `excludeInTeam` (boolean): `true` to list unassigned users.

**Response Schema:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "users": [
      {
        "_id": "67b9a...",
        "uniqueId": "jdoe_123",
        "name": "John Doe",
        "email": "john@example.com",
        "phoneNo": "9876543210",
        "systemRole": "sales_manager",
        "designation": "Sales Manager",
        "permissions": ["leads.view", "tasks.create"],
        "isSelf": true,
        "group": { "_id": "...", "name": "North Zone" },
        "team": { "_id": "...", "name": "Team Alpha" }
      }
    ],
    "totalCount": 1,
    "pagination": { "page": 1, "limit": 20, "hasNextPage": false }
  },
  "message": "Users fetched successfully"
}
```

### 2. Create Staff Member
**Endpoints:**
- `POST /api/v1/users/company/createSalesManager`
- `POST /api/v1/users/company/createTeamLeader`
- `POST /api/v1/users/company/createSalesExecutive`

**Request Payload:**
```json
{
  "uniqueId": "jane_smith",
  "name": "Jane Smith",
  "email": "jane@example.com",
  "phoneNo": "9998887770",
  "password": "SecurePassword123",
  "permissions": ["leads.view", "leads.assign", "tasks.create"],
  "team": "67b9a...", // Only for Team Leader/Executive
  "group": "67b9b..." // Only for Sales Manager
}
```

### 3. Update Staff Member (Partial)
**Endpoints:** `PATCH /api/v1/users/company/update[Role]/:id`  
**Payload:** Supports partial updates. If password is provided, it is automatically re-hashed.
```json
{
  "name": "Jane Updated",
  "permissions": ["leads.view"],
  "active": false
}
```

### 4. Role & Permissions Matrix
**Endpoint:** `GET /api/v1/users/:id/getPermissions`  
**Response:** Returns the matrix used to render the UI for the current or target user.
```json
{
  "success": true,
  "data": {
    "user": {
      "role": "employee",
      "designation": "Sales Manager",
      "permissions": ["leads.view", "..."],
      "modules": ["modules.lead", "modules.visit"],
      "ivrAgent": { "agentId": "101", "phone": "..." }
    }
  }
}
```

### 5. Organizational Hierarchy
**Endpoint:** `GET /api/v1/users/hierarchy/system`  
**Description:** Returns the complete tree structure of the company.

---

### 5. Team Management
- **List Teams:** `GET /api/v1/team/list`
- **Create Team:** `POST /api/v1/team/create` (Payload: `{ "name": "Team Alpha", "manager": "userId" }`)
- **Update Team:** `PATCH /api/v1/team/update/:id` (Payload: `{ "name": "New Name", "active": true }`)
- **Assign Leader:** `POST /api/v1/team/:teamId/assign-leader` (Payload: `{ "leaderIds": ["id1"] }`)
- **Add Executives:** `POST /api/v1/team/:teamId/add-executives` (Payload: `{ "executiveIds": ["id1", "id2"] }`)
- **Remove Executives:** `POST /api/v1/team/:teamId/remove-executives` (Payload: `{ "executiveIds": ["id1"] }`)

---

### 6. Group Management
- **List Groups:** `GET /api/v1/group/list`
- **Create Group:** `POST /api/v1/group/create` (Payload: `{ "name": "North Zone" }`)
- **Update Group:** `PATCH /api/v1/group/update/:id` (Payload: `{ "name": "New Name" }`)
- **Add Teams:** `POST /api/v1/group/:groupId/add-teams` (Payload: `{ "teamIds": ["id1"] }`)
- **Remove Teams:** `POST /api/v1/group/:groupId/remove-teams` (Payload: `{ "teamIds": ["id1"] }`)
- **Assign Manager:** `POST /api/v1/group/:groupId/assign-manager` (Payload: `{ "managerIds": ["id1"] }`)

---

## 🏗️ Inventory Module (Projects & Properties)

Manage real estate projects and their constituent property units (flats, plots, etc.).

### 1. List Projects (with Aggregated Stats)
**Endpoint:** `GET /api/v1/projects/list`  
**Description:** Fetches projects with real-time counts for leads, properties, and visits.  
**Response Schema:**
```json
{
  "success": true,
  "data": {
    "projects": [
      {
        "_id": "67b9c...",
        "name": "Green Valley Phase I",
        "developerName": "Green Corp",
        "category": "Residential",
        "status": "active",
        "leadsCount": 150,
        "propertiesCount": 45,
        "visitsSummary": {
          "total": 25,
          "scheduled": 10,
          "completed": 12,
          "cancelled": 3
        },
        "location": { "city": "Gurgaon", "state": "Haryana" },
        "totalArea": { "value": 500, "unit": "sqyd" }
      }
    ],
    "totalCount": 1,
    "pagination": { "page": 1, "limit": 20, "hasNextPage": false }
  }
}
```

### 2. Create Project
**Endpoint:** `POST /api/v1/projects/create`  
```json
{
  "name": "Green Valley",
  "developerName": "Green Corp",
  "category": "Residential",
  "status": "active",
  "location": {
    "address1": "Sector 45",
    "city": "Gurgaon",
    "state": "Haryana"
  },
  "totalArea": { "value": 500, "unit": "sqyd" }
}
```

---

### 3. Project Bulk Upload (V2)
**Step 1: Validate**  
**Endpoint:** `POST /api/v1/projects/bulk-upload-v2/validate` (Multipart/form-data with `file`)  
**Description:** Validates CSV rows for schema errors and duplicates.

**Step 2: Finalize**  
**Endpoint:** `POST /api/v1/projects/bulk-upload-v2/finalize` (JSON)  
**Payload:**
```json
{
  "projects": [
    {
      "name": "Green Valley",
      "developerName": "Green Corp",
      "category": "Residential",
      "status": "active",
      "location": { "city": "Gurgaon", "state": "Haryana" },
      "totalArea": { "value": 500, "unit": "sqyd" }
    }
  ]
}
```

---

### 4. Export Projects
**Endpoint:** `GET /api/v1/projects/export`  
**Description:** Downloads an Excel (.xlsx) file of all projects matching the current filters.

---

## 🏠 Properties Module (Units/Plots)

Management of individual units within a project.

### 1. List Properties
**Endpoint:** `GET /api/v1/projects/property/list`  
**Query Parameters:** `projectId` (Required), `status`, `propertyType`, `searchQuery`

---

### 1.1 List Property Names (Dropdown Helper)
**Endpoint:** `GET /api/v1/projects/property/names`  
**Description:** Returns a lightweight array of available units within a specific project.

---

### 2. Create Property
**Endpoint:** `POST /api/v1/projects/property/create`  
**Payload:**
```json
{
  "projectId": "67c...",
  "name": "Flat 101",
  "propertyType": "flat",
  "category": "Residential",
  "area": { "value": 1200, "unit": "sqft" },
  "price": 7500000,
  "status": "available"
}
```

---

### 3. Bulk Update Properties
**Endpoint:** `PATCH /api/v1/projects/property/bulk-update`  
**Payload:**
```json
{
  "propertyIds": ["id1", "id2"],
  "status": "booked",
  "category": "Residential"
}
```

---

### 4. Property Bulk Upload (V2)
**Step 1: Validate**  
**Endpoint:** `POST /api/v1/projects/properties/bulk-upload-v2/validate`  
**Query Params:** `projectId`  

**Step 2: Finalize**  
**Endpoint:** `POST /api/v1/projects/properties/bulk-upload-v2/finalize`  
**Payload:**
```json
{
  "projectId": "67c...",
  "properties": [
    {
      "name": "Flat 101",
      "propertyType": "flat",
      "area": { "value": 1200, "unit": "sqft" },
      "price": 7500000,
      "status": "available"
    }
  ]
}
```

---

## 📈 Lead Module

Core CRM functionality for managing customer inquiries and sales pipeline.

### 1. Create Lead
**Endpoint:** `POST /api/v1/leads/create`  
**Description:** Creates a new lead with project/property linking.  
**Request Payload:**
```json
{
  "name": "Amit Sharma",
  "phoneNo": "9810012345",
  "email": "amit@example.com",
  "source": "Website",
  "project": "67b9c...",
  "property": "67b9d...",
  "status": "67b9e...",
  "assignedTo": "67b9f...",
  "address": {
    "city": "Gurgaon",
    "state": "Haryana",
    "pinCode": "122001"
  },
  "amount": 7500000
}
```

**Response Schema:**
```json
{
  "success": true,
  "statusCode": 201,
  "data": {
    "lead": {
      "_id": "67b9g...",
      "name": "Amit Sharma",
      "status": { "_id": "...", "name": "Hot", "color": "#FF0000" },
      "assignedTo": { "name": "John Sales" }
    }
  },
  "message": "Lead created successfully"
}
```

### 2. List Leads (Scoped)
**Endpoint:** `GET /api/v1/leads/list`  
**Description:** Fetches leads based on the requester's hierarchical scope (My Leads vs Team Leads).  
**Query Parameters:**
- `status` (string): Filter by lead status ID.
- `searchQuery` (string): Search by name, phone, or email.
- `project` (string): Filter by project ID.

---

## 📅 Site Visit Module

Tracking physical site visits by potential customers.

### 1. Create Site Visit
**Endpoint:** `POST /api/v1/visits/create`  
**Payload:**
```json
{
  "lead": "67b9g...",
  "project": "67b9c...",
  "property": "67b9d...",
  "visitDate": "2024-03-25T14:00:00Z",
  "status": "Scheduled",
  "assignedTo": "67b9f...",
  "notes": "Interested in corner plot"
}
```

### 2. Get Visit Summary
**Endpoint:** `GET /api/v1/visits/summary/counts`  
**Description:** Returns dashboard counts for site visits.  
**Response:** `{ "success": true, "data": { "scheduled": 5, "completed": 10, "cancelled": 2 } }`

---

## 📍 Location Tracking Module

Real-time field staff tracking and geo-fencing.

### 1. Update Staff Location (Webhook)
**Endpoint:** `POST /api/v1/location/webhook`  
**Description:** Ingests GPS data from mobile app.  
**Payload:**
```json
{
  "userId": "67b9f...",
  "coordinates": { "lat": 28.4595, "lng": 77.0266 },
  "timestamp": "2024-03-22T10:30:00Z",
  "batteryLevel": 85,
  "isMocked": false
}
```

### 2. Find Nearby Staff
**Endpoint:** `GET /api/v1/location/nearby`  
**Query Parameters:**
- `lat`, `lng` (number): Center point for discovery.
- `radius` (number): Radius in meters (default: 5000).
- `project` (string): Filter staff assigned to a specific project.

**Response:**
```json
{
  "success": true,
  "data": {
    "staff": [
      {
        "userId": "67b9f...",
        "name": "John Field",
        "distance": 1.2,
        "lastSeen": "2024-03-22T10:30:00Z"
      }
    ]
  }
}
```
