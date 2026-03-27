import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboardData from '@salesforce/apex/FinanceDashboardController.getDashboardData';
import hasFinanceLWCComponents from '@salesforce/customPermission/Finance_LWC_Components';

export default class FinanceDashboard extends NavigationMixin(LightningElement) {
    get hasFinancePermission() {
        return hasFinanceLWCComponents;
    }

    @track data;
    @track isLoading = true;
    @track timeFilter = 'THIS_MONTH';

    get filterOptions() {
        return [
            { label: 'Today', value: 'TODAY' },
            { label: 'This Week', value: 'THIS_WEEK' },
            { label: 'This Month', value: 'THIS_MONTH' }
        ];
    }

    connectedCallback() {
        if (this.hasFinancePermission) {
            this.fetchData();
        }
    }

    handleFilterChange(event) {
        this.timeFilter = event.detail.value;
        this.fetchData();
    }

    fetchData() {
        this.isLoading = true;
        this.data = null; // Forces re-render of animations
        getDashboardData({ timeFilter: this.timeFilter })
            .then((result) => {
                this.data = { ...result }; // Clone object to allow safe modification
                this.data.isRefundTrendUp = this.data.refundPercentage > this.data.priorWeekRefundPercentage;
                this.data.isRefundTrendDown = this.data.refundPercentage <= this.data.priorWeekRefundPercentage;
                
                // Add computed CSS for status rails based on percentages
                this.data.successRailStyle = `width: ${this.data.successRate}%`;
                this.data.failedRailStyle = `width: ${this.data.failedRate}%`;
                this.data.pendingRailStyle = `width: ${this.data.pendingRate}%`;

                // Precompute boolean flags for templates (since LWC doesn't support .length checks)
                this.data.hasDailyTrends = this.data.dailyTrends && this.data.dailyTrends.length > 0;
                this.data.hasTopRestaurants = this.data.topRestaurants && this.data.topRestaurants.length > 0;
                this.data.hasTopCustomers = this.data.topCustomers && this.data.topCustomers.length > 0;
                this.data.hasHighRefundOrders = this.data.highRefundOrders && this.data.highRefundOrders.length > 0;

                // Calculate visual bar width for daily trends (relative to local max)
                if (this.data.hasDailyTrends) {
                    let maxRev = 0;
                    this.data.dailyTrends.forEach(dt => { if(dt.revenue > maxRev) maxRev = dt.revenue; });
                    this.data.dailyTrends = this.data.dailyTrends.map(dt => {
                        let widthPct = maxRev > 0 ? (dt.revenue / maxRev) * 100 : 0;
                        let refPct = (dt.revenue > 0) ? (dt.refund / dt.revenue) * widthPct : 0;
                        return {
                            ...dt,
                            revStyle: `width: ${widthPct}%`,
                            refStyle: `width: ${refPct}%`
                        };
                    });
                }
            })
            .catch((error) => {
                console.error('Error loading dashboard data: ', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasData() {
        return this.data != null;
    }

    handleViewRecord(event) {
        const recordId = event.currentTarget.dataset.id;
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