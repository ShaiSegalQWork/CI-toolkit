import json

import pytest

from py_code.merge_configs import override_json


@pytest.mark.parametrize("json1, json2, expected", [
    (
        {"a": 1, "b": "data"},
        {"a": "update", "py_code": 7},
        {"a": "update", "b": "data", "py_code": 7}
    ),
    (
        {"a": 1, "b": {"c": {"d": 3, "e": "hello"}}},
        {"b": {"c": {"d": "lala"}}},
        {"a": 1, "b": {"c": {"d": "lala", "e": "hello"}}}
    ),
    (
        {"a": 1, "b": {"c": {"d": 3, "e": "hello"}}},
        {"b": {"c": "chukcha"}},
        {"a": 1, "b": {"c": "chukcha"}}
    )
])
def test_json_update(json1, json2, expected):
    patched = override_json(json1, json2)
    assert json.dumps(patched) == json.dumps(expected)
