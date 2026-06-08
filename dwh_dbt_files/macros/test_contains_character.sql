/*
	# ============================================================================ #
		Macro: contains_character
	# ============================================================================ #
        Purpose: Detects if input value contains given character.
        Logic: Returns values with unwanted character. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:

            models:
            - name: model_name
                columns:
                - name: column_name
                    tests:
                    - contains_character
                        arguments:
                            character: '-'

	# ============================================================================ #
*/
{% test contains_character(model, column_name, character) %}

SELECT {{ column_name }}
FROM {{ model }}
WHERE
    {{ column_name }} IS NOT NULL
    AND {{ column_name }} LIKE '%' + '{{ character }}' + '%'

{% endtest %}