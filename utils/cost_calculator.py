"""
Cost calculation utilities for tracking LLM usage costs.

This module intentionally does NOT perform token estimation. If messages
or responses do not include explicit token counts (e.g. prompt_tokens,
completion_tokens or usage fields), the counts remain zero.
"""
import json
import os
import sqlite3
from typing import Dict, Any, Tuple, Optional, List

from db.progress_tracker import ProgressTracker
from db.progress_tracker_agent import ProgressTrackerAgent
from db.progress_tracker_rawmodel import ProgressTrackerRawModel
try:
    from ms_agent.llm.utils import Message
except ImportError:
    Message = dict
from datetime import datetime, timedelta


class CostCalculator:
    def __init__(self, price_file: str = "data/price.json"):
        """
        Initialize cost calculator with pricing data.

        Args:
            price_file: Path to the JSON file containing model pricing
        """
        self.price_file = price_file
        self.prices = self._load_prices()

    def _load_prices(self) -> Dict[str, Any]:
        """Load pricing information from JSON file."""
        if not os.path.exists(self.price_file):
            # No prices available; callers should handle zero-cost gracefully
            print(f"Warning: Price file not found at {self.price_file}")
            return {}

        with open(self.price_file, "r", encoding="utf-8") as f:
            return json.load(f)

    def get_model_price(self, model_name: str) -> Dict[str, Any]:
        """
        Get pricing for a specific model.

        Returns dict with keys: 'prompt' (per 1K tokens), 'complete' (per 1K tokens), 'currency'.
        If model not found, returns zeros.
        """
        # Exact match
        if model_name in self.prices:
            pricing = self.prices[model_name]
            return {
                'prompt': pricing.get('prompt', 0.0),
                'complete': pricing.get('complete', 0.0),
                'currency': pricing.get('currency', 'USD')
            }

        # Partial match
        for key, pricing in self.prices.items():
            if key in model_name or model_name in key:
                return {
                    'prompt': pricing.get('prompt', 0.0),
                    'complete': pricing.get('complete', 0.0),
                    'currency': pricing.get('currency', 'USD')
                }

        # Unknown model -> zero pricing
        return {'prompt': 0.0, 'complete': 0.0, 'currency': 'USD'}

    def calculate_cost(self, model_name: str, prompt_tokens: int, completion_tokens: int) -> float:
        """
        Calculate total cost (in model's currency) from token counts.
        Prices in `data/price.json` are per 1000 tokens.
        """
        pricing = self.get_model_price(model_name)
        # pricing values are stored as price per 100 tokens, so divide tokens by 100
        prompt_cost = (prompt_tokens / 1000.0) * pricing.get('prompt', 0.0)
        completion_cost = (completion_tokens / 1000.0) * pricing.get('complete', 0.0)
        return prompt_cost + completion_cost

    def extract_tokens_from_messages(self, messages: List[Message], model_name: str) -> Tuple[int, int, float]:
        """
        Extract token counts from a list of Message objects and compute cost.

        Rules (per user request):
        - Prefer explicit fields: message.prompt_tokens, message.completion_tokens
        - Or `message.usage` dict with keys 'prompt_tokens'/'completion_tokens'
        - Do NOT attempt any estimation for messages lacking token metadata; counts remain 0
        """
        total_prompt = 0
        total_completion = 0

        for m in messages:
            # message objects coming from the agent may expose .prompt_tokens/.completion_tokens
            if hasattr(m, 'prompt_tokens') and hasattr(m, 'completion_tokens'):
                total_prompt += (getattr(m, 'prompt_tokens') or 0)
                total_completion += (getattr(m, 'completion_tokens') or 0)
            elif 'prompt_tokens' in m and 'completion_tokens' in m:
                total_prompt += m.get('prompt_tokens', 0)
                total_completion += m.get('completion_tokens', 0)

        total_cost = self.calculate_cost(model_name, total_prompt, total_completion)
        return total_prompt, total_completion, total_cost

    def calculate_summary_cost(self, summary_model: str, input_obj: Any, output_obj: Any) -> Tuple[int, int, float]:
        """
        Calculate cost for summary generation.

        Behavior:
        - If `input_obj` is a list of Message objects, extract tokens via
          `extract_tokens_from_messages`.
        - If `input_obj`/`output_obj` are plain strings, do NOT estimate tokens
          (per user request) and return zeros.
        """
        if isinstance(input_obj, list):
            p, c, cost = self.extract_tokens_from_messages(input_obj, summary_model)
            return p, c, cost

        # Plain strings or other types: do not estimate
        return 0, 0, 0.0

    def _convert_currency_to_usd(self, amount: float, currency: str, rmb_to_usd: Optional[float] = None) -> float:
        """
        Convert a monetary amount to USD.

        Rules:
        - If currency is already USD, return amount.
        - If currency is RMB, convert using provided rmb_to_usd or environment variable RMB_TO_USD or a reasonable default.
        - For unknown currencies, assume USD (no conversion).
        """
        if amount is None:
            return 0.0
        if currency is None:
            return float(amount)
        currency = str(currency).upper()
        if currency == 'USD':
            return float(amount)
        if currency in ('RMB', 'CNY', '￥', '¥'):
            try:
                if rmb_to_usd is None:
                    rmb_to_usd = float(os.environ.get('RMB_TO_USD', '0.14'))
                return float(amount) * float(rmb_to_usd)
            except Exception:
                return float(amount) * 0.14
        try:
            return float(amount)
        except Exception:
            return 0.0

    def get_recent_spend_usd(self, progress_db_path: str, days: int = 7, rmb_to_usd: Optional[float] = None, table_name: str = "process_tracking") -> Tuple[float, Dict[str, float]]:
        """
        Compute total spend in the last `days` days (based on end_time column) in USD.

        This recomputes costs per-row using token counts and the pricing in `data/price.json`.

        Returns (total_usd, breakdown_by_currency) where breakdown_by_currency is a dict like {'USD': x, 'RMB': y}
        (breakdown contains raw sums in their original currencies before conversion for debugging).
        """
        if not os.path.exists(progress_db_path):
            return 0.0, {}

        cutoff_dt = datetime.now() - timedelta(days=days)
        cutoff_iso = cutoff_dt.isoformat()

        conn = sqlite3.connect(progress_db_path)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        # Validate table_name to prevent SQL injection (basic check)
        if not table_name.isidentifier():
            raise ValueError(f"Invalid table name: {table_name}")

        cur.execute(f"""
            SELECT file_path, model_coding, model_summary, prompt_tokens, completion_tokens,
                   summary_prompt_tokens, summary_completion_tokens, end_time
            FROM {table_name}
            WHERE end_time IS NOT NULL AND end_time >= ?
        """, (cutoff_iso,))

        rows = cur.fetchall()
        conn.close()

        total_usd = 0.0
        breakdown = {}

        for r in rows:
            model = r['model_coding'] or ''
            summary_model = r['model_summary'] or ''
            p_tokens = int(r['prompt_tokens'] or 0)
            c_tokens = int(r['completion_tokens'] or 0)
            sp_tokens = int(r['summary_prompt_tokens'] or 0)
            sc_tokens = int(r['summary_completion_tokens'] or 0)

            # Use calculate_cost to compute costs consistently (prices are per 1000 tokens)
            code_pricing = self.get_model_price(model)
            code_cost = self.calculate_cost(model, p_tokens, c_tokens)
            code_currency = code_pricing.get('currency', 'USD')

            summary_cost = 0.0
            summary_currency = 'USD'
            if summary_model:
                summ_pricing = self.get_model_price(summary_model)
                summary_cost = self.calculate_cost(summary_model, sp_tokens, sc_tokens)
                summary_currency = summ_pricing.get('currency', 'USD')

            breakdown[code_currency] = breakdown.get(code_currency, 0.0) + float(code_cost)
            breakdown[summary_currency] = breakdown.get(summary_currency, 0.0) + float(summary_cost)

            total_usd += self._convert_currency_to_usd(code_cost, code_currency, rmb_to_usd)
            total_usd += self._convert_currency_to_usd(summary_cost, summary_currency, rmb_to_usd)

        return total_usd, breakdown

    def check_and_pause_if_threshold(self, progress_db_path: str, days: int = 7, threshold_usd: Optional[float] = None, rmb_to_usd: Optional[float] = None, table_name: str = "process_tracking") -> Tuple[bool, float, Dict[str, float]]:
        """
        Convenience wrapper: compute recent spend and return (should_pause, total_usd, breakdown).
        The default threshold is read from environment variable COST_BUDGET (float), falling back to 100.0 if unset/invalid.
        should_pause is True if total_usd >= threshold_usd.
        """
        # Resolve threshold from env if not provided explicitly
        if threshold_usd is None:
            env_budget = os.environ.get("COST_BUDGET")
            try:
                threshold_usd = float(env_budget) if env_budget is not None else 100.0
            except (TypeError, ValueError):
                threshold_usd = 100.0

        total_usd, breakdown = self.get_recent_spend_usd(progress_db_path, days=days, rmb_to_usd=rmb_to_usd, table_name=table_name)
        should_pause = float(total_usd) >= float(threshold_usd)
        return should_pause, float(total_usd), breakdown


def format_cost_report(
    model_name: str,
    prompt_tokens: int,
    completion_tokens: int,
    total_cost: float,
    summary_model: Optional[str] = None,
    summary_prompt_tokens: int = 0,
    summary_completion_tokens: int = 0,
    summary_cost: float = 0.0,
) -> str:
    """Return a human-readable multi-line cost report."""
    out = []
    out.append("=== Cost Report ===")
    out.append(f"Model: {model_name}")
    out.append(f"  Prompt tokens: {prompt_tokens:,}")
    out.append(f"  Completion tokens: {completion_tokens:,}")
    out.append(f"  Total tokens: {prompt_tokens + completion_tokens:,}")
    out.append(f"  Cost: {total_cost:.6f}")

    if summary_model and summary_cost > 0:
        out.append("")
        out.append(f"Summary Model: {summary_model}")
        out.append(f"  Prompt tokens: {summary_prompt_tokens:,}")
        out.append(f"  Completion tokens: {summary_completion_tokens:,}")
        out.append(f"  Total tokens: {summary_prompt_tokens + summary_completion_tokens:,}")
        out.append(f"  Cost: {summary_cost:.6f}")
        out.append("")
        out.append(f"Grand Total Cost: {total_cost + summary_cost:.6f}")

    return "\n".join(out)

def check_cost_pause(
    cost_calculator: CostCalculator,
    tracker: ProgressTrackerRawModel | ProgressTrackerAgent | ProgressTracker,
    days: int = 7,
    table_name: str = "progress_tracker_rawmodel",
):
    env_budget = os.environ.get("COST_BUDGET")
    try:
        should_pause, recent_usd, breakdown = cost_calculator.check_and_pause_if_threshold(
            tracker.db_path, days=days, table_name=table_name
        )
        if should_pause:
            print(f"[PAUSE] Recent {days}-day spend ${recent_usd:.2f} >= ${env_budget}. Breakdown: {breakdown}")
            return True
    except Exception as e:
        print(f"Warning: failed to perform recent spend check: {e}")
    return False

