trigger PurchaseTrigger on Purchase__c (after insert, after update) {
	if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
		PurchaseTriggerHandler.updateTotals(Trigger.new);
	}
}