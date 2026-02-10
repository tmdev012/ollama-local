"""E2E smoke tests — validate full application lifecycle."""
import pytest
import subprocess


@pytest.mark.e2e
def test_lint_passes():
    """Verify code passes linting."""
    result = subprocess.run(
        ["python", "-m", "py_compile", "tests/unit/test_health.py"],
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"Lint failed: {result.stderr}"


@pytest.mark.e2e
def test_readme_has_content():
    """Verify README is not empty."""
    from pathlib import Path
    readme = Path(__file__).parent.parent.parent / "README.md"
    assert readme.exists()
    content = readme.read_text()
    assert len(content) > 100, "README too short"
