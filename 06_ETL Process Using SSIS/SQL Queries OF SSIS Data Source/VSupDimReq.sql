-- Create VSupDimReq view
create view VSupDimReq as
select CourseId , Requirement from [dbo].[CourseRequirements];

-- To verify VSupDimReq view
select * from VSupDimReq  order by CourseId;