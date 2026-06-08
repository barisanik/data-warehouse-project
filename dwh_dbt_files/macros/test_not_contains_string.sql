/*
	# ============================================================================ #
		Macro: not_contains_string
	# ============================================================================ #
        Purpose: Detects if input value contains given character.
        Logic: Returns values with unwanted character. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:

            models:
            - name: model_name
                columns:
                - name: column_name
                    tests:
                    - not_contains_string:
                        arguments:
                            character: '-'

	# ============================================================================ #
*/
{% test not_contains_string(model, column_name, text) %}

SELECT {{ column_name }}
FROM {{ model }}
WHERE
    {{ column_name }} IS NOT NULL
    AND {{ column_name }} LIKE '%' + '{{ text }}' + '%'

{% endtest %}