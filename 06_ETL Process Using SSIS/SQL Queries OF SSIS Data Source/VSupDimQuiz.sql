-- Create SupDimQuiz view
create VIEW VSupDimQuiz AS
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

-- To verify SupDimQuiz view
select * from VSupDimQuiz order by QuizId;