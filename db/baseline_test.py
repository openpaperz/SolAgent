"""
SQLite-based progress tracker for baseline test experiments.
Records test results with gas fees and vulnerability metrics.
"""
import sqlite3
import json
import os
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import contextmanager


class BaselineTest:
    """
    Progress tracker for baseline test experiments.
    Creates progress_tracker_rawmodel table with fields:
    - gas_fee_json: JSON string of gas fees per test method
    - slither_raw: Raw slither detection output as JSON
    - vuln_count: Count of vulnerabilities detected by slither
    """
    
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
        """Initialize database schema for baseline test table."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Create baseline_test table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS baseline_test (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path TEXT NOT NULL,
                    methods INTEGER DEFAULT 0,
                    total_files INTEGER DEFAULT 0,
                    test_pass INTEGER DEFAULT 0,
                    test_fail INTEGER DEFAULT 0,
                    test_total INTEGER DEFAULT 0,
                    gas_fee_json TEXT,
                    slither_raw TEXT,
                    vuln_count INTEGER DEFAULT 0,
                    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(file_path)
                )
            """)

    def get_entry(self, file_path: str) -> Optional[Dict[str, Any]]:
        """
        Get tracking entry for a specific file.
        
        Args:
            file_path: Path to the file being processed
            
        Returns:
            Dictionary with entry data or None if not found
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT * FROM baseline_test 
                WHERE file_path = ?
            """, (file_path,))
            
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None

    def create_or_update_entry(
        self,
        file_path: str,
        methods: int = 0,
        total_files: int = 0,
        test_pass: int = 0,
        test_fail: int = 0,
        test_total: int = 0,
        gas_fee_json: Optional[Dict] = None,
        slither_raw: Optional[Dict] = None,
        vuln_count: int = 0
    ) -> int:
        """
        Create or update a tracking entry.
        
        Args:
            file_path: Path to the file being processed
            methods: Total number of methods in the file
            total_files: Total number of files in dataset
            test_pass: Number of tests passed
            test_fail: Number of tests failed
            test_total: Total number of tests
            gas_fee_json: Dict of gas fees per test method
            slither_raw: Raw slither detection output
            vuln_count: Number of vulnerabilities detected
            
        Returns:
            ID of the created or updated entry
        """
        gas_fee_json_str = json.dumps(gas_fee_json) if gas_fee_json else None
        slither_raw_str = json.dumps(slither_raw) if slither_raw else None
        current_time = datetime.now().isoformat()
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Try to get existing entry
            existing = self.get_entry(file_path)
            
            if existing:
                # Update existing entry
                cursor.execute("""
                    UPDATE baseline_test
                    SET methods = ?,
                        total_files = ?,
                        test_pass = ?,
                        test_fail = ?,
                        test_total = ?,
                        gas_fee_json = ?,
                        slither_raw = ?,
                        vuln_count = ?,
                        update_time = ?
                    WHERE file_path = ?
                """, (
                    methods, total_files,
                    test_pass, test_fail, test_total,
                    gas_fee_json_str, slither_raw_str, vuln_count,
                    current_time, file_path
                ))
                return existing['id']
            else:
                # Create new entry
                cursor.execute("""
                    INSERT INTO baseline_test (
                        file_path, methods, total_files,
                        test_pass, test_fail, test_total,
                        gas_fee_json, slither_raw, vuln_count,
                        create_time, update_time
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    file_path, methods, total_files,
                    test_pass, test_fail, test_total,
                    gas_fee_json_str, slither_raw_str, vuln_count,
                    current_time, current_time
                ))
                return cursor.lastrowid

    def mark_completed(
        self,
        file_path: str,
        methods: int,
        test_pass: int = 0,
        test_fail: int = 0,
        test_total: int = 0,
        gas_fee_json: Optional[Dict] = None,
        slither_raw: Optional[Dict] = None,
        vuln_count: int = 0
    ):
        """
        Mark a file as completed with test results, gas fees, and vulnerability info.
        
        Args:
            file_path: Path to the file
            methods: Total number of methods
            test_pass: Number of tests passed
            test_fail: Number of tests failed
            test_total: Total tests
            gas_fee_json: Dict of gas fees per test method
            slither_raw: Raw slither output
            vuln_count: Number of vulnerabilities
        """
        self.create_or_update_entry(
            file_path=file_path,
            methods=methods,
            test_pass=test_pass,
            test_fail=test_fail,
            test_total=test_total,
            gas_fee_json=gas_fee_json,
            slither_raw=slither_raw,
            vuln_count=vuln_count
        )

    def get_all_entries(self) -> List[Dict[str, Any]]:
        """
        Get all tracking entries.
        
        Returns:
            List of entry dictionaries
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM baseline_test ORDER BY id")
            return [dict(row) for row in cursor.fetchall()]

    def get_stats(self) -> Dict[str, Any]:
        """
        Get overall statistics.
        
        Returns:
            Dictionary with total count
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) as total FROM baseline_test")
            total = cursor.fetchone()['total']
            
            return {
                'total': total
            }

    def reset_entry(self, file_path: str):
        """Reset an entry's data."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE baseline_test 
                SET update_time = ?
                WHERE file_path = ?
            """, (datetime.now().isoformat(), file_path))

    def delete_entry(self, file_path: str):
        """Delete an entry from the database."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM baseline_test 
                WHERE file_path = ?
            """, (file_path,))

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
        
        sql = f"UPDATE baseline_test SET {', '.join(set_clauses)} WHERE id = ?"
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql, values)
