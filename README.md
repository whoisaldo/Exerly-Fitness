# 🏋️‍♂️ Exerly-Fitness

A modern, full-stack fitness tracking application built with React.js, Node.js, and PostgreSQL. Track your workouts, nutrition, sleep, and fitness goals with a beautiful, responsive interface.

![Exerly-Fitness](https://img.shields.io/badge/Exerly-Fitness-Fitness%20App-blue)
![React](https://img.shields.io/badge/React-18.0.0-blue)
![Node.js](https://img.shields.io/badge/Node.js-Express-green)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-blue)

## ✨ Features

### 🎯 **Fitness Tracking**
- **Workout Management** - Create, track, and manage custom workouts
- **Activity Logging** - Log exercises with duration and calorie burn
- **Nutrition Tracking** - Track food intake with macro breakdown (protein, carbs, fat, sugar)
- **Sleep Monitoring** - Log sleep hours and quality
- **Goal Setting** - Set and track fitness objectives

### 🎨 **Modern UI/UX**
- **Glassmorphism Design** - Beautiful, modern interface with glass-like effects
- **Purple Theme** - Exerly's signature purple and black color scheme
- **Responsive Design** - Works perfectly on all devices
- **Smooth Animations** - Engaging user experience with CSS transitions
- **Dark Mode** - Easy on the eyes with elegant dark theme

### 🔐 **User Management**
- **Secure Authentication** - JWT-based login/signup system
- **Profile Management** - Comprehensive user profiles with BMI calculation
- **Unit Preferences** - Toggle between American (lbs, inches) and Metric (kg, cm) units
- **Privacy Settings** - Control profile visibility and notifications

### 👑 **Admin Panel**
- **User Management** - View and manage all users
- **Data Overview** - Comprehensive statistics and insights
- **Entry Management** - View and manage user entries
- **Reset Functionality** - Reset daily data for users

## 🚀 **Live Demo**

🌐 **[View Live Website](https://exerlyfitness.com)**

## 🛠️ **Technology Stack**

### **Frontend**
- **React.js 18** - Modern React with hooks and functional components
- **CSS3** - Advanced styling with CSS variables and animations
- **Responsive Design** - Mobile-first approach with CSS Grid and Flexbox

### **Backend**
- **Node.js** - Server-side JavaScript runtime
- **Express.js** - Web application framework
- **PostgreSQL** - Relational database
- **JWT** - JSON Web Token authentication
- **bcrypt** - Password hashing

### **Deployment**
- **GitHub Pages** - Frontend hosting
- **Heroku** - Backend hosting
- **PostgreSQL (Heroku)** - Database hosting

## 📱 **Screenshots**

*Screenshots coming soon! The app features a beautiful glassmorphism design with a signature purple theme.*

## 🚀 **Getting Started**

### **Prerequisites**
- Node.js (v16 or higher)
- npm or yarn
- ✨ **No database setup needed for local dev!** (Uses SQLite automatically)

### **Installation**

1. **Clone the repository**
   ```bash
   git clone https://github.com/whoisaldo/Exerly-Fitness.git
   cd Exerly-Fitness
   ```

2. **Install dependencies**
   ```bash
   # Install backend dependencies
   cd backend
   npm install
   
   # Install frontend dependencies
   cd ../frontend
   npm install
   ```

3. **Environment Setup**
   
   Create `.env` file in the frontend directory:
   ```env
   REACT_APP_API_URL=https://your-backend-url.com
   REACT_APP_ADMIN_EMAILS=your-admin-email@example.com
   ```

4. **Database Setup**
   - Set up PostgreSQL database
   - Update database connection in backend
   - Run database initialization scripts

5. **Start the application**
   ```bash
   # Start backend (from backend directory)
   npm start
   
   # Start frontend (from frontend directory)
   npm start
   ```

## 🏗️ **Project Structure**

```
Exerly-Fitness/
├── frontend/                 # React frontend application
│   ├── src/
│   │   ├── Components/       # React components
│   │   │   ├── Dashboard/    # Dashboard components
│   │   │   ├── Admin/        # Admin panel
│   │   │   └── LoginSignup/  # Authentication
│   │   ├── App.js           # Main application component
│   │   └── index.js         # Application entry point
│   └── package.json
├── backend/                  # Node.js backend server
│   ├── index.js             # Express server setup
│   ├── routes/              # API routes
│   └── package.json
└── README.md
```

## 🔧 **Key Components**

### **Dashboard (`/dashboard`)**
- Overview of daily fitness metrics
- Quick access to all tracking features
- Real-time statistics and progress

### **Profile (`/dashboard/profile`)**
- Personal information management
- BMI calculation and health metrics
- Unit preference settings (Imperial/Metric)
- Goal and target weight tracking

### **Goals (`/dashboard/goals`)**
- Set fitness objectives
- Track progress over time
- Customizable goal categories

### **Activities (`/dashboard/activities`)**
- Log workout sessions
- Track exercise duration and calories
- Activity history and analytics

### **Food (`/dashboard/food`)**
- Nutrition logging
- Macro tracking (protein, carbs, fat, sugar)
- Meal categorization

### **Sleep (`/dashboard/sleep`)**
- Sleep duration tracking
- Sleep quality assessment
- Sleep pattern analysis

### **Workouts (`/dashboard/workouts`)**
- Custom workout creation
- Exercise library management
- Workout history and progress

### **Admin Panel (`/dashboard/admin`)**
- User management
- Data overview and statistics
- System administration tools

## 🎨 **Design Features**

### **Color Scheme**
- **Primary Purple**: `#8b5cf6`
- **Secondary Purple**: `#a855f7`
- **Accent Purple**: `#ec4899`
- **Dark Background**: `#1e1b4b`
- **Card Background**: Glassmorphism with transparency

### **UI Elements**
- **Glassmorphism Cards** - Semi-transparent cards with backdrop blur
- **Gradient Buttons** - Beautiful gradient buttons with hover effects
- **Smooth Animations** - CSS transitions and keyframe animations
- **Responsive Grid** - CSS Grid layouts that adapt to all screen sizes

## 🔒 **Security Features**

- **JWT Authentication** - Secure token-based authentication
- **Password Hashing** - bcrypt password encryption
- **Protected Routes** - Role-based access control
- **Input Validation** - Server-side and client-side validation
- **CORS Protection** - Cross-origin resource sharing security

## 📊 **Performance Features**

- **Optimized Builds** - Production-ready React builds
- **Lazy Loading** - Component-based code splitting
- **Efficient State Management** - React hooks optimization
- **Responsive Images** - Optimized image loading
- **CSS Optimization** - Minified and optimized stylesheets

## 🌟 **Recent Updates**

### **v2.1 - Feature Enhancements (October 2025)**
- 🗑️ **Delete functionality** for Activities, Food, and Sleep entries
- 📊 **Macro distribution charts** with visual progress bars
- 🎯 **Goals progress display** on dashboard with completion tracking
- 💾 **SQLite support** for local development (no setup needed!)
- ⚙️ **Smart API routing** (auto-detects local vs production)
- ✅ **Confirmation messages** for all save/delete operations
- 🔥 **Intensity levels** for activities with color coding
- 🛌 **Bedtime/wake time tracking** for sleep entries
- 🍽️ **Complete macro tracking** (protein, carbs, fat, sugar)
- 📈 **Real-time progress** calculations and visualizations

### **v2.0 - Complete Frontend Revamp**
- ✨ Modern glassmorphism design
- 🎯 New Goals section
- 🎨 Purple theme throughout
- 📱 Enhanced responsive design
- 🔧 Improved form handling
- 🇺🇸 American units by default with toggle
- 🐛 Bug fixes and performance improvements

### **v1.0 - Initial Release**
- 🏋️‍♂️ Basic fitness tracking
- 🔐 User authentication
- 📊 Dashboard overview
- 🍽️ Food and activity logging

## 🐛 **Bug Reports & Contact**

Found a bug or have an issue? Please contact us directly:

📧 **Email**: [aliyounes@eternalreverse.com](mailto:aliyounes@eternalreverse.com)

We appreciate detailed bug reports including:
- Steps to reproduce the issue
- Expected vs. actual behavior
- Browser/device information
- Screenshots if applicable

## 🤝 **Contributing**

We welcome contributions! Please feel free to submit issues, feature requests, or pull requests.

### **Development Guidelines**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 **License**

© 2025 Ali Younes. All rights reserved.

This code is made publicly viewable for evaluation and testing purposes only.
You MAY clone and run it locally to review functionality.
You MAY NOT copy, distribute, modify, fork, or use it in any other project
without the express written permission of the copyright holder.

## 👨‍💻 **Author**

**Ali Younes** - [GitHub Profile](https://github.com/whoisaldo)

## 🙏 **Acknowledgments**

- React.js community for the amazing framework
- CSS community for glassmorphism design inspiration
- Fitness tracking community for feature suggestions
- All contributors and users of Exerly-Fitness

---

<div align="center">

**Made with ❤️ and 💪 by the Exerly-Fitness Team**

[![GitHub stars](https://img.shields.io/github/stars/whoisaldo/Exerly-Fitness?style=social)](https://github.com/whoisaldo/Exerly-Fitness)
[![GitHub forks](https://img.shields.io/github/forks/whoisaldo/Exerly-Fitness?style=social)](https://github.com/whoisaldo/Exerly-Fitness)
[![GitHub issues](https://img.shields.io/github/issues/whoisaldo/Exerly-Fitness)](https://github.com/whoisaldo/Exerly-Fitness/issues)

</div>
# Force redeploy Fri Oct 17 23:22:16 EDT 2025
