CREATE OR ALTER PROCEDURE dbo.GetTableDataFromJSON
    @json          NVARCHAR(MAX),           -- JSON data serialized from a table with similar layout
    @table_name    NVARCHAR(128),           -- name of table that defines output layout
    @table_schema  NVARCHAR(128) = 'dbo',   -- schema of table that defines output layout 
    @database_name NVARCHAR(128) = NULL,    -- leave NULL for current DB
    @insert_into_table_name NVARCHAR(128) = NULL,   -- leave null to output data as a result set.  Specify table name here (temp or permanent) 
                                                    -- if you wish to write data to that table instead of outputting it.
    @debug int = 0                          -- leave 0 for normal processing.  1 = print dynamic sql and exec it.  -1 = do not execute it.
AS
/*
Deserializes JSON data that was previously serialized from a table and outputs it in the same format as the table specified.
Optionally inserts into a temp or other destionation table that matches the layout of the input table.
Missing or misnamed column names will return as all NULL in the output.  Column names are case sensitive.

Security Note: uses dynamic SQL so there is a SQL injection risk.  Do not use on customer facing applications unless you well check the inputs.

Usage:

-- To generate JSON Example:
DECLARE @json NVARCHAR(MAX) = (
    SELECT * FROM master.sys.schemas
    WHERE NAME NOT IN ( 'dbo' , 'guest' , 'sys' , 'INFORMATION_SCHEMA' ) AND NAME NOT LIKE 'db[_]%'
    FOR JSON PATH , ROOT('schemas')
) ;
PRINT @json ; 

-- Simple Output:    
EXEC dbo.GetTableDataFromJSON @json = '{"schemas":[{"name":"test","schema_id":8,"principal_id":8},{"name":"temp","schema_id":9,"principal_id":9}]}'
,   @table_name = 'schemas'
,   @table_schema = 'sys' ;
    /*
    name	schema_id	principal_id
    test	8	8
    temp	9	9
    */

-- Debug statement only:
EXEC dbo.GetTableDataFromJSON @json = '{"schemas":[{"name":"test","schema_id":8,"principal_id":8},{"name":"temp","schema_id":9,"principal_id":9}]}'
,   @table_name = 'schemas'
,   @table_schema = 'sys' 
,   @debug = -1;
    /*
        SELECT [name],[schema_id],[principal_id]
        FROM OPENJSON(@json, '$.schemas') 
        WITH ([name] nvarchar(128),[schema_id] int,[principal_id] int)
    */

-- Insert into temp table:
DROP TABLE IF EXISTS #tempSchemas;
SELECT TOP 0 * INTO #tempSchemas FROM master.sys.schemas ;

EXEC dbo.GetTableDataFromJSON @json = '{"schemas":[{"name":"test","schema_id":8,"principal_id":8},{"name":"temp","schema_id":9,"principal_id":9}]}'
,   @table_name = 'schemas'
,   @table_schema = 'sys' 
,   @insert_into_table_name = '#tempSchemas';

SELECT * FROM #tempSchemas 
WHERE name <> 'temp'; 
    /*
    name	schema_id	principal_id
    test	8	8
    */

*/
BEGIN
    SET NOCOUNT ON ;

    DECLARE @with_clause NVARCHAR(MAX);
    DECLARE @select_clause NVARCHAR(MAX);
    DECLARE @sql_command NVARCHAR(MAX);
    DECLARE @full_table_sql NVARCHAR(500) = 'SELECT TOP 0 * FROM ' +
        ISNULL( QUOTENAME(@database_name) , DB_NAME() ) + '.' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name);

    -- 1. Build the SELECT and WITH clauses by querying metadata from the target table
    SELECT @with_clause = ISNULL( @with_clause  + ',' , '' ) + QUOTENAME(name) + ' ' + system_type_name
    ,   @select_clause  = ISNULL( @select_clause  + ',' , '' ) + QUOTENAME(name) 
    FROM sys.dm_exec_describe_first_result_set(@full_table_sql, NULL, 0)
    ORDER BY column_ordinal;

    -- 2. Construct the final dynamic SELECT statement
    SET @sql_command = N'
        SELECT ' + @select_clause + '
        FROM OPENJSON(@json, ''$.' + @table_name +  ''') 
        WITH (' + @with_clause + ')';		

	-- 3. If @insert_into_table_name was input, setup insert of the data into that table
	IF LEN( @insert_into_table_name ) > 0 
      BEGIN
        SET @sql_command = 'INSERT INTO ' + @insert_into_table_name + '( ' + @select_clause + ' ) 
        ' + @sql_command ;

        -- detect and handle if the destination table has an identity column:
        SET @full_table_sql = 'SELECT TOP 0 * FROM ' + @insert_into_table_name ;

        IF EXISTS ( 
            SELECT 1
            FROM sys.dm_exec_describe_first_result_set(@full_table_sql, NULL, 0)
            WHERE is_identity_column = 1
        )
            SET @sql_command = 'SET IDENTITY_INSERT ' + @insert_into_table_name + ' ON; ' + @sql_command + ';
                SET IDENTITY_INSERT ' + @insert_into_table_name + ' OFF;';
      END;

     IF @debug <> 0 PRINT @sql_command ;

    -- 4. Execute with parameters 
    IF @debug >= 0 EXEC sp_executesql @sql_command, N'@json NVARCHAR(MAX)', @json = @json;
END;

GO

