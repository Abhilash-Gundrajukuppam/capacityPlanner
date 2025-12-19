//_______________This Code was generated using GenAI tool: Codify, Please check for accuracy_______________//

public class LeaveRequestTriggerHandler {
    
    /**
     * Handle after insert operations
     */
    public static void handleAfterInsert(List<Leave_Request__c> newRecords) {
        try {
            // Send notification emails to managers for new requests
            sendManagerNotifications(newRecords);
            
        } catch (Exception e) {
            System.debug('Error in LeaveRequestTriggerHandler.handleAfterInsert: ' + e.getMessage());
        }
    }
    
    /**
     * Handle after update operations
     */
    public static void handleAfterUpdate(List<Leave_Request__c> newRecords, Map<Id, Leave_Request__c> oldMap) {
        try {
            List<Leave_Request__c> statusChangedRecords = new List<Leave_Request__c>();
            
            // Identify records where status changed
            for (Leave_Request__c newRecord : newRecords) {
                Leave_Request__c oldRecord = oldMap.get(newRecord.Id);
                if (newRecord.Status__c != oldRecord.Status__c) {
                    statusChangedRecords.add(newRecord);
                }
            }
            
            if (!statusChangedRecords.isEmpty()) {
                // Send notification emails to requestors about status changes
                sendRequestorNotifications(statusChangedRecords);
            }
            
        } catch (Exception e) {
            System.debug('Error in LeaveRequestTriggerHandler.handleAfterUpdate: ' + e.getMessage());
        }
    }
    
    /**
     * Send email notifications to managers when new leave requests are submitted
     */
    private static void sendManagerNotifications(List<Leave_Request__c> leaveRequests) {
        // Get manager email addresses
        Set<Id> managerIds = new Set<Id>();
        for (Leave_Request__c request : leaveRequests) {
            if (request.Manager__c != null) {
                managerIds.add(request.Manager__c);
            }
        }
        
        if (managerIds.isEmpty()) return;
        
        // Get manager details
        Map<Id, Team_Member__c> managers = new Map<Id, Team_Member__c>([
            SELECT Id, First_Name__c, Last_Name__c, Email__c
            FROM Team_Member__c 
            WHERE Id IN :managerIds
        ]);
        
        // Get requestor details
        Set<Id> requestorIds = new Set<Id>();
        for (Leave_Request__c request : leaveRequests) {
            if (request.Requestor__c != null) {
                requestorIds.add(request.Requestor__c);
            }
        }
        
        Map<Id, Team_Member__c> requestors = new Map<Id, Team_Member__c>([
            SELECT Id, First_Name__c, Last_Name__c, Email__c
            FROM Team_Member__c 
            WHERE Id IN :requestorIds
        ]);
        
        // Send emails
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Leave_Request__c request : leaveRequests) {
            if (request.Manager__c != null && managers.containsKey(request.Manager__c)) {
                Team_Member__c manager = managers.get(request.Manager__c);
                Team_Member__c requestor = requestors.get(request.Requestor__c);
                
                if (manager.Email__c != null) {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new String[]{manager.Email__c});
                    email.setSubject('New Leave Request Awaiting Approval');
                    
                    String emailBody = buildManagerNotificationEmail(request, requestor, manager);
                    email.setHtmlBody(emailBody);
                    
                    emails.add(email);
                }
            }
        }
        
        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('Error sending manager notification emails: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Send email notifications to requestors when leave request status changes
     */
    private static void sendRequestorNotifications(List<Leave_Request__c> leaveRequests) {
        // Get requestor email addresses
        Set<Id> requestorIds = new Set<Id>();
        for (Leave_Request__c request : leaveRequests) {
            if (request.Requestor__c != null) {
                requestorIds.add(request.Requestor__c);
            }
        }
        
        if (requestorIds.isEmpty()) return;
        
        // Get requestor details
        Map<Id, Team_Member__c> requestors = new Map<Id, Team_Member__c>([
            SELECT Id, First_Name__c, Last_Name__c, Email__c
            FROM Team_Member__c 
            WHERE Id IN :requestorIds
        ]);
        
        // Get manager details
        Set<Id> managerIds = new Set<Id>();
        for (Leave_Request__c request : leaveRequests) {
            if (request.Manager__c != null) {
                managerIds.add(request.Manager__c);
            }
        }
        
        Map<Id, Team_Member__c> managers = new Map<Id, Team_Member__c>([
            SELECT Id, First_Name__c, Last_Name__c, Email__c
            FROM Team_Member__c 
            WHERE Id IN :managerIds
        ]);
        
        // Send emails
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Leave_Request__c request : leaveRequests) {
            if (request.Requestor__c != null && requestors.containsKey(request.Requestor__c)) {
                Team_Member__c requestor = requestors.get(request.Requestor__c);
                Team_Member__c manager = managers.get(request.Manager__c);
                
                if (requestor.Email__c != null) {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new String[]{requestor.Email__c});
                    
                    String subject = 'Leave Request ' + 
                        (request.Status__c == 'Approved' ? 'Approved' : 
                         request.Status__c == 'Rejected' ? 'Rejected' : 'Updated');
                    email.setSubject(subject);
                    
                    String emailBody = buildRequestorNotificationEmail(request, requestor, manager);
                    email.setHtmlBody(emailBody);
                    
                    emails.add(email);
                }
            }
        }
        
        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('Error sending requestor notification emails: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Build email content for manager notifications
     */
    private static String buildManagerNotificationEmail(Leave_Request__c request, Team_Member__c requestor, Team_Member__c manager) {
        String requestorName = (requestor.First_Name__c != null ? requestor.First_Name__c + ' ' : '') + 
                              (requestor.Last_Name__c != null ? requestor.Last_Name__c : '');
        String managerName = (manager.First_Name__c != null ? manager.First_Name__c + ' ' : '') + 
                            (manager.Last_Name__c != null ? manager.Last_Name__c : '');
        
        String startDate = request.Start_Date__c != null ? request.Start_Date__c.format() : '';
        String endDate = request.End_Date__c != null ? request.End_Date__c.format() : '';
        
        String emailBody = '<html><body style="font-family: Arial, sans-serif; color: #333;">';
        emailBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">';
        emailBody += '<h2 style="color: #1976d2; border-bottom: 2px solid #1976d2; padding-bottom: 10px;">New Leave Request</h2>';
        emailBody += '<p>Hello ' + managerName + ',</p>';
        emailBody += '<p>You have received a new leave request that requires your approval:</p>';
        emailBody += '<div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">';
        emailBody += '<strong>Requestor:</strong> ' + requestorName + '<br>';
        emailBody += '<strong>Date:</strong> ' + startDate;
        if (String.isNotBlank(endDate) && endDate != startDate) {
            emailBody += ' to ' + endDate;
        }
        emailBody += '<br>';
        emailBody += '<strong>Type:</strong> ' + request.Leave_Type__c + ' (' + request.Leave_Category__c + ')<br>';
        if (String.isNotBlank(request.Reason__c)) {
            emailBody += '<strong>Reason:</strong> ' + request.Reason__c + '<br>';
        }
        emailBody += '</div>';
        emailBody += '<p>Please log in to the Capacity Planner to review and process this request.</p>';
        emailBody += '<p>Best regards,<br>Capacity Planner System</p>';
        emailBody += '</div></body></html>';
        
        return emailBody;
    }
    
    /**
     * Build email content for requestor notifications
     */
    private static String buildRequestorNotificationEmail(Leave_Request__c request, Team_Member__c requestor, Team_Member__c manager) {
        String requestorName = (requestor.First_Name__c != null ? requestor.First_Name__c + ' ' : '') + 
                              (requestor.Last_Name__c != null ? requestor.Last_Name__c : '');
        String managerName = (manager.First_Name__c != null ? manager.First_Name__c + ' ' : '') + 
                            (manager.Last_Name__c != null ? manager.Last_Name__c : '');
        
        String startDate = request.Start_Date__c != null ? request.Start_Date__c.format() : '';
        String endDate = request.End_Date__c != null ? request.End_Date__c.format() : '';
        
        String statusColor = request.Status__c == 'Approved' ? '#4caf50' : 
                           request.Status__c == 'Rejected' ? '#f44336' : '#ff9800';
        
        String emailBody = '<html><body style="font-family: Arial, sans-serif; color: #333;">';
        emailBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">';
        emailBody += '<h2 style="color: ' + statusColor + '; border-bottom: 2px solid ' + statusColor + '; padding-bottom: 10px;">';
        emailBody += 'Leave Request ' + request.Status__c + '</h2>';
        emailBody += '<p>Hello ' + requestorName + ',</p>';
        emailBody += '<p>Your leave request has been <strong style="color: ' + statusColor + ';">' + request.Status__c.toLowerCase() + '</strong>:</p>';
        emailBody += '<div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">';
        emailBody += '<strong>Date:</strong> ' + startDate;
        if (String.isNotBlank(endDate) && endDate != startDate) {
            emailBody += ' to ' + endDate;
        }
        emailBody += '<br>';
        emailBody += '<strong>Type:</strong> ' + request.Leave_Type__c + ' (' + request.Leave_Category__c + ')<br>';
        emailBody += '<strong>Reviewed by:</strong> ' + managerName + '<br>';
        if (String.isNotBlank(request.Manager_Comments__c)) {
            emailBody += '<strong>Manager Comments:</strong> ' + request.Manager_Comments__c + '<br>';
        }
        emailBody += '</div>';
        
        if (request.Status__c == 'Approved') {
            emailBody += '<p style="color: #4caf50;">Your leave has been approved. Your team capacity will be automatically adjusted for the requested dates.</p>';
        } else if (request.Status__c == 'Rejected') {
            emailBody += '<p style="color: #f44336;">Your leave request was not approved. Please contact your manager if you have any questions.</p>';
        }
        
        emailBody += '<p>Best regards,<br>Capacity Planner System</p>';
        emailBody += '</div></body></html>';
        
        return emailBody;
    }
}

//__________________________GenAI: Generated code ends here______________________________//
