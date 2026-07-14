# Mail & Marketing API

The Mail module enables companies to integrate their own SMTP servers and send single or bulk emails to leads using customizable templates.

## Base Paths
- **Custom Email (SMTP)**: `/api/v1/custom-email`
- **Email Templates**: `/api/v1/marketing`

---

## 🔐 Permissions & Access Control

### Modular Access
Access is governed by the marketing module:
- `modules.marketing`: Must be enabled for the company.

### User-Level Permissions
| Permission Key | Action |
| :--- | :--- |
| `marketing.mail` | Send individual and bulk emails |
| `marketing.templates.view` | View email templates |
| `marketing.templates.create` | Create/Edit email templates |

---

## 🏗️ SMTP Integration (`/custom-email`)

### 3. Get Integration Status
`GET /status`
Returns the current SMTP configuration (password is masked).

---

## 📝 Email Templates (`/marketing/mail/templates`)

### 1. Create Template
`POST /create`

**Request Payload:**
```json
{
  "name": "Welcome Email",
  "subject": "Welcome to our platform!",
  "body": "<h1>Hello {{name}}</h1><p>...</p>"
}
```

### 2. List Templates
`GET /`
Supports search via `?search=query`.

---

## ✉️ Sending Emails (`/custom-email`)

### 1. Send Single Email
`POST /send`

**Request Payload:**
```json
{
  "to": "lead@example.com",
  "subject": "Your Quote",
  "body": "<p>Content here...</p>",
  "cc": ["manager@company.com"],
  "bcc": [],
  "replyTo": "sales@company.com",
  "employeeMail": "executive@company.com"
}
```

### 2. Send Bulk Emails
`POST /bulk/send`
Sends individual emails to multiple recipients and creates an `EmailLog`.

**Request Payload:**
```json
{
  "recipients": ["lead1@test.com", "lead2@test.com"],
  "subject": "Exclusive Offer",
  "body": "Check out our new products...",
  "mailType": "marketing"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "totalRecipients": 2,
    "sent": 2,
    "failedCount": 0,
    "results": [
      { "email": "lead1@test.com", "status": "sent" },
      { "email": "lead2@test.com", "status": "sent" }
    ]
  }
}
```

---

## 📊 Logging & Tracking

### Email Log Schema
Every bulk send operation creates a record in `EmailLog` with:
- `provider`: "custom"
- `type`: `marketing`, `invoice`, `itinerary`, etc.
- `mailedBy`: User ID of the sender.
- `mailsSent`: Count of successful deliveries.
- `recipients`: Array of email addresses.
- `metaData`: Contains detailed results and CC/BCC information.

### Encryption
SMTP passwords are encrypted using `AES-256-CBC` before storage in the database.
