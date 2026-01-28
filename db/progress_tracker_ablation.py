import sqlite3
import json
import os
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import contextmanager
from db.progress_tracker import ProgressTracker


class ProgressTrackerAblation(ProgressTracker):
    """
    Progress tracker for ablation experiments.
    Inherits all fields from ProgressTracker and adds ablation_type field.
    Unique key: (file_path, model_coding, ablation_type)
    """
    table_name = "process_tracking_ablation"  # Table name for ablation tracker
    
    def __init__(self, db_path: str = "output/progress.db"):
        """Initialize the progress tracker with SQLite database."""
        self.db_path = db_path
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self._init_db()

    def _init_db(self):
        """Initialize database schema with ablation_type field."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            # Create table identical to process_tracking but with ablation_type field
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS process_tracking_ablation (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path TEXT NOT NULL,
                    ablation_type INTEGER NOT NULL,
                    methods INTEGER DEFAULT 0,
                    total_files INTEGER DEFAULT 0,
                    status INTEGER DEFAULT 0,
                    rounds INTEGER DEFAULT 0,
                    model_coding TEXT,
                    model_summary TEXT,
                    test_pass INTEGER DEFAULT 0,
                    test_fail INTEGER DEFAULT 0,
                    test_total INTEGER DEFAULT 0,
                    test_json TEXT,
                    gas_fee_json TEXT,
                    round_gas_fee_json TEXT,
                    slither_raw TEXT,
                    round_slither_raw TEXT,
                    vuln_count INTEGER DEFAULT 0,
                    round_vuln_count INTEGER DEFAULT 0,
                    messages TEXT,
                    round_messages TEXT,
                    coding_messages TEXT,
                    prompt_tokens INTEGER DEFAULT 0,
                    completion_tokens INTEGER DEFAULT 0,
                    total_cost REAL DEFAULT 0.0,
                    summary_prompt_tokens INTEGER DEFAULT 0,
                    summary_completion_tokens INTEGER DEFAULT 0,
                    summary_cost REAL DEFAULT 0.0,
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    duration REAL DEFAULT 0.0,
                    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(file_path, model_coding, ablation_type)
                )
            """)
            
            # Create indexes for faster lookups
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_file_model_ablation 
                ON process_tracking_ablation(file_path, model_coding, ablation_type)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_status_ablation 
                ON process_tracking_ablation(status)
            """)

    def get_entry(self, file_path: str, model_coding: str, ablation_type: int) -> Optional[Dict[str, Any]]:
        """
        Get tracking entry for a specific file, model, and ablation type.
        
        Args:
            file_path: Path to the file being processed
            model_coding: Name of the code model being used
            ablation_type: Type of ablation experiment
            
        Returns:
            Dictionary with entry data or None if not found
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT * FROM process_tracking_ablation 
                WHERE file_path = ? AND model_coding = ? AND ablation_type = ?
            """, (file_path, model_coding, ablation_type))
            
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None

    def create_or_update_entry(
        self,
        file_path: str,
        model_coding: str,
        ablation_type: int,
        methods: int = 0,
        total_files: int = 0,
        status: int = 0,
        rounds: int = 0,
        model_summary: Optional[str] = None,
        test_pass: int = 0,
        test_fail: int = 0,
        test_total: int = 0,
        test_json: Optional[Dict] = None,
        gas_fee_json: Optional[Dict] = None,
        round_gas_fee_json: Optional[Dict] = None,
        slither_raw: Optional[Dict] = None,
        round_slither_raw: Optional[Dict] = None,
        vuln_count: int = 0,
        round_vuln_count: int = 0,
        messages: Optional[Dict] = None,
        round_messages: Optional[Dict] = None,
        coding_messages: Optional[Dict] = None,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_cost: float = 0.0,
        summary_prompt_tokens: int = 0,
        summary_completion_tokens: int = 0,
        summary_cost: float = 0.0,
        start_time: Optional[str] = None
    ) -> int:
        """
        Create or update a tracking entry with ablation_type.
        
        Args:
            Same as ProgressTracker.create_or_update_entry, plus:
            ablation_type: Type of ablation experiment (int)
            
        Returns:
            ID of the created or updated entry
        """
        test_json_str = json.dumps(test_json) if test_json else None
        gas_fee_json_str = json.dumps(gas_fee_json) if gas_fee_json else None
        round_gas_fee_json_str = json.dumps(round_gas_fee_json) if round_gas_fee_json else None
        slither_raw_str = json.dumps(slither_raw) if slither_raw else None
        round_slither_raw_str = json.dumps(round_slither_raw) if round_slither_raw else None
        round_vuln_count_str = json.dumps(round_vuln_count) if round_vuln_count else None
        messages_str = json.dumps(messages) if messages else None
        round_messages_str = json.dumps(round_messages) if round_messages else None
        coding_messages_str = json.dumps(coding_messages) if coding_messages else None
        current_time = datetime.now().isoformat()
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Try to get existing entry
            existing = self.get_entry(file_path, model_coding, ablation_type)
            
            if existing:
                # Update existing entry
                if status == 0:
                    # Overwrite start_time for a new run; clear end_time and duration
                    cursor.execute("""
                        UPDATE process_tracking_ablation
                        SET methods = ?,
                            total_files = ?,
                            status = ?,
                            rounds = ?,
                            model_summary = ?,
                            test_pass = ?,
                            test_fail = ?,
                            test_total = ?,
                            test_json = ?,
                            gas_fee_json = ?,
                            round_gas_fee_json = ?,
                            slither_raw = ?,
                            round_slither_raw = ?,
                            vuln_count = ?,
                            round_vuln_count = ?,
                            messages = ?,
                            round_messages = ?,
                            coding_messages = ?,
                            prompt_tokens = ?,
                            completion_tokens = ?,
                            total_cost = ?,
                            summary_prompt_tokens = ?,
                            summary_completion_tokens = ?,
                            summary_cost = ?,
                            start_time = ?,
                            end_time = NULL,
                            duration = 0.0,
                            update_time = ?
                        WHERE file_path = ? AND model_coding = ? AND ablation_type = ?
                    """, (
                        methods, total_files, status, rounds, model_summary,
                        test_pass, test_fail, test_total, test_json_str,
                        gas_fee_json_str, round_gas_fee_json_str,
                        slither_raw_str, round_slither_raw_str,
                        vuln_count, round_vuln_count_str,
                        messages_str, round_messages_str, coding_messages_str,
                        prompt_tokens, completion_tokens, total_cost,
                        summary_prompt_tokens, summary_completion_tokens, summary_cost,
                        start_time or current_time, current_time, 
                        file_path, model_coding, ablation_type
                    ))
                else:
                    # Keep existing start_time for non-new runs
                    cursor.execute("""
                        UPDATE process_tracking_ablation
                        SET methods = ?,
                            total_files = ?,
                            status = ?,
                            rounds = ?,
                            model_summary = ?,
                            test_pass = ?,
                            test_fail = ?,
                            test_total = ?,
                            test_json = ?,
                            gas_fee_json = ?,
                            round_gas_fee_json = ?,
                            slither_raw = ?,
                            round_slither_raw = ?,
                            vuln_count = ?,
                            round_vuln_count = ?,
                            messages = ?,
                            round_messages = ?,
                            coding_messages = ?,
                            prompt_tokens = ?,
                            completion_tokens = ?,
                            total_cost = ?,
                            summary_prompt_tokens = ?,
                            summary_completion_tokens = ?,
                            summary_cost = ?,
                            update_time = ?
                        WHERE file_path = ? AND model_coding = ? AND ablation_type = ?
                    """, (
                        methods, total_files, status, rounds, model_summary,
                        test_pass, test_fail, test_total, test_json_str,
                        gas_fee_json_str, round_gas_fee_json_str,
                        slither_raw_str, round_slither_raw_str,
                        vuln_count, round_vuln_count_str,
                        messages_str, round_messages_str, coding_messages_str,
                        prompt_tokens, completion_tokens, total_cost,
                        summary_prompt_tokens, summary_completion_tokens, summary_cost,
                        current_time, file_path, model_coding, ablation_type
                    ))

                return existing['id']
            else:
                # Create new entry
                cursor.execute("""
                    INSERT INTO process_tracking_ablation (
                        file_path, ablation_type, methods, total_files, status, rounds,
                        model_coding, model_summary, test_pass, test_fail,
                        test_total, test_json, gas_fee_json, round_gas_fee_json,
                        slither_raw, round_slither_raw, vuln_count, round_vuln_count,
                        messages, round_messages, coding_messages, prompt_tokens, completion_tokens,
                        total_cost, summary_prompt_tokens, summary_completion_tokens,
                        summary_cost, start_time, create_time, update_time
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    file_path, ablation_type, methods, total_files, status, rounds,
                    model_coding, model_summary, test_pass, test_fail,
                    test_total, test_json_str, gas_fee_json_str, round_gas_fee_json_str,
                    slither_raw_str, round_slither_raw_str, vuln_count, round_vuln_count_str,
                    messages_str, round_messages_str, coding_messages_str, prompt_tokens, completion_tokens,
                    total_cost, summary_prompt_tokens, summary_completion_tokens,
                    summary_cost, start_time or current_time, current_time, current_time
                ))
                return cursor.lastrowid

    def mark_completed(
        self,
        file_path: str,
        model_coding: str,
        ablation_type: int,
        methods: Optional[int] = None,
        test_pass: int = 0,
        test_fail: int = 0,
        test_total: int = 0,
        test_json: Optional[Dict] = None,
        gas_fee_json: Optional[Dict] = None,
        round_gas_fee_json: Optional[Dict] = None,
        slither_raw: Optional[Dict] = None,
        round_slither_raw: Optional[Dict] = None,
        vuln_count: Optional[int] = None,
        round_vuln_count: Optional[Dict] = None,
        messages: Optional[Dict] = None,
        round_messages: Optional[Dict] = None,
        coding_messages: Optional[Dict] = None,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_cost: float = 0.0,
        summary_model: Optional[str] = None,
        summary_prompt_tokens: int = 0,
        summary_completion_tokens: int = 0,
        summary_cost: float = 0.0,
        end_time: Optional[str] = None
    ):
        """
        Mark a file as completed with test results and cost information.
        
        Args:
            Same as ProgressTracker.mark_completed, plus:
            ablation_type: Type of ablation experiment
        """
        existing = self.get_entry(file_path, model_coding, ablation_type)
        if existing:
            # Calculate rounds from test_json
            rounds = 0
            if test_json:
                if isinstance(test_json, dict):
                    numeric_keys = [int(k) for k in test_json.keys() if str(k).isdigit()]
                    if numeric_keys:
                        rounds = max(numeric_keys)
                    else:
                        # if dict but keys not numeric, treat number of items as rounds
                        rounds = len(test_json)
                elif isinstance(test_json, list):
                    rounds = len(test_json)
            
            end_time = end_time or datetime.now().isoformat()
            
            # Calculate duration if start_time exists
            duration = 0.0
            if existing.get('start_time'):
                try:
                    start = datetime.fromisoformat(existing['start_time'])
                    end = datetime.fromisoformat(end_time)
                    duration = (end - start).total_seconds()
                except (ValueError, TypeError):
                    pass
            
            # Update entry with completion data
            self.create_or_update_entry(
                file_path=file_path,
                model_coding=model_coding,
                ablation_type=ablation_type,
                methods=methods if methods is not None else existing.get('methods', 0),
                total_files=existing.get('total_files', 0),
                status=1,
                rounds=rounds,
                model_summary=summary_model,
                test_pass=test_pass,
                test_fail=test_fail,
                test_total=test_total,
                test_json=test_json,
                gas_fee_json=gas_fee_json,
                round_gas_fee_json=round_gas_fee_json,
                slither_raw=slither_raw,
                round_slither_raw=round_slither_raw,
                vuln_count=vuln_count,
                round_vuln_count=round_vuln_count,
                messages=(messages if messages is not None else existing.get('messages')),
                round_messages=(round_messages if round_messages is not None else existing.get('round_messages')),
                coding_messages=(coding_messages if coding_messages is not None else existing.get('coding_messages')),
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_cost=total_cost,
                summary_prompt_tokens=summary_prompt_tokens,
                summary_completion_tokens=summary_completion_tokens,
                summary_cost=summary_cost
            )
            # Update end_time and duration separately
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE process_tracking_ablation 
                    SET end_time = ?, duration = ?
                    WHERE file_path = ? AND model_coding = ? AND ablation_type = ?
                """, (end_time, duration, file_path, model_coding, ablation_type))
            return existing.get('id')
        return None

    def get_all_entries(self, status: Optional[int] = None, ablation_type: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Get all tracking entries, optionally filtered by status and/or ablation_type.
        
        Args:
            status: Filter by status (0 or 1), None for all
            ablation_type: Filter by ablation type, None for all
            
        Returns:
            List of entry dictionaries
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            query = "SELECT * FROM process_tracking_ablation WHERE 1=1"
            params = []
            
            if status is not None:
                query += " AND status = ?"
                params.append(status)
            
            if ablation_type is not None:
                query += " AND ablation_type = ?"
                params.append(ablation_type)
            
            query += " ORDER BY id"
            
            cursor.execute(query, params)
            return [dict(row) for row in cursor.fetchall()]

    def reset_entry(self, file_path: str, model_coding: str, ablation_type: int):
        """Reset an entry's status to unprocessed."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE process_tracking_ablation 
                SET status = 0, update_time = ?
                WHERE file_path = ? AND model_coding = ? AND ablation_type = ?
            """, (datetime.now().isoformat(), file_path, model_coding, ablation_type))

    def delete_entry(self, file_path: str, model_coding: str, ablation_type: int):
        """Delete an entry from the database."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM process_tracking_ablation 
                WHERE file_path = ? AND model_coding = ? AND ablation_type = ?
            """, (file_path, model_coding, ablation_type))
