import { LightningElement, wire, track } from 'lwc';
import getActiveOrders from '@salesforce/apex/OrderLifecycleController.getActiveOrders';
import updateOrderStatus from '@salesforce/apex/OrderLifecycleController.updateOrderStatus';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import hasAccess from '@salesforce/customPermission/Operation_LWC_Components';

const STAGES = [
    { label: 'Payment Pending', value: 'PAYMENT_PENDING' },
    { label: 'Confirmed', value: 'CONFIRMED' },
    { label: 'Preparing', value: 'PREPARING' },
    { label: 'Out for Delivery', value: 'OUT_FOR_DELIVERY' },
    { label: 'Delivered', value: 'DELIVERED' },
    { label: 'Cancelled', value: 'CANCELLED' }
];

export default class Order_lifecycle extends NavigationMixin(LightningElement) {
    @track stages = STAGES.map(stage => ({ ...stage, orders: [] }));
    @track isLoading = true;
    @track hasDashboardAccess = false;

    connectedCallback() {
        this.hasDashboardAccess = hasAccess;
    }

    wiredOrdersResult;

    @wire(getActiveOrders)
    wiredOrders(result) {
        this.wiredOrdersResult = result;
        const { data, error } = result;
        if (data) {
            this.processOrders(data);
            this.isLoading = false;
        } else if (error) {
            if (this.hasDashboardAccess) {
                // Only show toast if they actually have access but something else failed.
                // If they don't have access, the template will simply show Access Denied.
                this.showToast('Error', error.body ? error.body.message : 'Failed to load orders', 'error');
            }
            this.isLoading = false;
        }
    }

    processOrders(data) {
        // Reset stages
        let newStages = STAGES.map(s => ({
            label: s.label,
            value: s.value,
            orders: []
        }));

        data.forEach(wrapper => {
            const order = wrapper.order;
            // Find corresponding stage bucket
            const stageIndex = newStages.findIndex(s => s.value === order.Order_Status__c);
            
            if (stageIndex !== -1) {
                newStages[stageIndex].orders.push({
                    id: order.Id,
                    orderNumber: order.Name,
                    customerName: order.Customer__r ? order.Customer__r.Name : 'N/A',
                    restaurantName: order.Restaurant__r ? order.Restaurant__r.Name : 'N/A',
                    deliveryAgentName: order.Delivery_Agent__r ? order.Delivery_Agent__r.Name : 'Unassigned',
                    orderTotal: order.Order_Total__c || 0,
                    createdTime: new Date(order.CreatedDate).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                    slaStatus: order.SLA_Status__c || 'N/A',
                    slaClass: this.getSlaClass(order.SLA_Status__c),
                    canEdit: wrapper.canEdit,
                    draggable: wrapper.canEdit ? 'true' : 'false'
                });
            }
        });

        this.stages = newStages;
    }

    getSlaClass(status) {
        if (status === 'At Risk') return 'sla-badge sla-risk';
        if (status === 'Breached') return 'sla-badge sla-breached';
        return 'sla-badge sla-safe';
    }

    handleDragStart(event) {
        event.dataTransfer.setData('orderId', event.target.dataset.id);
    }

    handleDragOver(event) {
        event.preventDefault(); // Necessary to allow dropping
    }

    async handleDrop(event) {
        event.preventDefault();
        const orderId = event.dataTransfer.getData('orderId');
        
        let targetElement = event.target;
        // Travel up to find the closest stage-column
        while (!targetElement.dataset.stageName && targetElement.parentElement) {
            targetElement = targetElement.parentElement;
        }

        const newStage = targetElement.dataset.stageName;

        if (orderId && newStage) {
            this.isLoading = true;
            try {
                await updateOrderStatus({ orderId: orderId, newStatus: newStage });
                this.showToast('Success', 'Order status updated successfully', 'success');
                await refreshApex(this.wiredOrdersResult);
            } catch (error) {
                this.showToast('Error', error.body ? error.body.message : 'Failed to update order status', 'error');
                this.isLoading = false; // refreshApex also re-triggers wire so it unsets loading there usually, but manual catch
            }
        }
    }

    handleViewDetails(event) {
        const orderId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order__c',
                actionName: 'view'
            }
        });
    }

    handleEditRecord(event) {
        const orderId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order__c',
                actionName: 'edit'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}