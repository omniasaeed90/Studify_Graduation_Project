-- SQL script to create and populate dim_date table
BEGIN TRY
    TRUNCATE TABLE dim_date
    DROP TABLE [dim_date]
END TRY
BEGIN CATCH
    -- DO NOTHING
END CATCH

CREATE TABLE [dbo].[dim_date](
    [Date_id_sk] [int] NOT NULL,
    [Date] [datetime] NOT NULL,
    [Day] [char](2) NOT NULL,
      NOT NULL,
      NOT NULL,
    [DOWInMonth] [TINYINT] NOT NULL,
    [DayOfYear] [int] NOT NULL,
    [WeekOfYear] [tinyint] NOT NULL,
    [WeekOfMonth] [tinyint] NOT NULL,
    [Month] [char](2) NOT NULL,
      NOT NULL,
    [Quarter] [tinyint] NOT NULL,
    [QuarterName] [varchar](6) NOT NULL,
      NOT NULL,
      NULL,
      NULL,
    CONSTRAINT [PK_DimDate] PRIMARY KEY CLUSTERED ([date_id_sk] ASC)
) ON [PRIMARY]

GO

-- Populate Date Dimension
TRUNCATE TABLE [dim_date]

DECLARE @tmpDOW TABLE (DOW INT, Cntr INT)
INSERT INTO @tmpDOW (DOW, Cntr) VALUES (1,0),(2,0),(3,0),(4,0),(5,0),(6,0),(7,0)

DECLARE @StartDate datetime = '2020-01-01', @EndDate datetime = '2025-12-31'
DECLARE @Date datetime = @StartDate, @WDofMonth INT, @CurrentMonth INT = 1

WHILE @Date < @EndDate
BEGIN
    IF DATEPART(MONTH,@Date) <> @CurrentMonth 
    BEGIN
        SELECT @CurrentMonth = DATEPART(MONTH,@Date)
        UPDATE @tmpDOW SET Cntr = 0
    END

    UPDATE @tmpDOW SET Cntr = Cntr + 1 WHERE DOW = DATEPART(WEEKDAY,@Date)
    SELECT @WDofMonth = Cntr FROM @tmpDOW WHERE DOW = DATEPART(WEEKDAY,@Date)

    INSERT INTO [dim_date] ([date_id_sk], [Date], [Day], [DaySuffix], [DayOfWeek], [DOWInMonth], [DayOfYear], [WeekOfYear], [WeekOfMonth], [Month], [MonthName], [Quarter], [QuarterName], [Year])
    SELECT 
        CONVERT(VARCHAR, @Date, 112), 
        @Date,
        RIGHT('0' + CAST(DATEPART(DAY, @Date) AS VARCHAR), 2),
        CASE
            WHEN DATEPART(DAY, @Date) IN (11,12,13) THEN CAST(DATEPART(DAY, @Date) AS VARCHAR) + 'th'
            WHEN RIGHT(DATEPART(DAY, @Date), 1) = '1' THEN CAST(DATEPART(DAY, @Date) AS VARCHAR) + 'st'
            WHEN RIGHT(DATEPART(DAY, @Date), 1) = '2' THEN CAST(DATEPART(DAY, @Date) AS VARCHAR) + 'nd'
            WHEN RIGHT(DATEPART(DAY, @Date), 1) = '3' THEN CAST(DATEPART(DAY, @Date) AS VARCHAR) + 'rd'
            ELSE CAST(DATEPART(DAY, @Date) AS VARCHAR) + 'th' 
        END,
        DATENAME(WEEKDAY, @Date),
        @WDofMonth,
        DATEPART(DAYOFYEAR, @Date),
        DATEPART(WEEK, @Date),
        DATEPART(WEEK, @Date) + 1 - DATEPART(WEEK, CAST(DATEPART(MONTH, @Date) AS VARCHAR) + '/1/' + CAST(DATEPART(YEAR, @Date) AS VARCHAR)),
        RIGHT('0' + CAST(DATEPART(MONTH, @Date) AS VARCHAR), 2),
        DATENAME(MONTH, @Date),
        DATEPART(QUARTER, @Date),
        CASE DATEPART(QUARTER, @Date) 
            WHEN 1 THEN 'First'
            WHEN 2 THEN 'Second'
            WHEN 3 THEN 'Third'
            WHEN 4 THEN 'Fourth'
        END,
        CAST(DATEPART(YEAR, @Date) AS CHAR(4))

    SELECT @Date = DATEADD(DAY, 1, @Date)
END

-- Update Standard Date
UPDATE dbo.dim_date
SET StandardDate = Month + '/' + Day + '/' + Year

-- Add Holidays
UPDATE [dim_date] SET HolidayText = 'Christmas Day' WHERE [MONTH] = '12' AND [DAY] = '25'
UPDATE [dim_date] SET HolidayText = 'New Year''s Day' WHERE [MONTH] = '01' AND [DAY] = '01'
UPDATE [dim_date] SET HolidayText = 'Independence Day' WHERE [MONTH] = '07' AND [DAY] = '04'
UPDATE [dim_date] SET HolidayText = 'Halloween' WHERE [MONTH] = '10' AND [DAY] = '31'

-- Indexes
CREATE UNIQUE NONCLUSTERED INDEX [IDX_DimDate_Date] ON [dbo].[dim_date] ([Date] ASC)
CREATE NONCLUSTERED INDEX [IDX_DimDate_Month] ON [dbo].[dim_date] ([Month] ASC)
CREATE NONCLUSTERED INDEX [IDX_DimDate_Year] ON [dbo].[dim_date] ([Year] ASC)
