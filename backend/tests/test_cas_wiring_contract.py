"""CAS Executor ↔ Action YAML 接线契约测试。"""
from __future__ import annotations

import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from cas.wiring import assert_cas_wiring_ok, audit_cas_wiring


def test_all_executors_are_registered_in_action_yaml():
    gaps = audit_cas_wiring(load_executors=True)
    assert gaps["executors_without_action"] == [], gaps["executors_without_action"]
    assert gaps["actions_without_executor"] == [], gaps["actions_without_executor"]
    assert gaps["executor_ref_mismatch"] == [], gaps["executor_ref_mismatch"]


def test_assert_cas_wiring_ok_passes():
    assert_cas_wiring_ok(load_executors=True)
