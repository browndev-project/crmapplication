# 💰 Invoice Module API Documentation

This document provides a technical reference for the **Invoice** module. This module handles tax invoice generation, payment tracking, and PDF document management.

---

## 🔐 Permissions & Module Access

### 1. Modular Access
- **Key**: `modules.invoice`
- **Description**: Must be enabled at the company level for the Invoice module to be accessible.

### 2. Action Permissions (`PERMISSIONS`)
| Action | Permission Key | Used In |
| :--- | :--- | :--- |
| **View** | `invoice.view` | List, Details, View Dialog |
| **Create** | `invoice.create` | Creating new invoices |
| **Update** | `invoice.update` | Modifying data or status |
| **Delete** | `invoice.delete` | Permanent removal |
| **Download** | `invoice.download` | PDF Generation & R2 access |
| **Send** | `invoice.send` | Email/WhatsApp sharing workflows |

---

## 🧾 Invoice Operations

### 1. List Invoices
**Endpoint:** `GET /api/v1/invoice/list`  
**Permissions:** `invoice.view`  
**Query Parameters:** `page`, `limit`, `searchQuery`, `status`  
**Response Schema:**
```json
{
  "success": true,
  "data": {
    "invoices": [
      {
        "_id": "67d...",
        "invoiceNumber": "INV-1711...",
        "subject": "Services for Project Alpha",
        "clientName": "Jane Doe",
        "clientCompany": "Global Tech",
        "clientPhoneNo": "9876543210",
        "clientEmail": "jane@tech.com",
        "lead": "67a...",
        "subTotal": 12000,
        "discountTotal": 500,
        "taxTotal": 1000,
        "adjustment": 0,
        "grandTotal": 12500,
        "status": "PAID",
        "invoiceDate": "2024-03-22T...",
        "dueDate": "2024-04-05T...",
        "dealDate": "2024-03-20T...",
        "isGenerated": true,
        "invoiceLink": "https://...",
        "invoiceLinkKey": "company/invoices/...",
        "billingAddress": {
          "street": "...", "city": "...", "state": "...", "zip": "...", "country": "..."
        },
        "shippingAddress": {
          "street": "...", "city": "...", "state": "...", "zip": "...", "country": "..."
        },
        "account": {
          "bankName": "...", "bankIfsc": "...", "accountOwner": "...", "accountNumber": "...", "upiId": "..."
        },
        "items": [
          {
            "itemType": "SERVICE",
            "name": "Web Hosting",
            "description": "...",
            "quantity": 1,
            "unitPrice": 12000,
            "discount": 500,
            "tax": 1000,
            "amount": 11500,
            "totalAmount": 12500
          }
        ],
        "termsAndConditions": "...",
        "description": "...",
        "createdAt": "2024-03-22T..."
      }
    ],
    "totalCount": 1,
    "pagination": { "page": 1, "limit": 10 }
  }
}
```

### 2. Create Invoice
**Endpoint:** `POST /api/v1/invoice/create`  
**Permissions:** `invoice.create`  
**Request Payload (Exact Match):**
```json
{
  "subject": "Annual Maintenance",
  "invoiceDate": "2024-03-25",
  "dueDate": "2024-04-10",
  "dealDate": "2024-03-20",
  "status": "CREATED",
  "clientCompany": "Retail Hub",
  "clientName": "Mike Ross",
  "clientPhoneNo": "9876543210",
  "clientEmail": "mike@retailhub.com",
  "leadId": "67a...",
  "adjustment": 0,
  "items": [
    {
      "itemType": "SERVICE",
      "itemId": "67b...", 
      "name": "Cloud Storage",
      "description": "50GB Monthly",
      "quantity": 1,
      "unitPrice": 1200,
      "discount": 100,
      "tax": 216
    }
  ],
  "billingAddress": {
    "street": "123 Main St",
    "city": "Dehradun",
    "state": "Uttarakhand",
    "zip": "248001",
    "country": "India"
  },
  "shippingAddress": {
    "street": "456 Office Rd",
    "city": "Dehradun",
    "state": "Uttarakhand",
    "zip": "248001",
    "country": "India"
  },
  "account": {
    "accountOwner": "Trevion Admin",
    "bankName": "HDFC Bank",
    "bankIfsc": "HDFC0001",
    "accountNumber": "123456789",
    "upiId": "trevion@upi"
  },
  "termsAndConditions": "Payment due within 15 days...",
  "description": "Quarterly billing cycle..."
}
```

### 3. Update Invoice
**Endpoint:** `PATCH /api/v1/invoice/update/:id`  
**Permissions:** `invoice.update`  
**Description:** Updates core invoice data. Note that `CANCELLED` invoices cannot be updated.

### 4. Update Invoice Status
**Endpoint:** `PATCH /api/v1/invoice/update-status/:id`  
**Permissions:** `invoice.update`  
**Request Body:** `{ "status": "PAID" }`  
**Allowed Values:** `DRAFT`, `CREATED`, `SENT`, `PAID`, `CANCELLED`

---

## 📄 PDF & Downloads

### 1. Direct PDF Download
**Endpoint:** `GET /api/v1/invoice/download/:id`  
**Permissions:** `invoice.download`  
**Description:** Generates the PDF on the fly and returns a binary blob (`application/pdf`).

### 2. Generate Public Link (R2)
**Endpoint:** `GET /api/v1/invoice/generate/:id`  
**Permissions:** `invoice.download`  
**Description:** Generates PDF, uploads to Cloudflare R2, and returns a public URL.  
**Response:** `{ "success": true, "pdfUrl": "https://..." }`
