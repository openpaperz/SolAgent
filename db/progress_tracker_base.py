"""
Base progress tracker providing common DB operations.
Subclasses should set `table_name` to the target table.
"""
import sqlite3
import json
import os
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import contextmanager


class BaseProgressTracker:
    table_name = ""

    def __init__(self, db_path: str = "output/progress.db"):
        self.db_path = db_path
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self._init_db()

    @contextmanager
    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def _init_db(self):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            # Use table_name variable for creation
            cursor.execute(f"""
                CREATE TABLE IF NOT EXISTS {self.table_name} (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path TEXT NOT NULL,
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
                    UNIQUE(file_path, model_coding)
                )
            """)

            # Add new columns if they don't exist (for database migration)
            alter_statements = [
                ("start_time", "TIMESTAMP"),
                ("end_time", "TIMESTAMP"),
                ("duration", "REAL DEFAULT 0.0"),
                ("gas_fee_json", "TEXT"),
                ("round_gas_fee_json", "TEXT"),
                ("slither_raw", "TEXT"),
                ("round_slither_raw", "TEXT"),
                ("vuln_count", "INTEGER DEFAULT 0"),
                ("round_vuln_count", "INTEGER DEFAULT 0"),
                ("messages", "TEXT"),
                ("round_messages", "TEXT"),
                ("coding_messages", "TEXT"),
                ("prompt_tokens", "INTEGER DEFAULT 0"),
                ("completion_tokens", "INTEGER DEFAULT 0"),
                ("total_cost", "REAL DEFAULT 0.0"),
                ("summary_prompt_tokens", "INTEGER DEFAULT 0"),
                ("summary_completion_tokens", "INTEGER DEFAULT 0"),
                ("summary_cost", "REAL DEFAULT 0.0"),
            ]
            for col_name, col_type in alter_statements:
                try:
                    cursor.execute(f"ALTER TABLE {self.table_name} ADD COLUMN {col_name} {col_type}")
                except sqlite3.OperationalError:
                    # Column already exists
                    pass

            # Create indices
            cursor.execute(f"""
                CREATE INDEX IF NOT EXISTS idx_file_model
                ON {self.table_name}(file_path, model_coding)
            """)
            cursor.execute(f"""
                CREATE INDEX IF NOT EXISTS idx_status
                ON {self.table_name}(status)
            """)

    def get_entry(self, file_path: str, model_coding: str) -> Optional[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM {self.table_name} WHERE file_path = ? AND model_coding = ?", (file_path, model_coding))
            row = cursor.fetchone()
            return dict(row) if row else None

    def create_or_update_entry(
        self,
        file_path: str,
        model_coding: str,
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
            existing = self.get_entry(file_path, model_coding)

            if existing:
                if status == 0:
                    cursor.execute(f"""
                        UPDATE {self.table_name}
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
                        WHERE file_path = ? AND model_coding = ?
                    """, (
                        methods, total_files, status, rounds, model_summary,
                        test_pass, test_fail, test_total, test_json_str,
                        gas_fee_json_str, round_gas_fee_json_str,
                        slither_raw_str, round_slither_raw_str,
                        vuln_count, round_vuln_count_str,
                        messages_str, round_messages_str, coding_messages_str,
                        prompt_tokens, completion_tokens, total_cost,
                        summary_prompt_tokens, summary_completion_tokens, summary_cost,
                        start_time or current_time, current_time, file_path, model_coding
                    ))
                else:
                    cursor.execute(f"""
                        UPDATE {self.table_name}
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
                        WHERE file_path = ? AND model_coding = ?
                    """, (
                        methods, total_files, status, rounds, model_summary,
                        test_pass, test_fail, test_total, test_json_str,
                        gas_fee_json_str, round_gas_fee_json_str,
                        slither_raw_str, round_slither_raw_str,
                        vuln_count, round_vuln_count_str,
                        messages_str, round_messages_str, coding_messages_str,
                        prompt_tokens, completion_tokens, total_cost,
                        summary_prompt_tokens, summary_completion_tokens, summary_cost,
                        current_time, file_path, model_coding
                    ))

                return existing['id']
            else:
                cursor.execute(f"""
                    INSERT INTO {self.table_name} (
                        file_path, methods, total_files, status, rounds,
                        model_coding, model_summary, test_pass, test_fail,
                        test_total, test_json, gas_fee_json, round_gas_fee_json,
                        slither_raw, round_slither_raw, vuln_count, round_vuln_count,
                        messages, round_messages, coding_messages, prompt_tokens, completion_tokens,
                        total_cost, summary_prompt_tokens, summary_completion_tokens,
                        summary_cost, start_time, create_time, update_time
                        ) VALUES ({', '.join(['?']*29)})
                """, (
                    file_path, methods, total_files, status, rounds,
                    model_coding, model_summary, test_pass, test_fail,
                    test_total, test_json_str, gas_fee_json_str, round_gas_fee_json_str,
                    slither_raw_str, round_slither_raw_str, vuln_count, round_vuln_count_str,
                    messages_str, round_messages_str, coding_messages_str, prompt_tokens, completion_tokens,
                    total_cost, summary_prompt_tokens, summary_completion_tokens,
                    summary_cost, start_time or current_time, current_time, current_time
                ))
                return cursor.lastrowid

    def mark_completed(self,
        file_path: str,
        model_coding: str,
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
        existing = self.get_entry(file_path, model_coding)
        rounds = 0
        if existing:
            if test_json:
                if isinstance(test_json, dict):
                    numeric_keys = [int(k) for k in test_json.keys() if str(k).isdigit()]
                    if numeric_keys:
                        rounds = max(numeric_keys)
                    else:
                        rounds = len(test_json)
                elif isinstance(test_json, list):
                    rounds = len(test_json)

            end_time = end_time or datetime.now().isoformat()

            duration = 0.0
            if existing.get('start_time'):
                try:
                    start_dt = datetime.fromisoformat(existing['start_time'])
                    end_dt = datetime.fromisoformat(end_time)
                    duration = (end_dt - start_dt).total_seconds()
                except (ValueError, TypeError):
                    duration = 0.0

            self.create_or_update_entry(
                file_path=file_path,
                model_coding=model_coding,
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
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(f"UPDATE {self.table_name} SET end_time = ?, duration = ? WHERE file_path = ? AND model_coding = ?", (end_time, duration, file_path, model_coding))
            return existing.get('id')
        return None

    def get_all_entries(self, status: Optional[int] = None) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            if status is not None:
                cursor.execute(f"SELECT * FROM {self.table_name} WHERE status = ? ORDER BY id", (status,))
            else:
                cursor.execute(f"SELECT * FROM {self.table_name} ORDER BY id")
            return [dict(row) for row in cursor.fetchall()]

    def get_stats(self) -> Dict[str, Any]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT COUNT(*) as total FROM {self.table_name}")
            total = cursor.fetchone()['total']
            cursor.execute(f"SELECT COUNT(*) as processed FROM {self.table_name} WHERE status = 1")
            processed = cursor.fetchone()['processed']
            cursor.execute(f"SELECT COUNT(*) as unprocessed FROM {self.table_name} WHERE status = 0")
            unprocessed = cursor.fetchone()['unprocessed']
            return {
                'total': total,
                'processed': processed,
                'unprocessed': unprocessed,
                'completion_rate': (processed / total * 100) if total > 0 else 0
            }

    def reset_entry(self, file_path: str, model_coding: str):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE {self.table_name} SET status = 0, update_time = ? WHERE file_path = ? AND model_coding = ?", (datetime.now().isoformat(), file_path, model_coding))

    def delete_entry(self, file_path: str, model_coding: str):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"DELETE FROM {self.table_name} WHERE file_path = ? AND model_coding = ?", (file_path, model_coding))

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
