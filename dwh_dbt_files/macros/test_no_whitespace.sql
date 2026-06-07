-- macros/test_no_whitespace.sql
{% test no_whitespace(model, column_name) %}

SELECT {{ column_name }}
FROM {{ model }}
WHERE
    {{ column_name }} IS NOT NULL
    AND LEN({{ column_name }}) != LEN(TRIM({{ column_name }}))

{% endtest %}