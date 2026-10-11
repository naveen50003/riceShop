# 🌾 Rice Shop Customer Management App

A Flutter-based customer management application designed for **Rice Shops / Ration Shops** to maintain customer details, manage operational records, import/export customer data through Excel, and quickly search and update customer information.

The application uses **Hive** as its local database and supports Flutter Web and Android environments.

---

## 📱 Features

### 👥 Master Customer Management

The Master Customer List is the permanent customer directory.

It supports:

- Add new customers
- Edit existing customers
- Delete customers
- Search customers
- Pagination
- Unique Ration Card Number
- Automatic insert/update based on Ration Card Number
- Excel import
- Excel export
- Mobile number
- Aadhaar number
- Units
- Customer details lookup

### 📋 View Records

View Records maintains operational/shop records.

Features include:

- Add customer records
- Edit records
- Delete records
- Search records
- Pagination
- Excel import
- Excel export
- Customer details management
- Call customer
- Send SMS
- WhatsApp communication
- Share customer information

---

## 🔄 Master Customer vs View Records

The application separates permanent customer information from operational records.

```text
                 ┌─────────────────────────┐
                 │     Master Customers     │
                 │                         │
                 │ Permanent Customer Data  │
                 │                         │
                 │ Ration Card             │
                 │ Name                    │
                 │ Mobile                  │
                 │ Aadhaar                 │
                 │ Units                   │
                 └────────────┬────────────┘
                              │
                              │ Lookup
                              ▼
                 ┌─────────────────────────┐
                 │       Add Customer      │
                 │                         │
                 │ Search by Ration Card   │
                 │                         │
                 │ Auto-populate details   │
                 └────────────┬────────────┘
                              │
                              ▼
                 ┌─────────────────────────┐
                 │      View Records       │
                 │                         │
                 │ Operational Records     │
                 │                         │
                 │ Daily shop activity     │
                 └─────────────────────────┘

## Steps to run the application
D:\work\rice_shop_appln\android\app\build\outputs\apk\release - remove apk in this folder

D:\work\rice_shop_appln\android  ------> .\gradlew assembleRelease --stacktrace

flutter clean
flutter pub get
flutter run