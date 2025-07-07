public with sharing class PurchaseLineTriggerHandler {
	public static void updatePurchaseTotals(List<PurchaseLine__c> newLines, List<PurchaseLine__c> oldLines, Boolean isDelete, Boolean isUndelete) {
		// Сбор всех ID заказов, затронутых триггером
		Set<Id> purchaseIds = new Set<Id>();

		if (isDelete && oldLines != null) {
			for (PurchaseLine__c line : oldLines) {
				if (line.PurchaseId__c != null) {
					purchaseIds.add(line.PurchaseId__c);
				}
			}
		} else if (newLines != null) {
			for (PurchaseLine__c line : newLines) {
				if (line.PurchaseId__c != null) {
					purchaseIds.add(line.PurchaseId__c);
				}
			}
		}

		// Если нет ID для обработки, выходим
		if (purchaseIds.isEmpty()) {
			return;
		}

		// Получаем агрегированные данные
		Map<Id, AggregateResult> purchaseTotals = new Map<Id, AggregateResult>();
		for (AggregateResult ar : [
				SELECT PurchaseId__c, SUM(Amount__c) totalItems
				FROM PurchaseLine__c
				WHERE PurchaseId__c IN :purchaseIds
				GROUP BY PurchaseId__c
		]) {
			purchaseTotals.put((Id)ar.get('PurchaseId__c'), ar);
		}

		// Получаем сумму для grandTotal
		Map<Id, Decimal> purchaseGrandTotals = new Map<Id, Decimal>();
		for (AggregateResult ar : [
				SELECT PurchaseId__c, SUM(Amount__c) totalAmount, SUM(UnitCost__c) totalUnitCost
				FROM PurchaseLine__c
				WHERE PurchaseId__c IN :purchaseIds
				GROUP BY PurchaseId__c
		]) {
			Decimal totalAmount = (Decimal)ar.get('totalAmount');
			Decimal totalUnitCost = (Decimal)ar.get('totalUnitCost');
			purchaseGrandTotals.put((Id)ar.get('PurchaseId__c'), totalAmount != null && totalUnitCost != null ? totalAmount * totalUnitCost : 0);
		}

		// Подготовка записей для обновления
		List<Purchase__c> purchasesToUpdate = new List<Purchase__c>();
		for (Id purchaseId : purchaseIds) {
			Decimal totalItems = purchaseTotals.containsKey(purchaseId) ? (Decimal)purchaseTotals.get(purchaseId).get('totalItems') : 0;
			Decimal grandTotal = purchaseGrandTotals.containsKey(purchaseId) ? purchaseGrandTotals.get(purchaseId) : 0;
			purchasesToUpdate.add(new Purchase__c(
					Id = purchaseId,
					TotalItems__c = totalItems,
					GrandTotal__c = grandTotal
			));
		}

		// Обновление записей, если есть что обновлять
		if (!purchasesToUpdate.isEmpty()) {
			update purchasesToUpdate;
		}
	}
}