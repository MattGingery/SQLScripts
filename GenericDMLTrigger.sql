-- Same code on all  tables except the table name and trigger name.
-- If the primary key is not called "ID", you would need to change that column name in the below trigger.  

create TRIGGER dbo.tr_tbl_CUSTOMER 
   ON dbo.tbl_CUSTOMER 
   AFTER DELETE,UPDATE
AS 
BEGIN
	IF (ROWCOUNT_BIG() = 0)
	RETURN;

	SET NOCOUNT ON;

	INSERT dbo.tbl_DML_LOG
	( DBName , UName , DTM , TName , DMLType , RID , OldValues , NewValues ) 
	SELECT DB_NAME(), SUSER_SNAME() , GETDATE() , ( SELECT OBJECT_NAME(parent_id) FROM sys.triggers where object_id = @@procid )
	,	Typ , id , jsonOLD , jsonNEW
	FROM ( 
		SELECT ISNULL( i.ID , d.id ) AS id
		, CASE	WHEN   i.ID IS NOT NULL 
				AND    d.id IS NOT NULL THEN 'U'
				WHEN   i.ID IS NOT NULL THEN 'I' 
				WHEN   d.ID IS NOT NULL THEN 'D' ELSE '?' END AS Typ
		, (SELECT d.* FOR JSON PATH , WITHOUT_ARRAY_WRAPPER) as jsonOLD
		, (SELECT i.* FOR JSON PATH , WITHOUT_ARRAY_WRAPPER) as jsonNEW 
		FROM deleted AS d
			FULL OUTER JOIN inserted AS i
				ON d.ID = i.ID
	) AS A 
END
GO
