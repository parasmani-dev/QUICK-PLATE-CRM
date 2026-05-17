import { LightningElement } from 'lwc';
import FINANCE_BANNER from '@salesforce/resourceUrl/Finance_Banner';
import hasFinanceLWCComponents from '@salesforce/customPermission/Finance_LWC_Components';

export default class FinanceBanner extends LightningElement {
    bannerUrl = FINANCE_BANNER;
    
    get hasFinancePermission() {
        return hasFinanceLWCComponents;
    }
}