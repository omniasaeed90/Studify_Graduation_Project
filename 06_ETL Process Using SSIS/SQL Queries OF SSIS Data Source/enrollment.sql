WITH RankedEnrollments AS (
    SELECT 
        e.StudentId, 
        e.CourseId, 
        CONVERT(INT, FORMAT(StartDate, 'yyyyMMdd')) AS StartDateKey,
        CONVERT(INT, FORMAT(CompletionDate, 'yyyyMMdd')) AS CompletionDateKey,
        Status,
        Rating, 
        ProgressPercentage, 
        Grade,
        ROW_NUMBER() OVER (PARTITION BY e.StudentId, e.CourseId ORDER BY StartDate DESC) AS RowNum
    FROM Enrollments e 
    LEFT JOIN StudentGrades s ON e.StudentId = s.StudentId
)
SELECT 
    StudentId, 
    CourseId, 
    StartDateKey,
    CompletionDateKey,
    Status,
    Rating, 
    ProgressPercentage, 
    Grade
FROM RankedEnrollments
WHERE RowNum = 1
ORDER BY StudentId;


