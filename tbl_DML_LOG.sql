CREATE TABLE dbo.tbl_DML_LOG ( 
	DMLLogID INT NOT NULL IDENTITY(1,1) CONSTRAINT pk_DML_LOG PRIMARY KEY CLUSTERED
,	DBName SYSNAME NOT NULL 
,	UName NVARCHAR(100) NOT NULL 
,	DTM DATETIME NOT NULL 
,	TName VARCHAR(100) NOT NULL 
,	DMLType CHAR(1) NOT NULL 
,	RID VARCHAR(100) NOT NULL 
,	OldValues VARCHAR(MAX) NULL
,	NewValues VARCHAR(MAX) NULL
) ;
GO