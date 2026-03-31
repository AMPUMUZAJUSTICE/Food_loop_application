# Food Loop - Product Requirements Document (PRD)

**Version:** 1.0  
**Date:** January 29, 2026  
**Author:** Product Team  
**Status:** Draft for Review

---

## Executive Summary

### Product Vision
Food Loop is a peer-to-peer mobile application that connects university students to share, sell, or buy surplus food, addressing food insecurity while reducing food waste on campus.

### Problem Statement
At Mbarara University of Science and Technology (MUST):
- 33% of students face food insecurity
- Significant amounts of edible food are wasted daily
- Students lack an efficient platform to exchange surplus food
- Economic constraints prevent students from accessing adequate nutrition

### Solution
A mobile-first platform that enables students to:
1. Post surplus food for sale or free sharing
2. Discover and purchase/request affordable food from peers
3. Manage food expiry dates to minimize waste
4. Build a trusted campus community through ratings and reviews

### Success Metrics
- **Adoption:** 500+ active users within 6 months
- **Engagement:** 1,000+ food transactions per month
- **Impact:** 30% reduction in reported food waste among users
- **Satisfaction:** 4.5+ average rating on app stores

---

## 1. Product Overview

### 1.1 Target Audience

**Primary Users:** University students aged 18-25 at MUST

**User Personas:**

**Persona 1: Sarah - The Budget-Conscious Student**
- Age: 20, Second-year Business student
- Lives in campus hostel
- Monthly food budget: UGX 150,000
- Pain Points: Struggles to afford meals toward month-end, sometimes cooks too much
- Goals: Save money on food, avoid wasting leftovers
- Tech Savviness: High - uses WhatsApp, Instagram, TikTok daily

**Persona 2: Keith - The Busy Engineering Student**
- Age: 22, Third-year Engineering student
- Limited cooking time due to demanding schedule
- Often has excess ingredients from bulk purchases
- Pain Points: Food expires before use, no time to cook daily
- Goals: Minimize food waste, occasionally buy ready meals
- Tech Savviness: Very High - early adopter of campus tech

**Persona 3: Prisciller - The Community Helper**
- Age: 21, Fourth-year Medical student
- Active in campus welfare programs
- Occasionally has surplus from care packages from home
- Pain Points: Wants to help peers but lacks efficient distribution channel
- Goals: Support food-insecure students, build community
- Tech Savviness: Moderate - uses essential apps

### 1.2 Product Positioning

**Category:** Peer-to-peer marketplace / Social impact app

**Unique Value Proposition:**
"The campus food-sharing platform that saves you money while feeding your community"

**Key Differentiators:**
1. **Campus-specific:** Geo-fenced to university, building trust and proximity
2. **Dual marketplace:** Both commercial and free sharing options
3. **Proactive waste prevention:** Built-in expiry tracking and reminders
4. **Student-verified:** University email authentication ensures safety

### 1.3 Platform Requirements

**Phase 1 (MVP - Month 1-3):**
- Android native app (Kotlin/Java)
- Minimum SDK: Android 7.0 (API 24)
- Target SDK: Android 13 (API 33)

**Phase 2 (Month 4-6):**
- iOS app (Swift)
- Minimum: iOS 13
- Target: iOS 17

**Infrastructure:**
- Backend: Firebase (Authentication, Firestore, Storage, Cloud Functions)
- Payment: Mobile Money API integration (MTN, Airtel)
- Maps: Google Maps SDK
- Notifications: Firebase Cloud Messaging

---

## 2. Functional Requirements

### 2.1 User Authentication & Onboarding

#### FR-1.1: University Email Verification
**Priority:** P0 (Must Have)

**Description:**  
Users must register with a valid university email address ending in `.ac.ug` or institution-specific domain.

**Acceptance Criteria:**
- System validates email format during registration
- Verification email sent with 6-digit code
- Code expires after 15 minutes
- Users cannot access app features without verification
- Support for resending code (maximum 3 attempts)

**User Flow:**
1. User enters full name, university email, phone number, password
2. System validates email domain
3. System sends 6-digit verification code to email
4. User enters code within 15 minutes
5. Account activated upon successful verification

**Business Rules:**
- Only verified university students can create accounts
- One account per email address
- Phone number must be unique (prevent duplicate accounts)

---

#### FR-1.2: Phone Number Verification
**Priority:** P0 (Must Have)

**Description:**  
Secondary verification via SMS to enable direct communication and payment processing.

**Acceptance Criteria:**
- Ugandan phone numbers (+256) required
- 6-digit SMS code sent upon registration
- Code expires after 10 minutes
- Maximum 3 resend attempts per hour
- Users can update phone number in settings (requires re-verification)

---

#### FR-1.3: Onboarding Tutorial
**Priority:** P1 (Should Have)

**Description:**  
Three-screen swipeable tutorial explaining app value and basic usage.

**Screens:**
1. **Problem Screen:** Visual showing food insecurity + waste statistics
2. **Solution Screen:** Illustration of peer food exchange
3. **How It Works Screen:** 3-step usage guide

**Acceptance Criteria:**
- Appears only on first app launch
- Can be skipped with "Get Started" button
- Not shown again after completion
- Can be revisited from Help section

---

### 2.2 Food Listing Management

#### FR-2.1: Create Food Listing
**Priority:** P0 (Must Have)

**Description:**  
Users can post available food items with details, photos, and pickup information.

**Input Fields:**
- **Food Photos:** 1-3 images (required: minimum 1)
  - Max size: 5MB per image
  - Formats: JPEG, PNG
  - Camera or gallery selection
  
- **Food Title:** Text (required, 5-50 characters)
  - Example: "Freshly Cooked Matoke", "Homemade Chapati (5 pieces)"
  
- **Description:** Multiline text (optional, max 300 characters)
  - Ingredients, allergens, portion size
  
- **Category:** Single select (required)
  - Cooked Meals
  - Fruits & Vegetables
  - Baked Goods
  - Snacks & Drinks
  - Ingredients
  - Other
  
- **Quantity:** Number + Unit (required)
  - Units: Portions, Pieces, Grams, Kilograms, Liters
  
- **Listing Type:** Toggle (required)
  - For Sale: Requires price input (UGX 500 - 50,000)
  - Free Sharing: Price set to 0
  
- **Expiry Date/Time:** DateTime picker (required)
  - Cannot be in the past
  - Maximum 7 days in future for fresh food
  
- **Pickup Location:** Location (required)
  - Current location (GPS)
  - Custom location (map picker)
  - Address text field
  
- **Pickup Time:** Time range (required)
  - Start time, End time
  - Example: "3:00 PM - 6:00 PM"
  
- **Additional Notes:** Text (optional, max 150 characters)

**Acceptance Criteria:**
- All required fields validated before submission
- Price must be in multiples of 500 UGX
- Images compressed automatically to reduce storage
- Location must be within 5km of campus boundaries
- Success notification upon posting
- Auto-save draft every 30 seconds
- Draft retained if user exits before posting

**User Flow:**
1. User taps "Share My Food" button
2. User captures/selects photos
3. User fills in food details
4. User sets price or marks as free
5. User specifies pickup details
6. User reviews summary
7. User taps "Post Now"
8. System validates inputs
9. System creates listing in database
10. User receives success confirmation

**Business Rules:**
- Users can have maximum 5 active listings at once
- Free items cannot be changed to paid after posting
- Listings auto-expire at specified expiry time
- Users receive reminder 24h before expiry

---

#### FR-2.2: Edit/Delete Listing
**Priority:** P0 (Must Have)

**Description:**  
Listing creators can modify or remove their active listings.

**Editable Fields:**
- All fields except "Listing Type" (free/paid cannot be changed)

**Acceptance Criteria:**
- Edit button visible only to listing creator
- Changes saved immediately with confirmation
- Delete requires confirmation dialog
- Deleted listings moved to "Expired" tab, not permanently removed
- Users with pending orders cannot delete listing (must cancel orders first)

---

#### FR-2.3: Mark Listing as Sold/Completed
**Priority:** P0 (Must Have)

**Description:**  
Users can mark listings as unavailable once food is sold or given away.

**Acceptance Criteria:**
- "Mark as Sold" button visible in My Listings
- Confirmation dialog prevents accidental marking
- Listing immediately hidden from public feed
- Status changed to "Sold" in listing history
- Triggers rating request for buyer/receiver

---

### 2.3 Food Discovery & Search

#### FR-3.1: Home Feed
**Priority:** P0 (Must Have)

**Description:**  
Main discovery interface displaying available food listings.

**Feed Sections:**
1. **Quick Actions:** Two prominent buttons
   - Share My Food
   - Find Food Now
   
2. **Active Deals:** Horizontal carousel
   - Food expiring within 24 hours
   - Sorted by soonest expiry
   - Shows countdown timer
   - Maximum 10 items
   
3. **Categories Grid:** 2x4 grid of category filters
   - Tappable icons
   - Badge showing count per category
   
4. **Recent Listings:** Infinite scroll vertical list
   - All active listings
   - Default sort: Newest first
   - Shows: Photo, title, price, distance, time posted

**Acceptance Criteria:**
- Feed loads within 2 seconds on 4G connection
- Listings update in real-time (new posts appear without refresh)
- "Pull to refresh" gesture supported
- Infinite scroll loads 20 items per batch
- Distance calculated from user's current location
- Expired listings automatically removed

**Personalization (Phase 2):**
- Prioritize categories user browses most
- Show "Based on your interests" section

---

#### FR-3.2: Search Functionality
**Priority:** P0 (Must Have)

**Description:**  
Users can search for specific food items by keyword.

**Search Features:**
- Real-time search as user types
- Search across: Title, Description, Category
- Recent search history (last 10 searches)
- Autocomplete suggestions based on popular searches

**Acceptance Criteria:**
- Search results appear within 1 second
- Minimum 2 characters required to trigger search
- Results sorted by relevance (title match > description match)
- Empty state shows "No results" with suggestion to post
- Search history clearable by user

---

#### FR-3.3: Advanced Filters
**Priority:** P1 (Should Have)

**Description:**  
Refinement options to narrow search results.

**Filter Options:**
- **Price Range:** Slider (UGX 0 - 50,000)
- **Distance:** Radio buttons (On Campus, <1km, <3km, <5km, Any)
- **Food Type:** Checkboxes (Vegetarian, Vegan, Non-vegetarian, Halal)
- **Expiry Time:** Checkboxes (Today, Tomorrow, This Week)
- **Listing Type:** Checkboxes (For Sale, Free)
- **Sort By:** Dropdown (Newest, Oldest, Price: Low-High, Price: High-Low, Nearest)

**Acceptance Criteria:**
- Filters accessible via funnel icon in search bar
- Multiple filters applicable simultaneously
- Active filter count badge displayed
- "Clear All" button resets filters
- Filter state persists during session
- Results update immediately on filter change

---

#### FR-3.4: Map View
**Priority:** P2 (Nice to Have)

**Description:**  
Geographic visualization of food listings.

**Features:**
- Toggle between List View and Map View
- Clustered pins for nearby items
- Price bubble on each pin
- Tap pin to see preview card
- Tap card to open full listing details

**Acceptance Criteria:**
- Map centered on user's current location
- Shows only listings within visible map bounds
- Pins update when map moved
- Smooth transition between list and map views

---

### 2.4 Messaging & Communication

#### FR-4.1: In-App Chat
**Priority:** P0 (Must Have)

**Description:**  
Direct messaging between buyers and sellers to coordinate exchanges.

**Message Types:**
- Text messages
- Food listing cards (embedded)
- Location sharing
- Images

**Acceptance Criteria:**
- Real-time message delivery (<2 seconds)
- Read receipts (single tick: sent, double tick: delivered, blue tick: read)
- Online status indicator
- Message character limit: 500 per message
- Image size limit: 5MB
- Messages stored for 90 days

**Special Features:**
- **Listing Card:** Auto-inserted when chat initiated from listing
  - Shows current price, status, photo
  - Updates if listing modified
  - "View Full Details" button
  
- **Quick Replies:** Suggested responses
  - "Is this still available?"
  - "When can I pick up?"
  - "Can you negotiate the price?"
  
- **Transaction Actions:**
  - "Send Payment" button (appears for buyer)
  - "Confirm Pickup" button (both parties)
  - "Mark as Complete" button (both parties)

**User Flow:**
1. User taps "Message Seller" on listing
2. Chat opens with listing card embedded
3. Users exchange messages
4. Buyer sends payment (if applicable)
5. Seller confirms receipt
6. Parties coordinate pickup time/location
7. Both confirm pickup completion
8. Rating prompt appears

**Business Rules:**
- Chats auto-archive after 30 days of inactivity
- Users can block/report inappropriate conversations
- Payment must be completed before marking as complete

---

#### FR-4.2: Push Notifications
**Priority:** P0 (Must Have)

**Description:**  
Timely alerts for important events.

**Notification Types:**
1. **Transaction Notifications:**
   - "Keith purchased your Chapati for UGX 2,000"
   - "Payment of UGX 2,000 received from Keith"
   - "Prisciller has requested your free Bananas"
   
2. **Message Notifications:**
   - "New message from Prisciller"
   - Message preview (first 50 characters)
   
3. **Expiry Reminders:**
   - "Your Milk expires in 24 hours - Share it now!"
   - "Reminder: Chapati expires today at 6 PM"
   
4. **Marketing Notifications (opt-in):**
   - "Flash Deal! Chapati nearby for UGX 500"
   - "5 new listings near you"
   
5. **System Notifications:**
   - "Welcome to Food Loop!"
   - "New feature available: Expiry Manager"

**Acceptance Criteria:**
- Users can customize notification preferences in settings
- Notifications grouped by type
- Actionable notifications deep-link to relevant screen
- Quiet hours respected (10 PM - 7 AM: silent by default)
- Maximum 5 marketing notifications per week per user

---

### 2.5 Payment Processing

#### FR-5.1: Mobile Money Integration
**Priority:** P0 (Must Have)

**Description:**  
Secure payment processing via MTN and Airtel Mobile Money.

**Supported Networks:**
- MTN Mobile Money
- Airtel Money

**Payment Flow:**
1. Buyer initiates payment from chat
2. Order summary displayed (item, price, service fee)
3. Buyer selects payment method (MTN/Airtel)
4. Buyer confirms phone number
5. System sends payment request to mobile money API
6. User receives USSD prompt on phone
7. User enters PIN on phone to authorize
8. System receives payment confirmation
9. Funds held in escrow
10. Funds released to seller after pickup confirmation

**Acceptance Criteria:**
- Payment processed within 30 seconds
- Service fee: 5% of item price (minimum UGX 100)
- Escrow holds funds for 48 hours maximum
- Auto-release to seller after 48h if no dispute
- Refund processed within 24h if transaction cancelled
- Payment receipt sent via email and in-app

**Business Rules:**
- Minimum transaction: UGX 500
- Maximum transaction: UGX 50,000
- Seller must verify phone number before receiving payments
- Disputes must be raised within 24h of transaction

---

#### FR-5.2: In-App Wallet
**Priority:** P1 (Should Have)

**Description:**  
Digital wallet for storing funds and faster transactions.

**Wallet Features:**
- Add money via Mobile Money
- Use wallet balance for purchases
- Withdraw to Mobile Money account
- Transaction history

**Acceptance Criteria:**
- Minimum top-up: UGX 1,000
- Maximum balance: UGX 100,000
- Withdrawal minimum: UGX 2,000
- Withdrawal fee: UGX 500
- Withdrawal processed within 24 hours
- Real-time balance updates

---

#### FR-5.3: Cash on Pickup
**Priority:** P1 (Should Have)

**Description:**  
Option for sellers to accept cash payment during pickup.

**Features:**
- Seller enables "Accept Cash" toggle on listing
- No platform service fee for cash transactions
- Honor system (no escrow)
- Both parties mark as "Paid" to complete transaction

**Acceptance Criteria:**
- Cash option clearly labeled on listing
- Buyer reminded to bring exact change
- No payment button in chat for cash listings
- Transaction marked complete only after both parties confirm

**Limitations:**
- No dispute resolution for cash transactions
- No automatic ratings trigger (manual prompt)

---

### 2.6 User Profiles & Reputation

#### FR-6.1: User Profile
**Priority:** P0 (Must Have)

**Description:**  
Public-facing profile showcasing user information and activity.

**Profile Elements:**
- Profile photo (optional)
- Display name (required)
- University/Department (optional)
- Member since date
- Average rating (⭐ out of 5)
- Total reviews count
- Statistics:
  - Items shared
  - Money saved
  - Successful transactions
  - Response time (average)

**Acceptance Criteria:**
- Profile accessible by tapping username anywhere in app
- Users can edit own profile from Profile tab
- Profile photo cropped to square, max 2MB
- Display name: 2-30 characters, no special characters except space, hyphen, apostrophe

---

#### FR-6.2: Ratings & Reviews
**Priority:** P0 (Must Have)

**Description:**  
Post-transaction feedback system to build trust.

**Rating Components:**
- **Food Quality:** 1-5 stars (required)
- **Seller/Buyer Reliability:** 1-5 stars (required)
- **Written Review:** Text (optional, max 200 characters)
- **Anonymous Toggle:** Option to hide name

**Acceptance Criteria:**
- Rating prompt appears after both parties mark transaction complete
- Users can skip rating but cannot transact again until rated
- Ratings visible on user profiles
- Average calculated from all received ratings
- Reviews editable within 24 hours
- Inappropriate reviews flaggable for moderation

**User Flow:**
1. Transaction marked complete by both parties
2. Rating screen appears for both users
3. Users rate each other independently
4. Ratings published simultaneously (neither sees rating until both submit)
5. Notification sent when rated

**Business Rules:**
- One rating per transaction
- Cannot rate same user twice for same transaction
- Ratings permanent (editable for 24h, then locked)
- Users with <3.0 average flagged for review

---

#### FR-6.3: Verification Badges
**Priority:** P2 (Nice to Have)

**Description:**  
Visual indicators of trusted users.

**Badge Types:**
- ✅ **Email Verified:** All users (automatic)
- 📱 **Phone Verified:** SMS verification complete
- 🏆 **Top Seller:** 50+ successful transactions + 4.8+ rating
- ⭐ **Trusted:** 25+ successful transactions + 4.5+ rating
- 🌱 **New Member:** <5 transactions

**Acceptance Criteria:**
- Badges displayed next to username
- Tooltip explains badge meaning on tap
- Badges earned automatically based on criteria
- Cannot be removed once earned

---

### 2.7 Food Expiry Management

#### FR-7.1: Expiry Tracker
**Priority:** P1 (Should Have)

**Description:**  
Proactive tool to help users track food expiration dates and reduce waste.

**Features:**
- Add food items manually (name, expiry date, photo)
- Scan receipt to auto-extract items (Phase 2)
- Calendar/timeline view
- Color-coded urgency:
  - Red: Expiring within 24 hours
  - Yellow: Expiring in 2-7 days
  - Green: Expiring in 8+ days
- "Share Now" quick action button
- Set custom reminders per item

**Acceptance Criteria:**
- Items sortable by expiry date or name
- Expired items auto-archived after 7 days
- "Share Now" pre-fills listing form with item details
- Reminders sent via push notification
- Default reminder: 24 hours before expiry

**User Flow:**
1. User navigates to Expiry Manager
2. User taps "Add Item"
3. User enters item name, expiry date
4. Optional: User uploads photo
5. Item appears in timeline
6. User receives reminder before expiry
7. User taps "Share Now" to create listing
8. Listing form pre-populated with item details

---

### 2.8 Safety & Moderation

#### FR-8.1: Food Safety Guidelines
**Priority:** P0 (Must Have)

**Description:**  
Educational content and mandatory acknowledgment of food safety practices.

**Guidelines Include:**
- Proper food storage temperatures
- Cross-contamination prevention
- Allergen disclosure requirements
- Signs of spoilage
- Hygiene best practices

**Acceptance Criteria:**
- Displayed during registration (must accept to proceed)
- Accessible from Settings > Food Safety Guidelines
- Pop-up reminder when posting perishable items
- Link in footer of every listing

---

#### FR-8.2: Report & Block
**Priority:** P0 (Must Have)

**Description:**  
User safety mechanisms to report violations and block unwanted contact.

**Report Reasons:**
- Inappropriate content
- Fraudulent listing
- Unsafe food
- Harassment
- Spam

**Block Features:**
- Block from chat screen or profile
- Blocked users cannot see your listings
- Blocked users cannot message you
- Block list manageable in settings

**Acceptance Criteria:**
- Report button accessible from listing details and chat
- Report triggers admin review within 24 hours
- User notified of resolution
- Severe violations result in account suspension
- Block takes effect immediately

---

#### FR-8.3: Content Moderation
**Priority:** P0 (Must Have)

**Description:**  
Automated and manual review systems for listing quality.

**Automated Checks:**
- Profanity filter for titles and descriptions
- Image analysis for inappropriate content
- Price validation (within reasonable range)
- Duplicate listing detection

**Manual Review Triggers:**
- Listings reported by 2+ users
- User with multiple reports
- High-value transactions (>UGX 20,000)

**Acceptance Criteria:**
- Flagged listings hidden pending review
- Moderators respond within 24 hours
- Users notified of violations with reason
- 3 violations = account warning
- 5 violations = account suspension

---

### 2.9 Analytics & Insights (Admin)

#### FR-9.1: Dashboard Metrics
**Priority:** P1 (Should Have)

**Description:**  
Backend analytics for monitoring platform health.

**Key Metrics:**
- Daily active users (DAU)
- Monthly active users (MAU)
- Total listings posted
- Transactions completed
- Transaction value (total, average)
- User retention (Day 1, Day 7, Day 30)
- Top categories
- Peak usage times
- Geographic distribution on campus

**Acceptance Criteria:**
- Dashboard accessible to admin users only
- Real-time metric updates
- Exportable reports (CSV, PDF)
- Date range filters

---

## 3. Non-Functional Requirements

### 3.1 Performance

**NFR-1.1: App Launch Time**
- Cold start: <3 seconds
- Warm start: <1 second

**NFR-1.2: Screen Load Time**
- Home feed: <2 seconds
- Listing details: <1 second
- Chat messages: <500ms

**NFR-1.3: API Response Time**
- Search queries: <1 second
- Payment processing: <30 seconds
- Image upload: <5 seconds (on 4G)

**NFR-1.4: Offline Support**
- Cached listings viewable offline
- Drafts saved locally
- Messages queued when offline, sent when reconnected

---

### 3.2 Security

**NFR-2.1: Data Encryption**
- All data in transit encrypted (TLS 1.3)
- User passwords hashed (bcrypt)
- Payment data encrypted at rest
- PII encrypted in database

**NFR-2.2: Authentication**
- JWT tokens with 7-day expiry
- Refresh tokens for session persistence
- Two-factor authentication (email + phone)

**NFR-2.3: Privacy**
- GDPR-compliant data handling
- User data deletion within 30 days of account deletion
- Location data not stored permanently
- Transaction history retained for 2 years (accounting purposes)

---

### 3.3 Scalability

**NFR-3.1: User Capacity**
- Support 5,000 concurrent users
- Handle 10,000 registered users
- Database queries optimized for <100ms

**NFR-3.2: Storage**
- Firebase Storage: 100GB initial allocation
- Image compression: 70% quality, max 800x800px
- CDN for static assets

---

### 3.4 Reliability

**NFR-4.1: Uptime**
- Target: 99.5% uptime
- Maintenance windows: Sundays 2-4 AM

**NFR-4.2: Error Handling**
- Graceful degradation on API failures
- User-friendly error messages
- Automatic retry for failed operations
- Crash reporting (Firebase Crashlytics)

---

### 3.5 Usability

**NFR-5.1: Accessibility**
- WCAG 2.1 Level AA compliance
- Screen reader support
- Minimum touch target: 48x48dp
- Color contrast ratio: 4.5:1

**NFR-5.2: Localization**
- English (primary)
- Runyankore (Phase 2)
- Currency: Ugandan Shillings (UGX)

---

### 3.6 Compatibility

**NFR-6.1: Device Support**
- Android: OS 7.0+ (95% of MUST students' devices)
- iOS: iOS 13+ (Phase 2)
- Screen sizes: 4" - 7" phones and tablets

**NFR-6.2: Network Conditions**
- Functional on 3G networks (1 Mbps)
- Optimized for 4G (10 Mbps)
- Data-saver mode reduces image quality

---

## 4. User Interface Requirements

### 4.1 Design System

**Color Palette:**
- **Primary:** #2E7D32 (Green - sustainability, food)
- **Secondary:** #FF9800 (Orange - urgency, warmth)
- **Background:** #FAFAFA (Off-white)
- **Text Primary:** #212121 (Dark gray)
- **Text Secondary:** #757575 (Medium gray)
- **Error:** #D32F2F (Red)
- **Success:** #388E3C (Green)
- **Warning:** #FFC107 (Amber)

**Typography:**
- **Headings:** Poppins Semi-Bold
  - H1: 24sp
  - H2: 20sp
  - H3: 18sp
- **Body:** Roboto Regular
  - Body1: 16sp
  - Body2: 14sp
  - Caption: 12sp
- **Numbers/Prices:** Roboto Mono 16sp

**Spacing:**
- 8dp base unit
- 16dp screen margins
- 12dp between list items
- 8dp between form fields

**Icons:**
- Material Icons (outlined for unselected, filled for selected)
- 24dp standard size
- 2dp stroke width

---

### 4.2 Key Screen Specifications

Refer to detailed screen specifications document for:
- Onboarding & Authentication (4 screens)
- Main App Navigation (4 tabs)
- Food Listing Management (4 screens)
- Payment Flow (3 screens)
- Profile & Settings (multiple screens)

---

## 5. Technical Architecture

### 5.1 Technology Stack

**Frontend:**
- **Android:** Kotlin, Jetpack Compose
- **iOS (Phase 2):** Swift, SwiftUI

**Backend:**
- **Firebase Authentication:** User management
- **Cloud Firestore:** Real-time database
- **Firebase Storage:** Image hosting
- **Cloud Functions:** Server-side logic (Node.js)

**Third-Party Services:**
- **Google Maps SDK:** Location services
- **Mobile Money APIs:** MTN MoMo, Airtel Money
- **Firebase Cloud Messaging:** Push notifications
- **Crashlytics:** Error tracking
- **Google Analytics:** User behavior tracking

---

### 5.2 Data Model

**Users Collection:**
```json
{
  "userId": "string (Firebase Auth UID)",
  "fullName": "string",
  "email": "string",
  "phoneNumber": "string",
  "photoURL": "string",
  "university": "MUST",
  "department": "string (optional)",
  "isVerified": "boolean",
  "createdAt": "timestamp",
  "rating": "number (0-5)",
  "totalReviews": "number",
  "totalListings": "number",
  "successfulTransactions": "number",
  "walletBalance": "number",
  "fcmToken": "string (for notifications)"
}
```

**Listings Collection:**
```json
{
  "listingId": "string (auto-generated)",
  "userId": "string (creator)",
  "title": "string",
  "description": "string",
  "category": "string (enum)",
  "quantity": {
    "value": "number",
    "unit": "string"
  },
  "price": "number (0 for free)",
  "isFree": "boolean",
  "photos": ["array of URLs"],
  "expiryDate": "timestamp",
  "pickupLocation": {
    "lat": "number",
    "lng": "number",
    "address": "string"
  },
  "pickupTimeStart": "timestamp",
  "pickupTimeEnd": "timestamp",
  "additionalNotes": "string",
  "status": "string (active, sold, expired)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "views": "number",
  "savedBy": ["array of userIds"]
}
```

**Transactions Collection:**
```json
{
  "transactionId": "string",
  "listingId": "string",
  "buyerId": "string",
  "sellerId": "string",
  "amount": "number",
  "serviceFee": "number",
  "paymentMethod": "string (mobile_money, wallet, cash)",
  "paymentStatus": "string (pending, completed, failed, refunded)",
  "pickupStatus": "string (pending, completed)",
  "buyerConfirmed": "boolean",
  "sellerConfirmed": "boolean",
  "createdAt": "timestamp",
  "completedAt": "timestamp",
  "cancelledAt": "timestamp",
  "cancellationReason": "string"
}
```

**Messages Collection:**
```json
{
  "chatId": "string (composed of userId1_userId2)",
  "participants": ["userId1", "userId2"],
  "lastMessage": {
    "text": "string",
    "senderId": "string",
    "timestamp": "timestamp"
  },
  "unreadCount": {
    "userId1": "number",
    "userId2": "number"
  },
  "messages": [
    {
      "messageId": "string",
      "senderId": "string",
      "text": "string",
      "type": "string (text, image, location, listing_card)",
      "timestamp": "timestamp",
      "read": "boolean"
    }
  ]
}
```

**Reviews Collection:**
```json
{
  "reviewId": "string",
  "transactionId": "string",
  "reviewerId": "string",
  "revieweeId": "string",
  "foodRating": "number (1-5)",
  "userRating": "number (1-5)",
  "comment": "string",
  "isAnonymous": "boolean",
  "createdAt": "timestamp"
}
```

---

## 6. Development Roadmap

### Phase 1: MVP (Months 1-3)

**Month 1:**
- Week 1-2: Setup development environment, Firebase configuration
- Week 3-4: Authentication & onboarding screens

**Month 2:**
- Week 1-2: Food listing creation & management
- Week 3-4: Home feed, search, and filters

**Month 3:**
- Week 1-2: Messaging system
- Week 3: Payment integration (Mobile Money)
- Week 4: Testing & bug fixes

**MVP Features:**
- User registration & authentication
- Post/edit/delete listings
- Browse and search food
- In-app messaging
- Mobile Money payments
- Ratings & reviews

---

### Phase 2: Enhancement (Months 4-6)

**Month 4:**
- Expiry tracker
- Wallet system
- Advanced filters
- Performance optimization

**Month 5:**
- iOS app development
- Push notifications enhancement
- Map view integration
- Analytics dashboard

**Month 6:**
- User testing with 30 pilot users
- Iterative improvements based on feedback
- Soft launch preparation
- Documentation & training materials

---

### Phase 3: Scale & Iterate (Months 7-12)

**Post-Launch:**
- Receipt scanning (OCR)
- Multi-campus expansion
- Runyankore localization
- Referral program
- In-app promotions
- Advanced analytics
- Community features (leaderboards, challenges)

---

## 7. Success Metrics & KPIs

### 7.1 Adoption Metrics
- **Registration Rate:** 500+ users in 6 months
- **Activation Rate:** 70% of registered users post or request food within 7 days
- **Retention:**
  - Day 1: 60%
  - Day 7: 40%
  - Day 30: 25%

### 7.2 Engagement Metrics
- **Daily Active Users (DAU):** 200+ by Month 6
- **Listings per Week:** 100+
- **Transactions per Month:** 1,000+
- **Average Session Duration:** 5+ minutes
- **Messages per Transaction:** 5-10 average

### 7.3 Business Metrics
- **Transaction Volume:** UGX 2,000,000+ monthly by Month 6
- **Service Fee Revenue:** UGX 100,000+ monthly
- **Average Order Value:** UGX 2,500
- **Completion Rate:** 80% of initiated transactions completed

### 7.4 Impact Metrics
- **Food Waste Reduction:** 30% reduction reported by active users
- **Cost Savings:** UGX 15,000+ average savings per user per month
- **Food Insecurity:** 20% of users report improved food access
- **Community Building:** 4.5+ average user satisfaction rating

---

## 8. Risks & Mitigation

### 8.1 Technical Risks

**Risk:** Firebase costs exceed budget  
**Mitigation:** Implement usage quotas, optimize queries, consider hybrid architecture

**Risk:** Poor network connectivity on campus  
**Mitigation:** Extensive offline mode, data compression, progressive image loading

**Risk:** Payment API downtime  
**Mitigation:** Support multiple payment providers, cash backup option, clear user communication

---

### 8.2 Business Risks

**Risk:** Low user adoption  
**Mitigation:** Aggressive campus marketing, referral incentives, partnership with student welfare

**Risk:** Fraudulent transactions  
**Mitigation:** Escrow system, user verification, reputation scores, reporting mechanisms

**Risk:** Food safety incidents  
**Mitigation:** Mandatory safety guidelines, clear disclaimers, insurance consideration

---

### 8.3 Regulatory Risks

**Risk:** Mobile Money licensing requirements  
**Mitigation:** Legal consultation, partnership with licensed payment aggregator

**Risk:** Data privacy regulations  
**Mitigation:** GDPR compliance, clear privacy policy, user consent mechanisms

---

## 9. Future Enhancements

### 9.1 Features Backlog
1. **Subscription Model:** Premium tier with unlimited listings, priority visibility
2. **Group Orders:** Students pool orders to save on delivery/pickup
3. **Meal Plans:** Weekly subscription to specific sellers' menus
4. **Sustainability Score:** Gamification around waste reduction
5. **Recipe Sharing:** Community recipes for leftover ingredients
6. **Integration with Campus Cafeterias:** Official partnerships for discounted meals
7. **Dietary Preferences:** Advanced filters for allergies, religious restrictions
8. **Donation to Charity:** Option to donate proceeds to campus food bank

### 9.2 Platform Expansion
- Web portal for desktop access
- Expansion to other universities in Uganda
- Regional adaptation for different countries
- API for third-party integrations (e.g., campus dining apps)

---

## 10. Appendices

### Appendix A: Glossary
- **Listing:** A posted food item available for sale or free sharing
- **Transaction:** A completed exchange of food between users
- **Escrow:** Temporary holding of payment until pickup confirmation
- **Service Fee:** Platform commission on paid transactions (5%)
- **Expiry Tracker:** Tool for monitoring food expiration dates
- **Active Deal:** Listing expiring within 24 hours

### Appendix B: User Research Summary
- 30 pilot users identified from MUST student body
- Surveys conducted: 150 respondents (33% reported food insecurity)
- Focus groups: 3 sessions with 8-10 students each
- Competitive analysis: Similar apps in other markets (OLIO, Too Good To Go)

### Appendix C: Legal & Compliance
- Terms of Service (TOS) draft required
- Privacy Policy compliant with Uganda Data Protection Act
- Food Safety Disclaimer mandatory at registration
- Mobile Money license or aggregator partnership needed

### Appendix D: Support & Documentation
- User Guide (in-app help section)
- FAQ document
- Video tutorials for key features
- Admin manual for moderators
- Developer API documentation (Phase 3)

---

**Document Approval:**

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Product Manager |  |  |  |
| Lead Developer |  |  |  |
| UX Designer |  |  |  |
| Project Sponsor |  |  |  |

---

**Document History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Jan 29, 2026 | Product Team | Initial draft |

---

**End of Product Requirements Document**
