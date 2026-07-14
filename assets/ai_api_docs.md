# 🤖 AI Module API Documentation

This document provides a technical reference for the **AI Generation Module**. This module handles prompt optimization and on-the-fly AI image generation used primarily in the Itinerary module for generating dynamic cover photos and destination images.

---

## 🔐 Permissions & Access

These endpoints are authenticated (require a valid user session) but are generally accessible to all authenticated users utilizing the system to build itineraries or other assets.

---

## 🎨 Endpoints

### 1. Optimize Prompt [POST]
**Endpoint:** `POST /api/v1/ai/optimize-prompt`  
**Description:** Takes a simple user-provided description and expands it into a highly detailed, photorealistic prompt optimized for AI image generation using the Pollinations Text API.

**Request Payload:**
```json
{
  "description": "A beautiful sunset over the mountains in Switzerland",
  "systemPrompt": "Optional custom system prompt to override the default behavior."
}
```

**Default System Prompt Behavior:**
If `systemPrompt` is not provided in the request, the backend automatically prepends a default strict instruction pattern. However, the Itinerary module frontend (`AiImageGeneratorDialog.jsx`) explicitly passes the following dynamic system prompt to ensure high-quality outputs suitable for the CRM:

> *"You are an expert AI image prompt engineer. Analyze the provided description to determine its subject, context, and intent. Then, generate a highly detailed, photorealistic, and visually stunning image prompt tailored perfectly to that specific subject. Focus on lighting, atmosphere, and 2k resolution quality appropriate for the context. Do not include any text, UI elements, or logos unless explicitly requested in the description. Return ONLY the optimized prompt text and nothing else."*

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "prompt": "A breathtaking, photorealistic wide-angle shot of a majestic mountain range in Switzerland during sunset. The sky is painted in vibrant hues of deep orange, magenta, and purple, casting a warm golden glow over the snow-capped peaks. Lush green alpine valleys are visible below..."
  },
  "message": "Prompt optimized successfully"
}
```

---

### 2. Generate Image [POST]
**Endpoint:** `POST /api/v1/ai/generate-image`  
**Description:** Generates an image using the Pollinations Image API based on a detailed prompt. Returns a base64 Data URL (`data:image/jpeg;base64,...`) that can be immediately rendered in the frontend UI or uploaded to Cloudflare R2 when the user saves the itinerary.

**Request Payload:**
```json
{
  "prompt": "A breathtaking, photorealistic wide-angle shot of a majestic mountain range in Switzerland...",
  "width": 800, 
  "height": 500,
  "nologo": true
}
```
*Note: `width` (default 800), `height` (default 500), and `nologo` (default true) are optional parameters.*

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "url": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/4g..."
  },
  "message": "Image generated successfully"
}
```

---

## 💡 Workflow: Itinerary Image Generation

The Itinerary module uses the `AiImageGeneratorDialog` component to generate cover photos, section images, and stay (hotel) images. The description is dynamically constructed based on the context of what the user is editing.

### 1. Description Construction Cases
The frontend constructs the `initialPrompt` (description) by concatenating the title and description of the specific block being edited:
```javascript
const description = `${blockName} ${blockDesc}`.trim();
```

*   **Hero Image (`type: 'hero'`):** The user manually types the prompt describing the overall trip (e.g., "A beautiful beach in Goa").
*   **Day Section (`type: 'section'`):** `blockName` is the Day Title (e.g., "Arrival in Goa"), and `blockDesc` is the Day Description (e.g., "Check-in and relax at the beach").
*   **Stay/Hotel (`type: 'stay'`):** `blockName` is the Hotel Name (e.g., "Taj Exotica"), and `blockDesc` is the Hotel Description (e.g., "Luxury 5-star resort overlooking the Arabian Sea").

### 2. Generation Flow
1. **User Input / Context:** The `initialPrompt` is pre-filled based on the current block's context as described above.
2. **Optimization:** The frontend calls `/api/v1/ai/optimize-prompt` passing the constructed description and the custom system prompt.
3. **Generation:** The frontend takes the optimized prompt, allows the user to select a resolution preset (e.g., Landscape 1024x576), and calls `/api/v1/ai/generate-image`.
4. **Rendering:** The base64 URL returned is previewed in the UI.
5. **Persistence:** When the itinerary is saved, the Base64 string is uploaded to Cloudflare R2 and converted into a permanent CDN link.
