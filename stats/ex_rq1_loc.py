#!/usr/bin/env python3
"""
Collect LOC (Lines of Code) statistics for RQ1 supplementary analysis.
Extracts code from database messages and counts lines excluding comments and empty lines.
"""

import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from db.progress_tracker import ProgressTracker
from stats.common_utils import safe_json_loads, get_best_pass_round, print_table_header, print_table_row
from stats.code_metrics import (
    calculate_complexity,
    count_loc,
    count_physical_loc,
    extract_code_from_messages,
)

AGENT_TYPES = ["metagpt", "deepcode", "qwenagent", "copilot"]
TARGET_MODELS = ["claude-sonnet-4-5", "gpt-5-mini", "gpt-5.1"]


def collect_loc_statistics_generic(tracker, tracker_name, target_models, db_path='output/progress.db', limit=None):
    """
    Generic function to collect LOC statistics from all progress tracker entries.
    Works with any tracker that has the same structure as ProgressTracker.
    
    Args:
        tracker: Progress tracker instance (ProgressTracker, ProgressTrackerSummary, or ProgressTrackerAblation)
        tracker_name: Name of the tracker (for display purposes)
        target_models: List of target model names to include
        db_path: Path to the database
        limit: Optional limit on number of entries to process
        
    Returns:
        loc_stats_by_file: Dict mapping file_path to {round_idx: loc}
    """
    all_entries = tracker.get_all_entries(status=1)
    # Filter to only include target models
    all_entries = [e for e in all_entries if e.get('model_coding') in target_models]
    
    print("="*120)
    print(f"Collecting {tracker_name} LOC Statistics")
    print(f"Database: {db_path}")
    print(f"Total entries (after filtering): {len(all_entries)}")
    print("="*120)
    
    processed_count = 0
    loc_stats_by_file = {}  # Dict[(model, file_path)] = {round_idx: loc}
    
    for idx, entry in enumerate(all_entries):
        if limit and processed_count >= limit:
            break
        
        file_path = entry.get('file_path', '')
        model_coding = entry.get('model_coding', 'N/A')
        test_json_str = entry.get('test_json', '{}')
        test_json = safe_json_loads(test_json_str)
        
        # Skip if no existing test data
        if not test_json:
            continue
        
        # Match rq1_statistics.py logic: check if best_pass round has test_total > 0
        best_round, best_pass, best_total = get_best_pass_round(test_json)
        if not best_total > 0:
            continue
        
        print(f"\n[{idx + 1}/{len(all_entries)}] Processing: {file_path}, model: {model_coding}, id: {entry.get('id', 'N/A')}")
        print(f"  Rounds to process: {list(test_json.keys())}")
        
        # Process each round
        new_round_loc_json = {}
        
        for round_idx in test_json.keys():
            print(f"\n  Processing Round {round_idx}...")
            
            # Check if this round has any tests (regardless of pass/fail)
            round_idx_str = str(round_idx)
            if round_idx_str in test_json:
                round_test_data = test_json[round_idx_str]
                if isinstance(round_test_data, dict):
                    test_total = round_test_data.get('total', 0)
                    if test_total == 0:
                        print(f"    [SKIP] No tests in this round")
                        continue
                    passed_count = round_test_data.get('passed', 0)
                    print(f"    {test_total} total tests ({passed_count} passed)")
            
            # Get round messages and extract code
            round_messages = safe_json_loads(entry.get('round_messages', '{}'))

            if not round_messages or round_idx_str not in round_messages:
                print(f"    [SKIP] No messages found")
                continue

            valid_code = extract_code_from_messages(
                round_messages[round_idx_str], file_path
            )
            
            if not valid_code:
                print(f"    [SKIP] No assistant message with valid code found")
                continue
            
            # Count LOC (Lines of Code) and Complexity
            try:
                loc = count_loc(valid_code)
                physical_loc = count_physical_loc(valid_code)
                complexity = calculate_complexity(valid_code)
                print(f"    ✓ Code LOC: {loc}, Physical LOC: {physical_loc}, Complexity: {complexity}")
                
                # Store LOC for this round
                # Convert round_idx to int to match get_best_pass_round return type
                new_round_loc_json[int(round_idx)] = {
                    'loc': loc, 
                    'physical_loc': physical_loc,
                    'complexity': complexity
                }
                    
            except Exception as e:
                print(f"    [ERROR] Failed to count LOC/Complexity: {e}")
                continue
        
        # Accumulate LOC statistics (no database update needed)
        if new_round_loc_json:
            # Use (model, file_path) as key to track model-specific LOC
            loc_stats_by_file[(model_coding, file_path)] = new_round_loc_json
            processed_count += 1
            print(f"\n  ✓ Collected LOC for {len(new_round_loc_json)} rounds")
    
    print(f"\n{'='*120}")
    print(f"{tracker_name} Complete - Processed {processed_count} entries")
    print(f"{'='*120}")
    
    return loc_stats_by_file


def collect_loc_progress_tracker(target_models, db_path='output/progress.db', limit=None):
    """
    Collect LOC statistics from progress tracker.
    
    Args:
        target_models: List of target model names to include
        db_path: Path to the database
        limit: Optional limit on number of entries to process
        
    Returns:
        loc_stats_by_file: Dict mapping (model, file_path) to {round_idx: loc}
    """
    tracker = ProgressTracker(db_path)
    return collect_loc_statistics_generic(tracker, "ProgressTracker", target_models, db_path, limit)



def collect_loc_agent_rawmodel_generic(tracker, tracker_name, target_models, db_path='output/progress.db', limit=None):
    """
    Generic function to collect LOC statistics from agent or rawmodel tracker.
    These trackers store coding_messages (not round-based like progress_tracker).
    
    Args:
        tracker: Progress tracker instance (ProgressTrackerAgent or ProgressTrackerRawModel)
        tracker_name: Name of the tracker (for display purposes)
        target_models: List of target model names to include
        db_path: Path to the database
        limit: Optional limit on number of entries to process
        
    Returns:
        loc_stats_by_file: Dict mapping (model, file_path) to LOC
    """
    all_entries = tracker.get_all_entries()
    # Filter to only include target models
    all_entries = [e for e in all_entries if e.get('model_coding') in target_models]
    
    print("="*120)
    print(f"Collecting {tracker_name} LOC Statistics")
    print(f"Database: {db_path}")
    print(f"Total entries (after filtering): {len(all_entries)}")
    print("="*120)
    
    processed_count = 0
    loc_stats_by_file = {}  # Dict[(model, agent_type, file_path)] = LOC for Agent, Dict[(model, file_path)] = LOC for RawModel
    
    for idx, entry in enumerate(all_entries):
        if limit and processed_count >= limit:
            break
        
        file_path = entry.get('file_path', '')
        model_coding = entry.get('model_coding', 'N/A')
        
        # Skip if no tests recorded (match rq1_statistics.py logic)
        test_total = entry.get('test_total', 0)
        if not test_total > 0:
            continue
        
        print(f"\n[{idx + 1}/{len(all_entries)}] Processing: {file_path}, model: {model_coding}, id: {entry.get('id', 'N/A')}")
        
        # Extract assistant code from coding_messages
        coding_messages = safe_json_loads(entry.get('coding_messages', '[]'))
        if not coding_messages:
            print(f"  [SKIP] No coding_messages found")
            continue
        
        agent_type = entry.get('agent_type', '')
        valid_code = extract_code_from_messages(
            coding_messages, file_path, agent_type=agent_type
        )
        
        if not valid_code:
            print(f"  [SKIP] No assistant message with valid code found")
            continue
        
        # Count LOC and Complexity
        try:
            loc = count_loc(valid_code)
            physical_loc = count_physical_loc(valid_code)
            complexity = calculate_complexity(valid_code)
            print(f"  ✓ Code LOC: {loc}, Physical LOC: {physical_loc}, Complexity: {complexity}")
            
            # Store LOC (single value, not round-based)
            # For Agent: use (model, agent_type, file_path) to distinguish different agents
            # For RawModel: use (model, file_path) since there's no agent_type
            loc_data = {
                'loc': loc, 
                'physical_loc': physical_loc,
                'complexity': complexity
            }
            if agent_type:  # Agent table has agent_type
                loc_stats_by_file[(model_coding, agent_type, file_path)] = loc_data
            else:  # RawModel table doesn't have agent_type
                loc_stats_by_file[(model_coding, file_path)] = loc_data
            processed_count += 1
        except Exception as e:
            print(f"  [ERROR] Failed to count LOC/Complexity: {e}")
            continue
    
    print(f"\n{'='*120}")
    print(f"{tracker_name} Complete - Processed {processed_count} entries")
    print(f"{'='*120}")
    
    return loc_stats_by_file


def collect_loc_agent(target_models, db_path='output/progress.db', limit=None):
    """
    Collect LOC statistics from progress_tracker_agent table.
    
    Args:
        target_models: List of target model names to include
        db_path: Path to the database
        limit: Optional limit on number of entries to process
        
    Returns:
        loc_stats_by_file: Dict mapping (model, file_path) to LOC
    """
    from db.progress_tracker_agent import ProgressTrackerAgent
    tracker = ProgressTrackerAgent(db_path)
    return collect_loc_agent_rawmodel_generic(tracker, "ProgressTrackerAgent", target_models, db_path, limit)


def collect_loc_rawmodel(target_models, db_path='output/progress.db', limit=None):
    """
    Collect LOC statistics from progress_tracker_rawmodel table.
    
    Args:
        target_models: List of target model names to include
        db_path: Path to the database
        limit: Optional limit on number of entries to process
        
    Returns:
        loc_stats_by_file: Dict mapping (model, file_path) to LOC
    """
    from db.progress_tracker_rawmodel import ProgressTrackerRawModel
    tracker = ProgressTrackerRawModel(db_path)
    return collect_loc_agent_rawmodel_generic(tracker, "ProgressTrackerRawModel", target_models, db_path, limit)


def print_loc_statistics_table(all_loc_stats, TARGET_MODELS):
    """Print LOC statistics table.
    
    Args:
        all_loc_stats: Dict of {source: {(model, file_path): loc_data}}
            For SolAgent (round-based): loc_data is {round_idx: loc}
            For Agent/RawModel (non-round-based): loc_data is just LOC (int)
        TARGET_MODELS: List of target models to analyze
    """
    from stats.common_utils import safe_json_loads, print_table_header, print_table_row, get_best_pass_round
    
    print("\n" + "="*120)
    print("RQ-1 Supplementary Statistics: LOC (Lines of Code)")
    print("="*120)
    print("\n【LOC Statistics】")
    print("Count lines of code generated by each model/method\n")
    print("Note: LOC excludes empty lines and comments; Physical LOC includes all lines")
    print("      SolAgent counts LOC at best_pass round, Agent/RawModel counts LOC of final code\n")
    
    # Collect LOC for each source/model combination
    loc_summary = []  # List of {source, model, total_loc, file_count, total_complexity}
    
    for source_name, loc_data in all_loc_stats.items():
        # Determine if this is Agent data (has agent_type in keys)
        # Check first key to see if it's (model, agent_type, file_path) or (model, file_path)
        if loc_data:
            first_key = next(iter(loc_data.keys()))
            has_agent_type = len(first_key) == 3 and isinstance(first_key[1], str) and first_key[1] in ['metagpt', 'deepcode', 'qwenagent']
        else:
            has_agent_type = False
        
        if has_agent_type:
            # Group by agent_type first, then by model
            agent_type_stats = {}  # {agent_type: {model: {total_loc, total_physical_loc, total_complexity, file_count}}}
            for (model, agent_type, file_path), loc_dict in loc_data.items():
                if model not in TARGET_MODELS:
                    continue
                if agent_type not in agent_type_stats:
                    agent_type_stats[agent_type] = {}
                if model not in agent_type_stats[agent_type]:
                    agent_type_stats[agent_type][model] = {
                        'total_loc': 0, 
                        'total_physical_loc': 0, 
                        'total_complexity': 0,
                        'file_count': 0
                    }
                agent_type_stats[agent_type][model]['total_loc'] += loc_dict['loc']
                agent_type_stats[agent_type][model]['total_physical_loc'] += loc_dict['physical_loc']
                agent_type_stats[agent_type][model]['total_complexity'] += loc_dict.get('complexity', 0)
                agent_type_stats[agent_type][model]['file_count'] += 1
            
            # Create summary entries for each agent_type
            for agent_type, model_stats in agent_type_stats.items():
                # Map agent_type to display name
                agent_display_names = {
                    'metagpt': 'MetaGPT',
                    'deepcode': 'DeepCode',
                    'qwenagent': 'QwenAgent',
                    'copilot': 'Copilot'
                }
                display_name = agent_display_names.get(agent_type, agent_type)
                for model in TARGET_MODELS:
                    if model in model_stats and model_stats[model]['file_count'] > 0:
                        loc_summary.append({
                            'source': display_name,
                            'model': model,
                            'total_loc': model_stats[model]['total_loc'],
                            'total_physical_loc': model_stats[model]['total_physical_loc'],
                            'file_count': model_stats[model]['file_count'],
                            'avg_loc': model_stats[model]['total_loc'] / model_stats[model]['file_count'],
                            'avg_physical_loc': model_stats[model]['total_physical_loc'] / model_stats[model]['file_count'],
                            'total_complexity': model_stats[model]['total_complexity'],
                            'avg_complexity': model_stats[model]['total_complexity'] / model_stats[model]['file_count']
                        })
            continue
        
        # Original logic for non-agent data (SolAgent, RawModel)
        # Group by model
        model_stats = {}  # {model: {total_loc, total_physical_loc, total_complexity, file_count}}
        for model in TARGET_MODELS:
            model_stats[model] = {
                'total_loc': 0, 
                'total_physical_loc': 0, 
                'total_complexity': 0,
                'file_count': 0
            }
        
        # Check if this is round-based (SolAgent) or not (Agent/RawModel)
        is_round_based = source_name == 'SolAgent'
        
        if is_round_based:
            # For SolAgent: loc_data is {(model, file_path): {round_idx: loc}}
            # Need to get best_pass round from database
            db_path = 'output/progress.db'
            tracker = ProgressTracker(db_path)
            all_entries = tracker.get_all_entries(status=1)
            # Use (file_path, model) as key to handle multiple models per file
            entry_map = {(entry.get('file_path'), entry.get('model_coding')): entry for entry in all_entries}
            
            for (model, file_path), round_loc_data in loc_data.items():
                if model not in TARGET_MODELS:
                    continue
                
                # Get entry to find best_pass round
                entry_key = (file_path, model)
                if entry_key not in entry_map:
                    continue
                
                entry = entry_map[entry_key]
                
                # Get best_pass round
                test_json_str = entry.get('test_json', '{}')
                test_json = safe_json_loads(test_json_str)
                best_round, _, _ = get_best_pass_round(test_json)
                
                if best_round > 0 and best_round in round_loc_data:
                    loc_dict = round_loc_data[best_round]
                    model_stats[model]['total_loc'] += loc_dict['loc']
                    model_stats[model]['total_physical_loc'] += loc_dict['physical_loc']
                    model_stats[model]['total_complexity'] += loc_dict.get('complexity', 0)
                    model_stats[model]['file_count'] += 1
                else:
                    # Debug: Log why file was skipped
                    available_rounds = list(round_loc_data.keys())
                    print(f"[DEBUG] Skipped {file_path} (model: {model}): best_round={best_round}, available_rounds={available_rounds}")
        else:
            # For Agent/RawModel: loc_data is {(model, file_path): loc_dict}
            for (model, file_path), loc_dict in loc_data.items():
                if model not in TARGET_MODELS:
                    continue
                model_stats[model]['total_loc'] += loc_dict['loc']
                model_stats[model]['total_physical_loc'] += loc_dict['physical_loc']
                model_stats[model]['total_complexity'] += loc_dict.get('complexity', 0)
                model_stats[model]['file_count'] += 1
        
        # Create summary entries
        for model in TARGET_MODELS:
            if model_stats[model]['file_count'] > 0:
                loc_summary.append({
                    'source': source_name,
                    'model': model,
                    'total_loc': model_stats[model]['total_loc'],
                    'total_physical_loc': model_stats[model]['total_physical_loc'],
                    'file_count': model_stats[model]['file_count'],
                    'avg_loc': model_stats[model]['total_loc'] / model_stats[model]['file_count'],
                    'avg_physical_loc': model_stats[model]['total_physical_loc'] / model_stats[model]['file_count'],
                    'total_complexity': model_stats[model]['total_complexity'],
                    'avg_complexity': model_stats[model]['total_complexity'] / model_stats[model]['file_count']
                })
    
    # Print table with custom ordering
    # Order specified by user:
    # 1. RawModel claude-sonnet-4-5, SolAgent claude-sonnet-4-5
    # 2. RawModel gpt-5-mini, SolAgent gpt-5-mini
    # 3. RawModel gpt-5.1, SolAgent gpt-5.1
    # 4. MetaGPT/DeepCode/QwenAgent claude-sonnet-4-5 (agents for each model)
    # 5. MetaGPT/DeepCode/QwenAgent gpt-5-mini
    # 6. MetaGPT/DeepCode/QwenAgent gpt-5.1
    
    def custom_sort_key(stat):
        source = stat['source']
        model = stat['model']
        
        # Model order
        model_order = {'claude-sonnet-4-5': 0, 'gpt-5-mini': 1, 'gpt-5.1': 2}
        model_idx = model_order.get(model, 999)
        
        # Group sources: RawModel/SolAgent first (group 0), then Agents (group 1)
        if source in ['RawModel', 'SolAgent']:
            group = 0
            # Within RawModel/SolAgent group, sort by model first, then source
            if source == 'RawModel':
                source_idx = 0
            else:  # SolAgent
                source_idx = 1
            return (group, model_idx, source_idx)
        else:
            # Agents group - sort by MODEL first, then agent type within each model
            group = 1
            if source == 'MetaGPT':
                agent_idx = 0
            elif source == 'DeepCode':
                agent_idx = 1
            elif source == 'QwenAgent':
                agent_idx = 2
            else:
                agent_idx = 999
            return (group, model_idx, agent_idx)  # Changed order: model before agent
    
    widths = [20, 20, 15, 15, 18, 20, 22]
    print_table_header(['Source', 'Model', 'Files', 'Total LOC', 'Avg LOC/File', 'Total Physical LOC', 'Avg Physical LOC/File'], widths)
    
    for stat in sorted(loc_summary, key=custom_sort_key):
        print_table_row([
            stat['source'],
            stat['model'],
            str(stat['file_count']),
            str(stat['total_loc']),
            f"{stat['avg_loc']:.1f}",
            str(stat['total_physical_loc']),
            f"{stat['avg_physical_loc']:.1f}"
        ], widths)
    
    print("\n" + "="*120)
    print("【Comprehensive Statistics: LOC & Complexity】")
    print("Complete comparison including lines of code and cyclomatic complexity")
    print("Complexity = number of decision nodes + 1 (decision nodes include: if, while, for, case, catch, &&, ||, ?, require, assert)")
    
    # Source, Model, Files, Total LOC, Avg LOC, Total Phy, Avg Phy, Total CC, Avg CC
    comp_widths = [18, 20, 8, 15, 15, 18, 18, 18, 18]
    print_table_header(['Source', 'Model', 'Files', 'Total LOC', 'Avg LOC', 'Total Physical LOC', 'Avg Physical LOC', 'Total Complexity', 'Avg Complexity'], comp_widths)
    
    for stat in sorted(loc_summary, key=custom_sort_key):
        print_table_row([
            stat['source'],
            stat['model'],
            str(stat['file_count']),
            str(stat['total_loc']),
            f"{stat['avg_loc']:.1f}",
            str(stat['total_physical_loc']),
            f"{stat['avg_physical_loc']:.1f}",
            str(stat['total_complexity']),
            f"{stat['avg_complexity']:.1f}"
        ], comp_widths)
        
    print("\n" + "="*120)
    print(f"Statistics completed!")
    print("="*120)


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Collect LOC statistics for RQ1 supplementary analysis')
    parser.add_argument('--db', type=str, default='output/progress.db', 
                       help='Path to database file')
    parser.add_argument('--limit', type=int, default=None,
                       help='Limit number of entries to process per table')
    parser.add_argument('--table', type=str, choices=['progress', 'agent', 'rawmodel', 'all'], default='all',
                       help='Which table(s) to collect LOC from (default: all)')
    
    args = parser.parse_args()
    
    all_loc_stats = {}
    
    if args.table in ['progress', 'all']:
        print("\n" + "="*120)
        print("Collecting SolAgent (ProgressTracker) LOC statistics...")
        print("="*120)
        loc_stats = collect_loc_progress_tracker(TARGET_MODELS, db_path=args.db, limit=args.limit)
        all_loc_stats['SolAgent'] = loc_stats  # loc_stats is {(model, file_path): {round_idx: loc}}
        print(f"  → Collected {len(loc_stats)} file/model combinations")
    
    if args.table in ['agent', 'all']:
        print("\n" + "="*120)
        print("Collecting Agent LOC statistics...")
        print("="*120)
        loc_stats = collect_loc_agent(TARGET_MODELS, db_path=args.db, limit=args.limit)
        all_loc_stats['Agent'] = loc_stats  # loc_stats is {(model, agent_type, file_path): loc}
        print(f"  → Collected {len(loc_stats)} file/model combinations")
    
    if args.table in ['rawmodel', 'all']:
        print("\n" + "="*120)
        print("Collecting RawModel LOC statistics...")
        print("="*120)
        loc_stats = collect_loc_rawmodel(TARGET_MODELS, db_path=args.db, limit=args.limit)
        all_loc_stats['RawModel'] = loc_stats  # loc_stats is {(model, file_path): loc}
        print(f"  → Collected {len(loc_stats)} file/model combinations")
    
    print(f"\n" + "="*120)
    print(f"Data sources collected: {list(all_loc_stats.keys())}")
    print("="*120)
    
    # Print statistics
    print_loc_statistics_table(all_loc_stats, TARGET_MODELS)
