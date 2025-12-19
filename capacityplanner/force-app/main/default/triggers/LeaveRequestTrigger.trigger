//_______________This Code was generated using GenAI tool: Codify, Please check for accuracy_______________//

trigger LeaveRequestTrigger on Leave_Request__c (after insert, after update) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            LeaveRequestTriggerHandler.handleAfterInsert(Trigger.new);
        }
        
        if (Trigger.isUpdate) {
            LeaveRequestTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}

//__________________________GenAI: Generated code ends here______________________________//
