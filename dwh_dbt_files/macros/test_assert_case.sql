/*
	# ============================================================================ #
		Macro: assert_case
	# ============================================================================ #
        Purpose: Validates that all non-null values in a column are fully uppercased, lowercased or initcapped.
        Logic:  Returns rows where the value does not match the expected case.
                BigQuery string comparisons are case-sensitive by default, so COLLATE is not needed.
                dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:
            models:
              - name: model_name
                columns:
                  - name: column_name
                    tests:
                      - assert_case:
                          case: 'upper'   # 'upper' | 'lower' | 'initcap'
        
	# ============================================================================ #
*/
{% test assert_case(model, column_name, case='upper') %}
    SELECT
        {{ column_name }}
    FROM
        {{ model }}
    WHERE
        {% if case == 'upper' %}
            {{ column_name }} != UPPER({{ column_name }})
        {% elif case == 'lower' %}
            {{ column_name }} != LOWER({{ column_name }})
        {% elif case == 'initcap' %}
            {{ column_name }} != {{ fn_initcap(column_name) }}
        {% else %}
            {{ exceptions.raise_compiler_error(
                "case argument must be 'upper', 'lower' or 'initcap'. Got: '" ~ case ~ "'"
            ) }}
        {% endif %}
{% endtest %}