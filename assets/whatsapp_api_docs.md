?# 💬 WhatsApp Module API Documentation

This document provides a technical reference for the **WhatsApp integration**, covering chat conversations, message handling, and template management via the Meta Graph API.

---

## 🔐 Permissions & Module Access

### 1. Backend Role-Based Access Scoping
The backend endpoints do not enforce custom action-based permission strings (e.g., no `whatsapp.view` or `whatsapp.send` checking in middleware). Instead, access is guarded by user authentication (`authenticate` middleware) and filtered at the query layer via system-wide **Role-Based Scope Scoping**:
- **`company_admin`**: Full access. Can view and modify all conversations, campaign settings, automations, and templates across the entire company.
- **`sales_manager` / `team_leader`**: Scoped access. Can view and interact only with conversations for leads mapped to their managed teams.
- **`sales_executive`**: Strict assignment access. Can only access conversations that have leads explicitly assigned to them.

---

### 2. Frontend Module & Permission Rules (Gating)
To access any WhatsApp page or automation sub-feature, the frontend enforces strict gating. **ALL** of the specified module configurations must be active, and the designated user permission string must be assigned. If any condition is missing, access is blocked.

#### 💬 WhatsApp Chat
*   **Path:** `/dashboard/whatsapp/chats`
*   **Required Active Modules:**
    *   `"modules.integration"`
    *   `"modules.whatsapp"`
*   **Required Permissions:** None

#### 📄 WhatsApp Templates
*   **Path:** `/dashboard/whatsapp/templates`
*   **Required Active Modules:**
    *   `"modules.whatsapp"`
    *   `"modules.integration"`
    *   `"modules.integration.whatsapp"`
*   **Required Permissions:** None

#### 📣 WhatsApp Campaigns (Marketing)
*   **Path:** `/dashboard/whatsapp/campaigns`
*   **Required Active Modules:**
    *   `"modules.whatsapp"`
    *   `"modules.integration"`
    *   `"modules.integration.whatsapp"`
*   **Required Permissions:** None

#### 🤖 Base Automation Tab
*   **Path:** `/dashboard/whatsapp/automation`
*   **Required Active Modules:**
    *   `"modules.integration"`
    *   `"modules.integration.whatsapp"`
    *   `"modules.whatsapp"`
*   **Required Permissions:** None

#### 📥 Automation Sub-Tab: Incoming Leads
*   **Path:** `/dashboard/whatsapp/automation/incoming-leads`
*   **Required Active Modules:**
    *   `"modules.integration"`
    *   `"modules.integration.whatsapp"`
    *   `"modules.lead"`
    *   `"modules.whatsapp"`
*   **Required Permissions:**
    *   `"leads.view"`

#### 🔄 Automation Sub-Tab: Status
*   **Path:** `/dashboard/whatsapp/automation/status`
*   **Required Active Modules:**
    *   `"modules.integration"`
    *   `"modules.integration.whatsapp"`
    *   `"modules.lead"`
    *   `"modules.whatsapp"`
*   **Required Permissions:**
    *   `"leads.view"`

#### 👥 Automation Sub-Tab: Visits
*   **Path:** `/dashboard/whatsapp/automation/visits`
*   **Required Active Modules:**
    *   `"modules.integration"`
    *   `"modules.integration.whatsapp"`
    *   `"modules.visit"`
    *   `"modules.whatsapp"`
*   **Required Permissions:**
    *   `"visits.view"`

#### Automation Tab Configuration Object (`AutomationNav.jsx`):
```javascript
const links = [
    {
        label: "Incoming Leads",
        path: "/dashboard/whatsapp/automation/incoming-leads",
        icon: <CallReceivedIcon fontSize="small" />,
        module: MODULES.LEADS,
        permission: PERMISSIONS.LEADS_VIEW
    },
    {
        label: "Visits",
        path: "/dashboard/whatsapp/automation/visits",
        icon: <GroupIcon fontSize="small" />,
        module: MODULES.VISITS,
        permission: PERMISSIONS.VISITS_VIEW
    },
    {
        label: "Status",
        path: "/dashboard/whatsapp/automation/status",
        icon: <AutorenewIcon fontSize="small" />,
        module: MODULES.LEADS,
        permission: PERMISSIONS.LEADS_VIEW
    }
];
```

---

### 3. Constants Mappings (`lib/constants.js`)
The frontend constants evaluate to the following exact string values:

#### Module Keys (`MODULES`)
*   `MODULES.INTEGRATION` ➔ `"modules.integration"`
*   `MODULES.WHATSAPP` ➔ `"modules.whatsapp"`
*   `MODULES.INTEGRATION_WHATSAPP` ➔ `"modules.integration.whatsapp"`
*   `MODULES.LEADS` ➔ `"modules.lead"`
*   `MODULES.VISITS` ➔ `"modules.visit"`

#### Permission Keys (`PERMISSIONS`)
*   `PERMISSIONS.LEADS_VIEW` ➔ `"leads.view"`
*   `PERMISSIONS.VISITS_VIEW` ➔ `"visits.view"`

---

## 📱 Core Concepts & Enums

### Message Directions
- **`INBOUND`**: Messages received from the lead.
- **`OUTBOUND`**: Messages sent from the CRM.

### Message Types
- `text`, `template`, `image`, `video`, `audio`, `document`, `interactive`, `location`, `contacts`, `sticker`, `button`, `unknown`.

### Message Statuses
- `pending`, `sent`, `delivered`, `read`, `failed`.

---

## 💬 Conversations & Messages (Read)

### 1. Get Conversations [GET]
**Endpoint:** `GET /api/v1/whatsapp-read/conversations`  
**Description:** Fetches all conversations scoped to the user's role (Company Admin sees all, Sales sees assigned leads).  
**Response Schema:**
```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "id": "67b...",
        "waId": "919876543210",
        "phone": "919876543210",
        "lastMessage": "I am interested in...",
        "lastMessageAt": "2024-03-22T10:00:00Z",
        "unreadCount": 2,
        "leads": [
          {
            "id": "67a...",
            "name": "Jane Doe",
            "phoneNo": "9876543210"
          }
        ]
      }
    ]
  }
}
```

### 2. Get Messages in Conversation [GET]
**Endpoint:** `GET /api/v1/whatsapp-read/messages/:conversationId`  
**Description:** Fetches all messages for a specific conversation, sorted chronologically.  
**Response Schema:**
```json
{
  "success": true,
  "data": {
    "messages": [
      {
        "id": "67c...",
        "direction": "INBOUND",
        "type": "text",
        "status": "read",
        "timestamp": "2024-03-22T10:00:00Z",
        "body": "Can you send the brochure?",
        "sentBy": null
      },
      {
        "id": "67d...",
        "direction": "OUTBOUND",
        "type": "template",
        "status": "delivered",
        "timestamp": "2024-03-22T10:05:00Z",
        "body": "Here is our brochure...",
        "sentBy": {
          "id": "67f...",
          "name": "Admin User",
          "systemRole": "admin"
        },
        "templateMeta": {
          "name": "send_brochure",
          "language": "en",
          "category": "MARKETING",
          "components": [...]
        }
      }
    ]
  }
}
```

---

## 📨 Sending Messages (Write)

### 1. Send Message [POST]
**Endpoint:** `POST /api/v1/whatsapp-message/send`  
**Description:** Sends a text or template message.

#### Request: Text Message
```json
{
  "waId": "919876543210",
  "conversationId": "67b...",
  "type": "text",
  "message": "Hello Jane, checking in regarding your recent inquiry."
}
```

#### Request: Template Message
```json
{
  "waId": "919876543210",
  "conversationId": "67b...",
  "type": "template",
  "template": {
    "name": "welcome_message",
    "language": "en",
    "components": [
      {
        "type": "header",
        "parameters": [
          {
            "type": "image",
            "image": {
              "link": "https://r2.cloudflare.com/banner.jpg"
            }
          }
        ]
      },
      {
        "type": "body",
        "parameters": [
          { "type": "text", "text": "Jane" }
        ]
      },
      {
        "type": "button",
        "sub_type": "url",
        "index": "0",
        "parameters": [
          { "type": "text", "text": "promo_code_123" }
        ]
      }
    ]
  },
  "__previewText": "Hi Jane, welcome to Trevion!",
  "__fullTemplate": { ... } // Optional: Raw template metadata for UI rendering
}
```

### 2. Variable Resolution & Placeholders
Template text components often contain placeholders (e.g., `Hi {{1}}, your order {{2}} is ready`). 
To populate these, you pass an array of parameters. The frontend `MessageBubble.jsx` recursively parses `{{n}}` placeholders and replaces them using the ordered `parameters` array from the `BODY` component block.

### 3. Supported Media Types in Templates
- **Images**: `image` component parameter with `link` or `id`.
- **Videos**: `video` component parameter with `link` or `id`.
- **Documents**: `document` component parameter with `link` or `id` and optional `filename`.

*Note: The frontend `MessageBubble` component natively handles proxying media URLs and displaying them in a lightbox if they are sent correctly via the payload structure above.*

### 4. Message Automated Sources (`source` field)
When templates are sent via automated triggers (not manually by a user), the backend marks them with a `source`. The UI (`MessageBubble.jsx`) renders these with specific badge labels.
| Backend Source Key | UI Display Badge |
| :--- | :--- |
| `manual` | Manual |
| `lead_automation` | Automation |
| `status_trigger` | Status Trigger |
| `visit_created` | Visit Created |
| `visit_rescheduled` | Visit Rescheduled |
| `visit_cancelled` | Visit Cancelled |
| `visit_completed` | Visit Completed |
| `visit_reminder` | Visit Reminder |

---

## 📣 Marketing & Bulk Campaigns

The **Marketing** tab of the WhatsApp module manages large-scale, automated broadcasts using templates. It is backed by a batch execution pipeline, automatic rate limiting based on daily Meta limits, and live webhook-driven delivery tracing.

### 1. Create Bulk Campaign [POST]
**Endpoint:** `POST /api/v1/whatsapp/campaigns`  
**Content-Type:** `multipart/form-data`  
**Description:** Generates a new bulk marketing run. Supports uploading a recipient Excel sheet or selecting existing leads.
*   **Request Fields:**
    *   `name` (String, Required): e.g. `"May Premium Offer"`
    *   `templateName` (String, Required): e.g. `"exclusive_promo"`
    *   `templateLanguage` (String, Required): e.g. `"en_US"`
    *   `templateComponents` (JSON String/Array, Optional): Full structure of template blocks.
    *   `variableMappings` (JSON String/Array, Required): List of variable definitions matching template placeholders:
        ```json
        [
          { "key": "1", "source": "lead_name" },
          { "key": "2", "source": "custom", "customValue": "EXTRA15" }
        ]
        ```
    *   `recipientSource` (String, Required): `"excel"` or `"leads"`
    *   `scheduledAt` (ISO Date String, Optional): Schedules future batch dispatch.
    *   `file` (Binary file, Required if `recipientSource` is `"excel"`): Spreadsheet with a `"Phone"` header.
    *   `leadIds` (JSON String/Array, Required if `recipientSource` is `"leads"`): Array of Lead MongoDB `_id` values.
*   **Response Schema (201 Created):**
    ```json
    {
      "success": true,
      "message": "Campaign created and sending started",
      "data": {
        "campaign": {
          "_id": "67f...",
          "name": "May Premium Offer",
          "status": "processing",
          "totalRecipients": 250,
          "scheduledAt": null
        }
      }
    }
    ```

---

### 2. List Bulk Campaigns [GET]
**Endpoint:** `GET /api/v1/whatsapp/campaigns`  
**Query Parameters:** `page`, `limit`  
**Description:** Paginated list of all campaigns sent or scheduled by the company. Includes delivery rates.
*   **Response Schema:**
    ```json
    {
      "success": true,
      "data": {
        "campaigns": [
          {
            "_id": "67f...",
            "name": "May Premium Offer",
            "status": "completed",
            "totalRecipients": 250,
            "sentCount": 250,
            "deliveredCount": 248,
            "readCount": 182,
            "failedCount": 2,
            "scheduledAt": null,
            "createdAt": "2026-05-17T20:00:00.000Z"
          }
        ],
        "total": 12,
        "page": 1,
        "limit": 20
      }
    }
    ```

---

### 3. Get Single Campaign [GET]
**Endpoint:** `GET /api/v1/whatsapp/campaigns/:id`  
**Description:** Returns full execution progress and settings of a single broadcast run.

---

### 4. Fetch Campaign Recipients [GET]
**Endpoint:** `GET /api/v1/whatsapp/campaigns/:id/recipients`  
**Query Parameters:** `page`, `limit`, `status` (optional filter: `pending` | `sent` | `delivered` | `read` | `failed`)  
**Description:** Fetches detailed audit records for each recipient in the run, including exact delivery statuses mapped from Meta Webhooks.

---

### 5. Trigger or Resume Dispatch [POST]
**Endpoint:** `POST /api/v1/whatsapp/campaigns/:id/send`  
**Description:** Manually triggers or resumes execution of a `draft`, `scheduled`, or `paused` campaign run.

---

### 6. Quick Status Update [PATCH]
**Endpoint:** `PATCH /api/v1/whatsapp/campaigns/:id/status`  
**Request Payload:**
```json
{
  "status": "paused" // draft, scheduled, paused, completed
}
```

---

### 7. Delete Campaign Run [DELETE]
**Endpoint:** `DELETE /api/v1/whatsapp/campaigns/:id`  
**Description:** Deletes a broadcast run and sweeps all associated recipient documents from the DB. Fails if status is currently `processing`.

---

### 8. Fetch Daily Messaging Limit [GET]
**Endpoint:** `GET /api/v1/whatsapp/campaigns/settings/messaging-limit`  
**Description:** Returns the active daily Meta tier sending capacity, current consumption, remaining capacity, and reset window.
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "data": {
        "messagingLimit": 1000,
        "messagesToday": 150,
        "remaining": 850,
        "resetAt": "2026-05-18T00:00:00.000Z"
      }
    }
    ```

---

### 9. Update Daily messaging Limit [PATCH]
**Endpoint:** `PATCH /api/v1/whatsapp/campaigns/settings/messaging-limit`  
**Description:** Updates the company's daily cap limit manually to align with Meta tier upgrades (e.g., upgrading from 1K to 10K messages per day).
*   **Request Payload:**
    ```json
    {
      "messagingLimit": 10000
    }
    ```

---

## 🤖 Automation Rules & Event Triggers

The **Automation** module is powered by separate backend event engines: **Incoming Leads Automations** (handles automated welcome responders for lead streams) and **Event Automations** (split into **Status Automations** for lead stage changes and **Visit Automations** for calendar triggers).

---

### 1. Incoming Leads Automations (`/api/v1/whatsapp-automations`)

Utilized by `/dashboard/whatsapp/automation/incoming-leads`. Sends immediate template dispatches to newly captured leads based on their ingestion source (e.g. Website leads, Meta Lead Ads).

> [!IMPORTANT]
> **Form Overrides Constraint:** The `formOverrides` configuration is strictly available and processed **ONLY** when `leadSources` contains `"Meta Page Form"` (representing lead streams coming from Meta Lead Ads). For all other lead sources, the `formOverrides` array is ignored.

#### A. Fetch Automations [GET]
*   **Endpoint:** `GET /api/v1/whatsapp-automations`
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automations fetched successfully",
      "data": {
        "automations": [
          {
            "_id": "67a12b...",
            "name": "Meta Lead Form Welcome Rule",
            "leadSources": ["Meta Page Form"],
            "template": {
              "name": "welcome_generic_lead",
              "language": "en",
              "components": []
            },
            "variableMappings": [
              { "key": "1", "source": "lead.name" }
            ],
            "formOverrides": [
              {
                "formId": "4892019384820",
                "isActive": true,
                "template": {
                  "name": "meta_campaign_special_offer",
                  "language": "en",
                  "components": []
                },
                "variableMappings": [
                  { "key": "1", "source": "lead.name" },
                  { "key": "2", "source": "custom", "customValue": "SPRING20" }
                ]
              }
            ],
            "isActive": true,
            "company": "67a99...",
            "createdBy": "67c99..."
          }
        ]
      }
    }
    ```

#### B. Create Automation [POST]
*   **Endpoint:** `POST /api/v1/whatsapp-automations`
*   **Request Payload (with Form Overrides for Meta source):**
    ```json
    {
      "name": "Meta Page Form Welcome Responder",
      "leadSources": ["Meta Page Form"],
      "template": {
        "name": "meta_lead_general_welcome",
        "language": "en",
        "components": []
      },
      "variableMappings": [
        { "key": "1", "source": "lead.name" }
      ],
      "formOverrides": [
        {
          "formId": "9876543210123",
          "isActive": true,
          "template": {
            "name": "specialized_product_pitch",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" }
          ]
        }
      ],
      "isActive": true
    }
    ```
*   **Response Schema (201 Created):**
    ```json
    {
      "success": true,
      "message": "Automation created successfully",
      "data": {
        "automation": {
          "_id": "67b93a...",
          "name": "Meta Page Form Welcome Responder",
          "leadSources": ["Meta Page Form"],
          "template": {
            "name": "meta_lead_general_welcome",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" }
          ],
          "formOverrides": [
            {
              "formId": "9876543210123",
              "isActive": true,
              "template": {
                "name": "specialized_product_pitch",
                "language": "en",
                "components": []
              },
              "variableMappings": [
                { "key": "1", "source": "lead.name" }
              ]
            }
          ],
          "isActive": true,
          "company": "67a99...",
          "createdBy": "67c99...",
          "createdAt": "2026-05-17T21:00:00.000Z",
          "updatedAt": "2026-05-17T21:00:00.000Z"
        }
      }
    }
    ```

#### C. Update Automation [PUT]
*   **Endpoint:** `PUT /api/v1/whatsapp-automations/:id`
*   **Request Payload (Partial modification):**
    ```json
    {
      "name": "Updated Meta Welcome Responder",
      "template": {
        "name": "meta_lead_v2_welcome",
        "language": "en",
        "components": []
      },
      "formOverrides": [
        {
          "formId": "9876543210123",
          "isActive": false,
          "template": {
            "name": "specialized_product_pitch",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" }
          ]
        }
      ]
    }
    ```
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation updated successfully",
      "data": {
        "automation": {
          "_id": "67b93a...",
          "name": "Updated Meta Welcome Responder",
          "leadSources": ["Meta Page Form"],
          "template": {
            "name": "meta_lead_v2_welcome",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" }
          ],
          "formOverrides": [
            {
              "formId": "9876543210123",
              "isActive": false,
              "template": {
                "name": "specialized_product_pitch",
                "language": "en",
                "components": []
              },
              "variableMappings": [
                { "key": "1", "source": "lead.name" }
              ]
            }
          ],
          "isActive": true,
          "company": "67a99...",
          "createdBy": "67c99...",
          "createdAt": "2026-05-17T21:00:00.000Z",
          "updatedAt": "2026-05-17T21:30:00.000Z"
        }
      }
    }
    ```

#### D. Toggle Rule Status [PATCH]
*   **Endpoint:** `PATCH /api/v1/whatsapp-automations/:id/toggle`
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation activated",
      "data": {
        "automation": {
          "_id": "67b93a...",
          "isActive": true
        }
      }
    }
    ```

#### E. Delete Rule [DELETE]
*   **Endpoint:** `DELETE /api/v1/whatsapp-automations/:id`
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation deleted successfully"
    }
    ```

---

### 2. Status Automations (`/api/v1/event-automations`)

Utilized by `/dashboard/whatsapp/automation/status`. Instantly sends an automated WhatsApp template when a lead's visual status column changes to a designated step.

*   **Supported `eventType` string:** `"LEAD_STATUS_CHANGED"` (Requires `targetStatus` ObjectId)

#### A. Fetch Status Automations [GET]
*   **Endpoint:** `GET /api/v1/event-automations`
*   **Description:** Returns event-triggered automations configured for the company. (Filter for `eventType === "LEAD_STATUS_CHANGED"` in the frontend).
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automations fetched",
      "data": {
        "automations": [
          {
            "_id": "67c5e...",
            "name": "Trigger: Lead Moved to Site Visit",
            "eventType": "LEAD_STATUS_CHANGED",
            "targetStatus": "67a8801b...", // LeadStatus model reference
            "template": {
              "name": "visit_preparation_tips",
              "language": "en",
              "components": []
            },
            "variableMappings": [
              { "key": "1", "source": "lead.name" }
            ],
            "isActive": true
          }
        ]
      }
    }
    ```

#### B. Create Status Automation [POST]
*   **Endpoint:** `POST /api/v1/event-automations`
*   **Request Payload:**
    ```json
    {
      "name": "Status Trigger: Negotiation Step Offer",
      "eventType": "LEAD_STATUS_CHANGED",
      "targetStatus": "67a8802f...", // LeadStatus ObjectId
      "template": {
        "name": "negotiation_offer",
        "language": "en",
        "components": []
      },
      "variableMappings": [
        { "key": "1", "source": "lead.name" },
        { "key": "2", "source": "custom", "customValue": "MEMBER10" }
      ],
      "isActive": true
    }
    ```
*   **Response Schema (201 Created):**
    ```json
    {
      "success": true,
      "message": "Automation created successfully",
      "data": {
        "automation": {
          "_id": "67d11f...",
          "name": "Status Trigger: Negotiation Step Offer",
          "eventType": "LEAD_STATUS_CHANGED",
          "targetStatus": "67a8802f...",
          "template": {
            "name": "negotiation_offer",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" },
            { "key": "2", "source": "custom", "customValue": "MEMBER10" }
          ],
          "isActive": true,
          "company": "67a99...",
          "createdBy": "67c99...",
          "createdAt": "2026-05-17T21:20:00.000Z",
          "updatedAt": "2026-05-17T21:20:00.000Z"
        }
      }
    }
    ```

#### C. Update Status Automation [PUT]
*   **Endpoint:** `PUT /api/v1/event-automations/:id`
*   **Request Payload:**
    ```json
    {
      "name": "Negotiation Offer - V2",
      "template": {
        "name": "negotiation_offer_v2",
        "language": "en"
      }
    }
    ```
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation updated",
      "data": {
        "automation": {
          "_id": "67d11f...",
          "name": "Negotiation Offer - V2",
          "eventType": "LEAD_STATUS_CHANGED",
          "targetStatus": "67a8802f...",
          "template": {
            "name": "negotiation_offer_v2",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" },
            { "key": "2", "source": "custom", "customValue": "MEMBER10" }
          ],
          "isActive": true,
          "updatedAt": "2026-05-17T21:35:00.000Z"
        }
      }
    }
    ```

#### D. Toggle Rule State [PATCH]
*   **Endpoint:** `PATCH /api/v1/event-automations/:id/toggle-status`
*   **Request Payload:**
    ```json
    {
      "isActive": false
    }
    ```
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation status updated",
      "data": {
        "automation": {
          "_id": "67d11f...",
          "isActive": false
        }
      }
    }
    ```

#### E. Delete Status Automation [DELETE]
*   **Endpoint:** `DELETE /api/v1/event-automations/:id`
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation deleted"
    }
    ```

---

### 3. Visit Automations (`/api/v1/event-automations`)

Utilized by `/dashboard/whatsapp/automation/visits`. Triggers automated template alerts for customer site visit schedules, rescheduling, cancellations, and proactive timing reminders.

*   **Supported `eventType` Options:**
    *   `VISIT_CREATED`: Scheduled a new customer visit.
    *   `VISIT_RESCHEDULED`: Shifted a visit window.
    *   `VISIT_CANCELLED`: Marked a visit as cancelled.
    *   `VISIT_COMPLETED`: Marked a visit completed.
    *   `VISIT_REMINDER_DAY_BEFORE`: Proactive reminder dispatched 24 hours prior.
    *   `VISIT_REMINDER_MORNING`: Morning-of reminder dispatch.
    *   `VISIT_REMINDER_1_HOUR`: Proactive reminder dispatched exactly 1 hour prior.

> [!NOTE]
> **Variable Mapping Sources:** When configuring variable values, you can pull properties dynamically from either the lead or the visit document: e.g. `"lead.name"`, `"visit.dateTime"`, `"visit.address"`.

#### A. Fetch Visit Automations [GET]
*   **Endpoint:** `GET /api/v1/event-automations`
*   **Description:** Returns event-triggered automations configured for the company. (Filter in the frontend for `eventType !== "LEAD_STATUS_CHANGED"`).
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automations fetched",
      "data": {
        "automations": [
          {
            "_id": "67c9a...",
            "name": "Visit Reminder 1H Prior",
            "eventType": "VISIT_REMINDER_1_HOUR",
            "template": {
              "name": "visit_1h_reminder_alert",
              "language": "en",
              "components": []
            },
            "variableMappings": [
              { "key": "1", "source": "lead.name" },
              { "key": "2", "source": "visit.dateTime" }
            ],
            "isActive": true
          }
        ]
      }
    }
    ```

#### B. Create Visit Automation [POST]
*   **Endpoint:** `POST /api/v1/event-automations`
*   **Request Payload:**
    ```json
    {
      "name": "Visit Created Welcome Template",
      "eventType": "VISIT_CREATED",
      "template": {
        "name": "visit_created_confirmation",
        "language": "en",
        "components": []
      },
      "variableMappings": [
        { "key": "1", "source": "lead.name" },
        { "key": "2", "source": "visit.dateTime" }
      ],
      "isActive": true
    }
    ```
*   **Response Schema (201 Created):**
    ```json
    {
      "success": true,
      "message": "Automation created successfully",
      "data": {
        "automation": {
          "_id": "67d98b...",
          "name": "Visit Created Welcome Template",
          "eventType": "VISIT_CREATED",
          "template": {
            "name": "visit_created_confirmation",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" },
            { "key": "2", "source": "visit.dateTime" }
          ],
          "isActive": true,
          "company": "67a99...",
          "createdBy": "67c99...",
          "createdAt": "2026-05-17T21:40:00.000Z",
          "updatedAt": "2026-05-17T21:40:00.000Z"
        }
      }
    }
    ```

#### C. Update Visit Automation [PUT]
*   **Endpoint:** `PUT /api/v1/event-automations/:id`
*   **Request Payload:**
    ```json
    {
      "name": "Visit Confirmation - Updated Template",
      "template": {
        "name": "visit_created_confirmation_v2",
        "language": "en"
      }
    }
    ```
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation updated",
      "data": {
        "automation": {
          "_id": "67d98b...",
          "name": "Visit Confirmation - Updated Template",
          "eventType": "VISIT_CREATED",
          "template": {
            "name": "visit_created_confirmation_v2",
            "language": "en",
            "components": []
          },
          "variableMappings": [
            { "key": "1", "source": "lead.name" },
            { "key": "2", "source": "visit.dateTime" }
          ],
          "isActive": true,
          "updatedAt": "2026-05-17T21:45:00.000Z"
        }
      }
    }
    ```

#### D. Toggle Rule State [PATCH]
*   **Endpoint:** `PATCH /api/v1/event-automations/:id/toggle-status`
*   **Request Payload:**
    ```json
    {
      "isActive": false
    }
    ```
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation status updated",
      "data": {
        "automation": {
          "_id": "67d98b...",
          "isActive": false
        }
      }
    }
    ```

#### E. Delete Visit Automation [DELETE]
*   **Endpoint:** `DELETE /api/v1/event-automations/:id`
*   **Response Schema (200 OK):**
    ```json
    {
      "success": true,
      "message": "Automation deleted"
    }
    ```
---

## 📝 Template Management

### 1. Fetch Approved Templates [GET]
**Endpoint:** `GET /api/v1/whatsapp-message/templates`  
**Description:** Fetches templates from Meta Graph API and merges them with local configurations (e.g., resolving Cloudflare media URLs).  
**Response Structure:** Returns a list of templates containing `name`, `language`, `category`, `components`, and `isApproved`.

### 2. Create Template [POST]
**Endpoint:** `POST /api/v1/whatsapp-message/templates`  
**Description:** Submits a new template to Meta for approval. Automatically handles media uploads (from Cloudflare R2 to Meta's Resumable Upload API) for `HEADER` components.  
**Request Payload:**
```json
{
  "name": "promotional_offer",
  "language": "en_US",
  "category": "MARKETING",
  "components": [
    {
      "type": "HEADER",
      "format": "IMAGE",
      "example": {
        "header_handle": ["https://r2.cloudflare.com/my-image.jpg"]
      }
    },
    {
      "type": "BODY",
      "text": "Hi {{1}}, here is your discount code: {{2}}"
    }
  ]
}
```
*Note: The backend automatically intercepts the public R2 URL, uploads it to Meta, acquires a valid media `handle`, and submits the template. It then saves the original R2 URL in the local DB for persistent rendering.*

---

## ⚡ WebSockets & Real-Time Events

The CRM leverages Socket.io to synchronize chat threads and delivery states dynamically across browser clients without polling.

### 1. Client Actions (Subscriptions)
Browser clients subscribe to specific rooms to receive filtered, context-aware updates.

*   **`join:company`**
    *   **Payload:** `{ companyId: string }`
    *   **Action:** Enters the socket into the company-wide room `company:${companyId}`. Used for global inbound alerts and sidebar notification counts.
*   **`join:whatsapp:conversation`**
    *   **Payload:** `{ conversationId: string }`
    *   **Action:** Enters the socket into `whatsapp:conversation:${conversationId}`. Prepares the client to receive active message logs for the opened chat window.
*   **`leave:whatsapp:conversation`**
    *   **Payload:** `{ conversationId: string }`
    *   **Action:** Gracefully departs the `whatsapp:conversation:${conversationId}` room when switching chats or closing the window.

---

### 2. Server-Emitted Events

*   **`whatsapp:incoming`** (Emitted to: `company:${companyId}`)
    *   **Trigger:** Dispatched when the Meta Webhook handles a new incoming message from a lead.
    *   **Payload:**
        ```json
        {
          "waId": "919876543210",
          "conversationId": "67b...",
          "messageId": "wamid.HBgLOT...",
          "timestamp": "2026-05-17T20:30:00.000Z"
        }
        ```
    *   **Frontend Action:** Updates the sidebar list order, pushes active chat listings to the top, and increments unread indicators.

*   **`whatsapp:message:new`** (Emitted to: `whatsapp:conversation:${conversationId}`)
    *   **Trigger:** Dispatched concurrently with an inbound message.
    *   **Payload:**
        ```json
        {
          "conversationId": "67b...",
          "message": {
            "direction": "INBOUND",
            "type": "text",
            "body": "Hi there, is this product available?",
            "media": null,
            "timestamp": "2026-05-17T20:30:00.000Z"
          }
        }
        ```
    *   **Frontend Action:** Automatically appends the new message bubble to the thread inside the `ChatWindow` component in real-time.

*   **`whatsapp:message:status`** (Emitted to: `whatsapp:conversation:${conversationId}`)
    *   **Trigger:** Dispatched when Meta updates delivery logs (e.g. `sent`, `delivered`, `read`, or `failed`).
    *   **Payload:**
        ```json
        {
          "messageId": "wamid.HBgLOT...",
          "status": "delivered", // pending, sent, delivered, read, failed
          "error": {
            "code": null,
            "message": null
          }
        }
        ```
    *   **Frontend Action:** Updates the status icon checks on the outbound message bubble in real-time. If the status is `failed`, it renders the warning state alongside the `error.message` detail.
