"""
SQLite-based progress tracker for patch mode agent processing.
Uses a separate table 'progress_tracker_patch' for patch mode results.
"""
from db.progress_tracker import ProgressTracker


class ProgressTrackerPatch(ProgressTracker):
    """
    Progress tracker for patch mode, using a separate table.
    Inherits all functionality from ProgressTracker but uses 'progress_tracker_patch' table.
    """
    table_name = "progress_tracker_patch"  # Table name for patch mode tracker
    
    def _init_db(self):
        """Initialize database schema with patch-specific table."""
        import sqlite3
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS progress_tracker_patch (
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
                    cursor.execute(f"ALTER TABLE progress_tracker_patch ADD COLUMN {col_name} {col_type}")
                except sqlite3.OperationalError:
                    # Column already exists
                    pass

            # Create index for faster lookups
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_patch_file_model 
                ON progress_tracker_patch(file_path, model_coding)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_patch_status 
                ON progress_tracker_patch(status)
            """)

    def get_entry(self, file_path: str, model_coding: str):
        """Get tracking entry for a specific file and model from patch table."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT * FROM progress_tracker_patch 
                WHERE file_path = ? AND model_coding = ?
            """, (file_path, model_coding))
            
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None

    def create_or_update_entry(self, file_path: str, model_coding: str, **kwargs):
        """Create or update entry in patch table."""
        import json
        from datetime import datetime
        
        # Extract all parameters
        methods = kwargs.get('methods', 0)
        total_files = kwargs.get('total_files', 0)
        status = kwargs.get('status', 0)
        rounds = kwargs.get('rounds', 0)
        model_summary = kwargs.get('model_summary')
        test_pass = kwargs.get('test_pass', 0)
        test_fail = kwargs.get('test_fail', 0)
        test_total = kwargs.get('test_total', 0)
        test_json = kwargs.get('test_json')
        gas_fee_json = kwargs.get('gas_fee_json')
        round_gas_fee_json = kwargs.get('round_gas_fee_json')
        slither_raw = kwargs.get('slither_raw')
        round_slither_raw = kwargs.get('round_slither_raw')
        vuln_count = kwargs.get('vuln_count', 0)
        round_vuln_count = kwargs.get('round_vuln_count', 0)
        messages = kwargs.get('messages')
        round_messages = kwargs.get('round_messages')
        coding_messages = kwargs.get('coding_messages')
        prompt_tokens = kwargs.get('prompt_tokens', 0)
        completion_tokens = kwargs.get('completion_tokens', 0)
        total_cost = kwargs.get('total_cost', 0.0)
        summary_prompt_tokens = kwargs.get('summary_prompt_tokens', 0)
        summary_completion_tokens = kwargs.get('summary_completion_tokens', 0)
        summary_cost = kwargs.get('summary_cost', 0.0)
        start_time = kwargs.get('start_time')
        
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
                    cursor.execute("""
                        UPDATE progress_tracker_patch
                        SET methods = ?, total_files = ?, status = ?, rounds = ?,
                            model_summary = ?, test_pass = ?, test_fail = ?, test_total = ?,
                            test_json = ?, gas_fee_json = ?, round_gas_fee_json = ?,
                            slither_raw = ?, round_slither_raw = ?, vuln_count = ?,
                            round_vuln_count = ?, messages = ?, round_messages = ?,
                            coding_messages = ?, prompt_tokens = ?, completion_tokens = ?,
                            total_cost = ?, summary_prompt_tokens = ?, summary_completion_tokens = ?,
                            summary_cost = ?, start_time = ?, end_time = NULL, duration = 0.0,
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
                    cursor.execute("""
                        UPDATE progress_tracker_patch 
                        SET methods = ?, total_files = ?, status = ?, rounds = ?,
                            model_summary = ?, test_pass = ?, test_fail = ?, test_total = ?,
                            test_json = ?, gas_fee_json = ?, round_gas_fee_json = ?,
                            slither_raw = ?, round_slither_raw = ?, vuln_count = ?,
                            round_vuln_count = ?, messages = ?, round_messages = ?,
                            coding_messages = ?, prompt_tokens = ?, completion_tokens = ?,
                            total_cost = ?, summary_prompt_tokens = ?, summary_completion_tokens = ?,
                            summary_cost = ?, update_time = ?
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
                cursor.execute("""
                    INSERT INTO progress_tracker_patch (
                        file_path, methods, total_files, status, rounds,
                        model_coding, model_summary, test_pass, test_fail,
                        test_total, test_json, gas_fee_json, round_gas_fee_json,
                        slither_raw, round_slither_raw, vuln_count, round_vuln_count,
                        messages, round_messages, coding_messages, prompt_tokens, completion_tokens,
                        total_cost, summary_prompt_tokens, summary_completion_tokens,
                        summary_cost, start_time, create_time, update_time
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

    def mark_completed(self, file_path: str, model_coding: str, **kwargs):
        """Mark entry as completed in patch table."""
        from datetime import datetime
        import json
        
        existing = self.get_entry(file_path, model_coding)
        if existing:
            test_json = kwargs.get('test_json')
            rounds = existing.get('rounds', 0)
            
            if test_json:
                if isinstance(test_json, dict):
                    numeric_keys = [int(k) for k in test_json.keys() if str(k).isdigit()]
                    if numeric_keys:
                        rounds = max(numeric_keys)
                    else:
                        rounds = len(test_json)
                elif isinstance(test_json, list):
                    rounds = len(test_json)
            
            end_time = kwargs.get('end_time') or datetime.now().isoformat()
            
            duration = 0.0
            if existing.get('start_time'):
                try:
                    start_dt = datetime.fromisoformat(existing['start_time'])
                    end_dt = datetime.fromisoformat(end_time)
                    duration = (end_dt - start_dt).total_seconds()
                except (ValueError, TypeError):
                    duration = 0.0
            
            messages = kwargs.get('messages')
            round_messages = kwargs.get('round_messages')
            summary_model = kwargs.get('summary_model')
            
            self.create_or_update_entry(
                file_path=file_path,
                model_coding=model_coding,
                methods=kwargs.get('methods', existing.get('methods', 0)),
                total_files=existing.get('total_files', 0),
                status=1,
                rounds=rounds,
                model_summary=summary_model,
                test_pass=kwargs.get('test_pass', 0),
                test_fail=kwargs.get('test_fail', 0),
                test_total=kwargs.get('test_total', 0),
                test_json=test_json,
                gas_fee_json=kwargs.get('gas_fee_json'),
                round_gas_fee_json=kwargs.get('round_gas_fee_json'),
                slither_raw=kwargs.get('slither_raw'),
                round_slither_raw=kwargs.get('round_slither_raw'),
                vuln_count=kwargs.get('vuln_count'),
                round_vuln_count=kwargs.get('round_vuln_count'),
                messages=(messages if messages is not None else existing.get('messages')),
                round_messages=(round_messages if round_messages is not None else existing.get('round_messages')),
                coding_messages=kwargs.get('coding_messages') if kwargs.get('coding_messages') is not None else existing.get('coding_messages'),
                prompt_tokens=kwargs.get('prompt_tokens', 0),
                completion_tokens=kwargs.get('completion_tokens', 0),
                total_cost=kwargs.get('total_cost', 0.0),
                summary_prompt_tokens=kwargs.get('summary_prompt_tokens', 0),
                summary_completion_tokens=kwargs.get('summary_completion_tokens', 0),
                summary_cost=kwargs.get('summary_cost', 0.0)
            )
            
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE progress_tracker_patch 
                    SET end_time = ?, duration = ?
                    WHERE file_path = ? AND model_coding = ?
                """, (end_time, duration, file_path, model_coding))
            
            return existing.get('id')
        return None

    def get_all_entries(self, status=None):
        """Get all entries from patch table."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            if status is not None:
                cursor.execute(
                    "SELECT * FROM progress_tracker_patch WHERE status = ? ORDER BY id",
                    (status,)
                )
            else:
                cursor.execute("SELECT * FROM progress_tracker_patch ORDER BY id")
            
            return [dict(row) for row in cursor.fetchall()]

    def get_stats(self):
        """Get statistics from patch table."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) as total FROM progress_tracker_patch")
            total = cursor.fetchone()['total']
            
            cursor.execute("SELECT COUNT(*) as processed FROM progress_tracker_patch WHERE status = 1")
            processed = cursor.fetchone()['processed']
            
            cursor.execute("SELECT COUNT(*) as unprocessed FROM progress_tracker_patch WHERE status = 0")
            unprocessed = cursor.fetchone()['unprocessed']
            
            return {
                'total': total,
                'processed': processed,
                'unprocessed': unprocessed,
                'completion_rate': (processed / total * 100) if total > 0 else 0
            }

    def reset_entry(self, file_path: str, model_coding: str):
        """Reset entry status in patch table."""
        from datetime import datetime
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE progress_tracker_patch 
                SET status = 0, update_time = ?
                WHERE file_path = ? AND model_coding = ?
            """, (datetime.now().isoformat(), file_path, model_coding))

    def delete_entry(self, file_path: str, model_coding: str):
        """Delete entry from patch table."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM progress_tracker_patch 
                WHERE file_path = ? AND model_coding = ?
            """, (file_path, model_coding))
