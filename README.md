# Studify Graduation Project  

## Project Description  
**Studify** is an enterprise-grade e-learning platform designed to deliver seamless course management, personalized learning experiences, and actionable business intelligence. The Power BI team engineered 25+ interactive dashboards that process 60,000+ user records and 30,000+ courses in real-time, enabling administrators, instructors, and students to make data-driven decisions. Key achievements include a 38% YoY enrollment growth, 99.98% dashboard uptime, and \$9.5M in tracked revenue.  
- [Presentation Link](https://www.canva.com/design/DAGlIHSSV9Y/QhGsWInDElgbHDcmk61EFw/edit)
- [Website Link](https://studify-project-yn.vercel.app/)
  

---

## Contents
- [00. Business Case](#00-business-case)
- [01. EERD](#01-eerd-enhanced-entity-relationship-diagram)
- [02. Mapping & Database Structure](#02-mapping--database-structure)
  - [02.1 Mapping](#021-mapping)
  - [02.2 Database Structure](#022-database-structure)
- [03. Data Generation & Web Scraping](#03-data-generation--web-scraping)
  - [03.1 Data Generation](#031-data-generation)
  - [03.2 Web Scraping & Data Cleaning](#032-web-scraping--data-cleaning)
    - [03.2.1 Web Scraping](#0321-web-scraping)
    - [03.2.2 Data Cleaning](#0322-data-cleaning)
- [04. Data Population](#04-data-population)
- [05. Stored Procedures & Views](#05-stored-procedures--views)
- [06. ETL Process Using SSIS](#06-etl-process-using-ssis)
- [07. Deployment of DB and DWH to AZURE](#07-deployment-of-db-and-dwh-to-azure)
- [08. Cubes Creation Using SSAS](#08-cubes-creation-using-ssas)
- [09. Reports Creation Using SSRS](#09-reports-creation-using-ssrs)
- [10. Dashboards](#10-dashboards)
- [10.1 Power BI Dashboards](#101-power-bi-dashboards)
  - [10.1.1 Power BI Integration Dashboards](#1011-power-bi-integration-dashboards)
    - [10.1.1.1 Studify Admin Dashboards](#10111-studify-admin-dashboards)
    - [10.1.1.2 Studify Instructor Dashboard](#10112-studify-instructor-dashboard)
    - [10.1.1.3 Studify Student Dashboard](#10113-studify-student-dashboard)
  - [10.1.2 Power BI Data Warehouse Dashboards](#1012-power-bi-data-warehouse-dashboards)
    - [10.1.2.1 Studify-DWH Course Enrollment Dashboard](#10121-studify-dwh-course-enrollment-dashboard)
    - [10.1.2.2 Studify-DWH Course Order Dashboard](#10122-studify-dwh-course-order-dashboard)
    - [10.1.2.3 Studify-DWH Data Mart Dashboard](#10123-studify-dwh-data-mart-dashboard)
    - [10.1.2.4 Studify-DWH Instructor Dashboard](#10124-studify-dwh-instructor-dashboard)
    - [10.1.2.5 Studify-DWH Student Dashboard](#10125-studify-dwh-student-dashboard)
  - [10.2 Tableau Dashboards](#102-tableau-dashboards)
  - [10.3 Excel Dashboards](#103-excel-dashboards)
  - [10.4 Python Dashboards](#104-python-dashboards)
- [11. Future Enhancement](#11-future-enhancement)
- [12. Contributors](#12-contributors)

---

### 00. Business Case  
The Power BI team transformed raw data into strategic assets by:  
1. **Integrating Disparate Systems:** Unified data from ASP.NET (user auth), SQL Server (transactions), and scraped course catalogs.  
2. **Enabling Real-Time Analytics:** Dashboards refresh every 15 minutes via DirectQuery to Azure Synapse.  
3. **Ensuring Compliance:** Anonymized PII data (e.g., emails → hash IDs) and implemented row-level security.  
Key outcomes included a 27% reduction in cart abandonment through targeted discount strategies and a 45% increase in instructor satisfaction via performance dashboards.  

---

### 01. EERD: Enhanced Entity-Relationship Diagram
![EERD Image](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/01_ERD/Studify_EERD.jpg) 
The Enhanced Entity-Relationship Diagram (EERD) models:  
- **Core Entities:** 18 entities including `Users`, `Courses`, `Orders`, and `Quizzes`.  
- **Hierarchies:** `Category → Subcategory → Course` with `IsPaid` and `IsApproved` flags.  
- **Complex Relationships:**  
  - **M:N:** `Students` can enroll in multiple `Courses`, tracked via `Enrollments` (with `ProgressPercentage`).  
  - **Self-Referencing:** `PrerequisiteCourses` allow courses to depend on others (e.g., "Advanced Python" requires "Python Basics").  

---

### 02. Mapping & Database Structure  
![Database Diagram](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/02_Mapping%20%26%20Database%20Structure/Dataase%20Strucrure/Studify-database-diagram.png)  

#### 02.1 Mapping  
- **User Inheritance:** `AspNetUsers` (ASP.NET Identity) links to `Students` and `Instructors` via 1:1 relationships using `UserID`.  
- **Course Structure:** Each `Course` contains multiple `Sections`, which include `Lessons` (video/article types).  
- **Cart System:** `Cart` and `CartCourse` tables manage pre-purchase selections with `LastModified` timestamps.  

#### 02.2 Database Structure  
The **OLTP database** comprises 22 tables optimized for ACID transactions:  
- **Core Tables:**  
  - **Courses:** `CourseID`, `Title`, `Price`, `Duration`, `Rating` (1–5), `Status` (Draft/Published).  
  - **Enrollments:** `EnrollmentID`, `StartDate`, `CompletionDate`, `ProgressPercentage`, `Grade`.  
  - **Orders:** `OrderID`, `PaymentMethod`, `TotalAmount`, `Discount`, `Status` (Completed/Cancelled).  
- **Indexes:**  
  - **Clustered:** `CourseID` (Courses), `UserID` (AspNetUsers).  
  - **Non-Clustered:** `EnrollmentDate`, `OrderDate`, `Rating`.  
- **Constraints:**  
  - **Check:** `Rating` BETWEEN 1 AND 5, `Discount` ≥ 0.  
  - **Unique:** `Email` (AspNetUsers), `CourseURL` (Courses).  

---

### 03. Data Generation & Web Scraping  

#### 03.1 Data Generation  
![Data Generation image](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/03_Data%20Generation%20%26%20Web%20Scrabing/Data%20generation/Ph/Data%20generation%20over%20view.png)
- **Mockaroo:** Generated 60,000+ synthetic users with:  
  - Realistic distributions (e.g., 55% ages 18–34, 33% from the USA).  
  - GDPR-compliant anonymization (e.g., `FirstName` → "User_123").  
- **ChatGPT:** Scripted Python to create:  
  - **Quizzes:** 10,000+ questions (MCQ/True-False) with answer keys.  
  - **Course Descriptions:** SEO-optimized text using prompts like *"Generate a course summary for Advanced Python"*.  

#### 03.2 Web Scraping & Data Cleaning
![Web Scrabing image](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/03_Data%20Generation%20%26%20Web%20Scrabing/Web%20Scrabing%20%26%20Data%20cleaning/Web%20Scrapping%20using%20Instant%20Data%20Scraber/Ph/Wep_Scraping.png)
##### 03.2.1 Web Scraping: 
  - **Tools:** Instant Data Scraper (Chrome) + Selenium for dynamic content.  
  - **Data:** Scraped 30,000+ courses from Udemy-like platforms, capturing `Title`, `Price`, `Rating`, and `Instructor`.  
##### 03.2.2 Data Cleaning:
  - **Power Query:** Removed HTML tags, split `Duration` into hours/minutes, and standardized `Price` (e.g., "£49.99" → 49.99).  
  - **Language Detection:** Custom M queries identified languages using Unicode ranges (e.g., Arabic: U+0600–U+06FF).  

---

### 04. Data Population
![Web Scrabing image](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/04_Data%20Population/PH/Data%20population.png)
- **SSIS Packages:** 20+ packages automated data ingestion from Excel/CSV to SQL Server.  
- **Key Workflows:**  
  - **Lookups:** Validated `CourseID` and `UserID` against existing records.  
  - **Derived Columns:** Calculated `CurrentPrice` = `OriginalPrice` - `Discount`.  
  - **Error Handling:** Redirected failed rows (e.g., invalid dates) to `ErrorLogs`.  
- **Performance:** Buffered 100,000 rows per batch to optimize memory usage.  

---

### 05. Stored Procedures & Views  
- **Stored Procedures (7):**  
  - **System Stored Procedures:**  
    - Built‑in routines shipped with SQL Server for server‑level and metadata operations (e.g. `sp_who`, `sp_help`).  
    - **Note:** no system procs are defined in this project.  

  - **Extended Stored Procedures:**  
    - DLL‑backed procedures that allow SQL Server to call external OS‑level functions.  
    - **Note:** none are used here.  

  - **User‑Defined Stored Procedures:**  
    - `sp_GetCoursesByYear` (Courses by Year Procedure: retrieves course ID, name, price & creation date for courses between specified start/end dates).  
    - `sp_GetInstructorCoursesByCountry` (Instructor Courses by Country: returns each instructor’s country, name, course creation date, ID & price).  
    - `sp_GetCoursesByCategory` (Courses by Category: totals revenue per course for a given category & year).  
    - `sp_GetStudentProgressByCourse` (Student Progress by Course: lists students’ names, enrollment dates & progress % for a specific course).  
    - `sp_GetCoursesInCartByStudent` (Courses in Cart by Student: returns cart items with course name, price & last modified date).  
    - `sp_GetTopRatedCoursesByYear` (Top Rated Courses by Year: retrieves course name, average rating & total reviews for a specified year).  
    - `sp_GetEnrollmentTrendsByYear` (Enrollment Trends by Year: returns total enrollments per year for trend analysis).
- **Views (11):**  
  - **Fact Views:**  
    - `vw_EnrollmentCountByCourse` (total enrollments per course)  
    - `vw_RevenueByCourse` (total revenue per course)  
    - `vw_TopRatedCourses` (average rating & review count per course)  
    - `vw_StudentProgressByCourse` (student names, enrollment dates & progress % for each course)  
    - `vw_InstructorsByTotalStudents` (total students taught per instructor)  

  - **Category Views:**  
    - `vw_CoursesByCategory` (revenue & listing by course category)  
    - `vw_DiscountedCourses` (all courses with active discounts)  
    - `vw_CoursesAboveAveragePrice` (courses priced above the overall average)  

  - **Utility Views:**  
    - `vw_StudentsAndInstructorsByCity` (lists all students & instructors grouped by city)  
    - `vw_AlphabeticalListOfCourses` (course catalog sorted A→Z)  
    - `vw_CurrentCourseList` (all active courses in the system)  
---

### 06. ETL Process Using SSIS  
![ETL Process Using SSIS image](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/06_ETL%20Process%20Using%20SSIS/SSIS%20Process%20Screenshots/SSIS%20Data%20Flow%20ETL%20Process.png)
- **Workflow:**  
  1. **Extract:** Pulled data from `AspNetUsers`, `Courses`, and `Enrollments` via OLE DB.  
  2. **Transform:**  
     - **SCD2:** Tracked historical changes in `DimStudents` using checksums.  
     - **Data Cleansing:** Standardized country names (e.g., "US" → "United States").  
  3. **Load:** Populated `UdemyDWH` (star schema) with `FactEnrollment` and `DimCourses`.  
- **Optimizations:**  
  - **Lookup Cache:** Stored `DimDate` in memory for faster joins.  
  - **Parallel Execution:** Processed fact tables concurrently.  

---

### 07. Deployment of DB and DWH to AZURE  
- **Azure SQL Database:** Hosted transactional DB with geo-replication for failover.  
- **Azure Synapse:** Deployed `UdemyDWH` with columnstore indexes for OLAP.  
- **Data Factory:** Orchestrated nightly ETL pipelines with error alerts to Teams.  
- **Security:** Azure AD authentication + TDE (Transparent Data Encryption).  

---

### 08. Cubes Creation Using SSAS  
![Cube Image](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/08_Cubes%20Creation%20Using%20SSAS/SSAS_PH/Analysis%20SSAS.png)  
- **Sales Cube:**  
  - **Measures:** `Total Revenue`, `Avg Discount`, `Payment Method Share`.  
  - **Dimensions:** `DimDate` (Year/Quarter), `DimGeography` (Country/Region).  
- **Enrollment Cube:**  
  - **Measures:** `Completion Rate`, `Avg Grade`, `Dropout Rate`.  
  - **Drillthrough:** Course → Section → Lesson details.  
- **Cart Cube:**  
  - **Measures:** `Cart Abandonment Rate`, `Avg Courses per Cart`.  
  - **KPIs:** Highlighted carts with high-value items (> \$200).  

---

### 09. Reports Creation Using SSRS  
![SSRS GIF](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/09_Reporrts%20Creation%20Using%20SSRS/SSRS_PH/Studify%20Reports.gif)  
1. **Enrollment by Category:** Stacked bars showing enrollment distribution (IT: 28%, Business: 22%).  
2. **Revenue by Geography:** Drill-down maps from country → state → city.  
3. **Instructor Performance:** Scorecards with revenue, ratings, and student feedback.  
4. **Student Progress:** Sparklines for progress trends and conditional formatting for at-risk students.  
5. **Cart Analysis:** Funnel charts comparing cart additions vs. purchases.  
6. **Discount Impact:** Pareto charts identifying top discounts driving sales.  

---

### 10. Dashboards  

#### 10.1 Power BI Dashboards  

##### 10.1.1 Power BI Integration Dashboards
###### 10.1.1.1 Studify Admin Dashboards
![Studify Admin Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/01_Power%20BI%20Integration%20Dashboards/Screen%20Record/Studify%20Admin%20Dashboard.gif?raw=true)
- **Pages:**  
  - **Platform Overview:** Real-time metrics (active users, revenue, server health).  
  - **Geospatial Analysis:** Heatmaps of user logins and course demand.  
  - **Content Audit:** Flags courses with low ratings (<3.0) or high refunds.  
- **Features:**  
  - **Drillthrough:** Click a country → view top courses in that region.  
  - **Alerts:** SMS/email notifications for downtime or fraud detection.  

###### 10.1.1.2 Studify Instructor Dashboard 
![Studify Instructor Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/01_Power%20BI%20Integration%20Dashboards/Screen%20Record/Studify%20Instructor%20Dashboarrd.gif?raw=true)
- **Pages:**  
  - **Earnings Report:** Revenue by course, payment method, and student demographics.  
  - **Engagement Hub:** Avg. rating (4.3/5), Q&A response rate (82%), and completion trends.  
  - **Content Analytics:** Lesson popularity heatmaps and student feedback word clouds.  
- **Features:**  
  - **Benchmarking:** Compare performance against category averages.  
  - **Export:** Generate PDF reports for tax/ROI analysis.  

###### 10.1.1.3 Studify Student Dashboard  
![Studify Student Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/01_Power%20BI%20Integration%20Dashboards/Screen%20Record/Studify%20Student%20Dashboard.gif)
- **Pages:**  
  - **Learning Journey:** Progress timelines, course grades, and achievement badges.  
  - **Recommendations:** AI-curated courses based on enrollment history.  
  - **Social Learning:** Discussion forum activity and peer comparisons.  
- **Features:**  
  - **Calendar Sync:** Export deadlines to Google Calendar/Outlook.  
  - **Gamification:** Unlock badges for milestones (e.g., "10 Courses Completed").  

##### 10.1.2 Power BI Data Warehouse Dashboards  
###### 10.1.2.1 Studify-DWH Course Enrollment Dashboard
![Studify Enrollment Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/02_Power%20BI%20Data%20Warehouse%20Dashboards/Screen%20Records/Studify%20Enrollment%20Dashboards.gif)
- **Visualizations:**  
  - **YoY Growth:** Line charts showing 2024 enrollments (+38%).  
  - **Category Breakdown:** Treemaps (IT: 28%, Business: 22%).  
  - **Correlation Analysis:** Scatter plots (course duration vs. completion rate).  

###### 10.1.2.2 Studify-DWH Course Order Dashboard 
![Studify Course Order Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/02_Power%20BI%20Data%20Warehouse%20Dashboards/Screen%20Records/Studify%20Course%20order%20Dashboards%20.gif)
- **Visualizations:**  
  - **Sales Funnel:** Cart → Payment → Completion stages.  
  - **Revenue Maps:** Chloropleth maps highlighting top countries (USA: \$4.8M).  
  - **Discount Impact:** Pareto charts (top 20% discounts drive 80% sales).  

###### 10.1.2.3 Studify-DWH Data Mart Dashboard  
![Studify Data Mart Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/02_Power%20BI%20Data%20Warehouse%20Dashboards/Screen%20Records/Studify%20Cart%20Data%20Mart%20Dashboards.gif)
- **Visualizations:**  
  - **Cart Abandonment:** Heatmaps by time/day (peak: Sundays 8 PM).  
  - **Discount Depth vs. Conversion:** Trend lines (46% avg discount).  

###### 10.1.2.4 Studify-DWH Instructor Dashboard  
![Studify DWH Instructor Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/02_Power%20BI%20Data%20Warehouse%20Dashboards/Screen%20Records/Studify%20Instructor%20Dashboards.gif)
- **Visualizations:**  
  - **Leaderboards:** Top instructors by revenue (e.g., "Dr. Smith: \$120K").  
  - **Radar Charts:** Engagement metrics (ratings vs. response time).  

###### 10.1.2.5 Studify-DWH Student Dashboard
![Studify DWH Student Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/01_Power%20BI%20Dashboards/02_Power%20BI%20Data%20Warehouse%20Dashboards/Screen%20Records/Studify%20Student%20Dashboard.gif)
- **Visualizations:**  
  - **Progress Sankey:** Beginner → Advanced course pathways.  
  - **Grade Distributions:** Box plots per course (avg: 76/100).  

#### 10.2 Tableau Dashboards  
![Studify Tableau Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/02_Tableau%20Dashboards/Screen%20Record/Tablue%20Dashboard%20.gif)
- **Course Engagement Dashboard:**  
  - Sunburst charts for category → subcategory → course hierarchies.  
  - Real-time filters for age groups and regions.  
- **Revenue Forecasting Dashboard:**  
  - ARIMA models predicting next quarter’s revenue (±12% error).  
  - Scenario analysis for discount strategies.  

#### 10.3 Excel Dashboards
![Studify Excel Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/03_Excel%20Dashboards/Ph/Studify-Course%20Order%20Dashboard%20Excel.PNG)
- **Sales Tracker:**  
  - Pivot tables (revenue by category) + charts (monthly trends).  
  - Data bars highlighting top sellers (e.g., "Python Bootcamp: \$89K").  
- **Student Retention Report:**  
  - Conditional formatting for at-risk students (progress < 30%).  
  - VLOOKUP merging enrollment + course data.  

#### 10.4 Python Dashboards
![Studify Python Dashboard](https://github.com/Mohammed1999sstack/Studify_Graduation_Project/blob/main/10_Dashboards/04_Python%20Dashboards/Studify%20Python%20Dashboard.gif)
- **Streamlit Analytics App:**  
  - **Sentiment Analysis:** NLP-driven review scores (positive/negative).  
  - **Correlation Matrix:** Heatmaps (price vs. ratings vs. duration).  
  - **Predictive Models:** Linear regression forecasting enrollments.  
- **Deployment:** Azure Web Apps with auto-scaling (10k+ users).  

---

### 11. Future Enhancement  
1. **AI Integration:**  
   - **Chatbots:** Azure Bot Service for 24/7 student support.  
   - **Personalization:** Reinforcement learning for dynamic course recommendations.  
2. **Live Features:**  
   - **Virtual Labs:** Browser-based coding environments.  
   - **Live Polls/Q&A:** Real-time interaction during video lectures.  
3. **Advanced Analytics:**  
   - **Churn Prediction:** ML models identifying at-risk students.  
   - **Lifetime Value (LTV):** Predictive analytics for student spending.  
4. **Global Expansion:**  
   - **Multi-Language Support:** Arabic, Spanish, and Mandarin localization.  
   - **Regional Pricing:** Dynamic currency/pricing based on geolocation.  

---

### 12. Contributors  
- **Aya Mohamed Mahmoud (Team Leader)**  
- **Abdelrahman Elsayed Farouk**
- **Maha Fathy Ghoneim**
- **Mohammed Osama Alsamadoni** 
- **Omnia Saaed Abdelrahim**
