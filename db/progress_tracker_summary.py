"""Summary progress tracker that reuses BaseProgressTracker implementation."""
from .progress_tracker_base import BaseProgressTracker


class ProgressTrackerSummary(BaseProgressTracker):
    table_name = "process_tracking_summary"

