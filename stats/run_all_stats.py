#!/usr/bin/env python3
"""
Main Entry Point for Statistics Scripts

Run all statistics scripts at once (RQ-1, RQ-2, Summary comparison).

Usage:
    python stats/run_all_stats.py --db output/progress.db
    python stats/run_all_stats.py --db output/progress.db --rq1-only
    python stats/run_all_stats.py --db output/progress.db --rq2-only
"""
import argparse
import subprocess
import sys
import os


def run_script(script_name: str, db_path: str, extra_args: list = None):
    """Run a statistics script."""
    script_path = os.path.join(os.path.dirname(__file__), script_name)
    
    if not os.path.exists(script_path):
        print(f"⚠️  Script not found: {script_path}")
        return False
    
    cmd = [sys.executable, script_path, '--db', db_path]
    if extra_args:
        cmd.extend(extra_args)
    
    print(f"\n{'='*80}")
    print(f"Running: {script_name}")
    print(f"{'='*80}\n")
    
    try:
        result = subprocess.run(cmd, check=True)
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Script execution failed: {script_name}")
        print(f"   Error code: {e.returncode}")
        return False
    except Exception as e:
        print(f"\n❌ Script execution error: {script_name}")
        print(f"   {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Run all statistics scripts',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all statistics
  python stats/run_all_stats.py --db output/progress.db
  
  # Run RQ-1 only
  python stats/run_all_stats.py --db output/progress.db --rq1-only
  
  # Run RQ-2 only
  python stats/run_all_stats.py --db output/progress.db --rq2-only
  
  # Run Summary comparison only
  python stats/run_all_stats.py --db output/progress.db --summary-only
        """
    )
    
    parser.add_argument('--db', type=str, default='output/progress.db',
                       help='Database path')
    parser.add_argument('--models', type=str, default='claude-sonnet-4-5,gpt-5-mini,gpt-5.1',
                       help='Comma-separated model names')
    parser.add_argument('--rq1-only', action='store_true',
                       help='Run RQ-1 statistics only')
    parser.add_argument('--rq2-only', action='store_true',
                       help='Run RQ-2 statistics only')
    parser.add_argument('--summary-only', action='store_true',
                       help='Run Summary comparison only')
    
    args = parser.parse_args()
    
    # Check database exists
    if not os.path.exists(args.db):
        print(f"❌ Database file not found: {args.db}")
        sys.exit(1)
    
    print(f"\n{'#'*80}")
    print(f"# Experimental Results Statistics")
    print(f"#")
    print(f"# Database: {args.db}")
    print(f"# Models: {args.models}")
    print(f"{'#'*80}\n")
    
    success_count = 0
    total_count = 0
    
    # Determine which scripts to run
    run_rq1 = args.rq1_only or not (args.rq2_only or args.summary_only)
    run_rq2 = args.rq2_only or not (args.rq1_only or args.summary_only)
    run_summary = args.summary_only or not (args.rq1_only or args.rq2_only)
    
    # RQ-1 Statistics
    if run_rq1:
        total_count += 1
        if run_script('rq1_statistics.py', args.db, ['--models', args.models]):
            success_count += 1
    
    # RQ-2 Ablation Statistics
    if run_rq2:
        total_count += 1
        if run_script('rq2_ablation_statistics.py', args.db, ['--models', args.models]):
            success_count += 1
    
    # Summary Comparison
    if run_summary:
        total_count += 1
        if run_script('summary_comparison.py', args.db, ['--models', args.models]):
            success_count += 1
    
    # Summary
    print(f"\n{'='*80}")
    print(f"Statistics Completed")
    print(f"{'='*80}")
    print(f"Success: {success_count}/{total_count}")
    
    if success_count < total_count:
        print(f"\n⚠️  Some scripts failed. Please check error messages above.")
        sys.exit(1)
    else:
        print(f"\n✅ All statistics scripts executed successfully!")


if __name__ == '__main__':
    main()
