#!/usr/bin/env python3
"""
Dataset Token Statistics Script
Calculate average token count of training dataset before truncation
"""

import json
import logging
import bisect
from pathlib import Path
from typing import List, Dict, Any
from transformers import AutoTokenizer

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def load_data(data_path: str) -> List[Dict[str, Any]]:
    """Load processed data"""
    logger.info(f"Loading data from {data_path}")
    
    with open(data_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    logger.info(f"Loaded {len(data)} samples")
    return data


SCRIPT_DIR = Path(__file__).resolve().parent


def calculate_token_stats(
    data_path: str = str((SCRIPT_DIR / "output/processed_tracker.json")),
    model_name: str = "Qwen/Qwen3-4B-Instruct-2507",
    train_files_path: str = str((SCRIPT_DIR / "output/train_files.json")),
):
    """
    Calculate average token count of training dataset before truncation
    
    Args:
        data_path: Training data path
        model_name: Model name or path
        train_files_path: train_files.json path (used to distinguish training set and validation set)
    """
    logger.info("="*80)
    logger.info("📊 Dataset Token Statistics")
    logger.info("="*80)
    
    # Load data
    data = load_data(data_path)
    
    # Load train_files (if exists)
    train_files = None
    if Path(train_files_path).exists():
        with open(train_files_path, 'r', encoding='utf-8') as f:
            train_files = set(json.load(f))
        logger.info(f"✅ Loaded {len(train_files)} training files")
    
    # Load tokenizer
    logger.info(f"Loading tokenizer: {model_name}")
    try:
        from modelscope import snapshot_download
        model_path = snapshot_download(model_name)
        model_name = model_path
    except Exception:
        pass
    
    tokenizer = AutoTokenizer.from_pretrained(
        model_name,
        trust_remote_code=True,
    )
    logger.info("✅ Tokenizer loaded")
    
    # Calculate tokens
    train_token_counts = []
    eval_token_counts = []
    all_token_counts = []
    
    logger.info("\n" + "="*80)
    logger.info("🔢 Calculating token counts (without truncation)...")
    logger.info("="*80)
    
    for idx, sample in enumerate(data):
        if (idx + 1) % 100 == 0:
            logger.info(f"Processing {idx + 1}/{len(data)} samples...")
        
        messages = sample.get("messages", [])
        tools = sample.get("tools", [])
        source_file = sample.get("source_file", "unknown")
        
        # Use apply_chat_template to generate complete text (without truncation)
        try:
            # Use tokenizer's apply_chat_template, without truncation
            text = tokenizer.apply_chat_template(
                messages,
                tools=tools if tools else None,
                tokenize=False,
                add_generation_prompt=False
            )
            
            # Calculate token count (without truncation)
            tokens = tokenizer.encode(text, add_special_tokens=True)
            token_count = len(tokens)
            
            # Categorize statistics
            all_token_counts.append(token_count)
            
            if train_files and source_file in train_files:
                train_token_counts.append(token_count)
            elif train_files:
                eval_token_counts.append(token_count)
                
        except Exception as e:
            logger.warning(f"Failed to process sample {idx}: {e}")
            continue
    
    # Calculate statistics
    def calc_stats(counts: List[int], name: str):
        if not counts:
            logger.info(f"\n{name}: No data")
            return
        
        avg = sum(counts) / len(counts)
        max_count = max(counts)
        min_count = min(counts)
        median = sorted(counts)[len(counts) // 2]
        
        # Calculate number of samples exceeding different lengths
        over_4k = sum(1 for c in counts if c > 4096)
        over_8k = sum(1 for c in counts if c > 8192)
        over_16k = sum(1 for c in counts if c > 16384)
        over_32k = sum(1 for c in counts if c > 32768)

        # Sample count per 8K interval (left-closed, right-open); 8K = 8*1024 = 8192
        # Additionally add [0, 4096) subdivision interval
        bucket_size = 8 * 1024
        edges = [0, 4096, 8192]
        while edges[-1] <= max_count:
            edges.append(edges[-1] + bucket_size)
        buckets = [0] * (len(edges) - 1)
        for c in counts:
            idx = bisect.bisect_right(edges, c) - 1
            if idx < 0:
                idx = 0
            if idx >= len(buckets):
                # c exactly equals the last boundary, put into the last bucket
                idx = len(buckets) - 1
            buckets[idx] += 1
        
        logger.info(f"\n{'='*80}")
        logger.info(f"📈 {name} Statistics")
        logger.info(f"{'='*80}")
        logger.info(f"Total samples: {len(counts)}")
        logger.info(f"Average tokens: {avg:.2f}")
        logger.info(f"Median tokens: {median}")
        logger.info(f"Max tokens: {max_count}")
        logger.info(f"Min tokens: {min_count}")
        logger.info(f"")
        logger.info(f"Samples > 4K (4096):   {over_4k:5d} ({over_4k/len(counts)*100:5.2f}%)")
        logger.info(f"Samples > 8K (8192):   {over_8k:5d} ({over_8k/len(counts)*100:5.2f}%)")
        logger.info(f"Samples > 16K (16384): {over_16k:5d} ({over_16k/len(counts)*100:5.2f}%)")
        logger.info(f"Samples > 32K (32768): {over_32k:5d} ({over_32k/len(counts)*100:5.2f}%)")
        logger.info(f"{'='*80}")

        logger.info("Bucket counts (left-closed, right-open):")
        for idx, cnt in enumerate(buckets):
            logger.info(f"  [{edges[idx]:5d}, {edges[idx+1]:5d}): {cnt:5d}")
        
        return {
            "total_samples": len(counts),
            "avg_tokens": avg,
            "median_tokens": median,
            "max_tokens": max_count,
            "min_tokens": min_count,
            "over_4k": over_4k,
            "over_8k": over_8k,
            "over_16k": over_16k,
            "over_32k": over_32k,
            "buckets_8k": {
                f"[{edges[i]},{edges[i+1]})": buckets[i]
                for i in range(len(buckets))
            },
        }
    
    # Output statistics results
    all_stats = calc_stats(all_token_counts, "All Dataset")
    
    if train_files:
        train_stats = calc_stats(train_token_counts, "Training Set")
        eval_stats = calc_stats(eval_token_counts, "Validation Set")
        
        # Save statistics results to JSON
        stats_output = {
            "all": all_stats,
            "train": train_stats,
            "eval": eval_stats,
        }
    else:
        stats_output = {
            "all": all_stats,
        }
    
    # Save to file
    output_path = SCRIPT_DIR / "output/token_stats.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(stats_output, f, ensure_ascii=False, indent=2)
    
    logger.info(f"\n✅ Token statistics saved to {output_path}")
    
    logger.info("\n" + "="*80)
    logger.info("🎉 Token statistics calculation completed!")
    logger.info("="*80)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Calculate dataset token statistics")
    parser.add_argument(
        "--data_path",
        type=str,
        default=str((SCRIPT_DIR / "output/processed_tracker.json")),
        help="Path to processed data JSON"
    )
    parser.add_argument(
        "--model_name",
        type=str,
        default="Qwen/Qwen3-4B-Instruct-2507",
        help="Model name or path for tokenizer"
    )
    parser.add_argument(
        "--train_files",
        type=str,
        default=str((SCRIPT_DIR / "output/train_files.json")),
        help="Path to train_files.json"
    )
    
    args = parser.parse_args()
    
    calculate_token_stats(
        data_path=args.data_path,
        model_name=args.model_name,
        train_files_path=args.train_files
    )
