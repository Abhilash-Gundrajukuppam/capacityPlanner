# Capacity Planner - Salesforce Application

A comprehensive **Capacity Planning System** built on Salesforce that enables team managers to track team capacity, manage leave requests, and plan sprint resources effectively.

## Overview

This application provides:
- **Email-based Authentication** - No Salesforce User licenses required for team members
- **Leave Request Management** - Submit, approve, reject, and cancel leave requests
- **Sprint Capacity Planning** - Visual grid showing team availability across sprint dates
- **Holiday Management** - Location-based holiday tracking that auto-adjusts capacity
- **Team & Location Management** - Full CRUD operations for team members and locations

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Visualforce Page                              │
│                  (CapacityPlannerHome.page)                     │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   PublicSiteController                          │
│              (Global Apex Controller - @RemoteAction)           │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────────┐  │
│  │ Authentication │ │ Leave Requests │ │ Sprint Capacity    │  │
│  │ Management     │ │ Management     │ │ Planning           │  │
│  └────────────────┘ └────────────────┘ └────────────────────┘  │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────────┐  │
│  │ Team Member    │ │ Location       │ │ Capacity           │  │
│  │ CRUD           │ │ CRUD           │ │ Tracking           │  │
│  └────────────────┘ └────────────────┘ └────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Custom Objects                                │
│  ┌──────────────┐  ┌────────────┐  ┌────────────────────────┐  │
│  │ Team_Member  │  │ Location   │  │ Holiday                │  │
│  └──────┬───────┘  └─────┬──────┘  └────────────┬───────────┘  │
│         │                │                       │              │
│         ▼                ▼                       ▼              │
│  ┌──────────────┐  ┌────────────────────────────────────────┐  │
│  │Leave_Request │  │ Capacity_Tracking ◄─── Sprint          │  │
│  └──────────────┘  └────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Custom Objects

### Team_Member__c
Primary object storing employee information.

| Field | Type | Description |
|-------|------|-------------|
| First_Name__c | Text | First name |
| Last_Name__c | Text | Last name |
| Email__c | Email | Unique email for authentication |
| Role__c | Picklist | Manager / Team Member |
| Status__c | Picklist | Active / Inactive |
| Location__c | Lookup(Location__c) | Work location |
| Manager__c | Lookup(Team_Member__c) | Reporting manager |
| Daily_Capacity_Hours__c | Number | Default: 7.5 |
| Start_Date__c | Date | Employment start date |
| End_Date__c | Date | Employment end date |
| Employee_ID__c | Text | Employee identifier |
| Community_User_Id__c | Text | Optional community user ID |
| Story_Points_Per_Hour__c | Number | Velocity metric |

### Location__c
Work locations with timezone and working hours.

| Field | Type | Description |
|-------|------|-------------|
| Name | Text | Location name |
| Country__c | Text | Country |
| Time_Zone__c | Text | Timezone |
| Is_Active__c | Checkbox | Active status |
| Working_Hours_Start__c | Time | Work day start |
| Working_Hours_End__c | Time | Work day end |

### Holiday__c
Location-specific holidays.

| Field | Type | Description |
|-------|------|-------------|
| Name | Text | Holiday name |
| Start_Date__c | Date | Holiday start |
| End_Date__c | Date | Holiday end |
| Holiday_Type__c | Picklist | Holiday type |
| Location__c | Lookup(Location__c) | Location |
| Is_Active__c | Checkbox | Active status |

### Leave_Request__c
Employee leave requests with approval workflow.

| Field | Type | Description |
|-------|------|-------------|
| Requestor__c | Lookup(Team_Member__c) | Employee requesting leave |
| Manager__c | Lookup(Team_Member__c) | Approving manager |
| Leave_Type__c | Picklist | PTO, Sick, Personal, etc. |
| Leave_Category__c | Picklist | Full Day, Half Day, Hours |
| Start_Date__c | Date | Leave start |
| End_Date__c | Date | Leave end |
| Hours_Requested__c | Formula/Number | Hours per day |
| Is_Single_Day__c | Checkbox | Single day leave flag |
| Reason__c | Long Text | Leave reason |
| Status__c | Picklist | Submitted/Approved/Rejected/Cancelled |
| Manager_Comments__c | Long Text | Manager feedback |
| Cancellation_Reason__c | Long Text | Cancellation reason |

### Sprint__c
Sprint definitions for capacity planning.

| Field | Type | Description |
|-------|------|-------------|
| Name | Text | Sprint name |
| Start_Date__c | Date | Sprint start |
| End_Date__c | Date | Sprint end |
| Is_Active__c | Checkbox | Active status |
| Created_By__c | Lookup(Team_Member__c) | Creator |

### Capacity_Tracking__c
Daily capacity records per team member per sprint.

| Field | Type | Description |
|-------|------|-------------|
| Team_Member__c | Lookup(Team_Member__c) | Team member |
| Sprint__c | Lookup(Sprint__c) | Sprint |
| Date__c | Date | Specific date |
| Base_Hours__c | Number | Standard hours (7.5) |
| Leave_Hours__c | Number | Approved leave hours |
| Holiday_Hours__c | Number | Holiday hours |
| Available_Hours__c | Formula | Calculated availability |
| Is_Manual_Override__c | Checkbox | Manual override flag |
| Manual_Available_Hours__c | Number | Override value |
| Override_Reason__c | Text | Override reason |
| Last_Modified_By_Member__c | Lookup | Last modifier |

## Apex Classes

### PublicSiteController.cls
Main controller with `@RemoteAction` methods for Visualforce JavaScript Remoting.

**Authentication Methods:**
- `validateEmailAndLogin(email)` - Authenticates team member by email

**Leave Request Methods:**
- `submitLeaveRequest(...)` - Submit new leave request
- `getLeaveRequests(email)` - Get user's leave history
- `getTeamMemberRequests(email)` - Get team/peer leave requests
- `cancelLeaveRequest(email, requestId, reason)` - Cancel own request
- `updateLeaveRequest(email, requestId, type, category)` - Update request details
- `getPendingRequests(managerEmail)` - Get pending approvals (managers)
- `approveLeaveRequest(managerEmail, requestId, comments)` - Approve request
- `rejectLeaveRequest(managerEmail, requestId, comments)` - Reject request

**Team Member Methods:**
- `getCurrentTeamMember(email)` - Get current user details
- `getTeamMembers(managerEmail)` - Get manager's direct reports
- `createTeamMember(...)` - Create new team member
- `updateTeamMember(managerEmail, memberId, fieldsJson)` - Update team member
- `getManagers(email)` - Get list of all managers

**Location Methods:**
- `getLocations(managerEmail)` - Get all locations
- `createLocation(...)` - Create new location
- `updateLocation(managerEmail, locationId, fieldsJson)` - Update location

**Sprint Methods:**
- `getSprints(managerEmail)` - Get all sprints
- `createSprint(managerEmail, name, startDate, endDate)` - Create sprint
- `updateSprint(...)` - Update sprint
- `deleteSprint(managerEmail, sprintId)` - Delete sprint

**Capacity Planning Methods:**
- `getSprintGridData(managerEmail, sprintId)` - Get capacity grid data
- `updateCapacityCell(managerEmail, recordId, hours, reason)` - Manual override
- `refreshSprintCapacity(managerEmail, sprintId, forceRecalculate)` - Recalculate capacity
- `getCapacityData(email, startDate, endDate)` - Get capacity data range
- `calculateAndRefreshCapacity(requestDataJson)` - Bulk capacity calculation

**Other Methods:**
- `getManagerDashboardData(managerEmail)` - Manager dashboard data
- `getUpcomingHolidays(email)` - Location-based holidays

### LeaveRequestTriggerHandler.cls
Handles leave request trigger logic for capacity recalculation.

### CapacityCalculationService.cls
Service class for capacity calculation business logic.

## Deployment

### Prerequisites
- Salesforce CLI installed
- Authenticated to target org

### Deploy to Org
```bash
# Deploy all metadata
sf project deploy start --target-org <your-org-alias>

# Deploy specific components
sf project deploy start --source-dir force-app/main/default/objects --target-org <your-org-alias>
sf project deploy start --source-dir force-app/main/default/classes --target-org <your-org-alias>
```

### Retrieve from Org
```bash
sf project retrieve start --target-org <your-org-alias>
```

## Site Configuration

### Create Experience Cloud Site
1. Navigate to **Setup → Digital Experiences → All Sites**
2. Click **New** → Select **Build Your Own**
3. Site name: `Capacity Planner`
4. URL prefix: `capacity-planner`

### Configure Guest User Profile
1. Go to site **Settings → General**
2. Configure guest user profile with access to:
   - `PublicSiteController` Apex class
   - Required custom objects (read/write as needed)

### Add Visualforce Page to Site
1. In Experience Builder, add the `CapacityPlannerHome` Visualforce page
2. Publish the site

## User Guide

### Team Members
1. Access the site URL
2. Enter email address to login
3. View dashboard with personal capacity and leave history
4. Submit new leave requests
5. View team calendar (peers under same manager)
6. Cancel or update pending/approved requests

### Managers
1. Access site with manager email
2. View team roster with all direct reports
3. Review and approve/reject pending leave requests
4. Access Sprint Capacity Planner:
   - Create/edit sprints with date validation
   - View capacity grid showing team availability
   - Manual override for specific dates
   - Auto-calculation of holidays and approved leaves
5. Manage team members and locations

## Capacity Grid Features

The sprint capacity grid provides:
- **Visual Status Indicators:**
  - Weekend (gray) - Non-working days
  - Holiday (purple) - Location holidays
  - Leave (red) - Full day leave
  - Partial (orange) - Partial day leave
  - Override (blue) - Manual adjustments
  - Normal (green) - Available capacity

- **Auto-Calculations:**
  - Weekends automatically set to 0 hours
  - Holidays based on team member location
  - Approved leaves deducted from capacity
  - Partial leaves show remaining availability

- **Manual Overrides:**
  - Click editable cells to adjust hours
  - Add reason for audit trail
  - Refresh to recalculate (preserves or clears overrides)

## Project Structure

```
capacityplanner/
├── force-app/main/default/
│   ├── classes/
│   │   ├── PublicSiteController.cls
│   │   ├── PublicSiteController.cls-meta.xml
│   │   ├── CapacityCalculationService.cls
│   │   ├── CapacityCalculationService.cls-meta.xml
│   │   ├── LeaveRequestTriggerHandler.cls
│   │   └── LeaveRequestTriggerHandler.cls-meta.xml
│   ├── objects/
│   │   ├── Team_Member__c/
│   │   ├── Location__c/
│   │   ├── Holiday__c/
│   │   ├── Leave_Request__c/
│   │   ├── Sprint__c/
│   │   └── Capacity_Tracking__c/
│   ├── pages/
│   │   ├── CapacityPlannerHome.page
│   │   └── CapacityPlannerHome.page-meta.xml
│   ├── triggers/
│   │   ├── LeaveRequestTrigger.trigger
│   │   └── LeaveRequestTrigger.trigger-meta.xml
│   ├── sites/
│   ├── tabs/
│   └── layouts/
├── config/
│   └── project-scratch-def.json
├── manifest/
│   └── package.xml
└── sfdx-project.json
```

## Security Considerations

- **No User Licenses Required:** Team members authenticate via email without Salesforce User records
- **Role-Based Access:** Managers have additional capabilities (approvals, team management)
- **Data Isolation:** Team members can only see their data and peers under same manager
- **`without sharing`:** Controller runs without sharing for guest user access
- **Circular Relationship Prevention:** Manager assignment validates hierarchy

## License

This project is proprietary software developed for internal use.
