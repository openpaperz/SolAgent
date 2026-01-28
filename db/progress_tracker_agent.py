"""
SQLite-based progress tracker for agent experiments.
Extends rawmodel tracker with agent_type field to distinguish different agent results.
"""
import sqlite3
import json
import os
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import contextmanager


class ProgressTrackerAgent:
    """
    Progress tracker for agent experiments.
    Creates progress_tracker_agent table with additional agent_type field.
    """
    table_name = "progress_tracker_agent"  # Table name for agent tracker
    
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
        """Initialize database schema for agent table."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Create progress_tracker_agent table with agent_type field
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS progress_tracker_agent (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path TEXT NOT NULL,
                    methods INTEGER DEFAULT 0,
                    total_files INTEGER DEFAULT 0,
                    status INTEGER DEFAULT 0,
                    model_coding TEXT,
                    model_summary TEXT,
                    agent_type TEXT,
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
                    UNIQUE(file_path, model_coding, agent_type)
                )
            """)
            
            # Create indexes for faster lookups
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_agent_file_model_type 
                ON progress_tracker_agent(file_path, model_coding, agent_type)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_agent_status 
                ON progress_tracker_agent(status)
            """)

    def create_or_update_entry(
        self,
        file_path: str,
        model_coding: str,
        agent_type: str,
        methods: int = 0,
        total_files: int = 0,
        status: int = 0,
        model_summary: Optional[str] = None,
        start_time: Optional[str] = None
    ):
        """Create or update a progress entry."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT INTO progress_tracker_agent 
                (file_path, model_coding, agent_type, methods, total_files, status, model_summary, start_time, update_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(file_path, model_coding, agent_type) 
                DO UPDATE SET
                    methods = excluded.methods,
                    total_files = excluded.total_files,
                    status = excluded.status,
                    model_summary = excluded.model_summary,
                    start_time = COALESCE(excluded.start_time, start_time),
                    update_time = CURRENT_TIMESTAMP
            """, (file_path, model_coding, agent_type, methods, total_files, status, model_summary, start_time))

    def mark_completed(
        self,
        file_path: str,
        methods: int,
        model_coding: str,
        agent_type: str,
        test_pass: int = 0,
        test_fail: int = 0,
        test_total: int = 0,
        gas_fee_json: Optional[Dict] = None,
        slither_raw: Optional[Dict] = None,
        coding_messages: Optional[List[Dict]] = None,
        vuln_count: int = 0,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_cost: float = 0.0,
        end_time: Optional[str] = None
    ):
        """Mark an entry as completed with results."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Calculate duration if we have start_time
            cursor.execute(
                "SELECT start_time FROM progress_tracker_agent WHERE file_path = ? AND model_coding = ? AND agent_type = ?",
                (file_path, model_coding, agent_type)
            )
            row = cursor.fetchone()
            duration = 0.0
            if row and row['start_time'] and end_time:
                try:
                    start = datetime.fromisoformat(row['start_time'])
                    end = datetime.fromisoformat(end_time)
                    duration = (end - start).total_seconds()
                except Exception:
                    pass
            
            cursor.execute("""
                UPDATE progress_tracker_agent
                SET status = 1,
                    methods = ?,
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
                    end_time = ?,
                    duration = ?,
                    update_time = CURRENT_TIMESTAMP
                WHERE file_path = ? AND model_coding = ? AND agent_type = ?
            """, (
                methods,
                test_pass, test_fail, test_total,
                json.dumps(gas_fee_json) if gas_fee_json else None,
                json.dumps(slither_raw) if slither_raw else None,
                json.dumps(coding_messages) if coding_messages else None,
                vuln_count,
                prompt_tokens, completion_tokens, total_cost,
                end_time, duration,
                file_path, model_coding, agent_type
            ))

    def get_entry(self, file_path: str, model_coding: str, agent_type: str) -> Optional[Dict[str, Any]]:
        """Get a specific entry."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT * FROM progress_tracker_agent WHERE file_path = ? AND model_coding = ? AND agent_type = ?",
                (file_path, model_coding, agent_type)
            )
            row = cursor.fetchone()
            return dict(row) if row else None

    def get_all_entries(self, model_coding: Optional[str] = None, agent_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get all entries, optionally filtered by model and/or agent_type."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            if model_coding and agent_type:
                cursor.execute(
                    "SELECT * FROM progress_tracker_agent WHERE model_coding = ? AND agent_type = ? ORDER BY create_time",
                    (model_coding, agent_type)
                )
            elif model_coding:
                cursor.execute(
                    "SELECT * FROM progress_tracker_agent WHERE model_coding = ? ORDER BY create_time",
                    (model_coding,)
                )
            elif agent_type:
                cursor.execute(
                    "SELECT * FROM progress_tracker_agent WHERE agent_type = ? ORDER BY create_time",
                    (agent_type,)
                )
            else:
                cursor.execute("SELECT * FROM progress_tracker_agent ORDER BY create_time")
            return [dict(row) for row in cursor.fetchall()]

    def get_summary(self, model_coding: Optional[str] = None, agent_type: Optional[str] = None) -> Dict[str, Any]:
        """Get summary statistics."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            where_clause = []
            params = []
            if model_coding:
                where_clause.append("model_coding = ?")
                params.append(model_coding)
            if agent_type:
                where_clause.append("agent_type = ?")
                params.append(agent_type)
            
            where_str = " WHERE " + " AND ".join(where_clause) if where_clause else ""
            
            cursor.execute(f"""
                SELECT 
                    COUNT(*) as total,
                    SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) as completed,
                    SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) as pending,
                    SUM(test_pass) as total_pass,
                    SUM(test_fail) as total_fail,
                    SUM(test_total) as total_tests,
                    SUM(vuln_count) as total_vulns,
                    SUM(prompt_tokens) as total_prompt_tokens,
                    SUM(completion_tokens) as total_completion_tokens,
                    SUM(total_cost) as total_cost,
                    AVG(duration) as avg_duration
                FROM progress_tracker_agent{where_str}
            """, params)
            
            row = cursor.fetchone()
            return dict(row) if row else {}

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
        set_clauses.append("update_time = CURRENT_TIMESTAMP")
        values.append(row_id)
        
        sql = f"UPDATE {self.table_name} SET {', '.join(set_clauses)} WHERE id = ?"
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql, values)
