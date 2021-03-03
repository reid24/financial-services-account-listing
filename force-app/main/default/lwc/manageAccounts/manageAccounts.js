import { LightningElement, wire, api, track } from 'lwc';
import getAccountsApex from '@salesforce/apex/ManageAccountsController.getAccounts';
import updateAccounts from '@salesforce/apex/ManageAccountsController.updateAccounts';
import { refreshApex } from '@salesforce/apex';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

//Define the columns for our datatable component
//Note special treatment given to Account Name and Account Owner
//recordLink and ownerName are created manually in the wired method getAccounts below
//We need the fieldName to be the URL to the account record.  This works but has the drawback
//that we cannot make the Account Name field editable in inline edit this way.
//The alternative is using a button (commented out below) but this seems to hide the inline edit pencil icon.
//There is not a workaround to support both inline edit and a hyperlinked account name at the same time.
//The Account Owner column displays the name of the Owner
//We support editing this field by special treatment of it in the Apex method updateAccounts
const COLS = [
    // { 
    //     label: 'Account Name', fieldName: 'Name', editable: true, sortable: true, type: 'button',  
    //     typeAttributes: { label: { fieldName: 'Name' }, variant:'base' }
    // },
    { 
        label: 'Account Name', fieldName: 'recordLink', editable: false, sortable: true, type: 'url',  
        typeAttributes: { label: { fieldName: "Name" }, tooltip:"Name", target: "_blank" }
    },
    { label: 'Account Owner', fieldName: 'ownerName', editable: true, sortable: true },
    { label: 'Phone', fieldName: 'Phone', type: 'phone', editable: true },
    { label: 'Website', fieldName: 'Website', editable: true },
    { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency', editable: true }
];    

export default class ManageAccounts extends LightningElement {
    //by default sort by Name ascending
    sortBy = "Name";
    sortDirection = "asc";

    //holds the account name filter field value, connected to the lightning input at the top of the page
    filter;

    //the inline edit draft values are stored in an array
    draftValues = [];
    
    //the columns used by the datatable are put in class property
    columns = COLS;

    //accountList is referenced by the datatable, and populated via the wired getAccounts method
    @track 
    accountList = [];  

    //this list is maintained for filtering to revert back
    fullAccountList = [];
    
    //a separate wired list is required to support the refreshApex call effectively
    @track 
    wiredAccountList = [];  

    

    //wired method to fetch the accounts list
    @wire(getAccountsApex)
    getAccounts(result) {  
        //wire the result to this variable to allow for refreshApex call
        this.wiredAccountList = result;

        if (result.data) {  
            //construct the recordLink and ownerName field attributes to be used by the datatable
            var tempList = [];  
            for (var i = 0; i < result.data.length; i++) {  
                //clone the object
                let tempRecord = Object.assign({}, result.data[i]);
                tempRecord.recordLink = "/" + tempRecord.Id;  
                tempRecord.ownerName = tempRecord.Owner.Name;
                tempList.push(tempRecord);  
            }  
            //assign to the class variable
            this.accountList = tempList;  
            this.error = undefined;  
        } else if (result.error) {  
            this.error = result.error;  
            this.accountList = undefined;  
        } 
    }  

    callRowAction(event){
        console.log('onclickAccountName', JSON.stringify(event));
        window.open(event.detail.row.recordLink, '_blank');
    }

    //support sorting by Account Name and Account Owner columns
    sort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
    }
    
    //a generic sorting algorithm
    sortData(fieldname, direction) {
        let parseData = JSON.parse(JSON.stringify(this.accountList));
        //recordLink is given special treatment here, we want to sort by the Name value not the recordLink value
        if(fieldname == "recordLink") fieldname = "Name";
        
        // Return the value stored in the field
        let keyValue = (a) => a[fieldname];
        // cheking reverse direction
        let isReverse = direction === 'asc' ? 1: -1;
        
        // sorting data
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; // handling null values
            y = keyValue(y) ? keyValue(y) : '';
            // sorting values based on direction
            return isReverse * ((x > y) - (y > x));
        });

        //finally assign the sorted list to the accountList class attribute
        this.accountList = parseData;
    }

    handleFilterChange(event){
        console.log(event.detail.value);
        this.filter = event.detail.value;
        
        if(!this.filter || this.filter == '') {
            this.accountList = this.fullAccountList;
            return;
        }

        if(this.fullAccountList.length == 0) this.fullAccountList = this.accountList;
        
        var localFilter = this.filter.toLowerCase();
        
        let tempList = [];
        this.fullAccountList.forEach(function(acct){
            let accountName = acct['Name'];
            console.log(accountName);
            console.log(accountName.includes(localFilter));
            if(accountName && accountName.toLowerCase().includes(localFilter)) tempList.push(acct);
        })
        this.accountList = tempList;
    }

    async handleSave(event) {
        const updatedFields = event.detail.draftValues;
        
        // Prepare the record IDs for getRecordNotifyChange()
        const notifyChangeIds = updatedFields.map(row => { return { "recordId": row.Id } });
    
       // Pass edited fields to the updateAccounts Apex controller
        await updateAccounts({data: updatedFields}).then(result => {
            //on success create the toast success event
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Accounts updated',
                    variant: 'success'
                })
            );
            
            // Refresh LDS cache and wires
            getRecordNotifyChange(notifyChangeIds);

            // Display fresh data in the datatable
            refreshApex(this.wiredAccountList);
            this.draftValues = [];
        
       }).catch(error => {
           //handle errors through toast error message
           this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating records',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }
}