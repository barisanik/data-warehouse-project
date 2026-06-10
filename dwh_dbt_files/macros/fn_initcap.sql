{% macro fn_initcap(column_name) %}
    -- Requires [dbo].[FN_InitCap] UDF to be present on the target SQL Server database.
    [dbo].[FN_InitCap]({{ column_name }})
{% endmacro %}