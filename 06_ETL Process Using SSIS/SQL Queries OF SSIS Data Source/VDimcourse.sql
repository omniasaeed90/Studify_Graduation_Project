-- Create Dimcourse view
Create view VDimcourse as
SELECT 
  c.Id,Title,[Description],[Status],CourseLevel
  ,Discount,Price as OriginalPrice,CurrentPrice,
    Duration,NoSubscribers,Rating,
    IsFree,IsApproved,[Language],
    BestSeller,ct.[Name] as Category , sct.[Name] as SubCategory,InstructorId 
FROM [dbo].[Courses] c join Subcategories sct on sct.Id = c.SubCategoryId
join Categories ct on ct.Id = sct.CategoryId ;

-- Verify the Dimcourse view
select * from VDimcourse 