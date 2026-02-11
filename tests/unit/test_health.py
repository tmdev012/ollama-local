"""Unit tests — health check and basic validation."""
import pytest


@pytest.mark.unit
def test_python_version():
    """Verify Python 3.10+."""
    import sys
    assert sys.version_info >= (3, 10)


@pytest.mark.unit
def test_imports():
    """Verify core imports work."""
    import json  # noqa: F401
    import os  # noqa: F401
    import pathlib  # noqa: F401
    assert True


@pytest.mark.unit
def test_project_structure():
    """Verify expected directories exist."""
    from pathlib import Path
    root = Path(__file__).parent.parent.parent
    assert (root / "README.md").exists()
    assert (root / "requirements.txt").exists() or (root / "pyproject.toml").exists()
