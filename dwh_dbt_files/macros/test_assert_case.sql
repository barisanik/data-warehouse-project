/*
	# ============================================================================ #
		Macro: assert_case
	# ============================================================================ #
        Purpose: Validates that all non-null values in a column are fully uppercased or lowercased.
        Logic:  Returns rows where the value does not match the expected case. Uses COLLATE Latin1_General_BIN to enforce case-sensitive 
                comparison on SQL Server's default CI collation. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:
            models:
              - name: model_name
                columns:
                  - name: column_name
                    tests:
                      - assert_case:
                          case: 'upper'   # 'upper' | 'lower'
        
	# ============================================================================ #
*/
{% test assert_case(model, column_name, case='upper') %}
    SELECT
        {{ column_name }}
    FROM
        {{ model }}
    WHERE
        {% if case == 'upper' %}
            {{ column_name }} COLLATE Latin1_General_BIN != UPPER({{ column_name }})
        {% elif case == 'lower' %}
            {{ column_name }} COLLATE Latin1_General_BIN != LOWER({{ column_name }})
        {% else %}
            {{ exceptions.raise_compiler_error(
                "case argument must be 'upper' or 'lower'. Got: '" ~ case ~ "'"
            ) }}
        {% endif %}
{% endtest %}