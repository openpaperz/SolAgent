import sqlite3
import threading
from datetime import datetime
from typing import Optional, Dict, List, Any

class SummaryTracker:
    """
    Tracks file summaries in a SQLite database.
    """
    _local = threading.local()

    def __init__(self, db_path: str = "summary.db"):
        self.db_path = db_path
        self._init_db()

    def _get_connection(self):
        """Get thread-local database connection."""
        if not hasattr(self._local, "conn"):
            self._local.conn = sqlite3.connect(self.db_path)
            self._local.conn.row_factory = sqlite3.Row
        return self._local.conn

    def _init_db(self):
        """Initialize database schema."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS summary (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path TEXT NOT NULL UNIQUE,
                    summary_text TEXT,
                    model_name TEXT,
                    prompt_tokens INTEGER DEFAULT 0,
                    completion_tokens INTEGER DEFAULT 0,
                    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Add new columns if they don't exist (for database migration)
            alter_statements = [
                ("model_name", "TEXT"),
                ("prompt_tokens", "INTEGER DEFAULT 0"),
                ("completion_tokens", "INTEGER DEFAULT 0"),
            ]
            for col_name, col_type in alter_statements:
                try:
                    cursor.execute(f"ALTER TABLE summary ADD COLUMN {col_name} {col_type}")
                except sqlite3.OperationalError:
                    pass
            
            conn.commit()

    def add_or_update_summary(
        self, 
        file_path: str, 
        summary_text: str,
        model_name: Optional[str] = None,
        prompt_tokens: int = 0,
        completion_tokens: int = 0
    ) -> int:
        """
        Add a new summary or update an existing one.
        
        Args:
            file_path: Unique path of the file
            summary_text: The summary content
            model_name: Name of the model used
            prompt_tokens: Number of prompt tokens
            completion_tokens: Number of completion tokens
            
        Returns:
            ID of the row
        """
        current_time = datetime.now().isoformat()
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Check if exists
            cursor.execute("SELECT id FROM summary WHERE file_path = ?", (file_path,))
            row = cursor.fetchone()
            
            if row:
                # Update
                cursor.execute("""
                    UPDATE summary 
                    SET summary_text = ?, 
                        model_name = ?,
                        prompt_tokens = ?,
                        completion_tokens = ?,
                        update_time = ?
                    WHERE file_path = ?
                """, (summary_text, model_name, prompt_tokens, completion_tokens, current_time, file_path))
                return row['id']
            else:
                # Insert
                cursor.execute("""
                    INSERT INTO summary (
                        file_path, summary_text, model_name, 
                        prompt_tokens, completion_tokens, 
                        create_time, update_time
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    file_path, summary_text, model_name, 
                    prompt_tokens, completion_tokens, 
                    current_time, current_time
                ))
                return cursor.lastrowid

    def get_summary(self, file_path: str) -> Optional[str]:
        """Get summary for a file."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT summary_text FROM summary WHERE file_path = ?", (file_path,))
            row = cursor.fetchone()
            if row:
                return row['summary_text']
            return None
    
    def get_summary_by_file_and_model(self, file_path: str, model_name: str) -> Optional[str]:
        """
        Get summary for a file by file_path and model_name.
        
        Args:
            file_path: Unique path of the file
            model_name: Name of the model used
            
        Returns:
            Summary text if found, None otherwise
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT summary_text FROM summary WHERE file_path = ? AND model_name = ?",
                (file_path, model_name)
            )
            row = cursor.fetchone()
            if row:
                return row['summary_text']
            return None

    def get_summary_id_by_file_and_model(self, file_path: str, model_name: str) -> Optional[int]:
        """
        Return the summary table primary key id for a given file_path and model_name.
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id FROM summary WHERE file_path = ? AND model_name = ?",
                (file_path, model_name)
            )
            row = cursor.fetchone()
            if row:
                return int(row['id'])
            return None

    def close(self):
        """Close thread-local connection."""
        if hasattr(self._local, "conn"):
            self._local.conn.close()
            del self._local.conn
