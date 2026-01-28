"""Progress tracker wrapper that uses BaseProgressTracker.

This module keeps the original `ProgressTracker` API but delegates
implementation to the shared base class to avoid duplication.
"""
from .progress_tracker_base import BaseProgressTracker


class ProgressTracker(BaseProgressTracker):
    table_name = "process_tracking"

