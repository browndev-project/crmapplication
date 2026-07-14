# ⚙️ Settings Module API Documentation

This document provides a technical reference for the **Settings** module, covering company branding, financial details, attendance policies, lead statuses, and custom role labeling.

---

## 🔐 Permissions & Module Access

### 1. Modular Access
- **Key**: `modules.base` (Implicitly enabled for all companies)
- **Description**: Access to settings is typically restricted to users with `company` or `admin` roles.

### 1. Settigns sub tabs - Modular Access
const links = [
    {
        label: "Attendance Configuration",
        path: "/dashboard/settings/attendanceConfig",
        icon: <EventAvailableIcon fontSize="small" />,
        module: MODULES.ATTENDANCE,
    },
    {
        label: "Role Labels Configuration",
        path: "/dashboard/settings/roleLabelsConfig",
        icon: <BadgeIcon fontSize="small" />,
        module: MODULES.BASE,
    },
    {
        label: "Lead Status Configuration",
        path: "/dashboard/settings/leadStatusConfig",
        icon: <LabelIcon fontSize="small" />,
        module: MODULES.LEADS,
    },
    {
        label: "Company Settings",
        path: "/dashboard/settings/companySettings",
        icon: <BusinessIcon fontSize="small" />
    }
];

---

## 🏢 Company Profile & Branding

### 1. Get Company Details [GET]
**Endpoint:** `GET /api/v1/company/getCompanyDetails/:id`
**Description:** Fetches core company metadata including logo URL, address, and contact info.

### 2. Update Company [PATCH]
**Endpoint:** `PATCH /api/v1/company/update/:id`

**For invoice terms settings - MODULE:** `modules.invoice`

**Request Payload:**
```json
{
  "name": "Trevion Travel Solutions",
  "email": "contact@trevion.com",
  "contactPhone": "9876543210",
  "address": "123 Business Park, City",
  "logo": "https://r2.cloudflare.com/...",
  "invoiceTerms": "..."
}
```

---

## 🏦 Bank Account Management

These accounts are used for generating dynamic payment details on Invoices and Quotations.

### 1. List Bank Accounts [GET]
**Endpoint:** `GET /api/v1/bank/company/list`  
**MODULE:** `modules.invoice` || `modules.quotation` || `modules.voucher`

### 2. Create Bank Account [POST]
**Endpoint:** `POST /api/v1/bank/create`  
**Request Payload:**
```json
{
  "bankName": "HDFC Bank",
  "accountOwner": "Trevion Travels",
  "accountNumber": "50100012345678",
  "bankIfsc": "HDFC0001234",
  "upiId": "trevion@hdfc"
}
```

### 3. Update Bank Account [PATCH]
**Endpoint:** `PATCH /api/v1/bank/update/:id`

### 4. Delete Bank Account [DELETE]
**Endpoint:** `DELETE /api/v1/bank/delete/:id`

---

## 🕒 Attendance Configuration

Defines company-wide policies for employee attendance and tracking.

### 1. Get Attendance Config [GET]
**Endpoint:** `GET /api/v1/companyAttendanceConfig/`  
**Permissions:** `settings.view`

### 2. Update Attendance Config [PATCH]
**Endpoint:** `PATCH /api/v1/companyAttendanceConfig/update`  
**Permissions:** `settings.update`  
**Request Payload:**
```json
{
  "officeStartTime": "09:00",
  "officeEndTime": "18:00",
  "trackingEnabled": true,
  "geofencingEnabled": false,
  "workingDays": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
}
```

---

## 📈 Lead Status Configuration

Allows companies to define their own lead lifecycle stages.

### 1. List Lead Statuses [GET]
**Endpoint:** `GET /api/v1/leadStatus/company/list`  
**Permissions:** `leadStatus.manage`

### 2. Create Lead Status [POST]
**Endpoint:** `POST /api/v1/leadStatus/company/create`  
**Request Payload:**
```json
{
  "label": "Demo Scheduled",
  "color": "#3b82f6",
  "isActive": true,
  "isDeletable": true
}
```

### 3. Update Lead Status [PATCH]
**Endpoint:** `PATCH /api/v1/leadStatus/update/:id`

---

## 🏷️ Role Labels (Custom Role Naming)

Allows companies to rename system roles to match their internal hierarchy.

### 1. Get Role Labels [GET]
**Endpoint:** `GET /api/v1/company/role-labels`  
**Permissions:** `settings.view`

### 2. Update Role Labels [PATCH]
**Endpoint:** `PATCH /api/v1/company/role-labels/update`  
**Permissions:** `settings.update`  
**Request Payload:**
```json
{
  "team_leader": "Cluster Manager",
  "sales_executive": "Field Officer",
  "manager": "Region Head"
}
```
