# 🗺️ Itinerary, Quotation & Voucher API Documentation

This document provides a technical reference for the **Itinerary V2**, **Quotation**, and **Voucher** modules. These modules handle the end-to-end travel planning workflow from itinerary creation to financial quoting and operational vouchering.

---

## 🔐 Permissions & Module Access

Access to these endpoints is controlled by both modular and action-level permissions.

### 1. Modular Access
- **Key**: `modules.itinerary`
- **Description**: Must be enabled at the company level for any itinerary functionality to be visible or accessible.

### 2. Action Permissions (`PERMISSIONS`)
| Action | Permission Key | Used In |
| :--- | :--- | :--- |
| **View** | `itinerary.view`, `quotation.view`, `voucher.view` | Listing, Details, Templates, Previews |
| **Create** | `itinerary.create`, `quotation.create`, `voucher.create` | Creating new records |
| **Update** | `itinerary.update`, `quotation.update`, `voucher.update` | Modifying existing records |
| **Delete** | `itinerary.delete`, `quotation.delete`, `voucher.delete` | Permanent removal |
| **Download** | `itinerary.download`, `quotation.download`, `voucher.download` | PDF Generation & R2 access |
| **Send** | `itinerary.send`, `quotation.send`, `voucher.send` | WhatsApp & Email sharing |

---

## 🎨 Templates & Previews

Endpoints for exploring and previewing itinerary designs before saving.

### 1. List Available Templates
**Endpoint:** `GET /api/v1/itinerary-v2/templates`  
**Permissions:** `itinerary.view`  
**Response:**
```json
{
  "success": true,
  "data": {
    "templates": [
      {
        "_id": "67b9...",
        "name": "Premium Modern",
        "key": "premium-v3",
        "thumbnail": "https://...",
        "exampleData": { "subject": "Sample Trip", "sections": [...] }
      }
    ]
  }
}
```

### 2. Static Template Preview
**Endpoint:** `GET /api/v1/itinerary-v2/templates/:key/preview`  
**Description:** Renders a full-page HTML preview using the template's internal `exampleData`.  
**Response:** `text/html` (Rendered Handlebars template).

### 3. Live Data Preview
**Endpoint:** `POST /api/v1/itinerary-v2/templates/:key/preview`  
**Description:** Renders HTML based on the provided JSON body. Used in the "Live Editor" for real-time feedback.  
**Request Payload:** See **Create Itinerary** for schema.  
**Response:** `text/html`.

### 4. Ad-hoc PDF Download
**Endpoint:** `POST /api/v1/itinerary-v2/templates/:key/download`  
**Description:** Generates and returns a PDF binary buffer immediately. Does NOT save to database.  
**Response:** `application/pdf` (Binary Stream).

---

## 📝 Itinerary Management (CRUD)

### 1. List Itineraries
**Endpoint:** `GET /api/v1/itinerary-v2/all`  
**Permissions:** `itinerary.view`  
**Query Parameters:** 
- `page` (Number): Default 1
- `limit` (Number): Default 10
- `searchQuery` (String): Search by subject
- `hasQuotation` (Boolean): `true` to show itineraries with linked quotes, `false` for those without.
**Response Schema:**
```json
{
  "success": true,
  "data": {
    "itineraries": [
      {
        "_id": "67c...",
        "subject": "Himalayan Retreat",
        "customerName": "John Doe",
        "customerCompany": "Tech Corp",
        "heroImage": "https://...",
        "noOfDays": 3,
        "adults": 2,
        "rooms": 1,
        "startDate": "2024-04-10",
        "templateKey": "template1",
        "sections": [
          {
            "name": "Day 1: Arrival",
            "description": "Check-in and local sightseeing",
            "image": "https://..."
          }
        ],
        "stays": [
          { "name": "Grand Palace", "description": "...", "image": "..." }
        ],
        "transports": [
          { "type": "Flight", "details": "UK-123", "price": 5000 }
        ],
        "keyLocations": ["Dehradun", "Mussoorie"],
        "keyInclusions": ["Breakfast"],
        "keyExclusions": ["Lunch"],
        "termsAndConditions": [
          { "title": "Cancellation", "description": "Free before 24h" }
        ],
        "shortDescription": "A quick getaway...",
        "activitiesCost": 15000,
        "totalPrice": 25000,
        "pricePerAdult": 12500,
        "isGenerated": true,
        "itineraryLink": "https://...",
        "createdAt": "2024-03-22T..."
      }
    ],
    "totalCount": 1,
    "pagination": { "page": 1, "limit": 10 }
  }
}
```

### 2. Create Itinerary [POST]
**Endpoint:** `POST /api/v1/itinerary-v2/create`

**Exact Request Payload:**
```json
{
  "subject": "Golden Triangle Tour: 5 Days",
  "customerName": "Robert Smith",
  "customerCompany": "Smith Logistics",
  "customerEmail": "robert@example.com", 
  "customerPhone": "+91 9999988888",
  "startDate": "2024-10-10",
  "noOfDays": 5,
  "adults": 2,
  "rooms": 1,
  "keyLocations": ["Delhi", "Agra", "Jaipur"],
  "shortDescription": "Explore the historic heart of India in luxury.",
  "heroImage": "https://r2-storage.com/hero_image.jpg",
  "templateKey": "modern-v2",
  "sections": [
    {
      "name": "Day 1: Arrival & Red Fort",
      "description": "Airport pickup and visit to the Red Fort followed by local street food tour.",
      "image": "https://r2-storage.com/day1.jpg",
      "meals": { 
        "breakfast": false, 
        "lunch": true, 
        "dinner": true 
      },
      "notes": "Carry a water bottle.",
      "title": "Welcome to Delhi"
    }
  ],
  "stays": [
    {
      "name": "The Oberoi Amarvilas",
      "description": "Taj Mahal view luxury suite",
      "pricePerNight": 35000,
      "noOfNights": 2,
      "image": "https://r2-storage.com/hotel.jpg"
    }
  ],
  "transports": [
    {
      "type": "Flight",
      "details": "UK-123 | 10:00 AM",
      "price": 12000
    }
  ],
  "keyInclusions": ["Airport Transfers", "English Speaking Guide", "Entry Tickets"],
  "keyExclusions": ["Visa Fees", "International Flights", "Gratuities"],
  "activitiesCost": 15000,
  "totalPrice": 97000,
  "pricePerAdult": 48500,
  "termsAndConditions": [
    { "title": "Payment", "description": "50% advance for booking confirmation." },
    { "title": "Cancellation", "description": "Free cancellation 15 days before travel." }
  ]
}
```
**Response Schema:**
```json
{
  "success": true,
  "statusCode": 201,
  "data": {
    "itinerary": {
      "_id": "67c...",
      "itineraryLink": "https://...", 
      "isGenerated": true
    }
  },
  "message": "Itinerary created successfully"
}
```

### 3. Update Itinerary
**Endpoint:** `PATCH /api/v1/itinerary-v2/update/:id`  
**Permissions:** `itinerary.update`  
**Description:** Updates record and automatically regenerates the PDF on Cloudflare R2.

### 4. Delete Itinerary
**Endpoint:** `DELETE /api/v1/itinerary-v2/delete/:id`  
**Permissions:** `itinerary.delete`  
**Description:** Deletes record and cleans up the associated PDF from R2.

---

## 🚀 PDF & Links

### 1. Smart Link Generation
**Endpoint:** `POST /api/v1/itinerary-v2/generate/:id`  
**Permissions:** `itinerary.download`  
**Description:** Returns the existing PDF link if up-to-date, otherwise regenerates a new one.  
**Response:** `{ "success": true, "data": { "link": "https://..." } }`

### 2. Public Download Redirect
**Endpoint:** `GET /api/v1/itinerary-v2/download/:id`  
**Description:** Redirects directly to the Cloudflare R2 PDF URL. Used for public sharing.

---

## 💰 Quotation Management

Quotations serve as the financial layer for travel planning. They can be stand-alone or linked to an **Itinerary** and a **Lead**.

### 1. Enums & Constants
| Field | Type | Allowed Values |
| :--- | :--- | :--- |
| `status` | String | `DRAFT`, `CREATED`, `SENT`, `ACCEPTED`, `CANCELLED`, `REJECTED` |

### 2. Permissions
| Action | Permission String | Description |
| :--- | :--- | :--- |
| **View List/Detail** | `quotation.view` | Access the quotation list and view single records. |
| **Create** | `quotation.create` | Generate new quotations. |
| **Update** | `quotation.update` | Edit existing quotation details. |
| **Delete** | `quotation.delete` | Permanently remove quotations. |
| **Download PDF** | `quotation.download` | Retrieve PDF from R2 or trigger regeneration. |
| **Send Quote** | `quotation.send` | Send the quote via external communication channels. |

### 3. Schema & Field Details
- **`itinerary`**: ObjectId (Ref Itinerary). If provided, creates a bidirectional link.
- **`quotationNumber`**: String. Required (Unique).
- **`status`**: `DRAFT` | `CREATED` | `SENT` | `ACCEPTED` | `CANCELLED` (Default: `CREATED`).
- **`billingAddress`**: Object with `street`, `city`, `state`, `zip`, `country`.
- **`items`**: Array of items. Each item must have `unitPrice`, `quantity`, and `amount`.

### 2. Create Quotation [POST]
**Endpoint:** `POST /api/v1/quotation`  
**Permissions:** `quotation.create`  
**Description:** Creates a quote and automatically generates a PDF on Cloudflare R2.

**Exact Request Payload:**
```json
{
  "quotationNumber": "QUO-2024-001",
  "quotationDate": "2024-05-16",
  "validUntil": "2024-05-30",
  "subject": "5 Days Dubai Luxury Package",
  "status": "CREATED",
  "clientName": "Alice Wonder",
  "clientEmail": "alice@example.com",
  "clientPhoneNo": "9876543210",
  "clientCompany": "Wonderland Travels",
  "itinerary": "67c9f...",
  "billingAddress": {
    "street": "123 Business Park",
    "city": "Mumbai",
    "state": "Maharashtra",
    "zip": "400001",
    "country": "India"
  },
  "items": [
    {
      "itemId": "prod_123",
      "name": "Stay: Burj Al Arab",
      "description": "2 Nights - Deluxe Suite",
      "quantity": 1,
      "unitPrice": 150000,
      "discount": 10000,
      "tax": 18000,
      "amount": 150000,
      "totalAmount": 158000
    }
  ],
  "subTotal": 150000,
  "discountTotal": 10000,
  "taxTotal": 18000,
  "adjustment": -500,
  "grandTotal": 157500,
  "termsAndConditions": "1. 50% payment upfront.\n2. Non-refundable after confirmation."
}
```

### 3. Get Single Quotation [GET]
**Endpoint:** `GET /api/v1/quotation/:id`  
**Permissions:** `quotation.view`  
**Response:** Returns the full quotation object with populated itinerary details.

### 4. Update Quotation [PATCH]
**Endpoint:** `PATCH /api/v1/quotation/update/:id`  
**Permissions:** `quotation.update`  
**Description:** Updates the quote record and regenerates the PDF on R2. Accepts partial/full payload matching the Create structure.

### 5. Delete Quotation [DELETE]
**Endpoint:** `DELETE /api/v1/quotation/delete/:id`  
**Permissions:** `quotation.delete`  
**Description:** Deletes the record and associated R2 PDF. Unlinks from Itinerary/Lead.

### 6. List & Filter [GET]
**Endpoint:** `GET /api/v1/quotation`  
**Query Parameters:**
- `searchQuery`: Search by `subject` or `quotationNumber`.
- `status`: Filter by status (`DRAFT`, `CREATED`, `SENT`, `ACCEPTED`, `CANCELLED`, `REJECTED`).
- `page` & `limit`: Pagination support.

---

## 🚀 PDF & Links (Quotation)

### 1. Get R2 Link
**Endpoint:** `GET /api/v1/quotation/generate/:id`  
**Permissions:** `quotation.download`  
**Response:** `{ "success": true, "data": { "pdfUrl": "https://..." } }`

### 2. Public Download
**Endpoint:** `GET /api/v1/quotation/download/:id`  
**Description:** Redirects directly to the R2 PDF file.

### 4. Itinerary Pre-fill Logic (Frontend)
When creating a quotation from an itinerary, the frontend performs the following auto-mapping:

| Itinerary Field | Quotation Field | Logic |
| :--- | :--- | :--- |
| `customerName` | `clientName` | Direct Map |
| `customerEmail` | `clientEmail` | Direct Map |
| `customerPhone` | `clientPhoneNo` | Direct Map |
| `customerCompany` | `clientCompany` | Direct Map |
| `stays` | `items` | `name`: "Stay: {name}", `amount`: `pricePerNight * noOfNights` |
| `transports` | `items` | `name`: "Transport: {type}", `amount`: `price` |
| `activitiesCost`| `items` | Added as "Activities & Sightseeing" line item |
| `totalPrice` | `grandTotal` | Used to calculate activity cost if `activitiesCost` is missing |

---

## 🎫 Voucher Management

Vouchers confirm service bookings for clients. They are categorized into two types:

- **`TRAVEL`**: Used for transportation (Cabs/Buses). Tracks `travelStartDate`, `travelEndDate`, and `travelTotalKms`.
- **`HOTEL`**: Used for accommodation. Requires `checkIn`, `checkOut`, and `hotelDetails`. Cannot contain `TRAVEL` items.

### 1. Enums & Constants
| Field | Type | Allowed Values |
| :--- | :--- | :--- |
| `voucherType` | String | `TRAVEL`, `HOTEL` |
| `status` | String | `DRAFT`, `ISSUED`, `CANCELLED` |
| `items[].itemType` | String | `TRAVEL`, `ACCOMMODATION` |
| `guestList[].gender` | String | `Male`, `Female`, `Other` |
| `guestList[].type` | String | `Adult`, `Child` |

### 2. Permissions
| Action | Permission String | Description |
| :--- | :--- | :--- |
| **View List/Detail** | `voucher.view` | Access the voucher list and view single records. |
| **Create** | `voucher.create` | Create new Travel or Hotel vouchers. |
| **Update** | `voucher.update` | Modify existing voucher details. |
| **Delete** | `voucher.delete` | Remove vouchers from the system. |
| **Download PDF** | `voucher.download` | Generate and download PDF documents. |
| **Send Voucher** | `voucher.send` | Trigger automated WhatsApp/Email delivery. |

### 3. Create Voucher [POST]
**Endpoint:** `POST /api/v1/vouchers`  
**Permissions:** `voucher.create`  
**Description:** Creates a voucher and generates a PDF on R2.

#### Example: HOTEL Voucher
```json
{
  "voucherType": "HOTEL",
  "voucherNo": "V-HOTEL-999",
  "voucherDate": "2024-05-16",
  "clientName": "John Smith",
  "clientPhone": "9876543210",
  "clientEmail": "john@example.com",
  "clientAddress": "123 Green Street, NY",
  "checkIn": "2024-06-10",
  "checkOut": "2024-06-12",
  "noOfRooms": 2,
  "hotelDetails": {
    "name": "The Oberoi",
    "address": "Dr. Zakir Hussain Marg, Delhi",
    "contact": "011-23890505",
    "gstNo": "07AAAAA0000A1Z5"
  },
  "items": [
    {
      "itemType": "ACCOMMODATION",
      "description": "Luxury Suite - Double Occupancy",
      "quantity": 2,
      "price": 15000,
      "amount": 30000
    }
  ],
  "guestList": [
    { "name": "John Smith", "age": 35, "gender": "Male", "type": "Adult" },
    { "name": "Jane Smith", "age": 32, "gender": "Female", "type": "Adult" }
  ],
  "inclusions": ["Free WiFi", "Buffet Breakfast", "Airport Pickup"],
  "financials": {
    "subTotal": 30000,
    "discountTotal": 0,
    "taxTotal": 3600,
    "totalAmount": 33600,
    "advancePaid": 10000,
    "balanceAmount": 23600
  },
  "termsAndConditions": "1. ID proof mandatory at check-in.\n2. Cancellation rules apply."
}
```

#### Example: TRAVEL Voucher
```json
{
  "voucherType": "TRAVEL",
  "voucherNo": "V-TRAV-888",
  "clientName": "Robert Brown",
  "travelStartDate": "2024-05-20",
  "travelEndDate": "2024-05-25",
  "travelTotalKms": 500,
  "items": [
    {
      "itemType": "TRAVEL",
      "description": "Innova Crysta - 500km Package",
      "quantity": 500,
      "price": 20,
      "amount": 10000
    }
  ],
  "financials": {
    "totalAmount": 10000,
    "advancePaid": 2000,
    "balanceAmount": 8000
  }
}
```

### 2. Update Voucher [PUT]
**Endpoint:** `PUT /api/v1/vouchers/:id`  
**Permissions:** `voucher.update`  
**Description:** Full update of voucher details. Note: Uses `PUT` instead of `PATCH`.

### 3. Get Single Voucher [GET]
**Endpoint:** `GET /api/v1/vouchers/:id`  
**Permissions:** `voucher.view`

### 4. Delete Voucher [DELETE]
**Endpoint:** `DELETE /api/v1/vouchers/:id`  
**Permissions:** `voucher.delete`

### 5. List & Filter [GET]
**Endpoint:** `GET /api/v1/vouchers`  
**Query Parameters:**
- `searchQuery`: Search by `voucherNo`, `clientName`, or `clientEmail`.
- `voucherType`: Filter by `TRAVEL` or `HOTEL`.
- `status`: Filter by `DRAFT`, `ISSUED`, or `CANCELLED`.
- `page` & `limit`: Pagination support.

---

## 🚀 PDF & Links (Voucher)

### 1. Get R2 Link
**Endpoint:** `POST /api/v1/vouchers/:id/generate-link`  
**Permissions:** `voucher.download`  
**Response:** `{ "success": true, "pdfUrl": "https://..." }`

### 2. Public Download
**Endpoint:** `GET /api/v1/vouchers/:id/pdf`  
**Description:** Direct binary stream download of the PDF.