-- Create StudentInstructor view
CREATE VIEW [dbo].[StudentInstructor] AS
SELECT Id, Title, Bio, Wallet FROM [dbo].[Students]
UNION
SELECT Id, Title, Bio, Wallet FROM [dbo].[Instructors];

-- Verify the StudentInstructor view
SELECT * FROM [dbo].[StudentInstructor];

-- Create HasSocialMedia view
create VIEW [dbo].[HasSocialMedia] AS
WITH SocialMediaPivot AS (
    SELECT UserId, Name AS SocialmediaName, 1 AS Presence
    FROM [dbo].[SocialMedias]
    WHERE IsDeleted = 0
)
SELECT Id,
       ISNULL(Facebook, 0) AS HasFacebook,
       ISNULL(Linkedin, 0) AS HasLinkedin,
       ISNULL(X, 0) AS HasX,
       ISNULL(Instegram, 0) AS HasInstegram
FROM SocialMediaPivot
PIVOT (
    MAX(Presence)
    FOR SocialmediaName IN ([Facebook], [Linkedin], [X], [Instegram])
) AS PivotTable right join AspNetUsers u on u.id = UserId;

-- Verify the HasSocialMedia view
SELECT * FROM [dbo].[HasSocialMedia];

-- Create IsRole view
CREATE VIEW [dbo].[IsRole] AS
WITH RolePivot AS (
    SELECT ur.UserId, r.[Name] AS SocialmediaName, 1 AS Presence
    FROM [dbo].[AspNetUserRoles] ur
    JOIN [dbo].[AspNetRoles] r ON r.Id = ur.RoleId
)
SELECT UserId,
       ISNULL(Student, 0) AS IsStudent,
       ISNULL(Instructor, 0) AS IsInstructor,
       ISNULL(Admin, 0) AS IsAdmin
FROM RolePivot
PIVOT (
    MAX(Presence)
    FOR SocialmediaName IN ([Student], [Instructor], [Admin])
) AS PivotTable;

-- Verify the IsRole view
SELECT * FROM [dbo].[IsRole];

-- Create DimUser view
create VIEW [dbo].[VDimUser] AS
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

-- Verify the DimUser view
SELECT * FROM [dbo].[VDimUser] ORDER BY Id; --VDimUser [final result]
