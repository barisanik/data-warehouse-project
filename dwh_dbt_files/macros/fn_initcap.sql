{% macro fn_initcap(column_name) %}
    [dbo].[FN_InitCap]({{ column_name }})
{% endmacro %}