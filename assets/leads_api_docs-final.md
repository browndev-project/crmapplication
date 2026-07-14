# Leads Module API Documentation

This document provides a comprehensive reference for the Leads module APIs, ensuring high-fidelity parity between backend controller logic and frontend components (`LeadsTable2`, `LeadDialog`, `BulkUploadV2`).

> [!NOTE]
> All paths listed below are relative to the base API URL (e.g., `http://localhost:8000/api/v1`).

---


## 🔒 RBAC Permissions
All Lead endpoints require the user to be authenticated. Specific actions are guarded by granular permissions:

| Permission | Description | UI Action |
| :--- | :--- | :--- |
| `LEADS_VIEW` | View lead listing and details | Table, Drawer, Detail Page |
| `LEADS_CREATE_MANUAL` | Create a new lead manually | "Add Lead" Button |
| `LEADS_UPDATE_DETAILS` | Edit lead basic information | "Edit Lead" Button |
| `LEADS_UPDATE_STATUS` | Change lead status | "Update Status" Dialog |
| `LEADS_ASSIGN` | Reassign lead to an employee | "Assign" Button/Dialog |
| `LEADS_BULK_ASSIGN` | Reassign multiple leads | "Bulk Assign" Button |
| `LEADS_DELETE` | Delete a lead (Soft Delete) | "Delete" Button |
| `LEADS_BULK_UPLOAD` | Upload leads via CSV | Bulk Upload Wizard |
| `LEADS_BULK_UPDATE` | Update multiple leads at once | Bulk Action Toolbar |
| `LEADS_CALL` | Initiate calls (Dialer/IVR) | Dialer/Call Buttons |
| `LEADS_WHATSAPP` | Access CRM WhatsApp Chat | "CRM Chat" Button |
| `LEADS_DOWNLOAD` | Download lead list as XLSX | "Download" Button |

---

## 📦 Data Schema (Lead Object)

### **Core Fields**
| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | **Required.** Lead's full name. |
| `phoneNo` | String | **Required.** Cleaned phone number (e.g., "918888888888"). |
| `email` | String | Optional. Valid email address. |
| `dob` | Date | Optional. Date of Birth. |
| `source` | String | **Required.** Source of the lead (e.g., Website, Referral, IVR). |
| `referralName` | String | Required if `source === "Referral"`. |
| `description` | String | Internal notes about the lead. |
| `amount` | Number | Potential deal value. |
| `pipeline` | Enum | Stage: `Hot`, `Warm`, `Cold`, `Closed`, `Lost`. |
| `address` | Object | Nested address fields (`address1`, `city`, `state`, etc.). |

### **Associations**
| Field | Type | Description |
| :--- | :--- | :--- |
| `service` | ObjectId | Reference to `Service` model. |
| `project` | ObjectId | Reference to `Project` model. |
| `property` | ObjectId | Reference to `Property` model (Project-dependent). |
| `assignedTo` | ObjectId | Reference to `User` (Staff member). |
| `company` | ObjectId | Parent company/organization. |

---

## 🛠 Endpoints

### 1. List Leads
`GET /leads/system/list`

**Query Parameters:**
* `page`, `limit`: Pagination (Default: 1, 10).
* `searchQuery`: Searches `name`, `phoneNo`, `email`, `leadId`.
* `status`: CSV list of Status IDs.
* `source`: CSV list of Sources.
* `pipeline`: CSV list of Stages.
* `assignedToEmp`: CSV list of User IDs or `unassigned`.
* `service`, `project`, `team`, `group`: Association filters (CSV).
* `from`, `to`: Date range (YYYY-MM-DD).
* `sort`: Sorting criteria (e.g., `updated_desc`, `created_asc`).
* `showDuplicates`: Boolean. If `true`, returns leads identified as system duplicates.

**Response (Success 200):**
```json
{
  "statusCode": 200,
  "success": true,
  "message": "Leads fetched successfully",
  "data": {
    "leads": [...],
    "totalCount": 120,
    "pagination": {
      "page": 1,
      "limit": 10,
      "totalPages": 12
    }
  }
}
```

---

### 2. Create Lead (Manual)
`POST /leads/create/manual`

**Payload:**
```json
{
  "name": "John Doe",
  "phoneNo": "919999999999",
  "email": "john@example.com",
  "dob": "1990-05-20",
  "source": "Referral",
  "referralName": "Jane Smith",
  "service": "64f1...",
  "project": "64f2...",
  "description": "Interested in 3BHK",
  "amount": 5000000,
  "address": {
    "address1": "123 Main St",
    "city": "Mumbai",
    "state": "Maharashtra",
    "pinCode": "400001",
    "country": "India"
  },
  "status": "statusId",
  "assignedTo": "userId",
  "pipeline": "Hot"
}
```

---

### 3. Update Lead Details
`PATCH /leads/update/:id`

**Payload:** (Partial updates supported)
```json
{
  "name": "John Updated",
  "email": "john.updated@example.com",
  "phoneNo": "919999999999",
  "dob": "1990-05-20",
  "description": "Updated interest",
  "amount": 6000000,
  "address": {
    "address1": "...",
    "address2": "...",
    "city": "...",
    "state": "...",
    "pinCode": "...",
    "country": "..."
  },
  "service": "64f1...",
  "project": "64f2...",
  "property": "64f3...",
  "source": "Referral",
  "referralName": "...",
  "status": "...",
  "assignedTo": "...",
  "pipeline": "Hot"
}
```

---

### 4. Update Status
`PATCH /leads/:id/updateStatus`

**Payload:**
```json
{
  "status": "statusId",
  "comment": "Client interested in follow-up"
}
```

---

### 5. Assign Lead
`PATCH /leads/:id/assign`

**Payload:**
```json
{
  "toUser": "userId"
}
```

---

### 6. Bulk Operations

#### **A. Bulk Assign**
`POST /leads/bulk-assign`
```json
{
  "leadIds": ["id1", "id2"],
  "toUser": "userId"
}
```

#### **B. Bulk Update (Status/Stage/Project/Service)**
`POST /leads/bulk-update`
```json
{
  "leadIds": ["id1", "id2"],
  "updates": {
    "status": "statusId",
    "pipeline": "Hot",
    "service": "serviceId",
    "project": "projectId",
    "property": "propertyId"
  }
}
```

---

### 7. Advanced Bulk Upload (V2 Workflow)

#### **Step 1: Check System Duplicates**
`POST /leads/create/bulk-upload-v2/check-system-duplicates`
* **Input**: Multipart `file` (CSV) OR JSON object with lead data.
* **Returns**: List of rows identified as existing in the system.

#### **Step 2: Validate Data**
`POST /leads/create/bulk-upload-v2/validate` (for initial file)
`POST /leads/create/bulk-upload-v2/revalidate` (for corrected JSON)
* **Returns**: Detailed error report per row (missing fields, invalid formats).

#### **Step 3: Finalize Ingestion**
`POST /leads/create/bulk-upload-v2/finalize`
```json
{
  "leads": [...],
  "duplicateLeadIds": ["id1"] // IDs of leads to update instead of create
}
```

---

### 8. Call Logs
`GET /leads/call/logs`

**Query Parameters:**
* `leadId`: Required. ObjectId of the lead.
* `status`: Optional. Filter by raw call status (e.g., `completed`, `missed`, `delivered`).
* `fromDate`: Optional. Start date for filtering (YYYY-MM-DD).
* `toDate`: Optional. End date for filtering (YYYY-MM-DD).
* `page`: Optional. Current page (Default: 1).
* `limit`: Optional. Results per page (Default: 5, **Max: 5**).

**Response Schema:**
```json
{
  "statusCode": 200,
  "success": true,
  "message": "Call requests fetched successfully",
  "data": {
    "data": [
      {
        "_id": "...",
        "source": "IVR" | "APP_INITIATED" | "WEB_INITIATED",
        "callType": "INCOMING" | "OUTGOING",
        "status": "requested" | "pushed" | "delivered" | "failed" | "blocked" | "completed" | "missed" | "agent_not_picked_up",
        "duration": 45,
        "callerNumber": "...",
        "receiverNumber": "...",
        "phone": "...",
        "recordingUrl": "https://...",
        "startTime": "2024-01-01T10:00:00Z",
        "endTime": "2024-01-01T10:00:45Z",
        "ivr": { "ivrCallId": "...", "did": "..." },
        "initiatedBy": { "name": "...", "designation": "..." },
        "crmUserMapped": { "name": "..." },
        "callDetails": [
          { "state": "ACTIVE", "duration": 40, "startTime": "..." }
        ],
        "createdAt": "2024-01-01T10:00:00Z"
      }
    ],
    "pagination": {
      "total": 50,
      "page": 1,
      "limit": 5,
      "totalPages": 10,
      "hasNextPage": true,
      "hasPrevPage": false
    }
  }
}
```

---

### 9. Lead Details
`GET /leads/:id/details`
* Returns full lead object including `statusHistory`, `assignHistory`, `tasks`, and `meetings`.

---

### 10. Delete Lead
`DELETE /leads/delete/:id`
* **Behavior**: Soft delete (sets `deleted: true`).

---

### 11. Download Leads
`GET /leads/download`
* **Params**: Same as List Leads.
* **Returns**: Binary stream (XLSX).
