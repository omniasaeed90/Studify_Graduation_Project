--Stored Procedures for UdemyDB
--User Management Procedures
-- 1. Create a new user
CREATE OR ALTER PROCEDURE sp_CreateUser @FirstName NVARCHAR(50),@LastName NVARCHAR(50),
   @Email NVARCHAR(256),@PasswordHash NVARCHAR(MAX),
   @UserName NVARCHAR(256), @CountryName NVARCHAR(100),@Age INT,
   @Gender NVARCHAR(1),@IsAdmin BIT = 0,@IsInstructor BIT = 0,@IsStudent BIT = 1 
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate at least one role is selected
        IF @IsAdmin = 0 AND @IsInstructor = 0 AND @IsStudent = 0
        BEGIN RAISERROR('User must have at least one role (Admin, Instructor, or Student)', 16, 1);
        RETURN;END
        BEGIN TRANSACTION;
        DECLARE @NewUserId INT;        
        -- Insert into AspNetUsers
        INSERT INTO AspNetUsers (FirstName, LastName, Email, PasswordHash, UserName,EmailConfirmed, 
            PhoneNumberConfirmed, TwoFactorEnabled,LockoutEnabled, AccessFailedCount, CreatedDate,  
            CountryName, City, State, Age, Gender, IsDeleted)
        VALUES (@FirstName, @LastName, @Email, @PasswordHash, @UserName,1, 0, 0, 0, 0, GETDATE(), 
            @CountryName, 'Unknown', 'Unknown', @Age, @Gender, 0);
        SET @NewUserId = SCOPE_IDENTITY();
        -- Assign roles
        IF @IsAdmin = 1 INSERT INTO AspNetUserRoles (UserId, RoleId) VALUES (@NewUserId, 1);
        IF @IsInstructor = 1   
        BEGIN INSERT INTO AspNetUserRoles (UserId, RoleId) VALUES (@NewUserId, 2);
            INSERT INTO Instructors (Id, Title, Bio, TotalCourses, TotalReviews, TotalStudents, Wallet)
            VALUES (@NewUserId, 'New Instructor', 'Bio not specified', 0, 0, 0, 0); END  
        IF @IsStudent = 1 BEGIN
            INSERT INTO AspNetUserRoles (UserId, RoleId) VALUES (@NewUserId, 3);
            INSERT INTO Students (Id, Title, Bio, Wallet)VALUES (@NewUserId,
            'New Student', 'Bio not specified', 0);
            -- Create empty cart for student
        INSERT INTO Carts (StudentId, Amount, CreatedDate, IsDeleted)VALUES (@NewUserId, 0, GETDATE(), 0);
        END
        COMMIT TRANSACTION;       
        SELECT @NewUserId AS NewUserId, 1 AS Success, 'User created successfully' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;  
        SELECT 0 AS Success,'Error creating user: ' + ERROR_MESSAGE() AS Message,NULL AS NewUserId;    
    END CATCH
END GO
-----------------------------------------------------------------------------------------
-- 2. Update user profile
CREATE OR ALTER PROCEDURE sp_UpdateUserProfile @UserId INT,
    @FirstName NVARCHAR(50),@LastName NVARCHAR(50),@CountryName NVARCHAR(50),    
    @City NVARCHAR(50),@State NVARCHAR(50), @Age INT,@Gender NVARCHAR(1)
AS BEGIN
    UPDATE AspNetUsers
           SET FirstName = @FirstName, LastName = @LastName,
               CountryName = @CountryName, City = @City,
               State = @State, Age = @Age,
               Gender = @Gender, ModifiedDate = GETDATE()
        WHERE Id = @UserId    
END GO
-----------------------------------------------------------------------------------------
-- 3. Soft Delete user 
CREATE OR ALTER PROCEDURE sp_SoftDeleteUser @Id INT
AS
BEGIN
    UPDATE AspNetUsers
    SET IsDeleted = 1,
        ModifiedDate = GETDATE()
    WHERE Id = @Id
END
GO
-----------------------------------------------------------------------------------------
-- 4. Soft Delete user and all Data

CREATE OR ALTER PROCEDURE sp_DeleteUserAndAllData  @UserId INT,@HardDelete BIT = 0  
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate user exists
        IF NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE Id = @UserId)
        BEGIN SELECT 0 AS Success, 'User not found' AS Message;RETURN; END 
        BEGIN TRANSACTION;
        
        IF @HardDelete = 1 BEGIN
            -- HARD DELETE -----------------------------------------------------            
            -- 1. Delete user content
            DELETE FROM Answers WHERE UserId = @UserId;
            DELETE FROM Asks WHERE UserId = @UserId;
            DELETE FROM SocialMedias WHERE UserId = @UserId; 
            -- 2. If instructor - delete instructor data
            DELETE FROM CourseGoals WHERE CourseId IN (SELECT Id FROM Courses WHERE InstructorId = @UserId);
            DELETE FROM CourseRequirements WHERE CourseId IN (SELECT Id FROM Courses WHERE InstructorId = @UserId);
            DELETE FROM Sections WHERE CourseId IN (SELECT Id FROM Courses WHERE InstructorId = @UserId);
            DELETE FROM Quizzes WHERE CourseId IN (SELECT Id FROM Courses WHERE InstructorId = @UserId);
            DELETE FROM Courses WHERE InstructorId = @UserId;
            DELETE FROM Instructors WHERE Id = @UserId;            
            -- 3. If student - delete student data
            DELETE FROM Progresses WHERE StudentId = @UserId;
            DELETE FROM Enrollments WHERE StudentId = @UserId;
            DELETE FROM StudentGrades WHERE StudentId = @UserId;
            DELETE FROM CartCourse WHERE CartId IN (SELECT Id FROM Carts WHERE StudentId = @UserId);
            DELETE FROM Carts WHERE StudentId = @UserId;
            DELETE FROM Orders WHERE StudentId = @UserId;
            DELETE FROM Students WHERE Id = @UserId;           
            -- Finally delete the user
            DELETE FROM AspNetUsers WHERE Id = @UserId;            
            SELECT 1 AS Success, 'User and all related data permanently deleted' AS Message; END
        ELSE BEGIN
            -- SOFT DELETE -----------------------------------------------------    
            -- 1. Soft delete user
            UPDATE AspNetUsers SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE Id = @UserId;  
            -- 2. Soft delete user content
            UPDATE Answers SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE UserId = @UserId;
            UPDATE Asks SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE UserId = @UserId;
            UPDATE SocialMedias SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE UserId = @UserId;
            -- 3. If instructor - mark as deleted (no IsDeleted field, so we'll use a status field if exists)
            UPDATE Courses SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE InstructorId = @UserId;   
            -- 4. If student - mark as deleted (no IsDeleted field, so we'll skip this)
            UPDATE Enrollments SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE StudentId = @UserId;
            UPDATE Orders SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE StudentId = @UserId;
            UPDATE Progresses SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE StudentId = @UserId;
            UPDATE StudentGrades SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE StudentId = @UserId;
            UPDATE Carts SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE StudentId = @UserId;  
            SELECT 1 AS Success, 'User and related data marked as deleted' AS Message;END             
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;               
        SELECT 0 AS Success,'Error deleting user: ' + ERROR_MESSAGE() AS Message;      
    END CATCH
END GO
-----------------------------------------------------------------------------------------
-- 5. Get all Students Information 
CREATE OR ALTER PROCEDURE sp_GetAllStudentsINFO
AS
BEGIN
SELECT 
        u.Id, u.FirstName, u.LastName,
        u.Email, u.UserName,
        u.CountryName, u.City, u.State,
        u.Age, u.Gender, u.CreatedDate,
        s.Title AS StudentTitle, s.Bio,
        s.Wallet,
        (SELECT COUNT(*) FROM Enrollments WHERE StudentId = u.Id AND IsDeleted = 0) AS EnrollCount,
        (SELECT COUNT(*) FROM Orders WHERE StudentId = u.Id AND IsDeleted = 0) AS TotalOrders
    FROM AspNetUsers u
    JOIN Students s ON u.Id = s.Id
    WHERE u.IsDeleted = 0
    ORDER BY u.Id DESC
END
GO
-----------------------------------------------------------------------------------------
-- 6. Get all Instructors Information       
CREATE OR ALTER PROCEDURE sp_GetAllInstructorsINFO
    @IncludeDeleted BIT = 0,
    @MinCourses INT = NULL,
    @MinRating DECIMAL(2,1) = NULL
AS BEGIN
    SELECT 
        u.Id,u.FirstName,u.LastName,
        u.Email,u.UserName,
        u.CountryName,u.City,u.State,
        u.Age,u.Gender,u.CreatedDate,
        i.Title AS InstructorTitle, i.Bio, i.Wallet,
        i.TotalCourses,
        i.TotalStudents,
        i.TotalReviews,
        (SELECT AVG(Rating) FROM Courses WHERE InstructorId = u.Id AND IsDeleted = 0) AS AverageRating,
        (SELECT COUNT(*) FROM Courses WHERE InstructorId = u.Id AND IsDeleted = 0) AS ActiveCourseCount,
        (SELECT STRING_AGG(c.Title, ', ') AS CourseTitles  -- Added alias here
         FROM Courses c 
         WHERE c.InstructorId = u.Id AND c.IsDeleted = 0
         FOR JSON PATH) AS CourseTitlesJson
    FROM AspNetUsers u
    JOIN Instructors i ON u.Id = i.Id
    WHERE (@IncludeDeleted = 1 OR u.IsDeleted = 0)
    AND (@MinCourses IS NULL OR i.TotalCourses >= @MinCourses)
    AND (@MinRating IS NULL OR 
        (SELECT AVG(Rating) FROM Courses WHERE InstructorId = u.Id AND IsDeleted = 0) >= @MinRating)
    ORDER BY 
        CASE 
            WHEN @MinRating IS NOT NULL THEN (SELECT AVG(Rating) FROM Courses WHERE InstructorId = u.Id AND IsDeleted = 0)
            ELSE i.TotalStudents
        END DESC
END
GO
-----------------------------------------------------------------------------------------
-- 7. Get Student Information by ID       
CREATE OR ALTER PROCEDURE sp_GetStudentINFOByID @StudentID INT   
AS BEGIN
    SELECT 
        u.Id, u.FirstName, u.LastName,
        u.Email, u.UserName,
        u.CountryName, u.City, u.State,
        u.Age, u.Gender, u.CreatedDate,         
        s.Title AS StudentTitle, s.Bio, s.Wallet,
        (SELECT COUNT(*) FROM Enrollments WHERE StudentId = u.Id AND IsDeleted = 0) AS EnrollCount,
        (SELECT COUNT(*) FROM Orders WHERE StudentId = u.Id AND IsDeleted = 0) AS TotalOrders,
        (SELECT COUNT(*) FROM Enrollments WHERE StudentId = u.Id AND Status = 'Completed' AND IsDeleted = 0) AS CompletedCourses,
        (SELECT AVG(Rating) FROM Enrollments WHERE StudentId = u.Id AND Rating IS NOT NULL AND IsDeleted = 0) AS AverageCourseRating,
        -- Pivoted social media links
        MAX(CASE WHEN sm.Name = 'Facebook' THEN sm.Link END) AS Facebook,
        MAX(CASE WHEN sm.Name = 'Instagram' THEN sm.Link END) AS Instagram,
        MAX(CASE WHEN sm.Name = 'LinkedIn' THEN sm.Link END) AS LinkedIn,
        MAX(CASE WHEN sm.Name = 'X' THEN sm.Link END) AS X,
        -- Current enrollments count
        (SELECT COUNT(*) FROM Enrollments 
         WHERE StudentId = u.Id AND Status = 'In Progress' AND IsDeleted = 0) AS ActiveEnrollments
    FROM AspNetUsers u
    JOIN Students s ON u.Id = s.Id
    LEFT JOIN SocialMedias sm ON u.Id = sm.UserId AND sm.IsDeleted = 0
    WHERE u.Id = 1
    AND u.IsDeleted = 0
    GROUP BY 
        u.Id, u.FirstName, u.LastName,
        u.Email, u.UserName,
        u.CountryName, u.City, u.State,
        u.Age, u.Gender, u.CreatedDate,         
        s.Title, s.Bio, s.Wallet
END
GO
-----------------------------------------------------------------------------------------
-- 8. Get Instructor Information by ID       
CREATE OR ALTER PROCEDURE sp_GetInstructorINFOByID @InstructorID INT    
AS BEGIN
    SELECT 
        u.Id,u.FirstName,u.LastName,
        u.Email,u.UserName,
        u.CountryName,u.City,u.State,
        u.Age,u.Gender,u.CreatedDate,      
        i.Title AS InstructorTitle,i.Bio,i.Wallet,        
        i.TotalCourses, i.TotalStudents, i.TotalReviews,
        -- Pivoted Social Media Links
        MAX(CASE WHEN sm.Name = 'Facebook' THEN sm.Link END) AS Facebook,
        MAX(CASE WHEN sm.Name = 'Instagram' THEN sm.Link END) AS Instagram,
        MAX(CASE WHEN sm.Name = 'LinkedIn' THEN sm.Link END) AS LinkedIn,
        MAX(CASE WHEN sm.Name = 'X' THEN sm.Link END) AS X,
        -- Course Statistics
        (SELECT AVG(Rating) FROM Courses WHERE InstructorId = u.Id AND IsDeleted = 0) AS AverageRating,
        (SELECT COUNT(*) FROM Courses WHERE InstructorId = u.Id AND IsDeleted = 0) AS ActiveCourseCount,
        -- Formatted Course Titles (Top 5)
        (SELECT TOP 5 Title 
            FROM Courses 
            WHERE InstructorId = u.Id AND IsDeleted = 0
            ORDER BY NoSubscribers DESC
            FOR JSON PATH
        ) AS TopCoursesJson,
        -- Student and Earnings Data
        (SELECT SUM(NoSubscribers) FROM Courses WHERE InstructorId = u.Id AND IsDeleted = 0) AS TotalStudentsAllTime,
        (SELECT SUM(CurrentPrice * NoSubscribers) FROM Courses 
		WHERE InstructorId = u.Id AND IsDeleted = 0) * 0.7 AS EstimatedEarnings,
        -- Additional Metrics
        (SELECT COUNT(*) FROM Answers WHERE UserId = u.Id AND IsDeleted = 0) AS TotalAnswers,
        (SELECT COUNT(*) FROM Asks WHERE UserId = u.Id AND IsDeleted = 0) AS TotalQuestionsAsked
    FROM AspNetUsers u
    JOIN Instructors i ON u.Id = i.Id
    LEFT JOIN SocialMedias sm ON u.Id = sm.UserId AND sm.IsDeleted = 0
    WHERE u.Id = @InstructorID
    AND u.IsDeleted = 0
    GROUP BY 
        u.Id,u.FirstName,u.LastName,
        u.Email,u.UserName,
        u.CountryName,u.City,u.State,
        u.Age,u.Gender,u.CreatedDate,      
        i.Title,i.Bio,i.Wallet,        
        i.TotalCourses, i.TotalStudents, i.TotalReviews
END
GO       
-----------------------------------------------------------------------------------------       
-- 9. Get user by email
CREATE OR ALTER PROCEDURE sp_GetUserByEmail @Email NVARCHAR(256)
AS BEGIN
    SELECT 
        u.Id, u.FirstName, u.LastName,
        u.Email, u.UserName,
        u.CountryName, u.City, u.State,
        u.Age, u.Gender, u.CreatedDate,
        CASE 
            WHEN i.Id IS NOT NULL THEN 'Instructor'
            WHEN s.Id IS NOT NULL THEN 'Student'
            ELSE 'User'
        END AS UserType,
        i.Title AS InstructorTitle,
        s.Title AS StudentTitle
    FROM AspNetUsers u
    LEFT JOIN Instructors i ON u.Id = i.Id
    LEFT JOIN Students s ON u.Id = s.Id
    WHERE u.Email LIKE '%' + @Email + '%'
    AND u.IsDeleted = 0 ORDER BY u.Id
END GO      
-----------------------------------------------------------------------------------------    
-- 10. Get user by Full Name    
 CREATE OR ALTER PROCEDURE sp_GetUserByFullName @FullName NVARCHAR(101)     
AS BEGIN
    SELECT 
        u.Id, u.FirstName, u.LastName,
        u.Email, u.UserName,
        u.CountryName, u.City, u.State,
        u.Age, u.Gender, u.CreatedDate,
        CASE 
            WHEN i.Id IS NOT NULL THEN 'Instructor'
            WHEN s.Id IS NOT NULL THEN 'Student'
            ELSE 'User'
        END AS UserType,
        i.Title AS InstructorTitle,
        s.Title AS StudentTitle
    FROM AspNetUsers u
    LEFT JOIN Instructors i ON u.Id = i.Id
    LEFT JOIN Students s ON u.Id = s.Id
    WHERE CONCAT(u.FirstName, ' ', u.LastName) LIKE '%' + @FullName + '%'
    AND u.IsDeleted = 0 ORDER BY u.Id
    END GO
-----------------------------------------------------------------------------------------
--Course Management Procedures
-- 11. Create a new course
CREATE OR ALTER PROCEDURE sp_CreateCourse
    @Title NVARCHAR(255),
    @Description NVARCHAR(MAX),
    @Price DECIMAL(8,2),
    @Duration INT,
    @Language NVARCHAR(20),
    @SubCategoryId INT,
    @InstructorId INT
AS BEGIN
    DECLARE @IsFree BIT = CASE WHEN @Price > 0 THEN 0 ELSE 1 END
    INSERT INTO Courses (Title, Description, Status, CourseLevel, Price, Duration, 
                        Language, NoSubscribers, IsFree, IsApproved, SubCategoryId, 
                        InstructorId, CreatedDate, IsDeleted)
    VALUES (@Title, @Description, 'Draft', 'All', @Price, @Duration, 
            @Language, 0, @IsFree, 0, @SubCategoryId, 
            @InstructorId, GETDATE(), 0);
    UPDATE Instructors SET TotalCourses = TotalCourses +1 where Id = @InstructorId;
    SELECT SCOPE_IDENTITY() AS NewCourseId
END GO

-----------------------------------------------------------------------------------------    
-- 12. Update course information
CREATE OR ALTER PROCEDURE sp_UpdateCourse @CourseId INT, @Title NVARCHAR(255),
    @Description NVARCHAR(MAX),@OriginalPrice DECIMAL(8,2) = NULL,@Discount DECIMAL(8,2) = NULL,
    @Language NVARCHAR(20),@SubCategoryId INT  
AS BEGIN
    DECLARE @NewDiscount DECIMAL(8,2) DECLARE @NewOriginalPrice DECIMAL(8,2)   
    DECLARE @CurrentOriginalPrice DECIMAL(8,2) DECLARE @IsFree BIT
    -- Get current original price
    SELECT @CurrentOriginalPrice = Price FROM Courses WHERE Id = @CourseId
    -- Determine which values to update
    SET @NewOriginalPrice = COALESCE(@OriginalPrice, @CurrentOriginalPrice)
    SET @NewDiscount = COALESCE(@Discount, 
        (SELECT Discount FROM Courses WHERE Id = @CourseId))   
    -- CurrentPrice will be automatically computed by the column formula
    SET @IsFree = CASE WHEN (@NewOriginalPrice * (1 - (@NewDiscount/100))) = 0 THEN 1 ELSE 0 END
    UPDATE Courses SET Title = @Title,Description = @Description,Price = @NewOriginalPrice,    
        Discount = @NewDiscount,Language = @Language,SubCategoryId = @SubCategoryId,IsFree = @IsFree,  
        ModifiedDate = GETDATE() WHERE Id = @CourseId   
END GO
-----------------------------------------------------------------------------------------
-- 13. Approve a course
CREATE OR ALTER PROCEDURE sp_ApproveCourse
    @CourseId INT
AS
BEGIN
    UPDATE Courses
    SET IsApproved = 1,
        ModifiedDate = GETDATE()
    WHERE Id = @CourseId
END
GO
-----------------------------------------------------------------------------------------    
-- 14. Get All courses Details 
CREATE OR ALTER PROCEDURE sp_GetAllCourseDetails
AS BEGIN
    SELECT 
        c.Id AS CourseId,c.Title AS CourseTitle,c.Description,
        c.Status,c.CourseLevel,
        c.Price AS OriginalPrice,c.CurrentPrice,c.Discount,
        c.Duration AS TotalMinutes,c.Language,
        c.ImageUrl,c.VideoUrl,
        c.NoSubscribers,c.IsFree,c.IsApproved,
        c.Rating,c.CreatedDate,c.ModifiedDate,
        -- Instructor Information
        u.Id AS InstructorId,
        u.FirstName + ' ' + u.LastName AS InstructorFullName,
        i.Title AS InstructorTitle,
        i.Bio AS InstructorBio,
        i.TotalStudents AS InstructorTotalStudents,
        -- Category Information
        cat.Id AS CategoryId,
        cat.Name AS CategoryName,
        -- Subcategory Information
        sc.Id AS SubCategoryId,
        sc.Name AS SubCategoryName,
        -- Course Structure
        (SELECT COUNT(*) FROM Sections WHERE CourseId = c.Id AND IsDeleted = 0) AS NoSection,
        (SELECT COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id 
         WHERE s.CourseId = c.Id AND l.IsDeleted = 0) AS NoLesson,
		-- Video and Article Lessons Count
        (SELECT COUNT(*) FROM Lessons l 
         JOIN Sections s ON l.SectionId = s.Id 
         WHERE s.CourseId = c.Id AND l.IsDeleted = 0 AND l.Type = 'Video') AS NoVideo,
        (SELECT COUNT(*) FROM Lessons l 
         JOIN Sections s ON l.SectionId = s.Id 
         WHERE s.CourseId = c.Id AND l.IsDeleted = 0 AND l.Type = 'Article') AS NoArticle,
        -- Course Duration Breakdown
        (SELECT SUM(l.Duration) FROM Lessons l
         JOIN Sections s ON l.SectionId = s.Id
         WHERE s.CourseId = c.Id AND l.IsDeleted = 0) AS TotalVideoMinutes
    FROM Courses c
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    JOIN Instructors i ON u.Id = i.Id
    JOIN Subcategories sc ON c.SubCategoryId = sc.Id
    JOIN Categories cat ON sc.CategoryId = cat.Id
    WHERE c.IsDeleted = 0
    ORDER BY c.Id DESC
END
GO
-----------------------------------------------------------------------------------------
-- 15. Get course all Details by ID
CREATE OR ALTER PROCEDURE sp_GetCourseDetailsById
    @CourseId INT
AS BEGIN
    SELECT 
        c.Id AS CourseId,c.Title AS CourseTitle,c.Description,
        c.Status,c.CourseLevel,
        c.Price AS OriginalPrice,c.CurrentPrice,c.Discount,
        c.Duration AS TotalMinutes,c.Language,
        c.ImageUrl,c.VideoUrl,
        c.NoSubscribers,c.IsFree,c.IsApproved,
        c.Rating,c.CreatedDate,c.ModifiedDate,
        -- Instructor
        u.Id AS InstructorId,u.FirstName + ' ' + u.LastName AS InstructorFullName,
        i.Title AS InstructorTitle,i.Bio AS InstructorBio,i.TotalStudents AS InstructorTotalStudents,
        -- Category
        cat.Id AS CategoryId,cat.Name AS CategoryName,
        -- Subcategory
        sc.Id AS SubCategoryId,sc.Name AS SubCategoryName,
        -- Structure
        (SELECT COUNT(*) FROM Sections WHERE CourseId = c.Id AND IsDeleted = 0) AS NoSection,
        (SELECT COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id WHERE s.CourseId = c.Id AND l.IsDeleted = 0) AS NoLesson,
        (SELECT COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id WHERE s.CourseId = c.Id AND l.IsDeleted = 0 AND l.Type = 'Video') AS NoVideo,
        (SELECT COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id WHERE s.CourseId = c.Id AND l.IsDeleted = 0 AND l.Type = 'Article') AS NoArticle,
        (SELECT SUM(l.Duration) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id WHERE s.CourseId = c.Id AND l.IsDeleted = 0) AS TotalVideoMinutes,
        -- JSON Data
        (SELECT sm.Name,sm.Link FROM SocialMedias sm WHERE sm.UserId = u.Id AND sm.IsDeleted = 0 FOR JSON PATH) AS InstructorSocialMedia,
        (SELECT Goal FROM CourseGoals WHERE CourseId = c.Id AND IsDeleted = 0 FOR JSON PATH) AS CourseGoals,
        (SELECT Requirement FROM CourseRequirements WHERE CourseId = c.Id AND IsDeleted = 0 FOR JSON PATH) AS CourseRequirements
    FROM Courses c
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    JOIN Instructors i ON u.Id = i.Id
    JOIN Subcategories sc ON c.SubCategoryId = sc.Id
    JOIN Categories cat ON sc.CategoryId = cat.Id
    WHERE c.Id = @CourseId AND c.IsDeleted = 0
END
GO
-----------------------------------------------------------------------------------------    
-- 16. Get course by ID
CREATE OR ALTER PROCEDURE sp_GetCourseById @CourseId INT
AS BEGIN
    SELECT c.*, sc.Name AS SubCategoryName, cat.Name AS CategoryName,
           u.FirstName + ' ' + u.LastName AS InstructorName
    FROM Courses c
    JOIN Subcategories sc ON c.SubCategoryId = sc.Id
    JOIN Categories cat ON sc.CategoryId = cat.Id
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    WHERE c.Id = @CourseId AND c.IsDeleted = 0
END GO
-----------------------------------------------------------------------------------------    
-- 17. Search courses by keyword
CREATE OR ALTER PROCEDURE sp_SearchCourses @Keyword NVARCHAR(255)
AS BEGIN
    SELECT c.*, sc.Name AS SubCategoryName, u.FirstName + ' ' + u.LastName AS InstructorName
    FROM Courses c
    JOIN Subcategories sc ON c.SubCategoryId = sc.Id
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    WHERE (c.Title LIKE '%' + @Keyword + '%' OR 
           c.Description LIKE '%' + @Keyword + '%') AND 
          c.IsDeleted = 0 AND c.IsApproved = 1
    END GO
-----------------------------------------------------------------------------------------
-- 18. Get courses by CategoryID or CategoryName
CREATE OR ALTER PROCEDURE sp_GetCoursesByCategory @CategoryId INT = NULL,@CategoryName NVARCHAR(20) = NULL
AS BEGIN
    IF @CategoryId IS NULL AND @CategoryName IS NULL
    BEGIN
        RAISERROR('Either CategoryId or CategoryName must be provided', 16, 1)    RETURN
    END
    SELECT 
        c.Id AS CourseId,c.Title AS CourseTitle,c.Description,
        c.Price AS OriginalPrice,c.CurrentPrice,c.Discount,c.Duration,
        c.Language,c.ImageUrl,c.VideoUrl,
        c.NoSubscribers,c.Rating,c.CreatedDate,
        -- Subcategory Info
        sc.Id AS SubCategoryId, sc.Name AS SubCategoryName,
        -- Instructor Info
        u.Id AS InstructorId, i.Title AS InstructorTitle,
        u.FirstName + ' ' + u.LastName AS InstructorName,
        -- Course Structure
        (SELECT COUNT(*) FROM Sections WHERE CourseId = c.Id AND IsDeleted = 0) AS SectionCount,
        (SELECT COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id 
         WHERE s.CourseId = c.Id AND l.IsDeleted = 0) AS LessonCount,
        cat.Id AS CategoryId,
        cat.Name AS CategoryName
    FROM Courses c
    JOIN Subcategories sc ON c.SubCategoryId = sc.Id
    JOIN Categories cat ON sc.CategoryId = cat.Id
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    JOIN Instructors i ON u.Id = i.Id
    
    WHERE(@CategoryId IS NOT NULL AND sc.CategoryId = @CategoryId OR
          @CategoryName IS NOT NULL AND cat.Name LIKE '%' + @CategoryName + '%')
    AND c.IsDeleted = 0 AND c.IsApproved = 1
END GO
-----------------------------------------------------------------------------------------    
-- 19. Get courses by SubCategoryID or SubCategoryName
CREATE OR ALTER PROCEDURE sp_GetCoursesBySubcategory @SubcategoryId INT = NULL,
@SubcategoryName NVARCHAR(255) = NULL
AS BEGIN
    IF @SubcategoryId IS NULL AND @SubcategoryName IS NULL
    BEGIN
        RAISERROR('Either SubcategoryId or SubcategoryName must be provided', 16, 1)RETURN
    END
    SELECT 
        c.Id AS CourseId,c.Title AS CourseTitle,c.Description,
        c.Price AS OriginalPrice,c.CurrentPrice,c.Discount,c.Duration,
        c.Language,c.ImageUrl,c.VideoUrl,
        c.NoSubscribers,c.Rating,c.CreatedDate,
        -- Subcategory Info
        sc.Id AS SubCategoryId, sc.Name AS SubCategoryName,
        -- Category Info
        cat.Id AS CategoryId, cat.Name AS CategoryName,
        -- Instructor Info
        u.Id AS InstructorId, i.Title AS InstructorTitle,
        u.FirstName + ' ' + u.LastName AS InstructorName,
        -- Course Structure
        (SELECT COUNT(*) FROM Sections WHERE CourseId = c.Id AND IsDeleted = 0) AS SectionCount,
        (SELECT COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id 
         WHERE s.CourseId = c.Id AND l.IsDeleted = 0) AS LessonCount
    FROM Courses c
    JOIN Subcategories sc ON c.SubCategoryId = sc.Id
    JOIN Categories cat ON sc.CategoryId = cat.Id
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    JOIN Instructors i ON u.Id = i.Id
    WHERE 
        (@SubcategoryId IS NOT NULL AND sc.Id = @SubcategoryId OR
         @SubcategoryName IS NOT NULL AND sc.Name LIKE '%' + @SubcategoryName + '%')
    AND c.IsDeleted = 0 AND c.IsApproved = 1
END GO
-----------------------------------------------------------------------------------------
-- 20. Get courses by Instructor Name
CREATE OR ALTER PROCEDURE sp_GetCoursesByInstructorName @InstructorName NVARCHAR(101) = NULL
AS BEGIN
    IF @InstructorName IS NULL
    BEGIN
        RAISERROR('Instructor name must be provided', 16, 1) RETURN
    END
    SELECT 
        c.Id AS CourseId,c.Title AS CourseTitle,c.Description,
        c.Price AS OriginalPrice,c.CurrentPrice,c.Discount,c.Duration,
        c.Language,c.ImageUrl,c.VideoUrl,
        c.NoSubscribers,c.Rating,c.CreatedDate,
        -- Subcategory Info
        sc.Id AS SubCategoryId,sc.Name AS SubCategoryName,
        -- Category Info
        cat.Id AS CategoryId,cat.Name AS CategoryName,
        -- Instructor Info
        u.Id AS InstructorId,
        u.FirstName + ' ' + u.LastName AS InstructorFullName,
        i.Title AS InstructorTitle,i.TotalStudents AS InstructorStudents,
        -- Course Structure
        (SELECT COUNT(*) FROM Sections WHERE CourseId = c.Id AND IsDeleted = 0) AS SectionCount,
        (SELECT COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id 
         WHERE s.CourseId = c.Id AND l.IsDeleted = 0) AS LessonCount
    FROM Courses c
    JOIN Subcategories sc ON c.SubCategoryId = sc.Id
    JOIN Categories cat ON sc.CategoryId = cat.Id
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    JOIN Instructors i ON u.Id = i.Id
    WHERE 
        (u.FirstName + ' ' + u.LastName LIKE '%' + @InstructorName + '%' OR
         u.FirstName LIKE '%' + @InstructorName + '%' OR
         u.LastName LIKE '%' + @InstructorName + '%')
    AND c.IsDeleted = 0 AND c.IsApproved = 1
END GO
-----------------------------------------------------------------------------------------    
-- 21. Delete from Course by Course ID
CREATE OR ALTER PROCEDURE sp_DeleteCourse @CourseId INT,@HardDelete BIT = 0 
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate course exists
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId)
        BEGIN SELECT 0 AS Success, 'Course not found' AS Message;RETURN;END
        -- Check if already soft-deleted when doing soft delete
        IF @HardDelete = 0 AND EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId AND IsDeleted = 1)
        BEGIN SELECT 0 AS Success, 'Course is already deleted' AS Message;RETURN;END
        BEGIN TRANSACTION;
        IF @HardDelete = 1 BEGIN 
            -- HARD DELETE -------------------------------------------------  
            -- Delete quiz questions first (child of quizzes)
            DELETE FROM QuizQuestions WHERE QuizId IN (SELECT Id FROM Quizzes WHERE CourseId = @CourseId);  
            -- Delete quizzes
            DELETE FROM Quizzes WHERE CourseId = @CourseId;   
            -- Delete lessons (child of sections)
            DELETE FROM Lessons WHERE SectionId IN (SELECT Id FROM Sections WHERE CourseId = @CourseId);    
            -- Delete sections
            DELETE FROM Sections WHERE CourseId = @CourseId;  
            -- Delete course requirements and goals
            DELETE FROM CourseRequirements WHERE CourseId = @CourseId;
            DELETE FROM CourseGoals WHERE CourseId = @CourseId;
            -- Delete enrollments
            DELETE FROM Enrollments WHERE CourseId = @CourseId;
            -- Finally delete the course
            DELETE FROM Courses WHERE Id = @CourseId;
            SELECT 1 AS Success, 'Course and all related data permanently deleted' AS Message; END
        ELSE BEGIN
            -- SOFT DELETE -------------------------------------------------
            -- Soft delete the main course
            UPDATE Courses SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE Id = @CourseId;
            -- Soft delete CourseGoals    
            UPDATE CourseGoals SET IsDeleted = 1,ModifiedDate = GETDATE()WHERE CourseId = @CourseId;  
            -- Soft delete CourseRequirements
            UPDATE CourseRequirements SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE CourseId = @CourseId; 
            -- Soft delete sections and lessons
            UPDATE Sections SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE CourseId = @CourseId;  
            UPDATE Lessons SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE SectionId IN (SELECT Id FROM Sections WHERE CourseId = @CourseId);  
            -- Soft delete quizzes and questions
            UPDATE Quizzes SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE CourseId = @CourseId; 
            UPDATE QuizQuestions SET IsDeleted = 1,ModifiedDate = GETDATE()              
            WHERE QuizId IN (SELECT Id FROM Quizzes WHERE CourseId = @CourseId);    
            SELECT 1 AS Success, 'Course and all related data marked as deleted' AS Message;
        END        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;                  
        SELECT 0 AS Success, 'Error deleting course: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------
-- 22. Add course requirement
CREATE OR ALTER PROCEDURE sp_AddCourseRequirement @CourseId INT, @Requirement NVARCHAR(255)
AS BEGIN
    INSERT INTO CourseRequirements (Requirement, CourseId, CreatedDate, IsDeleted)
    VALUES (@Requirement, @CourseId, GETDATE(), 0)
END GO
-----------------------------------------------------------------------------------------    
-- 23. Add course goal
CREATE OR ALTER PROCEDURE sp_AddCourseGoal
    @CourseId INT,
    @Goal NVARCHAR(255)
AS BEGIN
    INSERT INTO CourseGoals (Goal, CourseId, CreatedDate, IsDeleted)
    VALUES (@Goal, @CourseId, GETDATE(), 0)
END GO
-----------------------------------------------------------------------------------------
--Enrollment and Cart Procedures
-- 24. Enroll Student in Course
CREATE OR ALTER PROCEDURE sp_EnrollStudentInCourse @StudentId INT, @CourseId INT
AS BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Check if enrollment already exists
        IF EXISTS (SELECT 1 FROM Enrollments 
                  WHERE StudentId = @StudentId AND CourseId = @CourseId AND IsDeleted = 0)
        BEGIN
            SELECT 0 AS Success, 'Student is already enrolled in this course' AS Message;
            RETURN;
        END 
        -- Add enrollment record
        INSERT INTO Enrollments (StudentId, CourseId, Status, CreatedDate, IsDeleted, ProgressPercentage)
        VALUES (@StudentId, @CourseId, 'Not Started', GETDATE(), 0, 0);
        -- Update subscriber count
        UPDATE Courses SET NoSubscribers = NoSubscribers + 1 WHERE Id = @CourseId;
        -- Initialize progress tracking for all lessons
        INSERT INTO Progresses (StudentId, LessonId, Status, CreatedDate, IsDeleted)
        SELECT 
            @StudentId, l.Id AS LessonId,'Not Started' AS Status,
            GETDATE() AS CreatedDate,0 AS IsDeleted
        FROM Lessons l JOIN Sections s ON l.SectionId = s.Id
        WHERE s.CourseId = @CourseId AND l.IsDeleted = 0 AND s.IsDeleted = 0;
        -- Return success
        SELECT 1 AS Success, 'Enrollment successful' AS Message;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SELECT 0 AS Success,'Enrollment failed: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
-- 25. Get Student Enrollments
CREATE OR ALTER PROCEDURE sp_GetStudentEnrollments @StudentId INT    
AS BEGIN
    SELECT 
        e.StudentId,s.FirstName + ' ' + s.LastName AS StudentFullName,
        e.CourseId,c.Title AS CourseTitle, c.ImageUrl AS CourseImage,
        e.Status,e.StartDate,e.CompletionDate,
        e.Rating,e.comment,e.ProgressPercentage,e.CertificationUrl,
        u.FirstName + ' ' + u.LastName AS InstructorFullName
    FROM Enrollments e
    JOIN Courses c ON e.CourseId = c.Id
    JOIN AspNetUsers u ON c.InstructorId = u.Id
    JOIN AspNetUsers s ON e.StudentId = s.Id
    WHERE e.StudentId = @StudentId 
    AND e.IsDeleted = 0
    ORDER BY e.StartDate DESC
END GO
-----------------------------------------------------------------------------------------
-- 26. Update Enrollment Progress
CREATE OR ALTER PROCEDURE sp_UpdateEnrollmentProgress @StudentId INT,@CourseId INT, @ProgressPercentage DECIMAL(8,2)  
AS BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Validate progress percentage (0-100)
        IF @ProgressPercentage < 0 SET @ProgressPercentage = 0;
        IF @ProgressPercentage > 100 SET @ProgressPercentage = 100;
        -- Update progress and status
        UPDATE Enrollments
        SET ProgressPercentage = @ProgressPercentage,ModifiedDate = GETDATE(),
            Status = CASE 
                        WHEN @ProgressPercentage = 100 THEN 'Completed'
                        WHEN @ProgressPercentage > 0 THEN 'In Progress'
                        ELSE Status END, -- Maintain existing status if 0%
            CompletionDate = CASE 
                               WHEN @ProgressPercentage = 100 THEN GETDATE()
                               ELSE CompletionDate
                            END
        WHERE StudentId = @StudentId AND CourseId = @CourseId AND IsDeleted = 0;
        COMMIT TRANSACTION;
        SELECT 1 AS Success, 'Progress updated successfully' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 'Error updating progress: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--27 Soft Delete from Enrollment
CREATE OR ALTER PROCEDURE sp_SoftDeleteEnrollment @StudentId INT,@CourseId INT
AS BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Check if enrollment exists and isn't already deleted
        IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE StudentId = @StudentId 
            AND CourseId = @CourseId AND IsDeleted = 0)
        BEGIN
            SELECT 0 AS Success, 'Enrollment not found or already deleted' AS Message;
            RETURN;
        END
        -- Soft delete the enrollment
        UPDATE Enrollments SET IsDeleted = 1,ModifiedDate = GETDATE()
        WHERE StudentId = @StudentId AND CourseId = @CourseId;
        -- Soft delete all progress records for this enrollment
        UPDATE p SET p.IsDeleted = 1, p.ModifiedDate = GETDATE()
        FROM Progresses p INNER JOIN Lessons l ON p.LessonId = l.Id
        INNER JOIN Sections s ON l.SectionId = s.Id
        WHERE p.StudentId = @StudentId AND s.CourseId = @CourseId AND p.IsDeleted = 0;
        -- Decrement subscriber count if enrollment was active
        UPDATE Courses
        SET NoSubscribers = NoSubscribers - 1
        WHERE Id = @CourseId
        AND EXISTS (SELECT 1 FROM Enrollments WHERE StudentId = @StudentId
            AND CourseId = @CourseId AND Status IN ('In Progress', 'Not Started'));
        -- Return success
        SELECT 1 AS Success, 'Enrollment and related progress records soft deleted' AS Message;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 
               'Error deleting enrollment: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--28 Add Course to Cart
CREATE OR ALTER PROCEDURE sp_AddCourseToCart @StudentId INT, @CourseId INT
AS BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @CartId INT;
        -- Check if student has an active cart
        SELECT @CartId = Id FROM Carts WHERE StudentId = @StudentId AND IsDeleted = 0;
        -- If no cart exists, create one
        IF @CartId IS NULL
        BEGIN
            INSERT INTO Carts (StudentId, Amount, CreatedDate, IsDeleted)
            VALUES (@StudentId, 0, GETDATE(), 0);
            SET @CartId = SCOPE_IDENTITY();
        END;
        -- Add course to cart if not already present
        IF NOT EXISTS (SELECT 1 FROM CartCourse WHERE CartId = @CartId AND CourseId = @CourseId)
        BEGIN
            INSERT INTO CartCourse (CartId, CourseId)
            VALUES (@CartId, @CourseId);
            -- Update cart amount (count of courses)
            UPDATE Carts SET Amount = (SELECT COUNT(*) FROM CartCourse WHERE CartId = @CartId),
            ModifiedDate = GETDATE()WHERE Id = @CartId;
        END;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION; THROW;
    END CATCH;
END GO
-----------------------------------------------------------------------------------------    
--29 Remove Course From Cart
CREATE OR ALTER PROCEDURE sp_RemoveCourseFromCart @StudentId INT,@CourseId INT
AS BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @CartId INT;
        -- Get the student's active cart
        SELECT @CartId = Id FROM Carts WHERE StudentId = @StudentId AND IsDeleted = 0;
        -- If cart exists, remove the course
        IF @CartId IS NOT NULL
        BEGIN
            -- Remove course from cart
            DELETE FROM CartCourse WHERE CartId = @CartId AND CourseId = @CourseId; 
            -- Update cart amount (count of remaining courses)
            UPDATE Carts
            SET Amount = (SELECT COUNT(*) FROM CartCourse WHERE CartId = @CartId), 
                ModifiedDate = GETDATE() WHERE Id = @CartId;
            -- If cart is now empty, soft delete it
            IF (SELECT COUNT(*) FROM CartCourse WHERE CartId = @CartId) = 0
             BEGIN
               UPDATE Carts SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE Id = @CartId;
             END;    
            SELECT 1 AS Success, 'Course removed from cart' AS Message;
        END
        ELSE
        BEGIN SELECT 0 AS Success, 'Active cart not found' AS Message; END;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 
               'Error removing course from cart: ' + ERROR_MESSAGE() AS Message;
    END CATCH;
END GO
-----------------------------------------------------------------------------------------    
--30 Soft delete the cart by Cart ID 
CREATE OR ALTER PROCEDURE sp_DeleteCart @CartId INT,@HardDelete BIT = 0   
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CartExists BIT = 0;
        -- Verify cart exists and get current deletion status
        SELECT @CartExists = 1 FROM Carts WHERE Id = @CartId; 
        IF @CartExists=0 BEGIN SELECT 0 AS Success, 'Cart not found' AS Message;RETURN;END
        IF @HardDelete = 0 AND EXISTS (SELECT 1 FROM Carts WHERE Id = @CartId AND IsDeleted = 1)
        BEGIN SELECT 0 AS Success, 'Cart is already deleted' AS Message;RETURN;END  
        BEGIN TRANSACTION;
        IF @HardDelete = 1 BEGIN
            -- First delete cart items (hard delete)Then hard delete the cart
            DELETE FROM CartCourse WHERE CartId = @CartId;
            DELETE FROM Carts WHERE Id = @CartId;END
        ELSE BEGIN
            -- Soft delete the cart (items remain associated but cart is marked deleted)
            UPDATE Carts SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE Id = @CartId;
            SELECT 1 AS Success, 'Cart marked as deleted' AS Message; END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 'Error deleting cart: ' + ERROR_MESSAGE() AS Message;  
    END CATCH
END GO 
-----------------------------------------------------------------------------------------    
--31 Get Cart Contents by Student Id
CREATE OR ALTER PROCEDURE sp_GetCartContents @StudentId INT
AS BEGIN
    SELECT 
        c.Id AS CartId,c.StudentId,
        s.FirstName + ' ' + s.LastName AS StudentFullName, 
        cc.CourseId,co.Title AS CourseTitle,co.CurrentPrice AS Price,co.Discount
    FROM Carts c
    JOIN AspNetUsers s ON c.StudentId = s.Id JOIN CartCourse cc ON c.Id = cc.CartId
    JOIN Courses co ON cc.CourseId = co.Id WHERE c.StudentId = @StudentId AND c.IsDeleted = 0
    ORDER BY cc.CourseId
END GO
-----------------------------------------------------------------------------------------    
--32 Create Order from Cart
CREATE OR ALTER PROCEDURE sp_CreateOrderFromCart @StudentId INT,@PaymentMethod NVARCHAR(50)          
AS BEGIN
    DECLARE @CartId INT, @OrderId INT, @TotalAmount DECIMAL(10,2)    
   BEGIN TRANSACTION
    BEGIN TRY
      -- Get student's active cart
      SELECT @CartId = Id, @TotalAmount = Amount  FROM Carts WHERE StudentId = @StudentId AND IsDeleted = 0     
        IF @CartId IS NULL BEGIN RAISERROR('No active cart found for student', 16, 1); RETURN;END   
        -- Create order with Pending status
        INSERT INTO Orders (StudentId, PaymentMethod, Status, TotalAmount, CreatedDate, IsDeleted)
        VALUES (@StudentId, @PaymentMethod, 'Pending', @TotalAmount, GETDATE(), 0)          
        SET @OrderId = SCOPE_IDENTITY()        
        -- Add courses to order with their discounted prices
        INSERT INTO CourseOrder (OrderId, CourseId, OrderPrice)
        SELECT @OrderId, cc.CourseId, 
               CASE  WHEN c.Discount > 0 THEN c.Price * (1 - (c.Discount/100)) ELSE c.Price END          
        FROM CartCourse cc JOIN Courses c ON cc.CourseId = c.Id WHERE cc.CartId = @CartId 
        -- Soft delete the cart
        UPDATE Carts SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE Id = @CartId
        COMMIT TRANSACTION        
        -- Return the new order ID
        SELECT @OrderId AS NewOrderId
    END TRY
    BEGIN CATCH 
        IF @@TRANCOUNT > 0   ROLLBACK TRANSACTION  THROW      
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--33 Complete Order And Enroll
CREATE OR ALTER PROCEDURE sp_CompleteOrderAndEnroll @OrderId INT
AS BEGIN
    DECLARE @StudentId INT DECLARE @PaymentStatus NVARCHAR(50)   
    DECLARE @CourseId INT DECLARE @ErrorMsg NVARCHAR(4000)   
    BEGIN TRANSACTION
    BEGIN TRY
        -- Verify order exists and is pending
        SELECT @StudentId = StudentId, @PaymentStatus = Status FROM Orders
        WHERE Id = @OrderId AND IsDeleted = 0
        IF @StudentId IS NULL BEGIN RAISERROR('Order not found or already processed', 16, 1)RETURN END      
        IF @PaymentStatus <> 'Pending' BEGIN RAISERROR('Order is not in pending status', 16, 1)RETURN END 
        -- Update order status to Completed
        UPDATE Orders SET Status = 'Completed',ModifiedDate = GETDATE()WHERE Id = @OrderId
        -- Enroll student in all courses from the order using cursor
        DECLARE CourseCursor CURSOR LOCAL FOR
        SELECT CourseId FROM CourseOrder WHERE OrderId = @OrderId
        OPEN CourseCursor FETCH NEXT FROM CourseCursor INTO @CourseId
        WHILE @@FETCH_STATUS = 0 BEGIN
            BEGIN TRY
                EXEC sp_EnrollStudentInCourse @StudentId = @StudentId, @CourseId = @CourseId
            END TRY
            BEGIN CATCH
                -- Log individual course enrollment failure but continue with others
                SET @ErrorMsg = 'Failed to enroll in course ' +CAST(@CourseId AS  NVARCHAR(10)) +    
                ': ' + ERROR_MESSAGE()RAISERROR(@ErrorMsg, 10, 1)
            END CATCH
            FETCH NEXT FROM CourseCursor INTO @CourseId
        END
        CLOSE CourseCursor
        DEALLOCATE CourseCursor
        COMMIT TRANSACTION
        SELECT 1 AS Success, 'Order completed and student enrolled in all courses' AS Message
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION           
        IF ERROR_SEVERITY() > 10 -- Only return error for critical failures
         BEGIN SELECT 0 AS Success, ERROR_MESSAGE() AS Message END        
       ELSE BEGIN        
        SELECT 1 AS Success,'Order completed with some enrollment warnings: ' + ERROR_MESSAGE() AS Message            
       END
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--34 Soft Delete from Order
CREATE OR ALTER PROCEDURE sp_SoftDeleteOrder
    @OrderId INT
AS BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Check if order exists and isn't already deleted
        IF NOT EXISTS (SELECT 1 FROM Orders WHERE Id = @OrderId AND IsDeleted = 0)
        BEGIN SELECT 0 AS Success, 'Order not found or already deleted' AS Message; RETURN; END
        -- Get order details
        DECLARE @StudentId INT, @OrderStatus NVARCHAR(50);
        SELECT @StudentId = StudentId, @OrderStatus = Status FROM Orders WHERE Id = @OrderId;
        -- Soft delete the order
        UPDATE Orders SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE Id = @OrderId;
        -- Delete course associations (no soft delete available)
        DELETE FROM CourseOrder WHERE OrderId = @OrderId;
        -- Handle completed orders (delete enrollments)
        IF @OrderStatus = 'Completed'
        BEGIN
            DECLARE @CourseId INT;
            DECLARE CourseCursor CURSOR FOR 
                SELECT CourseId FROM CourseOrder WHERE OrderId = @OrderId;
            OPEN CourseCursor;
            FETCH NEXT FROM CourseCursor INTO @CourseId;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC sp_SoftDeleteEnrollment @StudentId = @StudentId, @CourseId = @CourseId;
                FETCH NEXT FROM CourseCursor INTO @CourseId;
            END
            CLOSE CourseCursor;
            DEALLOCATE CourseCursor;
        END
        -- Return success
        SELECT 1 AS Success, 'Order and related records deleted' AS Message;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 'Error deleting order: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--35 Create Order with Courses
CREATE OR ALTER PROCEDURE sp_CreateOrderWithCourses
    @StudentId INT,@CourseIds NVARCHAR(MAX),@PaymentMethod NVARCHAR(50)  
AS BEGIN 
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @OrderId INT;
        DECLARE @TotalAmount INT = 0;  
        -- Count the number of courses being ordered
        SELECT @TotalAmount = COUNT(*) 
        FROM STRING_SPLIT(@CourseIds, ',');
        -- Create the order (now using @TotalAmount as course count)
        INSERT INTO Orders (StudentId, PaymentMethod, Status, TotalAmount, CreatedDate, IsDeleted)
        VALUES (@StudentId, @PaymentMethod, 'Pending', @TotalAmount, GETDATE(), 0);
        SET @OrderId = SCOPE_IDENTITY();
        -- Insert all course associations
        INSERT INTO CourseOrder (OrderId, CourseId)
        SELECT @OrderId, CAST(value AS INT)  -- Explicit cast to INT for safety
        FROM STRING_SPLIT(@CourseIds, ',');
        COMMIT TRANSACTION;
        SELECT @OrderId AS NewOrderId, 1 AS Success, 'Order created successfully' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 'Order creation failed: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--Course Content Procedures
--36 Add Section to Course
CREATE OR ALTER PROCEDURE sp_AddSectionToCourse @CourseId INT,@Title NVARCHAR(255)
AS BEGIN   
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate course exists and is not deleted
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId AND IsDeleted = 0)
        BEGIN
            RAISERROR('Course not found or has been deleted', 16, 1);RETURN;
        END
        BEGIN TRANSACTION;
        -- Insert new section
        INSERT INTO Sections (Title, Duration, NoLessons, CourseId, CreatedDate, IsDeleted)
        VALUES (@Title, 0, 0, @CourseId, GETDATE(), 0);
        -- Return the new section ID
        SELECT SCOPE_IDENTITY() AS NewSectionId, 1 AS Success, 'Section added successfully' AS Message;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;           
        SELECT 0 AS Success,'Failed to add section: ' + ERROR_MESSAGE() AS Message,NULL AS NewSectionId;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--37 Remove Section from Course
CREATE OR ALTER PROCEDURE sp_RemoveSectionFromCourse @SectionId INT
AS BEGIN 
  SET NOCOUNT ON;
    BEGIN TRY
        -- Validate section exists and is not deleted
        IF NOT EXISTS (SELECT 1 FROM Sections WHERE Id = @SectionId AND IsDeleted = 0)
        BEGIN RAISERROR('Section not found or already deleted', 16, 1);RETURN; END
        -- Check if section has lessons
        IF EXISTS (SELECT 1 FROM Lessons WHERE SectionId = @SectionId AND IsDeleted = 0)
        BEGIN
            RAISERROR('Cannot delete section with active lessons', 16, 1);RETURN;
        END
        BEGIN TRANSACTION;
        -- Soft delete the section
        UPDATE Sections SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE Id = @SectionId;
        SELECT @SectionId AS DeletedSectionId, 1 AS Success, 'Section removed successfully' AS Message;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success,'Failed to remove section: ' + ERROR_MESSAGE() AS Message,NULL AS    DeletedSectionId;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--38 Update Section
CREATE OR ALTER PROCEDURE sp_UpdateSection
    @SectionId INT,@Title NVARCHAR(255) = NULL,
    @Duration INT = NULL,@IsDeleted BIT = NULL
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate section exists
        IF NOT EXISTS (SELECT 1 FROM Sections WHERE Id = @SectionId)
        BEGIN RAISERROR('Section not found', 16, 1);RETURN; END
        BEGIN TRANSACTION; 
        -- Update only provided fields (except NoLessons)
        UPDATE Sections 
        SET Title = ISNULL(@Title, Title), Duration = ISNULL(@Duration, Duration),
            IsDeleted = ISNULL(@IsDeleted, IsDeleted), ModifiedDate = GETDATE()WHERE  Id = @SectionId; 
        SELECT @SectionId AS UpdatedSectionId,1 AS Success,'Section updated successfully' AS Message; 
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success,'Failed to update section: ' + ERROR_MESSAGE() AS Message,NULL AS UpdatedSectionId;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--39 Get Sections by Course
CREATE OR ALTER PROCEDURE sp_GetSectionsByCourse @CourseId INT,@IncludeDeleted BIT = 0
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate course exists
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId AND IsDeleted = 0)
        BEGIN RAISERROR('Course not found or has been deleted', 16, 1);RETURN; END
        -- Get all sections for the course
        SELECT s.Id,s.Title,s.Duration,
            s.NoLessons,s.CourseId, s.CreatedDate,
            -- Calculate total duration of all lessons in this section
            (SELECT SUM(Duration) FROM Lessons WHERE SectionId = s.Id AND IsDeleted = 0) AS ActualDuration,
            -- Count of lessons in this section
            (SELECT COUNT(*) FROM Lessons WHERE SectionId = s.Id AND IsDeleted = 0) AS ActualLessonCount
             FROM Sections s WHERE s.CourseId = @CourseId AND (@IncludeDeleted = 1 OR s.IsDeleted = 0)  
        SELECT 1 AS Success, 'Sections retrieved successfully' AS Message;
    END TRY
    BEGIN CATCH
        SELECT 0 AS Success,'Failed to retrieve sections: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--40 Add Lesson to Section
CREATE OR ALTER PROCEDURE sp_AddLessonToSection
    @SectionId INT,@Title NVARCHAR(255), @Type NVARCHAR(50),@Duration INT,
    @VideoUrl NVARCHAR(MAX) = NULL, @ArticleContent NVARCHAR(MAX) = NULL
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate section exists and isn't deleted
        IF NOT EXISTS (SELECT 1 FROM Sections WHERE Id = @SectionId AND IsDeleted = 0)
        BEGIN RAISERROR('Section not found or has been deleted', 16, 1);RETURN;END
        -- Validate lesson type
        IF @Type NOT IN ('Video', 'Article')
        BEGIN RAISERROR('Invalid lesson type. Must be Video, Article, or Quiz', 16, 1);RETURN; END
        -- Validate content based on type
        IF @Type = 'Video' AND @VideoUrl IS NULL
        BEGIN RAISERROR('Video URL is required for Video lessons', 16, 1);RETURN; END
        IF @Type = 'Article' AND @ArticleContent IS NULL
        BEGIN RAISERROR('Article content is required for Article lessons', 16, 1);RETURN; END
        BEGIN TRANSACTION;
        -- Add the lesson
        INSERT INTO Lessons (Title, Duration, Type, VideoUrl, ArticleContent, SectionId, CreatedDate, IsDeleted)
        VALUES (@Title, @Duration, @Type, @VideoUrl, @ArticleContent, @SectionId, GETDATE(), 0);
        -- Update section duration and lesson count
        UPDATE Sections
        SET Duration = Duration + @Duration,NoLessons = NoLessons + 1,ModifiedDate = GETDATE() WHERE Id = @SectionId;
        COMMIT TRANSACTION;
        SELECT SCOPE_IDENTITY() AS NewLessonId,1 AS Success,'Lesson added successfully' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success,'Failed to add lesson: ' + ERROR_MESSAGE() AS Message,NULL AS NewLessonId;      
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--41 Remove Lesson From Section
CREATE OR ALTER PROCEDURE sp_RemoveLessonFromSection @LessonId INT,@HardDelete BIT = 0
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        DECLARE @SectionId INT, @Duration INT;
        -- Get lesson details and validate existence
        SELECT @SectionId = SectionId, @Duration = Duration 
        FROM Lessons WHERE Id = @LessonId;
        IF @SectionId IS NULL BEGIN RAISERROR('Lesson not found', 16, 1); RETURN; END
        -- Validate not already deleted (for soft delete)
        IF @HardDelete = 0 AND EXISTS (SELECT 1 FROM Lessons WHERE Id = @LessonId AND IsDeleted = 1)
        BEGIN RAISERROR('Lesson is already deleted', 16, 1); RETURN; END
        BEGIN TRANSACTION;
        IF @HardDelete = 1 BEGIN
            -- First delete related progress records
            DELETE FROM Progresses WHERE LessonId = @LessonId;
            -- Then hard delete the lesson
            DELETE FROM Lessons WHERE Id = @LessonId;
            -- Update section stats
            UPDATE Sections SET Duration = Duration - @Duration,NoLessons = NoLessons - 1,
              ModifiedDate = GETDATE() WHERE Id = @SectionId;  
        END
        ELSE BEGIN 
            -- Soft delete the lesson (progress records remain but will need handling)
            UPDATE Lessons SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE Id = @LessonId;
            -- Optionally: Also soft delete related progress records
            UPDATE Progresses SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE LessonId = @LessonId;
        END
        COMMIT TRANSACTION;
        SELECT 
            @LessonId AS LessonId,
            1 AS Success,
            CASE WHEN @HardDelete = 1 
                 THEN 'Lesson and all progress records permanently deleted' 
                 ELSE 'Lesson and progress records marked as deleted' 
            END AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success,'Failed to remove lesson: ' + ERROR_MESSAGE() AS Message,NULL AS LessonId;     
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--42 Get Lessons by Section
CREATE OR ALTER PROCEDURE sp_GetLessonsBySection @SectionId INT,@IncludeDeleted BIT = 0   
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate section exists
        IF NOT EXISTS (SELECT 1 FROM Sections WHERE Id = @SectionId 
			AND (@IncludeDeleted = 1 OR IsDeleted = 0))
        BEGIN RAISERROR('Section not found', 16, 1); RETURN; END
        -- Get lessons with optional progress count
        SELECT 
            l.Id,l.Title,l.Duration,l.Type,
            l.VideoUrl,l.ArticleContent,l.SectionId,
            l.CreatedDate,l.ModifiedDate,l.IsDeleted,
            (SELECT COUNT(*) FROM Progresses p WHERE p.LessonId = l.Id 
			AND p.Status = 'Completed') AS CompletionCount
		FROM Lessons l WHERE l.SectionId = @SectionId AND (@IncludeDeleted = 1 OR l.IsDeleted = 0)
        SELECT 1 AS Success, 'Lessons retrieved successfully' AS Message;
    END TRY
    BEGIN CATCH
        SELECT 0 AS Success, 'Error retrieving lessons: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END
GO
-----------------------------------------------------------------------------------------    
--43 Get Sectionsa and Lessons
CREATE OR ALTER PROCEDURE sp_GetSectionsaAndLessons @CourseId INT, @IncludeDeleted BIT = 0
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate course exists
     IF NOT EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId AND (@IncludeDeleted = 1 OR IsDeleted = 0))
        BEGIN RAISERROR('Course not found or has been deleted', 16, 1); RETURN;END
        -- Create a temporary table to hold our hierarchical results
        CREATE TABLE #Results (
            RowType VARCHAR(10),Id INT,Title NVARCHAR(255),
            Duration INT,[Type] NVARCHAR(50),
            VideoUrl NVARCHAR(MAX),ArticleContent NVARCHAR(MAX),
            SectionId INT,NoLessons INT,CreatedDate DATETIME2(7),
            ModifiedDate DATETIME2(7),IsDeleted BIT,SortOrder INT);        
        -- Insert sections with sort order
        INSERT INTO #Results (RowType, Id, Title, Duration, NoLessons, 
                            CreatedDate, ModifiedDate, IsDeleted, SortOrder)
        SELECT 'Section',s.Id,s.Title,s.Duration,s.NoLessons,s.CreatedDate,s.ModifiedDate,s.IsDeleted,
        ROW_NUMBER() OVER (ORDER BY s.CreatedDate) * 2 - 1  -- Odd numbers for sections    
        FROM Sections s WHERE s.CourseId = @CourseId AND (@IncludeDeleted = 1 OR s.IsDeleted = 0);   
        -- Insert lessons with sort order (right after their section)
        INSERT INTO #Results (RowType, Id, Title, Duration, [Type],VideoUrl, ArticleContent, SectionId, 
         CreatedDate, ModifiedDate, IsDeleted, SortOrder)                               
        SELECT 'Lesson',l.Id,l.Title,l.Duration,l.Type,l.VideoUrl,l.ArticleContent,l.SectionId,
         l.CreatedDate,l.ModifiedDate,l.IsDeleted,   
         (SELECT SortOrder FROM #Results WHERE Id = l.SectionId AND RowType = 'Section') + 1    
          FROM Lessons l JOIN Sections s ON l.SectionId = s.Id
        WHERE s.CourseId = @CourseId AND (@IncludeDeleted = 1 OR l.IsDeleted = 0)
        ORDER BY l.SectionId, l.CreatedDate;
        -- Return the hierarchical results
        SELECT RowType,Id,Title,Duration,[Type],VideoUrl,ArticleContent,SectionId,NoLessons,
            CreatedDate,ModifiedDate,IsDeleted FROM #Results ORDER BY SortOrder;
        DROP TABLE #Results;
        SELECT 1 AS Success, 'Sections and lessons retrieved successfully' AS Message;    
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results;
        SELECT 0 AS Success, 'Error retrieving sections and lessons: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
-- 44. Update lesson progress
CREATE OR ALTER PROCEDURE sp_UpdateLessonProgress @StudentId INT,@LessonId INT,@Status NVARCHAR(20)
AS BEGIN SET NOCOUNT ON;    
    BEGIN TRY
        DECLARE @SectionId INT, @CourseId INT;DECLARE @CurrentStatus NVARCHAR(20);
        DECLARE @TotalLessons INT, @CompletedLessons INT;DECLARE @NewProgress DECIMAL(5,2);
        -- Validate input status
        IF @Status NOT IN ('In Progress', 'Completed')
        BEGIN RAISERROR('Invalid status. Must be "In Progress" or "Completed"', 16, 1);RETURN;END
        -- Get section and course info for the lesson
        SELECT @SectionId = l.SectionId, @CourseId = s.CourseId FROM Lessons l JOIN Sections s 
        ON l.SectionId = s.Id WHERE l.Id = @LessonId;
        IF @CourseId IS NULL
        BEGIN RAISERROR('Lesson not found', 16, 1);RETURN;END
        -- Check if student is enrolled in the course
        IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE StudentId = @StudentId AND CourseId = @CourseId)
        BEGIN RAISERROR('Student is not enrolled in this course', 16, 1);RETURN;END
        BEGIN TRANSACTION;    
        -- Check if progress record already exists
        SELECT @CurrentStatus = Status FROM Progresses 
		WHERE StudentId = @StudentId AND LessonId = @LessonId;
        -- Insert or update progress record
        IF @CurrentStatus IS NULL
        BEGIN INSERT INTO Progresses (StudentId, LessonId, Status, CreatedDate, IsDeleted)
            VALUES (@StudentId, @LessonId, @Status, GETDATE(), 0); END
        
        ELSE IF @CurrentStatus <> @Status BEGIN UPDATE Progresses SET Status = @Status,
         ModifiedDate = GETDATE() WHERE StudentId = @StudentId AND LessonId = @LessonId;END
        -- Calculate new course progress percentage
        SELECT @TotalLessons = SUM(s.NoLessons)FROM Sections s 
		WHERE s.CourseId=@CourseId AND s.IsDeleted=0;
        SELECT @CompletedLessons = COUNT(*)FROM Progresses p JOIN Lessons l ON p.LessonId = l.Id
        JOIN Sections s ON l.SectionId = s.Id WHERE p.StudentId = @StudentId AND s.CourseId = @CourseId
         AND p.Status = 'Completed'AND p.IsDeleted = 0 AND l.IsDeleted = 0 AND s.IsDeleted = 0;        
        -- Calculate progress percentage (rounded to 2 decimal places)
        SET @NewProgress = ROUND((CAST(@CompletedLessons AS DECIMAL) / @TotalLessons) * 100, 2);
        -- Update enrollment progress
        UPDATE Enrollments SET ProgressPercentage = @NewProgress,ModifiedDate = GETDATE()
        WHERE StudentId = @StudentId AND CourseId = @CourseId;
        COMMIT TRANSACTION;    
        SELECT 1 AS Success,'Progress updated successfully' 
		AS Message,@NewProgress AS NewProgressPercentage;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;SELECT 0 AS Success,
        'Error updating progress: ' + ERROR_MESSAGE() AS Message,NULL AS NewProgressPercentage;   
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
-- 45. Get Student Progress
CREATE OR ALTER PROCEDURE sp_GetStudentProgress @StudentId INT,@CourseId INT
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate student enrollment first
        IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE StudentId = @StudentId AND CourseId = @CourseId)
        BEGIN RAISERROR('Student is not enrolled in this course', 16, 1);RETURN;END
        -- Get overall course progress with more details
        SELECT e.ProgressPercentage,e.Status AS EnrollmentStatus,
        e.StartDate,e.CompletionDate,c.Title AS CourseTitle,c.Duration AS CourseDuration,
        (SELECT COUNT(*) FROM Sections WHERE CourseId = @CourseId AND IsDeleted = 0) AS TotalSections,
        (SELECT COUNT(*) FROM Lessons l  JOIN Sections s ON l.SectionId = s.Id 
         WHERE s.CourseId = @CourseId AND l.IsDeleted = 0 AND s.IsDeleted = 0) AS TotalLessons
        FROM Enrollments e JOIN Courses c ON e.CourseId = c.Id WHERE 
             e.StudentId = @StudentId AND e.CourseId = @CourseId;  
        -- Get progress by section with completion percentage
        SELECT s.Id AS SectionId,s.Title AS SectionTitle,s.Duration AS SectionDuration,
         COUNT(l.Id) AS TotalLessons,SUM(CASE WHEN p.Status = 'Completed' THEN 1 ELSE 0 END)    
         AS CompletedLessons,CAST(ROUND(CASE WHEN COUNT(l.Id) > 0    
         THEN (SUM(CASE WHEN p.Status = 'Completed' THEN 1.0 ELSE 0 END) / COUNT(l.Id)) * 100    
         ELSE 0 END, 2) AS DECIMAL(5,2)) AS CompletionPercentage   
        FROM Sections s JOIN  Lessons l ON s.Id = l.SectionId AND l.IsDeleted = 0 LEFT JOIN     
        Progresses p ON l.Id = p.LessonId AND p.StudentId = @StudentId AND p.IsDeleted = 0    
        WHERE s.CourseId = @CourseId AND s.IsDeleted = 0 GROUP BY s.Id, s.Title, s.Duration        
        -- Get detailed lesson progress with more information
        SELECT l.Id AS LessonId,l.Title AS LessonTitle,l.Type AS LessonType,l.Duration AS LessonDuration,  
        s.Id AS SectionId,s.Title AS SectionTitle,p.Status 
         AS ProgressStatus,p.CreatedDate AS ProgressCreatedDate, 
        p.ModifiedDate AS ProgressModifiedDate,CASE WHEN p.Status='Completed' 
        THEN 1 WHEN p.Status IS NOT NULL THEN 0.5   
      ELSE 0 END AS ProgressValue FROM Lessons l JOIN Sections s ON l.SectionId = s.Id AND s.IsDeleted = 0     
        LEFT JOIN Progresses p ON l.Id = p.LessonId AND p.StudentId = @StudentId AND p.IsDeleted = 0
        WHERE s.CourseId = @CourseId AND l.IsDeleted = 0 ORDER BY  s.CreatedDate, l.CreatedDate;
        SELECT 1 AS Success, 'Progress data retrieved successfully' AS Message;
    END TRY
    BEGIN CATCH
        SELECT 0 AS Success, 'Error retrieving progress: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--Q&A Procedures
-- 46. Create a question (ask)
CREATE OR ALTER PROCEDURE sp_CreateQuestion
    @Title NVARCHAR(20),@Content NVARCHAR(MAX),@CourseId INT,@UserId INT 
AS BEGIN
    INSERT INTO Asks (Title, Content, CourseId, UserId, CreatedDate, IsDeleted)
    VALUES (@Title, @Content, @CourseId, @UserId, GETDATE(), 0)
    SELECT SCOPE_IDENTITY() AS NewAskId
END GO
-----------------------------------------------------------------------------------------    
-- 47. Answer a question
CREATE OR ALTER PROCEDURE sp_AnswerQuestion @Content NVARCHAR(MAX),@AskId INT,@UserId INT  
AS BEGIN
    INSERT INTO Answers (Content, AskId, UserId, CreatedDate, IsDeleted)
    VALUES (@Content, @AskId, @UserId, GETDATE(), 0)    
    SELECT SCOPE_IDENTITY() AS NewAnswerId
END GO
-----------------------------------------------------------------------------------------    
-- 48. Get questions for course
CREATE OR ALTER PROCEDURE sp_GetCourseQuestions @CourseId INT  
AS BEGIN
    SELECT a.Id, a.Title, a.Content, a.CreatedDate,
           u.Id AS UserId, u.FirstName + ' ' + u.LastName AS UserName,
           (SELECT COUNT(*) FROM Answers WHERE AskId = a.Id AND IsDeleted = 0) AS AnswerCount
    FROM Asks a JOIN AspNetUsers u ON a.UserId = u.Id    
    WHERE a.CourseId = @CourseId AND a.IsDeleted = 0 ORDER BY a.CreatedDate DESC  
END GO
-----------------------------------------------------------------------------------------    
-- 49. Get answers for question
CREATE OR ALTER PROCEDURE sp_GetQuestionAnswers
    @AskId INT
AS
BEGIN
    SELECT ans.Id, ans.Content, ans.CreatedDate,
           u.Id AS UserId, u.FirstName + ' ' + u.LastName AS UserName,
           i.Title AS InstructorTitle
    FROM Answers ans
    JOIN AspNetUsers u ON ans.UserId = u.Id
    LEFT JOIN Instructors i ON u.Id = i.Id
    WHERE ans.AskId = @AskId AND ans.IsDeleted = 0
    ORDER BY ans.CreatedDate
END
GO
-----------------------------------------------------------------------------------------    
--Quiz Procedures
-- 50. Create quiz for course
CREATE OR ALTER PROCEDURE sp_CreateQuiz @CourseId INT
AS BEGIN
    INSERT INTO Quizzes (CourseId, CreatedDate, IsDeleted)
    VALUES (@CourseId, GETDATE(), 0)
    SELECT SCOPE_IDENTITY() AS NewQuizId
END GO
-----------------------------------------------------------------------------------------    
-- 51. Add question to quiz
CREATE OR ALTER PROCEDURE sp_AddQuizQuestion
    @QuizId INT, @Type NVARCHAR(50), @QuestionTxt NVARCHAR(MAX),
    @ChoiceA NVARCHAR(100) = NULL, @ChoiceB NVARCHAR(100) = NULL,
    @ChoiceC NVARCHAR(100) = NULL, @AnswerTxt NVARCHAR(MAX)
AS BEGIN
    DECLARE @QuestionId INT
    -- Get next question ID for this quiz
    SELECT @QuestionId = ISNULL(MAX(Id), 0) + 1 FROM QuizQuestions WHERE QuizId = @QuizId
    INSERT INTO QuizQuestions (Id, QuizId, Type, QuestionTxt, ChoiceA,
    ChoiceB, ChoiceC, AnswerTxt, CreatedDate, IsDeleted)
    VALUES (@QuestionId, @QuizId, @Type, @QuestionTxt, @ChoiceA,
    @ChoiceB, @ChoiceC, @AnswerTxt, GETDATE(), 0)
END GO
-----------------------------------------------------------------------------------------    
-- 52. Get quiz questions
CREATE OR ALTER PROCEDURE sp_GetQuizQuestions @QuizId INT   
AS BEGIN
    SELECT Id, Type, QuestionTxt, ChoiceA, ChoiceB, ChoiceC FROM QuizQuestions
    WHERE QuizId = @QuizId AND IsDeleted = 0 ORDER BY Id   
END GO
-----------------------------------------------------------------------------------------    
-- 53. Get student quiz grades
CREATE OR ALTER PROCEDURE sp_GetStudentQuizGrades @StudentId INT, @CourseId INT 
AS BEGIN
    SELECT q.Id AS QuizId, sg.Grade, sg.CreatedDate AS GradeDate
    FROM Quizzes q
    LEFT JOIN StudentGrades sg ON q.Id = sg.QuizId AND sg.StudentId = @StudentId
    WHERE q.CourseId = @CourseId AND q.IsDeleted = 0
END GO
-----------------------------------------------------------------------------------------    
--Notification Procedures
-- 54. Create notification
CREATE OR ALTER PROCEDURE sp_CreateNotification @Content NVARCHAR(MAX) 
AS BEGIN
    INSERT INTO Notifications (Content, CreatedDate, IsDeleted)VALUES (@Content, GETDATE(), 0)
    SELECT SCOPE_IDENTITY() AS NewNotificationId
END GO
-----------------------------------------------------------------------------------------    
-- 55. Send notification to user
CREATE OR ALTER PROCEDURE sp_SendNotificationToUser @NotificationId INT,@UserId INT
AS BEGIN
    INSERT INTO ApplicationUserNotification (NotificationsId,UsersId)VALUES (@NotificationId,@UserId)
END GO
-----------------------------------------------------------------------------------------    
-- 56. Get user notifications
CREATE OR ALTER PROCEDURE sp_GetUserNotifications @UserId INT,@Count INT = 10
AS BEGIN
    SELECT TOP (@Count) n.Id, n.Content, n.CreatedDate FROM Notifications n
    JOIN ApplicationUserNotification aun ON n.Id = aun.NotificationsId
    WHERE aun.UsersId = @UserId AND n.IsDeleted = 0
END GO
-----------------------------------------------------------------------------------------    
--Instructor and Student Procedures
-- 57. Become an instructor
CREATE OR ALTER PROCEDURE sp_BecomeInstructor 
@UserId INT,@Title NVARCHAR(255)=NULL,@Bio NVARCHAR(MAX)= NULL
AS BEGIN
    -- First make sure user isn't already an instructor
    IF NOT EXISTS (SELECT 1 FROM Instructors WHERE Id = @UserId)
        BEGIN INSERT INTO Instructors (Id, Title, Bio, TotalCourses, TotalReviews, TotalStudents, Wallet)
        VALUES (@UserId, @Title, @Bio, 0, 0, 0, 0) END
END GO
-----------------------------------------------------------------------------------------    
-- 58. Update instructor profile
CREATE OR ALTER PROCEDURE sp_UpdateInstructorProfile @InstructorId INT,@Title NVARCHAR(255), @Bio NVARCHAR(MAX)
AS BEGIN
    UPDATE Instructors SET Title = @Title,Bio = @Bio WHERE Id = @InstructorId
END GO
-----------------------------------------------------------------------------------------    
-- 59. Get Instructor Stats
CREATE or ALTER PROCEDURE sp_GetInstructorStats @InstructorId INT
AS BEGIN
    SELECT 
        i.Id , i.Title , i.Bio ,i.Wallet, i.TotalReviews,
        u.FirstName + ' ' + u.LastName AS FullName,u.Email,u.CountryName,
        (SELECT COUNT(*) FROM Courses WHERE InstructorId = @InstructorId AND IsDeleted = 0)
         AS TotalCourse,
        (SELECT SUM(NoSubscribers) FROM Courses WHERE InstructorId = @InstructorId AND IsDeleted = 0)
         AS TotalStudents,
        (SELECT AVG(Rating) FROM Courses WHERE InstructorId = @InstructorId AND IsDeleted = 0)
         AS AverageRating
    FROM Instructors i JOIN AspNetUsers u ON i.Id = u.Id WHERE i.Id = @InstructorId 
END GO
-----------------------------------------------------------------------------------------
-- 60. Update Student profile
CREATE OR ALTER PROCEDURE sp_UpdateStudentProfile @InstructorId INT,@Title NVARCHAR(255), @Bio NVARCHAR(MAX)
AS BEGIN
    UPDATE Students SET Title = @Title,Bio = @Bio WHERE Id = @InstructorId
END GO
-----------------------------------------------------------------------------------------
-- 61. Get Student Stats
CREATE OR ALTER PROCEDURE sp_GetStudentStats  @StudentId INT 
AS BEGIN
    SELECT 
        s.Id, s.Title, s.Bio, s.Wallet,u.FirstName + ' ' + u.LastName AS FullName,
        u.Email, u.CountryName, u.CreatedDate AS JoinDate,
        (SELECT COUNT(*) FROM Enrollments WHERE StudentId = @StudentId) AS TotalEnrollments,
        (SELECT COUNT(*) FROM Enrollments WHERE StudentId = @StudentId AND Status = 'Completed')
         AS CompletedCourses,
        (SELECT AVG(Rating) FROM Enrollments WHERE StudentId = @StudentId AND Rating IS NOT NULL)
         AS AvgCourseRating,
        (SELECT SUM(c.Duration) FROM Enrollments e JOIN Courses c ON e.CourseId =c.Id 
         WHERE e.StudentId = @StudentId) AS TotalLearningHours,
        (SELECT COUNT(*) FROM Progresses WHERE StudentId = @StudentId AND Status = 'Completed')
         AS LessonsCompleted 
    FROM Students s  JOIN AspNetUsers u ON s.Id = u.Id WHERE s.Id = @StudentId 
END GO    
-----------------------------------------------------------------------------------------    
--Admin and Reporting Procedures
-- 62. Get all users with roles
CREATE OR ALTER PROCEDURE sp_GetAllUsersWithRoles
AS BEGIN
    SELECT u.Id,u.FirstName + ' ' + u.LastName AS FullName,
    u.Email, u.CreatedDate,STRING_AGG(r.Name, ', ') AS Roles FROM AspNetUsers u
    LEFT JOIN AspNetUserRoles ur ON u.Id = ur.UserId LEFT JOIN AspNetRoles r ON ur.RoleId = r.Id
    WHERE u.IsDeleted = 0 GROUP BY u.Id, u.FirstName, u.LastName, u.Email, u.CreatedDate
END GO
-----------------------------------------------------------------------------------------    
-- 63. Get Sales Report
CREATE OR ALTER PROCEDURE sp_GetSalesReport
    @StartDate DATETIME2 = NULL,@EndDate DATETIME2 = NULL,    
    @InstructorId INT = NULL, @CourseId INT = NULL    
AS BEGIN
    -- Set default date range (last 30 days if not specified)
    IF @StartDate IS NULL SET @StartDate = DATEADD(day, -30, GETDATE())
    IF @EndDate IS NULL SET @EndDate = GETDATE()    
    -- Main sales report query
    SELECT  o.Id AS OrderId, u.FirstName + ' ' + u.LastName AS StudentName, u.Email AS StudentEmail,                       
        COUNT(c.Id) AS CourseCount, SUM(co.OrderPrice) AS OrderTotal, o.PaymentMethod,    
        o.CreatedDate AS OrderDate,SUM(c.Price) AS OriginalTotal,(SUM(c.Price) - SUM(co.OrderPrice)) AS DiscountAmount,
        STRING_AGG(c.Title, ', ') AS Courses,STRING_AGG(i.FirstName + ' ' + i.LastName, ', ') AS Instructors        
    FROM Orders o  JOIN AspNetUsers u ON o.StudentId = u.Id 
   JOIN CourseOrder co ON o.Id = co.OrderId  JOIN Courses c ON co.CourseId = c.Id 
   JOIN Instructors ins ON c.InstructorId = ins.Id JOIN AspNetUsers i ON ins.Id = i.Id 
    WHERE o.CreatedDate BETWEEN @StartDate AND @EndDate AND o.IsDeleted = 0    
      AND (@InstructorId IS NULL OR c.InstructorId = @InstructorId) AND (@CourseId IS NULL OR c.Id = @CourseId)     
    GROUP BY o.Id, u.FirstName, u.LastName, u.Email, o.PaymentMethod, o.CreatedDate    
    -- Additional summary statistics
    SELECT
        COUNT(DISTINCT o.Id) AS TotalOrders, COUNT(DISTINCT o.StudentId) AS UniqueStudents,       
        SUM(co.OrderPrice) AS GrossRevenue, AVG(co.OrderPrice) AS AverageOrderValue,        
        MIN(o.CreatedDate) AS FirstOrderDate, MAX(o.CreatedDate) AS LastOrderDate,       
        SUM(c.Price) AS PotentialRevenue, (SUM(c.Price) - SUM(co.OrderPrice)) AS TotalDiscountsGiven       
    FROM Orders o  JOIN CourseOrder co ON o.Id = co.OrderId JOIN Courses c ON co.CourseId = c.Id
    WHERE o.CreatedDate BETWEEN @StartDate AND @EndDate AND o.IsDeleted = 0  AND (@InstructorId IS NULL OR c.InstructorId = @InstructorId)  
    AND (@CourseId IS NULL OR EXISTS ( SELECT 1 FROM CourseOrder co  WHERE co.OrderId = o.Id AND co.CourseId = @CourseId  ))     
END GO
-----------------------------------------------------------------------------------------
-- 64. Get enrollment trends
CREATE OR ALTER PROCEDURE sp_GetEnrollmentTrends
    @Period NVARCHAR(10) = 'month', -- 'day', 'week', 'month', 'year'
    @StartDate DATE = NULL, @EndDate DATE = NULL,@CourseId INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    -- Set default date range (last 12 months if not specified)
    IF @StartDate IS NULL SET @StartDate = DATEADD(year, -1, GETDATE())
    IF @EndDate IS NULL SET @EndDate = GETDATE()  
    -- Validate period parameter
    IF @Period NOT IN ('day', 'week', 'month', 'year')
    BEGIN
        RAISERROR('Invalid period. Must be ''day'', ''week'', ''month'', or ''year''', 16, 1)RETURN
    END
    DECLARE @SQL NVARCHAR(MAX)SET @SQL = N'SELECT' + CASE 
         WHEN @Period = 'day' THEN 'CONVERT(date, e.CreatedDate) AS PeriodDate' WHEN @Period = 'week' THEN
         'DATEFROMPARTS(DATEPART(year, e.CreatedDate), DATEPART(month, e.CreatedDate), 
         DATEPART(day, DATEADD(day, 1-DATEPART(weekday, e.CreatedDate), e.CreatedDate)) AS WeekStartDate'
            WHEN @Period = 'month' THEN 
                'DATEFROMPARTS(YEAR(e.CreatedDate), MONTH(e.CreatedDate), 1) AS MonthStartDate'
            ELSE 'DATEFROMPARTS(YEAR(e.CreatedDate), 1, 1) AS YearStartDate'
        END + ',COUNT(*) AS EnrollmentCount,COUNT(DISTINCT e.StudentId) AS UniqueStudents,'+
           CASE WHEN @CourseId IS NULL THEN 
        'COUNT(DISTINCT e.CourseId) AS UniqueCourses' ELSE '1 AS UniqueCourses' END + '
        FROM Enrollments e  WHERE e.IsDeleted = 0 AND e.CreatedDate BETWEEN @StartDate AND @EndDate' +
        CASE WHEN @CourseId IS NOT NULL THEN 'AND e.CourseId = @CourseId' ELSE '' END + '    
        GROUP BY ' + CASE WHEN @Period = 'day' THEN 'CONVERT(date, e.CreatedDate)'
        WHEN @Period = 'week' THEN 'DATEPART(year, e.CreatedDate), DATEPART(week, e.CreatedDate)'
        WHEN @Period = 'month' THEN 'YEAR(e.CreatedDate), MONTH(e.CreatedDate)'
        ELSE 'YEAR(e.CreatedDate)'END + 'ORDER BY ' + CASE 
        WHEN @Period = 'day' THEN 'PeriodDate'WHEN @Period = 'week' THEN 'WeekStartDate'
        WHEN @Period = 'month' THEN 'MonthStartDate'ELSE 'YearStartDate'
END EXEC sp_executesql @SQL, N'@StartDate DATE, @EndDate DATE, @CourseId INT',@StartDate, @EndDate, @CourseId
END GO
-----------------------------------------------------------------------------------------    
--Additional Course Rating Procedures
-- 65. Get course reviews and ratings
CREATE OR ALTER PROCEDURE sp_GetCourseReviews @CourseId INT
AS BEGIN
    SELECT u.FirstName + ' ' + u.LastName AS StudentName,
	e.Rating,e.comment,e.ModifiedDate AS ReviewDate
    FROM Enrollments e JOIN AspNetUsers u ON e.StudentId = u.Id
    WHERE e.CourseId = @CourseId AND e.Rating IS NOT NULL AND e.IsDeleted = 0
END GO
-----------------------------------------------------------------------------------------
-- 66. Update course rating
CREATE OR ALTER PROCEDURE sp_UpdateCourseRating @CourseId INT,@StudentId INT,
                 @Rating DECIMAL(2,1),@Comment NVARCHAR(255) = NULL 
AS BEGIN
    UPDATE Enrollments SET Rating = @Rating,comment = @Comment, ModifiedDate = GETDATE()     
    WHERE CourseId = @CourseId AND StudentId = @StudentId
    -- Recalculate average rating for the course
    DECLARE @AvgRating DECIMAL(2,1)
    SELECT @AvgRating = AVG(Rating)FROM Enrollments WHERE CourseId = @CourseId AND Rating IS NOT NULL
    UPDATE Courses SET Rating = @AvgRating, ModifiedDate = GETDATE()
    WHERE Id = @CourseId
END GO  
-----------------------------------------------------------------------------------------    
---Social Features Procedures
-- 67. Add Social Media Link
CREATE OR ALTER PROCEDURE sp_AddSocialMediaLink @UserId INT,@Link NVARCHAR(MAX)
AS BEGIN
    SET NOCOUNT ON; 
    BEGIN TRY
        DECLARE @Name NVARCHAR(20);DECLARE @ExistingId INT;
        -- Extract social media name from link
        SET @Name = CASE WHEN @Link LIKE '%twitter.com%' OR @Link LIKE '%x.com%' THEN 'X'
            WHEN @Link LIKE '%linkedin.com%' OR @Link LIKE '%linked.in%' THEN 'LinkedIn'
            WHEN @Link LIKE '%facebook.com%' OR @Link LIKE '%fb.com%' THEN 'Facebook'
            WHEN @Link LIKE '%instagram.com%' OR @Link LIKE '%instagr.am%' THEN 'Instagram'
            ELSE NULL END;
        -- Validate we detected a supported platform
        IF @Name IS NULL
        BEGIN
         RAISERROR('Unsupported social media platform. Only LinkedIn, Facebook, X,
          and Instagram are allowed.', 16, 1);
            RETURN;END
        -- Check if user already has this social media type
        SELECT @ExistingId = Id FROM SocialMedias WHERE UserId = @UserId AND Name = @Name AND IsDeleted=0;
        BEGIN TRANSACTION;
        IF @ExistingId IS NOT NULL BEGIN
            -- Update existing record
          UPDATE SocialMedias SET Link = @Link, ModifiedDate = GETDATE(), IsDeleted = 0
          WHERE Id = @ExistingId AND UserId = @UserId;
          SELECT @ExistingId AS SocialMediaId, 1 AS Success,
          'Social media link updated successfully' AS Message;   
        END
        ELSE
        BEGIN DECLARE @NewId INT;
            -- Insert new record
            SELECT @NewId = ISNULL(MAX(Id), 0) + 1 FROM SocialMedias WHERE UserId = @UserId;
            INSERT INTO SocialMedias (Id, UserId, Name, Link, CreatedDate, IsDeleted)
            VALUES (@NewId, @UserId, @Name, @Link, GETDATE(), 0);
            
        SELECT SCOPE_IDENTITY() AS SocialMediaId, 1 AS Success,
       'Social media link added successfully' AS Message; END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success,'Error: ' + ERROR_MESSAGE() AS Message,NULL AS SocialMediaId;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
-- 68. Get user social media links
CREATE OR ALTER PROCEDURE sp_GetUserSocialMedia @UserId INT
AS BEGIN
    SELECT Name, Link FROM SocialMedias WHERE UserId = @UserId AND IsDeleted = 0
END GO 
-----------------------------------------------------------------------------------------    
--Instructor Payment Procedures
-- 69. Get instructor earnings report
CREATE OR ALTER PROCEDURE sp_GetInstructorEarnings @InstructorId INT, @StartDate DATETIME2 = NULL,@EndDate DATETIME2 = NULL 
AS BEGIN
    IF @StartDate IS NULL SET @StartDate = DATEADD(month, -1, GETDATE())
    IF @EndDate IS NULL SET @EndDate = GETDATE()
    SELECT c.Id AS CourseId,c.Title AS CourseTitle,COUNT(e.StudentId) AS Enrollments,
       SUM(c.CurrentPrice) AS GrossRevenue,SUM(c.CurrentPrice) * 0.7 AS InstructorEarnings 
    FROM Courses c JOIN Enrollments e ON c.Id = e.CourseId    
    WHERE c.InstructorId = @InstructorId AND e.CreatedDate BETWEEN @StartDate AND @EndDate   
    AND e.IsDeleted = 0 GROUP BY c.Id, c.Title ORDER BY InstructorEarnings DESC
END GO
-----------------------------------------------------------------------------------------    
--System Maintenance Procedures
-- 70. Clean up soft-deleted records
CREATE OR ALTER PROCEDURE sp_CleanupDeletedRecords @DaysOld INT = 30
AS BEGIN
    -- Clean up soft-deleted records older than @DaysOld days
    DECLARE @CutoffDate DATETIME2 = DATEADD(day, -@DaysOld, GETDATE())
    -- Example for one table - repeat for others as needed
    DELETE FROM Answers WHERE IsDeleted = 1 AND ModifiedDate < @CutoffDate
    DELETE FROM Asks WHERE IsDeleted = 1 AND ModifiedDate < @CutoffDate
    -- Add similar statements for other tables
    SELECT @@ROWCOUNT AS RecordsDeleted
END GO
-----------------------------------------------------------------------------------------
-- 71. Recalculate course ratings
CREATE OR ALTER PROCEDURE sp_RecalculateAllCourseRatings
AS BEGIN
    UPDATE c SET c.Rating = sub.AvgRating,c.ModifiedDate = GETDATE()FROM Courses c
    JOIN (SELECT CourseId, AVG(CAST(Rating AS DECIMAL(2,1))) AS AvgRating
        FROM Enrollments WHERE Rating IS NOT NULL GROUP BY CourseId)
        sub ON c.Id = sub.CourseId
END GO
-----------------------------------------------------------------------------------------    
--Soft Delete for Answers, Ask and Notifications
--72. Soft Delete Answer
CREATE OR ALTER PROCEDURE sp_SoftDeleteAnswer @Id INT    
AS BEGIN UPDATE Answers SET IsDeleted = 1,ModifiedDate = GETDATE()WHERE Id = @Id END GO
-----------------------------------------------------------------------------------------
--73. Soft Delete Ask
CREATE OR ALTER PROCEDURE sp_SoftDeleteAsk @Id INT
AS BEGIN UPDATE Asks SET IsDeleted = 1,ModifiedDate = GETDATE()WHERE Id = @Id END GO
-----------------------------------------------------------------------------------------
--74. Delete from Notification
CREATE OR ALTER PROCEDURE sp_DeleteNotification @Id INT,@HardDelete BIT = 0,@ForceDelete BIT = 0 
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @IsCurrentlyDeleted BIT;
        -- Check if notification exists and get current deletion status
        SELECT @IsCurrentlyDeleted = IsDeleted FROM Notifications WHERE Id = @Id;
        -- Validate notification exists
        IF @IsCurrentlyDeleted IS NULL AND @ForceDelete = 0
        BEGIN RAISERROR('Notification not found', 16, 1); RETURN;END
        -- Check if already soft-deleted
        IF @HardDelete = 0 AND @IsCurrentlyDeleted = 1 AND @ForceDelete = 0
        BEGIN RAISERROR('Notification is already deleted', 16, 1);RETURN; END
        BEGIN TRANSACTION;    
        IF @HardDelete = 1
        BEGIN

            -- First delete from junction table if exists
            IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ApplicationUserNotification')
            BEGIN DELETE FROM ApplicationUserNotification WHERE NotificationsId = @Id;END 
            -- Then hard delete the notification
            DELETE FROM Notifications  WHERE Id = @Id;    
            SELECT @Id AS NotificationId, 1 AS Success, 'Notification permanently deleted' AS Message;    
        END
        ELSE BEGIN
            -- Soft delete the notification
            UPDATE Notifications SET IsDeleted = 1,ModifiedDate = GETDATE()WHERE Id = @Id;            
            SELECT @Id AS NotificationId, 1 AS Success, 'Notification marked as deleted' AS Message;
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success,'Error deleting notification: ' + ERROR_MESSAGE() AS Message,    
        NULL AS NotificationId;    
    END CATCH
END GO
-----------------------------------------------------------------------------------------
--75. Delete from ApplicationUserNotification
CREATE OR ALTER PROCEDURE sp_SoftDeleteUserNotification @NotificationsId INT,@UsersId INT
AS BEGIN
   DELETE FROM ApplicationUserNotification WHERE NotificationsId = @NotificationsId AND UsersId = @UsersId
END GO
-----------------------------------------------------------------------------------------
--Delete Course Requirement and Course Goal    
--76. Delete from Course Requirement
CREATE OR ALTER PROCEDURE sp_DeleteCourseRequirement @Requirement NVARCHAR(255),@CourseId INT,
    @HardDelete BIT = 0,@ExactMatch BIT = 1
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate course exists and isn't deleted
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId AND IsDeleted = 0)
        BEGIN
            SELECT 0 AS Success, 'Course not found or is deleted' AS Message;RETURN;
        END
        -- Check if requirement exists
        IF NOT EXISTS (SELECT 1 FROM CourseRequirements WHERE CourseId = @CourseId 
         AND (@ExactMatch = 1 AND Requirement = @Requirement OR  @ExactMatch = 0   
         AND Requirement LIKE '%' + @Requirement + '%') AND IsDeleted = 0)
        BEGIN
            SELECT 0 AS Success, 'Requirement not found for this course' AS Message; RETURN;
        END
        BEGIN TRANSACTION;
        IF @HardDelete = 1 BEGIN 
            -- Hard delete the requirement(s)
            DELETE FROM CourseRequirements WHERE CourseId = @CourseId
            AND (@ExactMatch = 1 AND Requirement = @Requirement OR 
                 @ExactMatch = 0 AND Requirement LIKE '%' + @Requirement + '%');
            SELECT 1 AS Success,CASE WHEN @ExactMatch = 1 THEN 'Requirement permanently deleted' 
            ELSE 'Matching requirements permanently deleted' END AS Message;END
        ELSE BEGIN
            -- Soft delete the requirement(s)
            UPDATE CourseRequirements SET IsDeleted = 1,ModifiedDate = GETDATE()WHERE CourseId = @CourseId
            AND (@ExactMatch = 1 AND Requirement = @Requirement OR @ExactMatch = 0 
            AND Requirement LIKE '%' + @Requirement + '%')AND IsDeleted = 0;
            SELECT 1 AS Success,CASE WHEN @ExactMatch = 1 THEN 'Requirement marked as deleted' 
            ELSE 'Matching requirements marked as deleted' END AS Message;      
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 'Error deleting requirement: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    
--77. Delete from Course Goal
CREATE OR ALTER PROCEDURE sp_DeleteCourseGoal @Goal NVARCHAR(255),@CourseId INT,
    @HardDelete BIT = 0,@ExactMatch BIT = 1
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate course exists and isn't deleted
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId AND IsDeleted = 0)
        BEGIN
            SELECT 0 AS Success, 'Course not found or is deleted' AS Message;RETURN;
        END
        -- Check if goal exists
        IF NOT EXISTS (SELECT 1 FROM CourseGoals WHERE CourseId = @CourseId 
         AND (@ExactMatch = 1 AND Goal = @Goal OR @ExactMatch = 0   
         AND Goal LIKE '%' + @Goal + '%') AND IsDeleted = 0)
        BEGIN
            SELECT 0 AS Success, 'Goal not found for this course' AS Message;RETURN;
        END
        BEGIN TRANSACTION;
        IF @HardDelete = 1 BEGIN 
            -- Hard delete the goal(s)
            DELETE FROM CourseGoals WHERE CourseId = @CourseId
            AND (@ExactMatch = 1 AND Goal = @Goal OR 
                 @ExactMatch = 0 AND Goal LIKE '%' + @Goal + '%');
            
            SELECT 1 AS Success,CASE WHEN @ExactMatch = 1 THEN 'Goal permanently deleted' 
            ELSE 'Matching goals permanently deleted' END AS Message;END
        ELSE BEGIN
            -- Soft delete the goal(s)
            UPDATE CourseGoals SET IsDeleted = 1,ModifiedDate = GETDATE()WHERE CourseId = @CourseId
            AND (@ExactMatch = 1 AND Goal = @Goal OR @ExactMatch = 0 
            AND Goal LIKE '%' + @Goal + '%')AND IsDeleted = 0;
            SELECT 1 AS Success,CASE WHEN @ExactMatch = 1 THEN 'Goal marked as deleted' 
            ELSE 'Matching goals marked as deleted' END AS Message;      
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 'Error deleting goal: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO 
-----------------------------------------------------------------------------------------    
--Soft Delete Stored Procedure
--78. Soft Delete for CourseOrder
CREATE OR ALTER PROCEDURE sp_DeleteCourseOrder  @OrderId INT, @CourseId INT, @HardDelete BIT = 1  
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate order exists and isn't deleted
        IF NOT EXISTS (SELECT 1 FROM Orders WHERE Id = @OrderId AND IsDeleted = 0)
        BEGIN  SELECT 0 AS Success, 'Order not found or is deleted' AS Message; RETURN;END
        -- Validate course exists and isn't deleted
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Id = @CourseId AND IsDeleted = 0)
        BEGIN SELECT 0 AS Success, 'Course not found or is deleted' AS Message;RETURN;END 
        -- Validate course-order relationship exists
        IF NOT EXISTS (SELECT 1 FROM CourseOrder WHERE OrderId = @OrderId AND CourseId = @CourseId)
        BEGIN SELECT 0 AS Success, 'Course not found in this order' AS Message;RETURN; END
        DECLARE @CoursePrice DECIMAL(8,2), @OriginalPrice DECIMAL(8,2), @NewDiscount DECIMAL(8,2);
        DECLARE @OrderPrice DECIMAL(8,2);        
        -- Get course pricing and order price
        SELECT @CoursePrice = CurrentPrice, @OriginalPrice = Price  FROM Courses WHERE Id = @CourseId;               
        SELECT @OrderPrice = OrderPrice FROM CourseOrder WHERE OrderId = @OrderId AND CourseId = @CourseId;       
        -- Calculate new discount percentage
        SET @NewDiscount = CASE WHEN @OriginalPrice > 0 
            THEN ((@OriginalPrice - @CoursePrice)/@OriginalPrice)*100  ELSE 0  END;           
        BEGIN TRANSACTION;        
        IF @HardDelete = 1 BEGIN        
          -- 1. Remove course from order
          DELETE FROM CourseOrder WHERE OrderId = @OrderId AND CourseId = @CourseId;            
          -- 2. Update order total (subtract the actual order price)
          UPDATE Orders SET TotalAmount = TotalAmount - @OrderPrice,ModifiedDate = GETDATE() WHERE Id = @OrderId;  
          -- 3. Update course discount
          UPDATE Courses SET Discount = @NewDiscount,ModifiedDate = GETDATE() WHERE Id = @CourseId;  
            SELECT 1 AS Success, 'Course removed and pricing updated' AS Message;END    
        ELSE BEGIN       
          SELECT 1 AS Success, 'Soft delete not supported for course-order relationships' AS Message; END               
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0  ROLLBACK TRANSACTION;     
        SELECT 0 AS Success, 'Error deleting course from order: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------
--79. Soft Delete for Quizzes
CREATE OR ALTER PROCEDURE sp_SoftDeleteQuiz @Id INT 
AS BEGIN
    UPDATE Quizzes SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE Id = @Id;
	UPDATE QuizQuestions SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE @Id = QuizId;
END GO
-----------------------------------------------------------------------------------------
--80. Soft Delete for QuizQuestions
CREATE OR ALTER PROCEDURE sp_SoftDeleteQuizQuestion @Id INT, @QuizId INT
AS BEGIN
 UPDATE QuizQuestions SET IsDeleted = 1,ModifiedDate = GETDATE()WHERE Id = @Id 
AND QuizId = @QuizId
END GO
-----------------------------------------------------------------------------------------
--81. Soft Delete for StudentGrades
CREATE OR ALTER PROCEDURE sp_SoftDeleteStudentGrade @StudentId INT, @QuizId INT
AS BEGIN
    UPDATE StudentGrades SET IsDeleted = 1,ModifiedDate = GETDATE()
    WHERE StudentId = @StudentId AND QuizId = @QuizId
END GO
-----------------------------------------------------------------------------------------
--82. Soft Delete for Social Media
CREATE OR ALTER PROCEDURE sp_SoftDeleteSocialMedia @UserId INT,@SocialMedia NVARCHAR(60)
AS BEGIN
  UPDATE SocialMedias SET IsDeleted = 1,ModifiedDate = GETDATE()
  WHERE Name = @SocialMedia AND UserId = @UserId
END GO
-----------------------------------------------------------------------------------------
--83. Soft Delete for Progress
CREATE OR ALTER PROCEDURE sp_DeleteProgress @Id INT,@HardDelete BIT = 0
AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @StudentId INT, @LessonId INT, @CourseId INT;
        -- Get progress details
        SELECT @StudentId = StudentId, @LessonId = LessonId FROM Progresses WHERE Id = @Id; 
        -- Validate progress exists
        IF @StudentId IS NULL BEGIN SELECT 0 AS Success, 'Progress record not found' AS Message;RETURN;END
        -- Get course ID from lesson
        SELECT @CourseId = c.Id FROM Lessons l JOIN Sections s ON l.SectionId = s.Id
        JOIN Courses c ON s.CourseId = c.Id WHERE l.Id = @LessonId;
        BEGIN TRANSACTION;
        -- Hard delete progress
        IF @HardDelete = 1 BEGIN DELETE FROM Progresses WHERE Id = @Id; END ELSE BEGIN
        -- Soft delete progress    
        UPDATE Progresses SET IsDeleted = 1,ModifiedDate = GETDATE() WHERE Id = @Id;END    
        -- Update enrollment progress percentage
        DECLARE @TotalLessons INT, @CompletedLessons INT, @NewProgress DECIMAL(5,2);
        -- Count total lessons in course
        SELECT @TotalLessons = COUNT(*) FROM Lessons l JOIN Sections s ON l.SectionId = s.Id
        WHERE s.CourseId = @CourseId AND l.IsDeleted = 0 AND s.IsDeleted = 0;
        -- Count completed lessons for student
        SELECT @CompletedLessons = COUNT(*)
        FROM Progresses p
        JOIN Lessons l ON p.LessonId = l.Id JOIN Sections s ON l.SectionId = s.Id 
        WHERE p.StudentId = @StudentId AND s.CourseId = @CourseId AND p.Status = 'Completed'
        AND p.IsDeleted = 0 AND l.IsDeleted = 0 AND s.IsDeleted = 0;        
        -- Calculate new progress percentage
        SET @NewProgress = CASE WHEN @TotalLessons > 0 
            THEN ROUND((@CompletedLessons * 100.0 / @TotalLessons), 2) ELSE 0 END;
        -- Update enrollment
        UPDATE Enrollments SET ProgressPercentage = @NewProgress,ModifiedDate = GETDATE()    
        WHERE StudentId = @StudentId AND CourseId = @CourseId;
        COMMIT TRANSACTION;
        SELECT 1 AS Success, 'Progress updated successfully' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 0 AS Success, 'Error updating progress: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------
--84. Delete from Students
CREATE OR ALTER PROCEDURE sp_DeleteStudent @Id INT,@HardDelete BIT = 0   
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate student exists
        IF NOT EXISTS (SELECT 1 FROM Students WHERE Id = @Id)
        BEGIN SELECT 0 AS Success, 'Student not found' AS Message;RETURN;END
        -- Check if already soft-deleted
        IF @HardDelete = 0 AND EXISTS (SELECT 1 FROM Students WHERE Id = @Id)
        BEGIN SELECT 0 AS Success, 'Student is already deleted' AS Message;RETURN;END
        BEGIN TRANSACTION;        
        IF @HardDelete = 1 BEGIN
            -- Hard delete all related records
            DELETE FROM Progresses WHERE StudentId = @Id;
            DELETE FROM Enrollments WHERE StudentId = @Id;
            DELETE FROM CartCourse WHERE CartId IN (SELECT Id FROM Carts WHERE StudentId = @Id);
            DELETE FROM Carts WHERE StudentId = @Id;
            DELETE FROM StudentGrades WHERE StudentId = @Id; 
            -- Finally hard delete the student
            DELETE FROM Students WHERE Id = @Id;      
            -- Also delete from AspNetUsers
            DELETE FROM AspNetUsers WHERE Id = @Id;
            SELECT 1 AS Success, 'Student and all related data permanently deleted' AS Message;END 
        ELSE
        BEGIN
            -- Soft delete related records
            UPDATE Enrollments SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE StudentId = @Id;
            UPDATE Carts SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE StudentId = @Id;
            SELECT 1 AS Success, 'Student marked as deleted' AS Message;END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;  
        SELECT 0 AS Success, 'Error deleting student: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------
--85. Delete from Instructors
CREATE OR ALTER PROCEDURE sp_DeleteInstructor @Id INT, @HardDelete BIT = 0 
AS BEGIN
    SET NOCOUNT ON;    
    BEGIN TRY
        -- Validate instructor exists
        IF NOT EXISTS (SELECT 1 FROM Instructors WHERE Id = @Id)
        BEGIN SELECT 0 AS Success, 'Instructor not found' AS Message; RETURN;END
        -- Check if already soft-deleted
        IF @HardDelete = 0 AND EXISTS (SELECT 1 FROM Instructors WHERE Id = @Id)
        BEGIN SELECT 0 AS Success, 'Instructor is already deleted' AS Message;RETURN;END
        BEGIN TRANSACTION;
        IF @HardDelete = 1 BEGIN
            -- Hard delete all related records
         DELETE FROM CourseGoals WHERE CourseId IN (SELECT Id FROM Courses WHERE InstructorId = @Id);
         DELETE FROM CourseRequirements WHERE CourseId IN(SELECT Id FROM Courses WHERE InstructorId= @Id);
         DELETE FROM Sections WHERE CourseId IN (SELECT Id FROM Courses WHERE InstructorId = @Id);
         DELETE FROM Quizzes WHERE CourseId IN (SELECT Id FROM Courses WHERE InstructorId = @Id);
         DELETE FROM Courses WHERE InstructorId = @Id; 
         -- Finally hard delete the instructor
         DELETE FROM Instructors WHERE Id = @Id; 
         -- Also delete from AspNetUsers
         DELETE FROM AspNetUsers WHERE Id = @Id;
            SELECT 1 AS Success, 'Instructor and all related data permanently deleted' 
            AS Message;END
        ELSE BEGIN           
            -- Soft delete related courses
            UPDATE Courses SET IsDeleted = 1, ModifiedDate = GETDATE() WHERE InstructorId = @Id;            
            SELECT 1 AS Success, 'Instructor marked as deleted' AS Message;
        END        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;                     
        SELECT 0 AS Success, 'Error deleting instructor: ' + ERROR_MESSAGE() AS Message;
    END CATCH
END GO
-----------------------------------------------------------------------------------------    