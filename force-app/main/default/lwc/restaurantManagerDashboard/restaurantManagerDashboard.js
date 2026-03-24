import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboardData from '@salesforce/apex/RestaurantManagerController.getDashboardData';
import hasAccess from '@salesforce/customPermission/Restaurant_LWC_Components';

export default class RestaurantManagerDashboard extends NavigationMixin(LightningElement) {
    @track kpiData = { totalRestaurants: 0, activeRestaurants: 0, inactiveRestaurants: 0, pendingApprovals: 0, restaurantsWithIssues: 0 };
    @track topRestaurants = [];
    @track problemRestaurants = [];
    @track recentApprovals = [];
    @track error;
    @track isLoading = true;
    @track hasDashboardAccess = false;

    connectedCallback() {
        this.hasDashboardAccess = hasAccess;
    }

    @wire(getDashboardData)
    wiredData({ error, data }) {
        if (data) {
            this.kpiData = data.kpis;
            this.topRestaurants = data.topRestaurants;
            
            this.problemRestaurants = data.problemRestaurants.map(pr => {
                let riskClass = 'risk-badge low';
                if (pr.riskLevel === 'HIGH') riskClass = 'risk-badge high';
                else if (pr.riskLevel === 'MEDIUM') riskClass = 'risk-badge medium';
                
                let mappedTickets = pr.tickets ? pr.tickets.map((t, idx) => {
                    return { ...t, keyId: 'tix-' + idx };
                }) : [];

                return { ...pr, riskClass, tickets: mappedTickets };
            });

            this.recentApprovals = data.recentApprovals;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unknown error';
            this.isLoading = false;
        }
    }

    get hasProblemRestaurants() {
        return this.problemRestaurants && this.problemRestaurants.length > 0;
    }

    handleNavigateToRecord(event) {
        const recordId = event.target.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        }
    }
}
