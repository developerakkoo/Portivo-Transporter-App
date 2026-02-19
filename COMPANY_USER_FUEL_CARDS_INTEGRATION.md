# Company User and Fuel Cards Integration Documentation

## Overview

This document describes the integration of company users (sub-admins) and fuel cards systems in the Portivo Transporter App. The system enables company users to login and manage the transporter app with permission-based access control.

## Table of Contents

1. [Authentication Flow](#authentication-flow)
2. [Permission System](#permission-system)
3. [API Endpoints](#api-endpoints)
4. [App Routes and Navigation](#app-routes-and-navigation)
5. [Permission-Based Access Control](#permission-based-access-control)
6. [Example Flows](#example-flows)

---

## Authentication Flow

### Company User Login

Company users authenticate using their mobile number and a 4-digit PIN.

#### Flow Diagram

```
User enters mobile + PIN
    ↓
App calls /api/auth/company-user-login
    ↓
Backend validates:
  - Company user exists
  - PIN is correct
  - hasAccess = true
  - status = 'active'
    ↓
Backend generates JWT token with:
  - userType: 'company-user'
  - userId: company user ID
  - transporterId: parent transporter ID
  - permissions: array of permissions
    ↓
App stores token and user data
    ↓
App connects Socket.IO using transporterId
    ↓
User redirected to home screen
```

#### PIN Login Screen

The PIN login screen (`lib/screens/pin_login.dart`) includes a toggle to switch between:
- **Transporter**: Uses transporter PIN login endpoint
- **Company User**: Uses company user login endpoint

**Key Features:**
- Mobile number input
- 4-digit PIN input (auto-advance between fields)
- User type toggle (Transporter/Company User)
- Automatic login on PIN completion

#### Auth Service Methods

**File**: `lib/services/auth_service.dart`

```dart
Future<AuthResponseModel> companyUserLogin(String mobile, String pin)
```

**Response Structure:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "jwt_token_here",
    "refreshToken": "refresh_token_here",
    "user": {
      "id": "company_user_id",
      "mobile": "9876543210",
      "name": "John Doe",
      "userType": "company-user",
      "status": "active",
      "hasAccess": true,
      "transporterId": "transporter_id",
      "permissions": ["viewTrips", "createTrips", "manageDrivers"]
    }
  }
}
```

#### Auth Provider

**File**: `lib/providers/auth_provider.dart`

The `AuthProvider` includes:
- `loginAsCompanyUser(String mobile, String pin)` - Company user login method
- Stores user type, permissions, and transporterId
- Connects Socket.IO using transporterId (company users receive updates for their transporter)

---

## Permission System

### Permission Service

**File**: `lib/services/permission_service.dart`

The `PermissionService` provides permission checking functionality:

#### Methods

1. **`hasPermission(String permission)`**
   - Checks if user has a specific permission
   - Returns `true` for transporters (they have all permissions)
   - Returns `true` for company users if they have the permission

2. **`hasAnyPermission(List<String> permissions)`**
   - Checks if user has at least one of the specified permissions

3. **`hasAllPermissions(List<String> permissions)`**
   - Checks if user has all of the specified permissions

4. **`isTransporter`** (getter)
   - Returns `true` if current user is a transporter

5. **`isCompanyUser`** (getter)
   - Returns `true` if current user is a company user

6. **`getPermissions()`** (getter)
   - Returns list of permissions for company users
   - Returns empty list for transporters

#### Available Permissions

- `viewTrips` - View trips
- `createTrips` - Create new trips
- `manageDrivers` - Manage drivers (add, edit, delete)
- `manageVehicles` - Manage vehicles (add, edit, delete)
- `manageWallet` - Access wallet and transactions
- `manageFuelCards` - Manage fuel cards
- `manageUsers` - Manage company users
- `viewReports` - View reports

#### Permission Logic

```dart
// Transporters have all permissions
if (user.userType == 'transporter') {
  return true; // Always grant permission
}

// Company users need explicit permission
return user.permissions.contains(permission);
```

---

## API Endpoints

### Authentication

#### Company User Login

**Endpoint**: `POST /api/auth/company-user-login`

**Request Body:**
```json
{
  "mobile": "9876543210",
  "pin": "1234"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "jwt_token",
    "refreshToken": "refresh_token",
    "user": {
      "id": "user_id",
      "mobile": "9876543210",
      "name": "John Doe",
      "userType": "company-user",
      "status": "active",
      "hasAccess": true,
      "transporterId": "transporter_id",
      "permissions": ["viewTrips", "createTrips"]
    }
  }
}
```

### Fuel Cards

#### List Fuel Cards

**Endpoint**: `GET /api/fuel-cards`

**Headers**: `Authorization: Bearer <token>`

**Permission Required**: `manageFuelCards` or transporter

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "card_id",
      "cardNumber": "1234567890123456",
      "balance": 5000.00,
      "status": "active",
      "assignedDriverId": "driver_id"
    }
  ]
}
```

#### View Fuel Card QR

**Endpoint**: `GET /api/fuel-cards/:id/qr`

**Permission Required**: `manageFuelCards` or transporter

### Company Users

#### List Company Users

**Endpoint**: `GET /api/company-users`

**Permission Required**: `manageUsers` or transporter

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "user_id",
      "name": "John Doe",
      "mobile": "9876543210",
      "email": "john@example.com",
      "hasAccess": true,
      "status": "active",
      "permissions": ["viewTrips", "createTrips"],
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### Create Company User

**Endpoint**: `POST /api/company-users`

**Permission Required**: `manageUsers` or transporter

**Request Body:**
```json
{
  "name": "John Doe",
  "mobile": "9876543210",
  "email": "john@example.com",
  "permissions": ["viewTrips", "createTrips"]
}
```

#### Update Company User

**Endpoint**: `PUT /api/company-users/:id`

**Permission Required**: `manageUsers` or transporter

**Note**: Company users cannot modify their own permissions (only transporter can)

#### Set PIN

**Endpoint**: `PUT /api/company-users/:id/set-pin`

**Permission Required**: `manageUsers` or transporter

**Request Body:**
```json
{
  "pin": "1234"
}
```

#### Toggle Access

**Endpoint**: `PUT /api/company-users/:id/toggle-access`

**Permission Required**: `manageUsers` or transporter

---

## App Routes and Navigation

### Route Configuration

Routes are defined in `lib/main.dart`:

```dart
'/login' -> LoginScreen
'/pin-login' -> PinLoginScreen (with company user toggle)
'/home' -> MainScaffold
'/create-trip' -> CreateTripScreen
'/fuel-cards' -> FuelCardsScreen
'/fuel-card-qr' -> FuelCardQRScreen
'/company-users' -> CompanyUsersScreen
'/add-user' -> AddEditUserScreen
'/vehicles' -> VehiclesListScreen
'/wallet' -> WalletScreen
```

### Navigation Structure

```
MainScaffold (Bottom Navigation)
├── HomeTab
│   └── Create Trip Button (permission: createTrips)
├── TripsTab
│   └── Add Trip Button (permission: createTrips)
├── DriversTab
│   └── Add Driver Button (permission: manageDrivers)
└── MoreTab
    ├── View Profile (always visible)
    ├── Vehicles (permission: manageVehicles)
    ├── Wallet (permission: manageWallet)
    ├── Fuel Cards (permission: manageFuelCards)
    ├── Company & Users (permission: manageUsers)
    └── Support (always visible)
```

---

## Permission-Based Access Control

### Screen-Level Protection

Screens check permissions at the entry point and redirect unauthorized users:

#### Example: Fuel Cards Screen

**File**: `lib/screens/fuel_cards.dart`

```dart
return Consumer<AuthProvider>(
  builder: (context, authProvider, authChild) {
    final permissionService = PermissionService(authProvider);
    
    // Check permission - redirect if unauthorized
    if (!permissionService.hasPermission('manageFuelCards') && 
        !permissionService.isTransporter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to access fuel cards'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return Scaffold(...);
    }
    
    // Render screen content
    return Consumer<FuelProvider>(...);
  },
);
```

### Navigation-Level Protection

Menu items in `MoreTab` are conditionally rendered:

**File**: `lib/screens/tabs/more_tab.dart`

```dart
// Vehicles - requires manageVehicles permission
if (permissionService.hasPermission('manageVehicles') || 
    permissionService.isTransporter)
  _buildMenuItem(...),

// Wallet - requires manageWallet permission
if (permissionService.hasPermission('manageWallet') || 
    permissionService.isTransporter)
  _buildMenuItem(...),

// Fuel Cards - requires manageFuelCards permission
if (permissionService.hasPermission('manageFuelCards') || 
    permissionService.isTransporter)
  _buildMenuItem(...),

// Company Users - requires manageUsers permission
if (permissionService.hasPermission('manageUsers') || 
    permissionService.isTransporter)
  _buildMenuItem(...),
```

### Action Button Protection

Action buttons are conditionally shown:

#### Example: Create Trip Button

**File**: `lib/screens/tabs/trips_tab.dart`

```dart
actions: [
  Consumer<AuthProvider>(
    builder: (context, authProvider, child) {
      final permissionService = PermissionService(authProvider);
      if (permissionService.hasPermission('createTrips') || 
          permissionService.isTransporter) {
        return IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => Navigator.of(context).pushNamed('/create-trip'),
        );
      }
      return const SizedBox.shrink();
    },
  ),
],
```

### Protected Screens

The following screens have permission checks:

1. **CreateTripScreen** - `createTrips` permission
2. **VehiclesListScreen** - `manageVehicles` permission
3. **WalletScreen** - `manageWallet` permission
4. **FuelCardsScreen** - `manageFuelCards` permission
5. **CompanyUsersScreen** - `manageUsers` permission

---

## Example Flows

### Flow 1: Company User Login

1. User opens app → sees login screen
2. User taps "Login with PIN"
3. User toggles to "Company User"
4. User enters mobile number: `9876543210`
5. User enters PIN: `1234`
6. App calls `companyUserLogin('9876543210', '1234')`
7. Backend validates and returns JWT token with permissions
8. App stores token and user data
9. App connects Socket.IO using transporterId
10. User redirected to home screen
11. User sees only permitted menu items and actions

### Flow 2: Creating a Trip (Company User)

1. Company user with `createTrips` permission navigates to Trips tab
2. User sees "Add Trip" button (permission check passed)
3. User taps button → navigates to CreateTripScreen
4. Screen checks permission → allows access
5. User fills form and creates trip
6. Trip is created with transporterId from company user's account
7. Trip appears in trips list

### Flow 3: Managing Fuel Cards (Company User)

1. Company user with `manageFuelCards` permission navigates to More tab
2. User sees "Fuel cards" menu item (permission check passed)
3. User taps menu item → navigates to FuelCardsScreen
4. Screen checks permission → allows access
5. User sees list of fuel cards for their transporter
6. User can view QR codes and manage fuel cards

### Flow 4: Unauthorized Access Attempt

1. Company user without `manageUsers` permission tries to access Company Users screen
2. User navigates to More tab
3. User does NOT see "Company & users" menu item (hidden by permission check)
4. If user somehow navigates directly (e.g., deep link):
   - Screen checks permission → fails
   - User is redirected back
   - Error message shown: "You do not have permission to access company users"

### Flow 5: Managing Company Users (Transporter)

1. Transporter logs in (has all permissions)
2. Transporter navigates to More tab
3. Transporter sees "Company & users" menu item
4. Transporter taps menu item → navigates to CompanyUsersScreen
5. Transporter can:
   - View all company users
   - Create new company user
   - Edit company user (including permissions)
   - Set PIN for company user
   - Toggle access for company user
   - Delete company user

---

## Security Considerations

### Backend Enforcement

1. **All API endpoints validate permissions** - Frontend checks are for UX only
2. **Company users can only access their transporter's data** - Filtered by `transporterId`
3. **Company users cannot modify their own permissions** - Only transporter can
4. **Company users cannot delete the main transporter account** - Protected in backend
5. **JWT tokens include userType and permissions** - Validated on every request

### Frontend Checks

1. **Navigation items hidden** - Users don't see unauthorized options
2. **Action buttons hidden** - Users can't trigger unauthorized actions
3. **Screen-level protection** - Unauthorized access redirects user
4. **Permission service** - Centralized permission checking logic

### Socket.IO

- Company users connect using their `transporterId`
- They receive real-time updates for their transporter's data
- Updates are filtered by transporterId on the backend

---

## Testing Checklist

- [x] Company user can login with mobile + PIN
- [x] Company user receives JWT token with correct userType
- [x] Company user can access permitted features
- [x] Company user cannot access restricted features
- [x] Company user sees only their transporter's data
- [x] Fuel cards integration works end-to-end
- [x] Company users management works end-to-end
- [x] Permission checks work correctly
- [x] Main transporter account has full access
- [x] Socket.IO works for company users (uses transporter ID)

---

## Files Modified/Created

### App Files

1. `lib/services/auth_service.dart` - Added `companyUserLogin` method
2. `lib/providers/auth_provider.dart` - Added `loginAsCompanyUser` method
3. `lib/data/models/auth_response_model.dart` - Added `permissions` and `transporterId` fields
4. `lib/screens/pin_login.dart` - Added company user login toggle
5. `lib/services/permission_service.dart` - **NEW** - Permission checking service
6. `lib/screens/tabs/more_tab.dart` - Permission-based menu items
7. `lib/screens/tabs/trips_tab.dart` - Permission check for create trip button
8. `lib/screens/tabs/drivers_tab.dart` - Permission check for add driver button
9. `lib/screens/tabs/home_tab.dart` - Permission check for create trip button
10. `lib/screens/create_trip.dart` - Permission check at screen level
11. `lib/screens/vehicles/vehicles_list_screen.dart` - Permission check at screen level
12. `lib/screens/wallet.dart` - Permission check at screen level
13. `lib/screens/fuel_cards.dart` - Permission check at screen level
14. `lib/screens/company_users/company_users_screen.dart` - Permission check at screen level

---

## Summary

The integration successfully enables:

1. **Company User Authentication**: Company users can login with mobile + PIN
2. **Permission-Based Access Control**: UI elements and screens are protected by permissions
3. **Fuel Cards Management**: Company users with `manageFuelCards` permission can manage fuel cards
4. **Company Users Management**: Transporters can create and manage company users with specific permissions
5. **Data Isolation**: Company users only see and access their transporter's data
6. **Security**: Backend enforces all permissions; frontend provides UX improvements

The system is production-ready and follows security best practices with both frontend and backend permission validation.
