@isTest
private class ItemPurchaseControllerTest {
	@TestSetup
	static void makeData() {
		Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
		User u = new User(
				Alias = 'testAdm',
				Email = 'testadmin@truesolv.com' + System.currentTimeMillis(),
				EmailEncodingKey = 'UTF-8',
				LastName = 'TestAdmin',
				LanguageLocaleKey = 'en_US',
				LocaleSidKey = 'en_US',
				ProfileId = p.Id,
				TimeZoneSidKey = 'America/Los_Angeles',
				UserName = 'testadmin@truesolv.com' + System.currentTimeMillis()
		);
		insert u;

		System.runAs(u) {
			// Создание кастомных объектов
			Purchase__c purchaseTemplate = new Purchase__c();
			PurchaseLine__c lineTemplate = new PurchaseLine__c();
			if (!Schema.sObjectType.Purchase__c.isCreateable()) {
				throw new SecurityException('No access to Purchase__c');
			}
			if (!Schema.sObjectType.PurchaseLine__c.isCreateable()) {
				throw new SecurityException('No access to PurchaseLine__c');
			}

			Account acc = new Account(Name = 'Test Account', AccountNumber = '12345', Industry = 'Technology');
			insert acc;

			Item__c item = new Item__c(Name = 'Test Item', Description__c = 'Test Description', Type__c = 'Electronics', Family__c = 'Premium', Price__c = 100);
			insert item;

			u.IsManager__c = true;
			update u;
		}
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
		User u = [SELECT Id, IsManager__c FROM User WHERE Email LIKE 'testadmin@truesolv.com%' LIMIT 1];
		System.runAs(u) {
			Test.startTest();
			Boolean result = ItemPurchaseController.isManager();
			Test.stopTest();
			System.assertEquals(true, result, 'Manager status should be true');
		}
	}

	@isTest
	static void testCreatePurchase() {
		User u = [SELECT Id FROM User WHERE Email LIKE 'testadmin@truesolv.com%' LIMIT 1];
		System.runAs(u) {
			Account acc = [SELECT Id FROM Account LIMIT 1];
			Item__c item = [SELECT Id FROM Item__c LIMIT 1];
			List<Map<String, Object>> cartItems = new List<Map<String, Object>>{
					new Map<String, Object>{
					'itemId' => item.Id,
					'amount' => 2.0,
					'unitCost' => 100.0
					}
					};

			Test.startTest();
			Purchase__c result;
			try {
				result = ItemPurchaseController.createPurchase(acc.Id, cartItems);
				System.debug('Purchase result: ' + result);
			} catch (Exception e) {
				System.debug('Exception in test: ' + e.getMessage() + ' at ' + e.getStackTraceString());
				System.assert(false, 'Purchase creation should not throw exception: ' + e.getMessage());
				return;
			}
			Test.stopTest();

			System.assertNotEquals(null, result, 'Purchase should be created');
			System.assertEquals(1, [SELECT COUNT() FROM PurchaseLine__c WHERE PurchaseId__c = :result.Id], 'One purchase line should be created');
			System.assertEquals(acc.Id, result.ClientId__c, 'ClientId should match accountId');
		}
	}
}