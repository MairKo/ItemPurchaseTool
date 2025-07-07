import { LightningElement, wire, track, api } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getAccountDetails from '@salesforce/apex/ItemPurchaseController.getAccountDetails';
import getItems from '@salesforce/apex/ItemPurchaseController.getItems';
import isManager from '@salesforce/apex/ItemPurchaseController.isManager';
import createItem from '@salesforce/apex/ItemPurchaseController.createItem';
import createPurchase from '@salesforce/apex/ItemPurchaseController.createPurchase';
import getImageUrl from '@salesforce/apex/ItemPurchaseController.getImageUrl';
import updateItemImage from '@salesforce/apex/ItemPurchaseController.updateItemImage';

export default class ItemPurchaseTool extends NavigationMixin(LightningElement) {
    @track account = {};
    @track items = { data: [] };
    @track cartItems = [];
    @track showCreateModal = false;
    @track showCartModal = false;
    @track showDetailsModal = false;
    @track selectedFamily = '';
    @track selectedType = '';
    @track searchKey = '';
    @track newItem = { name: '', description: '', type: '', family: '', price: null };
    @track isManager = false;
    @track totalItems = 0;
    @track grandTotal = 0;
    @track selectedItemId;
    @track selectedItemName;
    @track selectedItemDescription;
    @track selectedItemType;
    @track selectedItemFamily;
    @track selectedItemPrice;
    @track selectedItemImage;
    wiredItemsResult;

    @api recordId;

    familyOptions = [
        { label: 'All', value: '' }, { label: 'Premium', value: 'Premium' }, { label: 'Standard', value: 'Standard' }
    ];
    typeOptions = [
        { label: 'All', value: '' }, { label: 'Electronics', value: 'Electronics' }, { label: 'Clothing', value: 'Clothing' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: ['Account.Name', 'Account.AccountNumber', 'Account.Industry'] })
    wiredAccount({ error, data }) {
        console.log('RecordId:', this.recordId); // Отладка
        if (data) {
            this.account = {
                Name: getFieldValue(data, 'Account.Name'),
                AccountNumber: getFieldValue(data, 'Account.AccountNumber'),
                Industry: getFieldValue(data, 'Account.Industry')
            };
            console.log('Account loaded:', this.account);
        } else if (error) {
            this.showToast('Error', 'Failed to load account details: ' + JSON.stringify(error), 'error');
            console.error('Error loading account:', error);
        }
    }

    connectedCallback() {
        isManager().then(result => this.isManager = result).catch(error => this.showToast('Error', 'Manager check failed', 'error'));
        this.refreshItems();
    }

    @wire(getItems, { family: '$selectedFamily', type: '$selectedType', searchKey: '$searchKey' })
    wiredItems(result) {
        this.wiredItemsResult = result;
        if (result.data) {
            this.items.data = result.data.map(item => ({ ...item, quantity: 0 }));
        } else if (result.error) {
            this.showToast('Error', 'Failed to load items', 'error');
        }
    }

    handleFamilyChange(event) { this.selectedFamily = event.target.value; }
    handleTypeChange(event) { this.selectedType = event.target.value; }
    handleSearchChange(event) { this.searchKey = event.target.value; }
    applyFilters() {
        refreshApex(this.wiredItemsResult).then(() => {
            this.showToast('Success', 'Filters applied', 'success');
        }).catch(error => this.showToast('Error', 'Filter application failed', 'error'));
    }
    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        const quantity = parseInt(event.target.value, 10) || 0;
        const item = this.items.data.find(i => i.Id === itemId);
        if (item) item.quantity = quantity;
    }
    handleAddToCart(event) {
        const itemId = event.target.dataset.id;
        const item = this.items.data.find(i => i.Id === itemId);
        if (item && item.quantity > 0) {
            const cartItem = this.cartItems.find(i => i.itemId === itemId);
            if (cartItem) cartItem.amount = item.quantity;
            else this.cartItems.push({ itemId, name: item.Name, amount: item.quantity, unitCost: item.Price__c });
            this.updateTotals();
            this.showToast('Success', 'Item added to cart', 'success');
        } else {
            this.showToast('Error', 'Please enter a valid quantity', 'error');
        }
    }
    handleRemoveFromCart(event) {
        const itemId = event.target.dataset.id;
        this.cartItems = this.cartItems.filter(i => i.itemId !== itemId);
        this.updateTotals();
    }
    openCreateModal() { this.showCreateModal = true; }
    closeCreateModal() { this.showCreateModal = false; this.resetNewItemFields(); }
    handleNewItemChange(event) {
        const field = event.target.name;
        if (field === 'price') {
            this.newItem[field] = event.target.value ? parseFloat(event.target.value) : null;
        } else {
            this.newItem[field] = event.target.value;
        }
    }
    saveNewItem() {
        if (!this.newItem.name || !this.newItem.price) {
            this.showToast('Error', 'Name and Price are required', 'error');
            return;
        }
        createItem({
            name: this.newItem.name,
            description: this.newItem.description,
            type: this.newItem.type,
            family: this.newItem.family,
            price: this.newItem.price
        })
        .then(result => {
            this.showToast('Success', 'Item created', 'success');
            this.closeCreateModal();
            this.refreshItems();
        })
        .catch(error => {
            this.showToast('Error', error.body ? error.body.message : 'Unknown error', 'error');
        });
    }
    openCartModal() { this.showCartModal = true; }
    closeCartModal() { this.showCartModal = false; }
    openDetailsModal(event) {
        const itemId = event.target.dataset.id;
        const item = this.items.data.find(i => i.Id === itemId);
        if (item) {
            this.selectedItemId = item.Id;
            this.selectedItemName = item.Name;
            this.selectedItemDescription = item.Description;
            this.selectedItemType = item.Type__c;
            this.selectedItemFamily = item.Family__c;
            this.selectedItemPrice = item.Price__c;
            this.selectedItemImage = item.Image__c || '';
            this.showDetailsModal = true;
        }
    }
    closeDetailsModal() { this.showDetailsModal = false; }
    confirmOrder() {
        const accountId = this.recordId;
        if (accountId && this.cartItems.length > 0) {
            createPurchase({ accountId, cartItems: this.cartItems })
                .then(purchaseId => {
                    this.showToast('Success', 'Order placed', 'success');
                    this.closeCartModal();
                    this.cartItems = [];
                    this.updateTotals();
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: { recordId: purchaseId, objectApiName: 'Purchase__c', actionName: 'view' }
                    });
                })
                .catch(error => this.showToast('Error', error.body.message, 'error'));
        } else this.showToast('Error', 'Invalid account or cart', 'error');
    }

    refreshItems() { this.items = { data: [] }; refreshApex(this.wiredItemsResult); }
    resetNewItemFields() {
        this.newItem = { name: '', description: '', type: '', family: '', price: null };
    }
    updateTotals() {
        this.totalItems = this.cartItems.reduce((sum, item) => sum + item.amount, 0);
        this.grandTotal = this.cartItems.reduce((sum, item) => sum + (item.amount * item.unitCost), 0);
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    stopPropagation(event) {
        event.stopPropagation();
    }
}