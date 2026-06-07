-- macros/test_matches_pattern.sql
{% test matches_pattern(model, column_name, pattern) %}

SELECT {{ column_name }}
FROM {{ model }}
WHERE
    {{ column_name }} IS NOT NULL
    AND {{ column_name }} NOT LIKE '{{ pattern }}'

{% endtest %}