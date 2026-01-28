#!/usr/bin/env python3
"""
Collect Token statistics for RQ1 supplementary analysis.
Extracts prompt_token and completion_token from database messages.
"""

import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from db.progress_tracker import ProgressTracker
from db.progress_tracker_agent import ProgressTrackerAgent
from db.progress_tracker_rawmodel import ProgressTrackerRawModel
from stats.common_utils import safe_json_loads, get_best_pass_round, print_table_header, print_table_row


AGENT_TYPES = ["metagpt", "deepcode", "qwenagent"]
TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]


def extract_tokens_from_message(msg):
    """Extract prompt_token and completion_token from a message.
    
    Args:
        msg: Message dictionary
        
    Returns:
        tuple: (prompt_tokens, completion_tokens)
    """
    if not isinstance(msg, dict):
        return (0, 0)
    
    prompt_tokens = msg.get('prompt_tokens', 0) or 0
    completion_tokens = msg.get('completion_tokens', 0) or 0
    
    return (prompt_tokens, completion_tokens)


def has_tool_calls(msg):
    """Check if message has tool_calls.
    
    Args:
        msg: Message dictionary
        
    Returns:
        bool: True if message has tool_calls
    """
    if not isinstance(msg, dict):
        return False
    tool_calls = msg.get('tool_calls', [])
    return bool(tool_calls and len(tool_calls) >0)


def collect_token_statistics_solagent(tracker, target_models, db_path='output/progress.db', limit=None):
    """
    Collect token statistics from SolAgent (ProgressTracker).
    
    Returns:
        token_stats_by_file: Dict mapping (model, file_path) to token stats
    """
    all_entries = tracker.get_all_entries(status=1)
    all_entries = [e for e in all_entries if e.get('model_coding') in target_models]
    
    print("="*120)
    print(f"Collecting SolAgent Token Statistics")
    print(f"Database: {db_path}")
    print(f"Total entries (after filtering): {len(all_entries)}")
    print("="*120)
    
    processed_count = 0
    token_stats_by_file = {}
    
    for idx, entry in enumerate(all_entries):
        if limit and processed_count >= limit:
            break
        
        file_path = entry.get('file_path', '')
        model_coding = entry.get('model_coding', 'N/A')
        test_json_str = entry.get('test_json', '{}')
        test_json = safe_json_loads(test_json_str)
        
        if not test_json:
            continue
        
        best_round, best_pass, best_total = get_best_pass_round(test_json)
        if not best_total > 0:
            continue
        
        print(f"\n[{idx + 1}/{len(all_entries)}] Processing: {file_path}, model: {model_coding}, id: {entry.get('id', 'N/A')}")
        
        # Get coding_messages tokens (for round 1)
        coding_messages = safe_json_loads(entry.get('coding_messages', '[]'))
        coding_prompt_tokens = 0
        coding_completion_tokens = 0
        
        if coding_messages:
            # Find last assistant message in coding_messages
            for i in range(len(coding_messages) - 1, -1, -1):
                msg = coding_messages[i]
                if isinstance(msg, dict) and msg.get('role') == 'assistant':
                    p, c = extract_tokens_from_message(msg)
                    coding_prompt_tokens = p
                    coding_completion_tokens = c
                    break
        
        # Get refine tokens from round_messages (round 2+) and messages field
        # round_messages structure: {round_idx: [messages]}
        # For best_pass round calculation, we need to count tokens from rounds 2 to best_pass
        round_messages = safe_json_loads(entry.get('round_messages', '{}'))
        refine_prompt_tokens = 0
        refine_completion_tokens = 0
        refine_prompt_tokens_no_tool = 0
        refine_completion_tokens_no_tool = 0
        
        # Count tokens in round_messages for rounds 2 to best_pass
        if best_round > 1 and round_messages:
            for round_idx in range(2, best_round + 1):
                round_idx_str = str(round_idx)
                if round_idx_str in round_messages:
                    messages_list = round_messages[round_idx_str]
                    if messages_list:
                        # Find last assistant message in this round (avoid duplicates)
                        last_assistant_msg = None
                        for i in range(len(messages_list) - 1, -1, -1):
                            msg = messages_list[i]
                            if isinstance(msg, dict) and msg.get('role') == 'assistant':
                                last_assistant_msg = msg
                                break
                        
                        if last_assistant_msg:
                            p, c = extract_tokens_from_message(last_assistant_msg)
                            refine_prompt_tokens += p
                            refine_completion_tokens += c
                            
                            if not has_tool_calls(last_assistant_msg):
                                refine_prompt_tokens_no_tool += p
                                refine_completion_tokens_no_tool += c
        
        # Also check messages field for additional refine tokens (this contains tool call messages)
        # messages field contains round 2+ messages without round structure
        # We need to sum tokens only up to the last message of the best_round
        messages = safe_json_loads(entry.get('messages', '[]'))
        additional_refine_prompt = 0
        additional_refine_completion = 0
        
        if messages and best_round > 1:
            # Identify the target message ID (last assistant message of best_round)
            target_msg_id = None
            if round_messages:
                best_round_str = str(best_round)
                if best_round_str in round_messages:
                    msgs = round_messages[best_round_str]
                    for i in range(len(msgs) - 1, -1, -1):
                        if isinstance(msgs[i], dict) and msgs[i].get('role') == 'assistant':
                            target_msg_id = msgs[i].get('id')
                            break
            
            # Iterate through messages
            # Logic: Start counting AFTER the first assistant message with empty/None ID (Coding message)
            # Stop WHEN we hit the target_msg_id
            start_counting = False
            for msg in messages:
                if isinstance(msg, dict) and msg.get('role') == 'assistant':
                    msg_id = msg.get('id')
                    
                    # Check start condition: first assistant msg with empty ID AND no tool calls
                    if not start_counting:
                        if not msg_id and not has_tool_calls(msg): # None or empty string AND no tool calls
                            start_counting = True
                        continue # Skip everything before and including the start message
                    
                    # If we are counting:
                    # Check stop condition: reached target message
                    if target_msg_id and msg_id == target_msg_id:
                        break
                    
                    # Count tool calls
                    if has_tool_calls(msg):
                        p, c = extract_tokens_from_message(msg)
                        additional_refine_prompt += p
                        additional_refine_completion += c
        
        refine_prompt_tokens += additional_refine_prompt
        refine_completion_tokens += additional_refine_completion
        # Note: tool_call messages don't add to no_tool totals
        
        # Calculate total tokens up to best_pass round
        
        # For best_pass round tokens
        if best_round == 1:
            total_prompt_tokens = coding_prompt_tokens
            total_completion_tokens = coding_completion_tokens
            total_prompt_tokens_no_tool = coding_prompt_tokens
            total_completion_tokens_no_tool = coding_completion_tokens
            # Reset refine tokens to 0 for round 1
            refine_prompt_tokens = 0
            refine_completion_tokens = 0
            refine_prompt_tokens_no_tool = 0
            refine_completion_tokens_no_tool = 0
        else:
            # Round 1 + refine tokens
            total_prompt_tokens = coding_prompt_tokens + refine_prompt_tokens
            total_completion_tokens = coding_completion_tokens + refine_completion_tokens
            total_prompt_tokens_no_tool = coding_prompt_tokens + refine_prompt_tokens_no_tool
            total_completion_tokens_no_tool = coding_completion_tokens + refine_completion_tokens_no_tool
        
        token_stats = {
            'coding_prompt_tokens': coding_prompt_tokens,
            'coding_completion_tokens': coding_completion_tokens,
            'refine_prompt_tokens': refine_prompt_tokens,
            'refine_completion_tokens': refine_completion_tokens,
            'refine_prompt_tokens_no_tool': refine_prompt_tokens_no_tool,
            'refine_completion_tokens_no_tool': refine_completion_tokens_no_tool,
            'total_prompt_tokens': total_prompt_tokens,
            'total_completion_tokens': total_completion_tokens,
            'total_prompt_tokens_no_tool': total_prompt_tokens_no_tool,
            'total_completion_tokens_no_tool': total_completion_tokens_no_tool,
            'best_round': best_round
        }
        
        token_stats_by_file[(model_coding, file_path)] = token_stats
        processed_count += 1
        
        print(f"  ✓ Coding: {coding_prompt_tokens} / {coding_completion_tokens}, "
              f"Refine: {refine_prompt_tokens} / {refine_completion_tokens}, "
              f"Total: {total_prompt_tokens} / {total_completion_tokens}")
    
    print(f"\n{'='*120}")
    print(f"SolAgent Complete - Processed {processed_count} entries")
    print(f"{'='*120}")
    
    return token_stats_by_file


def collect_token_statistics_agent_rawmodel(tracker, tracker_name, target_models, db_path='output/progress.db', limit=None):
    """
    Collect token statistics from Agent or RawModel tracker.
    
    Returns:
        token_stats_by_file: Dict mapping (model, agent_type, file_path) or (model, file_path) to token stats
    """
    all_entries = tracker.get_all_entries()
    all_entries = [e for e in all_entries if e.get('model_coding') in target_models]
    
    print("="*120)
    print(f"Collecting {tracker_name} Token Statistics")
    print(f"Database: {db_path}")
    print(f"Total entries (after filtering): {len(all_entries)}")
    print("="*120)
    
    processed_count = 0
    token_stats_by_file = {}
    
    for idx, entry in enumerate(all_entries):
        if limit and processed_count >= limit:
            break
        
        file_path = entry.get('file_path', '')
        model_coding = entry.get('model_coding', 'N/A')
        agent_type = entry.get('agent_type', '')
        
        test_total = entry.get('test_total', 0)
        if not test_total > 0:
            continue
        
        print(f"\n[{idx + 1}/{len(all_entries)}] Processing: {file_path}, model: {model_coding}, id: {entry.get('id', 'N/A')}")
        
        # Extract tokens from coding_messages
        coding_messages = safe_json_loads(entry.get('coding_messages', '[]'))
        total_prompt_tokens = 0
        total_completion_tokens = 0
        total_prompt_tokens_no_tool = 0
        total_completion_tokens_no_tool = 0
        
        if coding_messages:
            for msg in coding_messages:
                if isinstance(msg, dict) and msg.get('role') == 'assistant':
                    p, c = extract_tokens_from_message(msg)
                    total_prompt_tokens += p
                    total_completion_tokens += c
        
        token_stats = {
            'total_prompt_tokens': total_prompt_tokens,
            'total_completion_tokens': total_completion_tokens
        }
        
        # Store with agent_type if available
        if agent_type:
            token_stats_by_file[(model_coding, agent_type, file_path)] = token_stats
        else:
            token_stats_by_file[(model_coding, file_path)] = token_stats
        
        processed_count += 1
        print(f"  ✓ Total: {total_prompt_tokens} / {total_completion_tokens}")
    
    print(f"\n{'='*120}")
    print(f"{tracker_name} Complete - Processed {processed_count} entries")
    print(f"{'='*120}")
    
    return token_stats_by_file


def print_token_statistics_table(all_token_stats, TARGET_MODELS, exclude_tool_calls=False):
    """Print token statistics table.
    
    Args:
        all_token_stats: Dict of {source: token_stats_by_file}
        TARGET_MODELS: List of target models to analyze
        exclude_tool_calls: If True, use stats excluding tool_calls
    """
    print("\n" + "="*150)
    if exclude_tool_calls:
        print("RQ-1 Supplementary Statistics: Token Usage (Excluding Tool Calls)")
    else:
        print("RQ-1 Supplementary Statistics: Token Usage (All Messages)")
    print("="*150)
    print("\n【Token Statistics】")
    print("Count token usage for each model/method\n")
    if exclude_tool_calls:
        print("Note: Excludes assistant messages containing tool_calls\n")
    else:
        print("Note: Includes all assistant messages (including tool_calls)\n")
    
    # Collect token stats for each source/model combination
    token_summary = []
    
    for source_name, token_data in all_token_stats.items():
        # Determine if this is Agent data
        if token_data:
            first_key = next(iter(token_data.keys()))
            has_agent_type = len(first_key) == 3 and isinstance(first_key[1], str) and first_key[1] in ['metagpt', 'deepcode', 'qwenagent']
        else:
            has_agent_type = False
        
        if has_agent_type:
            # Group by agent_type
            agent_type_stats = {}
            for (model, agent_type, file_path), token_stats in token_data.items():
                if model not in TARGET_MODELS:
                    continue
                if agent_type not in agent_type_stats:
                    agent_type_stats[agent_type] = {}
                if model not in agent_type_stats[agent_type]:
                    agent_type_stats[agent_type][model] = {
                        'total_prompt_tokens': 0,
                        'total_completion_tokens': 0,
                        'file_count': 0
                    }
                
                # Agent/RawModel don't have separate no_tool stats
                # Only use regular tokens (exclude_tool_calls doesn't apply to them)
                agent_type_stats[agent_type][model]['total_prompt_tokens'] += token_stats.get('total_prompt_tokens', 0)
                agent_type_stats[agent_type][model]['total_completion_tokens'] += token_stats.get('total_completion_tokens', 0)
                agent_type_stats[agent_type][model]['file_count'] += 1
            
            # Create summary entries
            for agent_type, model_stats in agent_type_stats.items():
                agent_display_names = {
                    'metagpt': 'MetaGPT',
                    'deepcode': 'DeepCode',
                    'qwenagent': 'QwenAgent',
                    'copilot': 'Copilot'
                }
                display_name = agent_display_names.get(agent_type, agent_type)
                for model in TARGET_MODELS:
                    if model in model_stats and model_stats[model]['file_count'] > 0:
                        stats = model_stats[model]
                        token_summary.append({
                            'source': display_name,
                            'model': model,
                            'file_count': stats['file_count'],
                            'total_prompt_tokens': stats['total_prompt_tokens'],
                            'total_completion_tokens': stats['total_completion_tokens'],
                            'avg_prompt_per_file': stats['total_prompt_tokens'] / stats['file_count'],
                            'avg_completion_per_file': stats['total_completion_tokens'] / stats['file_count']
                        })
            continue
        
        # For SolAgent and RawModel
        model_stats = {}
        for model in TARGET_MODELS:
            model_stats[model] = {
                'total_prompt_tokens': 0,
                'total_completion_tokens': 0,
                'coding_prompt_tokens': 0,
                'coding_completion_tokens': 0,
                'refine_prompt_tokens': 0,
                'refine_completion_tokens': 0,
                'file_count': 0,
                'total_rounds': 0
            }
        
        is_solagent = source_name == 'SolAgent'
        
        for key, token_stats in token_data.items():
            if len(key) == 2:
                model, file_path = key
            else:
                continue
            
            if model not in TARGET_MODELS:
                continue
            
            # Agent/RawModel/SolAgent stats
            # For Agent/RawModel: always use regular tokens (no_tool doesn't apply)
            # For SolAgent: use no_tool tokens when exclude_tool_calls=True
            if is_solagent and exclude_tool_calls:
                model_stats[model]['total_prompt_tokens'] += token_stats.get('total_prompt_tokens_no_tool', 0)
                model_stats[model]['total_completion_tokens'] += token_stats.get('total_completion_tokens_no_tool', 0)
            else:
                model_stats[model]['total_prompt_tokens'] += token_stats.get('total_prompt_tokens', 0)
                model_stats[model]['total_completion_tokens'] += token_stats.get('total_completion_tokens', 0)
            
            if is_solagent:
                model_stats[model]['coding_prompt_tokens'] += token_stats.get('coding_prompt_tokens', 0)
                model_stats[model]['coding_completion_tokens'] += token_stats.get('coding_completion_tokens', 0)
                
                if exclude_tool_calls:
                    model_stats[model]['refine_prompt_tokens'] += token_stats.get('refine_prompt_tokens_no_tool', 0)
                    model_stats[model]['refine_completion_tokens'] += token_stats.get('refine_completion_tokens_no_tool', 0)
                else:
                    model_stats[model]['refine_prompt_tokens'] += token_stats.get('refine_prompt_tokens', 0)
                    model_stats[model]['refine_completion_tokens'] += token_stats.get('refine_completion_tokens', 0)
                
                model_stats[model]['total_rounds'] += token_stats.get('best_round', 0)
            
            model_stats[model]['file_count'] += 1
        
        # Create summary entries
        for model in TARGET_MODELS:
            if model_stats[model]['file_count'] > 0:
                stats = model_stats[model]
                summary_entry = {
                    'source': source_name,
                    'model': model,
                    'file_count': stats['file_count'],
                    'total_prompt_tokens': stats['total_prompt_tokens'],
                    'total_completion_tokens': stats['total_completion_tokens'],
                    'avg_prompt_per_file': stats['total_prompt_tokens'] / stats['file_count'],
                    'avg_completion_per_file': stats['total_completion_tokens'] / stats['file_count']
                }
                
                if is_solagent:
                    summary_entry.update({
                        'coding_prompt_tokens': stats['coding_prompt_tokens'],
                        'coding_completion_tokens': stats['coding_completion_tokens'],
                        'refine_prompt_tokens': stats['refine_prompt_tokens'],
                        'refine_completion_tokens': stats['refine_completion_tokens'],
                        'avg_prompt_per_round': stats['total_prompt_tokens'] / stats['total_rounds'] if stats['total_rounds'] > 0 else 0,
                        'avg_completion_per_round': stats['total_completion_tokens'] / stats['total_rounds'] if stats['total_rounds'] > 0 else 0
                    })
                
                token_summary.append(summary_entry)
    
    # Custom sort
    def custom_sort_key(stat):
        source = stat['source']
        model = stat['model']
        model_order = {'claude-sonnet-4-5': 0, 'gpt-5-mini': 1, 'gpt-5.1': 2}
        model_idx = model_order.get(model, 999)
        
        if source in ['RawModel', 'SolAgent']:
            group = 0
            source_idx = 0 if source == 'RawModel' else 1
            return (group, model_idx, source_idx)
        else:
            group = 1
            if source == 'MetaGPT':
                agent_idx = 0
            elif source == 'DeepCode':
                agent_idx = 1
            elif source == 'QwenAgent':
                agent_idx = 2
            else:
                agent_idx = 999
            return (group, model_idx, agent_idx)
    
    # Print table
    # Check if we have SolAgent data to determine columns
    has_solagent = any(s['source'] == 'SolAgent' for s in token_summary)
    
    if has_solagent:
        headers = ['Source', 'Model', 'Files', 
                   'Coding Prompt', 'Coding Completion',
                   'Avg Coding P/F', 'Avg Coding C/F',
                   'Refine Prompt', 'Refine Completion',
                   'Total Prompt', 'Total Completion',
                   'Avg Total P/F', 'Avg Total C/F',
                   'Avg Prompt/Round', 'Avg Compl/Round']
        widths = [15, 18, 8, 14, 16, 14, 14, 14, 16, 14, 16, 14, 14, 16, 16]
    else:
        headers = ['Source', 'Model', 'Files',
                   'Total Prompt', 'Total Completion',
                   'Avg Prompt/File', 'Avg Compl/File']
        widths = [20, 20, 10, 18, 18, 18, 18]
    
    print_table_header(headers, widths)
    
    for stat in sorted(token_summary, key=custom_sort_key):
        if stat['source'] == 'SolAgent':
            row = [
                stat['source'],
                stat['model'],
                str(stat['file_count']),
                str(stat.get('coding_prompt_tokens', 0)),
                str(stat.get('coding_completion_tokens', 0)),
                f"{stat.get('coding_prompt_tokens', 0) / stat['file_count']:.0f}",
                f"{stat.get('coding_completion_tokens', 0) / stat['file_count']:.0f}",
                str(stat.get('refine_prompt_tokens', 0)),
                str(stat.get('refine_completion_tokens', 0)),
                str(stat['total_prompt_tokens']),
                str(stat['total_completion_tokens']),
                f"{stat['avg_prompt_per_file']:.0f}",
                f"{stat['avg_completion_per_file']:.0f}",
                f"{stat.get('avg_prompt_per_round', 0):.0f}",
                f"{stat.get('avg_completion_per_round', 0):.0f}"
            ]
        elif has_solagent:
            # For Agent/RawModel in the exclude_tool_calls table
            if exclude_tool_calls:
                # Show full stats (Coding = Total) to allow comparison
                row = [
                    stat['source'],
                    stat['model'],
                    str(stat['file_count']),
                    str(stat['total_prompt_tokens']),
                    str(stat['total_completion_tokens']),
                    f"{stat['avg_prompt_per_file']:.0f}",
                    f"{stat['avg_completion_per_file']:.0f}",
                    '-',
                    '-',
                    str(stat['total_prompt_tokens']),
                    str(stat['total_completion_tokens']),
                    f"{stat['avg_prompt_per_file']:.0f}",
                    f"{stat['avg_completion_per_file']:.0f}",
                    '-',
                    '-'
                ]
            else:
                # Normal table with all messages
                # For Agent/RawModel, Coding = Total
                row = [
                    stat['source'],
                    stat['model'],
                    str(stat['file_count']),
                    str(stat['total_prompt_tokens']),
                    str(stat['total_completion_tokens']),
                    f"{stat['avg_prompt_per_file']:.0f}",
                    f"{stat['avg_completion_per_file']:.0f}",
                    '-',
                    '-',
                    str(stat['total_prompt_tokens']),
                    str(stat['total_completion_tokens']),
                    f"{stat['avg_prompt_per_file']:.0f}",
                    f"{stat['avg_completion_per_file']:.0f}",
                    '-',
                    '-'
                ]
        else:
            row = [
                stat['source'],
                stat['model'],
                str(stat['file_count']),
                str(stat['total_prompt_tokens']),
                str(stat['total_completion_tokens']),
                f"{stat['avg_prompt_per_file']:.0f}",
                f"{stat['avg_completion_per_file']:.0f}"
            ]
        
        print_table_row(row, widths)
    
    print("\n" + "="*150)
    print("Statistics completed!")
    print("="*150)


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Collect Token statistics for RQ1 supplementary analysis')
    parser.add_argument('--db', type=str, default='output/progress.db',
                       help='Path to database file')
    parser.add_argument('--limit', type=int, default=None,
                       help='Limit number of entries to process per table')
    parser.add_argument('--table', type=str, choices=['progress', 'agent', 'rawmodel', 'all'], default='all',
                       help='Which table(s) to collect tokens from (default: all)')
    
    args = parser.parse_args()
    
    all_token_stats = {}
    
    if args.table in ['progress', 'all']:
        print("\n" + "="*120)
        print("Collecting SolAgent Token statistics...")
        print("="*120)
        tracker = ProgressTracker(args.db)
        token_stats = collect_token_statistics_solagent(tracker, TARGET_MODELS, db_path=args.db, limit=args.limit)
        all_token_stats['SolAgent'] = token_stats
        print(f"  → Collected {len(token_stats)} file/model combinations")
    
    if args.table in ['agent', 'all']:
        print("\n" + "="*120)
        print("Collecting Agent Token statistics...")
        print("="*120)
        tracker = ProgressTrackerAgent(args.db)
        token_stats = collect_token_statistics_agent_rawmodel(tracker, "ProgressTrackerAgent", TARGET_MODELS, db_path=args.db, limit=args.limit)
        all_token_stats['Agent'] = token_stats
        print(f"  → Collected {len(token_stats)} file/model combinations")
    
    if args.table in ['rawmodel', 'all']:
        print("\n" + "="*120)
        print("Collecting RawModel Token statistics...")
        print("="*120)
        tracker = ProgressTrackerRawModel(args.db)
        token_stats = collect_token_statistics_agent_rawmodel(tracker, "ProgressTrackerRawModel", TARGET_MODELS, db_path=args.db, limit=args.limit)
        all_token_stats['RawModel'] = token_stats
        print(f"  → Collected {len(token_stats)} file/model combinations")
    
    print(f"\n" + "="*120)
    print(f"Data sources collected: {list(all_token_stats.keys())}")
    print("="*120)
    
    # Print statistics - with all messages
    print_token_statistics_table(all_token_stats, TARGET_MODELS, exclude_tool_calls=False)
    
    # Print statistics - excluding tool_calls
    print("\n\n")
    print_token_statistics_table(all_token_stats, TARGET_MODELS, exclude_tool_calls=True)
