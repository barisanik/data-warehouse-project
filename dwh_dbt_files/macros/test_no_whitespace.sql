/*
	# ============================================================================ #
		Macro: no_whitespace
	# ============================================================================ #
        Purpose: Detects leading or trailing whitespace in a given column.
        Logic: Returns values with leading or trailing whitespace. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:

            models:
            - name: model_name
                columns:
                - name: column_name
                    tests:
                    - no_whitespace

	# ============================================================================ #
*/
{% test no_whitespace(model, column_name) %}

SELECT {{ column_name }}
FROM {{ model }}
WHERE
    {{ column_name }} IS NOT NULL
    AND LEN({{ column_name }}) != LEN(TRIM({{ column_name }}))

{% endtest %}