CREATE VIEW dbo.vw_DML_Log_Column_Values
AS
/*
Unpivots all the column values that were updated or deleted and displays the old and new values side-by-side 
along with the table, id, update type, date of action, and user who performed the action.

*/
SELECT l.DMLLogID 
, o.[Key] AS ColumnName , o.Value AS OldValue , n.Value AS NewValue , IIF( o.Value = n.Value , 0,1) AS IsValueDifferent 
,	l.DBName , l.TName , l.RID, l.DMLType , l.DTM, l.UName
FROM dbo.tbl_DML_log AS l
	CROSS APPLY OPENJSON(l.oldvalues) AS  o
	OUTER APPLY OPENJSON(l.newvalues) AS  n
WHERE o.[Key] = n.[Key]	-- for updates
or n.[Key] IS NULL ;	-- for deletes
GO
