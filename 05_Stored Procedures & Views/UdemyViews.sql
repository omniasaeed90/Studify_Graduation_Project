-- UdemyDB DatabaseViews

-- 1. Course Details View

CREATE OR ALTER VIEW vw_CourseDetails AS
SELECT 
    c.Id, c.Title, c.Description, c.Price, c.Discount, c.CurrentPrice,
    c.Duration, c.Language, c.Rating, c.NoSubscribers, c.IsApproved,
    cat.Name AS Category, sub.Name AS SubCategory,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    i.TotalStudents AS InstructorStudents
FROM Courses c
JOIN Subcategories sub ON c.SubCategoryId = sub.Id
JOIN Categories cat ON sub.CategoryId = cat.Id
JOIN Instructors i ON c.InstructorId = i.Id
JOIN AspNetUsers u ON i.Id = u.Id
WHERE c.IsDeleted = 0;
GO

-- 2. Popular Courses View

CREATE OR ALTER VIEW vw_PopularCourses AS
SELECT TOP 50
    c.Id, c.Title, c.Price, c.CurrentPrice, c.Rating, c.NoSubscribers,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    DENSE_RANK() OVER (ORDER BY c.NoSubscribers DESC) AS PopularityRank
FROM Courses c
JOIN Instructors i ON c.InstructorId = i.Id
JOIN AspNetUsers u ON i.Id = u.Id
WHERE c.IsDeleted = 0 AND c.IsApproved = 1
ORDER BY c.NoSubscribers DESC;
GO

-- 3. Student Enrollment Summary

CREATE OR ALTER VIEW vw_StudentEnrollmentSummary AS
SELECT 
    s.Id, 
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    COUNT(e.CourseId) AS EnrolledCourses,
    SUM(CASE WHEN e.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedCourses,
    AVG(e.Rating) AS AverageRatingGiven
FROM Students s
JOIN AspNetUsers u ON s.Id = u.Id
LEFT JOIN Enrollments e ON s.Id = e.StudentId
GROUP BY s.Id, u.FirstName, u.LastName;
GO

-- 4. Instructor Performance View

CREATE OR ALTER VIEW vw_InstructorPerformance AS
SELECT 
    i.Id,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    COUNT(c.Id) AS TotalCourses,
    SUM(c.NoSubscribers) AS TotalStudents,
    AVG(c.Rating) AS AverageRating,
    i.Wallet AS Earnings
FROM Instructors i
JOIN AspNetUsers u ON i.Id = u.Id
LEFT JOIN Courses c ON i.Id = c.InstructorId
WHERE c.IsDeleted = 0
GROUP BY i.Id, u.FirstName, u.LastName, i.Wallet;
GO

-- 5. Course Revenue View

CREATE OR ALTER VIEW vw_CourseRevenue AS
SELECT 
    c.Id AS CourseId,
    c.Title,
    c.NoSubscribers,
    c.Price,
    c.CurrentPrice,
    (c.CurrentPrice * c.NoSubscribers) AS EstimatedRevenue,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName
FROM Courses c
JOIN Instructors i ON c.InstructorId = i.Id
JOIN AspNetUsers u ON i.Id = u.Id
WHERE c.IsDeleted = 0 AND c.IsApproved = 1;
GO

-- 6. Student Progress View

CREATE OR ALTER VIEW vw_StudentProgress AS
SELECT 
    e.StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    e.CourseId,
    c.Title AS CourseTitle,
    e.ProgressPercentage,
    e.Status,
    COUNT(p.Id) AS CompletedLessons,
    (SELECT COUNT(*) FROM Lessons l 
     JOIN Sections s ON l.SectionId = s.Id 
     WHERE s.CourseId = e.CourseId) AS TotalLessons
FROM Enrollments e
JOIN Students s ON e.StudentId = s.Id
JOIN AspNetUsers u ON s.Id = u.Id
JOIN Courses c ON e.CourseId = c.Id
LEFT JOIN Progresses p ON e.StudentId = p.StudentId 
    AND p.Status = 'Completed'
    AND p.LessonId IN (SELECT Id FROM Lessons WHERE SectionId IN 
        (SELECT Id FROM Sections WHERE CourseId = e.CourseId))
GROUP BY e.StudentId, u.FirstName, u.LastName, e.CourseId, c.Title, 
         e.ProgressPercentage, e.Status;
GO

-- 7. Course Content View

CREATE OR ALTER VIEW vw_CourseContent AS
SELECT 
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    s.Id AS SectionId,
    s.Title AS SectionTitle,
    l.Id AS LessonId,
    l.Title AS LessonTitle,
    l.Type AS LessonType,
    l.Duration AS LessonDuration
FROM Courses c
JOIN Sections s ON c.Id = s.CourseId
JOIN Lessons l ON s.Id = l.SectionId
WHERE c.IsDeleted = 0 AND s.IsDeleted = 0 AND l.IsDeleted = 0
GO

-- 8. Student Cart Contents

CREATE OR ALTER VIEW vw_StudentCartContents AS
SELECT 
    cart.Id AS CartId,
    s.Id AS StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    cc.CourseId,
    c.Title AS CourseTitle,
    c.CurrentPrice AS CoursePrice,
    cart.Amount AS TotalAmount
FROM Carts cart
JOIN Students s ON cart.StudentId = s.Id
JOIN AspNetUsers u ON s.Id = u.Id
JOIN CartCourse cc ON cart.Id = cc.CartId
JOIN Courses c ON cc.CourseId = c.Id
WHERE cart.IsDeleted = 0;
GO

-- 9. Course Requirements and Goals

CREATE OR ALTER VIEW vw_CourseRequirementsGoals AS
SELECT 
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    r.Requirement,
    g.Goal
FROM Courses c
LEFT JOIN CourseRequirements r ON c.Id = r.CourseId
LEFT JOIN CourseGoals g ON c.Id = g.CourseId
WHERE c.IsDeleted = 0
GO

-- 10. Student Grades View

CREATE OR ALTER VIEW vw_StudentGrades AS
SELECT 
    sg.StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    sg.QuizId,
    q.CourseId,
    c.Title AS CourseTitle,
    sg.Grade,
    CASE 
        WHEN sg.Grade >= 90 THEN 'A'
        WHEN sg.Grade >= 80 THEN 'B'
        WHEN sg.Grade >= 70 THEN 'C'
        WHEN sg.Grade >= 60 THEN 'D'
        ELSE 'F'
    END AS GradeLetter
FROM StudentGrades sg
JOIN Students s ON sg.StudentId = s.Id
JOIN AspNetUsers u ON s.Id = u.Id
JOIN Quizzes q ON sg.QuizId = q.Id
JOIN Courses c ON q.CourseId = c.Id
WHERE sg.IsDeleted = 0;
GO

-- 11. Category Subcategory Hierarchy

CREATE OR ALTER VIEW vw_CategoryHierarchy AS
SELECT 
    cat.Id AS CategoryId,
    cat.Name AS CategoryName,
    sub.Id AS SubcategoryId,
    sub.Name AS SubcategoryName,
    COUNT(c.Id) AS CourseCount
FROM Categories cat
JOIN Subcategories sub ON cat.Id = sub.CategoryId
LEFT JOIN Courses c ON sub.Id = c.SubCategoryId AND c.IsDeleted = 0
WHERE cat.IsDeleted = 0 AND sub.IsDeleted = 0
GROUP BY cat.Id, cat.Name, sub.Id, sub.Name;
GO

-- 12. Instructor Social Media

CREATE OR ALTER VIEW vw_InstructorSocialMedia AS
SELECT 
    i.Id AS InstructorId,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    sm.Name AS SocialMediaPlatform,
    sm.Link
FROM Instructors i
JOIN AspNetUsers u ON i.Id = u.Id
JOIN SocialMedias sm ON u.Id = sm.UserId
WHERE sm.IsDeleted = 0;
GO

-- 13. Course Reviews Summary

CREATE OR ALTER VIEW vw_CourseReviewsSummary AS
SELECT 
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    COUNT(e.comment) AS TotalReviews,
    AVG(e.Rating) AS AverageRating,
    SUM(CASE WHEN e.Rating between 4.50 and 5.00 THEN 1 ELSE 0 END) AS FiveStar,
    SUM(CASE WHEN e.Rating between 3.50 and 4.40 THEN 1 ELSE 0 END) AS FourStar,
    SUM(CASE WHEN e.Rating between 2.50 and 3.40 THEN 1 ELSE 0 END) AS ThreeStar,
    SUM(CASE WHEN e.Rating between 1.50 and 2.40 THEN 1 ELSE 0 END) AS TwoStar,
    SUM(CASE WHEN e.Rating between 0.50 and 1.40 THEN 1 ELSE 0 END) AS OneStar
FROM Courses c
LEFT JOIN Enrollments e ON c.Id = e.CourseId AND e.comment IS NOT NULL
WHERE c.IsDeleted = 0
GROUP BY c.Id, c.Title;
GO

-- 14. Student Learning Activity

CREATE OR ALTER  VIEW vw_StudentLearningActivity AS
SELECT 
    s.Id AS StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    COUNT(DISTINCT e.CourseId) AS ActiveCourses,
    SUM(CASE WHEN p.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedLessons,
    SUM(l.Duration) / 60 AS TotalLearningHours
FROM Students s
JOIN AspNetUsers u ON s.Id = u.Id
LEFT JOIN Enrollments e ON s.Id = e.StudentId AND e.Status = 'In Progress'
LEFT JOIN Progresses p ON s.Id = p.StudentId
LEFT JOIN Lessons l ON p.LessonId = l.Id
GROUP BY s.Id, u.FirstName, u.LastName;
GO

-- 15. Best Selling Courses

CREATE OR ALTER VIEW vw_BestSellingCourses AS
SELECT 
    c.Id AS CourseId,
    c.Title,
    c.NoSubscribers,
    c.Rating,
    c.CurrentPrice,
    cat.Name AS Category,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    RANK() OVER (ORDER BY c.NoSubscribers DESC) AS SalesRank
FROM Courses c
JOIN Subcategories sub ON c.SubCategoryId = sub.Id
JOIN Categories cat ON sub.CategoryId = cat.Id
JOIN Instructors i ON c.InstructorId = i.Id
JOIN AspNetUsers u ON i.Id = u.Id
WHERE c.IsDeleted = 0 AND c.IsApproved = 1
GO

-- 16. Course Completion Rates

CREATE OR ALTER VIEW vw_CourseCompletionRates AS
SELECT 
    c.Id AS CourseId,
    c.Title,
    COUNT(e.StudentId) AS TotalEnrollments,
    SUM(CASE WHEN e.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedEnrollments,
    CAST(SUM(CASE WHEN e.Status = 'Completed' THEN 1 ELSE 0 END) AS FLOAT) / 
        NULLIF(COUNT(e.StudentId), 0) * 100 AS CompletionRate
FROM Courses c
LEFT JOIN Enrollments e ON c.Id = e.CourseId
WHERE c.IsDeleted = 0
GROUP BY c.Id, c.Title;
GO

-- 17. Instructor Earnings by Course

CREATE OR ALTER VIEW vw_InstructorEarningsByCourse AS
SELECT 
    i.Id AS InstructorId,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    c.NoSubscribers,
    c.CurrentPrice,
    (c.CurrentPrice * c.NoSubscribers) * 0.7 AS InstructorEarnings -- Assuming 70% revenue share
FROM Instructors i
JOIN AspNetUsers u ON i.Id = u.Id
JOIN Courses c ON i.Id = c.InstructorId
WHERE c.IsDeleted = 0 AND c.IsApproved = 1
GO

-- 18. Student Purchase History

CREATE OR ALTER VIEW vw_StudentPurchaseHistory AS
SELECT 
    s.Id AS StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    o.Id AS OrderId,
    o.TotalAmount,
    o.PaymentMethod,
    o.CreatedDate AS PurchaseDate,
    STRING_AGG(c.Title, ', ') AS PurchasedCourses
FROM Students s
JOIN AspNetUsers u ON s.Id = u.Id
JOIN Orders o ON s.Id = o.StudentId
JOIN CourseOrder co ON o.Id = co.OrderId
JOIN Courses c ON co.CourseId = c.Id
WHERE o.IsDeleted = 0
GROUP BY s.Id, u.FirstName, u.LastName, o.Id, o.TotalAmount, o.PaymentMethod, o.CreatedDate;
GO

-- 19. Course Q&A Summary

CREATE OR ALTER VIEW vw_CourseQASummary AS
SELECT 
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    COUNT(a.Id) AS TotalQuestions,
    COUNT(ans.Id) AS TotalAnswers,
    COUNT(a.Id) - COUNT(ans.Id) AS UnansweredQuestions,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName
FROM Courses c
LEFT JOIN Asks a ON c.Id = a.CourseId AND a.IsDeleted = 0
LEFT JOIN Answers ans ON a.Id = ans.AskId AND ans.IsDeleted = 0
JOIN Instructors i ON c.InstructorId = i.Id
JOIN AspNetUsers u ON i.Id = u.Id
WHERE c.IsDeleted = 0
GROUP BY c.Id, c.Title, u.FirstName, u.LastName;
GO

-- 20. Student Achievement Progress

CREATE OR ALTER VIEW vw_StudentAchievementProgress AS
SELECT 
    s.Id AS StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    COUNT(DISTINCT e.CourseId) AS TotalCoursesEnrolled,
    SUM(CASE WHEN e.Status = 'Completed' THEN 1 ELSE 0 END) AS CoursesCompleted,
    AVG(e.Rating) AS AverageCourseRating,
    COUNT(DISTINCT sg.QuizId) AS QuizzesTaken,
    AVG(sg.Grade) AS AverageQuizScore
FROM Students s
JOIN AspNetUsers u ON s.Id = u.Id
LEFT JOIN Enrollments e ON s.Id = e.StudentId
LEFT JOIN StudentGrades sg ON s.Id = sg.StudentId
GROUP BY s.Id, u.FirstName, u.LastName;
GO

-- 21. Course Duration Analysis

CREATE OR ALTER VIEW vw_CourseDurationAnalysis AS
SELECT 
    c.Id AS CourseId,
    c.Title,
    c.Duration AS TotalHours,
    (SELECT SUM(Duration) FROM Sections WHERE CourseId = c.Id) AS VideoHours,
    (SELECT COUNT(*) FROM Lessons WHERE SectionId IN 
        (SELECT Id FROM Sections WHERE CourseId = c.Id) AND Type = 'Article') AS ArticleCount,
    (SELECT COUNT(*) FROM Quizzes WHERE CourseId = c.Id) AS QuizCount
FROM Courses c
WHERE c.IsDeleted = 0;
GO

-- 22. Instructor Response Time

CREATE OR ALTER VIEW vw_InstructorResponseTime AS
SELECT 
    i.Id AS InstructorId,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    AVG(DATEDIFF(HOUR, a.CreatedDate, ans.CreatedDate)) AS AvgResponseTimeHours,
    COUNT(DISTINCT a.Id) AS QuestionsAnswered,
    COUNT(DISTINCT a.Id) * 100.0 / 
        (SELECT COUNT(*) FROM Asks WHERE CourseId IN 
            (SELECT Id FROM Courses WHERE InstructorId = i.Id)) AS AnswerRatePercentage
FROM Instructors i
JOIN AspNetUsers u ON i.Id = u.Id
JOIN Courses c ON i.Id = c.InstructorId
JOIN Asks a ON c.Id = a.CourseId
JOIN Answers ans ON a.Id = ans.AskId AND ans.UserId = i.Id
GROUP BY i.Id, u.FirstName, u.LastName;
GO

-- 23. Course Discount Analysis

CREATE OR ALTER VIEW vw_CourseDiscountAnalysis AS
SELECT 
    c.Id AS CourseId,
    c.Title,
    c.Price,
    c.Discount,
    c.CurrentPrice,
    c.NoSubscribers,
    CASE 
        WHEN c.Discount > 0 THEN 'Discounted'
        ELSE 'Full Price'
    END AS PricingStatus,
    (c.CurrentPrice * c.NoSubscribers) AS EstimatedRevenue
FROM Courses c
WHERE c.IsDeleted = 0 AND c.IsApproved = 1
GO

-- 24. Student Learning Path

CREATE OR ALTER VIEW vw_StudentLearningPath AS
SELECT 
    s.Id AS StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    cat.Name AS Category,
    e.StartDate,
    e.CompletionDate,
    e.ProgressPercentage,
    e.Status
FROM Students s
JOIN AspNetUsers u ON s.Id = u.Id
JOIN Enrollments e ON s.Id = e.StudentId
JOIN Courses c ON e.CourseId = c.Id
JOIN Subcategories sub ON c.SubCategoryId = sub.Id
JOIN Categories cat ON sub.CategoryId = cat.Id
WHERE e.IsDeleted = 0
GO

-- 25. Course Content Duration

CREATE OR ALTER VIEW vw_CourseContentDuration AS
SELECT 
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    s.Id AS SectionId,
    s.Title AS SectionTitle,
    s.Duration AS SectionDuration,
    (SELECT SUM(Duration) FROM Lessons WHERE SectionId = s.Id) AS LessonsTotalDuration,
    (SELECT COUNT(*) FROM Lessons WHERE SectionId = s.Id) AS LessonCount
FROM Courses c
JOIN Sections s ON c.Id = s.CourseId
WHERE c.IsDeleted = 0 AND s.IsDeleted = 0
GO

-- 26. Student Quiz Performance

CREATE OR ALTER VIEW vw_StudentQuizPerformance AS
SELECT 
    s.Id AS StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    q.CourseId,
    c.Title AS CourseTitle,
    sg.QuizId,
    sg.Grade,
    CASE 
        WHEN sg.Grade >= (SELECT AVG(Grade) FROM StudentGrades WHERE QuizId = sg.QuizId) 
        THEN 'Above Average'
        ELSE 'Below Average'
    END AS Performance
FROM Students s
JOIN AspNetUsers u ON s.Id = u.Id
JOIN StudentGrades sg ON s.Id = sg.StudentId
JOIN Quizzes q ON sg.QuizId = q.Id
JOIN Courses c ON q.CourseId = c.Id
WHERE sg.IsDeleted = 0;
GO

-- 27. Course Popularity by Category

CREATE OR ALTER VIEW vw_CoursePopularityByCategory AS
SELECT 
    cat.Id AS CategoryId,
    cat.Name AS CategoryName,
    sub.Id AS SubcategoryId,
    sub.Name AS SubcategoryName,
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    c.NoSubscribers,
    c.Rating,
    RANK() OVER (PARTITION BY cat.Id ORDER BY c.NoSubscribers DESC) AS CategoryRank
FROM Categories cat
JOIN Subcategories sub ON cat.Id = sub.CategoryId
JOIN Courses c ON sub.Id = c.SubCategoryId
WHERE c.IsDeleted = 0 AND c.IsApproved = 1
GO

-- 28. Instructor Course Portfolio

CREATE OR ALTER VIEW vw_InstructorCoursePortfolio AS
SELECT 
    i.Id AS InstructorId,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName,
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    c.NoSubscribers,
    c.Rating,
    c.CreatedDate AS CourseCreatedDate,
    c.CurrentPrice,
    (c.CurrentPrice * c.NoSubscribers) * 0.7 AS EstimatedEarnings -- Assuming 70% revenue share
FROM Instructors i
JOIN AspNetUsers u ON i.Id = u.Id
JOIN Courses c ON i.Id = c.InstructorId
WHERE c.IsDeleted = 0
GO

-- 29. Student Learning Preferences

CREATE OR ALTER VIEW vw_StudentLearningPreferences AS
SELECT 
    s.Id AS StudentId,
    CONCAT(u.FirstName, ' ', u.LastName) AS StudentName,
    cat.Name AS FavoriteCategory,
    COUNT(e.CourseId) AS CoursesInCategory,
    AVG(e.Rating) AS AverageRatingInCategory
FROM Students s
JOIN AspNetUsers u ON s.Id = u.Id
JOIN Enrollments e ON s.Id = e.StudentId
JOIN Courses c ON e.CourseId = c.Id
JOIN Subcategories sub ON c.SubCategoryId = sub.Id
JOIN Categories cat ON sub.CategoryId = cat.Id
WHERE e.IsDeleted = 0
GROUP BY s.Id, u.FirstName, u.LastName, cat.Name
HAVING COUNT(e.CourseId) > 0;
GO

-- 30. Course Update History

CREATE OR ALTER VIEW vw_CourseUpdateHistory AS
SELECT 
    c.Id AS CourseId,
    c.Title AS CourseTitle,
    c.CreatedDate,
    c.ModifiedDate,
    DATEDIFF(DAY, c.CreatedDate, COALESCE(c.ModifiedDate, GETDATE())) AS DaysSinceLastUpdate,
    CONCAT(u.FirstName, ' ', u.LastName) AS InstructorName
FROM Courses c
JOIN Instructors i ON c.InstructorId = i.Id
JOIN AspNetUsers u ON i.Id = u.Id
WHERE c.IsDeleted = 0;
go

-- 31. Fact Enrollment View

CREATE OR ALTER VIEW vw_FactEnrollment AS
SELECT
    e.StudentId, 
    e.CourseId, 
    CAST(FORMAT(e.StartDate, 'yyyyMMdd') AS INT) AS StartDateKey,
    CAST(FORMAT(e.CompletionDate, 'yyyyMMdd') AS INT) AS CompletionDateKey,
    e.Status,
    e.Rating, 
    e.comment, 
    e.CertificationUrl, 
    e.ProgressPercentage,
    Grades.Grade, 
    CAST(FORMAT(Grades.GradeDate, 'yyyyMMdd') AS INT) AS GradeDateKey
FROM Enrollments e 
LEFT JOIN (
    SELECT 
        sg.StudentId, 
        q.CourseId, 
        sg.Grade, 
        sg.CreatedDate AS GradeDate
    FROM StudentGrades sg 
    LEFT JOIN Quizzes q ON q.Id = sg.QuizId
) AS Grades ON e.StudentId = Grades.StudentId AND e.CourseId = Grades.CourseId;
GO

-- 32. Fact Order View

CREATE OR ALTER VIEW vw_FactOrder AS
SELECT
    co.*,o.StudentId, 
    o.PaymentMethod, 
    o.Status, 
    o.TotalAmount,
    o.Discount, 
    CAST(FORMAT(o.CreatedDate, 'yyyyMMdd') AS INT) AS OrderDateKey, 
    CAST(FORMAT(o.ModifiedDate , 'yyyyMMdd') AS INT) AS ModifiedDateKey 
FROM Orders o 
LEFT JOIN CourseOrder co ON o.Id = co.OrderId;
GO

-- 33. Fact Cart View
CREATE OR ALTER VIEW vw_FactCart AS
SELECT 
    cc.CartId, 
    c.StudentId, 
    cc.CourseId, 
    c.Amount,
    CAST(FORMAT(c.CreatedDate, 'yyyyMMdd') AS INT) AS CartDateKey
FROM CartCourse cc 
JOIN Carts c ON cc.CartId = c.Id;
GO
------------------------------------------------------------------------------
-- 34. Dimension Courses View
CREATE OR ALTER view [dbo].[VDimcourse] as
SELECT 
  c.Id,Title,[Description],[Status],CourseLevel
  ,Discount,Price as OriginalPrice,CurrentPrice,
    Duration,NoSubscribers,Rating,
    IsFree,IsApproved,[Language],
    BestSeller,ct.[Name] as Category , sct.[Name] as SubCategory , c.InstructorId
FROM [dbo].[Courses] c join Subcategories sct on sct.Id = c.SubCategoryId
join Categories ct on ct.Id = sct.CategoryId ;
GO
------------------------------------------------------------------------------
-- 35. Dimension Users View
CREATE OR ALTER VIEW [dbo].[VDimUser] AS
SELECT 
    u.[Id], [FirstName], [LastName],
    [CountryName], [City], [State],
    [Age], [Gender],
    [Email], HasFacebook, HasLinkedin, HasX, HasInstegram,
    Title, Bio, Wallet,
    IsStudent, IsInstructor, IsAdmin
FROM [dbo].[AspNetUsers] u
JOIN [dbo].[HasSocialMedia] hs ON hs.Id = u.Id
JOIN [dbo].[StudentInstructor] si ON si.Id = u.Id
JOIN [dbo].[IsRole] ir ON u.Id = ir.UserId;
GO
------------------------------------------------------------------------------
--36.  Sup Dimension Quiz view
CREATE OR ALTER VIEW [dbo].[VSupDimQuiz] AS
SELECT 
    Q.CourseId,
    QQ.QuizId,
    SUM(CASE WHEN QQ.Type = 'Multiple Choice' THEN 1 ELSE 0 END) AS MultipleChoiceCount,
    SUM(CASE WHEN QQ.Type = 'True or False' THEN 1 ELSE 0 END) AS TrueOrFalseCount
FROM 
    dbo.Quizzes Q
JOIN 
    dbo.QuizQuestions QQ ON Q.Id = QQ.QuizId
GROUP BY 
    Q.CourseId, QQ.QuizId;
GO
------------------------------------------------------------------------------
--37. Sup Dimention Section view
CREATE OR ALTER VIEW [dbo].[VSupDimSection] AS
SELECT 
	[Id] as SectionId,l.[CourseId],[Title],
	[Duration],[NoLessons],VideoCount,ArticleCount
FROM [dbo].[Sections] s join LessonTypeCount l on s.Id =l.SectionId
GO
------------------------------------------------------------------------------