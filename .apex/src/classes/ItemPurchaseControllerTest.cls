@isTest
private class ItemPurchaseControllerTest {
	@TestSetup
	static void makeData() {
		Account acc = new Account(Name = 'Test Account', AccountNumber = '12345', Industry = 'Technology');
		insert acc;

		Item__c item = new Item__c(Name = 'Test Item', Description__c = 'Test Description', Type__c = 'Electronics', Family__c = 'Premium', Price__c = 100);
		insert item;

		User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
		u.IsManager__c = true;
		update u;
	}

	@isTest
	static void testGetAccountDetails() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		Test.startTest();
		Account result = ItemPurchaseController.getAccountDetails(acc.Id);
		Test.stopTest();
		System.assertEquals(acc.Id, result.Id, 'Account details should match');
	}

	@isTest
	static void testGetItems() {
		Test.startTest();
		List<Item__c> result = ItemPurchaseController.getItems('Premium', 'Electronics', 'Test');
		Test.stopTest();
		System.assert(!result.isEmpty(), 'Items should be returned');
	}

	@isTest
	static void testIsManager() {
		User u = [SELECT Id, IsManager__c FROM User WHERE IsActive = true LIMIT 1];
		Test.startTest();
		Boolean result = ItemPurchaseController.isManager();
		Test.stopTest();
		System.assertEquals(u.IsManager__c, result, 'Manager status should match');
	}

	@isTest
	static void testCreatePurchase() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		Item__c item = [SELECT Id FROM Item__c LIMIT 1];
		List<Map<String, Object>> cartItems = new List<Map<String, Object>>{
				new Map<String, Object>{
				'itemId' => item.Id,
				'amount' => 2.0, // Убедимся, что тип Decimal
				'unitCost' => 100.0 // Убедимся, что тип Decimal
				}
				};

		Test.startTest();
		Purchase__c result;
		try {
			result = ItemPurchaseController.createPurchase(acc.Id, cartItems);
		} catch (Exception e) {
			System.debug('Exception: ' + e.getMessage());
			System.assert(false, 'Purchase creation should not throw exception: ' + e.getMessage());
			return;
		}
		Test.stopTest();

		System.assertNotEquals(null, result, 'Purchase should be created');
		System.assertEquals(1, [SELECT COUNT() FROM PurchaseLine__c WHERE PurchaseId__c = :result.Id], 'One purchase line should be created');
		System.assertEquals(acc.Id, result.ClientId__c, 'ClientId should match accountId');
	}
}