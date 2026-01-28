#!/usr/bin/env python3
"""
Token Pruning Analysis: Calculate token reduction ratio in refine process.

This script analyzes the token pruning effect for TARGET_MODELS by comparing
the original round_messages with a reconstructed pre-pruning version.

Usage:
    python stats/ex_prune_token.py --db output/progress.db
"""
import argparse
import sys
import os
import json
from typing import Dict, List, Any

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from db.progress_tracker import ProgressTracker

TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]


def serialize_message(msg: Any) -> str:
    """Serialize a message to string for comparison."""
    if isinstance(msg, dict):
        return json.dumps(msg, sort_keys=True, ensure_ascii=False)
    elif isinstance(msg, str):
        return msg
    else:
        return str(msg)


def reconstruct_preprune_messages(round_messages: Dict[str, List[Any]]) -> Dict[str, List[Any]]:
    """
    Reconstruct pre-pruning messages using incremental accumulation.
    
    This simplified approach assumes that pre-pruning state should include
    all unique messages from previous rounds plus current round messages.
    
    Args:
        round_messages: Dict mapping round number (as string) to list of messages
    
    Returns:
        Dict mapping round number to reconstructed pre-pruning messages
    """
    if not round_messages:
        return {}
    
    preprune_round_messages = {}
    
    # Get sorted round numbers
    rounds = sorted([int(r) for r in round_messages.keys() if str(r).isdigit()])
    
    if not rounds:
        return {}
    
    # Track all seen messages across rounds using hash-based deduplication
    accumulated_msgs = {}  # role_type -> {hash: msg}
    
    for round_num in rounds:
        round_key = str(round_num)
        current_messages = round_messages.get(round_key, [])
        
        if not current_messages or len(current_messages) < 3:
            preprune_round_messages[round_key] = current_messages.copy()
            continue
        
        # Start with first two messages (system and user) - always fresh
        reconstructed = current_messages[:2].copy()
        
        # Process messages from index 2 onwards
        current_round_msgs = current_messages[2:]
        
        # Add all accumulated messages from previous rounds that aren't in current round
        for msg_hash, msg in accumulated_msgs.items():
            # Check if this message is in current round by hash
            found_in_current = False
            for curr_msg in current_round_msgs:
                if hash(serialize_message(curr_msg)) == msg_hash:
                    found_in_current = True
                    break
            
            if not found_in_current:
                reconstructed.append(msg)
        
        # Add current round messages and update accumulated messages
        for msg in current_round_msgs:
            if isinstance(msg, dict):
                msg_hash = hash(serialize_message(msg))
                accumulated_msgs[msg_hash] = msg
                reconstructed.append(msg)
        
        preprune_round_messages[round_key] = reconstructed
    
    return preprune_round_messages


def calculate_token_approximation(messages: List[Any]) -> int:
    """
    Calculate approximate token count by summing string lengths of all messages.
    
    Args:
        messages: List of messages
    
    Returns:
        Approximate token count (sum of string lengths)
    """
    total_length = 0
    for msg in messages:
        msg_str = serialize_message(msg)
        total_length += len(msg_str)
    return total_length


def calculate_round_tokens(round_messages: Dict[str, List[Any]]) -> Dict[str, int]:
    """
    Calculate approximate token count for each round.
    
    Args:
        round_messages: Dict mapping round number to list of messages
    
    Returns:
        Dict mapping round number to approximate token count
    """
    round_tokens = {}
    for round_key, messages in round_messages.items():
        round_tokens[round_key] = calculate_token_approximation(messages)
    return round_tokens


def analyze_pruning_effect(db_path: str, model: str) -> Dict[str, Any]:
    """
    Analyze token pruning effect for a specific model.
    
    Args:
        db_path: Path to the database
        model: Model name
    
    Returns:
        Dictionary containing pruning statistics
    """
    tracker = ProgressTracker(db_path)
    all_rows = tracker.get_all_entries(status=1)
    rows = [r for r in all_rows if r['model_coding'] == model]
    
    if not rows:
        return {
            'model': model,
            'total_files': 0,
            'files_with_rounds': 0,
            'total_original_tokens': 0,
            'total_preprune_tokens': 0,
            'reduction_ratio': 0.0,
            'per_file_reductions': []
        }
    
    total_original_tokens = 0
    total_preprune_tokens = 0
    files_with_rounds = 0
    per_file_reductions = []
    
    print(f"Processing {len(rows)} files for model {model}...")
    
    for idx, row in enumerate(rows):
        if idx % 10 == 0:
            print(f"  Progress: {idx}/{len(rows)} files processed...")
        
        round_messages_str = row.get('round_messages')
        if not round_messages_str:
            continue
        
        try:
            round_messages = json.loads(round_messages_str)
        except (json.JSONDecodeError, TypeError):
            continue
        
        if not isinstance(round_messages, dict) or not round_messages:
            continue
        
        # Reconstruct pre-pruning messages
        preprune_round_messages = reconstruct_preprune_messages(round_messages)
        
        # Calculate tokens for original and pre-pruning messages
        original_tokens = calculate_round_tokens(round_messages)
        preprune_tokens = calculate_round_tokens(preprune_round_messages)
        
        # Sum up all rounds
        file_original_total = sum(original_tokens.values())
        file_preprune_total = sum(preprune_tokens.values())
        
        if file_preprune_total > 0:
            files_with_rounds += 1
            total_original_tokens += file_original_total
            total_preprune_tokens += file_preprune_total
            
            file_reduction = 1.0 - (file_original_total / file_preprune_total)
            per_file_reductions.append({
                'file_path': row.get('file_path', 'unknown'),
                'original_tokens': file_original_total,
                'preprune_tokens': file_preprune_total,
                'reduction_ratio': file_reduction,
                'rounds': len(round_messages)
            })
    
    print(f"  Completed: {len(rows)}/{len(rows)} files processed.")
    
    # Calculate overall reduction ratio
    overall_reduction = 0.0
    if total_preprune_tokens > 0:
        overall_reduction = 1.0 - (total_original_tokens / total_preprune_tokens)
    
    return {
        'model': model,
        'total_files': len(rows),
        'files_with_rounds': files_with_rounds,
        'total_original_tokens': total_original_tokens,
        'total_preprune_tokens': total_preprune_tokens,
        'reduction_ratio': overall_reduction,
        'per_file_reductions': per_file_reductions
    }


def print_statistics(results: List[Dict[str, Any]]):
    """Print token pruning statistics in a formatted table."""
    print("\n" + "="*100)
    print("Token Pruning Analysis - Refine Process")
    print("="*100)
    
    # Summary table
    print("\n【Overall Statistics】")
    headers = ['Model', 'Total Files', 'Files w/ Rounds', 'Original Tokens', 
               'Pre-prune Tokens', 'Reduction %']
    widths = [20, 12, 15, 18, 18, 15]
    
    # Print header
    header_line = "  ".join([h.ljust(w) for h, w in zip(headers, widths)])
    print(header_line)
    print("-" * 100)
    
    # Print data
    for result in results:
        if result['files_with_rounds'] == 0:
            continue
        
        row = [
            result['model'],
            str(result['total_files']),
            str(result['files_with_rounds']),
            f"{result['total_original_tokens']:,}",
            f"{result['total_preprune_tokens']:,}",
            f"{result['reduction_ratio']*100:.2f}%"
        ]
        row_line = "  ".join([r.ljust(w) for r, w in zip(row, widths)])
        print(row_line)
    
    # Calculate and print aggregate statistics for all models
    print("-" * 100)
    total_files_all = sum(r['total_files'] for r in results if r['files_with_rounds'] > 0)
    files_with_rounds_all = sum(r['files_with_rounds'] for r in results if r['files_with_rounds'] > 0)
    total_original_all = sum(r['total_original_tokens'] for r in results if r['files_with_rounds'] > 0)
    total_preprune_all = sum(r['total_preprune_tokens'] for r in results if r['files_with_rounds'] > 0)
    reduction_all = 1.0 - (total_original_all / total_preprune_all) if total_preprune_all > 0 else 0.0
    
    row_all = [
        "ALL MODELS",
        str(total_files_all),
        str(files_with_rounds_all),
        f"{total_original_all:,}",
        f"{total_preprune_all:,}",
        f"{reduction_all*100:.2f}%"
    ]
    row_line_all = "  ".join([r.ljust(w) for r, w in zip(row_all, widths)])
    print(row_line_all)
    
    # Detailed per-file statistics
    print("\n【Top 10 Files with Highest Reduction for Each Model】")
    for result in results:
        if result['files_with_rounds'] == 0:
            continue
        
        print(f"\nModel: {result['model']}")
        print(f"{'File Path':<60}  {'Rounds':<8}  {'Original':<15}  {'Pre-prune':<15}  {'Reduction %':<12}")
        print("-" * 120)
        
        # Sort by reduction ratio
        sorted_files = sorted(result['per_file_reductions'], 
                            key=lambda x: x['reduction_ratio'], 
                            reverse=True)
        
        # Print top 10
        for file_info in sorted_files[:10]:
            file_path = file_info['file_path']
            if len(file_path) > 58:
                file_path = "..." + file_path[-55:]
            
            print(f"{file_path:<60}  {file_info['rounds']:<8}  "
                  f"{file_info['original_tokens']:<15,}  "
                  f"{file_info['preprune_tokens']:<15,}  "
                  f"{file_info['reduction_ratio']*100:<12.2f}%")
    
    print("\n" + "="*100)
    print("\nNotes:")
    print("- Token count is approximated by summing the string length of all messages")
    print("- Reduction % = 1 - (Original Tokens / Pre-prune Tokens)")
    print("- Pre-prune tokens include messages that would have been present before pruning")
    print("- Only files with valid round_messages are included in the analysis")
    print("="*100)


def main():
    parser = argparse.ArgumentParser(description='Token Pruning Analysis')
    parser.add_argument('--db', type=str, default='output/progress.db', 
                       help='Database path')
    parser.add_argument('--models', type=str, default=','.join(TARGET_MODELS),
                       help='Comma-separated model names')
    
    args = parser.parse_args()
    models = [m.strip() for m in args.models.split(',')]
    
    results = []
    for model in models:
        print(f"Analyzing token pruning for model: {model}...")
        result = analyze_pruning_effect(args.db, model)
        results.append(result)
    
    print_statistics(results)
    print(f"\nAnalysis complete! Processed {len(results)} models.")


if __name__ == '__main__':
    main()
