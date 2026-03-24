import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPendingApprovals from '@salesforce/apex/RestaurantApprovalController.getPendingApprovals';
import getPastApprovals from '@salesforce/apex/RestaurantApprovalController.getPastApprovals';
import processApproval from '@salesforce/apex/RestaurantApprovalController.processApproval';
import hasAccess from '@salesforce/customPermission/Operation_LWC_Components';

export default class RestaurantApprovalConsole extends LightningElement {
    @track requests = [];
    @track selectedRequest = null;
    @track isLoading = true;
    @track isActionLoading = false;
    @track comments = '';
    @track error = '';
    @track hasDashboardAccess = false;
    @track pastApprovals = [];
    @track isPastLoading = true;

    connectedCallback() {
        this.hasDashboardAccess = hasAccess;
    }

    // To hold the wired result for refreshApex
    wiredRequestsResult;
    wiredPastRequestsResult;

    @wire(getPendingApprovals)
    wiredApprovals(result) {
        this.wiredRequestsResult = result;
        if (result.data) {
            this.requests = result.data.map(req => {
                return {
                    ...req,
                    cardClass: 'request-card'
                };
            });
            this.error = undefined;
            this.isLoading = false;
            
            // Re-apply selection state if we have a selected card
            if(this.selectedRequest) {
                const stillExists = this.requests.find(r => r.restaurantId === this.selectedRequest.restaurantId);
                if(!stillExists) {
                    this.selectedRequest = null;
                } else {
                    this.updateCardSelection(this.selectedRequest.restaurantId);
                }
            }
        } else if (result.error) {
            this.error = result.error.body ? result.error.body.message : 'Error fetching approvals';
            this.requests = [];
            this.isLoading = false;
        }
    }

    @wire(getPastApprovals)
    wiredPastData(result) {
        this.wiredPastRequestsResult = result;
        if (result.data) {
            this.pastApprovals = result.data.map(req => {
                const isAccepted = req.status === 'Accepted' || req.status === 'Approved';
                return {
                    ...req,
                    isIconCheck: isAccepted,
                    isIconClose: req.status === 'Rejected',
                    cardClass: isAccepted ? 'past-card accepted' : 'past-card rejected'
                };
            });
            this.isPastLoading = false;
        } else if (result.error) {
            console.error('Error fetching past approvals: ', result.error);
            this.pastApprovals = [];
            this.isPastLoading = false;
        }
    }

    get hasPastApprovals() {
        return this.pastApprovals && this.pastApprovals.length > 0;
    }

    get isListEmpty() {
        return !this.isLoading && this.requests && this.requests.length === 0;
    }

    get isActionDisabled() {
        return this.isActionLoading;
    }

    handleSelectRequest(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.selectedRequest = this.requests.find(req => req.restaurantId === selectedId);
        this.comments = ''; // Reset notes on new selection
        
        this.updateCardSelection(selectedId);
    }

    updateCardSelection(selectedId) {
        this.requests = this.requests.map(req => {
            return {
                ...req,
                cardClass: req.restaurantId === selectedId ? 'request-card selected' : 'request-card'
            };
        });
    }

    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    async handleApprove() {
        if (!this.validateComments()) return;
        await this.handleAction('Approve');
    }

    async handleReject() {
        if (!this.validateComments()) return;
        await this.handleAction('Reject');
    }

    validateComments() {
        if (!this.comments || this.comments.trim() === '') {
            this.showToast('Warning', 'Approval notes are required.', 'warning');
            return false;
        }
        return true;
    }

    async handleAction(action) {
        this.isActionLoading = true;
        try {
            await processApproval({ 
                workItemId: this.selectedRequest.workItemId, 
                action: action, 
                comments: this.comments 
            });
            
            // Success
            const actionText = action === 'Approve' ? 'Approved' : 'Rejected';
            this.showToast('Success', `Restaurant has been ${actionText}.`, 'success');
            
            // Clear selection and refresh list
            this.selectedRequest = null;
            this.comments = '';
            await refreshApex(this.wiredRequestsResult);
            if (this.wiredPastRequestsResult) {
                await refreshApex(this.wiredPastRequestsResult);
            }
            
        } catch (error) {
            console.error('Action error', error);
            this.showToast('Error', error.body ? error.body.message : 'An error occurred during process.', 'error');
        } finally {
            this.isActionLoading = false;
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}
