import { LightningElement } from 'lwc';
import RESTAURANT_OP from '@salesforce/resourceUrl/RESTAURANT_OP';

export default class RestaurantOpBanner extends LightningElement {
    bannerUrl = RESTAURANT_OP;
}