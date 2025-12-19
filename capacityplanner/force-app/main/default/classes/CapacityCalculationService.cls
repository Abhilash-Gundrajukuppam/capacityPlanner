//_______________This Code was generated using GenAI tool: Codify, Please check for accuracy_______________//

public with sharing class CapacityCalculationService {
    
    /**
     * Update capacity tracking when leave is approved
     */
    public static void updateCapacityForApprovedLeave(Id leaveRequestId) {
        try {
            Leave_Request__c leaveRequest = [
                SELECT Id, Requestor__c, Start_Date__c, End_Date__c, 
                       Is_Single_Day__c, Hours_Requested__c, Leave_Type__c
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId LIMIT 1
            ];
            
            List<Date> leaveDates = getDateRange(leaveRequest.Start_Date__c, 
                leaveRequest.Is_Single_Day__c ? leaveRequest.Start_Date__c : leaveRequest.End_Date__c);
            
            List<Capacity_Tracking__c> capacityRecords = new List<Capacity_Tracking__c>();
            
            for (Date leaveDate : leaveDates) {
                // Check if capacity record already exists
                List<Capacity_Tracking__c> existingRecords = [
                    SELECT Id, Leave_Hours__c
                    FROM Capacity_Tracking__c 
                    WHERE Team_Member__c = :leaveRequest.Requestor__c 
                    AND Date__c = :leaveDate LIMIT 1
                ];
                
                Decimal leaveHours = calculateLeaveHours(leaveRequest.Leave_Type__c, leaveRequest.Requestor__c);
                
                if (!existingRecords.isEmpty()) {
                    // Update existing record
                    Capacity_Tracking__c existingRecord = existingRecords[0];
                    existingRecord.Leave_Hours__c = (existingRecord.Leave_Hours__c != null ? existingRecord.Leave_Hours__c : 0) + leaveHours;
                    capacityRecords.add(existingRecord);
                } else {
                    // Create new record
                    capacityRecords.add(createCapacityRecord(leaveRequest.Requestor__c, leaveDate, leaveHours));
                }
            }
            
            upsert capacityRecords;
            
        } catch (Exception e) {
            System.debug('Error updating capacity for approved leave: ' + e.getMessage());
            throw new AuraHandledException('Error updating capacity: ' + e.getMessage());
        }
    }
    
    /**
     * Calculate leave hours based on leave type
     */
    private static Decimal calculateLeaveHours(String leaveType, Id teamMemberId) {
        Team_Member__c teamMember = [
            SELECT Daily_Capacity_Hours__c FROM Team_Member__c WHERE Id = :teamMemberId LIMIT 1
        ];
        
        if (leaveType == 'Full Day') {
            return teamMember.Daily_Capacity_Hours__c;
        } else if (leaveType == 'Half Day') {
            return teamMember.Daily_Capacity_Hours__c / 2;
        }
        
        return 0;
    }
    
    /**
     * Create new capacity tracking record
     */
    private static Capacity_Tracking__c createCapacityRecord(Id teamMemberId, Date recordDate, Decimal leaveHours) {
        Team_Member__c teamMember = [
            SELECT Daily_Capacity_Hours__c FROM Team_Member__c WHERE Id = :teamMemberId LIMIT 1
        ];
        
        Capacity_Tracking__c capacityRecord = new Capacity_Tracking__c();
        capacityRecord.Team_Member__c = teamMemberId;
        capacityRecord.Date__c = recordDate;
        capacityRecord.Base_Hours__c = teamMember.Daily_Capacity_Hours__c;
        capacityRecord.Leave_Hours__c = leaveHours;
        capacityRecord.Holiday_Hours__c = calculateHolidayHours(teamMemberId, recordDate);
        
        return capacityRecord;
    }
    
    /**
     * Calculate holiday hours for a specific date
     */
    private static Decimal calculateHolidayHours(Id teamMemberId, Date recordDate) {
        Team_Member__c teamMember = [
            SELECT Location__c, Daily_Capacity_Hours__c FROM Team_Member__c WHERE Id = :teamMemberId LIMIT 1
        ];
        
        List<Holiday__c> holidays = [
            SELECT Id FROM Holiday__c 
            WHERE Location__c = :teamMember.Location__c 
            AND Start_Date__c <= :recordDate 
            AND End_Date__c >= :recordDate 
            AND Is_Active__c = true
            LIMIT 1
        ];
        
        return holidays.isEmpty() ? 0 : teamMember.Daily_Capacity_Hours__c;
    }
    
    /**
     * Generate date range between start and end date
     */
    private static List<Date> getDateRange(Date startDate, Date endDate) {
        List<Date> dateRange = new List<Date>();
        Date currentDate = startDate;
        
        while (currentDate <= endDate) {
            // Skip weekends (Saturday = 7, Sunday = 1)
            Datetime currentDatetime = Datetime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
            String dayOfWeek = currentDatetime.format('u');
            
            if (dayOfWeek != '6' && dayOfWeek != '7') { // Skip Saturday and Sunday
                dateRange.add(currentDate);
            }
            
            currentDate = currentDate.addDays(1);
        }
        
        return dateRange;
    }
    
    /**
     * Get team capacity summary for manager dashboard
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTeamCapacitySummary(Id managerId, String projectStartDate, String endDate) {
        try {
            Date start = Date.valueOf(projectStartDate);
            Date endDt = Date.valueOf(endDate);
            
            // Get team members
            List<Team_Member__c> teamMembers = [
                SELECT Id, First_Name__c, Last_Name__c, Daily_Capacity_Hours__c, Story_Points_Per_Hour__c
                FROM Team_Member__c 
                WHERE Manager__c = :managerId AND Status__c = 'Active'
            ];
            
            List<Id> teamMemberIds = new List<Id>();
            for (Team_Member__c member : teamMembers) {
                teamMemberIds.add(member.Id);
            }
            
            // Get capacity data
            List<Capacity_Tracking__c> capacityData = [
                SELECT Team_Member__c, Date__c, Available_Hours__c, Base_Hours__c,
                       Leave_Hours__c, Holiday_Hours__c
                FROM Capacity_Tracking__c 
                WHERE Team_Member__c IN :teamMemberIds 
                AND Date__c >= :start AND Date__c <= :endDt
                ORDER BY Date__c, Team_Member__c
            ];
            
            // Calculate totals
            Decimal totalHours = 0;
            Decimal availableHours = 0;
            
            for (Capacity_Tracking__c record : capacityData) {
                totalHours += (record.Base_Hours__c != null ? record.Base_Hours__c : 0);
                availableHours += (record.Available_Hours__c != null ? record.Available_Hours__c : 0);
            }
            
            // Calculate story points
            Decimal totalStoryPoints = 0;
            for (Team_Member__c member : teamMembers) {
                Decimal memberAvailableHours = 0;
                for (Capacity_Tracking__c record : capacityData) {
                    if (record.Team_Member__c == member.Id) {
                        memberAvailableHours += (record.Available_Hours__c != null ? record.Available_Hours__c : 0);
                    }
                }
                totalStoryPoints += memberAvailableHours * (member.Story_Points_Per_Hour__c != null ? member.Story_Points_Per_Hour__c : 0);
            }
            
            Map<String, Object> summary = new Map<String, Object>();
            summary.put('totalHours', totalHours);
            summary.put('availableHours', availableHours);
            summary.put('totalStoryPoints', totalStoryPoints);
            summary.put('capacityData', capacityData);
            summary.put('teamMembers', teamMembers);
            
            return summary;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating team capacity: ' + e.getMessage());
        }
    }
    
    /**
     * Generate capacity records for a date range (used for initialization)
     */
    public static void generateCapacityRecords(Id teamMemberId, Date projectStartDate, Date endDate) {
        List<Date> dateRange = getDateRange(projectStartDate, endDate);
        List<Capacity_Tracking__c> recordsToInsert = new List<Capacity_Tracking__c>();
        
        for (Date recordDate : dateRange) {
            // Check if record already exists
            List<Capacity_Tracking__c> existing = [
                SELECT Id FROM Capacity_Tracking__c 
                WHERE Team_Member__c = :teamMemberId AND Date__c = :recordDate LIMIT 1
            ];
            
            if (existing.isEmpty()) {
                recordsToInsert.add(createCapacityRecord(teamMemberId, recordDate, 0));
            }
        }
        
        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________//
