"""
Example usage of the ProgressTracker for debugging and testing.
"""
from progress_tracker import ProgressTracker


def main():
    # Initialize tracker
    tracker = ProgressTracker(db_path="../output/progress.db")
    
    # Example 1: Create or update an entry
    print("Creating new entry...")
    tracker.create_or_update_entry(
        file_path="repository/test/Example.sol",
        model_coding="gpt-5-mini",
        methods=15,
        total_files=100,
        status=0,
        model_summary="qwen3"
    )
    
    # Example 2: Get an entry
    print("\nRetrieving entry...")
    entry = tracker.get_entry("repository/test/Example.sol", "gpt-5-mini")
    if entry:
        print(f"Found entry: {entry}")
    
    # Example 3: Mark as completed with test results
    print("\nMarking as completed...")
    tracker.mark_completed(
        file_path="repository/test/Example.sol",
        model_coding="gpt-5-mini",
        test_pass=12,
        test_fail=3,
        test_total=15,
        test_json={
            "rounds": [
                {"round": 1, "pass": 10, "fail": 5, "total": 15},
                {"round": 2, "pass": 12, "fail": 3, "total": 15}
            ]
        }
    )
    
    # Example 4: Get statistics
    print("\nGetting statistics...")
    stats = tracker.get_stats()
    print(f"Statistics: {stats}")
    
    # Example 5: Get all entries
    print("\nGetting all entries...")
    all_entries = tracker.get_all_entries()
    for entry in all_entries:
        print(f"  - {entry['file_path']} ({entry.get('model_coding')}): status={entry['status']}")
    
    # Example 6: Reset an entry
    print("\nResetting entry...")
    tracker.reset_entry("repository/test/Example.sol", "gpt-5-mini")
    
    # Example 7: Delete an entry (cleanup)
    print("\nDeleting entry...")
    tracker.delete_entry("repository/test/Example.sol", "gpt-5-mini")
    
    print("\nDone!")


if __name__ == "__main__":
    main()
