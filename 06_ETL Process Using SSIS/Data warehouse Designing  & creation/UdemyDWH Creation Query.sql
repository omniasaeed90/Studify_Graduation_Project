-- Database Creation
CREATE DATABASE UdemyDwH;
GO

USE UdemyDwH;
GO

/****** Dimension Tables ******/

-- DimDate
CREATE TABLE dbo.DimDate (
    Date_id_sk        INT          NOT NULL,
    [Date]            DATETIME     NOT NULL,
    [Day]             CHAR(2)      NOT NULL,
    DaySuffix         VARCHAR(4)   NOT NULL,
    DayOfWeek         VARCHAR(9)   NOT NULL,
    DOWInMonth        TINYINT      NOT NULL,
    DayOfYear         INT          NOT NULL,
    WeekOfYear        TINYINT      NOT NULL,
    WeekOfMonth       TINYINT      NOT NULL,
    [Month]           CHAR(2)      NOT NULL,
    MonthName         VARCHAR(9)   NOT NULL,
    Quarter           TINYINT      NOT NULL,
    QuarterName       VARCHAR(6)   NOT NULL,
    [Year]            CHAR(4)      NOT NULL,
    StandardDate      VARCHAR(10)  NULL,
    HolidayText       VARCHAR(50)  NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (Date_id_sk)
);
GO

-- DimUsers
CREATE TABLE dbo.DimUsers (
    UserId_SK       INT           IDENTITY(1,1) NOT NULL,
    UserId_BK       INT           NOT NULL,
    FirstName       NVARCHAR(50)  NOT NULL,
    LastName        NVARCHAR(50)  NOT NULL,
    CountryName     NVARCHAR(50)  NOT NULL,
    City            NVARCHAR(50)  NOT NULL,
    [State]         NVARCHAR(50)  NOT NULL,
    Age             INT           NOT NULL,
    Gender          NVARCHAR(1)   NOT NULL,
    Email           NVARCHAR(256) NULL,
    PhoneNumber     NVARCHAR(100) NULL,
    HasFacebook     BIT           NOT NULL,
    HasInstagram    BIT           NOT NULL,
    HasLinkedIn     BIT           NOT NULL,
    HasX            BIT           NOT NULL,
    IsStudent       BIT           NOT NULL,
    IsInstructor    BIT           NOT NULL,
    Title           NVARCHAR(255) NULL,
    Bio             NVARCHAR(MAX) NULL,
    Wallet          DECIMAL(18,2) NULL,
    IsAdmin         BIT           NOT NULL,
    StartDate       DATETIME      NOT NULL DEFAULT GETDATE(),
    EndDate         DATETIME      NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_DimUsers PRIMARY KEY CLUSTERED (UserId_SK)
);
GO

-- DimCourses
CREATE TABLE dbo.DimCourses (
    CourseId_SK     INT            IDENTITY(1,1) NOT NULL,
    CourseId_BK     INT            NOT NULL,
    Title           NVARCHAR(255)  NULL,
    Description     NVARCHAR(MAX)  NOT NULL,
    Status          NVARCHAR(100)  NOT NULL,
    CourseLevel     NVARCHAR(MAX)  NOT NULL,
    OriginalPrice   DECIMAL(8,2)   NOT NULL,
    CurrentPrice    DECIMAL(8,2)   NOT NULL,
    Discount        DECIMAL(8,2)   NULL,
    Duration        DECIMAL(8,2)   NOT NULL,
    Language        NVARCHAR(20)   NOT NULL,
    NoSubscribers   INT            NOT NULL,
    IsFree          BIT            NOT NULL,
    IsApproved      BIT            NOT NULL,
    Rating          DECIMAL(2,1)   NULL,
    SubCategory     NVARCHAR(255)  NOT NULL,
    Category        NVARCHAR(255)  NOT NULL,
    BestSeller      NVARCHAR(20)   NULL,
    InstructorId    INT            NULL,
    StartDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    EndDate         DATETIME       NULL,
    IsDeleted       BIT            NOT NULL DEFAULT 0,
    CONSTRAINT PK_DimCourses PRIMARY KEY CLUSTERED (CourseId_SK)
);
GO

ALTER TABLE dbo.DimCourses
ADD CONSTRAINT FK_DimCourses_DimUsers
FOREIGN KEY (InstructorId) REFERENCES dbo.DimUsers(UserId_SK);
GO

/****** Sub-Dimension Tables ******/

-- SubDimCrsReq
CREATE TABLE dbo.SubDimCrsReq (
    ReqId_SK        INT            IDENTITY(1,1) NOT NULL,
    CourseId_SK     INT            NOT NULL,
    Requirement     NVARCHAR(255)  NOT NULL,
    StartDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    EndDate         DATETIME       NULL,
    IsDeleted       BIT            NOT NULL DEFAULT 0,
    CONSTRAINT PK_SubDimCrsReq PRIMARY KEY CLUSTERED (ReqId_SK)
);
GO

ALTER TABLE dbo.SubDimCrsReq
ADD CONSTRAINT FK_SubDimCrsReq_DimCourses
FOREIGN KEY (CourseId_SK) REFERENCES dbo.DimCourses(CourseId_SK);
GO

-- SubDimSection
CREATE TABLE dbo.SubDimSection (
    SectionId_SK    INT            IDENTITY(1,1) NOT NULL,
    SectionId       INT            NOT NULL,
    CourseId_SK     INT            NOT NULL,
    Title           NVARCHAR(255)  NULL,
    Duration        INT            NOT NULL,
    NoLessons       INT            NOT NULL,
    NoVideo         INT            NULL,
    NoArticle       INT            NULL,
    StartDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    EndDate         DATETIME       NULL,
    IsDeleted       BIT            NOT NULL DEFAULT 0,
    CONSTRAINT PK_SubDimSection PRIMARY KEY CLUSTERED (SectionId_SK)
);
GO

ALTER TABLE dbo.SubDimSection
ADD CONSTRAINT FK_SubDimSection_DimCourses
FOREIGN KEY (CourseId_SK) REFERENCES dbo.DimCourses(CourseId_SK);
GO

-- SDimQuiz
CREATE TABLE dbo.SDimQuiz (
    QuizId_SK           INT           IDENTITY(1,1) NOT NULL,
    QuizId              INT           NOT NULL,
    CourseId_SK         INT           NOT NULL,
    MultipleChoiceCount INT           NULL,
    TrueOrFalseCount    INT           NULL,
    StartDate           DATETIME      NOT NULL DEFAULT GETDATE(),
    EndDate             DATETIME      NULL,
    IsDeleted           BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_SDimQuiz PRIMARY KEY CLUSTERED (QuizId_SK)
);
GO

ALTER TABLE dbo.SDimQuiz
ADD CONSTRAINT FK_SDimQuiz_DimCourses
FOREIGN KEY (CourseId_SK) REFERENCES dbo.DimCourses(CourseId_SK);
GO

/****** Fact Tables ******/

-- FactEnrollment
CREATE TABLE dbo.FactEnrollment (
    Sk_Enroll_ID        INT            IDENTITY(1,1) NOT NULL,
    UserId_SK           INT            NOT NULL,
    CourseId_SK         INT            NOT NULL,
    StartDateKey        INT            NULL,
    CompletionDateKey   INT            NULL,
    [Status]            NVARCHAR(MAX)  NOT NULL,
    Rating              DECIMAL(8,2)   NULL,
    ProgressPercentage  DECIMAL(8,2)  NULL,
    Grade               DECIMAL(8,2)  NULL,
    CONSTRAINT PK_FactEnrollment PRIMARY KEY CLUSTERED (Sk_Enroll_ID)
);
GO

ALTER TABLE dbo.FactEnrollment
ADD CONSTRAINT FK_FactEnrollment_DimUsers
FOREIGN KEY (UserId_SK) REFERENCES dbo.DimUsers(UserId_SK);

ALTER TABLE dbo.FactEnrollment
ADD CONSTRAINT FK_FactEnrollment_DimCourses
FOREIGN KEY (CourseId_SK) REFERENCES dbo.DimCourses(CourseId_SK);

ALTER TABLE dbo.FactEnrollment 
ADD CONSTRAINT FK_FactEnrollment_DimDate_Start
FOREIGN KEY (StartDateKey) REFERENCES dbo.DimDate(Date_id_sk);

ALTER TABLE dbo.FactEnrollment 
ADD CONSTRAINT FK_FactEnrollment_DimDate_Completion
FOREIGN KEY (CompletionDateKey) REFERENCES dbo.DimDate(Date_id_sk);
GO

-- FactOrder
CREATE TABLE dbo.FactOrder (
    OrderId_SK       INT            IDENTITY(1,1) NOT NULL,
    OrderId_bk       INT            NOT NULL,
    UserId_SK        INT            NOT NULL,
    CourseId_SK      INT            NOT NULL,
    PaymentMethod    NVARCHAR(MAX)  NOT NULL,
    [Status]         NVARCHAR(MAX)  NOT NULL,
    TotalAmount      INT            NOT NULL,
    OrderPrice       DECIMAL(8,2)   NOT NULL,
    Discount         DECIMAL(8,2)   NULL,
    OrderDateKey     INT            NOT NULL,
    CONSTRAINT PK_FactOrder PRIMARY KEY CLUSTERED (OrderId_SK)
);
GO

ALTER TABLE dbo.FactOrder
ADD CONSTRAINT FK_FactOrder_DimUsers
FOREIGN KEY (UserId_SK) REFERENCES dbo.DimUsers(UserId_SK);

ALTER TABLE dbo.FactOrder
ADD CONSTRAINT FK_FactOrder_DimCourses
FOREIGN KEY (CourseId_SK) REFERENCES dbo.DimCourses(CourseId_SK);

ALTER TABLE dbo.FactOrder
ADD CONSTRAINT FK_FactOrder_DimDate
FOREIGN KEY (OrderDateKey) REFERENCES dbo.DimDate(Date_id_sk);
GO