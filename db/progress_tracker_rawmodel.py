"""
SQLite-based progress tracker for rawmodel RQ1 experiments.
Extends base ProgressTracker with additional fields for gas fees and vulnerability metrics.
"""
import sqlite3
import json
import os
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import contextmanager


class ProgressTrackerRawModel:
    """
    Progress tracker for RQ1 rawmodel experiments.
    Creates progress_tracker_rawmodel table with additional fields:
    - gas_fee_json: JSON string of gas fees per test method
    - slither_raw: Raw slither detection output as JSON
    - vuln_count: Count of vulnerabilities detected by slither
    """
    table_name = "progress_tracker_rawmodel"  # Table name for rawmodel tracker
    
    def __init__(self, db_path: str = "output/progress.db"):
        """Initialize the progress tracker with SQLite database."""
        self.db_path = db_path
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self._init_db()

    @contextmanager
    def _get_connection(self):
        """Context manager for database connections."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def _init_db(self):
        """Initialize database schema for rawmodel table."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Create progress_tracker_rawmodel table with additional fields
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS progress_tracker_rawmodel (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path TEXT NOT NULL,
                    methods INTEGER DEFAULT 0,
                    total_files INTEGER DEFAULT 0,
                    status INTEGER DEFAULT 0,
                    model_coding TEXT,
                    model_summary TEXT,
                        coding_messages TEXT,
                    test_pass INTEGER DEFAULT 0,
                    test_fail INTEGER DEFAULT 0,
                    test_total INTEGER DEFAULT 0,
                    gas_fee_json TEXT,
                    slither_raw TEXT,
                    vuln_count INTEGER DEFAULT 0,
                    prompt_tokens INTEGER DEFAULT 0,
                    completion_tokens INTEGER DEFAULT 0,
                    summary_prompt_tokens INTEGER DEFAULT 0,
                    summary_completion_tokens INTEGER DEFAULT 0,
                    total_cost REAL DEFAULT 0.0,
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    duration REAL DEFAULT 0.0,
                    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(file_path, model_coding)
                )
            """)
            
            # Try to add new columns if they don't exist (for database migration)
            new_columns = [
                ("gas_fee_json", "TEXT"),
                ("slither_raw", "TEXT"),
                ("coding_messages", "TEXT"),
                ("vuln_count", "INTEGER DEFAULT 0"),
                ("start_time", "TIMESTAMP"),
                ("end_time", "TIMESTAMP"),
                ("duration", "REAL DEFAULT 0.0"),
                ("summary_prompt_tokens", "INTEGER DEFAULT 0"),
                ("summary_completion_tokens", "INTEGER DEFAULT 0")
            ]
            
            for col_name, col_type in new_columns:
                try:
                    cursor.execute(f"ALTER TABLE progress_tracker_rawmodel ADD COLUMN {col_name} {col_type}")
                except sqlite3.OperationalError:
                    pass  # Column already exists
            
            # Create indexes for faster lookups
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_rawmodel_file_model 
                ON progress_tracker_rawmodel(file_path, model_coding)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_rawmodel_status 
                ON progress_tracker_rawmodel(status)
            """)

    def get_entry(self, file_path: str, model_coding: str) -> Optional[Dict[str, Any]]:
        """
        Get tracking entry for a specific file and model.
        
        Args:
            file_path: Path to the file being processed
            model_coding: Name of the code model being used
            
        Returns:
            Dictionary with entry data or None if not found
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT * FROM progress_tracker_rawmodel 
                WHERE file_path = ? AND model_coding = ?
            """, (file_path, model_coding))
            
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None

    def create_or_update_entry(
        self,
        file_path: str,
        model_coding: str,
        methods: int = 0,
        total_files: int = 0,
        status: int = 0,
        model_summary: Optional[str] = None,
        test_pass: int = 0,
        test_fail: int = 0,
        test_total: int = 0,
        gas_fee_json: Optional[Dict] = None,
        slither_raw: Optional[Dict] = None,
        coding_messages: Optional[Dict] = None,
        vuln_count: int = 0,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_cost: float = 0.0,
        start_time: Optional[str] = None
    ) -> int:
        """
        Create or update a tracking entry.
        
        Args:
            file_path: Path to the file being processed
            model_coding: Name of the code model
            methods: Total number of methods in the file
            total_files: Total number of files in dataset
            status: 0=unprocessed, 1=processed
            model_summary: Name of the summary model
            test_pass: Number of tests passed
            test_fail: Number of tests failed
            test_total: Total number of tests
            gas_fee_json: Dict of gas fees per test method
            slither_raw: Raw slither detection output
            vuln_count: Number of vulnerabilities detected
            prompt_tokens: Total prompt tokens used
            completion_tokens: Total completion tokens used
            total_cost: Total cost in USD
            start_time: Start time of processing (ISO format string)
            
        Returns:
            ID of the created or updated entry
        """
        gas_fee_json_str = json.dumps(gas_fee_json) if gas_fee_json else None
        slither_raw_str = json.dumps(slither_raw) if slither_raw else None
        coding_messages_str = json.dumps(coding_messages) if coding_messages else None
        current_time = datetime.now().isoformat()
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Try to get existing entry
            existing = self.get_entry(file_path, model_coding)
            
            if existing:
                # Update existing entry
                if status == 0:
                    # Overwrite start_time for a new run; clear end_time and duration
                    cursor.execute("""
                        UPDATE progress_tracker_rawmodel
                        SET methods = ?,
                            total_files = ?,
                            status = ?,
                            model_summary = ?,
                            coding_messages = ?,
                            test_pass = ?,
                            test_fail = ?,
                            test_total = ?,
                            gas_fee_json = ?,
                            slither_raw = ?,
                            vuln_count = ?,
                            prompt_tokens = ?,
                            completion_tokens = ?,
                            total_cost = ?,
                            start_time = ?,
                            end_time = NULL,
                            duration = 0.0,
                            update_time = ?
                        WHERE file_path = ? AND model_coding = ?
                    """, (
                        methods, total_files, status, model_summary, coding_messages_str,
                        test_pass, test_fail, test_total,
                        gas_fee_json_str, slither_raw_str, vuln_count,
                        prompt_tokens, completion_tokens, total_cost,
                        start_time or current_time, current_time, file_path, model_coding
                    ))
                else:
                    # Keep existing start_time for non-new runs
                    cursor.execute("""
                        UPDATE progress_tracker_rawmodel 
                        SET methods = ?,
                            total_files = ?,
                            status = ?,
                            model_summary = ?,
                            test_pass = ?,
                            test_fail = ?,
                            test_total = ?,
                            gas_fee_json = ?,
                            slither_raw = ?,
                            coding_messages = ?,
                            vuln_count = ?,
                            prompt_tokens = ?,
                            completion_tokens = ?,
                            total_cost = ?,
                            update_time = ?
                        WHERE file_path = ? AND model_coding = ?
                    """, (
                        methods, total_files, status, model_summary,
                        test_pass, test_fail, test_total,
                        gas_fee_json_str, slither_raw_str, coding_messages_str, vuln_count,
                        prompt_tokens, completion_tokens, total_cost,
                        current_time, file_path, model_coding
                    ))

                return existing['id']
            else:
                # Create new entry
                cursor.execute("""
                    INSERT INTO progress_tracker_rawmodel (
                        file_path, methods, total_files, status,
                        model_coding, model_summary, coding_messages, test_pass, test_fail,
                        test_total, gas_fee_json, slither_raw, vuln_count,
                        prompt_tokens, completion_tokens, total_cost,
                        start_time, create_time, update_time
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    file_path, methods, total_files, status,
                    model_coding, model_summary, coding_messages_str, test_pass, test_fail,
                    test_total, gas_fee_json_str, slither_raw_str, vuln_count,
                    prompt_tokens, completion_tokens, total_cost,
                    start_time or current_time, current_time, current_time
                ))
                return cursor.lastrowid

    def mark_completed(
        self,
        file_path: str,
        methods: int,
        model_coding: str,
        test_pass: int = 0,
        test_fail: int = 0,
        test_total: int = 0,
        gas_fee_json: Optional[Dict] = None,
        slither_raw: Optional[Dict] = None,
        coding_messages: Optional[Dict] = None,
        vuln_count: int = 0,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_cost: float = 0.0,
        end_time: Optional[str] = None
    ):
        """
        Mark a file as completed with test results, gas fees, and vulnerability info.
        
        Args:
            file_path: Path to the file
            model_coding: Model name
            test_pass: Number of tests passed
            test_fail: Number of tests failed
            test_total: Total tests
            gas_fee_json: Dict of gas fees per test method
            slither_raw: Raw slither output
            vuln_count: Number of vulnerabilities
            prompt_tokens: Total prompt tokens
            completion_tokens: Total completion tokens
            total_cost: Total cost
            end_time: End time of processing (ISO format string)
        """
        existing = self.get_entry(file_path, model_coding)
        if existing:
            end_time = end_time or datetime.now().isoformat()
            
            # Calculate duration if start_time exists
            duration = 0.0
            if existing.get('start_time'):
                try:
                    start_dt = datetime.fromisoformat(existing['start_time'])
                    end_dt = datetime.fromisoformat(end_time)
                    duration = (end_dt - start_dt).total_seconds()
                except (ValueError, TypeError):
                    duration = 0.0
            
            # Update entry
            self.create_or_update_entry(
                file_path=file_path,
                model_coding=model_coding,
                methods=methods,
                total_files=existing.get('total_files', 0),
                status=1,
                model_summary=existing.get('model_summary'),
                coding_messages=coding_messages,
                test_pass=test_pass,
                test_fail=test_fail,
                test_total=test_total,
                gas_fee_json=gas_fee_json,
                slither_raw=slither_raw,
                vuln_count=vuln_count,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_cost=total_cost
            )
            
            # Update end_time and duration separately
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE progress_tracker_rawmodel 
                    SET end_time = ?, duration = ?
                    WHERE file_path = ? AND model_coding = ?
                """, (end_time, duration, file_path, model_coding))
            
            return existing.get('id')
        return None

    def get_all_entries(self, status: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Get all tracking entries, optionally filtered by status.
        
        Args:
            status: Filter by status (0 or 1), None for all
            
        Returns:
            List of entry dictionaries
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            if status is not None:
                cursor.execute(
                    "SELECT * FROM progress_tracker_rawmodel WHERE status = ? ORDER BY id",
                    (status,)
                )
            else:
                cursor.execute("SELECT * FROM progress_tracker_rawmodel ORDER BY id")
            
            return [dict(row) for row in cursor.fetchall()]

    def get_stats(self) -> Dict[str, Any]:
        """
        Get overall statistics.
        
        Returns:
            Dictionary with total, processed, and unprocessed counts
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) as total FROM progress_tracker_rawmodel")
            total = cursor.fetchone()['total']
            
            cursor.execute("SELECT COUNT(*) as processed FROM progress_tracker_rawmodel WHERE status = 1")
            processed = cursor.fetchone()['processed']
            
            cursor.execute("SELECT COUNT(*) as unprocessed FROM progress_tracker_rawmodel WHERE status = 0")
            unprocessed = cursor.fetchone()['unprocessed']
            
            return {
                'total': total,
                'processed': processed,
                'unprocessed': unprocessed,
                'completion_rate': (processed / total * 100) if total > 0 else 0
            }

    def reset_entry(self, file_path: str, model_coding: str):
        """Reset an entry's status to unprocessed."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE progress_tracker_rawmodel 
                SET status = 0, update_time = ?
                WHERE file_path = ? AND model_coding = ?
            """, (datetime.now().isoformat(), file_path, model_coding))

    def delete_entry(self, file_path: str, model_coding: str):
        """Delete an entry from the database."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM progress_tracker_rawmodel 
                WHERE file_path = ? AND model_coding = ?
            """, (file_path, model_coding))

    def update_row(self, row_id: int, updates: Dict[str, Any]):
        """
        Update a specific row by ID with the provided updates.
        
        Args:
            row_id: The ID of the row to update
            updates: Dictionary of column names and values to update
        """
        if not updates:
            return
        
        # Build the SET clause
        set_clauses = []
        values = []
        for col, val in updates.items():
            set_clauses.append(f"{col} = ?")
            # Convert dicts to JSON strings if necessary
            if isinstance(val, (dict, list)):
                values.append(json.dumps(val, ensure_ascii=False))
            else:
                values.append(val)
        
        # Add update_time
        set_clauses.append("update_time = ?")
        values.append(datetime.now().isoformat())
        values.append(row_id)
        
        sql = f"UPDATE {self.table_name} SET {', '.join(set_clauses)} WHERE id = ?"
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql, values)
