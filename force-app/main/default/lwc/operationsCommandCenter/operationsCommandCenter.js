import { LightningElement, track, wire } from 'lwc';
import getDashboardData from '@salesforce/apex/OperationsCommandCenterController.getDashboardData';
import { refreshApex } from '@salesforce/apex';
import hasAccess from '@salesforce/customPermission/Operation_LWC_Components';

export default class OperationsCommandCenter extends LightningElement {
    @track data;
    @track error;
    @track isLoading = true;
    @track hasDashboardAccess = false;
    
    wiredResult;

    connectedCallback() {
        this.hasDashboardAccess = hasAccess;
    }

    @wire(getDashboardData)
    wiredData(result) {
        this.wiredResult = result;
        if (result.data) {
            this.data = result.data;
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error.body ? result.error.body.message : 'An unknown error occurred connecting to Operations Command Center.';
            this.data = undefined;
            this.isLoading = false;
        }
    }

    refreshData() {
        this.isLoading = true;
        refreshApex(this.wiredResult)
            .finally(() => {
                this.isLoading = false;
            });
    }
}