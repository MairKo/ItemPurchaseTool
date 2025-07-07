public with sharing class ItemPurchaseController {
	@AuraEnabled(cacheable=true)
	public static Account getAccountDetails(String accountId) {
		try {
			return [SELECT Id, Name, AccountNumber, Industry FROM Account WHERE Id = :accountId LIMIT 1];
		} catch (Exception e) {
			throw new AuraHandledException('Ошибка при получении данных аккаунта: ' + e.getMessage());
		}
	}

	@AuraEnabled(cacheable=true)
	public static List<Item__c> getItems(String family, String type, String searchKey) {
		try {
			String query = 'SELECT Id, Name, Description__c, Type__c, Family__c, Image__c, Price__c FROM Item__c WHERE Id != NULL';
			if (String.isNotBlank(family)) {
				query += ' AND Family__c = :family';
			}
			if (String.isNotBlank(type)) {
				query += ' AND Type__c = :type';
			}
			if (String.isNotBlank(searchKey)) {
				String searchTerm = '%' + searchKey + '%';
				query += ' AND (Name LIKE :searchTerm OR Description__c LIKE :searchTerm)';
			}
			return Database.query(query);
		} catch (Exception e) {
			throw new AuraHandledException('Ошибка при получении элементов: ' + e.getMessage());
		}
	}

	@AuraEnabled(cacheable=true)
	public static Boolean isManager() {
		try {
			return [SELECT IsManager__c FROM User WHERE Id = :UserInfo.getUserId()].IsManager__c;
		} catch (Exception e) {
			throw new AuraHandledException('Ошибка при проверке статуса менеджера: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static Item__c createItem(String name, String description, String type, String family, Decimal price) {
		try {
			// Сначала получаем URL изображения
			String imageUrl = getImageUrl(name);

			// Создаем запись с возможным URL
			Item__c newItem = new Item__c(
					Name = name,
					Description__c = description,
					Type__c = type,
					Family__c = family,
					Price__c = price,
					Image__c = imageUrl
			);
			insert newItem;

			return newItem;
		} catch (Exception e) {
			throw new AuraHandledException('Ошибка создания итема: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static Purchase__c createPurchase(String accountId, List<Map<String, Object>> cartItems) {
		try {
			Purchase__c purchase = new Purchase__c(ClientId__c = accountId);
			insert purchase;

			List<PurchaseLine__c> lines = new List<PurchaseLine__c>();
			for (Map<String, Object> item : cartItems) {
				lines.add(new PurchaseLine__c(
						PurchaseId__c = purchase.Id,
						ItemId__c = (String) item.get('itemId'),
						Amount__c = (Decimal) item.get('amount'),
						UnitCost__c = (Decimal) item.get('unitCost')
				));
			}
			insert lines;
			return purchase;
		} catch (Exception e) {
			throw new AuraHandledException('Ошибка при создании заказа: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static String getImageUrl(String itemName) {
		try {
			Http http = new Http();
			HttpRequest request = new HttpRequest();
			request.setEndpoint('https://api.unsplash.com/search/photos?query=' + EncodingUtil.urlEncode(itemName, 'UTF-8'));
			request.setMethod('GET');
			request.setHeader('Authorization', 'Client-ID W-dKZ33mIiSjlvFbaDdjJzaWnPFebS5qG7FEG5rbXQc'); // Убедись, что токен верный!
			HttpResponse response = http.send(request);
			System.debug('Response Status: ' + response.getStatusCode() + ' Body: ' + response.getBody());
			if (response.getStatusCode() == 200) {
				Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
				List<Object> results = (List<Object>)result.get('results');
				if (!results.isEmpty()) {
					Map<String, Object> photo = (Map<String, Object>)results[0];
					Map<String, Object> urls = (Map<String, Object>)photo.get('urls');
					return (String)urls.get('small');
				} else {
					System.debug('No images found for query: ' + itemName);
					return null;
				}
			} else {
				System.debug('API request failed with status: ' + response.getStatusCode() + ' - ' + response.getBody());
				return null;
			}
		} catch (Exception e) {
			System.debug('Error fetching image URL: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
			return null;
		}
	}

	@AuraEnabled
	public static void updateItemImage(Id itemId, String imageUrl) {
		try {
			Item__c item = new Item__c(Id = itemId, Image__c = imageUrl);
			update item;
			System.debug('Image updated for item ID: ' + itemId + ' with URL: ' + imageUrl);
		} catch (Exception e) {
			throw new AuraHandledException('Ошибка обновления изображения: ' + e.getMessage());
		}
	}
}