-- Create LessonTypeCount view
CREATE VIEW LessonTypeCount AS
SELECT 
    s.Id as SectionId,
    s.CourseId,
    COUNT(CASE WHEN l.Type = 'Video' THEN 1 ELSE NULL END) AS VideoCount,
    COUNT(CASE WHEN l.Type = 'Article' THEN 1 ELSE NULL END) AS ArticleCount
FROM 
    sections s
LEFT JOIN 
    lessons l ON s.Id = l.SectionId
GROUP BY 
    s.Id, s.CourseId;
	

-- To verify LessonTypeCount view
SELECT * FROM LessonTypeCount	order by SectionId;

-- Create SupDimSection view
CREATE VIEW VSupDimSection AS
SELECT 
	[Id] as SectionId,l.[CourseId],[Title],
	[Duration],[NoLessons],VideoCount,ArticleCount
FROM [dbo].[Sections] s join LessonTypeCount l on s.Id =l.SectionId

-- To verify SupDimSection view
select * from VSupDimSection order by SectionId; 