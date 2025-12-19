//_______________This Code was generated using GenAI tool: Codify, Please check for accuracy_______________//
global without sharing class PublicSiteController {
    
    // Property to support any page references
    public Team_Member__c member { get; set; }
    
    /**
     * Validates email address and logs in the user if email exists
     * @param email The email address to validate
     * @return ResponseWrapper containing success status and team member data
     */
    @AuraEnabled
    @RemoteAction
    public static ResponseWrapper validateEmailAndLogin(String email) {
        try {
            if (String.isBlank(email)) {
                return new ResponseWrapper(false, 'Please enter your email address.');
            }
            
            // Check if team member exists with this email
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c, Role__c, Status__c, Location__c
                FROM Team_Member__c 
                WHERE Email__c = :email AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Email not found in our system. Please contact your manager to be added to the project.');
            }
            
            // Return team member data for successful login
            ResponseWrapper response = new ResponseWrapper(true, 'Login successful. Welcome back!');
            response.teamMember = teamMembers[0];
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in validateEmailAndLogin: ' + e.getMessage());
            return new ResponseWrapper(false, 'An error occurred during login. Please try again.');
        }
    }
    
    /**
     * Verifies the provided code against the email address
     * @param email The email address
     * @param code The verification code
     * @return ResponseWrapper containing success status and team member data
     */
    @RemoteAction
    public static ResponseWrapper verifyCode(String email, String code) {
        try {
            if (String.isBlank(email) || String.isBlank(code)) {
                return new ResponseWrapper(false, 'Please enter both email and verification code.');
            }
            
            // Check for valid verification code
            List<Email_Verification__c> verifications = [
                SELECT Id, Verification_Code__c, Expiry_DateTime__c
                FROM Email_Verification__c 
                WHERE Email__c = :email
                AND Expiry_DateTime__c > :DateTime.now()
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (verifications.isEmpty()) {
                return new ResponseWrapper(false, 'Verification code has expired or does not exist. Please request a new code.');
            }
            
            Email_Verification__c verification = verifications[0];
            
            if (!verification.Verification_Code__c.equals(code)) {
                return new ResponseWrapper(false, 'Invalid verification code. Please try again.');
            }
            
            // Get team member data
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c, Role__c, Status__c, Location__c
                FROM Team_Member__c 
                WHERE Email__c = :email AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found or inactive.');
            }
            
            // Delete the used verification code
            delete verification;
            
            ResponseWrapper response = new ResponseWrapper(true, 'Verification successful.');
            response.teamMember = teamMembers[0];
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in verifyCode: ' + e.getMessage());
            return new ResponseWrapper(false, 'An error occurred during verification. Please try again.');
        }
    }
    
    /**
     * Submits a leave request for a team member identified by email
     * @param teamMemberEmail The email of the team member
     * @param leaveType The type of leave being requested
     * @param leaveCategory The category of leave
     * @param startDateStr The start date of the leave (YYYY-MM-DD format)
     * @param endDateStr The end date of the leave (YYYY-MM-DD format)
     * @param hoursRequested Number of hours requested
     * @param reason The reason for the leave request
     * @param isSingleDay Whether this is a single day request
     * @return ResponseWrapper containing success status and message
     */
    @RemoteAction
    public static ResponseWrapper submitLeaveRequest(
        String teamMemberEmail,
        String leaveType,
        String leaveCategory,
        String startDateStr,
        String endDateStr,
        Decimal hoursRequested,
        String reason,
        Boolean isSingleDay
    ) {
        try {
            // Validate required fields
            if (String.isBlank(teamMemberEmail) || String.isBlank(leaveType) || 
                String.isBlank(leaveCategory) || String.isBlank(startDateStr) || String.isBlank(reason)) {
                return new ResponseWrapper(false, 'Please fill in all required fields.');
            }
            
            // Convert date strings to Date objects
            Date startDate;
            Date endDate;
            
            try {
                startDate = Date.valueOf(startDateStr);
                if (String.isNotBlank(endDateStr)) {
                    endDate = Date.valueOf(endDateStr);
                }
            } catch (Exception dateEx) {
                return new ResponseWrapper(false, 'Invalid date format. Please use YYYY-MM-DD format.');
            }
            
            // Get team member by email
            List<Team_Member__c> teamMembers = [
                SELECT Id, Manager__c, First_Name__c, Last_Name__c, Email__c, Status__c
                FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found or inactive.');
            }
            
            Team_Member__c teamMember = teamMembers[0];
            
            // Validate dates
            if (endDate != null && endDate < startDate) {
                return new ResponseWrapper(false, 'End date cannot be before start date.');
            }
            
            // Set end date for single day requests
            if (isSingleDay) {
                endDate = startDate;
            }
            
            // Create leave request (Hours_Requested__c is auto-calculated by formula field)
            Leave_Request__c leaveRequest = new Leave_Request__c(
                Requestor__c = teamMember.Id,
                Manager__c = teamMember.Manager__c,
                Leave_Type__c = leaveType,
                Leave_Category__c = leaveCategory,
                Start_Date__c = startDate,
                End_Date__c = endDate,
                Reason__c = reason,
                Is_Single_Day__c = isSingleDay,
                Status__c = 'Submitted'
            );
            
            insert leaveRequest;
            
            return new ResponseWrapper(true, 'Leave request submitted successfully. You will be notified once your manager reviews it.');
            
        } catch (DmlException e) {
            System.debug('DML Error in submitLeaveRequest: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in submitLeaveRequest: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new ResponseWrapper(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Gets leave requests for a team member by email
     * @param teamMemberEmail The email of the team member
     * @return ResponseWrapper containing leave request data
     */
    @RemoteAction
    public static ResponseWrapper getLeaveRequests(String teamMemberEmail) {
        try {
            if (String.isBlank(teamMemberEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get team member
            List<Team_Member__c> teamMembers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found.');
            }
            
            // Get leave requests
            List<Leave_Request__c> leaveRequests = [
                SELECT Id, Leave_Type__c, Leave_Category__c, Start_Date__c, End_Date__c, 
                       Hours_Requested__c, Status__c, Reason__c, Manager_Comments__c, 
                       Is_Single_Day__c, CreatedDate
                FROM Leave_Request__c 
                WHERE Requestor__c = :teamMembers[0].Id
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Leave requests retrieved successfully.');
            response.leaveRequests = leaveRequests;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getLeaveRequests: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving leave requests.');
        }
    }
    
    /**
     * Gets all team leave requests for team members under the same manager (for team members)
     * or direct reports (for managers)
     * @param teamMemberEmail The email of the team member or manager
     * @return ResponseWrapper containing team member requests data
     */
    @RemoteAction
    public static ResponseWrapper getTeamMemberRequests(String teamMemberEmail) {
        try {
            if (String.isBlank(teamMemberEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get current team member with role and manager info
            List<Team_Member__c> currentTeamMembers = [
                SELECT Id, Manager__c, Role__c FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (currentTeamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found.');
            }
            
            Team_Member__c currentMember = currentTeamMembers[0];
            Set<Id> teamMemberIds = new Set<Id>();
            
            // Check if current user is a Manager
            if (currentMember.Role__c == 'Manager') {
                // For managers: Get all team members who report to this manager (direct reports)
                for (Team_Member__c member : [
                    SELECT Id FROM Team_Member__c 
                    WHERE Manager__c = :currentMember.Id AND Status__c = 'Active'
                ]) {
                    teamMemberIds.add(member.Id);
                }
                
                // If no direct reports found
                if (teamMemberIds.isEmpty()) {
                    ResponseWrapper response = new ResponseWrapper(true, 'No team members found under your management.');
                    response.teamMemberRequests = new List<Leave_Request__c>();
                    return response;
                }
            } else {
                // For team members: Get all team members under the same manager (peers)
                // If no manager, only return own requests
                if (currentMember.Manager__c == null) {
                    List<Leave_Request__c> ownRequests = [
                        SELECT Id, Leave_Type__c, Leave_Category__c, Start_Date__c, End_Date__c, 
                               Hours_Requested__c, Status__c, Reason__c, CreatedDate,
                               Requestor__r.First_Name__c, Requestor__r.Last_Name__c
                        FROM Leave_Request__c 
                        WHERE Requestor__c = :currentMember.Id
                        ORDER BY Start_Date__c DESC
                        LIMIT 100
                    ];
                    
                    ResponseWrapper response = new ResponseWrapper(true, 'Team member requests retrieved successfully.');
                    response.teamMemberRequests = ownRequests;
                    return response;
                }
                
                // Get all team members under the same manager (including current user)
                for (Team_Member__c member : [
                    SELECT Id FROM Team_Member__c 
                    WHERE Manager__c = :currentMember.Manager__c AND Status__c = 'Active'
                ]) {
                    teamMemberIds.add(member.Id);
                }
            }
            
            // Get all leave requests for the identified team members
            List<Leave_Request__c> teamRequests = [
                SELECT Id, Leave_Type__c, Leave_Category__c, Start_Date__c, End_Date__c, 
                       Hours_Requested__c, Status__c, Reason__c, CreatedDate,
                       Requestor__r.First_Name__c, Requestor__r.Last_Name__c
                FROM Leave_Request__c 
                WHERE Requestor__c IN :teamMemberIds
                ORDER BY Start_Date__c DESC
                LIMIT 200
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Team member requests retrieved successfully.');
            response.teamMemberRequests = teamRequests;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getTeamMemberRequests: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving team member requests.');
        }
    }
    
    /**
     * Gets current team member details by email
     * @param teamMemberEmail The email of the team member
     * @return ResponseWrapper containing team member data
     */
    @RemoteAction
    public static ResponseWrapper getCurrentTeamMember(String teamMemberEmail) {
        try {
            if (String.isBlank(teamMemberEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get team member
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c, Role__c, Status__c, Location__c,
                       Start_Date__c, End_Date__c, Daily_Capacity_Hours__c
                FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found.');
            }
            
            ResponseWrapper response = new ResponseWrapper(true, 'Team member retrieved successfully.');
            response.teamMember = teamMembers[0];
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getCurrentTeamMember: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving team member data.');
        }
    }
    
    /**
     * Gets capacity tracking data for a team member by email
     * @param teamMemberEmail The email of the team member
     * @param startDate The start date for capacity data
     * @param endDate The end date for capacity data
     * @return ResponseWrapper containing capacity data
     */
    @AuraEnabled
    public static ResponseWrapper getCapacityData(String teamMemberEmail, Date startDate, Date endDate) {
        try {
            if (String.isBlank(teamMemberEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get team member
            List<Team_Member__c> teamMembers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found.');
            }
            
            // Set default date range if not provided
            if (startDate == null) {
                startDate = Date.today().toStartOfMonth();
            }
            if (endDate == null) {
                endDate = startDate.addMonths(1).addDays(-1);
            }
            
            // Get capacity tracking data
            List<Capacity_Tracking__c> capacityData = [
                SELECT Id, Date__c, Base_Hours__c, Leave_Hours__c, Holiday_Hours__c, Available_Hours__c
                FROM Capacity_Tracking__c 
                WHERE Team_Member__c = :teamMembers[0].Id
                AND Date__c >= :startDate
                AND Date__c <= :endDate
                ORDER BY Date__c ASC
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Capacity data retrieved successfully.');
            response.capacityData = capacityData;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getCapacityData: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving capacity data.');
        }
    }
    
    /**
     * Gets upcoming holidays for a team member's location
     * @param teamMemberEmail The email of the team member
     * @return ResponseWrapper containing holiday data
     */
    @AuraEnabled
    public static ResponseWrapper getUpcomingHolidays(String teamMemberEmail) {
        try {
            if (String.isBlank(teamMemberEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get team member with location
            List<Team_Member__c> teamMembers = [
                SELECT Id, Location__c FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found.');
            }
            
            // Get holidays for team member's location
            List<Holiday__c> holidays = [
                SELECT Id, Name, Start_Date__c, End_Date__c, Holiday_Type__c
                FROM Holiday__c 
                WHERE Location__c = :teamMembers[0].Location__c
                AND Is_Active__c = true
                AND Start_Date__c >= :Date.today()
                ORDER BY Start_Date__c ASC
                LIMIT 10
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Holidays retrieved successfully.');
            response.holidays = holidays;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getUpcomingHolidays: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving holidays.');
        }
    }
    
    /**
     * Gets team members for a manager identified by email
     * @param managerEmail The email of the manager
     * @return ResponseWrapper containing team members data
     */
    @RemoteAction
    public static ResponseWrapper getTeamMembers(String managerEmail) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get manager team member record
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get team members under this manager with location and manager details
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c, Role__c, Status__c,
                       Location__c, Location__r.Name, Location__r.Country__c,
                       Manager__c, Manager__r.First_Name__c, Manager__r.Last_Name__c,
                       Daily_Capacity_Hours__c, Start_Date__c
                FROM Team_Member__c 
                WHERE Manager__c = :managers[0].Id
                ORDER BY First_Name__c, Last_Name__c
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Team members retrieved successfully.');
            response.teamMembers = teamMembers;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getTeamMembers: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving team members.');
        }
    }
    
    /**
     * Gets manager dashboard data for a manager identified by email
     * @param managerEmail The email of the manager
     * @return ResponseWrapper containing manager dashboard data
     */
    @AuraEnabled
    public static ResponseWrapper getManagerDashboardData(String managerEmail) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get manager team member record
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get team members under this manager
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c, Role__c, Status__c
                FROM Team_Member__c 
                WHERE Manager__c = :managers[0].Id AND Status__c = 'Active'
                ORDER BY First_Name__c, Last_Name__c
            ];
            
            // Get pending leave requests for this manager
            List<Leave_Request__c> pendingRequests = [
                SELECT Id, Requestor__r.First_Name__c, Requestor__r.Last_Name__c,
                       Leave_Type__c, Start_Date__c, End_Date__c, Hours_Requested__c, 
                       Reason__c, CreatedDate
                FROM Leave_Request__c 
                WHERE Manager__c = :managers[0].Id AND Status__c = 'Submitted'
                ORDER BY CreatedDate ASC
                LIMIT 20
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Manager dashboard data retrieved successfully.');
            response.teamMembers = teamMembers;
            response.pendingRequests = pendingRequests;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getManagerDashboardData: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving manager dashboard data.');
        }
    }
    
    /**
     * Gets pending leave requests for a manager identified by email
     * @param managerEmail The email of the manager
     * @return ResponseWrapper containing pending leave requests
     */
    @RemoteAction
    public static ResponseWrapper getPendingRequests(String managerEmail) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Get manager team member record
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get pending leave requests for this manager with requestor details
            List<Leave_Request__c> pendingRequests = [
                SELECT Id, Requestor__r.First_Name__c, Requestor__r.Last_Name__c,
                       Requestor__r.Email__c, Leave_Type__c, Leave_Category__c,
                       Start_Date__c, End_Date__c, Hours_Requested__c, 
                       Reason__c, Is_Single_Day__c, CreatedDate
                FROM Leave_Request__c 
                WHERE Manager__c = :managers[0].Id AND Status__c = 'Submitted'
                ORDER BY CreatedDate ASC
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Pending requests retrieved successfully.');
            response.pendingRequests = pendingRequests;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getPendingRequests: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving pending requests.');
        }
    }
    
    /**
     * Approves a leave request
     * @param managerEmail The email of the manager
     * @param leaveRequestId The ID of the leave request to approve
     * @param comments Optional manager comments
     * @return ResponseWrapper containing success status and message
     */
    @RemoteAction
    public static ResponseWrapper approveLeaveRequest(String managerEmail, String leaveRequestId, String comments) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(leaveRequestId)) {
                return new ResponseWrapper(false, 'Manager email and leave request ID are required.');
            }
            
            // Get manager team member record
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get leave request and verify manager authorization
            List<Leave_Request__c> leaveRequests = [
                SELECT Id, Status__c, Requestor__r.First_Name__c, Requestor__r.Last_Name__c
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId AND Manager__c = :managers[0].Id
                LIMIT 1
            ];
            
            if (leaveRequests.isEmpty()) {
                return new ResponseWrapper(false, 'Leave request not found or you are not authorized to approve it.');
            }
            
            Leave_Request__c leaveRequest = leaveRequests[0];
            
            if (leaveRequest.Status__c != 'Submitted') {
                return new ResponseWrapper(false, 'This leave request has already been processed.');
            }
            
            // Update leave request
            leaveRequest.Status__c = 'Approved';
            if (String.isNotBlank(comments)) {
                leaveRequest.Manager_Comments__c = comments;
            }
            
            update leaveRequest;
            
            String requestorName = leaveRequest.Requestor__r.First_Name__c + ' ' + leaveRequest.Requestor__r.Last_Name__c;
            return new ResponseWrapper(true, 'Leave request for ' + requestorName + ' has been approved successfully.');
            
        } catch (DmlException e) {
            System.debug('DML Error in approveLeaveRequest: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in approveLeaveRequest: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Rejects a leave request
     * @param managerEmail The email of the manager
     * @param leaveRequestId The ID of the leave request to reject
     * @param comments Required manager comments for rejection
     * @return ResponseWrapper containing success status and message
     */
    @RemoteAction
    public static ResponseWrapper rejectLeaveRequest(String managerEmail, String leaveRequestId, String comments) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(leaveRequestId)) {
                return new ResponseWrapper(false, 'Manager email and leave request ID are required.');
            }
            
            if (String.isBlank(comments)) {
                return new ResponseWrapper(false, 'Comments are required when rejecting a leave request.');
            }
            
            // Get manager team member record
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get leave request and verify manager authorization
            List<Leave_Request__c> leaveRequests = [
                SELECT Id, Status__c, Requestor__r.First_Name__c, Requestor__r.Last_Name__c
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId AND Manager__c = :managers[0].Id
                LIMIT 1
            ];
            
            if (leaveRequests.isEmpty()) {
                return new ResponseWrapper(false, 'Leave request not found or you are not authorized to reject it.');
            }
            
            Leave_Request__c leaveRequest = leaveRequests[0];
            
            if (leaveRequest.Status__c != 'Submitted') {
                return new ResponseWrapper(false, 'This leave request has already been processed.');
            }
            
            // Update leave request
            leaveRequest.Status__c = 'Rejected';
            leaveRequest.Manager_Comments__c = comments;
            
            update leaveRequest;
            
            String requestorName = leaveRequest.Requestor__r.First_Name__c + ' ' + leaveRequest.Requestor__r.Last_Name__c;
            return new ResponseWrapper(true, 'Leave request for ' + requestorName + ' has been rejected.');
            
        } catch (DmlException e) {
            System.debug('DML Error in rejectLeaveRequest: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in rejectLeaveRequest: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Cancels a leave request by the team member
     * @param teamMemberEmail The email of the team member
     * @param leaveRequestId The ID of the leave request to cancel
     * @param cancellationReason The reason for cancellation (required)
     * @return ResponseWrapper containing success status and message
     */
    @RemoteAction
    public static ResponseWrapper cancelLeaveRequest(String teamMemberEmail, String leaveRequestId, String cancellationReason) {
        try {
            if (String.isBlank(teamMemberEmail) || String.isBlank(leaveRequestId)) {
                return new ResponseWrapper(false, 'Email and leave request ID are required.');
            }
            
            if (String.isBlank(cancellationReason)) {
                return new ResponseWrapper(false, 'Cancellation reason is required.');
            }
            
            // Get team member
            List<Team_Member__c> teamMembers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found or inactive.');
            }
            
            // Get leave request and verify ownership
            List<Leave_Request__c> leaveRequests = [
                SELECT Id, Status__c, Requestor__c, Leave_Type__c, Start_Date__c, End_Date__c
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId AND Requestor__c = :teamMembers[0].Id
                LIMIT 1
            ];
            
            if (leaveRequests.isEmpty()) {
                return new ResponseWrapper(false, 'Leave request not found or you are not authorized to cancel it.');
            }
            
            Leave_Request__c leaveRequest = leaveRequests[0];
            
            // Only allow cancellation for Submitted or Approved requests
            if (leaveRequest.Status__c != 'Submitted' && leaveRequest.Status__c != 'Approved') {
                return new ResponseWrapper(false, 'Only Submitted or Approved leave requests can be cancelled. Current status: ' + leaveRequest.Status__c);
            }
            
            // Update leave request to Cancelled
            leaveRequest.Status__c = 'Cancelled';
            leaveRequest.Cancellation_Reason__c = cancellationReason;
            
            update leaveRequest;
            
            return new ResponseWrapper(true, 'Leave request for ' + leaveRequest.Leave_Type__c + ' (' + leaveRequest.Start_Date__c.format() + ' - ' + leaveRequest.End_Date__c.format() + ') has been cancelled successfully.');
            
        } catch (DmlException e) {
            System.debug('DML Error in cancelLeaveRequest: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in cancelLeaveRequest: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Updates a leave request (only type and category allowed)
     * @param teamMemberEmail The email of the team member
     * @param leaveRequestId The ID of the leave request to update
     * @param leaveType The new leave type
     * @param leaveCategory The new leave category
     * @return ResponseWrapper containing success status and message
     */
    @RemoteAction
    public static ResponseWrapper updateLeaveRequest(String teamMemberEmail, String leaveRequestId, String leaveType, String leaveCategory) {
        try {
            if (String.isBlank(teamMemberEmail) || String.isBlank(leaveRequestId)) {
                return new ResponseWrapper(false, 'Email and leave request ID are required.');
            }
            
            if (String.isBlank(leaveType) || String.isBlank(leaveCategory)) {
                return new ResponseWrapper(false, 'Leave type and category are required.');
            }
            
            // Get team member
            List<Team_Member__c> teamMembers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :teamMemberEmail AND Status__c = 'Active'
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found or inactive.');
            }
            
            // Get leave request and verify ownership
            List<Leave_Request__c> leaveRequests = [
                SELECT Id, Status__c, Requestor__c, Leave_Type__c, Leave_Category__c
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId AND Requestor__c = :teamMembers[0].Id
                LIMIT 1
            ];
            
            if (leaveRequests.isEmpty()) {
                return new ResponseWrapper(false, 'Leave request not found or you are not authorized to update it.');
            }
            
            Leave_Request__c leaveRequest = leaveRequests[0];
            
            // Only allow updates for Submitted or Approved requests
            if (leaveRequest.Status__c != 'Submitted' && leaveRequest.Status__c != 'Approved') {
                return new ResponseWrapper(false, 'Only Submitted or Approved leave requests can be edited. Current status: ' + leaveRequest.Status__c);
            }
            
            // Update only type and category
            leaveRequest.Leave_Type__c = leaveType;
            leaveRequest.Leave_Category__c = leaveCategory;
            
            update leaveRequest;
            
            return new ResponseWrapper(true, 'Leave request updated successfully.');
            
        } catch (DmlException e) {
            System.debug('DML Error in updateLeaveRequest: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in updateLeaveRequest: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Gets capacity data for a manager's team for a specific week
     * @param managerEmail The email of the manager
     * @param startDate The start date of the week (YYYY-MM-DD format)
     * @return ResponseWrapper containing capacity data
     */
    @RemoteAction
    public static ResponseWrapper getCapacityData(String managerEmail, String startDate) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Manager email is required.');
            }
            
            // Get manager team member record
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Parse start date
            Date weekStart;
            if (String.isNotBlank(startDate)) {
                try {
                    weekStart = Date.valueOf(startDate);
                } catch (Exception e) {
                    weekStart = Date.today().toStartOfWeek();
                }
            } else {
                weekStart = Date.today().toStartOfWeek();
            }
            
            Date weekEnd = weekStart.addDays(6);
            
            // Get team members under this manager
            List<Team_Member__c> teamMembers = [
                SELECT Id FROM Team_Member__c 
                WHERE Manager__c = :managers[0].Id AND Status__c = 'Active'
            ];
            
            Set<Id> teamMemberIds = new Set<Id>();
            for (Team_Member__c member : teamMembers) {
                teamMemberIds.add(member.Id);
            }
            
            // Get capacity tracking data for the week
            List<Capacity_Tracking__c> capacityRecords = [
                SELECT Id, Team_Member__c, Date__c, Available_Hours__c
                FROM Capacity_Tracking__c 
                WHERE Team_Member__c IN :teamMemberIds
                AND Date__c >= :weekStart
                AND Date__c <= :weekEnd
                ORDER BY Team_Member__c, Date__c
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Capacity data retrieved successfully.');
            response.capacityData = capacityRecords;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getCapacityData: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving capacity data: ' + e.getMessage());
        }
    }
    
    /**
     * Calculate and refresh capacity for a team member
     * @param requestData JSON string containing team member ID, dates, and capacity hours
     * @return ResponseWrapper containing calculation results
     */
    @RemoteAction
    public static ResponseWrapper calculateAndRefreshCapacity(String requestData) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(requestData);
            
            Id teamMemberId = (Id) data.get('teamMemberId');
            Date startDate = Date.valueOf((String) data.get('startDate'));
            Date endDate = Date.valueOf((String) data.get('endDate'));
            Decimal dailyCapHours = (Decimal) data.get('dailyCapHours');
            
            // Validate inputs
            if (startDate == null) {
                return new ResponseWrapper(false, 'Start date is required');
            }
            
            if (endDate == null) {
                return new ResponseWrapper(false, 'End date is required');
            }
            
            if (startDate > endDate) {
                return new ResponseWrapper(false, 'Start date cannot be after end date');
            }
            
            if (dailyCapHours == null || dailyCapHours <= 0) {
                return new ResponseWrapper(false, 'Daily capacity hours must be greater than 0');
            }
            
            if (dailyCapHours > 24) {
                return new ResponseWrapper(false, 'Daily capacity hours cannot exceed 24 hours');
            }
            
            // Prevent excessive date ranges
            if (startDate.daysBetween(endDate) > 365) {
                return new ResponseWrapper(false, 'Date range cannot exceed 365 days');
            }
            
            // Get existing capacity tracking records in date range
            Map<Date, Capacity_Tracking__c> existingRecords = new Map<Date, Capacity_Tracking__c>();
            for (Capacity_Tracking__c record : [
                SELECT Id, Date__c, Leave_Hours__c, Holiday_Hours__c, Base_Hours__c
                FROM Capacity_Tracking__c 
                WHERE Team_Member__c = :teamMemberId 
                AND Date__c >= :startDate AND Date__c <= :endDate
            ]) {
                existingRecords.put(record.Date__c, record);
            }
            
            // Get holidays in date range for team member's location
            Set<Date> holidays = getHolidaysForTeamMember(teamMemberId, startDate, endDate);
            
            // Generate/update records for each date
            List<Capacity_Tracking__c> recordsToUpsert = new List<Capacity_Tracking__c>();
            List<String> affectedDates = new List<String>();
            Integer recordsCreated = 0;
            Integer recordsUpdated = 0;
            
            Date currentDate = startDate;
            while (currentDate <= endDate) {
                Capacity_Tracking__c record = existingRecords.get(currentDate);
                Boolean isNewRecord = (record == null);
                
                if (record == null) {
                    // Create new record
                    record = new Capacity_Tracking__c();
                    record.Team_Member__c = teamMemberId;
                    record.Date__c = currentDate;
                    record.Leave_Hours__c = 0;
                    record.Holiday_Hours__c = holidays.contains(currentDate) ? dailyCapHours : 0;
                    recordsCreated++;
                } else {
                    recordsUpdated++;
                }
                
                // Update base hours (Available_Hours__c is calculated automatically via formula field)
                record.Base_Hours__c = dailyCapHours;
                
                recordsToUpsert.add(record);
                affectedDates.add(currentDate.format());
                
                currentDate = currentDate.addDays(1);
            }
            
            // Perform upsert
            upsert recordsToUpsert;
            
            // Build success response
            ResponseWrapper response = new ResponseWrapper(true, 'Successfully processed ' + recordsToUpsert.size() + ' capacity records');
            response.recordsCreated = recordsCreated;
            response.recordsUpdated = recordsUpdated;
            response.affectedDates = affectedDates;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in calculateAndRefreshCapacity: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error calculating capacity: ' + e.getMessage());
        }
    }
    
    /**
     * Get holidays for team member's location in date range
     */
    private static Set<Date> getHolidaysForTeamMember(Id teamMemberId, Date startDate, Date endDate) {
        Set<Date> holidayDates = new Set<Date>();
        
        try {
            // Get team member's location
            List<Team_Member__c> teamMembers = [
                SELECT Location__c FROM Team_Member__c WHERE Id = :teamMemberId LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return holidayDates;
            }
            
            Id locationId = teamMembers[0].Location__c;
            if (locationId == null) {
                return holidayDates;
            }
            
            // Query holidays for the location and date range
            List<Holiday__c> holidays = [
                SELECT Start_Date__c, End_Date__c
                FROM Holiday__c 
                WHERE Location__c = :locationId 
                AND Is_Active__c = true
                AND Start_Date__c <= :endDate 
                AND End_Date__c >= :startDate
            ];
            
            // Generate all dates covered by holidays
            for (Holiday__c holiday : holidays) {
                Date holidayStart = holiday.Start_Date__c > startDate ? holiday.Start_Date__c : startDate;
                Date holidayEnd = holiday.End_Date__c < endDate ? holiday.End_Date__c : endDate;
                
                Date currentDate = holidayStart;
                while (currentDate <= holidayEnd) {
                    holidayDates.add(currentDate);
                    currentDate = currentDate.addDays(1);
                }
            }
        } catch (Exception e) {
            System.debug('Error getting holidays: ' + e.getMessage());
        }
        
        return holidayDates;
    }

    /**
     * Saves capacity data for a manager's team
     * @param managerEmail The email of the manager
     * @param capacityDataJson JSON string containing capacity records
     * @return ResponseWrapper containing success status
     */
    @RemoteAction
    public static ResponseWrapper saveCapacityData(String managerEmail, String capacityDataJson) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(capacityDataJson)) {
                return new ResponseWrapper(false, 'Manager email and capacity data are required.');
            }
            
            // Get manager team member record
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Parse capacity data JSON
            List<Object> capacityDataList = (List<Object>) JSON.deserializeUntyped(capacityDataJson);
            
            List<Capacity_Tracking__c> recordsToUpsert = new List<Capacity_Tracking__c>();
            
            for (Object recordObj : capacityDataList) {
                Map<String, Object> recordMap = (Map<String, Object>) recordObj;
                
                String teamMemberId = (String) recordMap.get('teamMemberId');
                String dateStr = (String) recordMap.get('date');
                Decimal hours = (Decimal) recordMap.get('hours');
                
                if (String.isNotBlank(teamMemberId) && String.isNotBlank(dateStr) && hours != null) {
                    Date recordDate = Date.valueOf(dateStr);
                    
                    // Create capacity tracking record
                    Capacity_Tracking__c capacityRecord = new Capacity_Tracking__c(
                        Team_Member__c = teamMemberId,
                        Date__c = recordDate,
                        Base_Hours__c = hours, // Base hours - Available_Hours__c is calculated formula
                        Leave_Hours__c = 0,
                        Holiday_Hours__c = 0
                    );
                    
                    recordsToUpsert.add(capacityRecord);
                }
            }
            
            if (!recordsToUpsert.isEmpty()) {
                // Use upsert with external ID or custom logic for duplicate handling
                upsert recordsToUpsert;
            }
            
            return new ResponseWrapper(true, 'Capacity data saved successfully.');
            
        } catch (Exception e) {
            System.debug('Error in saveCapacityData: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error saving capacity data: ' + e.getMessage());
        }
    }

    // Private helper methods
    
    private static Boolean sendVerificationEmail(String email, String code, String firstName, String role) {
        try {
            // Create email message
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            
            // Set recipient
            mail.setToAddresses(new String[] { email });
            
            // Set role-based subject line
            String emailSubject;
            String emailContent;
            
            if (role == 'Manager') {
                emailSubject = 'Capacity Planner - Verification Code';
                emailContent = buildManagerEmailContent(firstName, code);
            } else {
                emailSubject = 'Leave Request - Verification Code';
                emailContent = buildTeamMemberEmailContent(firstName, code);
            }
            
            mail.setSubject(emailSubject);
            mail.setHtmlBody(emailContent);
            mail.setPlainTextBody(getPlainTextContent(firstName, code, role));
            
            // Set reply-to and display name (uses organization default if not set)
            mail.setSenderDisplayName('Capacity Planning System');
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
            // Check if email was sent successfully
            if (results[0].isSuccess()) {
                System.debug('Verification email sent successfully to: ' + email);
                return true;
            } else {
                System.debug('Failed to send verification email: ' + results[0].getErrors()[0].getMessage());
                return false;
            }
            
        } catch (Exception e) {
            System.debug('Error sending verification email: ' + e.getMessage());
            return false;
        }
    }
    
    private static String buildManagerEmailContent(String firstName, String code) {
        return '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">' +
               '<div style="max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9; border-radius: 8px;">' +
               '<h2 style="color: #0176d3; text-align: center;">Capacity Planner Access</h2>' +
               '<p>Hello ' + firstName + ',</p>' +
               '<p>Your verification code for the <strong>Capacity Planning system</strong> is:</p>' +
               '<div style="text-align: center; margin: 25px 0;">' +
               '<span style="display: inline-block; padding: 15px 25px; background-color: #0176d3; color: white; font-size: 24px; font-weight: bold; border-radius: 5px; letter-spacing: 3px;">' + code + '</span>' +
               '</div>' +
               '<p>This code expires in <strong>15 minutes</strong>. Use this to access team capacity dashboards and approve leave requests.</p>' +
               '<p>If you didn\'t request this code, please contact your administrator.</p>' +
               '<hr style="margin: 25px 0; border: none; border-top: 1px solid #ddd;">' +
               '<p style="font-size: 12px; color: #666; text-align: center;">Best regards,<br>Capacity Planning Team</p>' +
               '</div></body></html>';
    }
    
    private static String buildTeamMemberEmailContent(String firstName, String code) {
        return '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">' +
               '<div style="max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9; border-radius: 8px;">' +
               '<h2 style="color: #16325c; text-align: center;">Leave Request System</h2>' +
               '<p>Hello ' + firstName + ',</p>' +
               '<p>Your verification code to access the <strong>Leave Request system</strong> is:</p>' +
               '<div style="text-align: center; margin: 25px 0;">' +
               '<span style="display: inline-block; padding: 15px 25px; background-color: #16325c; color: white; font-size: 24px; font-weight: bold; border-radius: 5px; letter-spacing: 3px;">' + code + '</span>' +
               '</div>' +
               '<p>This code expires in <strong>15 minutes</strong>. Use this to submit and track your leave requests.</p>' +
               '<p>If you didn\'t request this code, please contact your manager.</p>' +
               '<hr style="margin: 25px 0; border: none; border-top: 1px solid #ddd;">' +
               '<p style="font-size: 12px; color: #666; text-align: center;">Best regards,<br>Leave Request Team</p>' +
               '</div></body></html>';
    }
    
    private static String getPlainTextContent(String firstName, String code, String role) {
        String systemName = (role == 'Manager') ? 'Capacity Planning system' : 'Leave Request system';
        String contactInfo = (role == 'Manager') ? 'administrator' : 'manager';
        
        return 'Hello ' + firstName + ',\n\n' +
               'Your verification code for the ' + systemName + ' is: ' + code + '\n\n' +
               'This code expires in 15 minutes.\n\n' +
               'If you didn\'t request this code, please contact your ' + contactInfo + '.\n\n' +
               'Best regards,\n' +
               ((role == 'Manager') ? 'Capacity Planning Team' : 'Leave Request Team');
    }
    
    // ==================== LOCATION MANAGEMENT METHODS ====================
    
    /**
     * Gets all locations for dropdown selection
     * @param managerEmail The email of the manager (for authorization)
     * @return ResponseWrapper containing locations data
     */
    @RemoteAction
    public static ResponseWrapper getLocations(String managerEmail) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get all locations (including inactive for management view)
            List<Location__c> locations = [
                SELECT Id, Name, Country__c, Is_Active__c, Time_Zone__c, 
                       Working_Hours_Start__c, Working_Hours_End__c
                FROM Location__c 
                ORDER BY Name ASC
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Locations retrieved successfully.');
            response.locations = locations;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getLocations: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving locations: ' + e.getMessage());
        }
    }
    
    /**
     * Creates a new location
     * @param managerEmail The email of the manager
     * @param name Location name (required)
     * @param country Country name
     * @param timeZone Time zone
     * @param workingHoursStart Working hours start time (HH:MM format)
     * @param workingHoursEnd Working hours end time (HH:MM format)
     * @param isActive Whether location is active
     * @return ResponseWrapper containing success status and created location
     */
    @RemoteAction
    public static ResponseWrapper createLocation(String managerEmail, String name, String country, 
                                                  String timeZone, String workingHoursStart, 
                                                  String workingHoursEnd, Boolean isActive) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Manager email is required.');
            }
            
            if (String.isBlank(name)) {
                return new ResponseWrapper(false, 'Location name is required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Check for duplicate location name
            List<Location__c> existingLocations = [
                SELECT Id FROM Location__c 
                WHERE Name = :name
                LIMIT 1
            ];
            
            if (!existingLocations.isEmpty()) {
                return new ResponseWrapper(false, 'A location with this name already exists.');
            }
            
            // Create new location
            Location__c newLocation = new Location__c(
                Name = name,
                Country__c = country,
                Time_Zone__c = timeZone,
                Is_Active__c = isActive != null ? isActive : true
            );
            
            // Parse working hours if provided
            if (String.isNotBlank(workingHoursStart)) {
                newLocation.Working_Hours_Start__c = parseTimeString(workingHoursStart);
            }
            if (String.isNotBlank(workingHoursEnd)) {
                newLocation.Working_Hours_End__c = parseTimeString(workingHoursEnd);
            }
            
            insert newLocation;
            
            ResponseWrapper response = new ResponseWrapper(true, 'Location created successfully.');
            response.location = newLocation;
            
            return response;
            
        } catch (DmlException e) {
            System.debug('DML Error in createLocation: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in createLocation: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error creating location: ' + e.getMessage());
        }
    }
    
    /**
     * Updates an existing location
     * @param managerEmail The email of the manager
     * @param locationId The ID of the location to update
     * @param fieldsJson JSON string containing fields to update
     * @return ResponseWrapper containing success status
     */
    @RemoteAction
    public static ResponseWrapper updateLocation(String managerEmail, String locationId, String fieldsJson) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(locationId)) {
                return new ResponseWrapper(false, 'Manager email and location ID are required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get existing location
            List<Location__c> locations = [
                SELECT Id, Name, Country__c, Is_Active__c, Time_Zone__c, 
                       Working_Hours_Start__c, Working_Hours_End__c
                FROM Location__c 
                WHERE Id = :locationId
                LIMIT 1
            ];
            
            if (locations.isEmpty()) {
                return new ResponseWrapper(false, 'Location not found.');
            }
            
            Location__c location = locations[0];
            
            // Parse fields JSON
            Map<String, Object> fieldsMap = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
            
            // Check for duplicate name if name is being changed
            if (fieldsMap.containsKey('Name')) {
                String newName = (String) fieldsMap.get('Name');
                if (String.isNotBlank(newName) && newName != location.Name) {
                    List<Location__c> duplicateCheck = [
                        SELECT Id FROM Location__c 
                        WHERE Name = :newName AND Id != :locationId
                        LIMIT 1
                    ];
                    if (!duplicateCheck.isEmpty()) {
                        return new ResponseWrapper(false, 'A location with this name already exists.');
                    }
                    location.Name = newName;
                }
            }
            
            // Check if deactivating a location that's in use
            if (fieldsMap.containsKey('Is_Active__c')) {
                Boolean newIsActive = (Boolean) fieldsMap.get('Is_Active__c');
                if (newIsActive == false && location.Is_Active__c == true) {
                    // Check if any team members use this location
                    Integer teamMemberCount = [
                        SELECT COUNT() FROM Team_Member__c 
                        WHERE Location__c = :locationId AND Status__c = 'Active'
                    ];
                    if (teamMemberCount > 0) {
                        return new ResponseWrapper(false, 'Cannot deactivate location. ' + teamMemberCount + ' active team member(s) are using this location. Please reassign them first.');
                    }
                }
                location.Is_Active__c = newIsActive;
            }
            
            // Update other fields
            if (fieldsMap.containsKey('Country__c')) {
                location.Country__c = (String) fieldsMap.get('Country__c');
            }
            if (fieldsMap.containsKey('Time_Zone__c')) {
                location.Time_Zone__c = (String) fieldsMap.get('Time_Zone__c');
            }
            if (fieldsMap.containsKey('Working_Hours_Start__c')) {
                String startTime = (String) fieldsMap.get('Working_Hours_Start__c');
                location.Working_Hours_Start__c = String.isNotBlank(startTime) ? parseTimeString(startTime) : null;
            }
            if (fieldsMap.containsKey('Working_Hours_End__c')) {
                String endTime = (String) fieldsMap.get('Working_Hours_End__c');
                location.Working_Hours_End__c = String.isNotBlank(endTime) ? parseTimeString(endTime) : null;
            }
            
            update location;
            
            return new ResponseWrapper(true, 'Location updated successfully.');
            
        } catch (DmlException e) {
            System.debug('DML Error in updateLocation: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in updateLocation: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error updating location: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to parse time string (HH:MM) to Time object
     */
    private static Time parseTimeString(String timeStr) {
        if (String.isBlank(timeStr)) {
            return null;
        }
        try {
            List<String> parts = timeStr.split(':');
            Integer hours = Integer.valueOf(parts[0]);
            Integer minutes = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
            return Time.newInstance(hours, minutes, 0, 0);
        } catch (Exception e) {
            System.debug('Error parsing time: ' + e.getMessage());
            return null;
        }
    }
    
    // ==================== TEAM MEMBER MANAGEMENT METHODS ====================
    
    /**
     * Gets all managers for dropdown selection
     * @param managerEmail The email of the current manager (for authorization)
     * @return ResponseWrapper containing managers data
     */
    @RemoteAction
    public static ResponseWrapper getManagers(String managerEmail) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> currentManager = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (currentManager.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get all active managers
            List<Team_Member__c> allManagers = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c
                FROM Team_Member__c 
                WHERE Role__c = 'Manager' AND Status__c = 'Active'
                ORDER BY First_Name__c, Last_Name__c
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Managers retrieved successfully.');
            response.managers = allManagers;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getManagers: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving managers: ' + e.getMessage());
        }
    }
    
    /**
     * Creates a new team member
     * @param managerEmail The email of the manager creating the team member
     * @param firstName First name (required)
     * @param lastName Last name (required)
     * @param email Email address (required, unique)
     * @param role Role - Team Member or Manager (required)
     * @param locationId Location ID (required)
     * @param assignedManagerId Manager ID (optional, defaults to logged-in manager)
     * @param startDateStr Start date (optional)
     * @param dailyCapacityHours Daily capacity hours (required, default 7.5)
     * @param status Status - Active or Inactive (required)
     * @return ResponseWrapper containing success status and created team member
     */
    @RemoteAction
    public static ResponseWrapper createTeamMember(String managerEmail, String firstName, String lastName, 
                                                    String email, String role, String locationId, 
                                                    String assignedManagerId, String startDateStr, 
                                                    Decimal dailyCapacityHours, String status) {
        try {
            // Validate required fields
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Manager email is required.');
            }
            if (String.isBlank(firstName)) {
                return new ResponseWrapper(false, 'First name is required.');
            }
            if (String.isBlank(lastName)) {
                return new ResponseWrapper(false, 'Last name is required.');
            }
            if (String.isBlank(email)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            if (String.isBlank(role)) {
                return new ResponseWrapper(false, 'Role is required.');
            }
            if (String.isBlank(locationId)) {
                return new ResponseWrapper(false, 'Location is required.');
            }
            if (dailyCapacityHours == null || dailyCapacityHours <= 0) {
                dailyCapacityHours = 7.5;
            }
            if (String.isBlank(status)) {
                status = 'Active';
            }
            
            // Validate email format
            if (!Pattern.matches('^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$', email)) {
                return new ResponseWrapper(false, 'Invalid email format.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> currentManager = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (currentManager.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Check for duplicate email
            List<Team_Member__c> existingMembers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :email
                LIMIT 1
            ];
            
            if (!existingMembers.isEmpty()) {
                return new ResponseWrapper(false, 'A team member with this email already exists.');
            }
            
            // Verify location exists and is active
            List<Location__c> locations = [
                SELECT Id, Is_Active__c FROM Location__c 
                WHERE Id = :locationId
                LIMIT 1
            ];
            
            if (locations.isEmpty()) {
                return new ResponseWrapper(false, 'Location not found.');
            }
            
            if (!locations[0].Is_Active__c) {
                return new ResponseWrapper(false, 'Cannot assign to an inactive location.');
            }
            
            // Determine manager assignment
            Id finalManagerId;
            if (String.isNotBlank(assignedManagerId)) {
                // Verify assigned manager exists and is a Manager
                List<Team_Member__c> assignedManager = [
                    SELECT Id, Role__c FROM Team_Member__c 
                    WHERE Id = :assignedManagerId AND Status__c = 'Active'
                    LIMIT 1
                ];
                
                if (assignedManager.isEmpty()) {
                    return new ResponseWrapper(false, 'Assigned manager not found.');
                }
                
                // A manager can only report to another Manager
                if (assignedManager[0].Role__c != 'Manager') {
                    return new ResponseWrapper(false, 'Team members can only report to users with Manager role.');
                }
                
                finalManagerId = assignedManager[0].Id;
            } else {
                // Default to the logged-in manager
                finalManagerId = currentManager[0].Id;
            }
            
            // Parse start date if provided
            Date startDate = null;
            if (String.isNotBlank(startDateStr)) {
                try {
                    startDate = Date.valueOf(startDateStr);
                } catch (Exception e) {
                    return new ResponseWrapper(false, 'Invalid start date format. Use YYYY-MM-DD.');
                }
            }
            
            // Create new team member
            Team_Member__c newMember = new Team_Member__c(
                First_Name__c = firstName,
                Last_Name__c = lastName,
                Email__c = email,
                Role__c = role,
                Location__c = locationId,
                Manager__c = finalManagerId,
                Start_Date__c = startDate,
                Daily_Capacity_Hours__c = dailyCapacityHours,
                Status__c = status
            );
            
            insert newMember;
            
            ResponseWrapper response = new ResponseWrapper(true, 'Team member created successfully.');
            response.teamMember = newMember;
            
            return response;
            
        } catch (DmlException e) {
            System.debug('DML Error in createTeamMember: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in createTeamMember: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error creating team member: ' + e.getMessage());
        }
    }
    
    /**
     * Updates an existing team member
     * @param managerEmail The email of the manager
     * @param teamMemberId The ID of the team member to update
     * @param fieldsJson JSON string containing fields to update
     * @return ResponseWrapper containing success status
     */
    @RemoteAction
    public static ResponseWrapper updateTeamMember(String managerEmail, String teamMemberId, String fieldsJson) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(teamMemberId)) {
                return new ResponseWrapper(false, 'Manager email and team member ID are required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> currentManager = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (currentManager.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get existing team member
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c, Role__c, 
                       Location__c, Manager__c, Start_Date__c, Daily_Capacity_Hours__c, Status__c
                FROM Team_Member__c 
                WHERE Id = :teamMemberId
                LIMIT 1
            ];
            
            if (teamMembers.isEmpty()) {
                return new ResponseWrapper(false, 'Team member not found.');
            }
            
            Team_Member__c member = teamMembers[0];
            
            // Parse fields JSON
            Map<String, Object> fieldsMap = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
            
            // Check for duplicate email if email is being changed
            if (fieldsMap.containsKey('Email__c')) {
                String newEmail = (String) fieldsMap.get('Email__c');
                if (String.isNotBlank(newEmail) && newEmail != member.Email__c) {
                    // Validate email format
                    if (!Pattern.matches('^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$', newEmail)) {
                        return new ResponseWrapper(false, 'Invalid email format.');
                    }
                    
                    List<Team_Member__c> duplicateCheck = [
                        SELECT Id FROM Team_Member__c 
                        WHERE Email__c = :newEmail AND Id != :teamMemberId
                        LIMIT 1
                    ];
                    if (!duplicateCheck.isEmpty()) {
                        return new ResponseWrapper(false, 'A team member with this email already exists.');
                    }
                    member.Email__c = newEmail;
                }
            }
            
            // Check manager assignment
            if (fieldsMap.containsKey('Manager__c')) {
                String newManagerId = (String) fieldsMap.get('Manager__c');
                
                if (String.isNotBlank(newManagerId)) {
                    // Verify new manager exists and is a Manager
                    List<Team_Member__c> newManager = [
                        SELECT Id, Role__c, Manager__c FROM Team_Member__c 
                        WHERE Id = :newManagerId AND Status__c = 'Active'
                        LIMIT 1
                    ];
                    
                    if (newManager.isEmpty()) {
                        return new ResponseWrapper(false, 'Assigned manager not found.');
                    }
                    
                    if (newManager[0].Role__c != 'Manager') {
                        return new ResponseWrapper(false, 'Team members can only report to users with Manager role.');
                    }
                    
                    // Check for self-assignment
                    if (newManagerId == teamMemberId) {
                        return new ResponseWrapper(false, 'A team member cannot be their own manager.');
                    }
                    
                    // Check for circular relationship
                    if (hasCircularRelationship(teamMemberId, newManagerId)) {
                        return new ResponseWrapper(false, 'Cannot assign this manager - would create a circular reporting relationship.');
                    }
                    
                    member.Manager__c = newManagerId;
                } else {
                    member.Manager__c = null;
                }
            }
            
            // Check location assignment
            if (fieldsMap.containsKey('Location__c')) {
                String newLocationId = (String) fieldsMap.get('Location__c');
                if (String.isNotBlank(newLocationId)) {
                    List<Location__c> locations = [
                        SELECT Id, Is_Active__c FROM Location__c 
                        WHERE Id = :newLocationId
                        LIMIT 1
                    ];
                    
                    if (locations.isEmpty()) {
                        return new ResponseWrapper(false, 'Location not found.');
                    }
                    
                    if (!locations[0].Is_Active__c) {
                        return new ResponseWrapper(false, 'Cannot assign to an inactive location.');
                    }
                    
                    member.Location__c = newLocationId;
                }
            }
            
            // Update other fields
            if (fieldsMap.containsKey('First_Name__c')) {
                String firstName = (String) fieldsMap.get('First_Name__c');
                if (String.isBlank(firstName)) {
                    return new ResponseWrapper(false, 'First name is required.');
                }
                member.First_Name__c = firstName;
            }
            if (fieldsMap.containsKey('Last_Name__c')) {
                String lastName = (String) fieldsMap.get('Last_Name__c');
                if (String.isBlank(lastName)) {
                    return new ResponseWrapper(false, 'Last name is required.');
                }
                member.Last_Name__c = lastName;
            }
            if (fieldsMap.containsKey('Role__c')) {
                member.Role__c = (String) fieldsMap.get('Role__c');
            }
            if (fieldsMap.containsKey('Status__c')) {
                member.Status__c = (String) fieldsMap.get('Status__c');
            }
            if (fieldsMap.containsKey('Start_Date__c')) {
                String startDateStr = (String) fieldsMap.get('Start_Date__c');
                if (String.isNotBlank(startDateStr)) {
                    try {
                        member.Start_Date__c = Date.valueOf(startDateStr);
                    } catch (Exception e) {
                        return new ResponseWrapper(false, 'Invalid start date format. Use YYYY-MM-DD.');
                    }
                } else {
                    member.Start_Date__c = null;
                }
            }
            if (fieldsMap.containsKey('Daily_Capacity_Hours__c')) {
                Object capacityValue = fieldsMap.get('Daily_Capacity_Hours__c');
                if (capacityValue != null) {
                    Decimal hours = Decimal.valueOf(String.valueOf(capacityValue));
                    if (hours <= 0) {
                        return new ResponseWrapper(false, 'Daily capacity hours must be greater than 0.');
                    }
                    member.Daily_Capacity_Hours__c = hours;
                }
            }
            
            update member;
            
            return new ResponseWrapper(true, 'Team member updated successfully.');
            
        } catch (DmlException e) {
            System.debug('DML Error in updateTeamMember: ' + e.getMessage());
            String errorMsg = 'Database error: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                errorMsg += e.getDmlMessage(i) + ' ';
            }
            return new ResponseWrapper(false, errorMsg);
        } catch (Exception e) {
            System.debug('Error in updateTeamMember: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error updating team member: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to count working days (Mon-Fri) between two dates
     * Excludes weekends (Saturday and Sunday)
     */
    private static Integer countWorkingDays(Date startDate, Date endDate) {
        Integer workingDays = 0;
        Date currentDate = startDate;
        
        while (currentDate <= endDate) {
            DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
            Integer dayOfWeek = Integer.valueOf(dt.format('u')); // 1 = Monday, 7 = Sunday
            
            // Only count Monday (1) through Friday (5)
            if (dayOfWeek >= 1 && dayOfWeek <= 5) {
                workingDays++;
            }
            
            currentDate = currentDate.addDays(1);
        }
        
        return workingDays;
    }
    
    /**
     * Helper method to check if a date is a weekend (Saturday or Sunday)
     */
    private static Boolean isWeekendDate(Date checkDate) {
        DateTime dt = DateTime.newInstance(checkDate, Time.newInstance(0, 0, 0, 0));
        Integer dayOfWeek = Integer.valueOf(dt.format('u')); // 1 = Monday, 7 = Sunday
        return (dayOfWeek == 6 || dayOfWeek == 7); // Saturday or Sunday
    }
    
    /**
     * Helper method to check for circular manager relationships
     * Returns true if assigning newManagerId as manager of memberId would create a circular relationship
     */
    private static Boolean hasCircularRelationship(String memberId, String newManagerId) {
        // If someone reports to newManagerId, and we're making newManagerId report to memberId,
        // we need to check if memberId appears in newManagerId's chain of command
        
        Set<Id> visitedIds = new Set<Id>();
        String currentId = newManagerId;
        
        // Walk up the management chain from newManagerId
        while (String.isNotBlank(currentId) && visitedIds.size() < 100) { // Safety limit
            if (currentId == memberId) {
                // Found memberId in the chain - this would create a cycle
                return true;
            }
            
            if (visitedIds.contains(currentId)) {
                // Already visited this ID (existing cycle in data)
                break;
            }
            
            visitedIds.add(currentId);
            
            // Get this person's manager
            List<Team_Member__c> managers = [
                SELECT Manager__c FROM Team_Member__c 
                WHERE Id = :currentId
                LIMIT 1
            ];
            
            if (managers.isEmpty() || managers[0].Manager__c == null) {
                break;
            }
            
            currentId = managers[0].Manager__c;
        }
        
        return false;
    }
    
    // ==================== SPRINT CAPACITY PLANNER METHODS ====================
    
    /**
     * Gets all sprints
     * @param managerEmail The email of the manager
     * @return ResponseWrapper containing sprints data
     */
    @RemoteAction
    public static ResponseWrapper getSprints(String managerEmail) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Email is required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get all sprints ordered by start date
            List<Sprint__c> sprints = [
                SELECT Id, Name, Start_Date__c, End_Date__c, Is_Active__c, Created_By__c
                FROM Sprint__c 
                ORDER BY Start_Date__c DESC
                LIMIT 50
            ];
            
            ResponseWrapper response = new ResponseWrapper(true, 'Sprints retrieved successfully.');
            response.sprints = sprints;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getSprints: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error retrieving sprints: ' + e.getMessage());
        }
    }
    
    /**
     * Creates a new sprint with overlap validation
     * @param managerEmail The email of the manager
     * @param name Sprint name
     * @param startDateStr Start date (YYYY-MM-DD)
     * @param endDateStr End date (YYYY-MM-DD)
     * @return ResponseWrapper containing success status and created sprint ID
     */
    @RemoteAction
    public static ResponseWrapper createSprint(String managerEmail, String name, String startDateStr, String endDateStr) {
        try {
            if (String.isBlank(managerEmail)) {
                return new ResponseWrapper(false, 'Manager email is required.');
            }
            if (String.isBlank(name)) {
                return new ResponseWrapper(false, 'Sprint name is required.');
            }
            if (String.isBlank(startDateStr) || String.isBlank(endDateStr)) {
                return new ResponseWrapper(false, 'Start and end dates are required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Parse dates
            Date startDate = Date.valueOf(startDateStr);
            Date endDate = Date.valueOf(endDateStr);
            
            if (startDate > endDate) {
                return new ResponseWrapper(false, 'End date must be after start date.');
            }
            
            // Check for overlapping sprints
            List<Sprint__c> overlappingSprints = [
                SELECT Name, Start_Date__c, End_Date__c
                FROM Sprint__c 
                WHERE (Start_Date__c <= :endDate AND End_Date__c >= :startDate)
                LIMIT 1
            ];
            
            if (!overlappingSprints.isEmpty()) {
                Sprint__c overlap = overlappingSprints[0];
                return new ResponseWrapper(false, 'Sprint dates overlap with existing sprint "' + overlap.Name + '" (' + overlap.Start_Date__c.format() + ' - ' + overlap.End_Date__c.format() + ').');
            }
            
            // Create new sprint
            Sprint__c newSprint = new Sprint__c(
                Name = name,
                Start_Date__c = startDate,
                End_Date__c = endDate,
                Is_Active__c = true,
                Created_By__c = managers[0].Id
            );
            
            insert newSprint;
            
            ResponseWrapper response = new ResponseWrapper(true, 'Sprint created successfully.');
            response.sprintId = newSprint.Id;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in createSprint: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error creating sprint: ' + e.getMessage());
        }
    }
    
    /**
     * Updates an existing sprint
     * @param managerEmail The email of the manager
     * @param sprintId The ID of the sprint to update
     * @param name Sprint name
     * @param startDateStr Start date (YYYY-MM-DD)
     * @param endDateStr End date (YYYY-MM-DD)
     * @return ResponseWrapper containing success status
     */
    @RemoteAction
    public static ResponseWrapper updateSprint(String managerEmail, String sprintId, String name, String startDateStr, String endDateStr) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(sprintId)) {
                return new ResponseWrapper(false, 'Manager email and sprint ID are required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get existing sprint
            List<Sprint__c> sprints = [
                SELECT Id, Name, Start_Date__c, End_Date__c
                FROM Sprint__c 
                WHERE Id = :sprintId
                LIMIT 1
            ];
            
            if (sprints.isEmpty()) {
                return new ResponseWrapper(false, 'Sprint not found.');
            }
            
            Sprint__c sprint = sprints[0];
            
            // Parse dates
            Date startDate = String.isNotBlank(startDateStr) ? Date.valueOf(startDateStr) : sprint.Start_Date__c;
            Date endDate = String.isNotBlank(endDateStr) ? Date.valueOf(endDateStr) : sprint.End_Date__c;
            
            if (startDate > endDate) {
                return new ResponseWrapper(false, 'End date must be after start date.');
            }
            
            // Check for overlapping sprints (excluding current sprint)
            List<Sprint__c> overlappingSprints = [
                SELECT Name, Start_Date__c, End_Date__c
                FROM Sprint__c 
                WHERE Id != :sprintId
                AND (Start_Date__c <= :endDate AND End_Date__c >= :startDate)
                LIMIT 1
            ];
            
            if (!overlappingSprints.isEmpty()) {
                Sprint__c overlap = overlappingSprints[0];
                return new ResponseWrapper(false, 'Sprint dates overlap with existing sprint "' + overlap.Name + '" (' + overlap.Start_Date__c.format() + ' - ' + overlap.End_Date__c.format() + ').');
            }
            
            // Update sprint
            sprint.Name = String.isNotBlank(name) ? name : sprint.Name;
            sprint.Start_Date__c = startDate;
            sprint.End_Date__c = endDate;
            
            update sprint;
            
            return new ResponseWrapper(true, 'Sprint updated successfully.');
            
        } catch (Exception e) {
            System.debug('Error in updateSprint: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error updating sprint: ' + e.getMessage());
        }
    }
    
    /**
     * Deletes a sprint
     * @param managerEmail The email of the manager
     * @param sprintId The ID of the sprint to delete
     * @return ResponseWrapper containing success status
     */
    @RemoteAction
    public static ResponseWrapper deleteSprint(String managerEmail, String sprintId) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(sprintId)) {
                return new ResponseWrapper(false, 'Manager email and sprint ID are required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get sprint
            List<Sprint__c> sprints = [
                SELECT Id FROM Sprint__c 
                WHERE Id = :sprintId
                LIMIT 1
            ];
            
            if (sprints.isEmpty()) {
                return new ResponseWrapper(false, 'Sprint not found.');
            }
            
            delete sprints[0];
            
            return new ResponseWrapper(true, 'Sprint deleted successfully.');
            
        } catch (Exception e) {
            System.debug('Error in deleteSprint: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error deleting sprint: ' + e.getMessage());
        }
    }
    
    /**
     * Gets sprint grid data for capacity planning
     * @param managerEmail The email of the manager
     * @param sprintId The ID of the sprint
     * @return ResponseWrapper containing grid data
     */
    @RemoteAction
    public static ResponseWrapper getSprintGridData(String managerEmail, String sprintId) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(sprintId)) {
                return new ResponseWrapper(false, 'Manager email and sprint ID are required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get sprint details
            List<Sprint__c> sprints = [
                SELECT Id, Name, Start_Date__c, End_Date__c
                FROM Sprint__c 
                WHERE Id = :sprintId
                LIMIT 1
            ];
            
            if (sprints.isEmpty()) {
                return new ResponseWrapper(false, 'Sprint not found.');
            }
            
            Sprint__c sprint = sprints[0];
            
            // Get team members under this manager
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Role__c, Location__c, Daily_Capacity_Hours__c
                FROM Team_Member__c 
                WHERE Manager__c = :managers[0].Id AND Status__c = 'Active'
                ORDER BY First_Name__c, Last_Name__c
            ];
            
            Set<Id> teamMemberIds = new Set<Id>();
            Set<Id> locationIds = new Set<Id>();
            for (Team_Member__c tm : teamMembers) {
                teamMemberIds.add(tm.Id);
                if (tm.Location__c != null) {
                    locationIds.add(tm.Location__c);
                }
            }
            
            // Get holidays for team member locations in sprint date range
            Map<Id, Set<Date>> holidaysByLocation = new Map<Id, Set<Date>>();
            for (Holiday__c holiday : [
                SELECT Location__c, Start_Date__c, End_Date__c
                FROM Holiday__c 
                WHERE Location__c IN :locationIds 
                AND Is_Active__c = true
                AND Start_Date__c <= :sprint.End_Date__c 
                AND End_Date__c >= :sprint.Start_Date__c
            ]) {
                if (!holidaysByLocation.containsKey(holiday.Location__c)) {
                    holidaysByLocation.put(holiday.Location__c, new Set<Date>());
                }
                Date hStart = holiday.Start_Date__c > sprint.Start_Date__c ? holiday.Start_Date__c : sprint.Start_Date__c;
                Date hEnd = holiday.End_Date__c < sprint.End_Date__c ? holiday.End_Date__c : sprint.End_Date__c;
                Date currentDate = hStart;
                while (currentDate <= hEnd) {
                    holidaysByLocation.get(holiday.Location__c).add(currentDate);
                    currentDate = currentDate.addDays(1);
                }
            }
            
            // Get approved leaves for team members in sprint date range
            Map<Id, Map<Date, Decimal>> leavesByMember = new Map<Id, Map<Date, Decimal>>();
            for (Leave_Request__c leave : [
                SELECT Requestor__c, Start_Date__c, End_Date__c, Hours_Requested__c
                FROM Leave_Request__c 
                WHERE Requestor__c IN :teamMemberIds 
                AND Status__c = 'Approved'
                AND Start_Date__c <= :sprint.End_Date__c 
                AND End_Date__c >= :sprint.Start_Date__c
            ]) {
                if (!leavesByMember.containsKey(leave.Requestor__c)) {
                    leavesByMember.put(leave.Requestor__c, new Map<Date, Decimal>());
                }
                Date lStart = leave.Start_Date__c > sprint.Start_Date__c ? leave.Start_Date__c : sprint.Start_Date__c;
                Date lEnd = leave.End_Date__c < sprint.End_Date__c ? leave.End_Date__c : sprint.End_Date__c;
                
                // Hours_Requested__c represents daily leave hours (not total hours to divide)
                // Use it directly as the hours to subtract per working day
                Decimal hoursPerDay = leave.Hours_Requested__c != null ? leave.Hours_Requested__c : 7.5;
                
                Date currentDate = lStart;
                while (currentDate <= lEnd) {
                    // Only apply leave hours to working days (skip weekends)
                    if (!isWeekendDate(currentDate)) {
                        Map<Date, Decimal> memberLeaves = leavesByMember.get(leave.Requestor__c);
                        Decimal existingHours = memberLeaves.containsKey(currentDate) ? memberLeaves.get(currentDate) : 0;
                        memberLeaves.put(currentDate, existingHours + hoursPerDay);
                    }
                    currentDate = currentDate.addDays(1);
                }
            }
            
            // Get existing capacity tracking records for this sprint
            Map<String, Capacity_Tracking__c> existingCapacity = new Map<String, Capacity_Tracking__c>();
            for (Capacity_Tracking__c ct : [
                SELECT Id, Team_Member__c, Date__c, Base_Hours__c, Leave_Hours__c, Holiday_Hours__c, 
                       Available_Hours__c, Is_Manual_Override__c, Manual_Available_Hours__c, Override_Reason__c
                FROM Capacity_Tracking__c 
                WHERE Team_Member__c IN :teamMemberIds 
                AND Sprint__c = :sprintId
            ]) {
                String key = ct.Team_Member__c + '_' + ct.Date__c.format();
                existingCapacity.put(key, ct);
            }
            
            // Build grid data structure
            List<Map<String, Object>> datesList = new List<Map<String, Object>>();
            List<Map<String, Object>> membersList = new List<Map<String, Object>>();
            
            // Generate dates array
            Date currentDate = sprint.Start_Date__c;
            List<String> dayNames = new List<String>{'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
            while (currentDate <= sprint.End_Date__c) {
                DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
                Integer dayOfWeek = Integer.valueOf(dt.format('u')); // 1 = Monday, 7 = Sunday
                Boolean isWeekend = (dayOfWeek == 6 || dayOfWeek == 7); // Saturday or Sunday
                
                Map<String, Object> dateInfo = new Map<String, Object>();
                dateInfo.put('date', currentDate.format());
                dateInfo.put('dayName', dayNames[Math.mod(dayOfWeek, 7)]);
                dateInfo.put('isWeekend', isWeekend);
                datesList.add(dateInfo);
                
                currentDate = currentDate.addDays(1);
            }
            
            // Generate member capacity data
            List<Capacity_Tracking__c> recordsToCreate = new List<Capacity_Tracking__c>();
            Decimal totalCapacity = 0;
            
            for (Team_Member__c member : teamMembers) {
                Map<String, Object> memberData = new Map<String, Object>();
                memberData.put('id', member.Id);
                memberData.put('name', member.First_Name__c + ' ' + member.Last_Name__c);
                memberData.put('role', member.Role__c);
                
                List<Map<String, Object>> dailyCapacity = new List<Map<String, Object>>();
                Decimal memberTotal = 0;
                Decimal baseHours = member.Daily_Capacity_Hours__c != null ? member.Daily_Capacity_Hours__c : 7.5;
                Set<Date> memberHolidays = holidaysByLocation.containsKey(member.Location__c) ? holidaysByLocation.get(member.Location__c) : new Set<Date>();
                Map<Date, Decimal> memberLeaves = leavesByMember.containsKey(member.Id) ? leavesByMember.get(member.Id) : new Map<Date, Decimal>();
                
                currentDate = sprint.Start_Date__c;
                while (currentDate <= sprint.End_Date__c) {
                    String key = member.Id + '_' + currentDate.format();
                    DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
                    Integer dayOfWeek = Integer.valueOf(dt.format('u'));
                    Boolean isWeekend = (dayOfWeek == 6 || dayOfWeek == 7);
                    Boolean isHoliday = memberHolidays.contains(currentDate);
                    Decimal leaveHours = memberLeaves.containsKey(currentDate) ? memberLeaves.get(currentDate) : 0;
                    Boolean hasLeave = leaveHours > 0;
                    Boolean isPartialLeave = hasLeave && leaveHours < baseHours;
                    
                    Map<String, Object> dayCapacity = new Map<String, Object>();
                    Decimal availableHours = 0;
                    String status = 'normal';
                    Boolean editable = true;
                    String tooltip = '';
                    String recordId = null;
                    Boolean isOverride = false;
                    
                    // Check for existing capacity record
                    Capacity_Tracking__c existingRecord = existingCapacity.get(key);
                    
                    if (existingRecord != null) {
                        recordId = existingRecord.Id;
                        isOverride = existingRecord.Is_Manual_Override__c;
                        availableHours = existingRecord.Available_Hours__c != null ? existingRecord.Available_Hours__c : 0;
                        
                        if (isOverride) {
                            status = 'override';
                            tooltip = 'Manual override' + (String.isNotBlank(existingRecord.Override_Reason__c) ? ': ' + existingRecord.Override_Reason__c : '');
                        } else if (isWeekend) {
                            status = 'weekend';
                            editable = false;
                        } else if (isHoliday) {
                            status = 'holiday';
                            editable = false;
                            tooltip = 'Holiday';
                        } else if (hasLeave) {
                            status = isPartialLeave ? 'partial' : 'leave';
                            editable = false;
                            tooltip = isPartialLeave ? 'Partial leave (' + leaveHours + 'h)' : 'Full day leave';
                        }
                    } else {
                        // Calculate capacity for new record
                        Decimal holidayHours = 0;
                        
                        if (isWeekend) {
                            status = 'weekend';
                            availableHours = 0;
                            editable = false;
                        } else if (isHoliday) {
                            status = 'holiday';
                            holidayHours = baseHours;
                            availableHours = 0;
                            editable = false;
                            tooltip = 'Holiday';
                        } else if (hasLeave) {
                            status = isPartialLeave ? 'partial' : 'leave';
                            availableHours = Math.max(0, baseHours - leaveHours);
                            editable = false;
                            tooltip = isPartialLeave ? 'Partial leave (' + leaveHours + 'h)' : 'Full day leave';
                        } else {
                            availableHours = baseHours;
                        }
                        
                        // Create capacity tracking record for this date
                        Capacity_Tracking__c newRecord = new Capacity_Tracking__c(
                            Team_Member__c = member.Id,
                            Sprint__c = sprintId,
                            Date__c = currentDate,
                            Base_Hours__c = isWeekend ? 0 : baseHours,
                            Leave_Hours__c = leaveHours,
                            Holiday_Hours__c = holidayHours,
                            Is_Manual_Override__c = false
                        );
                        recordsToCreate.add(newRecord);
                    }
                    
                    dayCapacity.put('hours', availableHours);
                    dayCapacity.put('status', status);
                    dayCapacity.put('editable', editable);
                    dayCapacity.put('tooltip', tooltip);
                    dayCapacity.put('recordId', recordId);
                    dayCapacity.put('isOverride', isOverride);
                    
                    dailyCapacity.add(dayCapacity);
                    memberTotal += availableHours;
                    
                    currentDate = currentDate.addDays(1);
                }
                
                memberData.put('dailyCapacity', dailyCapacity);
                memberData.put('totalHours', memberTotal);
                membersList.add(memberData);
                totalCapacity += memberTotal;
            }
            
            // Insert new capacity records
            if (!recordsToCreate.isEmpty()) {
                insert recordsToCreate;
                
                // Update the grid data with new record IDs
                Map<String, Id> newRecordIds = new Map<String, Id>();
                for (Capacity_Tracking__c rec : recordsToCreate) {
                    String key = rec.Team_Member__c + '_' + rec.Date__c.format();
                    newRecordIds.put(key, rec.Id);
                }
                
                // Update member data with record IDs
                for (Map<String, Object> memberData : membersList) {
                    String memberId = (String) memberData.get('id');
                    List<Map<String, Object>> dailyCapacity = (List<Map<String, Object>>) memberData.get('dailyCapacity');
                    currentDate = sprint.Start_Date__c;
                    Integer dayIndex = 0;
                    while (currentDate <= sprint.End_Date__c && dayIndex < dailyCapacity.size()) {
                        String key = memberId + '_' + currentDate.format();
                        if (dailyCapacity[dayIndex].get('recordId') == null && newRecordIds.containsKey(key)) {
                            dailyCapacity[dayIndex].put('recordId', newRecordIds.get(key));
                        }
                        currentDate = currentDate.addDays(1);
                        dayIndex++;
                    }
                }
            }
            
            // Build final grid data
            Map<String, Object> gridData = new Map<String, Object>();
            gridData.put('sprintId', sprint.Id);
            gridData.put('sprintName', sprint.Name);
            gridData.put('startDate', sprint.Start_Date__c.format());
            gridData.put('endDate', sprint.End_Date__c.format());
            gridData.put('dates', datesList);
            gridData.put('teamMembers', membersList);
            gridData.put('totalCapacity', totalCapacity);
            
            ResponseWrapper response = new ResponseWrapper(true, 'Grid data retrieved successfully.');
            response.gridData = gridData;
            
            return response;
            
        } catch (Exception e) {
            System.debug('Error in getSprintGridData: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new ResponseWrapper(false, 'Error retrieving grid data: ' + e.getMessage());
        }
    }
    
    /**
     * Updates a capacity cell with manual override
     * @param managerEmail The email of the manager
     * @param capacityRecordId The ID of the capacity tracking record
     * @param newHours The new available hours value
     * @param overrideReason Optional reason for the override
     * @return ResponseWrapper containing success status
     */
    @RemoteAction
    public static ResponseWrapper updateCapacityCell(String managerEmail, String capacityRecordId, Decimal newHours, String overrideReason) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(capacityRecordId)) {
                return new ResponseWrapper(false, 'Manager email and capacity record ID are required.');
            }
            
            if (newHours == null || newHours < 0) {
                return new ResponseWrapper(false, 'Hours must be a positive number.');
            }
            
            if (newHours > 24) {
                return new ResponseWrapper(false, 'Hours cannot exceed 24.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get capacity record
            List<Capacity_Tracking__c> records = [
                SELECT Id, Team_Member__c, Date__c, Base_Hours__c, Leave_Hours__c, Holiday_Hours__c
                FROM Capacity_Tracking__c 
                WHERE Id = :capacityRecordId
                LIMIT 1
            ];
            
            if (records.isEmpty()) {
                return new ResponseWrapper(false, 'Capacity record not found.');
            }
            
            Capacity_Tracking__c record = records[0];
            
            // Update with manual override
            record.Manual_Available_Hours__c = newHours;
            record.Is_Manual_Override__c = true;
            record.Override_Reason__c = overrideReason;
            record.Last_Modified_By_Member__c = managers[0].Id;
            
            update record;
            
            return new ResponseWrapper(true, 'Capacity updated successfully.');
            
        } catch (Exception e) {
            System.debug('Error in updateCapacityCell: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error updating capacity: ' + e.getMessage());
        }
    }
    
    /**
     * Refreshes sprint capacity (recalculates all capacity records)
     * @param managerEmail The email of the manager
     * @param sprintId The ID of the sprint
     * @param forceRecalculate If true, resets manual overrides
     * @return ResponseWrapper containing success status
     */
    @RemoteAction
    public static ResponseWrapper refreshSprintCapacity(String managerEmail, String sprintId, Boolean forceRecalculate) {
        try {
            if (String.isBlank(managerEmail) || String.isBlank(sprintId)) {
                return new ResponseWrapper(false, 'Manager email and sprint ID are required.');
            }
            
            // Verify the user is a manager
            List<Team_Member__c> managers = [
                SELECT Id FROM Team_Member__c 
                WHERE Email__c = :managerEmail AND Status__c = 'Active' AND Role__c = 'Manager'
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                return new ResponseWrapper(false, 'Manager not found or not authorized.');
            }
            
            // Get sprint
            List<Sprint__c> sprints = [
                SELECT Id, Start_Date__c, End_Date__c
                FROM Sprint__c 
                WHERE Id = :sprintId
                LIMIT 1
            ];
            
            if (sprints.isEmpty()) {
                return new ResponseWrapper(false, 'Sprint not found.');
            }
            
            Sprint__c sprint = sprints[0];
            
            // Get team members
            List<Team_Member__c> teamMembers = [
                SELECT Id, Location__c, Daily_Capacity_Hours__c
                FROM Team_Member__c 
                WHERE Manager__c = :managers[0].Id AND Status__c = 'Active'
            ];
            
            Set<Id> teamMemberIds = new Set<Id>();
            Set<Id> locationIds = new Set<Id>();
            Map<Id, Decimal> memberCapacity = new Map<Id, Decimal>();
            Map<Id, Id> memberLocations = new Map<Id, Id>();
            
            for (Team_Member__c tm : teamMembers) {
                teamMemberIds.add(tm.Id);
                memberCapacity.put(tm.Id, tm.Daily_Capacity_Hours__c != null ? tm.Daily_Capacity_Hours__c : 7.5);
                if (tm.Location__c != null) {
                    locationIds.add(tm.Location__c);
                    memberLocations.put(tm.Id, tm.Location__c);
                }
            }
            
            // Get holidays
            Map<Id, Set<Date>> holidaysByLocation = new Map<Id, Set<Date>>();
            for (Holiday__c holiday : [
                SELECT Location__c, Start_Date__c, End_Date__c
                FROM Holiday__c 
                WHERE Location__c IN :locationIds 
                AND Is_Active__c = true
                AND Start_Date__c <= :sprint.End_Date__c 
                AND End_Date__c >= :sprint.Start_Date__c
            ]) {
                if (!holidaysByLocation.containsKey(holiday.Location__c)) {
                    holidaysByLocation.put(holiday.Location__c, new Set<Date>());
                }
                Date hStart = holiday.Start_Date__c > sprint.Start_Date__c ? holiday.Start_Date__c : sprint.Start_Date__c;
                Date hEnd = holiday.End_Date__c < sprint.End_Date__c ? holiday.End_Date__c : sprint.End_Date__c;
                Date currentDate = hStart;
                while (currentDate <= hEnd) {
                    holidaysByLocation.get(holiday.Location__c).add(currentDate);
                    currentDate = currentDate.addDays(1);
                }
            }
            
            // Get approved leaves
            Map<Id, Map<Date, Decimal>> leavesByMember = new Map<Id, Map<Date, Decimal>>();
            for (Leave_Request__c leave : [
                SELECT Requestor__c, Start_Date__c, End_Date__c, Hours_Requested__c
                FROM Leave_Request__c 
                WHERE Requestor__c IN :teamMemberIds 
                AND Status__c = 'Approved'
                AND Start_Date__c <= :sprint.End_Date__c 
                AND End_Date__c >= :sprint.Start_Date__c
            ]) {
                if (!leavesByMember.containsKey(leave.Requestor__c)) {
                    leavesByMember.put(leave.Requestor__c, new Map<Date, Decimal>());
                }
                Date lStart = leave.Start_Date__c > sprint.Start_Date__c ? leave.Start_Date__c : sprint.Start_Date__c;
                Date lEnd = leave.End_Date__c < sprint.End_Date__c ? leave.End_Date__c : sprint.End_Date__c;
                
                // Hours_Requested__c represents daily leave hours (not total hours to divide)
                // Use it directly as the hours to subtract per working day
                Decimal hoursPerDay = leave.Hours_Requested__c != null ? leave.Hours_Requested__c : 7.5;
                
                Date currentDate = lStart;
                while (currentDate <= lEnd) {
                    // Only apply leave hours to working days (skip weekends)
                    if (!isWeekendDate(currentDate)) {
                        Map<Date, Decimal> memberLeaves = leavesByMember.get(leave.Requestor__c);
                        Decimal existingHours = memberLeaves.containsKey(currentDate) ? memberLeaves.get(currentDate) : 0;
                        memberLeaves.put(currentDate, existingHours + hoursPerDay);
                    }
                    currentDate = currentDate.addDays(1);
                }
            }
            
            // Get existing capacity records
            List<Capacity_Tracking__c> existingRecords = [
                SELECT Id, Team_Member__c, Date__c, Is_Manual_Override__c
                FROM Capacity_Tracking__c 
                WHERE Team_Member__c IN :teamMemberIds 
                AND Sprint__c = :sprintId
            ];
            
            // Update records
            List<Capacity_Tracking__c> recordsToUpdate = new List<Capacity_Tracking__c>();
            
            for (Capacity_Tracking__c record : existingRecords) {
                // Skip manual overrides unless force recalculate
                if (record.Is_Manual_Override__c && !forceRecalculate) {
                    continue;
                }
                
                Decimal baseHours = memberCapacity.get(record.Team_Member__c);
                Id locationId = memberLocations.get(record.Team_Member__c);
                Set<Date> memberHolidays = locationId != null && holidaysByLocation.containsKey(locationId) ? holidaysByLocation.get(locationId) : new Set<Date>();
                Map<Date, Decimal> memberLeaves = leavesByMember.containsKey(record.Team_Member__c) ? leavesByMember.get(record.Team_Member__c) : new Map<Date, Decimal>();
                
                DateTime dt = DateTime.newInstance(record.Date__c, Time.newInstance(0, 0, 0, 0));
                Integer dayOfWeek = Integer.valueOf(dt.format('u'));
                Boolean isWeekend = (dayOfWeek == 6 || dayOfWeek == 7);
                Boolean isHoliday = memberHolidays.contains(record.Date__c);
                Decimal leaveHours = memberLeaves.containsKey(record.Date__c) ? memberLeaves.get(record.Date__c) : 0;
                
                record.Base_Hours__c = isWeekend ? 0 : baseHours;
                record.Leave_Hours__c = leaveHours;
                record.Holiday_Hours__c = isHoliday ? baseHours : 0;
                
                if (forceRecalculate) {
                    record.Is_Manual_Override__c = false;
                    record.Manual_Available_Hours__c = null;
                    record.Override_Reason__c = null;
                }
                
                recordsToUpdate.add(record);
            }
            
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            
            return new ResponseWrapper(true, 'Capacity refreshed successfully. ' + recordsToUpdate.size() + ' records updated.');
            
        } catch (Exception e) {
            System.debug('Error in refreshSprintCapacity: ' + e.getMessage());
            return new ResponseWrapper(false, 'Error refreshing capacity: ' + e.getMessage());
        }
    }
    
    // Wrapper class for responses
    public class ResponseWrapper {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Team_Member__c teamMember { get; set; }
        @AuraEnabled public List<Leave_Request__c> leaveRequests { get; set; }
        @AuraEnabled public List<Leave_Request__c> teamMemberRequests { get; set; }
        @AuraEnabled public List<Capacity_Tracking__c> capacityData { get; set; }
        @AuraEnabled public List<Holiday__c> holidays { get; set; }
        @AuraEnabled public List<Team_Member__c> teamMembers { get; set; }
        @AuraEnabled public List<Team_Member__c> managers { get; set; }
        @AuraEnabled public List<Leave_Request__c> pendingRequests { get; set; }
        @AuraEnabled public List<Location__c> locations { get; set; }
        @AuraEnabled public Location__c location { get; set; }
        @AuraEnabled public Integer recordsCreated { get; set; }
        @AuraEnabled public Integer recordsUpdated { get; set; }
        @AuraEnabled public List<String> affectedDates { get; set; }
        @AuraEnabled public List<Sprint__c> sprints { get; set; }
        @AuraEnabled public String sprintId { get; set; }
        @AuraEnabled public Map<String, Object> gridData { get; set; }
        
        public ResponseWrapper(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
}
//__________________________GenAI: Generated code ends here______________________________//
