# Lead Documents & Document Forms API

This module manages lead-related document metadata and the system for requesting documents from clients via public forms.

## Base Paths
- **Lead Documents**: `/api/v1/lead-documents`
- **Document Forms**: `/api/v1/document-forms`

---

## 🔐 Permissions & Access Control

### Modular Access
Access to this entire functionality is governed by the module key:
- `modules.leadDocs`: Must be enabled for the company.

### User-Level Permissions
| Permission Key | Action |
| :--- | :--- |
| `leads.docs.view` | View lead documents and module dashboard |
| `leads.docs.upload` | Upload new documents to a lead |
| `leads.docs.delete` | Delete lead documents |
| `leads.docs.download` | Download document files |
| `leads.docs.request` | Access the "Request Documents" dialog |
| `leads.docs.form.create`| Create new document request templates |
| `leads.docs.form.edit` | Edit document request templates |
| `leads.docs.form.delete` | Delete (deactivate) document request templates |

---

## 📊 Enums & Constants

### Uploaded By (`uploadedBy`)
Specifies the origin of the document:
- `Staff`: Uploaded by a CRM user via the dashboard.
- `Client`: Uploaded by the lead/client via a public request form.

### Document Status
- `isLocked`: Boolean. If `true`, specific actions (like delete) might be restricted by the UI or backend logic. Defaults to `true`.

---

## 1. Lead Documents

### A. Upload Document Metadata
`POST /lead-documents/upload`
Saves metadata after the file has been successfully uploaded to Cloudflare R2.

**Payload:**
```json
{
  "leadId": "64f1...",
  "label": "Aadhaar Card",
  "fileType": "image/jpeg",
  "size": 524288,
  "r2Key": "leadDocs/64f1.../aadhaar_card.jpg"
}
```

**Logic:**
- Validates that the lead belongs to the same company as the user.
- Checks company storage limits (`company.storage.used + size <= company.storage.limit`).
- Automatically generates a `fieldKey` (e.g., `aadhaar_card`, `aadhaar_card2`).
- Increases `company.storage.used`.

---

### B. List Lead Documents
`GET /lead-documents/list/:leadId`

**Response:**
```json
{
  "statusCode": 200,
  "success": true,
  "data": {
    "documents": [
      {
        "_id": "...",
        "label": "Aadhaar Card",
        "fieldKey": "aadhaar_card",
        "fileType": "image/jpeg",
        "size": 524288,
        "r2Key": "...",
        "isLocked": true,
        "uploadedBy": "Staff",
        "uploader": { "name": "Admin", "systemRole": "admin" },
        "createdAt": "2024-01-01T10:00:00Z"
      }
    ]
  }
}
```

---

### C. Delete Document
`DELETE /lead-documents/:id`

**Behavior:**
- Deletes the file from Cloudflare R2.
- Deletes metadata from the database.
- Decreases `company.storage.used`.
- Removes the document reference from the `Lead` model.

---

### D. Toggle Lock
`PATCH /lead-documents/toggle-lock/:id`
Locks or unlocks a document to prevent/allow actions.

**Response:**
```json
{
  "statusCode": 200,
  "data": { "isLocked": false },
  "message": "Document unlocked successfully"
}
```

---

### E. Global Document List (Module View)
`GET /lead-documents/all`
Used for the dashboard-wide documents management page.

**Query Parameters:**
- `search`: Search by document label, lead name, or fieldKey.
- `fileType`: Filter by MIME type (e.g., `image`, `application/pdf`).
- `uploadedBy`: `Staff` or `Client`.
- `isLocked`: `true` or `false`.
- `from`/`to`: Date range (YYYY-MM-DD).
- `page`/`limit`: Pagination (Default: 1/10).

---

## 2. Document Forms (Templates)

### A. List Forms
`GET /document-forms/list`
Lists all active form templates for the company.

---

### B. Create Form Template
`POST /document-forms/create`

**Payload:**
```json
{
  "name": "Standard Onboarding",
  "fields": [
    { "label": "Aadhaar Card", "required": true },
    { "label": "Pan Card", "required": true }
  ]
}
```

---

### C. Update Form Template
`PUT /document-forms/:id`
Updates the name or fields of an existing template.

---

### D. Delete Form Template
`DELETE /document-forms/:id`
**Behavior**: Soft delete (sets `isActive: false`).

---

## 3. Public / Client Endpoints

### A. Get Public Form Details
`GET /document-forms/public/:formId`
Used by the public form page to fetch field requirements.

---

### B. Public Document Submission
`POST /document-forms/submit`
Used by clients to submit multiple documents at once.

**Payload:**
```json
{
  "leadId": "64f1...",
  "documents": [
    {
      "label": "Aadhaar Card",
      "fileType": "image/jpeg",
      "size": 524288,
      "r2Key": "..."
    }
  ]
}
```
**Logic**: Sets `uploadedBy: "Client"`.

---

### C. Get Public Lead Documents
`GET /lead-documents/public/:leadId`
Fetches document list for public viewing (e.g., client portal).
