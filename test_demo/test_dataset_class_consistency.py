import json
import sys
from pathlib import Path


def check_dataset_single_class(dataset_path: Path):
    """Return a dict of offenders: file_path -> sorted list of classes when a file has >1 class.

    The function does not raise; it returns the offenders mapping so callers can decide how to report.
    """
    if not dataset_path.exists():
        raise FileNotFoundError(f"dataset.json not found at {dataset_path}")

    with dataset_path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    offenders = {}
    for file_path, funcs in data.items():
        classes = set()
        if not isinstance(funcs, list):
            # unexpected structure: skip or treat as no-classes
            continue
        for fn in funcs:
            if not isinstance(fn, dict):
                continue
            cls = fn.get("class")
            # normalize empty/None
            if cls is None:
                continue
            cls = str(cls).strip()
            if cls == "":
                continue
            classes.add(cls)

        if len(classes) > 1:
            offenders[file_path] = sorted(classes)

    return offenders


def test_dataset_files_single_class_per_file():
    """Pytest wrapper around check_dataset_single_class."""
    repo_root = Path(__file__).resolve().parent.parent
    dataset_path = repo_root / "data" / "dataset.json"
    offenders = check_dataset_single_class(dataset_path)
    assert not offenders, (
        "Found files where functions belong to multiple classes.\n"
        "Offending files and classes:\n"
        + "\n".join(f"{p}: {cls_list}" for p, cls_list in offenders.items())
    )


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    dataset_path = repo_root / "data" / "dataset.json"
    try:
        offenders = check_dataset_single_class(dataset_path)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    if offenders:
        print("Found files where functions belong to multiple classes:\n")
        for p, cls_list in offenders.items():
            print(f"{p}: {cls_list}")
        sys.exit(1)
    print("OK: all dataset files have functions from at most one class")
