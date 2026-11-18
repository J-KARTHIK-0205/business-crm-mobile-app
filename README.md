# Business CRM Mobile Application

A cross-platform Business Customer Relationship Management (CRM) application developed using Flutter, Firebase Authentication, PHP and MySQL. The application helps businesses manage customers, leads, organizations, tasks and business activities through a centralized mobile interface.

## Project Overview

The Business CRM Mobile Application is designed to simplify customer relationship management by providing an organized platform for managing business information, tracking leads, handling tasks and viewing reports.

The application integrates a Flutter frontend with a PHP backend API and a MySQL database, while Firebase Authentication provides user authentication.

## Technologies Used

| Technology | Purpose |
|---|---|
| Flutter | Mobile application development |
| Dart | Application programming language |
| Firebase Authentication | User authentication |
| Cloud Firestore | User-related application data |
| PHP | Backend API development |
| MySQL | Database management |
| MySQL Workbench | Database administration |
| HTTP | API communication |
| Git & GitHub | Version control |

## Application Modules

### 1. Dashboard
- Displays an overview of CRM activities.
- Shows customer, lead and task information.
- Provides dashboard data synchronization.

### 2. Customer Management
- Add new customers.
- View customer records.
- Update customer information.
- Delete customer records.

### 3. Lead Management
- Manage business leads.
- View and update lead information.
- Track lead status.
- Convert qualified leads into customers.

### 4. Organization Management
- Manage organization information.
- View and maintain organization records.

### 5. Task Management
- Create and manage tasks.
- Track pending and completed tasks.

### 6. Reports
- View business-related reports and summaries.

### 7. Settings and Profile
- Manage user profile information.
- Configure application preferences.
- Support light and dark themes.

### 8. Authentication
- User registration.
- User login.
- Forgot password functionality.
- Firebase-based authentication.

## Project Architecture

The application follows a frontend-backend-database architecture.

Flutter Mobile Application
          |
          | HTTP Requests
          |
          v
       PHP API
          |
          | Database Queries
          |
          v
      MySQL Database

Firebase Authentication
          |
          v
     User Verification

## Project Structure

business_crm/
│
├── lib/
│   ├── auth/
│   ├── auth_screens/
│   ├── screens/
│   ├── widgets/
│   ├── main.dart
│   └── firebase_options.dart
│
├── android/
├── assets/
├── test/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
└── README.md

## Installation and Setup

### Prerequisites

Install the following tools:

- Flutter SDK
- Dart SDK
- Android Studio
- Visual Studio Code
- PHP
- MySQL Server
- MySQL Workbench
- Git

### Step 1: Clone the Repository

git clone https://github.com/J-KARTHIK-0205/business-crm.git

### Step 2: Open the Project

cd business-crm

### Step 3: Install Dependencies

flutter pub get

### Step 4: Configure Firebase

Configure Firebase for your own development environment.

Ensure that the appropriate Firebase project configuration files are available locally. Never commit service-account private keys or other secret credentials.

### Step 5: Configure the Backend

Clone and configure the PHP API repository:

https://github.com/J-KARTHIK-0205/business-crm-api

Configure the MySQL database connection in the backend's local configuration file.

### Step 6: Run the Application

flutter run

## Database

Database Name: `business_crm`

The MySQL database contains the following tables:

1. users
2. customers
3. leads
4. organizations
5. tasks
6. activities
7. notifications
8. settings

The database backup can be maintained separately as `business_crm.sql`.

## API Configuration

The Flutter application communicates with the PHP backend using HTTP requests.

Example local API addresses:

- Web: `http://localhost/business_crm_api`
- Android Emulator: `http://10.0.2.2/business_crm_api`

For physical Android devices, configure the backend URL using your computer's local network IP address.

For production deployment, host the backend and database on a properly secured server and use HTTPS.

## Testing

The following development and testing activities have been carried out:

- MySQL database and CRUD operations.
- PHP and MySQL database connectivity.
- Flutter and PHP API integration.
- Customer data synchronization.
- Dashboard data synchronization.
- CRM component testing.
- Flutter static code analysis.

## Security Considerations

- Firebase Authentication is used for user authentication.
- Backend APIs validate authenticated requests.
- User-specific records are handled through account-based filtering.
- Database credentials and Firebase service-account files must remain private.
- Production deployment should use HTTPS and secure database configuration.

## Future Enhancements

- Cloud deployment of the backend.
- Production-ready Android APK distribution.
- Advanced analytics and reporting.
- Enhanced notifications.
- Additional CRM automation features.

## Author
**J Karthik**
B.E – Computer Science and Engineering (Artificial Intelligence)

## License

This project is developed as an academic and internship project.
