{% macro fn_initcap(column_name) %}
    INITCAP({{ column_name }})
{% endmacro %}