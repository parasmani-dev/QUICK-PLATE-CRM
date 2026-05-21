import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMySubmittedRestaurants from '@salesforce/apex/RestaurantOnboardingTrackerCtrl.getMySubmittedRestaurants';
import submitRestaurantForApproval from '@salesforce/apex/RestaurantOnboardingTrackerCtrl.submitRestaurantForApproval';

export default class RestaurantOnboardingTracker extends LightningElement {
    @track isSubmitting = false;
    @track submissions = [];
    @track isLoading = true;

    wiredTrackerResult;

    @wire(getMySubmittedRestaurants)
    wiredSubmissions(result) {
        this.wiredTrackerResult = result;
        if (result.data) {
            this.submissions = result.data.map(sub => {
                let badgeClass = 'badge badge-default';
                if(sub.approvalStatus === 'Approved') badgeClass = 'badge badge-approved';
                else if(sub.approvalStatus === 'Rejected') badgeClass = 'badge badge-rejected';
                else if(sub.approvalStatus === 'Pending') badgeClass = 'badge badge-pending';
                
                return {
                    ...sub,
                    statusBadgeClass: badgeClass
                };
            });
            this.isLoading = false;
        } else if (result.error) {
            this.isLoading = false;
            this.showToast('Error', 'Error loading tracker data', 'error');
            console.error(result.error);
        }
    }

    handleSubmit(event) {
        event.preventDefault(); 
        const fields = event.detail.fields;
        this.isSubmitting = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        const recordId = event.detail.id;
        
        submitRestaurantForApproval({ restaurantId: recordId })
            .then(() => {
                this.showToast('Success', 'Restaurant created and submitted for approval!', 'success');
                const inputFields = this.template.querySelectorAll('lightning-input-field');
                if (inputFields) {
                    inputFields.forEach(field => field.reset());
                }
                return refreshApex(this.wiredTrackerResult);
            })
            .catch(error => {
                console.error(error);
                let message = error.body ? error.body.message : error.message;
                // Sometimes Salesforce might throw a specific error if process definition isn't found
                this.showToast('Submit Error', message, 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title, message, variant
        }));
    }
}