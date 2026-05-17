import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Security Requirement: Using custom permissions to restrict access
import hasFinanceLWCComponents from '@salesforce/customPermission/Finance_LWC_Components';

// Placeholder imports for your Apex Controller interactions
import getPendingRefundTickets from '@salesforce/apex/RefundApprovalController.getPendingRefundTickets';
import getRefundDetails from '@salesforce/apex/RefundApprovalController.getRefundDetails';
import approveRefund from '@salesforce/apex/RefundApprovalController.approveRefund';
import rejectRefund from '@salesforce/apex/RefundApprovalController.rejectRefund';

export default class RefundApprovalConsole extends LightningElement {
    
    // UI rendering gates based on authorization
    get hasFinancePermission() {
        return hasFinanceLWCComponents;
    }

    @track pendingTickets = [];
    @track selectedTicketId = null;
    @track selectedTicketDetails = null;

    // Async state tracking
    isListLoading = false;
    isDetailLoading = false;
    isActionLoading = false;

    // Finance payload trackers
    refundAmount = null;
    financeNotes = '';

    connectedCallback() {
        if (this.hasFinancePermission) {
            this.fetchPendingTickets();
        }
    }

    /** 
     * Requirement: getPendingRefundTickets()
     */
    fetchPendingTickets() {
        this.isListLoading = true;
        
        getPendingRefundTickets()
            .then((result) => {
                this.pendingTickets = result.map(ticket => ({
                    ...ticket,
                    // Determine Priority Badge CSS class based on backend state
                    priorityClass: this.getPriorityClass(ticket.Priority),
                    // Set active visual state
                    cardClass: this.selectedTicketId === ticket.Id ? 'ticket-card selected' : 'ticket-card'
                }));
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to load pending requests. ' + this.reduceErrors(error), 'error');
            })
            .finally(() => {
                this.isListLoading = false;
            });
    }

    /**
     * Requirement: Clickable item loads details on the right panel
     */
    handleTicketSelect(event) {
        const ticketId = event.currentTarget.dataset.id;
        if (ticketId === this.selectedTicketId) return;

        this.selectedTicketId = ticketId;
        
        // Visually highlight the newly selected ticket in the array
        this.pendingTickets = this.pendingTickets.map(ticket => ({
            ...ticket,
            cardClass: ticket.Id === ticketId ? 'ticket-card selected' : 'ticket-card'
        }));

        this.fetchTicketDetails(ticketId);
    }

    /**
     * Requirement: getRefundDetails(ticketId) -> Returns combined data
     */
    fetchTicketDetails(ticketId) {
        this.isDetailLoading = true;
        
        getRefundDetails({ ticketId: ticketId })
            .then((result) => {
                this.selectedTicketDetails = result;
                
                // Requirement: Finance team sets the refund amount derived from Order_Total or input
                // Prefill value with RecommendedRefundAmount if provided by Support, otherwise OrderTotal 
                this.refundAmount = result.RecommendedRefundAmount || result.OrderTotal || 0;
                this.financeNotes = '';
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to load ticket details: ' + this.reduceErrors(error), 'error');
                this.selectedTicketId = null;
            })
            .finally(() => {
                this.isDetailLoading = false;
            });
    }

    handleNotesChange(event) {
        this.financeNotes = event.target.value;
    }

    handleAmountChange(event) {
        this.refundAmount = event.target.value;
    }

    get isOverLimit() {
        if (!this.refundAmount || !this.selectedTicketDetails) return false;
        const amount = parseFloat(this.refundAmount) || 0;
        const max = parseFloat(this.selectedTicketDetails.OrderTotal) || 0;
        return amount > max;
    }

    /**
     * Requirement: trigger backend financial operation for Approval
     */
    handleApprove() {
        if (!this.refundAmount || this.refundAmount <= 0) {
            this.showToast('Validation Error', 'Refund amount must be greater than zero.', 'error');
            return;
        }

        this.isActionLoading = true;
        approveRefund({ 
            ticketId: this.selectedTicketId, 
            amount: this.refundAmount, 
            notes: this.financeNotes 
        })
        .then(() => {
            // Requirement: Highlight success toast & auto-refresh
            this.showToast('Success', 'Refund Approved and payment transaction created.', 'success');
            // Remove resolved ticket from the pending local list
            this.pendingTickets = this.pendingTickets.filter(t => t.Id !== this.selectedTicketId);
            this.clearSelection();
        })
        .catch(error => {
            this.showToast('Approval Failed', this.reduceErrors(error), 'error');
        })
        .finally(() => {
            this.isActionLoading = false;
        });
    }

    /**
     * Requirement: trigger backend financial operation for Rejection
     */
    handleReject() {
        if (!this.financeNotes) {
            this.showToast('Validation Error', 'Please provide notes explaining the rationale for rejection.', 'error');
            return;
        }

        this.isActionLoading = true;
        rejectRefund({ 
            ticketId: this.selectedTicketId, 
            notes: this.financeNotes 
        })
        .then(() => {
            this.showToast('Success', 'Refund Request Rejected effectively.', 'success');
            this.pendingTickets = this.pendingTickets.filter(t => t.Id !== this.selectedTicketId);
            this.clearSelection();
        })
        .catch(error => {
            this.showToast('Rejection Failed', this.reduceErrors(error), 'error');
        })
        .finally(() => {
            this.isActionLoading = false;
        });
    }

    // Helper: Reset selection state
    clearSelection() {
        this.selectedTicketId = null;
        this.selectedTicketDetails = null;
        this.refundAmount = null;
        this.financeNotes = '';
    }

    // Colors priority appropriately
    getPriorityClass(priority) {
        let baseClass = 'slds-badge ';
        const priorityUpper = (priority || '').toUpperCase();
        
        if (priorityUpper === 'HIGH' || priorityUpper === 'CRITICAL') {
            return baseClass + 'badge-high';
        } else if (priorityUpper === 'MEDIUM') {
            return baseClass + 'badge-medium';
        }
        return baseClass + 'badge-low';
    }

    // Visual formatting to warn finance member of repeat offenders
    get issueCountClass() {
        if (!this.selectedTicketDetails) return '';
        const count = this.selectedTicketDetails.CustomerIssueCount || 0;
        if (count >= 3) return 'slds-text-color_error slds-text-title_bold';
        if (count > 0) return 'text-warning slds-text-title_bold';
        return 'slds-text-color_success';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    reduceErrors(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        } else if (error && error.message) {
            return error.message;
        }
        return String(error);
    }
}