/* 
CartDM Data Mart Schema
Star Schema Design for Udemy-like Platform Cart Analysis
*/

-- =============================================
-- 1. Dimension Tables
-- =============================================

-- Core Student Dimension (Type 2 SCD)
CREATE TABLE [dbo].[DimStudents](
    [StudentId_SK] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [StudentId_BK] [int] NOT NULL,          -- Business Key from Source
    [FirstName] [nvarchar](50) NOT NULL,
    [LastName] [nvarchar](50) NOT NULL,
    [Demographics] [nvarchar](50) NOT NULL, -- Country/City/State
    [Age] [int] NOT NULL,
    [Gender] [nvarchar](1) NOT NULL,
    [ContactInfo] [nvarchar](256) NULL,     -- Email/Phone
    [SocialPresence] [bit] NOT NULL,        -- Facebook/Instagram/LinkedIn/X flags
    [ProfileInfo] [nvarchar](max) NULL,     -- Title/Bio
    [Wallet] [decimal](18, 2) NULL,
    [SCD Dates] [datetime] NOT NULL,        -- StartDate/EndDate
    [IsDeleted] [bit] NOT NULL DEFAULT 0
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];

-- Date Dimension (Standard Pattern)
CREATE TABLE [dbo].[DimDate](
    [Date_id_sk] [int] NOT NULL PRIMARY KEY,
    [Date] [datetime] NOT NULL,
    [Day] [char](2) NOT NULL,
    [DaySuffix] [varchar](4) NOT NULL,
    [DayOfWeek] [varchar](9) NOT NULL,
    [DOWInMonth] [tinyint] NOT NULL,
    [DayOfYear] [int] NOT NULL,
    [WeekOfYear] [tinyint] NOT NULL,
    [WeekOfMonth] [tinyint] NOT NULL,
    [Month] [char](2) NOT NULL,
    [MonthName] [varchar](9) NOT NULL,
    [Quarter] [tinyint] NOT NULL,
    [QuarterName] [varchar](6) NOT NULL,
    [Year] [char](4) NOT NULL,
    [HolidayText] [varchar](50) NULL
) ON [PRIMARY];

-- Course Dimension (Type 1 SCD)
CREATE TABLE [dbo].[DimCourses](
    [CourseId_SK] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [CourseId_BK] [int] NOT NULL,            -- Source System ID
    [Title] [nvarchar](255) NULL,
    [Description] [nvarchar](max) NOT NULL,
    [Pricing] [decimal](8, 2) NOT NULL,      -- Original/Current Price
    [Duration] [decimal](8, 2) NOT NULL,
    [Language] [nvarchar](20) NOT NULL,
    [Popularity] [int] NOT NULL,             -- NoSubscribers
    [ApprovalStatus] [bit] NOT NULL,         -- IsApproved
    [CategoryInfo] [nvarchar](255) NOT NULL, -- Category/SubCategory
    [SCD Dates] [datetime] NOT NULL,         -- StartDate/EndDate
    [IsDeleted] [bit] NOT NULL DEFAULT 0
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];

-- =============================================
-- 2. Fact Tables
-- =============================================

-- Cart Activity Fact (Granularity: Cart-Course)
CREATE TABLE [dbo].[FactCarts](
    [CartId_SK] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [CartId_BK] [int] NOT NULL,              -- Source Cart ID
    [StudentId_SK] [int] NOT NULL,
    [CourseId_SK] [int] NOT NULL,
    [DateKey] [int] NOT NULL,                -- DimDate FK
    [Amount] [int] NULL,
    CONSTRAINT [FK_Student] FOREIGN KEY ([StudentId_SK]) REFERENCES DimStudents,
    CONSTRAINT [FK_Course] FOREIGN KEY ([CourseId_SK]) REFERENCES DimCourses,
    CONSTRAINT [FK_Date] FOREIGN KEY ([DateKey]) REFERENCES DimDate
) ON [PRIMARY];

-- =============================================
-- 3. Supporting Dimensions (Conformed)
-- =============================================

-- Quiz Structure Dimension
CREATE TABLE [dbo].[SDimQuiz](
    [QuizId_SK] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [CourseId_SK] [int] NOT NULL,
    [QuestionTypes] [int] NULL,              -- MC/TrueFalse counts
    [SCD Dates] [datetime] NOT NULL,
    CONSTRAINT [FK_QuizCourse] FOREIGN KEY ([CourseId_SK]) REFERENCES DimCourses
) ON [PRIMARY];

-- Course Requirements Dimension
CREATE TABLE [dbo].[SubDimCrsReq](
    [ReqId_SK] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [CourseId_SK] [int] NOT NULL,
    [Requirement] [nvarchar](255) NOT NULL,
    [SCD Dates] [datetime] NOT NULL,
    CONSTRAINT [FK_ReqCourse] FOREIGN KEY ([CourseId_SK]) REFERENCES DimCourses
) ON [PRIMARY];

-- Section Content Dimension
CREATE TABLE [dbo].[SubDimSection](
    [SectionId_SK] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [CourseId_SK] [int] NOT NULL,
    [ContentMetrics] [int] NOT NULL,         -- Duration/Lesson counts
    [MediaTypes] [int] NULL,                 -- Video/Article counts
    [SCD Dates] [datetime] NOT NULL,
    CONSTRAINT [FK_SectionCourse] FOREIGN KEY ([CourseId_SK]) REFERENCES DimCourses
) ON [PRIMARY];