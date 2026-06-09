/*
    # ============================================================================ #
        Macro: assert_formula
    # ============================================================================ #
        Purpose : Validates that a column's value equals the result of an arithmetic operation between two other columns.
        Logic   : Returns rows where column_name != column_a <op> column_b. dbt marks a test as failed if this query returns any rows.

        Usage on schema.yml:
            models:
              - name: model_name
                columns:
                  - name: total_price
                    tests:
                      - assert_formula:
                        arguments:
                          column_a: 'unit_price'
                          column_b: 'quantity'
                          op: 'multiply'
    # ============================================================================ #
*/
{% test assert_formula(model, column_name, column_a, column_b, op='multiply') %}
    SELECT
        {{ column_name }}
    FROM
        {{ model }}
    WHERE
        {% if op == 'multiply' %}
            {{ column_name }} != {{ column_a }} * {{ column_b }}
        {% elif op == 'divide' %}
            {{ column_name }} != {{ column_a }} / {{ column_b }}
        {% elif op == 'add' %}
            {{ column_name }} != {{ column_a }} + {{ column_b }}
        {% elif op == 'subtract' %}
            {{ column_name }} != {{ column_a }} - {{ column_b }}
        {% else %}
            {{ exceptions.raise_compiler_error(
                "op argument must be 'multiply', 'divide', 'add', or 'subtract'. Got: '" ~ op ~ "'"
            ) }}
        {% endif %}
{% endtest %}