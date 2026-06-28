/*
    # ============================================================================ #
        Macro: assert_length
    # ============================================================================ #
        Purpose : Validates that a column's character length equals the given limit.
        Logic   : Returns rows where LENGTH(column_name) != length_limit. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:
            models:
              - name: model_name
                columns:
                  - name: title
                    tests:
                      - assert_length:
                        arguments:
                            length_limit: 15
    # ============================================================================ #
*/
{% test assert_length(model, column_name, length_limit) %}
    SELECT
        {{ column_name }}
    FROM
        {{ model }}
    WHERE
        LENGTH({{ column_name }}) != {{ length_limit }}
{% endtest %}