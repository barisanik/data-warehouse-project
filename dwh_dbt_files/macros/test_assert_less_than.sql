/*
	# ============================================================================ #
		Macro: assert_less_than
	# ============================================================================ #
        Purpose: Ensures column_a is strictly less than column_b.
        Logic: Returns rows where column_a is equal or higher than column_b. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:

        models:
          - name: model_name
            columns:
            - name: column_name
                tests:
                - assert_less_than:
                    arguments:
                        column_b: prd_end_dt

	# ============================================================================ #
*/

{% test assert_less_than(model, column_name, column_b) %}

SELECT {{ column_name }}
FROM {{ model }}
WHERE
    {{ column_name }} IS NOT NULL
    AND {{ column_b }} IS NOT NULL
    AND {{ column_name }} >= {{ column_b }}

{% endtest %}