# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.



- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) (or [oxc](https://oxc.rs) when used in [rolldown-vite](https://vite.dev/guide/rolldown)) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and [`typescript-eslint`](https://typescript-eslint.io) in your project.


# 🚀 Quick Plate – Salesforce Powered Food Delivery System

Quick Plate is a full-stack food delivery platform where:

- 🛒 Customers use **React**
- 🧠 Business logic runs entirely inside **Salesforce**
- 🚚 Delivery lifecycle is controlled by backend automation
- 💳 Stripe handles payments
- 🔄 Real-time tracking is powered by REST polling

---


## 🔹 Frontend
- React (Vite)
- Framer Motion (animations)
- Axios (API communication)
- Haptic feedback hooks
- Local delivery status simulation

## 🔹 Backend (Salesforce)
- Custom Objects:
  - `Order__c`
  - `Delivery_Agent__c`
  - `Restaurant__c`
  - `Payment_Transaction__c`
- Apex REST Controllers
- Invocable Apex (Flow-triggered)
- Delivery Assignment Engine
- Order Lifecycle Engine
- Stripe Webhook Integration

---

# 🚀 Core Features

---

## 1️⃣ Payment Flow

1. Customer places order (React)
2. Stripe Checkout handles payment
3. Stripe webhook updates:
   - `Payment_Status__c = PAID`
   - `Order_Status__c = CONFIRMED`
4. React polls `/order/status/{id}`
5. Redirects to Tracking page on success

---

## 2️⃣ Delivery Agent Assignment Engine

When order becomes `CONFIRMED`:

- Invocable Apex runs
- Filters eligible agents:
  - `Is_Active__c = TRUE`
  - `Service_Status__c = ONLINE`
  - Same city
  - Under max active load
  - Rejection count below threshold
- Assigns lowest workload agent
- Updates:
  - `Order_Status__c = ASSIGNED`
  - `Delivery_Agent__c`
  - Agent workload increment

---


