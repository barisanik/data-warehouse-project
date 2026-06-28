/*
	# ============================================================================ #
		Macro: matches_pattern
	# ============================================================================ #
        Purpose: Ensures input value matches to given pattern.
        Logic: Returns values with not matching format. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:

        models:
          - name: model_name
            columns:
            - name: column_name
                tests:
                - matches_pattern:
                    arguments:
                        pattern: '^.{2}_.{2}$'

        Expected input for pass: 'AB_CD'

        Note: Pattern argument must be a regular expression (BigQuery REGEXP_CONTAINS).
              Previously used T-SQL LIKE syntax (e.g. '__[_]__') is not compatible.

	# ============================================================================ #
*/

{% test matches_pattern(model, column_name, pattern) %}

SELECT {{ column_name }}
FROM {{ model }}
WHERE
    {{ column_name }} IS NOT NULL
    AND NOT REGEXP_CONTAINS({{ column_name }}, '{{ pattern }}')

{% endtest %}