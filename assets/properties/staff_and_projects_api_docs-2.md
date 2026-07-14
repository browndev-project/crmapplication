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
| **Meetings**   | `meetings.view`, `meetings.create`, `meetings.update`, `meetings.delete` |
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
**Description:** Fetches projects with real-time counts for leads, properties, and visits. Supports multi-value lists, sorting, and created date range selectors.  
**Query Parameters:**
- `page` (number): Page number (default: `1`).
- `limit` (number): Page limit (default: `20`, max: `100`).
- `searchQuery` (string): Filters projects by flexible regex match on `name` or `description`.
- `status` (string): Comma-separated status codes (e.g. `pre_launch,active,ready_to_move`). Matches any status in the list.
- `projectCategory` (string): Comma-separated category list (e.g. `Residential,Commercial`). Matches any project category in the list.
- `propertyCategory` (string): Comma-separated list of unit categories (e.g. `Residential,Land`). Filters projects containing property units of these categories.
- `from` (string): Start of created-at date range filter in `YYYY-MM-DD` format.
- `to` (string): End of created-at date range filter in `YYYY-MM-DD` format.
- `sort` (string): Sort criteria. Options:
  - `created_desc` (Newest first, default)
  - `created_asc` (Oldest first)
  - `updated_desc` (Recently updated first)
  - `updated_asc` (Least recently updated first)

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
**Description:** Creates a new project with comprehensive specifications, geographical coordinates, images, and payment plan.  
**Request Payload:**
```json
{
  "name": "Green Valley Phase I",
  "description": "Premium luxury township project",
  "category": "Residential", // "Residential" | "Commercial" | "Industrial" | "Land"
  "status": "active", // "pre_launch" | "active" | "under_construction" | "ready_to_move" | "sold_out" | "on_hold" | "blocked"
  "developerName": "Green Corp",
  "budgetRange": "₹50L - ₹1.5Cr",
  "location": {
    "address1": "Sector 45",
    "address2": "Near Golf Course Road",
    "city": "Gurgaon",
    "pincode": "122003",
    "state": "Haryana",
    "country": "India",
    "coordinates": {
      "lat": 28.4595,
      "lng": 77.0266
    }
  },
  "totalArea": {
    "value": 500,
    "unit": "sqyd" // "gaj" | "sqft" | "sqyd" | "acre"
  },
  "reraId": "RERA-HR-2026-991",
  "possessionDate": "2028-12-31",
  "amenities": ["Clubhouse", "Swimming Pool", "24/7 Security", "Gymnasium"],
  "images": ["https://cdn.example.com/project-image1.jpg", "https://cdn.example.com/project-image2.jpg"],
  "videos": ["https://www.youtube.com/watch?v=sample1", "https://vimeo.com/sample2"],
  "brochureUrl": "https://cdn.example.com/project-brochure.pdf",
  "paymentPlan": "10% Booking\n40% Construction Milestones\n50% Possession"
}
```


---

### 3. Delete Project
**Endpoint:** `DELETE /api/v1/projects/:id`  
**Auth Required:** Yes (`authenticate` middleware)  
**Permissions:** `project.delete`  
**Description:** Deletes the project and cleans up all property units associated with this project ID.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {},
  "message": "Project and its properties deleted successfully"
}
```

---

### 4. Project Bulk Upload (V2)
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

### 5. Export Projects
**Endpoint:** `GET /api/v1/projects/export`  
**Description:** Downloads an Excel (.xlsx) file of all projects matching the current filters.

---

## 🏠 Properties Module (Units/Plots)

Management of individual units within a project.

### 1. List Properties
**Endpoint:** `GET /api/v1/projects/property/list`  
**Description:** Fetches individual property units within the company (scoped by company ID). Supports comprehensive multi-faceted filters, price/area ranges, sorting, and pagination.  
**Query Parameters:**
- `page` (number): Page number (default: `1`).
- `limit` (number): Page limit (default: `20`, max: `100`).
- `projectId` (string): Filters properties belonging to a specific Project ID.
- `propertyType` (string): Property unit type (`plot`, `flat`, `floor`, `room`, `farmhouse`, `villa`, `duplex`, `shop`, `house`, `green_land`).
- `status` (string): Filter by status code. Supports single status or comma-separated values (e.g. `available,token_received`).
- `category` (string): Filter by unit category (`Residential`, `Commercial`, `Industrial`, `Land`). Supports comma-separated list.
- `minPrice` (number): Filters units priced greater than or equal to this value.
- `maxPrice` (number): Filters units priced less than or equal to this value.
- `facing` (string): Filter by facing direction (e.g. `North`, `North-East`).
- `bedrooms` (number): Filter by exact number of bedrooms.
- `areaUnit` (string): Filters area value specifically under this unit (`sqft`, `sqyd`, `acre`, `gaj`).
- `minArea` (number): Filters units with area value greater than or equal to this value.
- `maxArea` (number): Filters units with area value less than or equal to this value.
- `searchQuery` (string): Filters properties by name or description regex match.
- `sort` (string): Sorting option:
  - `created_desc` (Newest first, default)
  - `created_asc` (Oldest first)
  - `updated_desc` (Recently updated first)
  - `updated_asc` (Least recently updated first)

**Response Schema:**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "properties": [
      {
        "_id": "67b9d...",
        "companyId": "67b9c...",
        "projectId": {
          "_id": "67b9c...",
          "name": "Green Valley Phase I",
          "location": { "city": "Gurgaon", "state": "Haryana" }
        },
        "name": "Flat 101",
        "description": "Corner premium unit overlooking the central park",
        "category": "Residential",
        "propertyType": "flat",
        "status": "available",
        "price": 7500000,
        "token": 100000,
        "area": { "value": 1200, "unit": "sqft" },
        "length": { "value": 40, "unit": "feet" },
        "breadth": { "value": 30, "unit": "feet" },
        "location": {
          "address1": "Sector 45",
          "city": "Gurgaon",
          "state": "Haryana"
        },
        "internalNotes": "Customer requested wood panel flooring upgrade",
        "ownerName": "Amit Sharma",
        "ownerNumber": "9810012345",
        "facing": "North-East",
        "bedrooms": 3,
        "amenities": ["Clubhouse", "Swimming Pool", "24/7 Security"],
        "images": ["https://cdn.example.com/prop1.jpg"],
        "videos": [],
        "brochureUrl": "https://cdn.example.com/prop-brochure.pdf",
        "paymentPlan": "10% Booking\n50% Possession",
        "leadsCount": 5,
        "visitsSummary": {
          "total": 3,
          "scheduled": 1,
          "completed": 2,
          "cancelled": 0
        },
        "createdBy": {
          "_id": "67b93a...",
          "name": "John Creator",
          "email": "creator@company.com"
        },
        "updatedBy": {
          "_id": "67b93a...",
          "name": "John Creator"
        },
        "createdAt": "2026-05-30T10:00:00.000Z",
        "updatedAt": "2026-05-30T10:15:00.000Z"
      }
    ],
    "totalCount": 1,
    "pagination": {
      "page": 1,
      "limit": 20,
      "hasNextPage": false
    }
  },
  "message": "Properties fetched successfully"
}
```


---

### 1.1 List Property Names (Dropdown Helper)
**Endpoint:** `GET /api/v1/projects/property/names`  
**Description:** Returns a lightweight array of available units within a specific project.

---

### 1.2 Delete Property
**Endpoint:** `DELETE /api/v1/projects/property/:id`  
**Auth Required:** Yes (`authenticate` middleware)  
**Permissions:** `property.delete`  
**Description:** Deletes a single property unit.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {},
  "message": "Property deleted successfully"
}
```

---

### 2. Create Property
**Endpoint:** `POST /api/v1/projects/property/create`  
**Description:** Creates a new individual property unit within a specified project.  
**Payload:**
```json
{
  "projectId": "67cbf7e3...", // Project ID (Required)
  "name": "Flat 101", // Property/Unit name
  "description": "Corner premium unit overlooking the central park",
  "category": "Residential", // "Residential" | "Commercial" | "Industrial" | "Land"
  "propertyType": "flat", // "plot" | "flat" | "floor" | "room" | "farmhouse" | "villa" | "duplex" | "shop" | "house" | "green_land"
  "status": "available", // "available" | "on_hold" | "token_received" | "booked" | "sold" | "blocked" | "Ready to Move"
  "price": 7500000,
  "token": 100000, // Token amount received, defaults to 0
  "area": {
    "value": 1200,
    "unit": "sqft" // "sqft" | "sqyd" | "acre" | "gaj"
  },
  "length": {
    "value": 40,
    "unit": "feet" // "feet" | "yards" | "meters"
  },
  "breadth": {
    "value": 30,
    "unit": "feet" // "feet" | "yards" | "meters"
  },
  "location": {
    "address1": "Sector 45",
    "address2": "Near Golf Course Road",
    "city": "Gurgaon",
    "pincode": "122003",
    "state": "Haryana",
    "country": "India",
    "coordinates": {
      "lat": 28.4595,
      "lng": 77.0266
    }
  },
  "internalNotes": "Customer requested wood panel flooring upgrade",
  "ownerName": "Amit Sharma",
  "ownerNumber": "9810012345",
  "facing": "North-East",
  "bedrooms": 3,
  "amenities": ["Clubhouse", "Swimming Pool", "24/7 Security", "Modular Kitchen"],
  "images": ["https://cdn.example.com/property-image1.jpg", "https://cdn.example.com/property-image2.jpg"],
  "videos": ["https://www.youtube.com/watch?v=sample1", "https://vimeo.com/sample2"],
  "brochureUrl": "https://cdn.example.com/property-brochure.pdf",
  "paymentPlan": "10% Booking\n40% Construction Milestones\n50% Possession"
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

## 🔗 Public Showcase & Sharing API Endpoints

Technical documentation for the public portfolio showcase routes and share-message utility endpoints. These enable instant sharing of projects and properties with WhatsApp-optimized structures and live interactive landing pages.

> [!IMPORTANT]
> **Mobile App Integration & Frontend URL Structure:**
> When integrating with native mobile applications (iOS/Android) or external platforms, the app can dynamically construct the shareable Web-portfolio link to redirect or load users into the interactive landing page. The frontend URLs MUST be formed using the following patterns:
> - **Public Project Portfolio Showcase URL:** `{FRONTEND_BASE_URL}/public/projects/{projectId}`
> - **Public Property Unit Showcase URL:** `{FRONTEND_BASE_URL}/public/properties/{propertyId}`
> 
> *Example Base URL:* `https://trevion.browndevs.com`  
> *Generated Project link:* `https://trevion.browndevs.com/public/projects/67b9c0258d4a...`  
> *Generated Property link:* `https://trevion.browndevs.com/public/properties/67b9d14902ac...`

### 1. Generate Project Share Message
**Endpoint:** `GET /api/v1/projects/:id/share`  
**Auth Required:** Yes (`authenticate` middleware)  
**Description:** Generates a professional, structured WhatsApp sharing message containing key project specifications, first image preview URL, list of amenities, payment plan, brochure links, and the live public showcase page URL. It also returns isolated lists of images, videos, and brochure links for customized sharing payloads.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "message": "🏢 *COMPANY PRESENTS: GREEN VALLEY* 🏢\n-------------------------------------\n\n📸 *Preview Photo:* https://cdn.example.com/img1.jpg\n\n📌 *Project Name:* Green Valley\n🏗️ *Developer:* Green Corp\n📂 *Category:* Residential\n📍 *Location:* Sector 45, Gurgaon, Haryana\n📐 *Total Area:* 500 sqyd\n⚡ *Status:* Active / Launch\n🔑 *Possession Date:* 2028-12-31\n📜 *RERA ID:* RERA-HR-2026-991\n\n🌟 *Premium Amenities:*\n• Clubhouse\n• Swimming Pool\n\n💳 *Payment Plan:*\n10% Booking\n40% Construction Milestones\n50% Possession\n\n📥 *Download Brochure:* https://cdn.example.com/brochure.pdf\n\n🌐 *View Interactive Gallery & Full Details:* https://trevion.browndevs.com/public/projects/67b9c...\n\n📞 *Contact Us for details & site visits!*",
    "brochureUrl": "https://cdn.example.com/brochure.pdf",
    "images": ["https://cdn.example.com/img1.jpg"],
    "videos": ["https://www.youtube.com/watch?v=sample1"]
  },
  "message": "Share message generated successfully"
}
```

### 2. Generate Property Unit Share Message
**Endpoint:** `GET /api/v1/projects/property/:id/share`  
**Auth Required:** Yes (`authenticate` middleware)  
**Description:** Generates a structured sharing message for an individual property unit (e.g. flat, plot) with direct dimensions, pricing, and live property showcase landing page URL.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "message": "🏡 *COMPANY PRESENTS: FLAT 101* 🏡\n-------------------------------------\n\n📸 *Preview Photo:* https://cdn.example.com/prop1.jpg\n\n📌 *Property/Unit Name:* Flat 101\n🏢 *Project Name:* Green Valley\n📂 *Category:* Residential\n🏷️ *Property Type:* flat\n📐 *Size/Area:* 1200 sqft\n📏 *Dimensions:* 40 feet x 30 feet\n💰 *Price:* ₹75,000,00\n⚡ *Status:* available\n📍 *Location:* Sector 45, Gurgaon, Haryana\n\n🌟 *Amenities:*\n• Clubhouse\n• Swimming Pool\n\n💳 *Payment Plan:*\n10% Booking\n50% Possession\n\n🌐 *View Interactive Gallery & Full Details:* https://trevion.browndevs.com/public/properties/67b9d...\n\n📞 *Contact Us for bookings & site visits!*",
    "brochureUrl": "https://cdn.example.com/prop-brochure.pdf",
    "images": ["https://cdn.example.com/prop1.jpg"],
    "videos": []
  },
  "message": "Share message generated successfully"
}
```

<!-- NOT TO BE INTWGRATED ON APP -->
### 3. Fetch Public Project Showcase Page Details
**Endpoint:** `GET /api/v1/projects/public/:id`  
**Auth Required:** No (Unauthenticated, public route)  
**Description:** Retrieves complete project showcase details along with a listing of all available property units belonging to this project. Populates creator company profile (name, logo, description) to brand the public landing page.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "project": {
      "_id": "67b9c...",
      "name": "Green Valley",
      "developerName": "Green Corp",
      "category": "Residential",
      "status": "active",
      "location": {
        "address1": "Sector 45",
        "city": "Gurgaon",
        "state": "Haryana",
        "coordinates": { "lat": 28.4595, "lng": 77.0266 }
      },
      "totalArea": { "value": 500, "unit": "sqyd" },
      "reraId": "RERA-HR-2026-991",
      "possessionDate": "2028-12-31",
      "amenities": ["Clubhouse", "Swimming Pool"],
      "images": ["https://cdn.example.com/img1.jpg"],
      "videos": ["https://www.youtube.com/watch?v=sample1"],
      "brochureUrl": "https://cdn.example.com/brochure.pdf",
      "paymentPlan": "10% Booking\n50% Possession",
      "companyId": {
        "_id": "67b9d...",
        "name": "Trevion Real Estate",
        "logo": "https://cdn.example.com/logo.png",
        "description": "Leading developer"
      }
    },
    "properties": [
      {
        "_id": "67b9d...",
        "name": "Flat 101",
        "category": "Residential",
        "propertyType": "flat",
        "status": "available",
        "area": { "value": 1200, "unit": "sqft" },
        "price": 7500000,
        "location": { "city": "Gurgaon", "state": "Haryana" },
        "images": ["https://cdn.example.com/prop1.jpg"]
      }
    ]
  },
  "message": "Public project details and property listing fetched successfully"
}
```

### 4. Fetch Public Property Showcase Page Details
**Endpoint:** `GET /api/v1/projects/public/property/:id`  
**Auth Required:** No (Unauthenticated, public route)  
**Description:** Retrieves full property unit details, fully populating its parent project context (name, location, status, amenities, etc.) and company profile to render a beautiful, conversion-oriented individual unit public portfolio page.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "_id": "67b9d...",
    "projectId": {
      "_id": "67b9c...",
      "name": "Green Valley",
      "developerName": "Green Corp",
      "location": { "city": "Gurgaon", "state": "Haryana" },
      "status": "active",
      "totalArea": { "value": 500, "unit": "sqyd" },
      "reraId": "RERA-HR-2026-991",
      "amenities": ["Clubhouse", "Swimming Pool"],
      "brochureUrl": "https://cdn.example.com/brochure.pdf",
      "paymentPlan": "10% Booking\n50% Possession"
    },
    "companyId": {
      "_id": "67b9d...",
      "name": "Trevion Real Estate",
      "logo": "https://cdn.example.com/logo.png",
      "description": "Leading developer"
    },
    "name": "Flat 101",
    "propertyType": "flat",
    "category": "Residential",
    "area": { "value": 1200, "unit": "sqft" },
    "price": 7500000,
    "status": "available",
    "amenities": ["Clubhouse", "Swimming Pool", "24/7 Security"],
    "images": ["https://cdn.example.com/prop1.jpg"],
    "videos": [],
    "brochureUrl": "https://cdn.example.com/prop-brochure.pdf",
    "paymentPlan": "10% Booking\n50% Possession"
  },
  "message": "Public property details fetched successfully"
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

---

## 📅 Meeting Module

Technical documentation for the **Meeting** module. This module tracks and manages client meetings, Google/Outlook Calendar synchronization, automated SMTP/OAuth email updates, and automated WhatsApp alert triggers.

### 1. Meeting Schema & Model structure

- **`company`**: ObjectId (Ref Company, Required)
- **`lead`**: ObjectId (Ref Lead)
- **`scheduledAt`**: Date (Required)
- **`subject`**: String (Required)
- **`description`**: String
- **`host`**: String
- **`status`**: String (`Scheduled` | `Not Started` | `Completed` | `Cancelled`) - Default: `Scheduled`
- **`sendMail`**: Boolean - Default: `false`
- **`whatsappAutomation`**: Boolean - Default: `false`
- **`employeeEmail`**: String
- **`clientEmail`**: String
- **`meetLink`**: String
- **`provider`**: String (`gmail` | `outlook` | `custom` | `none`) - Default: `none`
- **`participants`**: Array of ObjectIds (Ref User)
- **`createdBy`**: ObjectId (Ref User)

---

### 2. Create Meeting [POST]
**Endpoint:** `POST /api/v1/meetings/create`  
**Permissions:** `meetings.create`  
**Description:** Creates a meeting, optional email invite sending via `gmail`/`outlook`/`SMTP`, and schedules automated WhatsApp event automation updates.  
**Request Payload:**
```json
{
  "leadId": "67a8801b...", // Lead ID (Required)
  "subject": "Discussion on Premium Flat 101", // Required
  "scheduledAt": "2026-06-10T14:30:00Z", // Required
  "description": "Details about payment plans and amenities",
  "host": "John Executive",
  "participants": ["john_exec", "67b93a..."], // Array of User ObjectIds or uniqueIds
  "provider": "gmail", // gmail | outlook | custom | none
  "sendMail": true,
  "whatsappAutomation": true,
  "employeeMail": "john.exec@company.com",
  "clientMail": "client@example.com",
  "meetLink": "https://meet.google.com/abc-defg-hij",
  "cc": ["manager@company.com"],
  "bcc": [],
  "replyTo": "john.exec@company.com"
}
```
**Response Schema (201 Created):**
```json
{
  "success": true,
  "statusCode": 201,
  "data": {
    "meeting": {
      "_id": "67d9c0258d4a...",
      "company": "67a99...",
      "lead": "67a8801b...",
      "subject": "Discussion on Premium Flat 101",
      "description": "Details about payment plans and amenities",
      "host": "John Executive",
      "scheduledAt": "2026-06-10T14:30:00.000Z",
      "status": "Scheduled",
      "sendMail": true,
      "whatsappAutomation": true,
      "employeeEmail": "john.exec@company.com",
      "clientEmail": "client@example.com",
      "meetLink": "https://meet.google.com/abc-defg-hij",
      "provider": "gmail",
      "participants": [
        {
          "_id": "67b93a...",
          "uniqueId": "john_exec",
          "name": "John Executive",
          "email": "john.exec@company.com",
          "designation": "Sales Executive"
        }
      ],
      "createdBy": "67b93a...",
      "createdAt": "2026-05-22T21:40:00.000Z",
      "updatedAt": "2026-05-22T21:40:00.000Z"
    }
  },
  "message": "Meeting created successfully"
}
```

---

### 3. Update Meeting [PATCH]
**Endpoint:** `PATCH /api/v1/meetings/update/:id`  
**Permissions:** `meetings.update`  
**Description:** Partially updates meeting details. If `scheduledAt` shifts, it triggers a `MEETING_RESCHEDULED` WhatsApp automation. If `status` becomes `Completed` or `Cancelled`, it triggers corresponding automations and resolves active pending notifications.  
**Request Payload:**
```json
{
  "subject": "Negotiation Discussion - Premium Flat 101",
  "status": "Completed" // Scheduled | Not Started | Completed | Cancelled
}
```
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "meeting": {
      "_id": "67d9c0258d4a...",
      "subject": "Negotiation Discussion - Premium Flat 101",
      "status": "Completed",
      "participants": [],
      "createdAt": "2026-05-22T21:40:00.000Z",
      "updatedAt": "2026-05-22T21:45:00.000Z"
    }
  },
  "message": "Meeting updated successfully"
}
```

---

### 4. Delete Meeting [DELETE]
**Endpoint:** `DELETE /api/v1/meetings/delete/:id`  
**Permissions:** `meetings.delete`  
**Description:** Deletes a meeting, removes it from lead mappings, sweeps all active notifications, and triggers socket-based UI sync.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "meetingId": "67d9c0258d4a..."
  },
  "message": "Meeting deleted successfully"
}
```

---

### 5. List Company Meetings [GET]
**Endpoint:** `GET /api/v1/meetings/company`  
**Permissions:** `meetings.view` (Company-scoped view)  
**Query Parameters:**
- `page` (Number): Default 1.
- `limit` (Number): Default 20.
- `searchQuery` (String): Filter by subject line match.
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "meetings": [
      {
        "_id": "67d9c025...",
        "subject": "Discussion...",
        "scheduledAt": "2026-06-10T14:30:00.000Z",
        "status": "Scheduled",
        "participants": [],
        "lead": {
          "_id": "67a8801b...",
          "name": "Amit Sharma"
        }
      }
    ],
    "totalCount": 1,
    "pagination": {
      "page": 1,
      "limit": 20,
      "totalPages": 1
    }
  },
  "message": "Meetings fetched"
}
```

### 8. List Meetings Hierarchical Scope V2 [GET]
**Endpoint:** `GET /api/v1/meetings/system/list`  
**Permissions:** `meetings.view`  
**Description:** Returns meetings filtered automatically by the user's organizational scope (`COMPANY` | `GROUP` | `TEAM` | `SELF`).  
**Query Parameters:**
- `page` (Number): Default 1.
- `limit` (Number): Default 10.
- `searchQuery` (String): Search by subject or lead name.
- `status` (String): Filter by status (`Scheduled`, etc.)
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "meetings": [
      {
        "_id": "67d9c025...",
        "subject": "Discussion...",
        "description": "...",
        "scheduledAt": "2026-06-10T14:30:00.000Z",
        "status": "Scheduled",
        "provider": "gmail",
        "clientEmail": "client@example.com",
        "employeeEmail": "john.exec@company.com",
        "meetLink": "https://meet.google.com/abc-defg-hij",
        "lead": {
          "_id": "67a8801b...",
          "name": "Amit Sharma"
        },
        "createdAt": "2026-05-22T21:40:00.000Z",
        "updatedAt": "2026-05-22T21:40:00.000Z"
      }
    ],
    "totalCount": 1,
    "pagination": {
      "page": 1,
      "limit": 10,
      "totalPages": 1,
      "hasNextPage": false,
      "hasPrevPage": false
    }
  },
  "message": "Meetings fetched successfully"
}
```

---

### 9. Get Meeting Summary Counts [GET]
**Endpoint:** `GET /api/v1/meetings/getMeetingSummaryCounts`  
**Permissions:** `meetings.view`  
**Description:** Retrieves summary totals of meetings across different statuses, automatically resolved by the user's active hierarchy scope.  
**Response Schema (200 OK):**
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "total": 5,
    "Scheduled": 3,
    "Not Started": 1,
    "Completed": 1,
    "Cancelled": 0
  },
  "message": "Meeting summary fetched successfully"
}

```
